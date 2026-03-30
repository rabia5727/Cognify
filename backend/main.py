from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from app.db.connection import connect_db, close_db
from app.routes import auth, users, task, workflow

@asynccontextmanager
async def lifespan(app: FastAPI):
    await connect_db()
    yield
    await close_db()

app = FastAPI(
    title="Cognify API",
    description="AI Powered Execution Hub for Productive Workflow Balance",
    version="1.0.0",
    lifespan=lifespan
)

# ✅ Fix CORS — allows Flutter web and mobile to connect
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
app.include_router(workflow.router)

@app.get("/")
async def root():
    return {"message": "Cognify API is running 🚀"}