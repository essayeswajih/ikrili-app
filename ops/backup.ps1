param([string]$Output = "./backups")
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
New-Item -ItemType Directory -Force -Path $Output | Out-Null
docker run --rm -v ikrili-production-data:/data -v "${PWD}/${Output}:/backup" alpine:3.20 sh -c "tar czf /backup/ikrili-$timestamp.tar.gz -C /data ."
Write-Output "Created backup: $Output/ikrili-$timestamp.tar.gz"
