[Reading 98 lines from start (total: 98 lines, 0 remaining)]

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

    static async Task<List<Dictionary<string,object?>>> ReadRows(NpgsqlCommand cmd,int columns,CancellationToken ct)
    {
        await using var r=await cmd.ExecuteReaderAsync(ct); var rows=new List<Dictionary<string,object?>>();
        while(await r.ReadAsync(ct)){var row=new Dictionary<string,object?>();for(var i=0;i<columns;i++)row[r.GetName(i)]=r.IsDBNull(i)?null:r.GetValue(i);rows.Add(row);}
        return rows;
    }
}

[executed on device: Sandman (3c28f028-a467-4934-be2f-752a8db6b6a8)]