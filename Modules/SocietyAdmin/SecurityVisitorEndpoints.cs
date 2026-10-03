using Npgsql;
using Society360.Data;
using Society360.Security;

namespace Society360.Modules.SocietyAdmin;

public static class SecurityVisitorEndpoints
{
    static string? Conn()=>Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION");
    static async Task<SessionContext?> Session(AuthService a,HttpContext h,CancellationToken c)=>await AuthGuard.Get(h,a,c);
    static async Task<NpgsqlConnection> Open(){var cn=new NpgsqlConnection(Conn());await cn.OpenAsync();return cn;}
    static async Task<IResult?> Check(AuthService a,HttpContext h,CancellationToken c,string module,string action)
    {
        var s=await Session(a,h,c); if(s is null)return Results.Unauthorized();
        if(s.SocietyId is null || !await a.HasPermissionAsync(s.UserId,module,action,c))return Results.Forbid();
        return null;
    }
    static async Task<IResult> Rows(NpgsqlCommand cmd,CancellationToken c)
    {
        await using var r=await cmd.ExecuteReaderAsync(c);var list=new List<Dictionary<string,object?>>();
        while(await r.ReadAsync(c)){var x=new Dictionary<string,object?>();for(int i=0;i<r.FieldCount;i++)x[r.GetName(i)]=r.IsDBNull(i)?null:r.GetValue(i);list.Add(x);}
        return Results.Ok(list);
    }
    static async Task<IResult> Query(AuthService a,HttpContext h,CancellationToken c,string module,string fn,params (string,object)[] args)
    {
        var g=await Check(a,h,c,module,"VIEW");if(g is not null)return g;var s=await Session(a,h,c);
        await using var cn=await Open();var ps="@s"+(args.Length>0?","+string.Join(",",args.Select((x,i)=>"@p"+i)):"");
        await using var cmd=new NpgsqlCommand($"select * from society_manager.{fn}({ps})",cn);cmd.Parameters.AddWithValue("s",s!.SocietyId!.Value);
        for(var i=0;i<args.Length;i++)cmd.Parameters.AddWithValue("p"+i,args[i].Item2);return await Rows(cmd,c);
    }
    static async Task<IResult> Call(AuthService a,HttpContext h,CancellationToken c,string module,string action,string sql,params (string,object)[] args)
    {
        var g=await Check(a,h,c,module,action);if(g is not null)return g;var s=await Session(a,h,c);
        try{await using var cn=await Open();await using var cmd=new NpgsqlCommand(sql,cn);cmd.Parameters.AddWithValue("s",s!.SocietyId!.Value);foreach(var p in args)cmd.Parameters.AddWithValue(p.Item1,p.Item1=="u"?s.UserId:p.Item2);var id=await cmd.ExecuteScalarAsync(c);return Results.Ok(new{success=true,id});}
        catch(PostgresException e){return Results.BadRequest(new{message=e.MessageText});}
    }
    public static void MapSecurityVisitorEndpoints(this WebApplication app)
    {
        app.MapGet("/api/security-visitor/master/{group}",async(string group,AuthService a,HttpContext h,CancellationToken c)=>await Query(a,h,c,"SEC_DASHBOARD","fn_security_master",("group",group)));
        app.MapGet("/api/security-visitor/dashboard",async(AuthService a,HttpContext h,CancellationToken c)=>{
            var g=await Check(a,h,c,"SEC_DASHBOARD","VIEW");if(g is not null)return g;var s=await Session(a,h,c);
            await using var cn=await Open();await using var cmd=new NpgsqlCommand("select * from society_manager.fn_security_dashboard(@s,current_date)",cn);cmd.Parameters.AddWithValue("s",s!.SocietyId!.Value);
            return await Rows(cmd,c);
        });
        app.MapGet("/api/security-visitor/dashboard/activity",async(AuthService a,HttpContext h,CancellationToken c)=>await Query(a,h,c,"SEC_DASHBOARD","fn_security_recent_activity",("limit",30)));
        app.MapGet("/api/security-visitor/guards",async(string? q,AuthService a,HttpContext h,CancellationToken c)=>await Query(a,h,c,"SEC_GUARDS","fn_security_guards",("q",q??"")));
        app.MapGet("/api/security-visitor/shifts",async(AuthService a,HttpContext h,CancellationToken c)=>await Query(a,h,c,"SEC_ROSTER","fn_security_shifts"));
        app.MapGet("/api/security-visitor/gates",async(string? q,AuthService a,HttpContext h,CancellationToken c)=>await Query(a,h,c,"SEC_GATES","fn_security_gates",("q",q??"")));
        app.MapGet("/api/security-visitor/roster",async(DateOnly? from,DateOnly? to,AuthService a,HttpContext h,CancellationToken c)=>{
            var f=from??DateOnly.FromDateTime(DateTime.Today.AddDays(-7));var t=to??DateOnly.FromDateTime(DateTime.Today.AddDays(14));
            return await Query(a,h,c,"SEC_ROSTER","fn_security_roster",("from",f),("to",t));
        });
        app.MapGet("/api/security-visitor/incidents",async(string? q,string? status,AuthService a,HttpContext h,CancellationToken c)=>await Query(a,h,c,"SEC_INCIDENTS","fn_security_incidents",("q",q??""),("status",status??"")));
        app.MapGet("/api/security-visitor/incident/{id:long}/history",async(long id,AuthService a,HttpContext h,CancellationToken c)=>await Query(a,h,c,"SEC_INCIDENTS","fn_security_incident_history",("id",id)));
        app.MapGet("/api/security-visitor/incident/{id:long}/attachment",async(long id,AuthService a,HttpContext h,CancellationToken c)=>{
            var g=await Check(a,h,c,"SEC_INCIDENTS","VIEW");if(g is not null)return g;var s=await Session(a,h,c);await using var cn=await Open();await using var cmd=new NpgsqlCommand("select * from society_manager.fn_security_incident_content(@s,@id)",cn);cmd.Parameters.AddWithValue("s",s!.SocietyId!.Value);cmd.Parameters.AddWithValue("id",id);await using var r=await cmd.ExecuteReaderAsync(c);if(!await r.ReadAsync(c))return Results.NotFound();return Results.File(r.GetFieldValue<byte[]>(2),r.GetString(1),r.GetString(0));
        });
        app.MapGet("/api/security-visitor/entry/{id:long}/photo",async(long id,AuthService a,HttpContext h,CancellationToken c)=>{
            var g=await Check(a,h,c,"VIS_ENTRY_EXIT","VIEW");if(g is not null)return g;var s=await Session(a,h,c);await using var cn=await Open();await using var cmd=new NpgsqlCommand("select * from society_manager.fn_visitor_photo(@s,@id)",cn);cmd.Parameters.AddWithValue("s",s!.SocietyId!.Value);cmd.Parameters.AddWithValue("id",id);await using var r=await cmd.ExecuteReaderAsync(c);if(!await r.ReadAsync(c))return Results.NotFound();return Results.File(r.GetFieldValue<byte[]>(1),r.GetString(0));
        });
        app.MapGet("/api/security-visitor/entries",async(string? q,bool inside,AuthService a,HttpContext h,CancellationToken c)=>await Query(a,h,c,"VIS_ENTRY_EXIT","fn_visitor_entries",("q",q??""),("inside",inside)));
        app.MapGet("/api/security-visitor/invitations",async(long? customerId,AuthService a,HttpContext h,CancellationToken c)=>await Query(a,h,c,"VIS_PREAPPROVAL","fn_visitor_invitations",("customer",customerId??0)));
        app.MapGet("/api/security-visitor/blacklist",async(AuthService a,HttpContext h,CancellationToken c)=>await Query(a,h,c,"VIS_BLACKLIST","fn_visitor_blacklist"));
        app.MapGet("/api/security-visitor/reports",async(string report,DateOnly? from,DateOnly? to,long? gateId,string? status,AuthService a,HttpContext h,CancellationToken c)=>await Query(a,h,c,"SEC_REPORTS","fn_security_reports",("report",report),("from",from??DateOnly.FromDateTime(DateTime.Today.AddDays(-30))),("to",to??DateOnly.FromDateTime(DateTime.Today)),("gate",gateId??(object)DBNull.Value),("status",status??"")));
        
        app.MapPost("/api/security-visitor/guard",async(GuardRequest x,AuthService a,HttpContext h,CancellationToken c)=>await Call(a,h,c,"SEC_GUARDS",x.Id>0?"EDIT":"ADD","select society_manager.sp_security_guard_save(@s,@id,@code,@name,@mobile,@gov,@agency,@type,@join,@active,@u)",("id",x.Id),("code",x.Code),("name",x.Name),("mobile",x.Mobile??""),("gov",x.GovernmentId??""),("agency",x.AgencyName??""),("type",x.GuardType??""),("join",(object?)x.JoiningDate??DBNull.Value),("active",x.Active),("u",x.UserId)));
        app.MapPost("/api/security-visitor/shift",async(ShiftRequest x,AuthService a,HttpContext h,CancellationToken c)=>{if(!TimeSpan.TryParse(x.Start,out var st)||!TimeSpan.TryParse(x.End,out var en))return Results.BadRequest(new{message="Valid shift start and end times are required."});return await Call(a,h,c,"SEC_ROSTER",x.Id>0?"EDIT":"ADD","select society_manager.sp_security_shift_save(@s,@id,@code,@name,@type,@start,@end,@active,@u)",("id",x.Id),("code",x.Code),("name",x.Name),("type",x.ShiftType),("start",st),("end",en),("active",x.Active),("u",x.UserId));});
        app.MapPost("/api/security-visitor/roster",async(RosterRequest x,AuthService a,HttpContext h,CancellationToken c)=>await Call(a,h,c,"SEC_ROSTER","EDIT","select society_manager.sp_security_roster_save(@s,@id,@guard,@shift,@date,@att,@in,@out,@remark,@u)",("id",x.Id),("guard",x.GuardId),("shift",x.ShiftId),("date",x.RosterDate),("att",x.AttendanceStatus),("in",(object?)x.CheckIn??DBNull.Value),("out",(object?)x.CheckOut??DBNull.Value),("remark",x.Remark??""),("u",x.UserId)));
        app.MapPost("/api/security-visitor/gate",async(GateRequest x,AuthService a,HttpContext h,CancellationToken c)=>await Call(a,h,c,"SEC_GATES",x.Id>0?"EDIT":"ADD","select society_manager.sp_security_gate_save(@s,@id,@code,@name,@type,@guard,@active,@u)",("id",x.Id),("code",x.Code),("name",x.Name),("type",x.GateType),("guard",(object?)x.GuardId??DBNull.Value),("active",x.Active),("u",x.UserId)));
        app.MapPost("/api/security-visitor/incident",IncidentUpload);
        app.MapPost("/api/security-visitor/incident/status",async(IncidentStatusRequest x,AuthService a,HttpContext h,CancellationToken c)=>await Call(a,h,c,"SEC_INCIDENTS","EDIT","select society_manager.sp_security_incident_status(@s,@id,@status,@remark,@u)",("id",x.IncidentId),("status",x.Status),("remark",x.Remark??""),("u",x.UserId)));
        app.MapPost("/api/security-visitor/invitation",async(InvitationRequest x,AuthService a,HttpContext h,CancellationToken c)=>await Call(a,h,c,"VIS_PREAPPROVAL","ADD","select society_manager.sp_visitor_invitation_save(@s,@id,@customer,@flat,@name,@mobile,@purpose,@type,@date,@time,@vehicle,@vehicleType,@u)",("id",x.Id),("customer",x.CustomerId),("flat",x.FlatId),("name",x.VisitorName),("mobile",x.Mobile??""),("purpose",x.Purpose??""),("type",x.VisitorType),("date",x.ExpectedDate),("time",(object?)x.ExpectedTime??DBNull.Value),("vehicle",x.VehicleNo??""),("vehicleType",x.VehicleType??""),("u",x.UserId)));
        app.MapPost("/api/security-visitor/invitation/status",async(ApprovalRequest x,AuthService a,HttpContext h,CancellationToken c)=>await Call(a,h,c,"VIS_PREAPPROVAL","APPROVE","select society_manager.sp_visitor_approve(@s,@id,@status,@u)",("id",x.InvitationId),("status",x.Status),("u",x.UserId)));
        app.MapPost("/api/security-visitor/walkin",WalkIn);
        app.MapPost("/api/security-visitor/entry-exit",async(EntryExitRequest x,AuthService a,HttpContext h,CancellationToken c)=>await Call(a,h,c,"VIS_ENTRY_EXIT",x.Action=="EXIT"?"EDIT":"ADD","select society_manager.sp_visitor_entry_exit(@s,@id,@action,@gate,@guard,@u)",("id",x.EntryId),("action",x.Action),("gate",(object?)x.GateId??DBNull.Value),("guard",(object?)x.GuardId??DBNull.Value),("u",x.UserId)));
        app.MapPost("/api/security-visitor/blacklist",async(BlacklistRequest x,AuthService a,HttpContext h,CancellationToken c)=>await Call(a,h,c,"VIS_BLACKLIST",x.Id>0?"EDIT":"ADD","select society_manager.sp_blacklist_save(@s,@id,@name,@mobile,@vehicle,@reason,@from,@to,@active,@u)",("id",x.Id),("name",x.VisitorName??""),("mobile",x.Mobile??""),("vehicle",x.VehicleNo??""),("reason",x.Reason),("from",(object?)x.StartDate??DBNull.Value),("to",(object?)x.EndDate??DBNull.Value),("active",x.Active),("u",x.UserId)));
    }
    static async Task<IResult> WalkIn(HttpRequest request,AuthService a,HttpContext h,CancellationToken c)
    {
        var g=await Check(a,h,c,"VIS_WALKIN","ADD");if(g is not null)return g;var s=await Session(a,h,c);
        if(!request.HasFormContentType)return Results.BadRequest(new{message="Visitor form is required."});
        var f=await request.ReadFormAsync(c);
        var restricted=bool.TryParse(f["overrideRestricted"],out var ov)&&ov;
        if(restricted && (s!.RoleCode is not ("SOCIETY_ADMIN" or "SUPER_ADMIN") || !await a.HasPermissionAsync(s.UserId,"VIS_WALKIN","APPROVE",c)))return Results.Forbid();
        byte[]? photo=null;string? photoType=null;var file=f.Files["photo"];
        if(file is not null&&file.Length>0){if(file.Length>2_000_000)return Results.BadRequest(new{message="Photo must be 2 MB or smaller."});if(file.ContentType is not ("image/jpeg" or "image/png"))return Results.BadRequest(new{message="Only JPG or PNG photos are allowed."});await using var ms=new MemoryStream();await file.CopyToAsync(ms,c);photo=ms.ToArray();photoType=file.ContentType;}
        long? ParseLong(string key){return long.TryParse(f[key].FirstOrDefault(),out var n)?n:null;}
        return await Call(a,h,c,"VIS_WALKIN","ADD","select society_manager.sp_visitor_walkin(@s,@flat,@customer,@name,@phone,@type,@purpose,@vehicle,@vehicleType,@gate,@guard,@idType,@idNumber,@photo,@photoType,@u,@override,@overrideReason)",("flat",(object?)ParseLong("flatId")??DBNull.Value),("customer",(object?)ParseLong("customerId")??DBNull.Value),("name",f["visitorName"].FirstOrDefault()??""),("phone",f["phone"].FirstOrDefault()??""),("type",f["visitorType"].FirstOrDefault()??""),("purpose",f["purpose"].FirstOrDefault()??""),("vehicle",f["vehicleNo"].FirstOrDefault()??""),("vehicleType",f["vehicleType"].FirstOrDefault()??""),("gate",(object?)ParseLong("gateId")??DBNull.Value),("guard",(object?)ParseLong("guardId")??DBNull.Value),("idType",f["idType"].FirstOrDefault()??""),("idNumber",f["idNumber"].FirstOrDefault()??""),("photo",(object?)photo??DBNull.Value),("photoType",(object?)photoType??DBNull.Value),("u",s!.UserId),("override",restricted),("overrideReason",f["overrideReason"].FirstOrDefault()??""));
    }
    static async Task<IResult> IncidentUpload(HttpRequest request,AuthService a,HttpContext h,CancellationToken c)
    {
        var g=await Check(a,h,c,"SEC_INCIDENTS","ADD");if(g is not null)return g;var s=await Session(a,h,c);
        if(!request.HasFormContentType)return Results.BadRequest(new{message="Incident form is required."});
        var f=await request.ReadFormAsync(c);var file=f.Files["file"];byte[]? data=null;string? name=null;string? type=null;
        if(file is not null && file.Length>0){if(file.Length>5_000_000)return Results.BadRequest(new{message="Attachment must be 5 MB or smaller."});if(file.ContentType is not ("image/jpeg" or "image/png" or "application/pdf"))return Results.BadRequest(new{message="Only JPG, PNG or PDF attachments are allowed."});await using var ms=new MemoryStream();await file.CopyToAsync(ms,c);data=ms.ToArray();name=Path.GetFileName(file.FileName);type=file.ContentType;}
        DateTimeOffset.TryParse(f["occurredAt"],out var when);if(when==default)when=DateTimeOffset.Now;
        return await Call(a,h,c,"SEC_INCIDENTS","ADD","select society_manager.sp_security_incident_save(@s,@id,@type,@gate,@flat,@visitor,@vehicle,@when,@location,@description,@status,@file,@content,@data,@u)",("id",long.Parse(f["id"].FirstOrDefault()??"0")),("type",f["incidentType"].FirstOrDefault()??"OTHER"),("gate",long.TryParse(f["gateId"],out var gate)?(object)gate:DBNull.Value),("flat",long.TryParse(f["flatId"],out var flat)?(object)flat:DBNull.Value),("visitor",long.TryParse(f["visitorEntryId"],out var ve)?(object)ve:DBNull.Value),("vehicle",f["vehicleNo"].FirstOrDefault()??""),("when",when),("location",f["location"].FirstOrDefault()??""),("description",f["description"].FirstOrDefault()??""),("status",f["status"].FirstOrDefault()??"Open"),("file",(object?)name??DBNull.Value),("content",(object?)type??DBNull.Value),("data",(object?)data??DBNull.Value),("u",s!.UserId));
    }
}

