using Npgsql;
using Society360.Data;
using Society360.Security;

namespace Society360.Modules.Billing;

public static class BillingEndpoints
{
    public static void MapBillingEndpoints(this WebApplication app)
    {
        app.MapGet("/api/billing/config", async (AuthService a,HttpContext h,CancellationToken c) =>
            await Query(a,h,c,"BILLING_CONFIGURATION","fn_billing_get_configuration"));

        app.MapGet("/api/billing/config/history", async (AuthService a,HttpContext h,CancellationToken c) =>
            await Query(a,h,c,"BILLING_CONFIGURATION","fn_billing_configuration_history"));

        app.MapGet("/api/billing/frequencies", async (AuthService a,HttpContext h,CancellationToken c) =>
            await QueryNoSociety(a,h,c,"BILLING_CONFIGURATION","fn_billing_frequencies"));

        app.MapGet("/api/billing/dpc-options", async (AuthService a,HttpContext h,CancellationToken c) =>
            await QueryNoSociety(a,h,c,"BILLING_CONFIGURATION","fn_billing_dpc_apply_on"));

        app.MapGet("/api/billing/property-types", async (AuthService a,HttpContext h,CancellationToken c) =>
            await Query(a,h,c,"BILLING_CONFIGURATION","fn_billing_property_types"));

        app.MapGet("/api/billing/rates", async (long? propertyTypeId,AuthService a,HttpContext h,CancellationToken c) =>
            await Query(a,h,c,"BILLING_CONFIGURATION","fn_billing_rates",("property",propertyTypeId??(object)DBNull.Value)));

        app.MapGet("/api/billing/next-month", async (AuthService a,HttpContext h,CancellationToken c) =>
            await Scalar(a,h,c,"BILLING_PROCESS","select society_manager.fn_billing_get_next_month(@s)"));

        app.MapGet("/api/billing/missing-rates", async (AuthService a,HttpContext h,CancellationToken c) =>
            await Query(a,h,c,"BILLING_PROCESS","fn_billing_required_rates_missing"));

        app.MapPost("/api/billing/config", async (BillingConfigRequest x,AuthService a,HttpContext h,CancellationToken c) =>
            await Call(a,h,c,"BILLING_CONFIGURATION",
                "select society_manager.sp_billing_save_configuration(@s,@frequency,@dpc,@apply,@rate,@type,@from,@to,@u,@remark)",
                new[]
                {
                    ("frequency",(object)x.FrequencyMonths),("dpc",(object)x.DpcApplicable),
                    ("apply",(object)x.DpcApplyOn),("rate",(object)x.DpcRate),
                    ("type",(object)x.DpcCalculationType),("from",(object)x.EffectiveFrom),
                    ("to",(object?)x.EffectiveTo??DBNull.Value),("u",(object)0L),
                    ("remark",(object)(x.Remark??""))
                },"EDIT"));

        app.MapPost("/api/billing/rate", async (BillingRateRequest x,AuthService a,HttpContext h,CancellationToken c) =>
            await Call(a,h,c,"BILLING_CONFIGURATION",
                "select society_manager.sp_billing_save_rate(@s,@id,@property,@code,@name,@type,@rate,@from,@to,@u,@remark)",
                new[]
                {
                    ("id",(object)x.Id),("property",(object)x.PropertyTypeId),("code",(object)x.ChargeCode),
                    ("name",(object)x.ChargeName),("type",(object)x.RateType),("rate",(object)x.Rate),
                    ("from",(object)x.EffectiveFrom),("to",(object?)x.EffectiveTo??DBNull.Value),
                    ("u",(object)0L),("remark",(object)(x.Remark??""))
                },x.Id>0?"EDIT":"ADD"));

        app.MapPost("/api/billing/start", async (AuthService a,HttpContext h,CancellationToken c) =>
            await Call(a,h,c,"BILLING_PROCESS",
                "select society_manager.sp_billing_prepare(@s,@u)",
                new[]{("u",(object)0L)},"POST"));

        app.MapGet("/api/billing/preview/{runId:long}", async (long runId,AuthService a,HttpContext h,CancellationToken c) =>
            await QueryRun(a,h,c,runId,"BILLING_PROCESS","fn_billing_preview"));

        app.MapPost("/api/billing/finalize", async (BillingFinalizeRequest x,AuthService a,HttpContext h,CancellationToken c) =>
            await Call(a,h,c,"BILLING_PROCESS",
                "select society_manager.sp_billing_finalize(@s,@run,@u,@confirm)",
                new[]{("run",(object)x.RunId),("confirm",(object)x.Confirm),("u",(object)0L)},"POST"));
    }

    static async Task<IResult?> Guard(AuthService a,HttpContext h,CancellationToken c,string module,string action)
    {
        var s=await AuthGuard.Get(h,a,c);
        if(s is null)return Results.Unauthorized();
        if(s.SocietyId is null)return Results.Forbid();
        if(s.RoleCode is not("SOCIETY_ADMIN" or "SUPER_ADMIN"))return Results.Forbid();
        if(!await a.HasPermissionAsync(s.UserId,module,action,c))return Results.Forbid();
        return null;
    }

