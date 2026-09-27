using System.Security.Claims;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
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
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddFixedWindowLimiter("public-auth",o =>
    {
        o.PermitLimit=10;
        o.Window=TimeSpan.FromMinutes(1);
        o.QueueLimit=0;
        o.AutoReplenishment=true;
    });
});
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.Cookie.Name = "society360_auth";
        options.Cookie.HttpOnly = true;
        options.Cookie.SameSite = SameSiteMode.Lax;
        options.Cookie.SecurePolicy = CookieSecurePolicy.SameAsRequest;
        options.Cookie.IsEssential = true;
        options.ExpireTimeSpan = TimeSpan.FromHours(8);
        options.SlidingExpiration = false;
        options.LoginPath = "/login.html";
        options.AccessDeniedPath = "/login.html";
    });

var app = builder.Build();

var forwardedHeaders = new ForwardedHeadersOptions
{
    ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto,
    ForwardLimit = 2
};
forwardedHeaders.KnownNetworks.Clear();
forwardedHeaders.KnownProxies.Clear();
app.UseForwardedHeaders(forwardedHeaders);
app.UseAuthentication();
app.UseRouting();
app.UseRateLimiter();

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

app.MapPost("/api/auth/login", async (LoginRequest request, AuthService auth, HttpResponse response, HttpContext httpContext, CancellationToken ct) =>
{
    if (!auth.IsConfigured)
        return Results.Problem("Database is not configured.",statusCode:503);

    if (string.IsNullOrWhiteSpace(request.Login) || string.IsNullOrWhiteSpace(request.Password))
        return Results.BadRequest(new { message = "Login name and password are required." });

    var ip = httpContext.Connection.RemoteIpAddress?.ToString() ?? "";
    var userAgent = httpContext.Request.Headers.UserAgent.ToString();
    var user = await auth.AuthenticateAsync(request.Login.Trim(),request.Password,ct);
    if (user is null)
    {
        var attempted = await auth.FindUserByLoginAsync(request.Login.Trim(),ct);
        await auth.RecordLoginFailureAsync(attempted?.UserId,attempted?.SocietyId,request.Login.Trim(),ip,userAgent,"Invalid credentials",ct);
        return Results.Unauthorized();
    }

    var societies = await auth.GetSocietiesAsync(user.UserId,ct);
    long? selected = societies.FirstOrDefault(x=>x.IsDefault)?.SocietyId;
    if (selected is null && societies.Count==1) selected=societies[0].SocietyId;
    var sessionInfo = await auth.CreateSessionAsync(user.UserId,selected,ct);
    var token = sessionInfo.RawToken;
    await auth.RecordLoginSuccessAsync(user.UserId,selected,user.LoginName,ip,userAgent,sessionInfo.SessionId,ct);
    AuthGuard.ClearCookie(response);
    var claims = new List<Claim>
    {
        new(ClaimTypes.NameIdentifier,user.UserId.ToString()),
        new(ClaimTypes.Name,user.LoginName),
        new(ClaimTypes.Role,user.RoleCode),
        new("society360_display_name",user.DisplayName),
        new("society360_session_token",token),
        new("society360_society_id",selected?.ToString() ?? string.Empty)
    };
    var identity = new ClaimsIdentity(claims,CookieAuthenticationDefaults.AuthenticationScheme);
    await httpContext.SignInAsync(
        CookieAuthenticationDefaults.AuthenticationScheme,
        new ClaimsPrincipal(identity),
        new AuthenticationProperties
        {
            IsPersistent = true,
            ExpiresUtc = DateTimeOffset.UtcNow.AddHours(8)
        });
    var permissions = await auth.GetPermissionsAsync(user.UserId,ct);
    var route=await auth.GetLoginRouteAsync(user.UserId,ct);
    var safeRoute = route?.RoutePath ?? user.RoleCode switch
    {
        "SUPER_ADMIN" => "/",
        "SOCIETY_ADMIN" => "/modules/society-admin/index.html",
        "BILLING_ADMIN" or "COLLECTOR" => "/modules/cashier/index.html",
        "RESIDENT" => "/modules/customer/index.html",
        _ => "/login.html"
    };
    return Results.Ok(new {
        user = new { user.UserId,user.LoginName,user.DisplayName,user.RoleCode,user.PreferredLanguage },
        societies, selectedSocietyId=selected, permissions,
        route = safeRoute
    });
}).RequireRateLimiting("public-auth");

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
    var token = http.User.FindFirstValue("society360_session_token");
    if (string.IsNullOrWhiteSpace(token) && http.Request.Cookies.TryGetValue("society360_session",out var legacyToken))
        token=legacyToken;
    if (string.IsNullOrWhiteSpace(token)) return Results.Unauthorized();
    if (!await auth.SelectSocietyAsync(token,request.SocietyId,ct))
        return Results.Forbid();
    return Results.Ok(new { societyId=request.SocietyId });
});

