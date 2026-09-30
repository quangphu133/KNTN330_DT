import os
from pathlib import Path

from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text

from app.database import Base, SessionLocal, engine, ensure_schema
from app.routes.admin import router as admin_router
from app.routes.auth import router as auth_router
from app.routes.task import router as task_router
from app.services.auth_service import ensure_admin_user

# Import models so SQLAlchemy registers tables before create_all.
from app.models import task, user  # noqa: F401

app = FastAPI(title="NexTask API")
ADMIN_DIST_DIR = Path(__file__).resolve().parents[2] / "admin" / "dist"
DEFAULT_CORS_ORIGINS = [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    "http://localhost:8000",
    "http://127.0.0.1:8000",
    "http://localhost:8001",
    "http://127.0.0.1:8001",
]


def get_cors_origins() -> list[str]:
    raw_origins = os.getenv("CORS_ORIGINS", "").strip()
    if not raw_origins:
        return DEFAULT_CORS_ORIGINS

    if raw_origins == "*":
        return ["*"]

    return [origin.strip() for origin in raw_origins.split(",") if origin.strip()]


cors_origins = get_cors_origins()
allow_credentials = cors_origins != ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=allow_credentials,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def on_startup():
    Base.metadata.create_all(bind=engine)
    ensure_schema()
    seed_admin_user()


def seed_admin_user():
    admin_email = os.getenv("ADMIN_EMAIL")
    admin_password = os.getenv("ADMIN_PASSWORD")
    admin_name = os.getenv("ADMIN_NAME", "NexTask Admin")

    if not admin_email or not admin_password:
        return

    db = SessionLocal()
    try:
        ensure_admin_user(
            db,
            name=admin_name,
            email=admin_email,
            password=admin_password,
        )
    finally:
        db.close()


@app.get("/")
def health_check():
    return {"message": "NexTask API is running"}


@app.get("/health")
def readiness_check():
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database connectivity check failed",
        ) from exc

    return {
        "status": "ok",
        "database": "reachable",
        "admin_dashboard": ADMIN_DIST_DIR.exists(),
    }


app.include_router(auth_router, prefix="/auth", tags=["Authentication"])
app.include_router(task_router, prefix="/tasks", tags=["Tasks"])
app.include_router(admin_router, prefix="/admin-api", tags=["Admin"])

if ADMIN_DIST_DIR.exists():
    app.mount("/admin", StaticFiles(directory=ADMIN_DIST_DIR, html=True), name="admin")
