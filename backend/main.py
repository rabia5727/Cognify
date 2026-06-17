from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from app.db.connection import connect_db, close_db
from app.routes import auth, users, task, project, notification, analytics, classroom  # MERGED: both routers
from app.crud.notification import setup_indexes
from app.crud.analytics import setup_indexes as setup_analytics_indexes 
from app.schedular import start_notification_scheduler, stop_notification_scheduler
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from app.limiter import limiter

@asynccontextmanager
async def lifespan(app: FastAPI):
    await connect_db()
    await setup_indexes()
    await setup_analytics_indexes()
    start_notification_scheduler()
    yield
    await close_db()    
    stop_notification_scheduler()


app = FastAPI(
    title="Cognify API",
    description="AI Powered Execution Hub for Productive Workflow Balance",
    version="1.0.0",
    lifespan=lifespan
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(task.router)
app.include_router(project.router)
app.include_router(notification.router)
app.include_router(analytics.router)   # YOUR branch
app.include_router(classroom.router)   # TEAMMATE's branch


@app.get("/")
async def root():
    return {"message": "Cognify API is running 🚀"}