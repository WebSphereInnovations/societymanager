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

$SecureAdminPassword = Read-Host 'Enter initial Super Admin password for Rahul' -AsSecureString
$AdminBSTR = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureAdminPassword)
try { $AdminPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($AdminBSTR) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($AdminBSTR) }

$PgPass = Join-Path $env:TEMP ('society360-pgpass-' + [guid]::NewGuid().ToString('N') + '.conf')
try {
    ($HostName + ':' + $Port + ':' + $Database + ':' + $Username + ':' + $Password) | Set-Content -Path $PgPass -Encoding ascii -NoNewline
    $env:PGPASSFILE = $PgPass
    & $Psql -h $HostName -p $Port -U $Username -d $Database -v ON_ERROR_STOP=1 -c "select current_database(), current_user, current_schema();"
    if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL connection failed.' }

    foreach ($file in @(
        '001_society360_foundation.sql',
        '002_core_functions.sql',
        '003_multilingual.sql',
        '005_complete_demo.sql',
        '006_migration_import.sql',
        '004_security_auth.sql'
    )) {
        & $Psql -h $HostName -p $Port -U $Username -d $Database -v ON_ERROR_STOP=1 -f (Join-Path $ProjectRoot ('Database\' + $file))
        if ($LASTEXITCODE -ne 0) { throw ('Database deployment failed: ' + $file) }
    }

    $env:PGPASSWORD = $Password
    $adminSql = "select society_manager.fn_create_super_admin('Rahul','Rahul', '$AdminPassword');"
    & $Psql -h $HostName -p $Port -U $Username -d $Database -v ON_ERROR_STOP=1 -c $adminSql
    if ($LASTEXITCODE -ne 0) { throw 'Super Admin initialization failed.' }
    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue

    $ConnectionString = 'Host=' + $HostName + ';Port=' + $Port + ';Database=' + $Database + ';Username=' + $Username + ';Password=' + $Password + ';Search Path=' + $Schema + ';'
    [Environment]::SetEnvironmentVariable('SOCIETY360_DB_CONNECTION', $ConnectionString, 'User')

    Write-Host ''
    Write-Host 'Database schema, functions, demo data and authentication deployed.'
    Write-Host 'Super Admin Rahul initialized.'
    Write-Host 'Restart Society360 so it reads the new connection setting.'
} finally {
    Remove-Item Env:PGPASSFILE -ErrorAction SilentlyContinue
    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue    if (Test-Path $PgPass) { Remove-Item $PgPass -Force -ErrorAction SilentlyContinue }
    $Password = $null
    $SecurePassword = $null
    $AdminPassword = $null
    $SecureAdminPassword = $null
}