# app/agents/task_agent.py
# Task Agent — tools for creating, reading, updating tasks and projects

from datetime import datetime, timezone, timedelta
from langchain_core.tools import tool
from app.db.connection import get_database
from app.models.task import TaskCreate
from app.crud.task import create_task, get_tasks, update_task


# ─────────────────────────────────────────────────────────────────
# Tool 1 — Create Task
# ─────────────────────────────────────────────────────────────────
def get_create_task_tool(user_id: str):
    @tool
    async def create_task_tool(
        title: str,
        due_date: str = "",
        priority: str = "medium",
        category: str = "general",
        description: str = "",
    ) -> str:
        """
        Create a new task for the user.
        Use when user says: 'add task', 'create task', 'remind me to',
        'I need to do', 'schedule task', 'add to my list'.
        
        Parameters:
        - title: task name (required)
        - due_date: 'today', 'tomorrow', 'next week', or 'YYYY-MM-DD'
        - priority: 'low', 'medium', or 'high'
        - category: 'academic', 'freelance', or 'general'
        - description: extra details
        """
        try:
            # Normalize empty strings to None
            due_date = due_date if due_date else None
            description = description if description else None
            
            # Parse due_date string to datetime
            parsed_due = None
            if due_date:
                due_lower = due_date.lower().strip()
                now = datetime.now(timezone.utc)
                if due_lower == "tomorrow":
                    parsed_due = (now + timedelta(days=1)).replace(hour=23, minute=59, second=0, microsecond=0)
                elif due_lower == "today":
                    parsed_due = now.replace(hour=23, minute=59, second=0, microsecond=0)
                elif due_lower == "next week":
                    parsed_due = (now + timedelta(days=7)).replace(hour=23, minute=59, second=0, microsecond=0)
                else:
                    try:
                        parsed_due = datetime.strptime(due_date, "%Y-%m-%d").replace(tzinfo=timezone.utc)
                    except:
                        parsed_due = None

            # Validate category
            valid_categories = {"academic", "freelance", "general", "email", "classroom"}
            if category not in valid_categories:
                category = "general"

            # Validate priority
            valid_priorities = {"low", "medium", "high"}
            if priority not in valid_priorities:
                priority = "medium"

            task_data = TaskCreate(
                title=title,
                description=description,
                priority=priority,
                category=category,
                due_date=parsed_due,
                source="manual",
            )

            task = await create_task(task_data, user_id)
            return f"✅ Task '{task.title}' created successfully!"

        except Exception as e:
            return f"Failed to create task: {str(e)}"

    return create_task_tool


# ─────────────────────────────────────────────────────────────────
# Tool 2 — Get Tasks
# ─────────────────────────────────────────────────────────────────
def get_tasks_tool(user_id: str):
    @tool
    async def get_user_tasks(limit: int = 10) -> str:
        """
        Get the user's tasks list.
        Use when user says: 'what are my tasks', 'show my tasks',
        'what do I have to do', 'list my tasks', 'my pending tasks',
        'show completed tasks', 'what tasks do I have'.
        """
        try:
            tasks = await get_tasks(
                user_id=user_id,
                limit=limit,
            )
            if not tasks:
                return "You have no tasks yet. Create one by saying 'add task...'"
            
            task_list = []
            for t in tasks:
                due = f", due {t.due_date.strftime('%b %d')}" if t.due_date else ""
                task_list.append(f"• {t.title} [{t.priority} priority{due}] — {t.status}")
            
            return f"You have {len(tasks)} task(s):\n" + "\n".join(task_list)
        except Exception as e:
            return f"Failed to get tasks: {str(e)}"
    return get_user_tasks


