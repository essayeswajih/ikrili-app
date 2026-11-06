param([Parameter(Mandatory=$true)][string]$Archive)
Write-Warning "Restore overwrites the production data volume. Stop the stack and verify the archive first."
docker compose -f docker-compose.production.yml down
docker run --rm -v ikrili-production-data:/data -v "${PWD}:/backup" alpine:3.20 sh -c "rm -rf /data/*; tar xzf /backup/$Archive -C /data"
docker compose -f docker-compose.production.yml up -d
