# Ikrili API

Small FastAPI service backed by SQLite. The database is created at
`backend/ikrili.db` on startup, or at the path supplied by
`IKRILI_DATABASE_PATH`.

From the `backend` directory:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --reload
```

The API exposes `/health`, `/users`, `/cars`, `/reservations`, owner pickup
location/GPS endpoints under `/owners/me/location/*`, and the renter discovery
endpoint `/owners/nearby`. Nearby results use Haversine distance, exclude
blocked owners, group cars per owner, and filter date-overlapping reservations.
Interactive documentation is available at `/docs`.

## Authentication

Use `/auth/register` or `/auth/login` to receive a short-lived JWT access token
and a rotating refresh token. Send the access token as
`Authorization: Bearer <token>`. Refresh tokens are stored hashed, rotated on
use, and revoked on logout or password reset. Set `IKRILI_JWT_SECRET` to a long,
random secret in every deployed environment; the built-in value is only for
local development.

Roles are `car_renter`, `car_owner`, and `admin`. Owner location routes require
an authenticated owner token. Password recovery uses one-time, expiring reset
tokens; production delivery should be connected to an email provider.

For the current development client, owner-only location endpoints identify the
owner with the `X-User-Id` header. Replace this with the app's authenticated
token/session middleware before production deployment.

## Docker Compose

From the project root:

```powershell
docker compose up --build
```

The API is available at `http://localhost:8000`, with documentation at
`http://localhost:8000/docs`. SQLite is persisted in the named Docker volume
`ikrili-sqlite-data` and is mounted at `/data` inside the container.
