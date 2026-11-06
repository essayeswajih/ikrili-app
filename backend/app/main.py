from __future__ import annotations

import sqlite3
import math
import asyncio
import base64
import hashlib
import hmac
import json
import os
import secrets
from pathlib import Path
from datetime import datetime, timezone, timedelta
from uuid import uuid4
from contextlib import asynccontextmanager
from datetime import date

from fastapi import Depends, FastAPI, File, HTTPException, Query, UploadFile, status
from io import BytesIO
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from fastapi.staticfiles import StaticFiles

from .database import initialize_database, session
from .schemas import (
    Car,
    CarCreate,
    Notification,
    Coordinates,
    GpsSettingsUpdate,
    NearbyOwner,
    NearbyOwnersResponse,
    OwnerLocation,
    Reservation,
    ReservationCreate,
    ReservationStatusUpdate,
    User,
    UserCreate,
    RegisterRequest, LoginRequest, RefreshRequest, LogoutRequest,
    PasswordResetRequest, PasswordResetConfirm, TokenResponse,
    ReservationEvent,
    UnavailablePeriod, UnavailablePeriodCreate, CarImage,
    DeviceTokenRegistration, NotificationPreferences,
    ReviewCreate, Review, CoinTransaction, CoinSpendRequest, ModerationUpdate, BlockUserRequest,
)


@asynccontextmanager
async def lifespan(_: FastAPI):
    initialize_database()
    if os.getenv("IKRILI_ENV", "development") == "production" and JWT_SECRET == "dev-only-change-this-secret":
        raise RuntimeError("IKRILI_JWT_SECRET must be configured in production")
    task = asyncio.create_task(_expire_due_reservations_loop())
    try:
        yield
    finally:
        task.cancel()
        await asyncio.gather(task, return_exceptions=True)


app = FastAPI(title="Ikrili API", version="0.1.0", lifespan=lifespan)
EARTH_RADIUS_KM = 6371.0088
GPS_MAX_AGE_MINUTES = 30
MEDIA_ROOT = Path(os.getenv("IKRILI_MEDIA_PATH", Path(__file__).resolve().parents[1] / "media"))
MEDIA_ROOT.mkdir(parents=True, exist_ok=True)
app.mount("/media", StaticFiles(directory=MEDIA_ROOT), name="media")
JWT_SECRET = os.getenv("IKRILI_JWT_SECRET", "dev-only-change-this-secret")
ACCESS_TTL_SECONDS = 900
REFRESH_TTL_SECONDS = 60 * 60 * 24 * 30
bearer = HTTPBearer(auto_error=False)


def _password_hash(password: str) -> str:
    salt = secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 310_000)
    return f"pbkdf2_sha256$310000${salt.hex()}${digest.hex()}"


def _verify_password(password: str, encoded: str) -> bool:
    try:
        algorithm, rounds, salt, digest = encoded.split("$")
        actual = hashlib.pbkdf2_hmac("sha256", password.encode(), bytes.fromhex(salt), int(rounds)).hex()
        return algorithm == "pbkdf2_sha256" and hmac.compare_digest(actual, digest)
    except (ValueError, TypeError):
        return False


def _jwt(payload: dict[str, object], ttl: int) -> str:
    body = {**payload, "exp": int(datetime.now(timezone.utc).timestamp()) + ttl}
    enc = lambda value: base64.urlsafe_b64encode(json.dumps(value, separators=(",", ":")).encode()).rstrip(b"=").decode()
    header = enc({"alg": "HS256", "typ": "JWT"})
    content = f"{header}.{enc(body)}"
    signature = hmac.new(JWT_SECRET.encode(), content.encode(), hashlib.sha256).digest()
    return f"{content}.{base64.urlsafe_b64encode(signature).rstrip(b'=').decode()}"


def _decode_jwt(token: str) -> dict[str, object]:
    try:
        header, encoded, signature = token.split(".")
        content = f"{header}.{encoded}"
        expected = base64.urlsafe_b64encode(hmac.new(JWT_SECRET.encode(), content.encode(), hashlib.sha256).digest()).rstrip(b"=").decode()
        if not hmac.compare_digest(expected, signature):
            raise ValueError
        payload = json.loads(base64.urlsafe_b64decode(encoded + "=" * (-len(encoded) % 4)))
        if int(payload["exp"]) <= int(datetime.now(timezone.utc).timestamp()):
            raise ValueError
        return payload
    except (ValueError, KeyError, TypeError, json.JSONDecodeError):
        raise HTTPException(status_code=401, detail="Invalid or expired access token")


def current_user(credentials: HTTPAuthorizationCredentials | None = Depends(bearer)) -> sqlite3.Row:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(status_code=401, detail="Bearer access token required")
    payload = _decode_jwt(credentials.credentials)
    with session() as connection:
        user = connection.execute("SELECT * FROM users WHERE id = ?", (payload.get("sub"),)).fetchone()
    if user is None or user["is_blocked"]:
        raise HTTPException(status_code=403, detail="User is not allowed")
    return user


def require_roles(*roles: str):
    def dependency(user: sqlite3.Row = Depends(current_user)) -> sqlite3.Row:
        if user["role"] not in roles:
            raise HTTPException(status_code=403, detail="Insufficient permissions")
        return user
    return dependency


def _tokens(user: sqlite3.Row) -> TokenResponse:
    refresh = secrets.token_urlsafe(48)
    now = datetime.now(timezone.utc)
    with session() as connection:
        connection.execute("INSERT INTO refresh_tokens(token_id, user_id, token_hash, expires_at) VALUES (?, ?, ?, ?)",
                           (uuid4().hex, user["id"], hashlib.sha256(refresh.encode()).hexdigest(),
                            (now.timestamp() + REFRESH_TTL_SECONDS)))
    return TokenResponse(access_token=_jwt({"sub": user["id"], "role": user["role"], "type": "access"}, ACCESS_TTL_SECONDS),
                         refresh_token=refresh, expires_in=ACCESS_TTL_SECONDS, user=_user(user))


def _user(row: sqlite3.Row) -> User:
    return User(**dict(row))


def _car(row: sqlite3.Row) -> Car:
    values = dict(row)
    values["is_available"] = bool(values["is_available"])
    return Car(**values)


