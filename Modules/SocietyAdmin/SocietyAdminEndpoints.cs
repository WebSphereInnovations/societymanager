using System.Text.Json;
using Npgsql;
using Society360.Data;
using Society360.Security;

namespace Society360.Modules.SocietyAdmin;

public static class SocietyAdminEndpoints
{
    public static void MapSocietyAdminEndpoints(this WebApplication app)
    {
        app.MapGet("/api/society-admin/dashboard", async (AuthService auth, HttpContext http, CancellationToken ct) =>
        {
            var session=await AuthGuard.Get(http,auth,ct);
            if(session is null) return Results.Unauthorized();
            if(!await auth.HasPermissionAsync(session.UserId,"APP_DASHBOARD","VIEW",ct)) return Results.Forbid();
            var societyId=session.SocietyId;
            if(societyId is null) return Results.BadRequest(new {message="Select a society first."});
            await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));
            await cn.OpenAsync(ct);
            await using var cmd=new NpgsqlCommand("select * from society_manager.fn_society_admin_dashboard(@society_id,@month)",cn);
            cmd.Parameters.AddWithValue("society_id",societyId.Value);
            cmd.Parameters.AddWithValue("month",new DateOnly(DateTime.UtcNow.Year,DateTime.UtcNow.Month,1));
            await using var r=await cmd.ExecuteReaderAsync(ct);
            if(!await r.ReadAsync(ct)) return Results.NotFound();
            return Results.Ok(new {totalFlats=r.GetInt64(0),occupiedFlats=r.GetInt64(1),billed=r.GetDecimal(2),collected=r.GetDecimal(3),outstanding=r.GetDecimal(4),openComplaints=r.GetInt64(5),insideVisitors=r.GetInt64(6),parkingSlots=r.GetInt64(7)});
        });

        app.MapGet("/api/society-admin/customers", async (string? q, AuthService auth, HttpContext http, CancellationToken ct) =>
            await Query(auth,http,ct,"fn_society_admin_customer_search",q??"",7));
        app.MapGet("/api/society-admin/flats", async (string? q, AuthService auth, HttpContext http, CancellationToken ct) =>
            await Query(auth,http,ct,"fn_society_admin_flat_search",q??"",9));
        app.MapGet("/api/society-admin/bills", async (string? q, AuthService auth, HttpContext http, CancellationToken ct) =>
            await Query(auth,http,ct,"fn_society_admin_bill_list",q??"",10));
        app.MapGet("/api/society-admin/collection", async (DateOnly? from, DateOnly? to, AuthService auth, HttpContext http, CancellationToken ct) =>
            await Collection(auth,http,ct,from??DateOnly.FromDateTime(DateTime.UtcNow.AddDays(-30)),to??DateOnly.FromDateTime(DateTime.UtcNow)));
        app.MapGet("/api/society-admin/complaints", async (string? q, AuthService auth, HttpContext http, CancellationToken ct) =>
            await Query(auth,http,ct,"fn_society_admin_complaints",q??"",9));
        app.MapGet("/api/society-admin/visitors", async (string? q, AuthService auth, HttpContext http, CancellationToken ct) =>
            await Query(auth,http,ct,"fn_society_admin_visitors",q??"",9));
        app.MapGet("/api/society-admin/parking", async (string? q, AuthService auth, HttpContext http, CancellationToken ct) =>
            await Query(auth,http,ct,"fn_society_admin_parking",q??"",7));
        app.MapGet("/api/society-admin/customer/{customerId:long}", async (long customerId, AuthService auth, HttpContext http, CancellationToken ct) =>
            await Customer(auth,http,ct,customerId));
        app.MapGet("/api/society-admin/customer/{customerId:long}/service-history", async (long customerId, AuthService auth, HttpContext http, CancellationToken ct) =>
            await ServiceHistory(auth,http,ct,customerId));
        app.MapGet("/api/society-admin/security/logins", async (AuthService auth, HttpContext http, CancellationToken ct) =>
            await LoginSecurity(auth,http,ct));
        app.MapGet("/api/society-admin/config/charges", async (AuthService auth,HttpContext http,CancellationToken ct)=>await Config(auth,http,ct,"fn_society_charge_rules",9));
        app.MapGet("/api/society-admin/config/interest", async (AuthService auth,HttpContext http,CancellationToken ct)=>await Config(auth,http,ct,"fn_society_interest_rules",10));
        app.MapPost("/api/society-admin/config/charge", async (ChargeRuleRequest x,AuthService auth,HttpContext http,CancellationToken ct)=>await SaveCharge(x,auth,http,ct));
        app.MapPost("/api/society-admin/config/interest", async (InterestRuleRequest x,AuthService auth,HttpContext http,CancellationToken ct)=>await SaveInterest(x,auth,http,ct));
        app.MapGet("/api/society-admin/customer-account/{customerId:long}", async (long customerId, AuthService auth, HttpContext http, CancellationToken ct) =>
            await CustomerAccount(auth,http,ct,customerId));
        app.MapGet("/api/society-admin/customer-account/{customerId:long}/statement", async (long customerId, AuthService auth, HttpContext http, CancellationToken ct) =>
            await AccountStatement(auth,http,ct,customerId));
        app.MapGet("/api/society-admin/config/charge-types", async (AuthService auth,HttpContext http,CancellationToken ct) =>
            await Config(auth,http,ct,"fn_society_charge_types",8));
        app.MapPost("/api/society-admin/config/charge-type", async (ChargeTypeRequest x,AuthService auth,HttpContext http,CancellationToken ct) =>
            await SaveChargeType(x,auth,http,ct));
        app.MapGet("/api/society-admin/config/billing", async (AuthService auth,HttpContext http,CancellationToken ct) =>
            await Config(auth,http,ct,"fn_society_billing_config",6));
        app.MapPost("/api/society-admin/config/billing", async (BillingConfigRequest x,AuthService auth,HttpContext http,CancellationToken ct) =>
            await SaveBillingConfig(x,auth,http,ct));
        app.MapPost("/api/society-admin/billing/generate", async (BillingGenerateRequest x,AuthService auth,HttpContext http,CancellationToken ct) =>
            await GenerateBills(x,auth,http,ct));

        app.MapGet("/api/society-admin/accounts", async (string? q,AuthService auth,HttpContext http,CancellationToken ct) =>
            await AccountList(q??"",auth,http,ct));
        app.MapGet("/api/society-admin/accounts/types", async (AuthService auth,HttpContext http,CancellationToken ct) =>
            await AccountTypes(auth,http,ct));
        app.MapGet("/api/society-admin/accounts/rights", async (AuthService auth,HttpContext http,CancellationToken ct) =>
            await AccountRights(auth,http,ct));
        app.MapGet("/api/society-admin/accounts/{userId:long}/rights", async (long userId,AuthService auth,HttpContext http,CancellationToken ct) =>
            await AccountUserRights(userId,auth,http,ct));
        app.MapPost("/api/society-admin/accounts/save", async (AdminAccountRequest x,AuthService auth,HttpContext http,CancellationToken ct) =>
            await SaveAccount(x,auth,http,ct));
        app.MapPost("/api/society-admin/accounts/status", async (AdminAccountStatusRequest x,AuthService auth,HttpContext http,CancellationToken ct) =>
            await SetAccountStatus(x,auth,http,ct));
        app.MapPost("/api/society-admin/accounts/extend", async (AdminAccountExtendRequest x,AuthService auth,HttpContext http,CancellationToken ct) =>
            await ExtendAccount(x,auth,http,ct));

        app.MapGet("/api/society-admin/consumer-account/{customerId:long}", async (long customerId,AuthService auth,HttpContext http,CancellationToken ct) =>
            await ConsumerAccount(auth,http,ct,customerId));
    }

    static async Task<IResult> AccountList(string q,AuthService auth,HttpContext http,CancellationToken ct)
    {
        var s=await AuthGuard.Get(http,auth,ct);
        if(s is null)return Results.Unauthorized();
        if(s.SocietyId is null || !await auth.HasPermissionAsync(s.UserId,"ADM_ACCOUNTS","VIEW",ct))return Results.Forbid();
        await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));await cn.OpenAsync(ct);
        await using var cmd=new NpgsqlCommand("select * from society_manager.fn_admin_account_list(@society,@search)",cn);
        cmd.Parameters.AddWithValue("society",s.SocietyId.Value);cmd.Parameters.AddWithValue("search",q);
        return Results.Ok(await ReadRows(cmd,12,ct));
    }

    static async Task<IResult> AccountTypes(AuthService auth,HttpContext http,CancellationToken ct)
    {
        var s=await AuthGuard.Get(http,auth,ct);if(s is null)return Results.Unauthorized();
        if(!await auth.HasPermissionAsync(s.UserId,"ADM_ACCOUNTS","VIEW",ct))return Results.Forbid();
        await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));await cn.OpenAsync(ct);
        await using var cmd=new NpgsqlCommand("select * from society_manager.fn_admin_account_types()",cn);
        return Results.Ok(await ReadRows(cmd,3,ct));
    }

    static async Task<IResult> AccountRights(AuthService auth,HttpContext http,CancellationToken ct)
    {
        var s=await AuthGuard.Get(http,auth,ct);if(s is null)return Results.Unauthorized();
        if(!await auth.HasPermissionAsync(s.UserId,"ADM_ACCOUNTS","VIEW",ct))return Results.Forbid();
        await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));await cn.OpenAsync(ct);
        await using var cmd=new NpgsqlCommand("select * from society_manager.fn_admin_module_rights()",cn);
        return Results.Ok(await ReadRows(cmd,7,ct));
    }

    static async Task<IResult> AccountUserRights(long userId,AuthService auth,HttpContext http,CancellationToken ct)
    {
        var s=await AuthGuard.Get(http,auth,ct);if(s is null)return Results.Unauthorized();
        if(s.SocietyId is null || !await auth.HasPermissionAsync(s.UserId,"ADM_ACCOUNTS","VIEW",ct))return Results.Forbid();
        await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));await cn.OpenAsync(ct);
        await using var cmd=new NpgsqlCommand("select * from society_manager.fn_admin_account_rights(@user_id,@society)",cn);
        cmd.Parameters.AddWithValue("user_id",userId);cmd.Parameters.AddWithValue("society",s.SocietyId.Value);
        return Results.Ok(await ReadRows(cmd,7,ct));
    }

    static async Task<IResult> SaveAccount(AdminAccountRequest x,AuthService auth,HttpContext http,CancellationToken ct)
    {
        var s=await AuthGuard.Get(http,auth,ct);if(s is null)return Results.Unauthorized();
        if(s.SocietyId is null || !await auth.HasPermissionAsync(s.UserId,"ADM_ACCOUNTS","EDIT",ct))return Results.Forbid();
        if(x.UserId==0 && !await auth.HasPermissionAsync(s.UserId,"ADM_ACCOUNTS","ADD",ct))return Results.Forbid();
        await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));await cn.OpenAsync(ct);
        await using var cmd=new NpgsqlCommand("call society_manager.sp_admin_save_account(@society,@user,@login,@name,@email,@phone,@type,@password,@from,@to,@rights,@by,@remark,NULL)",cn);
        cmd.Parameters.AddWithValue("society",s.SocietyId.Value);cmd.Parameters.AddWithValue("user",(object?)x.UserId??DBNull.Value);
        cmd.Parameters.AddWithValue("login",x.LoginName);cmd.Parameters.AddWithValue("name",x.DisplayName);
        cmd.Parameters.AddWithValue("email",(object?)x.Email??DBNull.Value);cmd.Parameters.AddWithValue("phone",(object?)x.Phone??DBNull.Value);
        cmd.Parameters.AddWithValue("type",x.AccountType);cmd.Parameters.AddWithValue("password",(object?)x.Password??DBNull.Value);
        cmd.Parameters.AddWithValue("from",x.ValidFrom);cmd.Parameters.AddWithValue("to",(object?)x.ValidTo??DBNull.Value);
        cmd.Parameters.AddWithValue("rights",JsonSerializer.SerializeToDocument(x.Rights??[]).RootElement);
        cmd.Parameters.AddWithValue("by",s.UserId);cmd.Parameters.AddWithValue("remark",x.Remark??"");
        await cmd.ExecuteNonQueryAsync(ct);
        return Results.Ok(new {success=true});
    }

    static async Task<IResult> SetAccountStatus(AdminAccountStatusRequest x,AuthService auth,HttpContext http,CancellationToken ct)
    {
        var s=await AuthGuard.Get(http,auth,ct);if(s is null)return Results.Unauthorized();
        if(s.SocietyId is null || !await auth.HasPermissionAsync(s.UserId,"ADM_ACCOUNTS","EDIT",ct))return Results.Forbid();
        await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));await cn.OpenAsync(ct);
        await using var cmd=new NpgsqlCommand("call society_manager.sp_admin_set_account_status(@society,@user,@active,@by,@remark)",cn);
        cmd.Parameters.AddWithValue("society",s.SocietyId.Value);cmd.Parameters.AddWithValue("user",x.UserId);cmd.Parameters.AddWithValue("active",x.IsActive);cmd.Parameters.AddWithValue("by",s.UserId);cmd.Parameters.AddWithValue("remark",x.Remark??"");
        await cmd.ExecuteNonQueryAsync(ct);return Results.Ok(new {success=true});
    }

    static async Task<IResult> ExtendAccount(AdminAccountExtendRequest x,AuthService auth,HttpContext http,CancellationToken ct)
    {
        var s=await AuthGuard.Get(http,auth,ct);if(s is null)return Results.Unauthorized();
        if(s.SocietyId is null || !await auth.HasPermissionAsync(s.UserId,"ADM_ACCOUNTS","EDIT",ct))return Results.Forbid();
        await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));await cn.OpenAsync(ct);
        await using var cmd=new NpgsqlCommand("call society_manager.sp_admin_extend_account(@society,@user,@to,@by,@remark)",cn);
        cmd.Parameters.AddWithValue("society",s.SocietyId.Value);cmd.Parameters.AddWithValue("user",x.UserId);cmd.Parameters.AddWithValue("to",x.ValidTo);cmd.Parameters.AddWithValue("by",s.UserId);cmd.Parameters.AddWithValue("remark",x.Remark??"");
        await cmd.ExecuteNonQueryAsync(ct);return Results.Ok(new {success=true});
    }

    static async Task<IResult> ConsumerAccount(AuthService auth,HttpContext http,CancellationToken ct,long customerId)
    {
        var s=await AuthGuard.Get(http,auth,ct);if(s is null)return Results.Unauthorized();
        if(s.SocietyId is null || !await auth.HasPermissionAsync(s.UserId,"CRM_CUSTOMER_360","VIEW",ct))return Results.Forbid();
        await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));await cn.OpenAsync(ct);
        await using var cmd=new NpgsqlCommand("select * from society_manager.fn_consumer_account(@society,@customer)",cn);
        cmd.Parameters.AddWithValue("society",s.SocietyId.Value);cmd.Parameters.AddWithValue("customer",customerId);
        var flats=await ReadRows(cmd,18,ct);
        if(flats.Count==0)return Results.NotFound(new {message="Consumer not found in selected society."});
        return Results.Ok(new {customer=new {customerId=flats[0]["customer_id"],customerCode=flats[0]["customer_code"],fullName=flats[0]["full_name"],customerType=flats[0]["customer_type"],phone=flats[0]["phone"],email=flats[0]["email"]},flats});
    }

    static async Task<IResult> Query(AuthService auth,HttpContext http,CancellationToken ct,string fn,string q,int columns)
    {
        var session=await AuthGuard.Get(http,auth,ct);
        if(session is null) return Results.Unauthorized();
        if(session.SocietyId is null) return Results.BadRequest(new {message="Select a society first."});
        var module=fn switch
        {
            "fn_society_admin_customer_search"=>"CRM_CUSTOMER_SEARCH",
            "fn_society_admin_flat_search"=>"FLATS",
            "fn_society_admin_bill_list"=>"BILLING_MANAGEMENT",
            "fn_society_admin_complaints"=>"CRM_COMPLAINT",
            "fn_society_admin_visitors"=>"SEC_VISITOR",
            "fn_society_admin_parking"=>"PARKING_MANAGEMENT",
            _=>"DASHBOARD"
        };
        if(!await auth.HasPermissionAsync(session.UserId,module,"VIEW",ct)) return Results.Forbid();
        await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));
        await cn.OpenAsync(ct);
        await using var cmd=new NpgsqlCommand($"select * from society_manager.{fn}(@society_id,@search)",cn);
        cmd.Parameters.AddWithValue("society_id",session.SocietyId.Value);
        cmd.Parameters.AddWithValue("search",q);
        await using var r=await cmd.ExecuteReaderAsync(ct);
        var rows=new List<Dictionary<string,object?>>();
        while(await r.ReadAsync(ct))
        {
            var row=new Dictionary<string,object?>();
            for(var i=0;i<columns;i++){var v=r.IsDBNull(i)?null:r.GetValue(i);row[r.GetName(i)]=v is System.Net.IPAddress ip?ip.ToString():v;}
            rows.Add(row);
        }
        return Results.Ok(rows);
    }

    static async Task<IResult> Collection(AuthService auth,HttpContext http,CancellationToken ct,DateOnly from,DateOnly to)
    {
        var session=await AuthGuard.Get(http,auth,ct);
        if(session is null) return Results.Unauthorized();
        if(session.SocietyId is null || !await auth.HasPermissionAsync(session.UserId,"COLLECTION_MANAGEMENT","VIEW",ct)) return Results.Forbid();
        await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));
        await cn.OpenAsync(ct);
        await using var cmd=new NpgsqlCommand("select * from society_manager.fn_society_admin_collection(@society_id,@from_date,@to_date)",cn);
        cmd.Parameters.AddWithValue("society_id",session.SocietyId!.Value); cmd.Parameters.AddWithValue("from_date",from); cmd.Parameters.AddWithValue("to_date",to);
        return Results.Ok(await ReadRows(cmd,8,ct));
    }

    static async Task<IResult> Customer(AuthService auth,HttpContext http,CancellationToken ct,long customerId)
    {
        var session=await AuthGuard.Get(http,auth,ct);
        if(session is null) return Results.Unauthorized();
        if(session.RoleCode is not ("SOCIETY_ADMIN" or "SUPER_ADMIN")) return Results.Forbid();
        await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));
        await cn.OpenAsync(ct);
        await using var cmd=new NpgsqlCommand("select * from society_manager.fn_society_admin_customer_360(@society_id,@customer_id)",cn);
        cmd.Parameters.AddWithValue("society_id",session.SocietyId!.Value); cmd.Parameters.AddWithValue("customer_id",customerId);
        var rows=await ReadRows(cmd,17,ct); return Results.Ok(rows.FirstOrDefault());
    }

    static async Task<IResult> ServiceHistory(AuthService auth,HttpContext http,CancellationToken ct,long customerId)
    {
        var session=await AuthGuard.Get(http,auth,ct);
        if(session is null) return Results.Unauthorized();
        if(session.RoleCode is not ("SOCIETY_ADMIN" or "SUPER_ADMIN") || session.SocietyId is null) return Results.Forbid();
        await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));
        await cn.OpenAsync(ct);
        await using var cmd=new NpgsqlCommand("select * from society_manager.fn_customer_service_history(@society,@customer,NULL,@limit)",cn);
        cmd.Parameters.AddWithValue("society",session.SocietyId.Value);
        cmd.Parameters.AddWithValue("customer",customerId);
        cmd.Parameters.AddWithValue("limit",500);
        return Results.Ok(await ReadRows(cmd,17,ct));
    }

    static async Task<IResult> LoginSecurity(AuthService auth,HttpContext http,CancellationToken ct)
    {
        var session=await AuthGuard.Get(http,auth,ct);
        if(session is null) return Results.Unauthorized();
        if(session.RoleCode is not ("SOCIETY_ADMIN" or "SUPER_ADMIN") || session.SocietyId is null) return Results.Forbid();
        await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));
        await cn.OpenAsync(ct);
        await using var cmd=new NpgsqlCommand("select * from society_manager.fn_login_security_overview(@society)",cn);
        cmd.Parameters.AddWithValue("society",session.SocietyId.Value);
        return Results.Ok(await ReadRows(cmd,9,ct));
    }

    static async Task<IResult> SaveCharge(ChargeRuleRequest x,AuthService auth,HttpContext http,CancellationToken ct){var s=await AuthGuard.Get(http,auth,ct);if(s is null)return Results.Unauthorized();if(s.RoleCode is not ("SOCIETY_ADMIN" or "SUPER_ADMIN")||s.SocietyId is null)return Results.Forbid();await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));await cn.OpenAsync(ct);await using var cmd=new NpgsqlCommand("call society_manager.sp_society_save_charge_rule(@society,@code,@plan,@method,@rate,@from,@to,@scope,@value,@user,NULL)",cn);cmd.Parameters.AddWithValue("society",s.SocietyId.Value);cmd.Parameters.AddWithValue("code",x.ChargeCode);cmd.Parameters.AddWithValue("plan",x.PlanName);cmd.Parameters.AddWithValue("method",x.Method);cmd.Parameters.AddWithValue("rate",x.Rate);cmd.Parameters.AddWithValue("from",x.EffectiveFrom);cmd.Parameters.AddWithValue("to",(object?)x.EffectiveTo??DBNull.Value);cmd.Parameters.AddWithValue("scope",x.ScopeType);cmd.Parameters.AddWithValue("value",(object?)x.ScopeValue??DBNull.Value);cmd.Parameters.AddWithValue("user",s.UserId);return Results.Ok(new{success=true,id=await cmd.ExecuteScalarAsync(ct)});}
    static async Task<IResult> SaveInterest(InterestRuleRequest x,AuthService auth,HttpContext http,CancellationToken ct){var s=await AuthGuard.Get(http,auth,ct);if(s is null)return Results.Unauthorized();if(s.RoleCode is not ("SOCIETY_ADMIN" or "SUPER_ADMIN")||s.SocietyId is null)return Results.Forbid();await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));await cn.OpenAsync(ct);await using var cmd=new NpgsqlCommand("call society_manager.sp_society_save_interest_rule(@society,@name,@type,@rate,@frequency,@compound,@grace,@cap,@from,@to,@user,NULL)",cn);cmd.Parameters.AddWithValue("society",s.SocietyId.Value);cmd.Parameters.AddWithValue("name",x.RuleName);cmd.Parameters.AddWithValue("type",x.CalculationType);cmd.Parameters.AddWithValue("rate",x.Rate);cmd.Parameters.AddWithValue("frequency",x.Frequency);cmd.Parameters.AddWithValue("compound",x.SimpleOrCompound);cmd.Parameters.AddWithValue("grace",x.GraceDays);cmd.Parameters.AddWithValue("cap",(object?)x.CapAmount??DBNull.Value);cmd.Parameters.AddWithValue("from",x.EffectiveFrom);cmd.Parameters.AddWithValue("to",(object?)x.EffectiveTo??DBNull.Value);cmd.Parameters.AddWithValue("user",s.UserId);return Results.Ok(new{success=true,id=await cmd.ExecuteScalarAsync(ct)});}

    static async Task<IResult> CustomerAccount(AuthService auth,HttpContext http,CancellationToken ct,long customerId)
    {
        var session=await AuthGuard.Get(http,auth,ct);
        if(session is null) return Results.Unauthorized();
        if(session.RoleCode is not ("SOCIETY_ADMIN" or "SUPER_ADMIN") || session.SocietyId is null) return Results.Forbid();
        await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));
        await cn.OpenAsync(ct);
        await using var cmd=new NpgsqlCommand("select society_manager.fn_society_admin_customer_account(@society,@customer)",cn);
        cmd.Parameters.AddWithValue("society",session.SocietyId.Value);
        cmd.Parameters.AddWithValue("customer",customerId);
        await using var r=await cmd.ExecuteReaderAsync(ct);
        if(!await r.ReadAsync(ct)) return Results.NotFound(new {message="Customer account not found."});
        var json=r.GetFieldValue<JsonDocument>(0);
        return Results.Json(json.RootElement);
    }

    static async Task<IResult> AccountStatement(AuthService auth,HttpContext http,CancellationToken ct,long customerId)
    {
        var session=await AuthGuard.Get(http,auth,ct);
        if(session is null) return Results.Unauthorized();
        if(session.RoleCode is not ("SOCIETY_ADMIN" or "SUPER_ADMIN") || session.SocietyId is null) return Results.Forbid();
        await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));
        await cn.OpenAsync(ct);
        await using var cmd=new NpgsqlCommand("select * from society_manager.fn_society_admin_account_statement(@society,@customer)",cn);
        cmd.Parameters.AddWithValue("society",session.SocietyId.Value);
        cmd.Parameters.AddWithValue("customer",customerId);
        return Results.Ok(await ReadRows(cmd,9,ct));
    }

    static async Task<IResult> SaveChargeType(ChargeTypeRequest x,AuthService auth,HttpContext http,CancellationToken ct)
    {
        var s=await AuthGuard.Get(http,auth,ct);
        if(s is null) return Results.Unauthorized();
        if(s.RoleCode is not ("SOCIETY_ADMIN" or "SUPER_ADMIN") || s.SocietyId is null) return Results.Forbid();
        if(string.IsNullOrWhiteSpace(x.Code)||string.IsNullOrWhiteSpace(x.Name)) return Results.BadRequest(new {message="Code and name are required."});
        await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));
        await cn.OpenAsync(ct);
        await using var cmd=new NpgsqlCommand("call society_manager.sp_society_add_charge_type(@society,@code,@name,@method,@recurring,@taxable,@mandatory,@user,@remark,NULL)",cn);
        cmd.Parameters.AddWithValue("society",s.SocietyId.Value);cmd.Parameters.AddWithValue("code",x.Code.Trim());
        cmd.Parameters.AddWithValue("name",x.Name.Trim());cmd.Parameters.AddWithValue("method",x.Method);
        cmd.Parameters.AddWithValue("recurring",x.Recurring);cmd.Parameters.AddWithValue("taxable",x.Taxable);
        cmd.Parameters.AddWithValue("mandatory",x.Mandatory);cmd.Parameters.AddWithValue("user",s.UserId);
        cmd.Parameters.AddWithValue("remark",(object?)x.Remark??"");
        await using var r=await cmd.ExecuteReaderAsync(ct);
        if(!await r.ReadAsync(ct)) return Results.BadRequest(new {message="Charge head could not be saved."});
        return Results.Ok(new {success=true,chargeTypeId=r.GetInt64(0)});
    }

    static async Task<IResult> SaveBillingConfig(BillingConfigRequest x,AuthService auth,HttpContext http,CancellationToken ct)
    {
        var s=await AuthGuard.Get(http,auth,ct);
        if(s is null) return Results.Unauthorized();
        if(s.RoleCode is not ("SOCIETY_ADMIN" or "SUPER_ADMIN") || s.SocietyId is null) return Results.Forbid();
        await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));
        await cn.OpenAsync(ct);
        await using var cmd=new NpgsqlCommand("call society_manager.sp_society_save_billing_config(@society,@day,@due,@carry,@dpc,@user,NULL,@remark)",cn);
        cmd.Parameters.AddWithValue("society",s.SocietyId.Value);cmd.Parameters.AddWithValue("day",x.BillingDay);
        cmd.Parameters.AddWithValue("due",x.DueDays);cmd.Parameters.AddWithValue("carry",x.CarryArrear);
        cmd.Parameters.AddWithValue("dpc",x.AutoDpc);cmd.Parameters.AddWithValue("user",s.UserId);
        cmd.Parameters.AddWithValue("remark",(object?)x.Remark??"");
        await using var r=await cmd.ExecuteReaderAsync(ct);
        if(!await r.ReadAsync(ct)) return Results.BadRequest(new {message="Billing configuration could not be saved."});
        return Results.Ok(new {success=true,billingConfigId=r.GetInt64(0)});
    }

    static async Task<IResult> GenerateBills(BillingGenerateRequest x,AuthService auth,HttpContext http,CancellationToken ct)
    {
        var s=await AuthGuard.Get(http,auth,ct);
        if(s is null) return Results.Unauthorized();
        if(s.RoleCode is not ("SOCIETY_ADMIN" or "SUPER_ADMIN") || s.SocietyId is null) return Results.Forbid();
        var month=new DateOnly(x.Year,x.Month,1);
        await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));
        await cn.OpenAsync(ct);
        await using var cmd=new NpgsqlCommand("call society_manager.sp_generate_monthly_bills(@society,@month,@user,@due,NULL)",cn);
        cmd.Parameters.AddWithValue("society",s.SocietyId.Value);cmd.Parameters.AddWithValue("month",month);
        cmd.Parameters.AddWithValue("user",s.UserId);cmd.Parameters.AddWithValue("due",x.DueDays??0);
        await using var r=await cmd.ExecuteReaderAsync(ct);
        if(!await r.ReadAsync(ct)) return Results.BadRequest(new {message="Monthly billing could not be completed."});
        return Results.Ok(new {success=true,createdCount=r.IsDBNull(0)?0:r.GetInt64(0),billMonth=month});
    }

    static async Task<IResult> Config(AuthService auth,HttpContext http,CancellationToken ct,string fn,int columns)
    {
        var session=await AuthGuard.Get(http,auth,ct); if(session is null)return Results.Unauthorized();
        if(session.RoleCode is not ("SOCIETY_ADMIN" or "SUPER_ADMIN") || session.SocietyId is null)return Results.Forbid();
        await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION")); await cn.OpenAsync(ct);
        await using var cmd=new NpgsqlCommand($"select * from society_manager.{fn}(@society_id)",cn); cmd.Parameters.AddWithValue("society_id",session.SocietyId.Value);
        return Results.Ok(await ReadRows(cmd,columns,ct));
    }

    static async Task<List<Dictionary<string,object?>>> ReadRows(NpgsqlCommand cmd,int columns,CancellationToken ct)
    {
        await using var r=await cmd.ExecuteReaderAsync(ct); var rows=new List<Dictionary<string,object?>>();
        while(await r.ReadAsync(ct)){var row=new Dictionary<string,object?>();for(var i=0;i<columns;i++)row[r.GetName(i)]=r.IsDBNull(i)?null:r.GetValue(i);rows.Add(row);}
        return rows;
    }
}

