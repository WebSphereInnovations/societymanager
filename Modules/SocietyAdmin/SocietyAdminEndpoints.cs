using System.Text.Json;
using Npgsql;
using NpgsqlTypes;
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

        app.MapGet("/api/society-admin/dashboard/analytics", async (
            DateOnly? from, DateOnly? to, long? buildingId, string? unitType, string? customerType,
            string? paymentMode, string? billStatus, AuthService auth, HttpContext http, CancellationToken ct) =>
        {
            var session = await AuthGuard.Get(http, auth, ct);
            if (session is null) return Results.Unauthorized();
            if (session.SocietyId is null) return Results.BadRequest(new { message = "Select a society first." });
            if (!await auth.HasPermissionAsync(session.UserId, "APP_DASHBOARD", "VIEW", ct)) return Results.Forbid();

            var today = DateOnly.FromDateTime(DateTime.Now);
            var toDate = to ?? today;
            var fromDate = from ?? new DateOnly(toDate.Year, toDate.Month, 1);
            if (fromDate > toDate) return Results.BadRequest(new { message = "Start date must be on or before end date." });
            if (toDate.DayNumber - fromDate.DayNumber > 366 * 5)
                return Results.BadRequest(new { message = "Choose a reporting period of five years or less." });

            await using var cn = new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));
            await cn.OpenAsync(ct);
            await using var cmd = new NpgsqlCommand(
                "select society_manager.fn_dashboard_analytics(@society,@from,@to,@building,@unit_type,@customer_type,@payment_mode,@bill_status)", cn);
            cmd.Parameters.AddWithValue("society", session.SocietyId.Value);
            cmd.Parameters.AddWithValue("from", fromDate);
            cmd.Parameters.AddWithValue("to", toDate);
            cmd.Parameters.Add("building", NpgsqlTypes.NpgsqlDbType.Bigint).Value = (object?)buildingId ?? DBNull.Value;
            cmd.Parameters.Add("unit_type", NpgsqlTypes.NpgsqlDbType.Varchar).Value = (object?)unitType ?? DBNull.Value;
            cmd.Parameters.Add("customer_type", NpgsqlTypes.NpgsqlDbType.Varchar).Value = (object?)customerType ?? DBNull.Value;
            cmd.Parameters.Add("payment_mode", NpgsqlTypes.NpgsqlDbType.Varchar).Value = (object?)paymentMode ?? DBNull.Value;
            cmd.Parameters.Add("bill_status", NpgsqlTypes.NpgsqlDbType.Varchar).Value = (object?)billStatus ?? DBNull.Value;
            var value = await cmd.ExecuteScalarAsync(ct);
            if (value is null or DBNull) return Results.Problem("Dashboard analytics are unavailable.", statusCode: 503);
            var json = value is JsonDocument document ? document.RootElement.Clone() : JsonDocument.Parse(value.ToString()!).RootElement.Clone();
            http.Response.Headers.CacheControl = "no-store";
            return Results.Ok(json);
        });

        app.MapGet("/api/society-admin/dashboard/drilldown", async (
            string type, string? label, DateOnly? from, DateOnly? to, long? buildingId, string? unitType,
            string? customerType, string? paymentMode, string? billStatus, AuthService auth, HttpContext http, CancellationToken ct) =>
            await DashboardDrilldown(type,label,from,to,buildingId,unitType,customerType,paymentMode,billStatus,auth,http,ct));

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

        app.MapGet("/api/society-admin/roles", async (AuthService auth,HttpContext http,CancellationToken ct) => await RoleList(auth,http,ct));
        app.MapGet("/api/society-admin/roles/{roleId:long}/rights", async (long roleId,AuthService auth,HttpContext http,CancellationToken ct) => await RoleRights(roleId,auth,http,ct));
        app.MapPost("/api/society-admin/roles/save", async (AdminRoleRequest x,AuthService auth,HttpContext http,CancellationToken ct) => await SaveRole(x,auth,http,ct));
        app.MapGet("/api/society-admin/menu-catalog", async (AuthService auth,HttpContext http,CancellationToken ct) => await MenuCatalog(auth,http,ct));
        app.MapPost("/api/society-admin/menu-catalog/save", async (AdminMenuRequest x,AuthService auth,HttpContext http,CancellationToken ct) => await SaveMenu(x,auth,http,ct));
        app.MapPost("/api/society-admin/menu-catalog/visibility", async (AdminMenuVisibilityRequest x,AuthService auth,HttpContext http,CancellationToken ct) => await SetMenuVisibility(x,auth,http,ct));

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
        try
        {
            await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));await cn.OpenAsync(ct);
            await using var cmd=new NpgsqlCommand("call society_manager.sp_admin_save_account(@society,@user,@login,@name,@email,@phone,@type,@password,@from,@to,@rights,@by,@remark,NULL)",cn);
            cmd.Parameters.AddWithValue("society",s.SocietyId.Value);cmd.Parameters.AddWithValue("user",x.UserId);
            cmd.Parameters.AddWithValue("login",x.LoginName);cmd.Parameters.AddWithValue("name",x.DisplayName);
            cmd.Parameters.AddWithValue("email",(object?)x.Email??DBNull.Value);cmd.Parameters.AddWithValue("phone",(object?)x.Phone??DBNull.Value);
            cmd.Parameters.AddWithValue("type",x.AccountType);cmd.Parameters.AddWithValue("password",(object?)x.Password??DBNull.Value);
            cmd.Parameters.AddWithValue("from",x.ValidFrom);cmd.Parameters.AddWithValue("to",(object?)x.ValidTo??DBNull.Value);
            var rights=cmd.Parameters.Add("rights",NpgsqlDbType.Jsonb);rights.Value=JsonSerializer.Serialize(x.Rights??[]);
            cmd.Parameters.AddWithValue("by",s.UserId);cmd.Parameters.AddWithValue("remark",x.Remark??"");
            await cmd.ExecuteNonQueryAsync(ct);
            return Results.Ok(new {success=true});
        }
        catch(PostgresException)
        {
            return Results.BadRequest(new {message="Operation could not be completed."});
        }
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

    static async Task<IResult> RoleList(AuthService auth,HttpContext http,CancellationToken ct)
    {
        var s=await AuthGuard.Get(http,auth,ct);if(s is null)return Results.Unauthorized();
        if(s.SocietyId is null || !await auth.HasPermissionAsync(s.UserId,"ADM_ACCOUNTS","VIEW",ct))return Results.Forbid();
        await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));await cn.OpenAsync(ct);
        await using var cmd=new NpgsqlCommand("select * from society_manager.fn_admin_role_list(@society)",cn);cmd.Parameters.AddWithValue("society",s.SocietyId.Value);
        return Results.Ok(await ReadRows(cmd,7,ct));
    }

    static async Task<IResult> RoleRights(long roleId,AuthService auth,HttpContext http,CancellationToken ct)
    {
        var s=await AuthGuard.Get(http,auth,ct);if(s is null)return Results.Unauthorized();
        if(!await auth.HasPermissionAsync(s.UserId,"ADM_ACCOUNTS","VIEW",ct))return Results.Forbid();
        await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));await cn.OpenAsync(ct);
        await using var cmd=new NpgsqlCommand("select * from society_manager.fn_admin_role_rights(@role)",cn);cmd.Parameters.AddWithValue("role",roleId);
        return Results.Ok(await ReadRows(cmd,9,ct));
    }

    static async Task<IResult> SaveRole(AdminRoleRequest x,AuthService auth,HttpContext http,CancellationToken ct)
    {
        var s=await AuthGuard.Get(http,auth,ct);if(s is null)return Results.Unauthorized();
        if(s.SocietyId is null || !await auth.HasPermissionAsync(s.UserId,"ADM_ACCOUNTS","EDIT",ct))return Results.Forbid();
        if(x.RoleId==0 && !await auth.HasPermissionAsync(s.UserId,"ADM_ACCOUNTS","ADD",ct))return Results.Forbid();
        try
        {
            await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));await cn.OpenAsync(ct);
            await using var cmd=new NpgsqlCommand("call society_manager.sp_admin_save_role(@role,@code,@name,@description,@rights,@by,@remark,NULL)",cn);
            cmd.Parameters.AddWithValue("role",x.RoleId);cmd.Parameters.AddWithValue("code",x.RoleCode);cmd.Parameters.AddWithValue("name",x.RoleName);
            cmd.Parameters.AddWithValue("description",(object?)x.Description??DBNull.Value);var rights=cmd.Parameters.Add("rights",NpgsqlDbType.Jsonb);rights.Value=JsonSerializer.Serialize(x.Rights??[]);
            cmd.Parameters.AddWithValue("by",s.UserId);cmd.Parameters.AddWithValue("remark",x.Remark??"");await cmd.ExecuteNonQueryAsync(ct);return Results.Ok(new {success=true});
        }
        catch(PostgresException){return Results.BadRequest(new {message="Operation could not be completed."});}
    }

    static async Task<IResult> MenuCatalog(AuthService auth,HttpContext http,CancellationToken ct)
    {
        var s=await AuthGuard.Get(http,auth,ct);if(s is null)return Results.Unauthorized();
        if(!await auth.HasPermissionAsync(s.UserId,"ADM_ACCOUNTS","VIEW",ct))return Results.Forbid();
        await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));await cn.OpenAsync(ct);
        await using var cmd=new NpgsqlCommand("select * from society_manager.fn_admin_menu_list()",cn);return Results.Ok(await ReadRows(cmd,9,ct));
    }

    static async Task<IResult> SaveMenu(AdminMenuRequest x,AuthService auth,HttpContext http,CancellationToken ct)
    {
        var s=await AuthGuard.Get(http,auth,ct);if(s is null)return Results.Unauthorized();
        if(!await auth.HasPermissionAsync(s.UserId,"ADM_ACCOUNTS","EDIT",ct))return Results.Forbid();
        if(x.ModuleId==0 && !await auth.HasPermissionAsync(s.UserId,"ADM_ACCOUNTS","ADD",ct))return Results.Forbid();
        try
        {
            await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));await cn.OpenAsync(ct);
            await using var cmd=new NpgsqlCommand("call society_manager.sp_admin_save_menu(@id,@code,@name,@parent,@order,@visible,@by,@remark,NULL)",cn);
            cmd.Parameters.AddWithValue("id",x.ModuleId);cmd.Parameters.AddWithValue("code",x.ModuleCode);cmd.Parameters.AddWithValue("name",x.ModuleName);
            cmd.Parameters.AddWithValue("parent",(object?)x.ParentModuleCode??DBNull.Value);cmd.Parameters.AddWithValue("order",x.DisplayOrder);cmd.Parameters.AddWithValue("visible",x.Visible);
            cmd.Parameters.AddWithValue("by",s.UserId);cmd.Parameters.AddWithValue("remark",x.Remark??"");await cmd.ExecuteNonQueryAsync(ct);return Results.Ok(new {success=true});
        }
        catch(PostgresException){return Results.BadRequest(new {message="Operation could not be completed."});}
    }

    static async Task<IResult> SetMenuVisibility(AdminMenuVisibilityRequest x,AuthService auth,HttpContext http,CancellationToken ct)
    {
        var s=await AuthGuard.Get(http,auth,ct);if(s is null)return Results.Unauthorized();
        if(!await auth.HasPermissionAsync(s.UserId,"ADM_ACCOUNTS","EDIT",ct))return Results.Forbid();
        try
        {
            await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));await cn.OpenAsync(ct);
            await using var cmd=new NpgsqlCommand("call society_manager.sp_admin_set_menu_visibility(@id,@visible,@by,@remark)",cn);
            cmd.Parameters.AddWithValue("id",x.ModuleId);cmd.Parameters.AddWithValue("visible",x.Visible);cmd.Parameters.AddWithValue("by",s.UserId);cmd.Parameters.AddWithValue("remark",x.Remark??"");await cmd.ExecuteNonQueryAsync(ct);return Results.Ok(new {success=true});
        }
        catch(PostgresException){return Results.BadRequest(new {message="Operation could not be completed."});}
    }

    static async Task<IResult> DashboardDrilldown(
        string type,string? label,DateOnly? from,DateOnly? to,long? buildingId,string? unitType,
        string? customerType,string? paymentMode,string? billStatus,AuthService auth,HttpContext http,CancellationToken ct)
    {
        var session=await AuthGuard.Get(http,auth,ct);
        if(session is null)return Results.Unauthorized();
        if(session.SocietyId is null)return Results.BadRequest(new {message="Select a society first."});
        var kind=(type??"").Trim().ToLowerInvariant();
        var permission=kind switch
        {
            "customers"=>"SOC_CUSTOMER",
            "flats" or "units"=>"FLATS",
            "bills" or "outstanding" or "overdue"=>"BILLING",
            "collection"=>"COLLECTION",
            "complaints"=>"COMPLAINTS",
            "visitors"=>"VISITORS",
            "parking" or "assignedparking"=>"PARKING",
            _=>null
        };
        if(permission is null)return Results.BadRequest(new {message="Unsupported dashboard drill-down."});
        if(!await auth.HasPermissionAsync(session.UserId,permission,"VIEW",ct))
            return Results.Json(new {message="You do not have permission to view these records."},statusCode:403);
        var today=DateOnly.FromDateTime(DateTime.Now);
        var toDate=to??today;
        var fromDate=from??new DateOnly(toDate.Year,toDate.Month,1);
        if(fromDate>toDate)return Results.BadRequest(new {message="Start date must be on or before end date."});
        if(toDate.DayNumber-fromDate.DayNumber>366*5)return Results.BadRequest(new {message="Choose a reporting period of five years or less."});

        var sql=kind switch
        {
            "customers"=>@"SELECT c.customer_id,c.customer_code,c.full_name,c.customer_type,c.phone,c.email,c.is_active
                FROM m_customer c
                WHERE c.society_id=@society
                  AND (@label IS NULL OR c.customer_type=@label)
                  AND (@customer_type IS NULL OR c.customer_type=@customer_type)
                  AND ((@building IS NULL AND @unit_type IS NULL) OR EXISTS (
                    SELECT 1 FROM m_customer_flat cf JOIN m_flat f ON f.flat_id=cf.flat_id
                    WHERE cf.customer_id=c.customer_id AND (cf.end_date IS NULL OR cf.end_date>=current_date)
                      AND f.society_id=@society AND f.is_active
                      AND (@building IS NULL OR f.building_id=@building)
                      AND (@unit_type IS NULL OR f.unit_type=@unit_type)))
                ORDER BY c.full_name LIMIT 250",
            "flats" or "units"=>@"SELECT f.flat_id,f.flat_no,COALESCE(w.wing_name,w.wing_code,'') AS wing,
                    COALESCE(b.building_name,b.building_code,'') AS building,f.unit_type,f.area_sqft,
                    f.occupancy_status,COALESCE(c.full_name,'') AS owner_name,COALESCE(c.phone,'') AS owner_phone
                FROM m_flat f LEFT JOIN m_wing w ON w.wing_id=f.wing_id
                LEFT JOIN m_building b ON b.building_id=f.building_id
                LEFT JOIN m_customer_flat cf ON cf.flat_id=f.flat_id AND cf.is_primary
                LEFT JOIN m_customer c ON c.customer_id=cf.customer_id
                WHERE f.society_id=@society AND f.is_active
                  AND (@building IS NULL OR f.building_id=@building)
                  AND (@unit_type IS NULL OR f.unit_type=@unit_type)
                  AND (@customer_type IS NULL OR c.customer_type=@customer_type)
                  AND (@label IS NULL OR (@kind='flats' AND upper(f.occupancy_status)=upper(@label)) OR (@kind='units' AND upper(f.unit_type)=upper(@label)))
                ORDER BY f.flat_no LIMIT 250",
            "bills" or "outstanding" or "overdue"=>@"SELECT b.bill_id,b.bill_no,b.bill_month,f.flat_no,
                    COALESCE(c.full_name,'') AS customer_name,b.total_amount,b.paid_amount,
                    GREATEST(COALESCE(b.total_amount,0)-COALESCE(b.paid_amount,0),0) AS balance,b.due_date,b.status
                FROM t_bill b JOIN m_flat f ON f.flat_id=b.flat_id
                LEFT JOIN m_customer_flat cf ON cf.flat_id=f.flat_id AND cf.is_primary
                LEFT JOIN m_customer c ON c.customer_id=cf.customer_id
                WHERE b.society_id=@society AND f.is_active
                  AND (@kind<>'bills' OR (b.bill_date>=@from AND b.bill_date<@to+1))
                  AND upper(COALESCE(b.status,'')) NOT IN ('DRAFT','CANCELLED','CANCELED','VOID','DELETED')
                  AND (@kind='bills' OR upper(COALESCE(b.status,'')) NOT IN ('PAID','SETTLED'))
                  AND (@bill_status IS NULL OR b.status=@bill_status)
                  AND (@label IS NULL OR @kind<>'bills' OR upper(b.status)=upper(@label))
                  AND (@kind<>'outstanding' OR GREATEST(COALESCE(b.total_amount,0)-COALESCE(b.paid_amount,0),0)>0)
                  AND (@kind<>'overdue' OR (GREATEST(COALESCE(b.total_amount,0)-COALESCE(b.paid_amount,0),0)>0 AND b.due_date<current_date))
                  AND (@building IS NULL OR f.building_id=@building)
                  AND (@unit_type IS NULL OR f.unit_type=@unit_type)
                  AND (@customer_type IS NULL OR c.customer_type=@customer_type)
                ORDER BY b.bill_date DESC,b.bill_id DESC LIMIT 250",
            "collection"=>@"SELECT p.payment_id,p.payment_no,p.payment_date::date AS payment_date,f.flat_no,
                    COALESCE(c.full_name,'') AS customer_name,p.amount,p.payment_mode,p.reference_no
                FROM t_payment p JOIN m_flat f ON f.flat_id=p.flat_id
                LEFT JOIN m_customer c ON c.customer_id=p.customer_id
                WHERE p.society_id=@society AND p.payment_date::date BETWEEN @from AND @to
                  AND upper(COALESCE(p.status,'')) IN ('SUCCESS','PAID','COMPLETED','SETTLED')
                  AND (@label IS NULL OR p.payment_mode=@label)
                  AND (@payment_mode IS NULL OR p.payment_mode=@payment_mode)
                  AND (@building IS NULL OR f.building_id=@building)
                  AND (@unit_type IS NULL OR f.unit_type=@unit_type)
                  AND (@customer_type IS NULL OR c.customer_type=@customer_type)
                ORDER BY p.payment_date DESC,p.payment_id DESC LIMIT 250",
            "complaints"=>@"SELECT x.complaint_id,x.complaint_no,f.flat_no,COALESCE(c.full_name,'') AS customer_name,
                    x.category,x.title,x.priority,x.status,x.created_at
                FROM t_complaint x LEFT JOIN m_flat f ON f.flat_id=x.flat_id
                LEFT JOIN m_customer c ON c.customer_id=x.customer_id
                WHERE x.society_id=@society
                  AND ((@label IS NULL AND x.status NOT IN ('Closed','Resolved'))
                    OR (@label IS NOT NULL AND x.created_at>=@from::timestamp AND x.created_at<(@to+1)::timestamp AND upper(x.status)=upper(@label)))
                  AND (@building IS NULL OR f.building_id=@building)
                  AND (@unit_type IS NULL OR f.unit_type=@unit_type)
                  AND (@customer_type IS NULL OR c.customer_type=@customer_type)
                ORDER BY x.created_at DESC LIMIT 250",
            "visitors"=>@"SELECT v.visitor_entry_id AS visitor_id,v.visitor_name,v.phone,f.flat_no,v.visitor_type,
                    v.purpose,v.status,v.entry_at AS entry_time,v.exit_at AS exit_time
                FROM t_visitor_entry v LEFT JOIN m_flat f ON f.flat_id=v.flat_id
                WHERE v.society_id=@society
                  AND ((@label IS NULL AND v.status='Inside')
                    OR (@label IS NOT NULL AND v.entry_at>=@from::timestamp AND v.entry_at<(@to+1)::timestamp AND upper(v.status)=upper(@label)))
                  AND (@building IS NULL OR f.building_id=@building)
                  AND (@unit_type IS NULL OR f.unit_type=@unit_type)
                ORDER BY v.entry_at DESC LIMIT 250",
            "parking" or "assignedparking"=>@"SELECT s.parking_slot_id AS slot_id,s.slot_no,s.slot_type,s.charge,COALESCE(f.flat_no,'') AS assigned_flat,
                    COALESCE(c.full_name,'') AS customer_name,
                    CASE WHEN a.assignment_id IS NULL THEN 'Available' ELSE 'Assigned' END AS status
                FROM m_parking_slot s LEFT JOIN t_parking_assignment a ON a.parking_slot_id=s.parking_slot_id AND a.is_active
                LEFT JOIN m_flat f ON f.flat_id=a.flat_id LEFT JOIN m_customer c ON c.customer_id=a.customer_id
                WHERE s.society_id=@society AND s.is_active
                  AND (@kind<>'assignedparking' OR a.assignment_id IS NOT NULL)
                  AND (@label IS NULL OR (CASE WHEN a.assignment_id IS NULL THEN 'Available' ELSE 'Assigned' END)=@label)
                  AND ((@building IS NULL AND @unit_type IS NULL) OR
                    (f.flat_id IS NOT NULL AND (@building IS NULL OR f.building_id=@building) AND (@unit_type IS NULL OR f.unit_type=@unit_type)))
                ORDER BY s.slot_no LIMIT 250",
            _=>throw new InvalidOperationException("Unsupported dashboard drill-down.")
        };

        await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));
        await cn.OpenAsync(ct);
        await using var cmd=new NpgsqlCommand(sql,cn);
        cmd.Parameters.AddWithValue("society",session.SocietyId.Value);
        cmd.Parameters.AddWithValue("kind",kind);
        cmd.Parameters.Add("label",NpgsqlDbType.Varchar).Value=(object?)label??DBNull.Value;
        cmd.Parameters.Add("from",NpgsqlDbType.Date).Value=fromDate;
        cmd.Parameters.Add("to",NpgsqlDbType.Date).Value=toDate;
        cmd.Parameters.Add("building",NpgsqlDbType.Bigint).Value=(object?)buildingId??DBNull.Value;
        cmd.Parameters.Add("unit_type",NpgsqlDbType.Varchar).Value=(object?)unitType??DBNull.Value;
        cmd.Parameters.Add("customer_type",NpgsqlDbType.Varchar).Value=(object?)customerType??DBNull.Value;
        cmd.Parameters.Add("payment_mode",NpgsqlDbType.Varchar).Value=(object?)paymentMode??DBNull.Value;
        cmd.Parameters.Add("bill_status",NpgsqlDbType.Varchar).Value=(object?)billStatus??DBNull.Value;
        await using var reader=await cmd.ExecuteReaderAsync(ct);
        var rows=new List<Dictionary<string,object?>>();
        while(await reader.ReadAsync(ct))
        {
            var row=new Dictionary<string,object?>();
            for(var i=0;i<reader.FieldCount;i++)row[reader.GetName(i)]=reader.IsDBNull(i)?null:reader.GetValue(i);
            rows.Add(row);
        }
        http.Response.Headers.CacheControl="no-store";
        return Results.Ok(rows);
    }

    static async Task<IResult> Query(AuthService auth,HttpContext http,CancellationToken ct,string fn,string q,int columns)
    {
        var session=await AuthGuard.Get(http,auth,ct);
        if(session is null) return Results.Unauthorized();
        if(session.SocietyId is null) return Results.BadRequest(new {message="Select a society first."});
        var module=fn switch
        {
            "fn_society_admin_customer_search"=>"SOC_CUSTOMER",
            "fn_society_admin_flat_search"=>"FLATS",
            "fn_society_admin_bill_list"=>"BILLING",
            "fn_society_admin_complaints"=>"COMPLAINTS",
            "fn_society_admin_visitors"=>"VISITORS",
            "fn_society_admin_parking"=>"PARKING",
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
        if(session.SocietyId is null || !await auth.HasPermissionAsync(session.UserId,"COLLECTION","VIEW",ct)) return Results.Forbid();
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
public sealed record AdminRoleRight(string ModuleCode,string ActionCode,bool Granted);
public sealed record AdminRoleRequest(long RoleId,string RoleCode,string RoleName,string? Description,List<AdminRoleRight>? Rights,string? Remark);
public sealed record AdminMenuRequest(long ModuleId,string ModuleCode,string ModuleName,string? ParentModuleCode,int DisplayOrder,bool Visible,string? Remark);
public sealed record AdminMenuVisibilityRequest(long ModuleId,bool Visible,string? Remark);
public sealed record ChargeRuleRequest(string ChargeCode,string PlanName,string Method,decimal Rate,DateOnly EffectiveFrom,DateOnly? EffectiveTo,string ScopeType,string? ScopeValue);
public sealed record InterestRuleRequest(string RuleName,string CalculationType,decimal Rate,string Frequency,string SimpleOrCompound,int GraceDays,decimal? CapAmount,DateOnly EffectiveFrom,DateOnly? EffectiveTo);
public sealed record ChargeTypeRequest(string Code,string Name,string Method,bool Recurring,bool Taxable,bool Mandatory,string? Remark);
public sealed record BillingConfigRequest(int BillingDay,int DueDays,bool CarryArrear,bool AutoDpc,string? Remark);
public sealed record BillingGenerateRequest(int Year,int Month,int? DueDays);
