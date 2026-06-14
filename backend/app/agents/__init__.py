# app/agents/__init__.py
# Makes agents a proper Python package

from .task_agent import get_task_agent_tools
from .execution_agent import get_execution_agent_tools
from .scheduler_agent import get_scheduler_agent_tools
from .analytics_agent import get_analytics_agent_tools

__all__ = [
    "get_task_agent_tools",
    "get_execution_agent_tools", 
    "get_scheduler_agent_tools",
    "get_analytics_agent_tools",
]