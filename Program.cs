using Microsoft.AspNetCore.DataProtection;
using Npgsql;
using Microsoft.AspNetCore.Antiforgery;
using Microsoft.AspNetCore.HttpOverrides;
using Society360.Data;
using Society360.Modules.Migration;
using Society360.Modules.SocietyAdmin;
using Society360.Modules.Customer;
using Society360.Modules.Cashier;
using Society360.Modules.Platform;
using Society360.Security;

var builder = WebApplication.CreateBuilder(args);

var keyPath = Path.Combine(
    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
    "Society360","keys");
Directory.CreateDirectory(keyPath);

var dataProtection = builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo(keyPath))
    .SetApplicationName("Society360");
if (OperatingSystem.IsWindows())
    dataProtection.ProtectKeysWithDpapi();

builder.Services.AddSingleton<SocietyDb>();
builder.Services.AddSingleton<AuthService>();
builder.Services.AddSingleton<ConnectionStringProtector>();
builder.Services.AddSingleton<MigrationService>();
builder.Services.AddAntiforgery(options => options.HeaderName = "X-CSRF-TOKEN");

var app = builder.Build();

app.UseForwardedHeaders(new ForwardedHeadersOptions
{
    ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto
});

app.Use(async (context,next) =>
{
    var path=context.Request.Path.Value ?? "";
    var protectedArea = path.StartsWith("/modules/society-admin",StringComparison.OrdinalIgnoreCase)
        || path.StartsWith("/modules/cashier",StringComparison.OrdinalIgnoreCase)
        || path.StartsWith("/modules/customer",StringComparison.OrdinalIgnoreCase)
        || path.Equals("/",StringComparison.OrdinalIgnoreCase)
        || path.Equals("/index.html",StringComparison.OrdinalIgnoreCase);
    if(!protectedArea){await next();return;}
    var auth=context.RequestServices.GetRequiredService<AuthService>();
    var session=await AuthGuard.Get(context,auth,context.RequestAborted);
    if(session is null){context.Response.Redirect("/login.html");return;}
    var target=(path.Equals("/",StringComparison.OrdinalIgnoreCase) || path.Equals("/index.html",StringComparison.OrdinalIgnoreCase)) ? "/"
        : path.StartsWith("/modules/society-admin",StringComparison.OrdinalIgnoreCase) ? "/modules/society-admin/index.html"
        : path.StartsWith("/modules/cashier",StringComparison.OrdinalIgnoreCase) ? "/modules/cashier/index.html"
        : "/modules/customer/index.html";
    var allowed=(target=="/" && session.RoleCode=="SUPER_ADMIN")
        || (target.Contains("society-admin") && session.RoleCode is "SUPER_ADMIN" or "SOCIETY_ADMIN")
        || (target.Contains("cashier") && session.RoleCode is "BILLING_ADMIN" or "COLLECTOR")
        || (target.Contains("customer") && session.RoleCode=="RESIDENT");
    if(!allowed){var route=await auth.GetLoginRouteAsync(session.UserId,context.RequestAborted);context.Response.Redirect(route?.RoutePath ?? "/login.html");return;}
    await next();
});
app.UseDefaultFiles();
app.UseStaticFiles();
app.MapSocietyAdminEndpoints();
app.MapCustomerEndpoints();
app.MapCashierEndpoints();
app.MapPaymentEndpoints();
app.MapPlatformEndpoints();

app.MapGet("/api/health", (SocietyDb db) => Results.Ok(new
{    application = "Society360",
    status = "online",
    databaseConfigured = db.IsConfigured,
    utc = DateTimeOffset.UtcNow
}));

app.MapPost("/api/auth/login", async (LoginRequest request, AuthService auth, HttpResponse response, CancellationToken ct) =>
{
    if (!auth.IsConfigured)
        return Results.Problem("Database is not configured.",statusCode:503);

    if (string.IsNullOrWhiteSpace(request.Login) || string.IsNullOrWhiteSpace(request.Password))
        return Results.BadRequest(new { message = "Login name and password are required." });

    var user = await auth.AuthenticateAsync(request.Login.Trim(),request.Password,ct);
    if (user is null)
        return Results.Unauthorized();

    var societies = await auth.GetSocietiesAsync(user.UserId,ct);
    long? selected = societies.FirstOrDefault(x=>x.IsDefault)?.SocietyId;
    if (selected is null && societies.Count==1) selected=societies[0].SocietyId;
    var token = await auth.CreateSessionAsync(user.UserId,selected,ct);
    AuthGuard.SetCookie(response,token);
    var permissions = await auth.GetPermissionsAsync(user.UserId,ct);
    var route=await auth.GetLoginRouteAsync(user.UserId,ct);
    return Results.Ok(new {
        user = new { user.UserId,user.LoginName,user.DisplayName,user.RoleCode,user.PreferredLanguage },
        societies, selectedSocietyId=selected, permissions,
        route = route?.RoutePath ?? "/login.html"
    });
});