def _reservation(row: sqlite3.Row) -> Reservation:
    values = dict(row)
    values["start_date"] = date.fromisoformat(values["start_date"])
    values["end_date"] = date.fromisoformat(values["end_date"])
    return Reservation(**values)


def _notification(row: sqlite3.Row) -> Notification:
    values = dict(row)
    values["is_read"] = bool(values["is_read"])
    return Notification(**values)


def _insert_notification(
    connection: sqlite3.Connection,
    *,
    user_id: str,
    title: str,
    message: str,
    notification_type: str,
    reservation_id: str | None = None,
) -> None:
    preference = connection.execute("SELECT reservation_events, payment_events FROM notification_preferences WHERE user_id = ?", (user_id,)).fetchone()
    if preference is not None:
        if notification_type.startswith("reservation_") and not preference["reservation_events"]: return
        if notification_type.startswith("payment_") and not preference["payment_events"]: return
    dedupe_key = f"{user_id}:{notification_type}:{reservation_id or ''}"
    connection.execute(
        "INSERT INTO notifications(id, user_id, title, message, type, reservation_id, dedupe_key) VALUES (?, ?, ?, ?, ?, ?, ?) ON CONFLICT(dedupe_key) DO NOTHING",
        (f"notification-{uuid4().hex}", user_id, title, message, notification_type, reservation_id, dedupe_key),
    )
    row = connection.execute("SELECT id FROM notifications WHERE dedupe_key = ?", (dedupe_key,)).fetchone()
    if row:
        tokens = connection.execute("SELECT id FROM device_tokens WHERE user_id = ? AND is_active = 1", (user_id,)).fetchall()
        for token in tokens:
            connection.execute("INSERT OR IGNORE INTO notification_deliveries(id, notification_id, device_token_id, status, next_attempt_at) VALUES (?, ?, ?, 'pending', CURRENT_TIMESTAMP)", (uuid4().hex, row["id"], token["id"]))


def _record_event(connection: sqlite3.Connection, reservation_id: str, event_type: str, *, actor_id: str | None = None, from_status: str | None = None, to_status: str | None = None, metadata: str = "{}") -> None:
    connection.execute("INSERT INTO reservation_events(id, reservation_id, actor_id, event_type, from_status, to_status, metadata) VALUES (?, ?, ?, ?, ?, ?, ?)", (uuid4().hex, reservation_id, actor_id, event_type, from_status, to_status, metadata))


def _audit(connection: sqlite3.Connection, actor_id: str | None, action: str, entity_type: str, entity_id: str | None = None, metadata: str = "{}") -> None:
    connection.execute("INSERT INTO audit_logs(id, actor_id, action, entity_type, entity_id, metadata) VALUES (?, ?, ?, ?, ?, ?)", (uuid4().hex, actor_id, action, entity_type, entity_id, metadata))


def _award_coins(connection: sqlite3.Connection, user_id: str, amount: int, reason: str, reservation_id: str) -> None:
    exists = connection.execute("SELECT 1 FROM coin_transactions WHERE user_id=? AND reservation_id=? AND reason=?", (user_id, reservation_id, reason)).fetchone()
    if exists: return
    connection.execute("INSERT INTO coin_transactions(id, user_id, amount, reason, reservation_id) VALUES (?, ?, ?, ?, ?)", (uuid4().hex, user_id, amount, reason, reservation_id))
    connection.execute("UPDATE users SET coins = coins + ? WHERE id = ?", (amount, user_id))


async def _expire_due_reservations_loop() -> None:
    while True:
        try:
            _expire_due_reservations()
        except Exception:
            pass
        await asyncio.sleep(30)


def _expire_due_reservations() -> int:
    now = datetime.now(timezone.utc).isoformat()
    with session() as connection:
        rows = connection.execute("SELECT id, renter_id, status FROM reservations WHERE status IN ('pending', 'awaiting_payment') AND payment_deadline IS NOT NULL AND payment_deadline <= ?", (now,)).fetchall()
        for row in rows:
            connection.execute("UPDATE reservations SET status = 'expired' WHERE id = ? AND status IN ('pending', 'awaiting_payment')", (row["id"],))
            _record_event(connection, row["id"], "expired", from_status=row["status"], to_status="expired", metadata='{"reason":"payment_deadline"}')
            _insert_notification(connection, user_id=row["renter_id"], title="Reservation expired", message="The payment deadline expired.", notification_type="reservation_expired", reservation_id=row["id"])
    return len(rows)


def _require_owner(user_id: str | None, connection: sqlite3.Connection) -> sqlite3.Row:
    if not user_id:
        raise HTTPException(status_code=401, detail="X-User-Id is required")
    user = connection.execute(
        "SELECT id, role FROM users WHERE id = ?", (user_id,)
    ).fetchone()
    if user is None:
        raise HTTPException(status_code=401, detail="User not found")
    if user["role"] != "car_owner":
        raise HTTPException(status_code=403, detail="Owner role required")
    return user


def _effective_location(row: sqlite3.Row) -> tuple[float | None, float | None, str]:
    if row["gps_enabled"] and row["gps_latitude"] is not None and row["gps_updated_at"]:
        updated = datetime.fromisoformat(row["gps_updated_at"].replace("Z", "+00:00"))
        age_minutes = (datetime.now(timezone.utc) - updated.astimezone(timezone.utc)).total_seconds() / 60
        if age_minutes < GPS_MAX_AGE_MINUTES:
            return row["gps_latitude"], row["gps_longitude"], "gps"
    if row["fixed_latitude"] is not None:
        return row["fixed_latitude"], row["fixed_longitude"], "fixed"
    return None, None, "none"


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    lat_delta = math.radians(lat2 - lat1)
    lon_delta = math.radians(lon2 - lon1)
    a = math.sin(lat_delta / 2) ** 2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(lon_delta / 2) ** 2
    return EARTH_RADIUS_KM * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "database": "sqlite"}


@app.get("/health/ready")
def readiness() -> dict[str, str]:
    with session() as connection:
        connection.execute("SELECT 1").fetchone()
    return {"status": "ready", "database": "sqlite"}


