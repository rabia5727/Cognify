# All database operations for Task module
# USER ACTION → API ROUTE → CRUD FUNCTION → DATABASE → RESPONSE BACK

import uuid
from datetime import datetime
from typing import Optional
from app.db.connection import get_database
from app.models.task import TaskCreate, TaskUpdate, TaskResponse


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
        "category": task_data.category,  # academic/freelance/personal
        "due_date": task_data.due_date,
        # System fields (user doesn't set these)
        "status": "pending",              # New tasks always start as pending
        "created_at": datetime.utcnow(),  # Set creation timestamp
        "updated_at": datetime.utcnow()   # Initially same as created_at
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

    # Step 2: Build update dictionary with ONLY provided fields
    # We check each field - if it's None, user didn't send it
    update_fields = {}

    if task_data.title is not None:
        update_fields["title"] = task_data.title          # Update title
    if task_data.description is not None:
        update_fields["description"] = task_data.description  # Update description
    if task_data.status is not None:
        update_fields["status"] = task_data.status        # Update status
    if task_data.priority is not None:
        update_fields["priority"] = task_data.priority      # Update priority
    if task_data.category is not None:
        update_fields["category"] = task_data.category    # Update category
    if task_data.due_date is not None:
        update_fields["due_date"] = task_data.due_date    # Update due date

    # Step 3: ALWAYS update the timestamp
    # This helps track when task was last modified
    update_fields["updated_at"] = datetime.utcnow()

    # Step 4: Perform the update in MongoDB
    # update_one() finds ONE document and updates it
    # $set means "set these fields" (leaves other fields unchanged)
    result = await db["tasks"].update_one(
        {"id": task_id, "user_id": user_id},  # Find this task (security check)
        {"$set": update_fields}                # Update only these fields
    )

    # Step 5: Check if task was found
    # matched_count = 1 means task existed and was updated
    # matched_count = 0 means task not found (wrong id or wrong user)
    if result.matched_count == 0:
        return None  # Route will handle 404

    # Step 6: Return the updated task
    # We reuse get_task_by_id to fetch the fresh data
    return await get_task_by_id(task_id, user_id)


# DELETE a task by ID
async def delete_task(task_id: str, user_id: str) -> bool:

    # Step 1: Get database connection
    db = get_database()

    # Step 2: Delete task matching BOTH id AND user_id
    # This ensures users can only delete their own tasks (security!)
    result = await db["tasks"].delete_one({
        "id": task_id,
        "user_id": user_id
    })

    # Step 3: Return result
    # deleted_count = 1 → successfully deleted
    # deleted_count = 0 → task not found (or wrong user)
    return result.deleted_count == 1