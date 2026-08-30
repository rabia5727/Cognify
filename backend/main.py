import os
import sys

# Windows consoles default to cp1252, which can't encode the emoji used in
# debug print()s across the app (classroom sync, gmail, scheduler, etc).
# An uncaught UnicodeEncodeError from a stray print() crashes the request
# it's in, so force UTF-8 stdout/stderr with a safe fallback.
if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

# All our OAuth flows (classroom/gmail/drive) request with
# include_granted_scopes='true', so Google can legitimately return a
# *broader* scope list than what was requested if the account already
# granted more scopes to this client earlier (e.g. via Connect All).
# google-auth-oauthlib treats that as a hard error by default and raises
# during fetch_token() — this is Google's own documented workaround so a
# reconnect doesn't 400 just because the account has more history than
# this one request asked for.
os.environ.setdefault("OAUTHLIB_RELAX_TOKEN_SCOPE", "1")

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from app.db.connection import connect_db, close_db
from app.routes import auth, users, task, project, notification, analytics, classroom, voice , assistant,drive, connect_all
from app.crud.notification import setup_indexes
from app.crud.analytics import setup_indexes as setup_analytics_indexes
from app.crud.password_reset import setup_indexes as setup_password_reset_indexes
from app.crud.sync_dismissals import setup_indexes as setup_sync_dismissal_indexes
from app.schedular import start_notification_scheduler, stop_notification_scheduler
from app.routes.documents import router as documents_router
from app.routes.emails import router as emails_router
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from app.limiter import limiter
from app.routes import gmail


@asynccontextmanager
async def lifespan(app: FastAPI):
    await connect_db()
    await setup_indexes()
    await setup_analytics_indexes()
    await setup_password_reset_indexes()
    await setup_sync_dismissal_indexes()
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
app.include_router(analytics.router)
app.include_router(classroom.router)
app.include_router(voice.router)
app.include_router(assistant.router)
app.include_router(gmail.router)
app.include_router(drive.router)
app.include_router(connect_all.router)
app.include_router(documents_router)
app.include_router(emails_router)

@app.get("/")
async def root():
    return {"message": "Cognify API is running 🚀"}