public sealed record AdminAccountRight(string ModuleCode,string ActionCode,bool Granted);
public sealed record AdminAccountRequest(long UserId,string LoginName,string DisplayName,string? Email,string? Phone,string AccountType,string? Password,DateOnly ValidFrom,DateOnly? ValidTo,List<AdminAccountRight>? Rights,string? Remark);
public sealed record AdminAccountStatusRequest(long UserId,bool IsActive,string? Remark);
public sealed record AdminAccountExtendRequest(long UserId,DateOnly ValidTo,string? Remark);
public sealed record ChargeRuleRequest(string ChargeCode,string PlanName,string Method,decimal Rate,DateOnly EffectiveFrom,DateOnly? EffectiveTo,string ScopeType,string? ScopeValue);
public sealed record InterestRuleRequest(string RuleName,string CalculationType,decimal Rate,string Frequency,string SimpleOrCompound,int GraceDays,decimal? CapAmount,DateOnly EffectiveFrom,DateOnly? EffectiveTo);
public sealed record ChargeTypeRequest(string Code,string Name,string Method,bool Recurring,bool Taxable,bool Mandatory,string? Remark);
public sealed record BillingConfigRequest(int BillingDay,int DueDays,bool CarryArrear,bool AutoDpc,string? Remark);
public sealed record BillingGenerateRequest(int Year,int Month,int? DueDays);