@app.get("/metrics")
def metrics() -> str:
    with session() as connection:
        users = connection.execute("SELECT COUNT(*) FROM users").fetchone()[0]
        cars = connection.execute("SELECT COUNT(*) FROM cars").fetchone()[0]
        reservations = connection.execute("SELECT COUNT(*) FROM reservations").fetchone()[0]
    return "\n".join([
        "# TYPE ikrili_users_total gauge", f"ikrili_users_total {users}",
        "# TYPE ikrili_cars_total gauge", f"ikrili_cars_total {cars}",
        "# TYPE ikrili_reservations_total gauge", f"ikrili_reservations_total {reservations}",
    ]) + "\n"


def _location_response(row: sqlite3.Row) -> OwnerLocation:
    latitude, longitude, source = _effective_location(row)
    return OwnerLocation(
        owner_id=row["owner_id"], fixed_latitude=row["fixed_latitude"], fixed_longitude=row["fixed_longitude"],
        gps_latitude=row["gps_latitude"], gps_longitude=row["gps_longitude"], gps_enabled=bool(row["gps_enabled"]),
        gps_updated_at=row["gps_updated_at"], effective_latitude=latitude, effective_longitude=longitude,
        effective_source=source,
    )


@app.put("/owners/me/location/fixed", response_model=OwnerLocation)
def set_fixed_location(payload: Coordinates, owner: sqlite3.Row = Depends(require_roles("car_owner"))) -> OwnerLocation:
    now = datetime.now(timezone.utc).isoformat()
    with session() as connection:
        if isinstance(owner, str):  # compatibility for direct service-level tests
            owner = connection.execute("SELECT id, role FROM users WHERE id = ?", (owner,)).fetchone()
            if owner is None or owner["role"] != "car_owner":
                raise HTTPException(status_code=403, detail="Owner role required")
        connection.execute(
            "INSERT INTO owner_locations(owner_id, fixed_latitude, fixed_longitude, updated_at) VALUES (?, ?, ?, ?) "
            "ON CONFLICT(owner_id) DO UPDATE SET fixed_latitude=excluded.fixed_latitude, fixed_longitude=excluded.fixed_longitude, updated_at=excluded.updated_at",
            (owner["id"], payload.latitude, payload.longitude, now),
        )
        row = connection.execute("SELECT * FROM owner_locations WHERE owner_id = ?", (owner["id"],)).fetchone()
    return _location_response(row)


@app.post("/owners/me/location/gps", response_model=OwnerLocation)
def update_gps_location(payload: Coordinates, owner: sqlite3.Row = Depends(require_roles("car_owner"))) -> OwnerLocation:
    now = datetime.now(timezone.utc).isoformat()
    with session() as connection:
        enabled = connection.execute("SELECT gps_enabled FROM owner_locations WHERE owner_id = ?", (owner["id"],)).fetchone()
        if enabled is None or not enabled["gps_enabled"]:
            raise HTTPException(status_code=409, detail="GPS sharing is disabled")
        connection.execute(
            "INSERT INTO owner_locations(owner_id, gps_latitude, gps_longitude, gps_enabled, gps_updated_at, updated_at) VALUES (?, ?, ?, 1, ?, ?) "
            "ON CONFLICT(owner_id) DO UPDATE SET gps_latitude=excluded.gps_latitude, gps_longitude=excluded.gps_longitude, gps_updated_at=excluded.gps_updated_at, updated_at=excluded.updated_at",
            (owner["id"], payload.latitude, payload.longitude, now, now),
        )
        row = connection.execute("SELECT * FROM owner_locations WHERE owner_id = ?", (owner["id"],)).fetchone()
    return _location_response(row)


@app.patch("/owners/me/location/settings", response_model=OwnerLocation)
def set_gps_settings(payload: GpsSettingsUpdate, owner: sqlite3.Row = Depends(require_roles("car_owner"))) -> OwnerLocation:
    now = datetime.now(timezone.utc).isoformat()
    with session() as connection:
        connection.execute(
            "INSERT INTO owner_locations(owner_id, gps_enabled, updated_at) VALUES (?, ?, ?) "
            "ON CONFLICT(owner_id) DO UPDATE SET gps_enabled=excluded.gps_enabled, updated_at=excluded.updated_at",
            (owner["id"], int(payload.enabled), now),
        )
        row = connection.execute("SELECT * FROM owner_locations WHERE owner_id = ?", (owner["id"],)).fetchone()
    return _location_response(row)


@app.get("/owners/me/location", response_model=OwnerLocation)
def get_my_location(owner: sqlite3.Row = Depends(require_roles("car_owner"))) -> OwnerLocation:
    with session() as connection:
        row = connection.execute("SELECT * FROM owner_locations WHERE owner_id = ?", (owner["id"],)).fetchone()
    if row is None:
        return OwnerLocation(owner_id=owner["id"], gps_enabled=False, effective_source="none")
    return _location_response(row)


@app.get("/owners/nearby", response_model=NearbyOwnersResponse)
def nearby_owners(
    latitude: float = Query(..., ge=-90, le=90), longitude: float = Query(..., ge=-180, le=180),
    radius_km: float = Query(5, ge=1, le=100), start_date: date | None = None,
    end_date: date | None = None, limit: int = Query(50, ge=1, le=200), offset: int = Query(0, ge=0),
) -> NearbyOwnersResponse:
    if (start_date is None) != (end_date is None):
        raise HTTPException(status_code=422, detail="start_date and end_date must be provided together")
    if start_date and end_date and end_date < start_date:
        raise HTTPException(status_code=422, detail="end_date must be on or after start_date")
    with session() as connection:
        owners = connection.execute(
            "SELECT u.id, u.name, u.image, u.rating, ol.* FROM users u JOIN owner_locations ol ON ol.owner_id = u.id "
            "WHERE u.role = 'car_owner' AND u.is_blocked = 0"
        ).fetchall()
        results: list[NearbyOwner] = []
        for owner in owners:
            owner_lat, owner_lon, source = _effective_location(owner)
            if source == "none":
                continue
            distance = _haversine_km(latitude, longitude, owner_lat, owner_lon)
            if distance > radius_km:
                continue
            cars = connection.execute(
                "SELECT c.price, c.currency FROM cars c WHERE c.owner_id = ? AND c.is_available = 1 AND c.approval_status = 'approved' "
                "AND NOT EXISTS (SELECT 1 FROM reservations r WHERE r.car_id = c.id AND r.status IN ('approved', 'active') "
                "AND (? IS NULL OR (r.start_date <= ? AND r.end_date >= ?))) "
                "AND NOT EXISTS (SELECT 1 FROM unavailable_periods u WHERE u.car_id = c.id AND (? IS NULL OR (u.start_date <= ? AND u.end_date >= ?)))",
                (owner["id"], end_date.isoformat() if end_date else None, end_date.isoformat() if end_date else None, start_date.isoformat() if start_date else None, end_date.isoformat() if end_date else None, end_date.isoformat() if end_date else None, start_date.isoformat() if start_date else None),
            ).fetchall()
            if not cars:
                continue
            currency = cars[0]["currency"]
            same_currency = [car for car in cars if car["currency"] == currency]
            results.append(NearbyOwner(
                owner_id=owner["id"], name=owner["name"], latitude=owner_lat, longitude=owner_lon,
                distance_km=round(distance, 2), lowest_price_per_day=min(car["price"] for car in same_currency),
                currency=currency, available_cars_count=len(cars), profile_image=owner["image"], rating=owner["rating"],
            ))
    results.sort(key=lambda item: item.distance_km)
    return NearbyOwnersResponse(radius_km=radius_km, total=len(results), owners=results[offset:offset + limit])


