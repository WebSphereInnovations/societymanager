[Reading 53 lines from start (total: 53 lines, 0 remaining)]

$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Psql = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'
$HostName = '192.168.1.11'
$Port = '5432'
$Database = 'society_manager'
$Username = 'society_manager'
$Schema = 'society_manager'

if (-not (Test-Path $Psql)) { throw "PostgreSQL psql.exe was not found at $Psql" }

Write-Host 'Society360 PostgreSQL setup'
Write-Host ('Database: ' + $Database)
Write-Host ('Host: ' + $HostName + ':' + $Port)
Write-Host ''

$SecurePassword = Read-Host ('Enter PostgreSQL password for ' + $Username) -AsSecureString
$BSTR = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
try { $Password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR) }

$PgPass = Join-Path $env:TEMP ('society360-pgpass-' + [guid]::NewGuid().ToString('N') + '.conf')
try {
    ($HostName + ':' + $Port + ':' + $Database + ':' + $Username + ':' + $Password) | Set-Content -Path $PgPass -Encoding ascii -NoNewline
    $env:PGPASSFILE = $PgPass

    & $Psql -h $HostName -p $Port -U $Username -d $Database -v ON_ERROR_STOP=1 -c "select current_database(), current_user, current_schema();"
    if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL connection failed.' }

    & $Psql -h $HostName -p $Port -U $Username -d $Database -v ON_ERROR_STOP=1 -f (Join-Path $ProjectRoot 'Database\001_society360_foundation.sql')
    if ($LASTEXITCODE -ne 0) { throw 'Foundation schema deployment failed.' }

    & $Psql -h $HostName -p $Port -U $Username -d $Database -v ON_ERROR_STOP=1 -f (Join-Path $ProjectRoot 'Database\002_core_functions.sql')
    if ($LASTEXITCODE -ne 0) { throw 'Core functions deployment failed.' }

    & $Psql -h $HostName -p $Port -U $Username -d $Database -v ON_ERROR_STOP=1 -f (Join-Path $ProjectRoot 'Database\003_multilingual.sql')
    if ($LASTEXITCODE -ne 0) { throw 'Multilingual database deployment failed.' }

    $ConnectionString = 'Host=' + $HostName + ';Port=' + $Port + ';Database=' + $Database + ';Username=' + $Username + ';Password=' + $Password + ';Search Path=' + $Schema + ';'
    [Environment]::SetEnvironmentVariable('SOCIETY360_DB_CONNECTION', $ConnectionString, 'User')

    Write-Host ''
    Write-Host 'Database connection verified.'
    Write-Host 'Foundation schema and core functions deployed.'
    Write-Host 'SOCIETY360_DB_CONNECTION configured for the current Windows user.'
    Write-Host 'Restart the Society360 application after this script completes.'
} finally {
    Remove-Item Env:PGPASSFILE -ErrorAction SilentlyContinue
    if (Test-Path $PgPass) { Remove-Item $PgPass -Force -ErrorAction SilentlyContinue }
    $Password = $null
    $SecurePassword = $null
}

[executed on device: Sandman (3c28f028-a467-4934-be2f-752a8db6b6a8)]