    static async Task<IResult> Query(AuthService a,HttpContext h,CancellationToken c,string module,string fn,params (string,object)[] args)
    {
        var g=await Guard(a,h,c,module,"VIEW");if(g is not null)return g;
        var s=await AuthGuard.Get(h,a,c);
        await using var cn=Open();
        await cn.OpenAsync(c);
        await using var cmd=new NpgsqlCommand($"select * from society_manager.{fn}(@s{string.Concat(args.Select(x=>",@"+x.Item1))})",cn);
        cmd.Parameters.AddWithValue("s",s!.SocietyId!.Value);
        foreach(var p in args)cmd.Parameters.AddWithValue(p.Item1,p.Item2);
        return await Rows(cmd,c);
    }

    static async Task<IResult> QueryNoSociety(AuthService a,HttpContext h,CancellationToken c,string module,string fn)
    {
        var g=await Guard(a,h,c,module,"VIEW");if(g is not null)return g;
        await using var cn=Open();
        await cn.OpenAsync(c);
        await using var cmd=new NpgsqlCommand($"select * from society_manager.{fn}()",cn);
        return await Rows(cmd,c);
    }

    static async Task<IResult> QueryRun(AuthService a,HttpContext h,CancellationToken c,long runId,string module,string fn)
    {
        var g=await Guard(a,h,c,module,"VIEW");if(g is not null)return g;
        var s=await AuthGuard.Get(h,a,c);
        await using var cn=Open();
        await cn.OpenAsync(c);
        await using var cmd=new NpgsqlCommand($"select * from society_manager.{fn}(@s,@run)",cn);
        cmd.Parameters.AddWithValue("s",s!.SocietyId!.Value);
        cmd.Parameters.AddWithValue("run",runId);
        return await Rows(cmd,c);
    }

    static async Task<IResult> Scalar(AuthService a,HttpContext h,CancellationToken c,string module,string sql)
    {
        var g=await Guard(a,h,c,module,"VIEW");if(g is not null)return g;
        var s=await AuthGuard.Get(h,a,c);
        await using var cn=Open();
        await cn.OpenAsync(c);
        await using var cmd=new NpgsqlCommand(sql,cn);
        cmd.Parameters.AddWithValue("s",s!.SocietyId!.Value);
        return Results.Ok(new { value=await cmd.ExecuteScalarAsync(c) });
    }

    static async Task<IResult> Call(AuthService a,HttpContext h,CancellationToken c,string module,string sql,(string,object)[] args,string action)
    {
        var g=await Guard(a,h,c,module,action);if(g is not null)return g;
        var s=await AuthGuard.Get(h,a,c);
        try
        {
            await using var cn=Open();
            await cn.OpenAsync(c);
            await using var cmd=new NpgsqlCommand(sql,cn);
            cmd.Parameters.AddWithValue("s",s!.SocietyId!.Value);
            foreach(var p in args)cmd.Parameters.AddWithValue(p.Item1,p.Item1=="u"?s.UserId:p.Item2);
            return Results.Ok(new { success=true,id=await cmd.ExecuteScalarAsync(c) });
        }
        catch(PostgresException ex)
        {
            return Results.BadRequest(new { success=false,code=ex.SqlState,message=BillingMessage(ex.MessageText) });
        }
    }

    static async Task<IResult> Rows(NpgsqlCommand cmd,CancellationToken c)
    {
        await using var r=await cmd.ExecuteReaderAsync(c);
        var rows=new List<Dictionary<string,object?>>();
        while(await r.ReadAsync(c))
        {
            var row=new Dictionary<string,object?>(StringComparer.OrdinalIgnoreCase);
            for(var i=0;i<r.FieldCount;i++)row[r.GetName(i)]=r.IsDBNull(i)?null:r.GetValue(i);
            rows.Add(row);
        }
        return Results.Ok(rows);
    }

    static NpgsqlConnection Open()
    {
        var cs=Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION");
        return new NpgsqlConnection(cs);
    }

    static string BillingMessage(string message) =>
        message switch
        {
            "Billing configuration is not available" => "Billing configuration is not available.",
            "Billing frequency is not configured" => "Billing frequency is not configured.",
            "DPC apply-on option is not configured" => "DPC apply-on option is not configured.",
            "Billing month is already finalized" => "This billing month has already been finalized.",
            "Prepared billing run not found" => "Billing preparation was not found. Please start billing again.",
            "Billing month already exists" => "This billing month already exists.",
            _ when message.Contains("Rate",StringComparison.OrdinalIgnoreCase) => message,
            _ => "Billing operation could not be completed."
        };
}

public sealed record BillingConfigRequest(int FrequencyMonths,bool DpcApplicable,string DpcApplyOn,decimal DpcRate,string DpcCalculationType,DateOnly EffectiveFrom,DateOnly? EffectiveTo,string? Remark);
public sealed record BillingRateRequest(long Id,long PropertyTypeId,string ChargeCode,string ChargeName,string RateType,decimal Rate,DateOnly EffectiveFrom,DateOnly? EffectiveTo,string? Remark);
public sealed record BillingFinalizeRequest(long RunId,bool Confirm);