app.MapGet("/api/auth/me", async (AuthService auth, HttpContext http, CancellationToken ct) =>
{
    var session = await AuthGuard.Get(http,auth,ct);
    if (session is null) return Results.Unauthorized();
    var societies = await auth.GetSocietiesAsync(session.UserId,ct);
    var permissions = await auth.GetPermissionsAsync(session.UserId,ct);
    return Results.Ok(new { session,societies,permissions });
});

app.MapPost("/api/auth/select-society", async (SocietySelectRequest request, AuthService auth, HttpContext http, CancellationToken ct) =>
{
    var session = await AuthGuard.Get(http,auth,ct);
    if (session is null) return Results.Unauthorized();
    if (!await auth.SelectSocietyAsync(http.Request.Cookies["society360_session"]!,request.SocietyId,ct))
        return Results.Forbid();
    return Results.Ok(new { societyId=request.SocietyId });
});

app.MapPost("/api/auth/change-login", async (ChangeLoginRequest request, AuthService auth, HttpContext http, CancellationToken ct) =>
{
    var session=await AuthGuard.Get(http,auth,ct);
    if (session is null) return Results.Unauthorized();
    if (string.IsNullOrWhiteSpace(request.CurrentPassword) || string.IsNullOrWhiteSpace(request.NewLogin))
        return Results.BadRequest(new { message="Login name and current password are required." });
    if (!await auth.ChangeLoginNameAsync(session.UserId,request.CurrentPassword,request.NewLogin.Trim(),ct))
        return Results.BadRequest(new { message="Login name change failed. It may already exist or current password is incorrect." });
    return Results.Ok(new { message="Login name changed successfully." });
});

app.MapPost("/api/auth/change-password", async (ChangePasswordRequest request, AuthService auth, HttpContext http, CancellationToken ct) =>{
    var session = await AuthGuard.Get(http,auth,ct);
    if (session is null) return Results.Unauthorized();
    if (string.IsNullOrWhiteSpace(request.CurrentPassword) || string.IsNullOrWhiteSpace(request.NewPassword) ||
        request.NewPassword.Length < 10)
        return Results.BadRequest(new { message="New password must contain at least 10 characters." });
    if (!await auth.ChangePasswordAsync(session.UserId,request.CurrentPassword,request.NewPassword,ct))
        return Results.BadRequest(new { message="Current password is incorrect." });
    return Results.Ok(new { message="Password changed successfully." });
});

app.MapPost("/api/auth/logout", async (AuthService auth, HttpContext http, CancellationToken ct) =>
{
    if (http.Request.Cookies.TryGetValue("society360_session",out var token))
        await auth.RevokeSessionAsync(token,ct);
    AuthGuard.ClearCookie(http.Response);
    return Results.Ok(new { success=true });
});

app.MapPost("/api/security/protect-connection", async (ConnectionRequest request, ConnectionStringProtector protector, AuthService auth, HttpContext http, CancellationToken ct) =>
{
    var session=await AuthGuard.Get(http,auth,ct);
    if (session is null || session.RoleCode!="SUPER_ADMIN") return Results.Forbid();
    if (string.IsNullOrWhiteSpace(request.Value)) return Results.BadRequest();
    return Results.Ok(new { value=protector.Protect(request.Value) });});

app.MapPost("/api/security/unprotect-connection", async (ConnectionRequest request, ConnectionStringProtector protector, AuthService auth, HttpContext http, CancellationToken ct) =>
{
    var session=await AuthGuard.Get(http,auth,ct);
    if (session is null || session.RoleCode!="SUPER_ADMIN") return Results.Forbid();
    try { return Results.Ok(new { value=protector.Unprotect(request.Value) }); }
    catch { return Results.BadRequest(new { message="Encrypted value is invalid or was created by another key ring." }); }
});

app.MapGet("/api/societies", async (SocietyDb db, AuthService auth, HttpContext http, CancellationToken ct) =>
{
    var session=await AuthGuard.Get(http,auth,ct);
    if (session is null) return Results.Unauthorized();
    if (!db.IsConfigured) return Results.Ok(new { configured=false,data=Array.Empty<object>() });
    return Results.Ok(new { configured=true,data=await auth.GetSocietiesAsync(session.UserId,ct) });
});

