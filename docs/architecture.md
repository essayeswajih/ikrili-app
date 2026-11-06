# Ikrili architecture

## Authority and offline strategy

FastAPI is the authoritative source for shared business data: users, cars,
reservations, notifications, ratings, payments, and owner locations. Flutter's
SQLite database is an offline-first cache and local session store. Reads use the
cache when offline; writes are queued as commands and reconciled when the API
is reachable. Until the synchronization layer is completed, local repositories
remain the compatibility implementation and must not be treated as a second
production authority.

Firebase is intentionally removed from the architecture. Push notifications,
media storage, and authentication belong behind FastAPI-owned integrations (or
explicit future providers), not Firebase-specific Flutter code.

## Flutter layers

- `domain/`: entities and business concepts, no Flutter or HTTP imports.
- `data/`: API clients, cache data sources, DTOs, and repository implementations.
- `app/`: Riverpod dependency/state providers.
- `presentation/`: pages and feature widgets only; no SQL or raw HTTP.

Repositories expose stable interfaces so local-cache and remote implementations
can be substituted in tests. Riverpod owns dependency wiring and invalidation.

## API contracts

The backend exposes `/users`, `/cars`, `/reservations`, `/notifications`,
`/owners/me/location/*`, and `/owners/nearby`. Contract changes must be made in
`backend/app/schemas.py`, covered by backend tests, and mirrored by Flutter DTOs.

## Migration policy

SQLite schema changes are additive and versioned in `AppDatabase` and
`backend/app/database.py`. Destructive changes require an explicit migration
and a backup/export path.
