from fastapi import APIRouter, HTTPException, status, Depends
from app.models.project import ProjectCreate, ProjectUpdate, ProjectResponse
from app.crud.project import (
    create_project,
    get_projects,
    get_project_by_id,
    update_project,
    delete_project,
    add_task_to_project,
)
from app.utils.dependencies import get_current_user

router = APIRouter(prefix="/projects", tags=["Projects"])


@router.post("/", response_model=ProjectResponse)
async def create_new_project(
    project_data: ProjectCreate,
    current_user: dict = Depends(get_current_user),
):
    user_id = str(current_user["_id"])
    return await create_project(project_data, user_id)


@router.get("/", response_model=list[ProjectResponse])
async def get_all_projects(
    current_user: dict = Depends(get_current_user),
):
    user_id = str(current_user["_id"])
    return await get_projects(user_id)


@router.get("/{project_id}", response_model=ProjectResponse)
async def get_single_project(
    project_id: str,
    current_user: dict = Depends(get_current_user),
):
    user_id = str(current_user["_id"])
    project = await get_project_by_id(project_id, user_id)
    if not project:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Project {project_id} not found or doesn't belong to you",
        )
    return project


@router.put("/{project_id}", response_model=ProjectResponse)
async def update_existing_project(
    project_id: str,
    project_data: ProjectUpdate,
    current_user: dict = Depends(get_current_user),
):
    user_id = str(current_user["_id"])
    project = await update_project(project_id, user_id, project_data)
    if not project:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Project {project_id} not found or doesn't belong to you",
        )
    return project


@router.delete("/{project_id}")
async def delete_existing_project(
    project_id: str,
    current_user: dict = Depends(get_current_user),
):
    user_id = str(current_user["_id"])
    deleted = await delete_project(project_id, user_id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Project {project_id} not found or doesn't belong to you",
        )
    return {"message": "Project deleted successfully"}


@router.post("/{project_id}/tasks/{task_id}", response_model=ProjectResponse)
async def link_task_to_project(
    project_id: str,
    task_id: str,
    current_user: dict = Depends(get_current_user),
):
    user_id = str(current_user["_id"])
    project = await add_task_to_project(project_id, user_id, task_id)
    if not project:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Project {project_id} not found or doesn't belong to you",
        )
    return project
