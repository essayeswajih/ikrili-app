from __future__ import annotations

import os
import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator


DEFAULT_DATABASE_PATH = Path(__file__).resolve().parents[1] / "ikrili.db"
DATABASE_PATH = Path(os.getenv("IKRILI_DATABASE_PATH", DEFAULT_DATABASE_PATH))


def connect() -> sqlite3.Connection:
    DATABASE_PATH.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(DATABASE_PATH)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys = ON")
    return connection


@contextmanager
def session() -> Iterator[sqlite3.Connection]:
    connection = connect()
    try:
        yield connection
        connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()


def initialize_database() -> None:
    with session() as connection:
        connection.executescript(
            """
            CREATE TABLE IF NOT EXISTS users (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                email TEXT NOT NULL UNIQUE,
                role TEXT NOT NULL CHECK (role IN ('car_owner', 'car_renter', 'admin')),
                is_blocked INTEGER NOT NULL DEFAULT 0 CHECK (is_blocked IN (0, 1)),
                image TEXT NOT NULL DEFAULT '',
                rating REAL NOT NULL DEFAULT 0 CHECK (rating >= 0 AND rating <= 5),
                password_hash TEXT NOT NULL DEFAULT '',
                coins INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS cars (
                id TEXT PRIMARY KEY,
                owner_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                brand TEXT NOT NULL,
                model TEXT NOT NULL,
                year INTEGER NOT NULL,
                price REAL NOT NULL CHECK (price > 0),
                currency TEXT NOT NULL DEFAULT 'DT',
                location TEXT NOT NULL DEFAULT '',
                is_available INTEGER NOT NULL DEFAULT 1 CHECK (is_available IN (0, 1)),
                approval_status TEXT NOT NULL DEFAULT 'approved' CHECK (approval_status IN ('pending', 'approved', 'rejected')),
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS reservations (
                id TEXT PRIMARY KEY,
                car_id TEXT NOT NULL REFERENCES cars(id) ON DELETE CASCADE,
                renter_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                start_date TEXT NOT NULL,
                end_date TEXT NOT NULL,
                pickup_time TEXT NOT NULL,
                total_days INTEGER NOT NULL CHECK (total_days > 0),
                total_cost REAL NOT NULL CHECK (total_cost > 0),
                deposit_amount REAL NOT NULL CHECK (deposit_amount >= 0),
                payment_deadline TEXT,
                picked_up_at TEXT,
                completed_at TEXT,
                cancelled_at TEXT,
                status TEXT NOT NULL CHECK (
                    status IN ('pending', 'awaiting_payment', 'approved',
                               'active', 'completed', 'rejected', 'cancelled', 'expired')
                ),
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                CHECK (end_date >= start_date)
            );

            CREATE TABLE IF NOT EXISTS notifications (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                title TEXT NOT NULL,
                message TEXT NOT NULL,
                type TEXT NOT NULL,
                is_read INTEGER NOT NULL DEFAULT 0 CHECK (is_read IN (0, 1)),
                reservation_id TEXT REFERENCES reservations(id) ON DELETE CASCADE,
                dedupe_key TEXT UNIQUE,
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS owner_locations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                owner_id TEXT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
                fixed_latitude REAL,
                fixed_longitude REAL,
                gps_latitude REAL,
                gps_longitude REAL,
                gps_enabled INTEGER NOT NULL DEFAULT 0 CHECK (gps_enabled IN (0, 1)),
                gps_updated_at TEXT,
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                CHECK ((fixed_latitude IS NULL AND fixed_longitude IS NULL) OR
                       (fixed_latitude BETWEEN -90 AND 90 AND fixed_longitude BETWEEN -180 AND 180)),
                CHECK ((gps_latitude IS NULL AND gps_longitude IS NULL) OR
                       (gps_latitude BETWEEN -90 AND 90 AND gps_longitude BETWEEN -180 AND 180))
            );

            CREATE TABLE IF NOT EXISTS refresh_tokens (
                token_id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                token_hash TEXT NOT NULL UNIQUE,
                expires_at TEXT NOT NULL,
                revoked_at TEXT,
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS password_reset_tokens (
                token_id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                token_hash TEXT NOT NULL UNIQUE,
                expires_at TEXT NOT NULL,
                used_at TEXT
            );

            CREATE TABLE IF NOT EXISTS reservation_events (
                id TEXT PRIMARY KEY,
                reservation_id TEXT NOT NULL REFERENCES reservations(id) ON DELETE CASCADE,
                actor_id TEXT,
                event_type TEXT NOT NULL,
                from_status TEXT,
                to_status TEXT,
                metadata TEXT NOT NULL DEFAULT '{}',
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS car_images (
                id TEXT PRIMARY KEY,
                car_id TEXT NOT NULL REFERENCES cars(id) ON DELETE CASCADE,
                storage_path TEXT NOT NULL,
                mime_type TEXT NOT NULL,
                width INTEGER NOT NULL,
                height INTEGER NOT NULL,
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS unavailable_periods (
                id TEXT PRIMARY KEY,
                car_id TEXT NOT NULL REFERENCES cars(id) ON DELETE CASCADE,
                start_date TEXT NOT NULL,
                end_date TEXT NOT NULL,
                reason TEXT NOT NULL DEFAULT 'maintenance',
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                CHECK (end_date >= start_date)
            );

            CREATE TABLE IF NOT EXISTS device_tokens (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                token TEXT NOT NULL UNIQUE,
                platform TEXT NOT NULL,
                is_active INTEGER NOT NULL DEFAULT 1,
                last_seen_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS notification_preferences (
                user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
                reservation_events INTEGER NOT NULL DEFAULT 1,
                payment_events INTEGER NOT NULL DEFAULT 1,
                marketing INTEGER NOT NULL DEFAULT 0,
                updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS notification_deliveries (
                id TEXT PRIMARY KEY,
                notification_id TEXT NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,
                device_token_id TEXT NOT NULL REFERENCES device_tokens(id) ON DELETE CASCADE,
                status TEXT NOT NULL CHECK (status IN ('pending', 'sent', 'failed')),
                attempts INTEGER NOT NULL DEFAULT 0,
                last_error TEXT,
                next_attempt_at TEXT,
                updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(notification_id, device_token_id)
            );

            CREATE TABLE IF NOT EXISTS reviews (
                id TEXT PRIMARY KEY,
                reservation_id TEXT NOT NULL REFERENCES reservations(id) ON DELETE CASCADE,
                author_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                subject_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
                comment TEXT NOT NULL DEFAULT '',
                status TEXT NOT NULL DEFAULT 'published' CHECK (status IN ('published','hidden','rejected')),
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(reservation_id, author_id)
            );

            CREATE TABLE IF NOT EXISTS coin_transactions (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                amount INTEGER NOT NULL,
                reason TEXT NOT NULL,
                reservation_id TEXT REFERENCES reservations(id) ON DELETE SET NULL,
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS audit_logs (
                id TEXT PRIMARY KEY,
                actor_id TEXT,
                action TEXT NOT NULL,
                entity_type TEXT NOT NULL,
                entity_id TEXT,
                metadata TEXT NOT NULL DEFAULT '{}',
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            );

            CREATE INDEX IF NOT EXISTS idx_cars_owner_id ON cars(owner_id);
            CREATE INDEX IF NOT EXISTS idx_reservations_car_dates
                ON reservations(car_id, start_date, end_date, status);
            CREATE INDEX IF NOT EXISTS idx_notifications_user_id
                ON notifications(user_id, is_read, created_at);
            CREATE INDEX IF NOT EXISTS idx_owner_locations_owner_id
                ON owner_locations(owner_id);
            """
        )
        columns = {row[1] for row in connection.execute("PRAGMA table_info(users)")}
        if "is_blocked" not in columns:
            connection.execute(
                "ALTER TABLE users ADD COLUMN is_blocked INTEGER NOT NULL DEFAULT 0"
            )
        if "image" not in columns:
            connection.execute("ALTER TABLE users ADD COLUMN image TEXT NOT NULL DEFAULT ''")
        if "rating" not in columns:
            connection.execute("ALTER TABLE users ADD COLUMN rating REAL NOT NULL DEFAULT 0")
        if "password_hash" not in columns:
            connection.execute("ALTER TABLE users ADD COLUMN password_hash TEXT NOT NULL DEFAULT ''")
        if "coins" not in columns:
            connection.execute("ALTER TABLE users ADD COLUMN coins INTEGER NOT NULL DEFAULT 0")
        reservation_columns = {row[1] for row in connection.execute("PRAGMA table_info(reservations)")}
        for name, definition in {
            "payment_deadline": "TEXT",
            "picked_up_at": "TEXT",
            "completed_at": "TEXT",
            "cancelled_at": "TEXT",
        }.items():
            if name not in reservation_columns:
                connection.execute(f"ALTER TABLE reservations ADD COLUMN {name} {definition}")
        car_columns = {row[1] for row in connection.execute("PRAGMA table_info(cars)")}
        if "approval_status" not in car_columns:
            connection.execute("ALTER TABLE cars ADD COLUMN approval_status TEXT NOT NULL DEFAULT 'approved'")

