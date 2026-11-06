from __future__ import annotations

from datetime import date
from typing import Literal

from pydantic import BaseModel, Field, model_validator


Role = Literal["car_owner", "car_renter", "admin"]
ReservationStatus = Literal[
    "pending",
    "awaiting_payment",
    "approved",
    "active",
    "completed",
    "rejected",
    "cancelled",
    "expired",
]


class UserCreate(BaseModel):
    id: str = Field(min_length=1)
    name: str = Field(min_length=2)
    email: str = Field(min_length=3)
    role: Role
    image: str = ""
    rating: float = Field(default=0, ge=0, le=5)


class User(UserCreate):
    created_at: str


class RegisterRequest(BaseModel):
    id: str = Field(min_length=1)
    name: str = Field(min_length=2)
    email: str = Field(min_length=5)
    password: str = Field(min_length=8)
    role: Literal["car_owner", "car_renter"]


class LoginRequest(BaseModel):
    email: str = Field(min_length=5)
    password: str = Field(min_length=1)


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=20)


class LogoutRequest(BaseModel):
    refresh_token: str = Field(min_length=20)


class PasswordResetRequest(BaseModel):
    email: str = Field(min_length=5)


class PasswordResetConfirm(BaseModel):
    token: str = Field(min_length=20)
    new_password: str = Field(min_length=8)


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    user: "User"


class CarCreate(BaseModel):
    id: str = Field(min_length=1)
    owner_id: str = Field(min_length=1)
    brand: str = Field(min_length=1)
    model: str = Field(min_length=1)
    year: int = Field(ge=1980, le=2100)
    price: float = Field(gt=0)
    currency: str = Field(min_length=1, max_length=8)
    location: str = ""
    is_available: bool = True


class Car(CarCreate):
    created_at: str
    approval_status: Literal["pending", "approved", "rejected"] = "approved"


class UnavailablePeriodCreate(BaseModel):
    start_date: date
    end_date: date
    reason: str = Field(default="maintenance", min_length=1, max_length=80)

    @model_validator(mode="after")
    def validate_range(self) -> "UnavailablePeriodCreate":
        if self.end_date < self.start_date:
            raise ValueError("end_date must be on or after start_date")
        return self


class UnavailablePeriod(UnavailablePeriodCreate):
    id: str
    car_id: str
    created_at: str


class CarImage(BaseModel):
    id: str
    car_id: str
    url: str
    mime_type: str
    width: int
    height: int
    created_at: str


class ReservationCreate(BaseModel):
    id: str = Field(min_length=1)
    car_id: str = Field(min_length=1)
    renter_id: str = Field(min_length=1)
    start_date: date
    end_date: date
    pickup_time: str = Field(min_length=1)

    @model_validator(mode="after")
    def validate_range(self) -> "ReservationCreate":
        if self.end_date < self.start_date:
            raise ValueError("end_date must be on or after start_date")
        return self


class Reservation(ReservationCreate):
    total_days: int
    total_cost: float
    deposit_amount: float
    status: ReservationStatus
    created_at: str
    payment_deadline: str | None = None
    picked_up_at: str | None = None
    completed_at: str | None = None
    cancelled_at: str | None = None


class ReservationStatusUpdate(BaseModel):
    status: ReservationStatus
    reason: str | None = Field(default=None, max_length=500)


class ReservationEvent(BaseModel):
    id: str
    reservation_id: str
    actor_id: str | None = None
    event_type: str
    from_status: str | None = None
    to_status: str | None = None
    metadata: str
    created_at: str


class Notification(BaseModel):
    id: str
    user_id: str
    title: str
    message: str
    type: str
    is_read: bool
    reservation_id: str | None = None
    created_at: str


class DeviceTokenRegistration(BaseModel):
    token: str = Field(min_length=10, max_length=4096)
    platform: Literal["android", "ios", "web", "windows", "macos", "linux"]


class NotificationPreferences(BaseModel):
    reservation_events: bool = True
    payment_events: bool = True
    marketing: bool = False


class ReviewCreate(BaseModel):
    reservation_id: str
    rating: int = Field(ge=1, le=5)
    comment: str = Field(default="", max_length=1000)


class Review(BaseModel):
    id: str
    reservation_id: str
    author_id: str
    subject_id: str
    rating: int
    comment: str
    status: Literal["published", "hidden", "rejected"]
    created_at: str


class CoinTransaction(BaseModel):
    id: str
    user_id: str
    amount: int
    reason: str
    reservation_id: str | None = None
    created_at: str


class CoinSpendRequest(BaseModel):
    amount: int = Field(gt=0, le=100000)
    reason: str = Field(min_length=1, max_length=120)


class ModerationUpdate(BaseModel):
    status: Literal["published", "hidden", "rejected"]
    reason: str = Field(default="", max_length=500)


class BlockUserRequest(BaseModel):
    blocked: bool
    reason: str = Field(default="", max_length=500)


class Coordinates(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)


class GpsSettingsUpdate(BaseModel):
    enabled: bool


class OwnerLocation(BaseModel):
    owner_id: str
    fixed_latitude: float | None = None
    fixed_longitude: float | None = None
    gps_latitude: float | None = None
    gps_longitude: float | None = None
    gps_enabled: bool
    gps_updated_at: str | None = None
    effective_latitude: float | None = None
    effective_longitude: float | None = None
    effective_source: Literal["fixed", "gps", "none"]


class NearbyOwner(BaseModel):
    owner_id: str
    name: str
    latitude: float
    longitude: float
    distance_km: float
    lowest_price_per_day: float
    currency: str
    available_cars_count: int
    profile_image: str | None = None
    rating: float


class NearbyOwnersResponse(BaseModel):
    radius_km: float
    total: int
    owners: list[NearbyOwner]

