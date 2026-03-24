# @router.______("______", response_model=______)
#        └┬┘    └──┬──┘    └──────┬───────┘
#      Method     Path         What we return

from fastapi import APIRouter, HTTPException, status, Depends, Query
from typing import Optional
from datetime import datetime
from app.models.task import TaskCreate, TaskUpdate, TaskResponse
from app.crud.task import (
    create_task,
    get_tasks,
    get_task_by_id,
    update_task,
    delete_task,
    count_tasks          # For pagination - tells frontend total pages
)
from app.utils.dependencies import get_current_user  # Gets user from JWT token

# Create router instance
# prefix="/tasks" means all routes start with /tasks
# tags=["Tasks"] groups them together in Swagger documentation
router = APIRouter(prefix="/tasks", tags=["Tasks"])


# --------------------------
# CREATE a new task
# POST /tasks/
# --------------------------
@router.post("/", response_model=TaskResponse)
async def create_new_task(
    task_data: TaskCreate,  # JSON body with title, description, priority, etc.
    current_user: dict = Depends(get_current_user)  # Get logged-in user from token
):
    """
    Create a new task for the authenticated user.
    
    ENDPOINT: POST /tasks/
    
    REQUEST BODY:
        - title: str (required)
        - description: str (optional)
        - priority: "low" | "medium" | "high"
        - category: "academic" | "freelance" | "personal" (optional)
        - due_date: datetime (optional)
    
    RETURNS:
        - 201: The created task with all fields
        - 401: If not authenticated
        - 422: If validation fails
    """
    # Extract user ID from JWT token (comes from auth middleware)
    user_id = str(current_user["_id"])
    
    # Call CRUD function to create task in database
    return await create_task(task_data, user_id)


# ─────────────────────────────────────────────────────────────────
# GET all tasks — NOW with search, filters, sorting, pagination
# ─────────────────────────────────────────────────────────────────
@router.get("/", response_model=dict)
async def get_all_tasks(
    # 🔍 SEARCH PARAMETER
    # Searches in both title and description fields
    # Example: /tasks/?search=react  → finds "React tutorial", "Learn React"
    search: Optional[str] = Query(None, description="Search in title or description"),

    # 🎯 FILTER PARAMETERS
    # Each filter narrows down results by exact match
    # Example: /tasks/?status=pending&priority=high
    status:   Optional[str] = Query(None, description="Filter by status: pending | in_progress | completed"),
    priority: Optional[str] = Query(None, description="Filter by priority: low | medium | high"),
    category: Optional[str] = Query(None, description="Filter by category: academic | freelance | personal"),

    # 📅 DATE RANGE PARAMETERS
    # Filter tasks due within a specific time period
    # Example: /tasks/?due_after=2025-01-01&due_before=2025-01-31
    due_after:  Optional[datetime] = Query(None, description="Tasks due after this date (ISO format)"),
    due_before: Optional[datetime] = Query(None, description="Tasks due before this date (ISO format)"),

    # 🔃 SORTING PARAMETERS
    # Control the order of results
    # Example: /tasks/?sort_by=due_date&sort_order=asc
    sort_by:    str = Query("created_at", description="Field to sort by: created_at | due_date | priority"),
    sort_order: str = Query("desc",       description="Sort direction: asc (oldest first) | desc (newest first)"),

    # 📄 PAGINATION PARAMETERS
    # Split results into pages for better performance
    # Example: /tasks/?page=2&page_size=10  → second page, 10 items per page
    page:      int = Query(1,  ge=1,   description="Page number (starts at 1)"),
    page_size: int = Query(20, ge=1, le=100, description="Number of tasks per page (max 100)"),

    current_user: dict = Depends(get_current_user)  # 🔒 Protected endpoint - requires login
):
    """
    Get all tasks for the authenticated user with powerful filtering.
    
    ENDPOINT: GET /tasks/
    
    QUERY PARAMETERS:
        - search: Search text in title/description
        - status: Filter by status (pending/in_progress/completed)
        - priority: Filter by priority (low/medium/high)
        - category: Filter by category (academic/freelance/personal)
        - due_after: Tasks due after this date
        - due_before: Tasks due before this date
        - sort_by: Field to sort by
        - sort_order: asc (oldest) or desc (newest)
        - page: Page number
        - page_size: Items per page
    
    RETURNS:
        - 200: Object with tasks array and pagination metadata
        - 401: If not authenticated
    
    EXAMPLE RESPONSE:
    {
        "tasks": [...],
        "pagination": {
            "total": 45,        # Total tasks matching filters
            "page": 2,          # Current page
            "page_size": 20,    # Items per page
            "total_pages": 3    # Total pages available
        }
    }
    """
    # Step 1: Get user ID from JWT token (security)
    user_id = str(current_user["_id"])

    # Step 2: Convert string sort order to MongoDB number format
    # MongoDB uses: 1 = ascending (oldest first), -1 = descending (newest first)
    mongo_sort_order = -1 if sort_order == "desc" else 1

    # Step 3: Convert page number to database skip value
    # MongoDB pagination uses skip + limit, not page numbers
    # Page 1: skip 0    (items 1-20)
    # Page 2: skip 20   (items 21-40)
    # Page 3: skip 40   (items 41-60)
    skip = (page - 1) * page_size

    # Step 4: Fetch filtered, sorted, and paginated tasks from database
    tasks = await get_tasks(
        user_id=user_id,
        search=search,
        status=status,
        priority=priority,
        category=category,
        due_after=due_after,
        due_before=due_before,
        sort_by=sort_by,
        sort_order=mongo_sort_order,
        skip=skip,
        limit=page_size,
    )

    # Step 5: Get total count for pagination metadata
    # Frontend needs this to calculate total pages
    total = await count_tasks(
        user_id=user_id,
        status=status,
        priority=priority,
        category=category,
    )

    # Step 6: Calculate total pages using ceiling division
    # Example: 45 tasks ÷ 20 per page = 2.25 → 3 pages
    total_pages = (total + page_size - 1) // page_size

    # Step 7: Return tasks with pagination metadata
    return {
        "tasks": tasks,  # Array of task objects
        "pagination": {
            "total": total,                    # Total matching tasks
            "page": page,                       # Current page
            "page_size": page_size,              # Items per page
            "total_pages": total_pages,          # Total pages available
        }
    }


