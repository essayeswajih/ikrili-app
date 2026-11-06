# Data synchronization policy

FastAPI is the only authority for shared users, cars, reservations,
notifications, ratings, and payments. SQLite is a device cache and offline
session store. A device may render cached data while offline, but must label
mutating actions as pending until the server acknowledges them.

Reads: fetch server data when authenticated and online, replace the local cache,
then render from the cache. Offline reads render the last successful snapshot.

Writes: enqueue an idempotent command with a client-generated ID, retry with
backoff, and reconcile by server response. Conflicts are resolved by server
validation; reservation conflicts are never resolved locally.

The API client lives in `lib/data/remote`, while existing SQLite repositories
remain the compatibility cache until each feature is migrated behind one
repository interface. No screen should directly choose between SQLite and HTTP.