app.MapGet("/api/dashboard/{societyId:long}", async (long societyId, DateOnly? month, SocietyDb db, AuthService auth, HttpContext http, CancellationToken ct) =>
{
    var session=await AuthGuard.Get(http,auth,ct);
    if (session is null) return Results.Unauthorized();
    if (session.RoleCode!="SUPER_ADMIN" && session.SocietyId!=societyId) return Results.Forbid();
    if (!db.IsConfigured) return Results.Ok(new { configured=false,data=(object?)null });
    var result=await db.GetDashboardSummaryAsync(societyId,month??new DateOnly(DateTime.UtcNow.Year,DateTime.UtcNow.Month,1),ct);    return Results.Ok(new { configured=true,data=result });
});

app.MapGet("/api/security/csrf", (IAntiforgery antiforgery, HttpContext http) =>
{
    var token=antiforgery.GetAndStoreTokens(http);
    return Results.Ok(new { token=token.RequestToken });
});

app.MapPost("/api/migration/preview", async (HttpRequest request, MigrationService migration, AuthService auth, HttpContext http, IAntiforgery antiforgery, CancellationToken ct) =>
{
    var session=await AuthGuard.Get(http,auth,ct);
    if (session is null) return Results.Unauthorized();
    try { await antiforgery.ValidateRequestAsync(http); } catch { return Results.BadRequest(new { message="Security token expired. Refresh the page and try again." }); }
    if (!request.HasFormContentType) return Results.BadRequest(new { message="Upload an Excel file." });
    var form=await request.ReadFormAsync(ct); var file=form.Files["file"];
    if (file is null || file.Length==0) return Results.BadRequest(new { message="Excel file is required." });
    await using var stream=file.OpenReadStream();
    var rows=migration.ReadExcel(stream,file.FileName);
    return Results.Ok(new { file=file.FileName, total=rows.Count, rows=rows.Take(100) });
});

app.MapPost("/api/migration/import", async (HttpRequest request, MigrationService migration, AuthService auth, HttpContext http, IAntiforgery antiforgery, CancellationToken ct) =>
{
    var session=await AuthGuard.Get(http,auth,ct);
    if (session is null) return Results.Unauthorized();
    try { await antiforgery.ValidateRequestAsync(http); } catch { return Results.BadRequest(new { message="Security token expired. Refresh the page and try again." }); }
    if (session.RoleCode!="SUPER_ADMIN" && session.RoleCode!="SOCIETY_ADMIN") return Results.Forbid();
    if (!request.HasFormContentType) return Results.BadRequest();
    var form=await request.ReadFormAsync(ct); var file=form.Files["file"];
    if (file is null || file.Length==0) return Results.BadRequest(new { message="Excel file is required." });
    await using var stream=file.OpenReadStream();
    var rows=migration.ReadExcel(stream,file.FileName);
    if (rows.Count==0) return Results.BadRequest(new { message="No importable flat/owner rows found." });
    var societyId=session.SocietyId ?? 0;
    if (societyId==0) return Results.BadRequest(new { message="Select a society before migration." });
    var batch=await migration.CreateBatchAsync(societyId,session.UserId,file.FileName,rows,ct);
    var result=await migration.ImportAsync(batch,session.UserId,ct);
    return Results.Ok(new { batchId=batch,file=file.FileName,parsedRows=rows.Count,result });
});

app.MapGet("/login", () => Results.Redirect("/login.html"));
app.MapFallbackToFile("index.html");

if (args.Contains("--apply-migration-schema", StringComparer.OrdinalIgnoreCase))
{
    var cs=Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION");
    if (string.IsNullOrWhiteSpace(cs)) throw new InvalidOperationException("SOCIETY360_DB_CONNECTION is not configured.");
    await using var connection=new NpgsqlConnection(cs);
    await connection.OpenAsync();
    var sql=await File.ReadAllTextAsync(Path.Combine(Directory.GetCurrentDirectory(),"Database","006_migration_import.sql"));
    await using var command=new NpgsqlCommand(sql,connection);
    await command.ExecuteNonQueryAsync();
    Console.WriteLine("Migration schema applied.");
    return;
}