public sealed record GuardRequest(long Id,string Code,string Name,string? Mobile,string? GovernmentId,string? AgencyName,string? GuardType,DateOnly? JoiningDate,bool Active,long UserId);
public sealed record ShiftRequest(long Id,string Code,string Name,string ShiftType,string Start,string End,bool Active,long UserId);
public sealed record RosterRequest(long Id,long GuardId,long ShiftId,DateOnly RosterDate,string AttendanceStatus,DateTimeOffset? CheckIn,DateTimeOffset? CheckOut,string? Remark,long UserId);
public sealed record GateRequest(long Id,string Code,string Name,string GateType,long? GuardId,bool Active,long UserId);
public sealed record IncidentStatusRequest(long IncidentId,string Status,string? Remark,long UserId);
public sealed record InvitationRequest(long Id,long CustomerId,long FlatId,string VisitorName,string? Mobile,string? Purpose,string VisitorType,DateOnly ExpectedDate,TimeSpan? ExpectedTime,string? VehicleNo,string? VehicleType,long UserId);
public sealed record ApprovalRequest(long InvitationId,string Status,long UserId);
public sealed record EntryExitRequest(long EntryId,string Action,long? GateId,long? GuardId,long UserId);
public sealed record BlacklistRequest(long Id,string? VisitorName,string? Mobile,string? VehicleNo,string Reason,DateOnly? StartDate,DateOnly? EndDate,bool Active,long UserId);
public sealed record WalkInRequest(long? FlatId,long? CustomerId,string VisitorName,string? Phone,string VisitorType,string? Purpose,string? VehicleNo,string? VehicleType,long? GateId,long? GuardId,string? IdType,string? IdNumber,byte[]? Photo,string? PhotoContentType,bool OverrideRestricted,string? OverrideReason);