app.MapGet("/api/public/subscription-plans", async (SocietyDb db, CancellationToken ct) =>
{
    if (!db.IsConfigured) return Results.Problem("Database is not configured.",statusCode:503);
    await using var cn = db.CreateConnection();
    await cn.OpenAsync(ct);
    await using var cmd = new NpgsqlCommand("select * from society_manager.fn_subscription_plans()",cn);
    await using var reader = await cmd.ExecuteReaderAsync(ct);
    var plans = new List<object>();
    while (await reader.ReadAsync(ct))
        plans.Add(new {
            planCode=reader.GetString(0),planName=reader.GetString(1),durationDays=reader.GetInt32(2),
            price=reader.GetDecimal(3),maxFlats=reader.IsDBNull(4)?(int?)null:reader.GetInt32(4),
            maxUsers=reader.IsDBNull(5)?(int?)null:reader.GetInt32(5),features=reader.GetFieldValue<System.Text.Json.JsonDocument>(6).RootElement
        });
    return Results.Ok(plans);
});

app.MapPost("/api/public/create-society", async (CreateSocietyRequest request, SocietyDb db, AuthService auth, HttpResponse response, HttpContext httpContext, CancellationToken ct) =>
{
    if (!db.IsConfigured) return Results.Problem("Database is not configured.",statusCode:503);
    if (string.IsNullOrWhiteSpace(request.SocietyName) || string.IsNullOrWhiteSpace(request.AdminName) ||
        string.IsNullOrWhiteSpace(request.LoginName) || string.IsNullOrWhiteSpace(request.Password) ||
        string.IsNullOrWhiteSpace(request.PlanCode))
        return Results.BadRequest(new { message="Society name, administrator, login, password and plan are required." });
    try
    {
        await using var cn = db.CreateConnection();
        await cn.OpenAsync(ct);
        await using var cmd = new NpgsqlCommand("call society_manager.sp_create_society_signup(@society_name,@email,@phone,@address,@admin_name,@login_name,@password,@plan_code,NULL,NULL,NULL,NULL,NULL,NULL,NULL)",cn);
        cmd.Parameters.AddWithValue("society_name",request.SocietyName.Trim());
        cmd.Parameters.AddWithValue("email",(object?)request.Email?.Trim()??DBNull.Value);
        cmd.Parameters.AddWithValue("phone",(object?)request.Phone?.Trim()??DBNull.Value);
        cmd.Parameters.AddWithValue("address",(object?)request.Address?.Trim()??DBNull.Value);
        cmd.Parameters.AddWithValue("admin_name",request.AdminName.Trim());
        cmd.Parameters.AddWithValue("login_name",request.LoginName.Trim());
        cmd.Parameters.AddWithValue("password",request.Password);
        cmd.Parameters.AddWithValue("plan_code",request.PlanCode.Trim());
        await using var reader=await cmd.ExecuteReaderAsync(ct);
        if(!await reader.ReadAsync(ct)) return Results.BadRequest(new { message="Society creation failed." });
        var createdSocietyId=reader.GetInt64(0);
        var createdUserId=reader.GetInt64(1);
        var sessionInfo=await auth.CreateSessionAsync(createdUserId,createdSocietyId,ct);
        var token=sessionInfo.RawToken;
        await auth.RecordLoginSuccessAsync(createdUserId,createdSocietyId,request.LoginName.Trim(),httpContext.Connection.RemoteIpAddress?.ToString()??"",httpContext.Request.Headers.UserAgent.ToString(),sessionInfo.SessionId,ct);
        AuthGuard.ClearCookie(response);
        var identity=new ClaimsIdentity(new[]
        {
            new Claim(ClaimTypes.NameIdentifier,createdUserId.ToString()),
            new Claim(ClaimTypes.Name,request.LoginName.Trim()),
            new Claim(ClaimTypes.Role,"SOCIETY_ADMIN"),
            new Claim("society360_session_token",token),
            new Claim("society360_society_id",createdSocietyId.ToString())
        },CookieAuthenticationDefaults.AuthenticationScheme);
        await httpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme,
            new ClaimsPrincipal(identity),
            new AuthenticationProperties { IsPersistent=true,ExpiresUtc=DateTimeOffset.UtcNow.AddHours(8) });
        return Results.Ok(new {
            societyId=createdSocietyId,userId=createdUserId,societyCode=reader.GetString(2),
            planCode=reader.GetString(3),planName=reader.GetString(4),amount=reader.GetDecimal(5),endDate=reader.GetDateTime(6).ToString("yyyy-MM-dd"),
            paymentStatus="Pending",route="/modules/society-admin/index.html"
        });
    }
    catch(PostgresException ex)
    {
        return Results.BadRequest(new { message=ex.MessageText });
    }
}).RequireRateLimiting("public-auth");

