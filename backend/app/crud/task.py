# All database operations for Task module
# USER ACTION → API ROUTE → CRUD FUNCTION → DATABASE → RESPONSE BACK

import uuid
from datetime import datetime, timezone
from typing import Optional
from app.db.connection import get_database
from app.models.task import TaskCreate, TaskUpdate, TaskResponse
from app.crud.analytics import record_daily_snapshot
from app.crud import sync_dismissals

async def _sync_project_status(db, project_id: str) -> None:
    """Auto-complete or reactivate a project based on its tasks' statuses."""
    project = await db["projects"].find_one({"id": project_id})
    if not project:
        return
    task_ids = project.get("task_ids", [])
    if not task_ids:
        return
    tasks = await db["tasks"].find({"id": {"$in": task_ids}}).to_list(length=None)
    if not tasks:
        return
    all_done = all(t.get("status") == "completed" for t in tasks)
    new_status = "completed" if all_done else "active"
    if project.get("status") != new_status:
        await db["projects"].update_one(
            {"id": project_id},
            {"$set": {"status": new_status, "updated_at": datetime.now(timezone.utc)}},
        )


# CREATE a new task
async def create_task(task_data: TaskCreate, user_id: str) -> TaskResponse:

    # Step 1: Get connection to MongoDB database
    db = get_database()

    # Step 2: Build the task document to save in MongoDB
    task_dict = {
        # Generate unique ID using UUID4 (random, no duplicates)
        "id": str(uuid.uuid4()),
        # Who owns this task? Comes from JWT token (not user input)
        "user_id": user_id,
        # These fields come from what user sent in API request
        "title": task_data.title,
        "description": task_data.description,
        "priority": task_data.priority,
        "category": task_data.category,
        "due_date": task_data.due_date,
        "due_time": task_data.due_time,
        "project_id": task_data.project_id,
        #add classroom fields
        "source": task_data.source,
        "source_id": task_data.source_id,
        "course_id": task_data.course_id,

        # System fields (user doesn't set these)
        "status": "pending",              # New tasks always start as pending
        "created_at": datetime.now(timezone.utc),  # Set creation timestamp
        "updated_at": datetime.now(timezone.utc)   # Initially same as created_at
    }

    # Step 3: Save to MongoDB
    # insert_one() adds this document to the "tasks" collection
    await db["tasks"].insert_one(task_dict)

    # Step 4: Remove MongoDB's internal _id field
    # MongoDB automatically adds "_id" to every document
    # But it's not JSON serializable - causes errors in API responses
    task_dict.pop("_id", None)

    # Step 5: Return as proper TaskResponse object
    return TaskResponse(**task_dict)
    
# ─────────────────────────────────────────────────────────────────
# GET all tasks — NOW with search, filters, sorting, pagination
# ─────────────────────────────────────────────────────────────────
async def get_tasks(
    user_id: str,

    # 🔍 SEARCH
    # Looks for keyword inside title or description
    # Example: search="React" → finds "React assignment", "Learn React"
    search: Optional[str] = None,

    # 🎯 FILTERS
    # Example: status="pending" → only unfinished tasks
    status: Optional[str] = None,      # pending | in_progress | completed
    priority: Optional[str] = None,    # low | medium | high
    category: Optional[str] = None,    # academic | freelance | personal

    # 📅 DATE RANGE FILTERS
    # Example: due_after=Monday + due_before=Friday → only this week's tasks
    due_after: Optional[datetime] = None,
    due_before: Optional[datetime] = None,

    # 🔃 SORTING
    # sort_by="due_date" + sort_order=1 → most urgent tasks first
    sort_by: str = "created_at",       # field to sort by
    sort_order: int = -1,              # -1=newest first, 1=oldest first

    # 📄 PAGINATION
    # Prevents loading ALL tasks at once (bad for performance)
    # skip=0, limit=20 → first 20 tasks
    # skip=20, limit=20 → next 20 tasks (page 2)
    skip: int = 0,
    limit: int = 20,

) -> list[TaskResponse]:

    # Step 1: Get database connection
    db = get_database()

    # ── Step 2: Build MongoDB query ──────────────────────────────
    # Always start with user_id — users only see THEIR tasks (security)
    query = {"user_id": user_id}

    # 🔍 SEARCH filter
    # $or = match title OR description
    # $regex = partial match (like SQL LIKE '%keyword%')
    # $options "i" = case-insensitive ("react" matches "React")
    if search:
        query["$or"] = [
            {"title":       {"$regex": search, "$options": "i"}},
            {"description": {"$regex": search, "$options": "i"}},
        ]

    # 🎯 EXACT MATCH filters — only added if user provided them
    if status:
        query["status"] = status      # Filter by task status

    if priority:
        query["priority"] = priority  # Filter by priority level

    if category:
        query["category"] = category  # Filter by category

    # 📅 DATE RANGE filter
    # $gte = greater than or equal (after this date)
    # $lte = less than or equal (before this date)
    if due_after or due_before:
        query["due_date"] = {}
        if due_after:
            query["due_date"]["$gte"] = due_after  # Tasks due after this date
        if due_before:
            query["due_date"]["$lte"] = due_before  # Tasks due before this date

    # ── Step 3: Run query with sort + pagination ─────────────────
    # Chain MongoDB methods: find → sort → skip → limit
    cursor = (
            db["tasks"]
            .find(query) 
            .sort(sort_by, sort_order)   # Sort results
            .skip(skip)               # Skip N items (pagination)
            .limit(limit)   
            )                # Take only N items

    # Step 4: Convert cursor to actual list of tasks
    # to_list() executes the query and returns results
    tasks = await cursor.to_list(length=limit)

    # Step 5: Clean and return results
    result = []
    for task in tasks:
        # Remove MongoDB _id from each task (not JSON serializable)
        task.pop("_id", None)
        # Convert to TaskResponse object (validates data)
        result.append(TaskResponse(**task))

    return result


