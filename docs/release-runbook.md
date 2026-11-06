# Ikrili release runbook

## Environments

Use separate Compose projects, domains, volumes, JWT secrets, and databases for
staging and production. Never copy production `.env` files into source control.

## Production start

1. Copy `.env.production.example` to `.env.production` and generate a random JWT secret.
2. Run `docker compose -f docker-compose.production.yml up -d --build`.
3. Verify `http://127.0.0.1:8000/health/ready`, `/docs`, and `/metrics`.
4. Create and verify a backup before enabling local beta traffic.

## Recovery

Run `ops/backup.ps1` daily and retain encrypted off-host copies. Test
`ops/restore.ps1` in staging before every release. Roll back by deploying the
previous image tag and restoring the last known-good database backup if a
migration is not backward compatible.

## Launch gates

Backend tests, Flutter analyze/test/build, dependency scan, backup/restore drill,
renter/owner/admin journeys, error-rate checks, and beta sign-off must all pass
before store submission. This deployment profile is intentionally local-only;
it does not configure DNS, reverse proxying, or TLS.