app.MapGet("/api/subscription/current", async (AuthService auth, HttpContext http, CancellationToken ct) =>
{
    var session=await AuthGuard.Get(http,auth,ct);
    if(session is null) return Results.Unauthorized();
    if(session.RoleCode is not ("SOCIETY_ADMIN" or "SUPER_ADMIN") || session.SocietyId is null) return Results.Forbid();
    await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));
    await cn.OpenAsync(ct);
    await using var cmd=new NpgsqlCommand("select * from society_manager.fn_current_society_subscription(@society)",cn);
    cmd.Parameters.AddWithValue("society",session.SocietyId.Value);
    await using var r=await cmd.ExecuteReaderAsync(ct);
    if(!await r.ReadAsync(ct)) return Results.NotFound(new { message="No active subscription found." });
    return Results.Ok(new {
        subscriptionId=r.GetInt64(0),planCode=r.GetString(1),planName=r.GetString(2),
        startDate=r.GetDateTime(3).ToString("yyyy-MM-dd"),endDate=r.GetDateTime(4).ToString("yyyy-MM-dd"),
        amount=r.GetDecimal(5),paymentStatus=r.GetString(6),paymentReference=r.IsDBNull(7)?null:r.GetString(7),
        daysRemaining=r.GetInt32(8)
    });
});