# ─────────────────────────────────────────────────────────────────
# Tool 3 — Check Deadlines
# ─────────────────────────────────────────────────────────────────
def get_check_deadlines_tool(user_id: str):
    @tool
    async def check_deadlines(hours_ahead: int = 24) -> str:
        """
        Check upcoming deadlines and overdue tasks.
        Use when user says: 'what's due today', 'any deadlines',
        'urgent tasks', 'what's overdue', 'upcoming deadlines',
        'what do I need to finish', 'tasks due soon'.
        """
        try:
            db = get_database()
            now = datetime.now(timezone.utc)
            future = now + timedelta(hours=hours_ahead)

            overdue_cursor = db["tasks"].find({
                "user_id": user_id,
                "status": {"$ne": "completed"},
                "due_date": {"$lt": now},
            })
            overdue = await overdue_cursor.to_list(length=20)

            upcoming_cursor = db["tasks"].find({
                "user_id": user_id,
                "status": {"$ne": "completed"},
                "due_date": {"$gte": now, "$lte": future},
            })
            upcoming = await upcoming_cursor.to_list(length=20)

            result = []
            if overdue:
                result.append(f"⚠️ OVERDUE ({len(overdue)} tasks):")
                for t in overdue:
                    result.append(f"  • {t['title']}")
            if upcoming:
                result.append(f"\n📅 DUE in next {hours_ahead}h ({len(upcoming)} tasks):")
                for t in upcoming:
                    due = t['due_date'].strftime('%b %d %H:%M') if t.get('due_date') else 'No date'
                    result.append(f"  • {t['title']} — {due}")
            if not overdue and not upcoming:
                return "No deadlines in the next 24 hours. You're all caught up! 🎉"
            return "\n".join(result)
        except Exception as e:
            return f"Failed to check deadlines: {str(e)}"
    return check_deadlines


# ─────────────────────────────────────────────────────────────────
# Tool 4 — Update Task Status
# ─────────────────────────────────────────────────────────────────
def get_update_task_tool(user_id: str):
    @tool
    async def update_task_status(task_title: str, status: str) -> str:
        """
        Update a task's status.
        Use when user says: 'mark task as done', 'complete task',
        'finish task', 'task is done', 'mark as completed',
        'start working on task', 'task in progress'.
        """
        try:
            # Normalize + validate status
            valid_statuses = {"pending", "in_progress", "completed"}
            status_normalized = status.lower().strip().replace("-", "_").replace(" ", "_")
            status_aliases = {
                "done": "completed",
                "finished": "completed",
                "complete": "completed",
                "started": "in_progress",
                "working": "in_progress",
                "todo": "pending",
                "in progress": "in_progress",
                "in-progress": "in_progress",
            }
            
            # ✅ FIX: Map the normalized status to the correct status value
            mapped_status = status_aliases.get(status_normalized, status_normalized)
            if mapped_status not in valid_statuses:
                return f"'{status}' isn't a recognized status. Use pending, in_progress, or completed."

            db = get_database()
            task = await db["tasks"].find_one({
                "user_id": user_id,
                "title": {"$regex": task_title, "$options": "i"},
                "status": {"$ne": "completed"},  # Don't update already completed tasks
            })
            if not task:
                return f"Could not find task matching '{task_title}'."

            from bson import ObjectId
            from app.models.task import TaskUpdate
            
            # ✅ FIX: Use mapped_status instead of the original status
            update_data = TaskUpdate(status=mapped_status)
            await update_task(ObjectId(task["_id"]), user_id, update_data)
            return f"✅ Task '{task['title']}' marked as {mapped_status}."
            
        except Exception as e:
            return f"Failed to update task: {str(e)}"
    return update_task_status

# ─────────────────────────────────────────────────────────────────
# Tool 5 — Get Projects
# ─────────────────────────────────────────────────────────────────
def get_projects_tool(user_id: str):
    @tool
    async def get_user_projects() -> str:
        """
        Get the user's projects.
        Use when user says: 'show my projects', 'what projects do I have',
        'list projects', 'my ongoing projects'.
        """
        try:
            db = get_database()
            projects = await db["projects"].find({"user_id": user_id}).to_list(length=20)
            if not projects:
                return "You have no projects yet."
            project_list = []
            for p in projects:
                task_count = len(p.get("task_ids", []))
                project_list.append(f"• {p['title']} [{p.get('status', 'active')}] — {task_count} tasks")
            return f"Your projects ({len(projects)}):\n" + "\n".join(project_list)
        except Exception as e:
            return f"Failed to get projects: {str(e)}"
    return get_user_projects


# ─────────────────────────────────────────────────────────────────
# Export all Task Agent tools
# ─────────────────────────────────────────────────────────────────
def get_task_agent_tools(user_id: str) -> list:
    return [
        get_create_task_tool(user_id),
        get_tasks_tool(user_id),
        get_check_deadlines_tool(user_id),
        get_update_task_tool(user_id),
        get_projects_tool(user_id),
    ]