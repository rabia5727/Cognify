# -------------------------------------------------------
# This module defines the API routes for managing workflows in the application. \
# It includes endpoints for creating, retrieving, updating, and deleting workflows,
#  as well as adding tasks and milestones to workflows. All routes are protected and require a valid JWT token for authentication. 
# The routes interact with the corresponding CRUD functions to perform database operations
#  and return appropriate responses or error messages based on the outcome of each operation.
#--------------------------------------------------------
from fastapi import APIRouter, HTTPException, status, Depends
from app.models.workflow import WorkflowCreate, WorkflowUpdate, WorkflowResponse, MilestoneCreate
from app.crud.workflow import (
    create_workflow,
    get_workflows,
    get_workflow_by_id,
    update_workflow,
    delete_workflow,
    add_task_to_workflow,
    add_milestone,
    complete_milestone
)
from app.utils.dependencies import get_current_user
from app.crud.notifications_triggers import check_workflow_progress

router = APIRouter(prefix="/workflows", tags=["Workflows"])


# CREATE a new workflow
@router.post("/", response_model=WorkflowResponse)
async def create_new_workflow(
    workflow_data: WorkflowCreate,
    current_user: dict = Depends(get_current_user)  # 🔒 Protected
):
    """
    ENDPOINT: POST /workflows/
        - Creates a new workflow (project container)
        - Requires JWT token
    """
    user_id = str(current_user["_id"])
    return await create_workflow(workflow_data, user_id)


# GET all workflows for a user
@router.get("/", response_model=list[WorkflowResponse])
async def get_all_workflows(
    current_user: dict = Depends(get_current_user)  # 🔒 Protected
):
    """
    ENDPOINT: GET /workflows/
        - Returns all workflows for logged in user
        - Requires JWT token
    """
    user_id = str(current_user["_id"])
    return await get_workflows(user_id)


# GET a single workflow
@router.get("/{workflow_id}", response_model=WorkflowResponse)
async def get_single_workflow(
    workflow_id: str,
    current_user: dict = Depends(get_current_user)  # 🔒 Protected
):
    """
    ENDPOINT: GET /workflows/{workflow_id}
        - Returns a single workflow with milestones and progress
        - Requires JWT token
    """
    user_id = str(current_user["_id"])
    workflow = await get_workflow_by_id(workflow_id, user_id)
    if not workflow:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Workflow {workflow_id} not found or doesn't belong to you"
        )
    return workflow


# UPDATE a workflow
@router.put("/{workflow_id}", response_model=WorkflowResponse)
async def update_existing_workflow(
    workflow_id: str,
    workflow_data: WorkflowUpdate,
    current_user: dict = Depends(get_current_user)  # 🔒 Protected
):
    """
    ENDPOINT: PUT /workflows/{workflow_id}
        - Update title, description, category or status
        - Requires JWT token
    """
    user_id = str(current_user["_id"])
    workflow = await update_workflow(workflow_id, user_id, workflow_data)
    if not workflow:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Workflow {workflow_id} not found or doesn't belong to you"
        )
    return workflow


# DELETE a workflow
@router.delete("/{workflow_id}")
async def delete_existing_workflow(
    workflow_id: str,
    current_user: dict = Depends(get_current_user)  # 🔒 Protected
):
    """
    ENDPOINT: DELETE /workflows/{workflow_id}
        - Permanently deletes a workflow
        - Requires JWT token
    """
    user_id = str(current_user["_id"])
    deleted = await delete_workflow(workflow_id, user_id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Workflow {workflow_id} not found or doesn't belong to you"
        )
    return {"message": "Workflow deleted successfully"}


# ADD a task to a workflow
@router.post("/{workflow_id}/tasks/{task_id}", response_model=WorkflowResponse)
async def link_task_to_workflow(
    workflow_id: str,
    task_id: str,
    current_user: dict = Depends(get_current_user)  # 🔒 Protected
):
    """
    ENDPOINT: POST /workflows/{workflow_id}/tasks/{task_id}
        - Links an existing task to a workflow
        - Requires JWT token
    """
    user_id = str(current_user["_id"])
    workflow = await add_task_to_workflow(workflow_id, user_id, task_id)
    if not workflow:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Workflow {workflow_id} not found or doesn't belong to you"
        )
    return workflow


# ADD a milestone to a workflow
@router.post("/{workflow_id}/milestones", response_model=WorkflowResponse)
async def add_workflow_milestone(
    workflow_id: str,
    milestone_data: MilestoneCreate,
    current_user: dict = Depends(get_current_user)  # 🔒 Protected
):
    """
    ENDPOINT: POST /workflows/{workflow_id}/milestones
        - Adds a milestone to a workflow
        - Requires JWT token
    """
    user_id = str(current_user["_id"])
    workflow = await add_milestone(workflow_id, user_id, milestone_data)
    if not workflow:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Workflow {workflow_id} not found or doesn't belong to you"
        )
    return workflow


# COMPLETE a milestone
@router.patch("/{workflow_id}/milestones/{milestone_id}/complete", response_model=WorkflowResponse)
async def mark_milestone_complete(
    workflow_id: str,
    milestone_id: str,
    current_user: dict = Depends(get_current_user)  # 🔒 Protected
):
    """
    ENDPOINT: PATCH /workflows/{workflow_id}/milestones/{milestone_id}/complete
        - Marks a milestone as completed
        - Updates progress percentage automatically
        - Requires JWT token
    """
    user_id = str(current_user["_id"])
    workflow = await complete_milestone(workflow_id, user_id, milestone_id)
    if not workflow:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Milestone {milestone_id} not found"
        )
    # Fire progress notification if a threshold was crossed
    await check_workflow_progress(
        workflow_id=workflow_id,
        user_id=user_id,
        workflow_title=workflow.title,
        progress=workflow.progress,
    )
    return workflow