app.MapPost("/api/subscription/payment", async (SubscriptionPaymentRequest request, AuthService auth, HttpContext http, CancellationToken ct) =>
{
    var session=await AuthGuard.Get(http,auth,ct);
    if(session is null) return Results.Unauthorized();
    if(session.RoleCode is not ("SOCIETY_ADMIN" or "SUPER_ADMIN") || session.SocietyId is null) return Results.Forbid();
    if(request.Amount<=0 || string.IsNullOrWhiteSpace(request.PaymentMode))
        return Results.BadRequest(new { message="Payment amount and payment method are required." });
    try
    {
        await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));
        await cn.OpenAsync(ct);
        await using var cmd=new NpgsqlCommand("call society_manager.sp_record_subscription_payment(@society,@subscription,@amount,@mode,@reference,@user,NULL,NULL,NULL)",cn);
        cmd.Parameters.AddWithValue("society",session.SocietyId.Value);
        cmd.Parameters.AddWithValue("subscription",request.SubscriptionId);
        cmd.Parameters.AddWithValue("amount",request.Amount);
        cmd.Parameters.AddWithValue("mode",request.PaymentMode.Trim());
        cmd.Parameters.AddWithValue("reference",(object?)request.ReferenceNo?.Trim()??DBNull.Value);
        cmd.Parameters.AddWithValue("user",session.UserId);
        await using var r=await cmd.ExecuteReaderAsync(ct);
        if(!await r.ReadAsync(ct)) return Results.BadRequest(new { message="Payment could not be recorded." });
        return Results.Ok(new { paymentId=r.GetInt64(0),subscriptionId=r.GetInt64(1),status=r.GetString(2) });
    }
    catch(PostgresException ex)
    {
        return Results.BadRequest(new { message=ex.MessageText });
    }
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
    var session=await AuthGuard.Get(http,auth,ct);
    var token=http.User.FindFirstValue("society360_session_token");
    if (string.IsNullOrWhiteSpace(token) && http.Request.Cookies.TryGetValue("society360_session",out var legacyToken))
        token=legacyToken;
    if (!string.IsNullOrWhiteSpace(token))
        await auth.RevokeSessionAsync(token,ct);
    await http.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
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
app.MapGet("/api/subscription/payment", () => Results.StatusCode(StatusCodes.Status405MethodNotAllowed));
app.Map("/api/{**path}", () => Results.NotFound(new { message="API endpoint not found." }));
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

if (args.Contains("--apply-society-signup-schema", StringComparer.OrdinalIgnoreCase))
{
    var cs=Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION");
    if (string.IsNullOrWhiteSpace(cs)) throw new InvalidOperationException("SOCIETY360_DB_CONNECTION is not configured.");
    await using var connection=new NpgsqlConnection(cs); await connection.OpenAsync();
    foreach(var file in new[]{"013_society_signup_and_plans.sql","014_society_admin_provision.sql","015_subscription_payment.sql"})
    {
        var sql=await File.ReadAllTextAsync(Path.Combine(Directory.GetCurrentDirectory(),"Database",file));
        await using var command=new NpgsqlCommand(sql,connection);
        await command.ExecuteNonQueryAsync();
    }
    Console.WriteLine("Society signup, subscription plans and admin provisioning schema applied."); return;
}

if (args.Contains("--provision-new-society-admin", StringComparer.OrdinalIgnoreCase))
{
    var cs=Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION");
    if (string.IsNullOrWhiteSpace(cs)) throw new InvalidOperationException("SOCIETY360_DB_CONNECTION is not configured.");
    await using var connection=new NpgsqlConnection(cs); await connection.OpenAsync();
    await using var command=new NpgsqlCommand("select login_name,generated_password,society_name from society_manager.fn_provision_new_society_admin(@society_code,@login_base)",connection);
    command.Parameters.AddWithValue("society_code","LAKEVIEW");
    command.Parameters.AddWithValue("login_base","societyadmin360");
    await using var reader=await command.ExecuteReaderAsync();
    if(await reader.ReadAsync())
    {
        Console.WriteLine("SOCIETY_ADMIN_LOGIN="+reader.GetString(0));
        Console.WriteLine("SOCIETY_ADMIN_PASSWORD="+reader.GetString(1));
        Console.WriteLine("SOCIETY_ADMIN_SOCIETY="+reader.GetString(2));
    }
    return;
}

app.Run();

public sealed record LoginRequest(string Login,string Password);
public sealed record ChangeLoginRequest(string CurrentPassword,string NewLogin);
public sealed record SocietySelectRequest(long SocietyId);
public sealed record CreateSocietyRequest(
    string SocietyName,string AdminName,string LoginName,string Password,string PlanCode,
    string? Email,string? Phone,string? Address);
public sealed record ChangePasswordRequest(string CurrentPassword,string NewPassword);
public sealed record SubscriptionPaymentRequest(long SubscriptionId,decimal Amount,string PaymentMode,string? ReferenceNo);
public sealed record ConnectionRequest(string Value);
