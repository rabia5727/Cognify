# All database operations for Task module
# USER ACTION → API ROUTE → CRUD FUNCTION → DATABASE → RESPONSE BACK

import uuid
from datetime import datetime
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
        "category": task_data.category,  # NEW - academic/freelance/personal
        "due_date": task_data.due_date,
        # System fields (user doesn't set these)
        "status": "pending",
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow()
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


# GET all tasks for a user
async def get_tasks(user_id: str) -> list[TaskResponse]:

    # Step 1: Get database connection
    db = get_database()

    # Step 2: Find all tasks for this user
    # find() with filter {"user_id": user_id} only gets tasks owned by this user
    cursor = db["tasks"].find({"user_id": user_id})

    # Step 3: Convert cursor to actual list of tasks
    # to_list(length=100) gets up to 100 tasks (prevents memory issues)
    tasks = await cursor.to_list(length=100)

    # Step 4: Process each task
    result = []
    for task in tasks:
        # Remove MongoDB _id from each task
        task.pop("_id", None)
        # Convert to TaskResponse and add to result list
        result.append(TaskResponse(**task))

    # Step 5: Return list of tasks
    return result


# GET a single task by ID
async def get_task_by_id(task_id: str, user_id: str) -> TaskResponse | None:

    # Step 1: Get database connection
    db = get_database()

    # Step 2: Find task by id AND user_id (security - user can only get their own tasks)
    # find_one() returns the first matching document or None
    task = await db["tasks"].find_one({
        "id": task_id,      # The task ID from URL
        "user_id": user_id  # Must belong to this user (security check)
    })

    # Step 3: If no task found, return None (route will handle 404)
    if not task:
        return None

    # Step 4: Remove MongoDB _id and convert to TaskResponse
    task.pop("_id", None)
    return TaskResponse(**task)


# UPDATE a task by ID
async def update_task(task_id: str, user_id: str, task_data: TaskUpdate) -> TaskResponse | None:

    # Step 1: Get database connection
    db = get_database()

    # Step 2: Build update dictionary with only provided fields
    # We check each field - if it's None, user didn't send it so we skip it
    update_fields = {}

    if task_data.title is not None:
        update_fields["title"] = task_data.title
    if task_data.description is not None:
        update_fields["description"] = task_data.description
    if task_data.status is not None:
        update_fields["status"] = task_data.status
    if task_data.priority is not None:
        update_fields["priority"] = task_data.priority
    if task_data.category is not None:
        update_fields["category"] = task_data.category  # NEW
    if task_data.due_date is not None:
        update_fields["due_date"] = task_data.due_date

    # Step 3: ALWAYS update the timestamp
    # This helps track when task was last modified
    update_fields["updated_at"] = datetime.utcnow()

    # Step 4: Perform the update in MongoDB
    # update_one() finds ONE document and updates it
    # $set means "set these specific fields" (don't touch other fields)
    result = await db["tasks"].update_one(
        {"id": task_id, "user_id": user_id},  # Find this task owned by this user
        {"$set": update_fields}                # Update only these fields
    )

    # Step 5: Check if task was found
    # matched_count = 1 means task existed, 0 means not found
    if result.matched_count == 0:
        return None  # Route will handle 404

    # Step 6: Return the updated task by fetching fresh data
    return await get_task_by_id(task_id, user_id)


# DELETE a task by ID
async def delete_task(task_id: str, user_id: str) -> bool:

    # Step 1: Get database connection
    db = get_database()

    # Step 2: Delete task matching BOTH id AND user_id
    # This ensures users can only delete their own tasks
    result = await db["tasks"].delete_one({
        "id": task_id,
        "user_id": user_id
    })

    # Step 3: Return result
    # deleted_count = 1 means success, 0 means task not found
    return result.deleted_count == 1