# --------------------------
# GET a single task
# GET /tasks/{task_id}
# --------------------------
@router.get("/{task_id}", response_model=TaskResponse)
async def get_single_task(
    task_id: str,  # Task ID from URL path
    current_user: dict = Depends(get_current_user)  # 🔒 Protected
):
    """
    Get one specific task by its ID.
    
    ENDPOINT: GET /tasks/{task_id}
    
    PATH PARAMETERS:
        - task_id: The unique ID of the task to retrieve
    
    RETURNS:
        - 200: The requested task
        - 401: If not authenticated
        - 404: If task not found or doesn't belong to user
    
    SECURITY NOTE: 
        Even if task exists, returns 404 if it doesn't belong to this user.
        This prevents users from accessing each other's tasks.
    """
    # Extract user ID from token
    user_id = str(current_user["_id"])
    
    # Fetch task from database (CRUD checks ownership)
    task = await get_task_by_id(task_id, user_id)

    # If task not found or doesn't belong to user
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Task {task_id} not found or doesn't belong to you"
        )
    
    # Return found task
    return task


# --------------------------
# UPDATE a task
# PUT /tasks/{task_id}
# --------------------------
@router.put("/{task_id}", response_model=TaskResponse)
async def update_existing_task(
    task_id: str,  # Task ID from URL path
    task_data: TaskUpdate,  # JSON body with fields to update (all optional)
    current_user: dict = Depends(get_current_user)  # 🔒 Protected
):
    """
    Update an existing task.
    
    ENDPOINT: PUT /tasks/{task_id}
    
    PATH PARAMETERS:
        - task_id: The unique ID of the task to update
    
    REQUEST BODY:
        Any of these fields (all optional):
        - title: str
        - description: str
        - status: "pending" | "in_progress" | "completed"
        - priority: "low" | "medium" | "high"
        - category: "academic" | "freelance" | "personal"
        - due_date: datetime
    
    RETURNS:
        - 200: The updated task
        - 401: If not authenticated
        - 404: If task not found or doesn't belong to user
        - 422: If validation fails
    
    NOTE: Only fields sent in the request body will be updated.
          Other fields remain unchanged.
    """
    # Extract user ID from token
    user_id = str(current_user["_id"])
    
    # Update task in database (CRUD checks ownership)
    task = await update_task(task_id, user_id, task_data)

    # If task not found or doesn't belong to user
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Task {task_id} not found or doesn't belong to you"
        )
    
    # Return updated task
    return task


# --------------------------
# DELETE a task
# DELETE /tasks/{task_id}
# --------------------------
@router.delete("/{task_id}")
async def delete_existing_task(
    task_id: str,  # Task ID from URL path
    current_user: dict = Depends(get_current_user)  # 🔒 Protected
):
    """
    Delete a task permanently.
    
    ENDPOINT: DELETE /tasks/{task_id}
    
    PATH PARAMETERS:
        - task_id: The unique ID of the task to delete
    
    RETURNS:
        - 200: {"message": "Task deleted successfully"}
        - 401: If not authenticated
        - 404: If task not found or doesn't belong to user
    
    WARNING: This permanently removes the task from the database.
             There is no undo!
    """
    # Extract user ID from token
    user_id = str(current_user["_id"])
    
    # Delete task from database (CRUD checks ownership)
    deleted = await delete_task(task_id, user_id)

    # If task not found or doesn't belong to user
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Task {task_id} not found or doesn't belong to you"
        )
    
    # Return success message
    return {"message": "Task deleted successfully"}