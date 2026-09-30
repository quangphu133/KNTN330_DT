# NexTask Backend Setup Log

This file documents each backend setup step requested so far and the fixes applied.

## Step 1 - FastAPI dependencies

Requested:
- Install `fastapi uvicorn sqlalchemy pymysql python-jose passlib bcrypt python-dotenv`

Executed:
- `python3 -m pip install fastapi uvicorn sqlalchemy pymysql python-jose passlib bcrypt python-dotenv`

Result:
- Dependencies installed successfully in user site-packages.

Notes:
- `pip` command was unavailable, so `python3 -m pip` was used.
- Initial sandbox network restriction was resolved by running install with elevated permissions.

## Step 2 - MySQL setup

Requested:
- `CREATE DATABASE employee_tasks;`

Executed:
- Installed MySQL via Homebrew.
- Started service: `brew services start mysql`
- Created DB: `mysql -u root -e "CREATE DATABASE employee_tasks;"`
- Verified: `mysql -u root -e "SHOW DATABASES LIKE 'employee_tasks';"`

Result:
- Database `employee_tasks` exists.

## Step 3 - User model

Requested fields:
- `id`
- `name`
- `email`
- `hashed_password`

Implemented in:
- `app/models/user.py`

## Step 4 - Task model

Requested fields:
- `id`
- `title`
- `description`
- `priority`
- `due_date`
- `status`
- `user_id`

Relationship requested:
- One user -> many tasks

Implemented in:
- `app/models/task.py`
- Relationship wiring:
  - `User.tasks`
  - `Task.user`

## Step 5 - JWT authentication

Requested:
- Password hashing
- Token generation
- Protected routes
- Use `bcrypt` and `python-jose`

Implemented:
- Password hashing and verification in `app/utils/security.py`
- JWT generation and decode in `app/utils/security.py`
- Register, login, and protected current-user endpoint in `app/routes/auth.py`
- Auth service logic in `app/services/auth_service.py`
- Router registration and startup table creation in `app/main.py`

API routes:
- `POST /auth/register`
- `POST /auth/login`
- `GET /auth/me` (protected, requires bearer token)

## Step 12 - Task schemas

Implemented in:
- `app/schemas/task.py`

Schemas:
- `TaskCreate`
- `TaskUpdate`
- `TaskResponse`

## Step 13 - Security

Implemented in:
- `app/utils/security.py`

Functions:
- `hash_password()`
- `verify_password()`
- `create_access_token()`
- `verify_token()`
- `get_current_user()`

## Step 14 - Auth service

Implemented in:
- `app/services/auth_service.py`

Functions:
- `register_user()`
- `login_user()`

## Step 15 - Task service

Implemented in:
- `app/services/task_service.py`

Functions:
- `create_task()`
- `get_tasks()`
- `update_task()`
- `delete_task()`

Features:
- search
- status filter

## Step 16 - Auth routes

Implemented in:
- `app/routes/auth.py`

Endpoints:
- `POST /auth/register`
- `POST /auth/login`

## Step 17 - Task routes

Implemented in:
- `app/routes/task.py`

Endpoints:
- `GET /tasks`
- `POST /tasks`
- `PUT /tasks/{task_id}`
- `DELETE /tasks/{task_id}`

Protection:
- All task routes use `Depends(get_current_user)`

## Step 18 - main.py configuration

Implemented in:
- `app/main.py`

Includes:
- FastAPI app
- auth and task routers
- CORS middleware
- table creation on startup

## Problems fixed

1. Missing written documentation
- Added this setup log.

2. `passlib` missing in requirements file
- Added `passlib` to `backend/requirements.txt`.

3. `.env` loading could fail from different launch directories
- Updated `app/database.py` to load `backend/.env` using an absolute path from the file location.

4. Runtime error: missing `users` table
- Initialized tables in `employee_tasks` from SQLAlchemy models.
- Verified auth endpoints after initialization.

5. Python 3.9 compatibility issue in new task modules
- Replaced `| None` type hints with `Optional[...]`.

6. Live server used wrong Python environment with plain `uvicorn`
- Verified the working command is `python3 -m uvicorn app.main:app --reload`.

## Current backend files added for auth

- `app/schemas/auth.py`
- `app/services/auth_service.py`
- `app/routes/auth.py`
- `app/utils/security.py`
- Package `__init__.py` files in `app/routes`, `app/schemas`, `app/services`, `app/utils`

## Run backend locally

From `backend/`:

```bash
python3 -m uvicorn app.main:app --reload

# Optional: initialize tables manually once
python3 -c "from app.database import Base, engine; from app.models import User, Task; Base.metadata.create_all(bind=engine)"
```

## Backend checklist verification

Verified:
- Register works
- Login works
- JWT token generated
- Protected routes work
- CRUD tasks work
- Search works
- Filter works
- MySQL connected
- Swagger docs working

## Bonus admin dashboard support

Added:
- `is_admin` role on users
- Admin-only dependency guard
- Admin APIs for:
- viewing all users
- viewing all tasks
- updating task status
- deleting tasks
- deleting users

Admin API prefix:
- `/admin-api`

Key endpoints:
- `GET /admin-api/summary`
- `GET /admin-api/users`
- `DELETE /admin-api/users/{user_id}`
- `GET /admin-api/tasks`
- `PATCH /admin-api/tasks/{task_id}/status`
- `DELETE /admin-api/tasks/{task_id}`

## Render production prep

Added for deployment readiness:
- `/health` endpoint with database connectivity check
- configurable `CORS_ORIGINS`
- production env template in `backend/.env.render.example`
- pinned Python version in repo root `.python-version`

Deployment guide:
- `RENDER_DEPLOYMENT.md`