if (args.Contains("--apply-auth-routing-schema", StringComparer.OrdinalIgnoreCase))
{
    var cs=Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION");
    if (string.IsNullOrWhiteSpace(cs)) throw new InvalidOperationException("SOCIETY360_DB_CONNECTION is not configured.");
    await using var connection=new NpgsqlConnection(cs);
    await connection.OpenAsync();
    var sql=await File.ReadAllTextAsync(Path.Combine(Directory.GetCurrentDirectory(),"Database","Auth","006_login_routing_and_customer_portal.sql"));
    await using var command=new NpgsqlCommand(sql,connection);
    await command.ExecuteNonQueryAsync();
    Console.WriteLine("Auth routing and customer portal schema applied.");
    return;
}

if (args.Contains("--provision-demo-accounts", StringComparer.OrdinalIgnoreCase))
{
    var cs=Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION");
    if (string.IsNullOrWhiteSpace(cs)) throw new InvalidOperationException("SOCIETY360_DB_CONNECTION is not configured.");
    await using var connection=new NpgsqlConnection(cs);
    await connection.OpenAsync();
    await using var command=new NpgsqlCommand("select society_manager.fn_provision_demo_accounts()",connection);
    await command.ExecuteNonQueryAsync();
    Console.WriteLine("Demo accounts provisioned.");
    return;
}

if (args.Contains("--apply-society-admin-schema", StringComparer.OrdinalIgnoreCase))
{
    var cs=Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION");
    if (string.IsNullOrWhiteSpace(cs)) throw new InvalidOperationException("SOCIETY360_DB_CONNECTION is not configured.");
    await using var connection=new NpgsqlConnection(cs);
    await connection.OpenAsync();
    var sql=await File.ReadAllTextAsync(Path.Combine(Directory.GetCurrentDirectory(),"Database","SocietyAdmin","001_society_admin_procedures.sql"));
    await using var command=new NpgsqlCommand(sql,connection);
    await command.ExecuteNonQueryAsync();
    Console.WriteLine("Society Admin procedure schema applied.");
    return;
}

if (args.Contains("--provision-society-admin-demo", StringComparer.OrdinalIgnoreCase))
{
    var cs=Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION");
    if (string.IsNullOrWhiteSpace(cs)) throw new InvalidOperationException("SOCIETY360_DB_CONNECTION is not configured.");
    await using var connection=new NpgsqlConnection(cs);
    await connection.OpenAsync();
    var sql=await File.ReadAllTextAsync(Path.Combine(Directory.GetCurrentDirectory(),"Database","SocietyAdmin","002_demo_account.sql"));
    await using var command=new NpgsqlCommand(sql,connection);
    await using var reader=await command.ExecuteReaderAsync();
    if(await reader.ReadAsync())
    {
        Console.WriteLine("DEMO_LOGIN=lakeadmin");
        Console.WriteLine("DEMO_TOKEN="+reader.GetString(0));
    }
    return;
}

if (args.Contains("--apply-module-catalog", StringComparer.OrdinalIgnoreCase))
{
    var cs=Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION");
    if (string.IsNullOrWhiteSpace(cs)) throw new InvalidOperationException("SOCIETY360_DB_CONNECTION is not configured.");
    await using var connection=new NpgsqlConnection(cs); await connection.OpenAsync();
    foreach(var file in new[]{"009_full_module_catalog.sql","010_platform_subscription_demo.sql","011_cashier_customer_search_v2.sql","012_customer_flats.sql"})
    {
        var sql=await File.ReadAllTextAsync(Path.Combine(Directory.GetCurrentDirectory(),"Database","Modules",file));
        await using var command=new NpgsqlCommand(sql,connection); await command.ExecuteNonQueryAsync();
    }
    Console.WriteLine("Full module and role workspace schema applied."); return;
}

if (args.Contains("--apply-platform-demo", StringComparer.OrdinalIgnoreCase))
{
    var cs=Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION");
    if (string.IsNullOrWhiteSpace(cs)) throw new InvalidOperationException("SOCIETY360_DB_CONNECTION is not configured.");
    await using var connection=new NpgsqlConnection(cs); await connection.OpenAsync();
    var sql=await File.ReadAllTextAsync(Path.Combine(Directory.GetCurrentDirectory(),"Database","Modules","010_platform_subscription_demo.sql"));
    await using var command=new NpgsqlCommand(sql,connection); await command.ExecuteNonQueryAsync();
    Console.WriteLine("Platform subscription demo applied."); return;
}

app.Run();

public sealed record LoginRequest(string Login,string Password);
public sealed record ChangeLoginRequest(string CurrentPassword,string NewLogin);
public sealed record SocietySelectRequest(long SocietyId);
public sealed record ChangePasswordRequest(string CurrentPassword,string NewPassword);
public sealed record ConnectionRequest(string Value);
