# @router.______("______", response_model=______)
#        └┬┘    └──┬──┘    └──────┬───────┘
#      Method     Path         What we return


from fastapi import APIRouter, HTTPException, status
from app.models.task import TaskCreate, TaskUpdate, TaskResponse
from app.crud.task import (
    create_task,
    get_tasks,
    get_task_by_id,
    update_task,
    delete_task
)

# Create router instance
# prefix="/tasks" means all routes start with /tasks
router = APIRouter(prefix="/tasks", tags=["Tasks"])


# CREATE a new task
@router.post("/", response_model=TaskResponse)
async def create_new_task(task_data: TaskCreate, user_id: str):
    """  
    ENDPOINT: POST /tasks/
        - task_data: Task details (title, description, priority, due_date)
        - user_id: Who owns this task
    """
    # Call CRUD function to create task in database
    task = await create_task(task_data, user_id)
    # Return the created task 
    return task


# GET all tasks for a user
@router.get("/", response_model=list[TaskResponse])
async def get_all_tasks(user_id: str):
    """ 
    ENDPOINT: GET /tasks?user_id=123
        - user_id: Whose tasks to fetch (as query parameter)
    """
    # Call CRUD function to get all tasks for this user
    tasks = await get_tasks(user_id)
    # Return list of tasks (empty list if no tasks found)
    return tasks
    

# GET a single task by ID
@router.get("/{task_id}", response_model=TaskResponse)
async def get_single_task(task_id: str, user_id: str):
  
    """
    ENDPOINT: GET /tasks/123?user_id=456
        - task_id: The ID of the task to fetch (from URL)
        - user_id: Who owns this task (security check)
    """
    
    # Call CRUD function to get specific task
    task = await get_task_by_id(task_id, user_id)
    
    # If task not found (CRUD returned None)
    if not task:
        # Raise 404 error with custom message
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Task with id {task_id} not found or doesn't belong to you"
        )
    
    # Return the found task
    return task

# UPDATE an existing task
@router.put("/{task_id}", response_model=TaskResponse)
async def update_existing_task(
    task_id: str,
    user_id: str,
    task_data: TaskUpdate
):
    """
     - task_id: The ID of the task to update
     - user_id: Who owns this task (security check)
     - task_data: Fields to update (any of: title, description, status, priority, due_date)
    """
   
    # Call CRUD function to update task
    task = await update_task(task_id, user_id, task_data)
    
    # If task not found (CRUD returned None)
    if not task:
        # Raise 404 error with custom message
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Task with id {task_id} not found or doesn't belong to you"
        )
    
    # Return the updated task
    return task



# DELETE a task
@router.delete("/{task_id}")
async def delete_existing_task(task_id: str, user_id: str):
    
    # Call CRUD function to delete task
    deleted = await delete_task(task_id, user_id)
    
    # If task not found (CRUD returned False)
    if not deleted:
        # Raise 404 error with custom message
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Task with id {task_id} not found or doesn't belong to you"
        )
    
    # Return success message
    return {"message": "Task deleted successfully"}