# Render Deployment Guide

This document covers the production deployment flow for NexTask on Render.

## What this repo already includes

- `render.yaml` for the FastAPI web service
- built React admin dashboard served by FastAPI at `/admin/`
- Render-ready backend env templates:
  - `backend/.env.example`
  - `backend/.env.render.example`
- pinned Python version with `.python-version`
- health endpoint at `/health`

## Important architecture note

The current `render.yaml` deploys the API service from this repository.

MySQL on Render is a separate private service with persistent disk storage. It is not provisioned by the current repo's `render.yaml`.

Official Render docs used for this setup:

- FastAPI deploy guide: https://render.com/docs/deploy-fastapi
- Health checks: https://render.com/docs/health-checks
- Python version pinning: https://render.com/docs/python-version
- MySQL deploy guide: https://render.com/docs/deploy-mysql

## Step 1: Push this repo to GitHub

Render will deploy from GitHub, so the latest local changes need to be pushed first.

## Step 2: Create MySQL on Render

Render's official MySQL setup is a separate private service based on their MySQL template.

Recommended values:

- Service type: `Private Service`
- Language: `Docker`
- MySQL version: `8`
- Service name: `nextask-mysql`
- Disk mount path: `/var/lib/mysql`
- Disk size: `10 GB` or higher

Set these MySQL environment variables when creating that service:

- `MYSQL_DATABASE=employee_tasks`
- `MYSQL_USER=nextask`
- `MYSQL_PASSWORD=<strong password>`
- `MYSQL_ROOT_PASSWORD=<strong root password>`

After deployment, the internal host should be:

- `nextask-mysql:3306`

If you use a different service name, update the database host in `DATABASE_URL`.

## Step 3: Create the API web service from this repo

In Render:

1. Click `New > Blueprint` or `New > Web Service`
2. Select this GitHub repository
3. Use the existing `render.yaml`

The web service is configured to:

- install Python requirements
- run `uvicorn`
- expose `/health` as the Render health check
- serve the admin dashboard at `/admin/`

## Step 4: Set API environment variables

Use `backend/.env.render.example` as the source of truth.

Required production values:

- `DATABASE_URL`
- `SECRET_KEY`
- `ALGORITHM`
- `ACCESS_TOKEN_EXPIRE_MINUTES`
- `ADMIN_NAME`
- `ADMIN_EMAIL`
- `ADMIN_PASSWORD`
- `CORS_ORIGINS`

Recommended production `DATABASE_URL`:

```text
mysql+pymysql://nextask:<db-password>@nextask-mysql:3306/employee_tasks
```

Recommended production `CORS_ORIGINS`:

```text
https://your-api-service.onrender.com
```

If you later add a custom domain, update `CORS_ORIGINS` to that domain as well.

## Step 5: Verify deployment

After the Render deploy completes, verify:

- root API:
  - `https://your-api-service.onrender.com/`
- health check:
  - `https://your-api-service.onrender.com/health`
- Swagger docs:
  - `https://your-api-service.onrender.com/docs`
- admin dashboard:
  - `https://your-api-service.onrender.com/admin/`

## Step 6: Verify admin login

Use the production admin credentials you set in Render:

- `ADMIN_EMAIL`
- `ADMIN_PASSWORD`

Do not reuse the local demo admin password in production.

## Step 7: Build Flutter against the live API

Once the API is live, build Flutter with the deployed URL:

```bash
flutter run --dart-define=API_BASE_URL=https://your-api-service.onrender.com
```

For the final APK:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://your-api-service.onrender.com
```

## Production notes

- `ACCESS_TOKEN_EXPIRE_MINUTES=10080` is recommended here because the app currently uses a single JWT without refresh tokens. This gives a 7-day session and avoids logging mobile users out too aggressively.
- `/health` performs a real database connectivity check, which aligns better with Render health checks than a plain TCP probe.
- The admin dashboard is served by the same FastAPI service, so it stays on the same origin as the API in production.
