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
            if(session.RoleCode is not ("SOCIETY_ADMIN" or "SUPER_ADMIN")) return Results.Forbid();
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
    }

    static async Task<IResult> Query(AuthService auth,HttpContext http,CancellationToken ct,string fn,string q,int columns)
    {
        var session=await AuthGuard.Get(http,auth,ct);
        if(session is null) return Results.Unauthorized();
        if(session.RoleCode is not ("SOCIETY_ADMIN" or "SUPER_ADMIN")) return Results.Forbid();
        if(session.SocietyId is null) return Results.BadRequest(new {message="Select a society first."});
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
            for(var i=0;i<columns;i++) row[r.GetName(i)]=r.IsDBNull(i)?null:r.GetValue(i);
            rows.Add(row);
        }
        return Results.Ok(rows);
    }

    static async Task<IResult> Collection(AuthService auth,HttpContext http,CancellationToken ct,DateOnly from,DateOnly to)
    {
        var session=await AuthGuard.Get(http,auth,ct);
        if(session is null) return Results.Unauthorized();
        if(session.RoleCode is not ("SOCIETY_ADMIN" or "SUPER_ADMIN")) return Results.Forbid();
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

public sealed record ChargeRuleRequest(string ChargeCode,string PlanName,string Method,decimal Rate,DateOnly EffectiveFrom,DateOnly? EffectiveTo,string ScopeType,string? ScopeValue);
public sealed record InterestRuleRequest(string RuleName,string CalculationType,decimal Rate,string Frequency,string SimpleOrCompound,int GraceDays,decimal? CapAmount,DateOnly EffectiveFrom,DateOnly? EffectiveTo);
