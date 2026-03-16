# All database operations for Workflow module
# USER ACTION → API ROUTE → CRUD FUNCTION → DATABASE → RESPONSE BACK

import uuid
from datetime import datetime
from app.db.connection import get_database
from app.models.workflow import WorkflowCreate, WorkflowUpdate, WorkflowResponse, MilestoneCreate, Milestone


# Helper function to calculate progress percentage
def calculate_progress(milestones: list) -> float:
    # If no milestones, progress is 0
    if not milestones:
        return 0.0
    # Count completed milestones
    completed = sum(1 for m in milestones if m.get("completed", False))
    # Return percentage
    return round((completed / len(milestones)) * 100, 1)


# Helper to build WorkflowResponse from database document
def build_workflow_response(workflow: dict) -> WorkflowResponse:
    # Remove MongoDB _id
    workflow.pop("_id", None)
    # Calculate progress from milestones
    progress = calculate_progress(workflow.get("milestones", []))
    return WorkflowResponse(**workflow, progress=progress)


# CREATE a new workflow
async def create_workflow(workflow_data: WorkflowCreate, user_id: str) -> WorkflowResponse:

    # Step 1: Get database connection
    db = get_database()

    # Step 2: Build workflow document
    workflow_dict = {
        "id": str(uuid.uuid4()),               # unique ID
        "user_id": user_id,                    # owner (from JWT)
        "title": workflow_data.title,
        "description": workflow_data.description,
        "category": workflow_data.category,
        "task_ids": [],                        # no tasks linked yet
        "milestones": [],                      # no milestones yet
        "status": "active",
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow()
    }

    # Step 3: Save to MongoDB
    await db["workflows"].insert_one(workflow_dict)

    # Step 4: Remove _id and return response
    workflow_dict.pop("_id", None)
    return WorkflowResponse(**workflow_dict, progress=0.0)


# GET all workflows for a user
async def get_workflows(user_id: str) -> list[WorkflowResponse]:

    # Step 1: Get database connection
    db = get_database()

    # Step 2: Find all workflows for this user
    cursor = db["workflows"].find({"user_id": user_id})
    workflows = await cursor.to_list(length=100)

    # Step 3: Build response for each workflow
    return [build_workflow_response(w) for w in workflows]


# GET a single workflow by ID
async def get_workflow_by_id(workflow_id: str, user_id: str) -> WorkflowResponse | None:

    # Step 1: Get database connection
    db = get_database()

    # Step 2: Find workflow by id AND user_id (security check)
    workflow = await db["workflows"].find_one({
        "id": workflow_id,
        "user_id": user_id
    })

    # Step 3: Return None if not found
    if not workflow:
        return None

    return build_workflow_response(workflow)


# UPDATE a workflow
async def update_workflow(workflow_id: str, user_id: str, update_data: WorkflowUpdate) -> WorkflowResponse | None:

    # Step 1: Get database connection
    db = get_database()

    # Step 2: Build update fields
    update_fields = {}
    if update_data.title is not None:
        update_fields["title"] = update_data.title
    if update_data.description is not None:
        update_fields["description"] = update_data.description
    if update_data.category is not None:
        update_fields["category"] = update_data.category
    if update_data.status is not None:
        update_fields["status"] = update_data.status

    # Always update timestamp
    update_fields["updated_at"] = datetime.utcnow()

    # Step 3: Perform update
    result = await db["workflows"].update_one(
        {"id": workflow_id, "user_id": user_id},
        {"$set": update_fields}
    )

    # Step 4: Return None if not found
    if result.matched_count == 0:
        return None

    return await get_workflow_by_id(workflow_id, user_id)


# DELETE a workflow
async def delete_workflow(workflow_id: str, user_id: str) -> bool:

    db = get_database()
    result = await db["workflows"].delete_one({
        "id": workflow_id,
        "user_id": user_id
    })
    return result.deleted_count == 1


# ADD a task to a workflow
async def add_task_to_workflow(workflow_id: str, user_id: str, task_id: str) -> WorkflowResponse | None:

    db = get_database()

    # $addToSet adds task_id only if it doesn't already exist (no duplicates)
    result = await db["workflows"].update_one(
        {"id": workflow_id, "user_id": user_id},
        {
            "$addToSet": {"task_ids": task_id},
            "$set": {"updated_at": datetime.utcnow()}
        }
    )

    if result.matched_count == 0:
        return None

    return await get_workflow_by_id(workflow_id, user_id)


# ADD a milestone to a workflow
async def add_milestone(workflow_id: str, user_id: str, milestone_data: MilestoneCreate) -> WorkflowResponse | None:

    db = get_database()

    # Build milestone document
    milestone = {
        "id": str(uuid.uuid4()),
        "title": milestone_data.title,
        "due_date": milestone_data.due_date,
        "completed": False,
        "completed_at": None
    }

    # $push adds milestone to the milestones array
    result = await db["workflows"].update_one(
        {"id": workflow_id, "user_id": user_id},
        {
            "$push": {"milestones": milestone},
            "$set": {"updated_at": datetime.utcnow()}
        }
    )

    if result.matched_count == 0:
        return None

    return await get_workflow_by_id(workflow_id, user_id)


# COMPLETE a milestone
async def complete_milestone(workflow_id: str, user_id: str, milestone_id: str) -> WorkflowResponse | None:

    db = get_database()

    # Update the specific milestone inside the milestones array
    # $ is the positional operator - updates the matched element
    result = await db["workflows"].update_one(
        {
            "id": workflow_id,
            "user_id": user_id,
            "milestones.id": milestone_id      # find the specific milestone
        },
        {
            "$set": {
                "milestones.$.completed": True,                      # mark complete
                "milestones.$.completed_at": datetime.utcnow(),      # set completion time
                "updated_at": datetime.utcnow()
            }
        }
    )

    if result.matched_count == 0:
        return None

    return await get_workflow_by_id(workflow_id, user_id)