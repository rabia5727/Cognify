# @router.______("______", response_model=______)
#        └┬┘    └──┬──┘    └──────┬───────┘
#      Method     Path         What we return

from fastapi import APIRouter, HTTPException, status, Depends
from app.models.task import TaskCreate, TaskUpdate, TaskResponse
from app.crud.task import (
    create_task,
    get_tasks,
    get_task_by_id,
    update_task,
    delete_task
)
from app.utils.dependencies import get_current_user

# Create router instance
# prefix="/tasks" means all routes start with /tasks
router = APIRouter(prefix="/tasks", tags=["Tasks"])


# CREATE a new task
@router.post("/", response_model=TaskResponse)
async def create_new_task(
    task_data: TaskCreate,
    current_user: dict = Depends(get_current_user)  # 🔒 Protected
):
    """
    ENDPOINT: POST /tasks/
        - task_data: Task details (title, description, priority, category, due_date)
        - current_user: Automatically extracted from JWT token (no need to send user_id)
    """
    # Extract user_id from the JWT token (secure - user can't fake this)
    user_id = str(current_user["_id"])
    # Call CRUD function to create task in database
    return await create_task(task_data, user_id)


# GET all tasks for a user
@router.get("/", response_model=list[TaskResponse])
async def get_all_tasks(
    current_user: dict = Depends(get_current_user)  # 🔒 Protected
):
    """
    ENDPOINT: GET /tasks/
        - current_user: Automatically extracted from JWT token
        - Returns only tasks belonging to the logged in user
    """
    # Extract user_id from JWT token
    user_id = str(current_user["_id"])
    # Call CRUD function to get all tasks for this user
    return await get_tasks(user_id)


# GET a single task by ID
@router.get("/{task_id}", response_model=TaskResponse)
async def get_single_task(
    task_id: str,
    current_user: dict = Depends(get_current_user)  # 🔒 Protected
):
    """
    ENDPOINT: GET /tasks/{task_id}
        - task_id: The ID of the task to fetch (from URL)
        - current_user: Automatically extracted from JWT token
    """
    # Extract user_id from JWT token
    user_id = str(current_user["_id"])
    # Call CRUD function to get specific task
    task = await get_task_by_id(task_id, user_id)

    # If task not found (CRUD returned None) raise 404
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Task {task_id} not found or doesn't belong to you"
        )
    return task


# UPDATE an existing task
@router.put("/{task_id}", response_model=TaskResponse)
async def update_existing_task(
    task_id: str,
    task_data: TaskUpdate,
    current_user: dict = Depends(get_current_user)  # 🔒 Protected
):
    """
    ENDPOINT: PUT /tasks/{task_id}
        - task_id: The ID of the task to update
        - task_data: Fields to update (any of: title, description, status, priority, category, due_date)
        - current_user: Automatically extracted from JWT token
    """
    # Extract user_id from JWT token
    user_id = str(current_user["_id"])
    # Call CRUD function to update task
    task = await update_task(task_id, user_id, task_data)

    # If task not found (CRUD returned None) raise 404
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Task {task_id} not found or doesn't belong to you"
        )
    return task


# DELETE a task
@router.delete("/{task_id}")
async def delete_existing_task(
    task_id: str,
    current_user: dict = Depends(get_current_user)  # 🔒 Protected
):
    """
    ENDPOINT: DELETE /tasks/{task_id}
        - task_id: The ID of the task to delete
        - current_user: Automatically extracted from JWT token
    """
    # Extract user_id from JWT token
    user_id = str(current_user["_id"])
    # Call CRUD function to delete task
    deleted = await delete_task(task_id, user_id)

    # If task not found (CRUD returned False) raise 404
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Task {task_id} not found or doesn't belong to you"
        )
    return {"message": "Task deleted successfully"}