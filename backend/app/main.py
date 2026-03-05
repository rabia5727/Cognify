from fastapi import FastAPI
from contextlib import asynccontextmanager
from app.db.connection import connect_db, close_db
from app.routes import auth

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

app.include_router(auth.router)

@app.get("/")
async def root():
    return {"message": "Cognify API is running 🚀"}