@app.post("/auth/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register(payload: RegisterRequest) -> TokenResponse:
    with session() as connection:
        try:
            row = connection.execute(
                "INSERT INTO users(id, name, email, role, password_hash) VALUES (?, ?, ?, ?, ?) "
                "RETURNING id, name, email, role, image, rating, created_at",
                (payload.id, payload.name.strip(), payload.email.strip().lower(), payload.role, _password_hash(payload.password)),
            ).fetchone()
        except sqlite3.IntegrityError as error:
            raise HTTPException(status_code=409, detail="Email or user id already exists") from error
    return _tokens(row)


@app.post("/auth/login", response_model=TokenResponse)
def login(payload: LoginRequest) -> TokenResponse:
    with session() as connection:
        row = connection.execute("SELECT * FROM users WHERE email = ?", (payload.email.strip().lower(),)).fetchone()
    if row is None or row["is_blocked"] or not _verify_password(payload.password, row["password_hash"]):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    return _tokens(row)


@app.post("/auth/refresh", response_model=TokenResponse)
def refresh(payload: RefreshRequest) -> TokenResponse:
    token_hash = hashlib.sha256(payload.refresh_token.encode()).hexdigest()
    with session() as connection:
        row = connection.execute("SELECT u.* FROM refresh_tokens r JOIN users u ON u.id = r.user_id WHERE r.token_hash = ? AND r.revoked_at IS NULL AND r.expires_at > ?", (token_hash, datetime.now(timezone.utc).timestamp())).fetchone()
        if row is None:
            raise HTTPException(status_code=401, detail="Invalid refresh token")
        connection.execute("UPDATE refresh_tokens SET revoked_at = ? WHERE token_hash = ?", (datetime.now(timezone.utc).isoformat(), token_hash))
    return _tokens(row)


@app.post("/auth/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(payload: LogoutRequest) -> None:
    with session() as connection:
        connection.execute("UPDATE refresh_tokens SET revoked_at = ? WHERE token_hash = ?", (datetime.now(timezone.utc).isoformat(), hashlib.sha256(payload.refresh_token.encode()).hexdigest()))


@app.get("/auth/me", response_model=User)
def me(user: sqlite3.Row = Depends(current_user)) -> User:
    return _user(user)


@app.post("/auth/password-reset/request")
def request_password_reset(payload: PasswordResetRequest) -> dict[str, str]:
    with session() as connection:
        user = connection.execute("SELECT id FROM users WHERE email = ?", (payload.email.strip().lower(),)).fetchone()
        if user:
            raw = secrets.token_urlsafe(32)
            connection.execute("INSERT INTO password_reset_tokens(token_id, user_id, token_hash, expires_at) VALUES (?, ?, ?, ?)", (uuid4().hex, user["id"], hashlib.sha256(raw.encode()).hexdigest(), datetime.now(timezone.utc).timestamp() + 3600))
    # Do not disclose whether an email exists. Delivery is delegated to a future mail provider.
    return {"message": "If the account exists, recovery instructions will be sent."}


@app.post("/auth/password-reset/confirm")
def confirm_password_reset(payload: PasswordResetConfirm) -> dict[str, str]:
    token_hash = hashlib.sha256(payload.token.encode()).hexdigest()
    with session() as connection:
        row = connection.execute("SELECT user_id FROM password_reset_tokens WHERE token_hash = ? AND used_at IS NULL AND expires_at > ?", (token_hash, datetime.now(timezone.utc).timestamp())).fetchone()
        if row is None:
            raise HTTPException(status_code=400, detail="Invalid or expired reset token")
        connection.execute("UPDATE users SET password_hash = ? WHERE id = ?", (_password_hash(payload.new_password), row["user_id"]))
        connection.execute("UPDATE password_reset_tokens SET used_at = ? WHERE token_hash = ?", (datetime.now(timezone.utc).isoformat(), token_hash))
        connection.execute("UPDATE refresh_tokens SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL", (datetime.now(timezone.utc).isoformat(), row["user_id"]))
    return {"message": "Password updated"}


@app.post("/users", response_model=User, status_code=status.HTTP_201_CREATED)
def create_user(payload: UserCreate, _: sqlite3.Row = Depends(require_roles("admin"))) -> User:
    try:
        with session() as connection:
            row = connection.execute(
                "INSERT INTO users(id, name, email, role, image, rating) VALUES (?, ?, ?, ?, ?, ?) "
                "RETURNING id, name, email, role, image, rating, created_at",
                (payload.id, payload.name.strip(), payload.email.strip().lower(), payload.role, payload.image, payload.rating),
            ).fetchone()
    except sqlite3.IntegrityError as error:
        raise HTTPException(status_code=409, detail="User already exists") from error
    return _user(row)


@app.get("/cars", response_model=list[Car])
def list_cars(available_only: bool = True, limit: int = Query(50, ge=1, le=200), offset: int = Query(0, ge=0)) -> list[Car]:
    where = "WHERE is_available = 1" if available_only else ""
    with session() as connection:
        rows = connection.execute(
            f"SELECT id, owner_id, brand, model, year, price, currency, location, "
            f"is_available, approval_status, created_at FROM cars {where} ORDER BY created_at DESC LIMIT ? OFFSET ?", (limit, offset)
        ).fetchall()
    return [_car(row) for row in rows]


@app.post("/cars", response_model=Car, status_code=status.HTTP_201_CREATED)
def create_car(payload: CarCreate, _: sqlite3.Row = Depends(current_user)) -> Car:
    try:
        with session() as connection:
            row = connection.execute(
                "INSERT INTO cars(id, owner_id, brand, model, year, price, currency, location, is_available) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) "
                "RETURNING id, owner_id, brand, model, year, price, currency, location, is_available, approval_status, created_at",
                (payload.id, payload.owner_id, payload.brand.strip(), payload.model.strip(), payload.year,
                 payload.price, payload.currency, payload.location.strip(), int(payload.is_available)),
            ).fetchone()
    except sqlite3.IntegrityError as error:
        raise HTTPException(status_code=400, detail="Invalid owner or duplicate car") from error
    return _car(row)


@app.put("/cars/{car_id}", response_model=Car)
def update_car(car_id: str, payload: CarCreate, owner: sqlite3.Row = Depends(require_roles("car_owner"))) -> Car:
    with session() as connection:
        row = connection.execute("SELECT owner_id FROM cars WHERE id = ?", (car_id,)).fetchone()
        if row is None: raise HTTPException(status_code=404, detail="Car not found")
        if row["owner_id"] != owner["id"]: raise HTTPException(status_code=403, detail="Only the owner can edit this car")
        updated = connection.execute("UPDATE cars SET brand=?, model=?, year=?, price=?, currency=?, location=?, is_available=? WHERE id=? RETURNING id, owner_id, brand, model, year, price, currency, location, is_available, approval_status, created_at", (payload.brand.strip(), payload.model.strip(), payload.year, payload.price, payload.currency, payload.location.strip(), int(payload.is_available), car_id)).fetchone()
    return _car(updated)


@app.patch("/cars/{car_id}/approval", response_model=Car)
def approve_car(car_id: str, approved: bool, _: sqlite3.Row = Depends(require_roles("admin"))) -> Car:
    with session() as connection:
        row = connection.execute("UPDATE cars SET approval_status=? WHERE id=? RETURNING id, owner_id, brand, model, year, price, currency, location, is_available, approval_status, created_at", ("approved" if approved else "rejected", car_id)).fetchone()
        if row is None: raise HTTPException(status_code=404, detail="Car not found")
    return _car(row)


@app.post("/cars/{car_id}/unavailable", response_model=UnavailablePeriod, status_code=status.HTTP_201_CREATED)
def add_unavailable_period(car_id: str, payload: UnavailablePeriodCreate, owner: sqlite3.Row = Depends(require_roles("car_owner"))) -> UnavailablePeriod:
    with session() as connection:
        car = connection.execute("SELECT owner_id FROM cars WHERE id=?", (car_id,)).fetchone()
        if car is None: raise HTTPException(status_code=404, detail="Car not found")
        if car["owner_id"] != owner["id"]: raise HTTPException(status_code=403, detail="Only the owner can manage availability")
        conflict = connection.execute("SELECT 1 FROM reservations WHERE car_id=? AND status IN ('awaiting_payment','approved','active') AND start_date<=? AND end_date>=?", (car_id, payload.end_date.isoformat(), payload.start_date.isoformat())).fetchone()
        if conflict: raise HTTPException(status_code=409, detail="Period conflicts with a reservation")
        row = connection.execute("INSERT INTO unavailable_periods(id, car_id, start_date, end_date, reason) VALUES (?, ?, ?, ?, ?) RETURNING id, car_id, start_date, end_date, reason, created_at", (uuid4().hex, car_id, payload.start_date.isoformat(), payload.end_date.isoformat(), payload.reason)).fetchone()
    return UnavailablePeriod(**dict(row))


@app.get("/cars/{car_id}/unavailable", response_model=list[UnavailablePeriod])
def list_unavailable_periods(car_id: str) -> list[UnavailablePeriod]:
    with session() as connection:
        rows = connection.execute("SELECT id, car_id, start_date, end_date, reason, created_at FROM unavailable_periods WHERE car_id=? ORDER BY start_date", (car_id,)).fetchall()
    return [UnavailablePeriod(**dict(row)) for row in rows]


@app.delete("/cars/{car_id}/unavailable/{period_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_unavailable_period(car_id: str, period_id: str, owner: sqlite3.Row = Depends(require_roles("car_owner"))) -> None:
    with session() as connection:
        connection.execute("DELETE FROM unavailable_periods WHERE id=? AND car_id=? AND car_id IN (SELECT id FROM cars WHERE owner_id=?)", (period_id, car_id, owner["id"]))


@app.post("/cars/{car_id}/images", response_model=CarImage, status_code=status.HTTP_201_CREATED)
async def upload_car_image(car_id: str, file: UploadFile = File(...), owner: sqlite3.Row = Depends(require_roles("car_owner"))) -> CarImage:
    from PIL import Image
    if file.content_type not in {"image/jpeg", "image/png", "image/webp"}:
        raise HTTPException(status_code=415, detail="Only JPEG, PNG, and WebP images are supported")
    data = await file.read()
    if len(data) > 8 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Image must be smaller than 8 MB")
    try:
        image = Image.open(BytesIO(data))
        image.verify()
        image = Image.open(BytesIO(data))
    except Exception as error:
        raise HTTPException(status_code=400, detail="Invalid image") from error
    if image.width < 320 or image.height < 200:
        raise HTTPException(status_code=422, detail="Image resolution is too small")
    image.thumbnail((1600, 1600))
    image_id = uuid4().hex
    folder = MEDIA_ROOT / "cars" / car_id
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / f"{image_id}.webp"
    image.convert("RGB").save(path, "WEBP", quality=85, optimize=True)
    with session() as connection:
        car = connection.execute("SELECT owner_id FROM cars WHERE id=?", (car_id,)).fetchone()
        if car is None: raise HTTPException(status_code=404, detail="Car not found")
        if car["owner_id"] != owner["id"]: raise HTTPException(status_code=403, detail="Only the owner can upload images")
        row = connection.execute("INSERT INTO car_images(id, car_id, storage_path, mime_type, width, height) VALUES (?, ?, ?, ?, ?, ?) RETURNING id, car_id, storage_path, mime_type, width, height, created_at", (image_id, car_id, str(path), "image/webp", image.width, image.height)).fetchone()
    value = dict(row); value["url"] = f"/media/cars/{car_id}/{image_id}.webp"; value.pop("storage_path")
    return CarImage(**value)


@app.delete("/cars/{car_id}/images/{image_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_car_image(car_id: str, image_id: str, owner: sqlite3.Row = Depends(require_roles("car_owner"))) -> None:
    with session() as connection:
        row = connection.execute("SELECT i.storage_path FROM car_images i JOIN cars c ON c.id=i.car_id WHERE i.id=? AND i.car_id=? AND c.owner_id=?", (image_id, car_id, owner["id"])).fetchone()
        if row is None: raise HTTPException(status_code=404, detail="Image not found")
        connection.execute("DELETE FROM car_images WHERE id=?", (image_id,))
    Path(row["storage_path"]).unlink(missing_ok=True)


@app.post("/reservations", response_model=Reservation, status_code=status.HTTP_201_CREATED)
def create_reservation(payload: ReservationCreate, _: sqlite3.Row = Depends(current_user)) -> Reservation:
    start = payload.start_date.isoformat()
    end = payload.end_date.isoformat()
    with session() as connection:
        connection.execute("BEGIN IMMEDIATE")
        car = connection.execute(
            "SELECT price, is_available FROM cars WHERE id = ?", (payload.car_id,)
        ).fetchone()
        if car is None or not car["is_available"]:
            raise HTTPException(status_code=404, detail="Available car not found")
        renter = connection.execute(
            "SELECT id, role FROM users WHERE id = ?", (payload.renter_id,)
        ).fetchone()
        if renter is None:
            raise HTTPException(status_code=404, detail="Renter not found")
        if renter["role"] != "car_renter":
            raise HTTPException(status_code=400, detail="Only car renters can create reservations")
        owner = connection.execute(
            "SELECT owner_id FROM cars WHERE id = ?", (payload.car_id,)
        ).fetchone()
        if owner["owner_id"] == payload.renter_id:
            raise HTTPException(status_code=400, detail="Owners cannot reserve their own cars")
        overlap = connection.execute(
            "SELECT 1 FROM reservations WHERE car_id = ? "
            "AND status IN ('awaiting_payment', 'approved', 'active') "
            "AND start_date <= ? AND end_date >= ? LIMIT 1",
            (payload.car_id, end, start),
        ).fetchone()
        if overlap:
            raise HTTPException(status_code=409, detail="Selected dates are unavailable")

        total_days = (payload.end_date - payload.start_date).days + 1
        total_cost = total_days * float(car["price"])
        try:
            row = connection.execute(
                "INSERT INTO reservations(id, car_id, renter_id, start_date, end_date, pickup_time, "
                "total_days, total_cost, deposit_amount, payment_deadline, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) "
                "RETURNING id, car_id, renter_id, start_date, end_date, pickup_time, total_days, total_cost, "
                "deposit_amount, payment_deadline, status, created_at",
                (payload.id, payload.car_id, payload.renter_id, start, end, payload.pickup_time,
                 total_days, total_cost, total_cost * 0.10,
                 (datetime.now(timezone.utc) + timedelta(minutes=30)).isoformat(), "pending"),
            ).fetchone()
        except sqlite3.IntegrityError as error:
            raise HTTPException(status_code=409, detail="Reservation already exists") from error
        _insert_notification(
            connection,
            user_id=owner["owner_id"],
            title="New booking request",
            message=f"A renter requested the car for {total_days} day(s).",
            notification_type="reservation_requested",
            reservation_id=payload.id,
        )
        _record_event(connection, payload.id, "created", actor_id=payload.renter_id, to_status="pending")
    return _reservation(row)


@app.post("/reservations/{reservation_id}/pickup", response_model=Reservation)
def pickup_reservation(reservation_id: str) -> Reservation:
    return update_reservation_status(reservation_id, ReservationStatusUpdate(status="active", reason="pickup_confirmed"))


@app.post("/reservations/{reservation_id}/complete", response_model=Reservation)
def complete_reservation(reservation_id: str) -> Reservation:
    return update_reservation_status(reservation_id, ReservationStatusUpdate(status="completed", reason="vehicle_returned"))


@app.get("/reservations/{reservation_id}/events", response_model=list[ReservationEvent])
def reservation_events(reservation_id: str) -> list[ReservationEvent]:
    with session() as connection:
        rows = connection.execute("SELECT id, reservation_id, actor_id, event_type, from_status, to_status, metadata, created_at FROM reservation_events WHERE reservation_id = ? ORDER BY created_at ASC", (reservation_id,)).fetchall()
    return [ReservationEvent(**dict(row)) for row in rows]


@app.get("/reservations", response_model=list[Reservation])
def list_reservations(car_id: str | None = None, renter_id: str | None = None, _: sqlite3.Row = Depends(current_user)) -> list[Reservation]:
    clauses: list[str] = []
    arguments: list[str] = []
    if car_id is not None:
        clauses.append("car_id = ?")
        arguments.append(car_id)
    if renter_id is not None:
        clauses.append("renter_id = ?")
        arguments.append(renter_id)
    where = f"WHERE {' AND '.join(clauses)}" if clauses else ""
    with session() as connection:
        rows = connection.execute(
            f"SELECT id, car_id, renter_id, start_date, end_date, pickup_time, total_days, total_cost, "
            f"deposit_amount, status, created_at FROM reservations {where} ORDER BY created_at DESC",
            arguments,
        ).fetchall()
    return [_reservation(row) for row in rows]


@app.patch("/reservations/{reservation_id}/status", response_model=Reservation)
def update_reservation_status(
    reservation_id: str,
    payload: ReservationStatusUpdate,
    _: sqlite3.Row = Depends(current_user),
) -> Reservation:
    with session() as connection:
        connection.execute("BEGIN IMMEDIATE")
        current = connection.execute(
            "SELECT id, car_id, renter_id, start_date, end_date, pickup_time, total_days, total_cost, "
            "deposit_amount, status, created_at FROM reservations WHERE id = ?",
            (reservation_id,),
        ).fetchone()
        if current is None:
            raise HTTPException(status_code=404, detail="Reservation not found")

        transitions = {
            "pending": {"awaiting_payment", "rejected", "cancelled", "expired"},
            "awaiting_payment": {"approved", "cancelled", "expired"},
            "approved": {"active", "cancelled"},
            "active": {"completed", "cancelled"},
            "completed": set(),
            "rejected": set(),
            "cancelled": set(),
            "expired": set(),
        }
        if payload.status not in transitions[current["status"]]:
            raise HTTPException(
                status_code=409,
                detail=f"Cannot move reservation from {current['status']} to {payload.status}",
            )

        if payload.status in {"awaiting_payment", "approved", "active"}:
            overlap = connection.execute(
                "SELECT 1 FROM reservations WHERE car_id = ? AND id != ? "
                "AND status IN ('awaiting_payment', 'approved', 'active') "
                "AND start_date <= ? AND end_date >= ? LIMIT 1",
                (current["car_id"], reservation_id, current["end_date"], current["start_date"]),
            ).fetchone()
            if overlap:
                raise HTTPException(status_code=409, detail="Selected dates are unavailable")

        now = datetime.now(timezone.utc).isoformat()
        fields = "status = ?"
        values: list[object] = [payload.status]
        if payload.status == "active":
            fields += ", picked_up_at = ?"
            values.append(now)
        elif payload.status == "completed":
            fields += ", completed_at = ?"
            values.append(now)
        elif payload.status == "cancelled":
            fields += ", cancelled_at = ?"
            values.append(now)
        values.append(reservation_id)
        row = connection.execute(
            f"UPDATE reservations SET {fields} WHERE id = ? RETURNING "
            "id, car_id, renter_id, start_date, end_date, pickup_time, total_days, total_cost, "
            "deposit_amount, payment_deadline, picked_up_at, completed_at, cancelled_at, status, created_at",
            values,
        ).fetchone()
        _record_event(connection, reservation_id, "status_changed", from_status=current["status"], to_status=payload.status, metadata=json.dumps({"reason": payload.reason} if payload.reason else {}))
        if payload.status == "completed":
            owner_id = connection.execute("SELECT owner_id FROM cars WHERE id=?", (current["car_id"],)).fetchone()["owner_id"]
            _award_coins(connection, current["renter_id"], 10, "reservation_completed", reservation_id)
            _award_coins(connection, owner_id, 5, "reservation_completed", reservation_id)
        _insert_notification(
            connection,
            user_id=current["renter_id"],
            title="Reservation updated",
            message=f"Your reservation is now {payload.status.replace('_', ' ')}.",
            notification_type=f"reservation_{payload.status}",
            reservation_id=reservation_id,
        )
    return _reservation(row)


@app.get("/notifications", response_model=list[Notification])
def list_notifications(user_id: str, unread_only: bool = False, limit: int = Query(50, ge=1, le=200), offset: int = Query(0, ge=0), _: sqlite3.Row = Depends(current_user)) -> list[Notification]:
    clause = "AND is_read = 0" if unread_only else ""
    with session() as connection:
        rows = connection.execute(
            "SELECT id, user_id, title, message, type, is_read, reservation_id, created_at "
            f"FROM notifications WHERE user_id = ? {clause} ORDER BY created_at DESC LIMIT ? OFFSET ?",
            (user_id, limit, offset),
        ).fetchall()
    return [_notification(row) for row in rows]


@app.post("/notifications/device-token", status_code=status.HTTP_204_NO_CONTENT)
def register_device_token(payload: DeviceTokenRegistration, user: sqlite3.Row = Depends(current_user)) -> None:
    with session() as connection:
        connection.execute("INSERT INTO device_tokens(id, user_id, token, platform, is_active, last_seen_at) VALUES (?, ?, ?, ?, 1, CURRENT_TIMESTAMP) ON CONFLICT(token) DO UPDATE SET user_id=excluded.user_id, platform=excluded.platform, is_active=1, last_seen_at=CURRENT_TIMESTAMP", (uuid4().hex, user["id"], payload.token, payload.platform))
        connection.execute("INSERT INTO notification_preferences(user_id) VALUES (?) ON CONFLICT(user_id) DO NOTHING", (user["id"],))


@app.delete("/notifications/device-token/{token}", status_code=status.HTTP_204_NO_CONTENT)
def unregister_device_token(token: str, user: sqlite3.Row = Depends(current_user)) -> None:
    with session() as connection:
        connection.execute("UPDATE device_tokens SET is_active=0 WHERE token=? AND user_id=?", (token, user["id"]))


@app.get("/notifications/preferences", response_model=NotificationPreferences)
def get_notification_preferences(user: sqlite3.Row = Depends(current_user)) -> NotificationPreferences:
    with session() as connection:
        row = connection.execute("SELECT * FROM notification_preferences WHERE user_id=?", (user["id"],)).fetchone()
        if row is None:
            return NotificationPreferences()
    return NotificationPreferences(reservation_events=bool(row["reservation_events"]), payment_events=bool(row["payment_events"]), marketing=bool(row["marketing"]))


@app.put("/notifications/preferences", response_model=NotificationPreferences)
def set_notification_preferences(payload: NotificationPreferences, user: sqlite3.Row = Depends(current_user)) -> NotificationPreferences:
    with session() as connection:
        connection.execute("INSERT INTO notification_preferences(user_id, reservation_events, payment_events, marketing, updated_at) VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP) ON CONFLICT(user_id) DO UPDATE SET reservation_events=excluded.reservation_events, payment_events=excluded.payment_events, marketing=excluded.marketing, updated_at=CURRENT_TIMESTAMP", (user["id"], int(payload.reservation_events), int(payload.payment_events), int(payload.marketing)))
    return payload


@app.get("/me/notifications", response_model=list[Notification])
def my_notifications(user: sqlite3.Row = Depends(current_user), unread_only: bool = False, limit: int = Query(50, ge=1, le=200), offset: int = Query(0, ge=0)) -> list[Notification]:
    return list_notifications(user["id"], unread_only=unread_only, limit=limit, offset=offset)


@app.patch("/notifications/{notification_id}/read", response_model=Notification)
def mark_notification_read(notification_id: str, user: sqlite3.Row = Depends(current_user)) -> Notification:
    with session() as connection:
        row = connection.execute(
            "UPDATE notifications SET is_read = 1 WHERE id = ? AND user_id = ? RETURNING "
            "id, user_id, title, message, type, is_read, reservation_id, created_at",
            (notification_id, user["id"]),
        ).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Notification not found")
    return _notification(row)


@app.post("/reviews", response_model=Review, status_code=status.HTTP_201_CREATED)
def create_review(payload: ReviewCreate, user: sqlite3.Row = Depends(current_user)) -> Review:
    with session() as connection:
        reservation = connection.execute("SELECT r.*, c.owner_id FROM reservations r JOIN cars c ON c.id=r.car_id WHERE r.id=?", (payload.reservation_id,)).fetchone()
        if reservation is None or reservation["status"] != "completed": raise HTTPException(status_code=409, detail="Only completed reservations can be reviewed")
        if user["id"] == reservation["renter_id"]: subject_id = reservation["owner_id"]
        elif user["id"] == reservation["owner_id"]: subject_id = reservation["renter_id"]
        else: raise HTTPException(status_code=403, detail="Only reservation participants can review")
        try:
            row = connection.execute("INSERT INTO reviews(id, reservation_id, author_id, subject_id, rating, comment) VALUES (?, ?, ?, ?, ?, ?) RETURNING id, reservation_id, author_id, subject_id, rating, comment, status, created_at", (uuid4().hex, payload.reservation_id, user["id"], subject_id, payload.rating, payload.comment.strip())).fetchone()
        except sqlite3.IntegrityError as error: raise HTTPException(status_code=409, detail="One review per reservation and author") from error
        aggregate = connection.execute("SELECT AVG(rating) AS average FROM reviews WHERE subject_id=? AND status='published'", (subject_id,)).fetchone()["average"]
        connection.execute("UPDATE users SET rating=? WHERE id=?", (round(float(aggregate or 0), 2), subject_id))
        _audit(connection, user["id"], "review_created", "review", row["id"])
    return Review(**dict(row))


@app.get("/users/{user_id}/reviews", response_model=list[Review])
def list_reviews(user_id: str) -> list[Review]:
    with session() as connection:
        rows = connection.execute("SELECT id, reservation_id, author_id, subject_id, rating, comment, status, created_at FROM reviews WHERE subject_id=? AND status='published' ORDER BY created_at DESC", (user_id,)).fetchall()
    return [Review(**dict(row)) for row in rows]


@app.patch("/reviews/{review_id}/moderation", response_model=Review)
def moderate_review(review_id: str, payload: ModerationUpdate, admin: sqlite3.Row = Depends(require_roles("admin"))) -> Review:
    with session() as connection:
        row = connection.execute("UPDATE reviews SET status=? WHERE id=? RETURNING id, reservation_id, author_id, subject_id, rating, comment, status, created_at", (payload.status, review_id)).fetchone()
        if row is None: raise HTTPException(status_code=404, detail="Review not found")
        _audit(connection, admin["id"], "review_moderated", "review", review_id, json.dumps({"status": payload.status, "reason": payload.reason}))
    return Review(**dict(row))


@app.get("/me/coins", response_model=list[CoinTransaction])
def coin_history(user: sqlite3.Row = Depends(current_user)) -> list[CoinTransaction]:
    with session() as connection:
        rows = connection.execute("SELECT id, user_id, amount, reason, reservation_id, created_at FROM coin_transactions WHERE user_id=? ORDER BY created_at DESC", (user["id"],)).fetchall()
    return [CoinTransaction(**dict(row)) for row in rows]


@app.post("/me/coins/spend", response_model=CoinTransaction)
def spend_coins(payload: CoinSpendRequest, user: sqlite3.Row = Depends(current_user)) -> CoinTransaction:
    with session() as connection:
        balance = connection.execute("SELECT coins FROM users WHERE id=?", (user["id"],)).fetchone()["coins"]
        if balance < payload.amount: raise HTTPException(status_code=409, detail="Insufficient coins")
        row = connection.execute("INSERT INTO coin_transactions(id, user_id, amount, reason) VALUES (?, ?, ?, ?) RETURNING id, user_id, amount, reason, reservation_id, created_at", (uuid4().hex, user["id"], -payload.amount, payload.reason)).fetchone()
        connection.execute("UPDATE users SET coins=coins-? WHERE id=?", (payload.amount, user["id"]))
    return CoinTransaction(**dict(row))


@app.get("/admin/analytics")
def admin_analytics(_: sqlite3.Row = Depends(require_roles("admin"))) -> dict[str, int]:
    with session() as connection:
        result = {}
        for key, table in (("users", "users"), ("cars", "cars"), ("reservations", "reservations"), ("reviews", "reviews")):
            result[key] = connection.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
    return result


@app.patch("/admin/users/{user_id}/block")
def block_user(user_id: str, payload: BlockUserRequest, admin: sqlite3.Row = Depends(require_roles("admin"))) -> dict[str, bool]:
    with session() as connection:
        updated = connection.execute("UPDATE users SET is_blocked=? WHERE id=? RETURNING is_blocked", (int(payload.blocked), user_id)).fetchone()
        if updated is None: raise HTTPException(status_code=404, detail="User not found")
        _audit(connection, admin["id"], "user_blocked" if payload.blocked else "user_unblocked", "user", user_id, json.dumps({"reason": payload.reason}))
    return {"blocked": bool(updated["is_blocked"])}


@app.get("/admin/audit-logs")
def audit_logs(_: sqlite3.Row = Depends(require_roles("admin")), limit: int = Query(100, ge=1, le=500)) -> list[dict[str, object]]:
    with session() as connection:
        rows = connection.execute("SELECT id, actor_id, action, entity_type, entity_id, metadata, created_at FROM audit_logs ORDER BY created_at DESC LIMIT ?", (limit,)).fetchall()
    return [dict(row) for row in rows]

