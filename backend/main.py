from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from app.db.connection import connect_db, close_db
from app.routes import auth, users, task, project, notification, classroom
from app.crud.notification import setup_indexes
from app.schedular import start_notification_scheduler, stop_notification_scheduler

@asynccontextmanager
async def lifespan(app: FastAPI):
    await connect_db()
    await setup_indexes() 
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


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(task.router)
app.include_router(project.router)
app.include_router(notification.router)
app.include_router(classroom.router)
@app.get("/")
async def root():
    return {"message": "Cognify API is running 🚀"}