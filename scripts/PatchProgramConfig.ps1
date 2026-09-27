$p='C:\Users\Delta\Society360\Program.cs'
$s=Get-Content $p -Raw
$s=$s.Replace('app.MapSocietyAdminEndpoints();','app.MapSocietyAdminEndpoints();`r`napp.MapOperationalConfigEndpoints();')
Set-Content -Path $p -Value $s -NoNewline
