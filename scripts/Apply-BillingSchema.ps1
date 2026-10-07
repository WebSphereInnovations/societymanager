$ErrorActionPreference='Stop'
$root='C:\Users\Delta\Society360'
$cs=[Environment]::GetEnvironmentVariable('SOCIETY360_DB_CONNECTION','User')
if([string]::IsNullOrWhiteSpace($cs)){throw 'SOCIETY360_DB_CONNECTION is not configured.'}
$m=[regex]::Match($cs,'(?i)(?:^|;)Password=([^;]*)')
if(-not $m.Success){throw 'Database password is not available in the configured connection string.'}
$env:PGPASSWORD=$m.Groups[1].Value
try {
  & 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h 192.168.1.11 -p 5432 -U society_manager -d society_manager -v ON_ERROR_STOP=1 -f (Join-Path $root 'Database\036_billing_complete.sql')
  if($LASTEXITCODE -ne 0){throw "Billing schema deployment failed with exit code $LASTEXITCODE."}
  & 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h 192.168.1.11 -p 5432 -U society_manager -d society_manager -v ON_ERROR_STOP=1 -f (Join-Path $root 'Database\037_billing_hardening.sql')
  if($LASTEXITCODE -ne 0){throw "Billing hardening deployment failed with exit code $LASTEXITCODE."}
  Write-Output 'BILLING_SCHEMA_APPLIED'
} finally { Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue }