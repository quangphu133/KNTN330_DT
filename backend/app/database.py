import os
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import declarative_base, sessionmaker

# Always load backend/.env regardless of where the server is launched from.
ENV_PATH = Path(__file__).resolve().parents[1] / ".env"
load_dotenv(dotenv_path=ENV_PATH)

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "mysql+pymysql://root@localhost/employee_tasks",
)

engine = create_engine(DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def ensure_schema():
    inspector = inspect(engine)
    table_names = inspector.get_table_names()

    if "users" in table_names:
        column_names = {column["name"] for column in inspector.get_columns("users")}
        if "is_admin" not in column_names:
            with engine.begin() as connection:
                connection.execute(
                    text(
                        "ALTER TABLE users "
                        "ADD COLUMN is_admin BOOLEAN NOT NULL DEFAULT FALSE"
                    )
                )
