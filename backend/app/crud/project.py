import uuid
from datetime import datetime
from app.db.connection import get_database
from app.models.project import ProjectCreate, ProjectUpdate, ProjectResponse


async def calculate_progress(db, task_ids: list) -> float:
    if not task_ids:
        return 0.0
    cursor = db["tasks"].find({"id": {"$in": task_ids}})
    tasks = await cursor.to_list(length=None)
    if not tasks:
        return 0.0
    completed = sum(1 for t in tasks if t.get("status") == "completed")
    return round((completed / len(tasks)) * 100, 1)


async def build_project_response(db, project: dict) -> ProjectResponse:
    project.pop("_id", None)
    progress = await calculate_progress(db, project.get("task_ids", []))
    return ProjectResponse(**project, progress=progress)


async def create_project(project_data: ProjectCreate, user_id: str) -> ProjectResponse:
    db = get_database()
    project_dict = {
        "id": str(uuid.uuid4()),
        "user_id": user_id,
        "title": project_data.title,
        "description": project_data.description,
        "category": project_data.category,
        "task_ids": project_data.task_ids,
        "status": "active",
        "due_date": project_data.due_date,
        "priority": project_data.priority or "medium",
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow(),
    }
    await db["projects"].insert_one(project_dict)
    project_dict.pop("_id", None)
    return ProjectResponse(**project_dict, progress=0.0)


async def get_projects(user_id: str) -> list[ProjectResponse]:
    db = get_database()
    cursor = db["projects"].find({"user_id": user_id})
    projects = await cursor.to_list(length=100)
    result = []
    for p in projects:
        result.append(await build_project_response(db, p))
    return result


async def get_project_by_id(project_id: str, user_id: str) -> ProjectResponse | None:
    db = get_database()
    project = await db["projects"].find_one({"id": project_id, "user_id": user_id})
    if not project:
        return None
    return await build_project_response(db, project)


async def update_project(project_id: str, user_id: str, update_data: ProjectUpdate) -> ProjectResponse | None:
    db = get_database()
    update_fields = {}
    if update_data.title is not None:
        update_fields["title"] = update_data.title
    if update_data.description is not None:
        update_fields["description"] = update_data.description
    if update_data.category is not None:
        update_fields["category"] = update_data.category
    if update_data.status is not None:
        update_fields["status"] = update_data.status
    if update_data.due_date is not None:
        update_fields["due_date"] = update_data.due_date
    if update_data.priority is not None:
        update_fields["priority"] = update_data.priority
    if update_data.task_ids is not None:
        update_fields["task_ids"] = update_data.task_ids
    update_fields["updated_at"] = datetime.utcnow()

    result = await db["projects"].update_one(
        {"id": project_id, "user_id": user_id},
        {"$set": update_fields},
    )
    if result.matched_count == 0:
        return None
    return await get_project_by_id(project_id, user_id)


async def delete_project(project_id: str, user_id: str) -> bool:
    db = get_database()
    result = await db["projects"].delete_one({"id": project_id, "user_id": user_id})
    return result.deleted_count == 1


async def add_task_to_project(project_id: str, user_id: str, task_id: str) -> ProjectResponse | None:
    db = get_database()
    result = await db["projects"].update_one(
        {"id": project_id, "user_id": user_id},
        {
            "$addToSet": {"task_ids": task_id},
            "$set": {"updated_at": datetime.utcnow()},
        },
    )
    if result.matched_count == 0:
        return None
    return await get_project_by_id(project_id, user_id)
