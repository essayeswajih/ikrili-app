import tempfile
import unittest
from datetime import datetime, timezone, timedelta
from pathlib import Path

from fastapi import HTTPException

from app import database
from app.main import (
    create_car,
    create_reservation,
    create_user,
    nearby_owners,
    set_fixed_location,
    update_reservation_status,
    register, login, refresh, logout,
    _expire_due_reservations, reservation_events,
)
from app.schemas import CarCreate, Coordinates, ReservationCreate, ReservationStatusUpdate, UserCreate, RegisterRequest, LoginRequest, RefreshRequest, LogoutRequest


class ApiSmokeTest(unittest.TestCase):
    def setUp(self) -> None:
        self.database_file = Path(tempfile.mktemp(suffix=".db"))
        database.DATABASE_PATH = self.database_file
        database.initialize_database()
        create_user(UserCreate(id="owner", name="Owner", email="owner@example.com", role="car_owner"))
        create_user(UserCreate(id="renter", name="Renter", email="renter@example.com", role="car_renter"))
        create_car(CarCreate(
            id="car-1", owner_id="owner", brand="Test", model="One",
            year=2026, price=100, currency="DT",
        ))

    def tearDown(self) -> None:
        self.database_file.unlink(missing_ok=True)

    def test_reservation_transition_rejects_overlap(self) -> None:
        create_reservation(ReservationCreate(
            id="res-1", car_id="car-1", renter_id="renter",
            start_date="2026-12-01", end_date="2026-12-02", pickup_time="09:00",
        ))
        update_reservation_status("res-1", ReservationStatusUpdate(status="awaiting_payment"))
        with self.assertRaises(HTTPException) as error:
            create_reservation(ReservationCreate(
                id="res-2", car_id="car-1", renter_id="renter",
                start_date="2026-12-02", end_date="2026-12-03", pickup_time="09:00",
            ))
        self.assertEqual(error.exception.status_code, 409)

    def test_nearby_groups_owner_and_uses_lowest_price(self) -> None:
        create_car(CarCreate(
            id="car-2", owner_id="owner", brand="Test", model="Two",
            year=2026, price=65, currency="DT",
        ))
        set_fixed_location(Coordinates(latitude=35.77, longitude=10.83), "owner")
        result = nearby_owners(
            latitude=35.77, longitude=10.83, radius_km=5, limit=50, offset=0,
        )
        self.assertEqual(result.total, 1)
        self.assertEqual(result.owners[0].available_cars_count, 2)
        self.assertEqual(result.owners[0].lowest_price_per_day, 65)

    def test_auth_register_login_refresh_and_logout(self) -> None:
        token = register(RegisterRequest(id="new-renter", name="New Renter", email="new@example.com", password="securepass", role="car_renter"))
        self.assertTrue(token.access_token)
        logged_in = login(LoginRequest(email="new@example.com", password="securepass"))
        self.assertNotEqual(token.refresh_token, logged_in.refresh_token)
        rotated = refresh(RefreshRequest(refresh_token=logged_in.refresh_token))
        self.assertTrue(rotated.access_token)
        logout(LogoutRequest(refresh_token=rotated.refresh_token))
        with self.assertRaises(HTTPException) as error:
            refresh(RefreshRequest(refresh_token=rotated.refresh_token))
        self.assertEqual(error.exception.status_code, 401)

    def test_auth_rejects_bad_password(self) -> None:
        with self.assertRaises(HTTPException) as error:
            login(LoginRequest(email="owner@example.com", password="wrong-password"))
        self.assertEqual(error.exception.status_code, 401)

    def test_payment_deadline_expires_and_records_event(self) -> None:
        create_reservation(ReservationCreate(
            id="res-expire", car_id="car-1", renter_id="renter",
            start_date="2027-01-01", end_date="2027-01-02", pickup_time="09:00",
        ))
        with database.session() as connection:
            connection.execute("UPDATE reservations SET payment_deadline = ? WHERE id = ?", (datetime.now(timezone.utc).isoformat(), "res-expire"))
        self.assertEqual(_expire_due_reservations(), 1)
        events = reservation_events("res-expire")
        self.assertEqual(events[-1].to_status, "expired")

    def test_nearby_excludes_stale_gps_without_fixed_location(self) -> None:
        create_user(UserCreate(id="owner-2", name="Second Owner", email="two@example.com", role="car_owner"))
        create_car(CarCreate(id="car-2", owner_id="owner-2", brand="Test", model="Two", year=2026, price=70, currency="DT"))
        with database.session() as connection:
            connection.execute("INSERT INTO owner_locations(owner_id, gps_latitude, gps_longitude, gps_enabled, gps_updated_at) VALUES (?, ?, ?, 1, ?)", ("owner-2", 35.77, 10.83, (datetime.now(timezone.utc) - timedelta(hours=2)).isoformat()))
        result = nearby_owners(latitude=35.77, longitude=10.83, radius_km=5, limit=50, offset=0)
        self.assertEqual([owner.owner_id for owner in result.owners], [])


if __name__ == "__main__":
    unittest.main()

