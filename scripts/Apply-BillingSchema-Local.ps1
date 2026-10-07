$ErrorActionPreference='Stop'
$root='C:\Users\Delta\Society360'
$cs=[Environment]::GetEnvironmentVariable('SOCIETY360_DB_CONNECTION','User')
$m=[regex]::Match($cs,'(?i)(?:^|;)Password=([^;]*)')
if(-not $m.Success){throw 'Configured database password is unavailable.'}
$env:PGPASSWORD=$m.Groups[1].Value
try {
  & 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h 127.0.0.1 -p 5432 -U society_manager -d society_manager -v ON_ERROR_STOP=1 -c "select current_database(),current_user,current_schema();"
  if($LASTEXITCODE -ne 0){throw "Local PostgreSQL connection failed with exit code $LASTEXITCODE."}
  & 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h 127.0.0.1 -p 5432 -U society_manager -d society_manager -v ON_ERROR_STOP=1 -f (Join-Path $root 'Database\036_billing_complete.sql')
  if($LASTEXITCODE -ne 0){throw "Billing schema deployment failed with exit code $LASTEXITCODE."}
  & 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -h 127.0.0.1 -p 5432 -U society_manager -d society_manager -v ON_ERROR_STOP=1 -f (Join-Path $root 'Database\037_billing_hardening.sql')
  if($LASTEXITCODE -ne 0){throw "Billing hardening deployment failed with exit code $LASTEXITCODE."}
  Write-Output 'BILLING_SCHEMA_APPLIED_LOCAL'
} finally {Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue}