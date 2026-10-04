[Reading 6 lines from start (total: 6 lines, 0 remaining)]

$ErrorActionPreference='Stop'
$env:SOCIETY360_DB_CONNECTION=[Environment]::GetEnvironmentVariable('SOCIETY360_DB_CONNECTION','User')
if([string]::IsNullOrWhiteSpace($env:SOCIETY360_DB_CONNECTION)){throw 'SOCIETY360_DB_CONNECTION is not configured for this Windows user.'}
$env:ASPNETCORE_URLS='http://0.0.0.0:5180'
Set-Location 'C:\Users\Delta\Society360'
& 'C:\Users\Delta\.dotnet\dotnet.exe' run --no-launch-profile --no-build @args

[executed on device: Sandman (3c28f028-a467-4934-be2f-752a8db6b6a8)]