# ─────────────────────────────────────────────────────────────────
# COUNT tasks — needed so frontend knows total pages
# Example: 45 tasks ÷ 20 per page = 3 pages total
# ─────────────────────────────────────────────────────────────────
async def count_tasks(
    user_id: str,
    status: Optional[str] = None,
    priority: Optional[str] = None,
    category: Optional[str] = None,
) -> int:

    # Step 1: Get database connection
    db = get_database()

    # Step 2: Build count query (same filters as get_tasks)
    # This ensures count matches what get_tasks returns
    query = {"user_id": user_id}  # Always filter by user (security)
    
    if status:
        query["status"] = status    # Count only tasks with this status
    if priority:
        query["priority"] = priority  # Count only tasks with this priority
    if category:
        query["category"] = category  # Count only tasks in this category

    # Step 3: Execute count query
    # count_documents() returns total number of matching documents
    return await db["tasks"].count_documents(query)


# GET a single task by ID
async def get_task_by_id(task_id: str, user_id: str) -> TaskResponse | None:

    # Step 1: Get database connection
    db = get_database()

    # Step 2: Find task by id AND user_id
    # This security check ensures users can only access their own tasks
    task = await db["tasks"].find_one({
        "id": task_id,       # The task ID from URL
        "user_id": user_id   # Must belong to this user (security!)
    })

    # Step 3: If no task found, return None (route will handle 404)
    if not task:
        return None

    # Step 4: Remove MongoDB _id and convert to TaskResponse
    task.pop("_id", None)           # Remove non-serializable field
    return TaskResponse(**task)      # Return validated task


# UPDATE a task by ID
async def update_task(task_id: str, user_id: str, task_data: TaskUpdate) -> TaskResponse | None:

    # Step 1: Get database connection
    db = get_database()

    # Step 2: Fetch current task to check existing status before updating
    current = await db["tasks"].find_one({"id": task_id, "user_id": user_id})
    if not current:
        return None

    # Step 3: Build update dictionary with ONLY provided fields
    update_fields = {}

    if task_data.title is not None:
        update_fields["title"] = task_data.title          # Update title
    if task_data.description is not None:
        update_fields["description"] = task_data.description
    if task_data.status is not None:
        update_fields["status"] = task_data.status
    if task_data.priority is not None:
        update_fields["priority"] = task_data.priority
    if task_data.category is not None:
        update_fields["category"] = task_data.category
    if task_data.due_date is not None:
        update_fields["due_date"] = task_data.due_date
    if task_data.due_time is not None:
        update_fields["due_time"] = task_data.due_time
    if task_data.project_id is not None:
        update_fields["project_id"] = task_data.project_id

    # Set completed_at once — only when transitioning TO completed for the first time
    if task_data.status == "completed" and current.get("status") != "completed":
        update_fields["completed_at"] = datetime.now(timezone.utc)

    # Step 4: ALWAYS update the timestamp
    update_fields["updated_at"] = datetime.now(timezone.utc)

    # Step 5: Perform the update in MongoDB
    # $set means "set these fields" (leaves other fields unchanged)
    await db["tasks"].update_one(
        {"id": task_id, "user_id": user_id},
        {"$set": update_fields}
    )

    # Step 6: Sync parent project status if task status changed
    if task_data.status is not None:
        project_id = current.get("project_id")
        if project_id:
            await _sync_project_status(db, project_id)

    # Record analytics snapshot when task is completed
    if task_data.status == "completed" and current.get("status") != "completed":
        await record_daily_snapshot(user_id)

    return await get_task_by_id(task_id, user_id)


# DELETE a task by ID
async def delete_task(task_id: str, user_id: str) -> bool:

    # Step 1: Get database connection
    db = get_database()

    # Step 2: Fetch task first to get its project_id before deleting
    task = await db["tasks"].find_one({"id": task_id, "user_id": user_id})
    if not task:
        return False

    # Step 3: Delete the task
    result = await db["tasks"].delete_one({"id": task_id, "user_id": user_id})
    if result.deleted_count == 0:
        return False

    # Step 4: Remove task_id from any project that references it
    project_id = task.get("project_id")
    if project_id:
        await db["projects"].update_one(
            {"id": project_id},
            {"$pull": {"task_ids": task_id}, "$set": {"updated_at": datetime.now(timezone.utc)}},
        )
        await _sync_project_status(db, project_id)

    # Step 5: If this task came from an external sync (Classroom, Gmail),
    # remember that the user dismissed it — otherwise the next auto-sync
    # sees no matching task and silently re-creates it.
    source = task.get("source")
    source_id = task.get("source_id")
    if source and source_id:
        await sync_dismissals.record_dismissal(user_id, source, source_id)

    return True