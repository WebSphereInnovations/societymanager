
using System.Text.Json;
using Npgsql;
using Society360.Data;
using Society360.Security;
namespace Society360.Modules.SocietyAdmin;

public static class RequestedSocietyManagerEndpoints
{
    static string? Conn()=>Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION");
    static async Task<SessionContext?> Session(AuthService auth,HttpContext http,CancellationToken ct)=>await AuthGuard.Get(http,auth,ct);
    static async Task<IResult> Rows(NpgsqlCommand cmd,CancellationToken ct)
    {
        await using var r=await cmd.ExecuteReaderAsync(ct);var list=new List<Dictionary<string,object?>>();
        while(await r.ReadAsync(ct)){var x=new Dictionary<string,object?>();for(int i=0;i<r.FieldCount;i++)x[r.GetName(i)]=r.IsDBNull(i)?null:r.GetValue(i);list.Add(x);}return Results.Ok(list);
    }
    static async Task<NpgsqlConnection> Open(){var c=new NpgsqlConnection(Conn());await c.OpenAsync();return c;}
    static async Task<IResult?> Guard(AuthService auth,HttpContext http,CancellationToken ct,string module,string action="VIEW")
    {
        var s=await Session(auth,http,ct);if(s is null)return Results.Unauthorized();
        if(s.SocietyId is null)return Results.BadRequest(new{message="No society selected."});
        if(!await auth.HasPermissionAsync(s.UserId,module,action,ct))return Results.Forbid();return null;
    }
    static async Task<IResult> Query(AuthService auth,HttpContext http,CancellationToken ct,string module,string fn,params (string,object)[] args)
    {
        var g=await Guard(auth,http,ct,module);if(g is not null)return g;var s=await Session(auth,http,ct)!;
        await using var cn=await Open();var ps="@s"+(args.Length>0?","+string.Join(",",args.Select((a,i)=>"@p"+i)):"");await using var cmd=new NpgsqlCommand($"select * from society_manager.{fn}({ps})",cn);
        cmd.Parameters.AddWithValue("s",s!.SocietyId!.Value);for(int i=0;i<args.Length;i++)cmd.Parameters.AddWithValue("p"+i,args[i].Item2);
        return await Rows(cmd,ct);
    }
    public static void MapRequestedSocietyManagerEndpoints(this WebApplication app)
    {
        app.MapGet("/api/sm/dashboard",async(AuthService a,HttpContext h,CancellationToken c)=>{var s=await Session(a,h,c);if(s is null)return Results.Unauthorized();if(s.SocietyId is null||!await a.HasPermissionAsync(s.UserId,"APP_DASHBOARD","VIEW",c))return Results.Forbid();await using var cn=await Open();await using var cmd=new NpgsqlCommand("select * from society_manager.fn_dashboard_summary(@s,current_date)",cn);cmd.Parameters.AddWithValue("s",s.SocietyId.Value);return await Rows(cmd,c);});

        app.MapGet("/api/sm/subscription/history",async(AuthService a,HttpContext h,CancellationToken c)=>await Query(a,h,c,"ADMIN_SUBSCRIPTION","fn_subscription_history"));
        app.MapGet("/api/sm/buildings",async(AuthService a,HttpContext h,CancellationToken c)=>await Query(a,h,c,"SOC_NEW_BUILDING","fn_building_catalog"));
        app.MapGet("/api/sm/wings",async(AuthService a,HttpContext h,CancellationToken c)=>await Query(a,h,c,"SOC_NEW_WING","fn_wing_catalog"));
        app.MapGet("/api/sm/parking",async(AuthService a,HttpContext h,CancellationToken c)=>await Query(a,h,c,"SOC_NEW_PARKING","fn_parking_catalog"));
        app.MapGet("/api/sm/management",async(string? q,AuthService a,HttpContext h,CancellationToken c)=>await Query(a,h,c,"SOC_CUSTOMER_MASTER","fn_society_management",("q",q??"")));
        app.MapGet("/api/sm/customers/search",async(string? q,AuthService a,HttpContext h,CancellationToken c)=>await Query(a,h,c,"CRM_CUSTOMER_ACCOUNT","fn_customer_search_requested",("q",q??"")));
        app.MapGet("/api/sm/collection/search",async(string? q,AuthService a,HttpContext h,CancellationToken c)=>await Query(a,h,c,"COL_ACCEPT_PAYMENT","fn_collection_consumer_search",("q",q??"")));
        app.MapGet("/api/sm/payment-modes",async(AuthService a,HttpContext h,CancellationToken c)=>await Query(a,h,c,"COL_ACCEPT_PAYMENT","fn_payment_modes"));
        app.MapGet("/api/sm/service-types",async(AuthService a,HttpContext h,CancellationToken c)=>await Query(a,h,c,"COL_SERVICE_PAYMENT","fn_service_charge_types"));
        app.MapGet("/api/sm/banks",async(AuthService a,HttpContext h,CancellationToken c)=>await Query(a,h,c,"COL_BANK_DETAILS","fn_bank_details"));
        app.MapGet("/api/sm/cheques",async(AuthService a,HttpContext h,CancellationToken c)=>await Query(a,h,c,"COL_DISHONORED","fn_dishonored_cheques"));
        app.MapGet("/api/sm/document-types",async(AuthService a,HttpContext h,CancellationToken c)=>await Query(a,h,c,"BACKOFFICE_DOCUMENT","fn_document_types"));
        app.MapGet("/api/sm/tickets",async(AuthService a,HttpContext h,CancellationToken c)=>await Query(a,h,c,"BACKOFFICE_TICKET","fn_tickets"));
        app.MapGet("/api/sm/ticket-statuses",async(AuthService a,HttpContext h,CancellationToken c)=>{var g=await Guard(a,h,c,"BACKOFFICE_TICKET");if(g is not null)return g;await using var cn=await Open();await using var cmd=new NpgsqlCommand("select * from society_manager.fn_ticket_statuses()",cn);return await Rows(cmd,c);});
        app.MapGet("/api/sm/notifications",async(AuthService a,HttpContext h,CancellationToken c)=>{var s=await Session(a,h,c);if(s is null)return Results.Unauthorized();if(s.SocietyId is null||!await a.HasPermissionAsync(s.UserId,"NOTIFICATION_CENTER","VIEW",c))return Results.Forbid();await using var cn=await Open();await using var cmd=new NpgsqlCommand("select * from society_manager.fn_notifications(@s,@u)",cn);cmd.Parameters.AddWithValue("s",s.SocietyId.Value);cmd.Parameters.AddWithValue("u",s.UserId);return await Rows(cmd,c);});
        app.MapGet("/api/sm/mis/consumer",async(long? wingId,string? q,AuthService a,HttpContext h,CancellationToken c)=>await Query(a,h,c,"MIS_CONSUMER_MASTER","fn_mis_consumer_master",("wing",wingId??(object)DBNull.Value),("q",q??"")));
        app.MapGet("/api/sm/mis/billing",async(DateOnly month,AuthService a,HttpContext h,CancellationToken c)=>await Query(a,h,c,"MIS_BILLING_DATA","fn_mis_billing",("month",month)));
        app.MapGet("/api/sm/mis/collection",async(DateOnly month,string? status,AuthService a,HttpContext h,CancellationToken c)=>await Query(a,h,c,"MIS_COLLECTION_DETAILS","fn_mis_collection",("month",month),("status",status??"")));
        app.MapGet("/api/sm/mis/complaints",async(string? status,AuthService a,HttpContext h,CancellationToken c)=>await Query(a,h,c,"MIS_COMPLAINT_HISTORY","fn_mis_complaints",("status",status??"")));

        app.MapGet("/api/sm/customer/{id:long}",async(long id,AuthService a,HttpContext h,CancellationToken c)=>{var g=await Guard(a,h,c,"CRM_CUSTOMER_ACCOUNT");if(g is not null)return g;var s=await Session(a,h,c);await using var cn=await Open();await using var cmd=new NpgsqlCommand("select society_manager.fn_consumer_account_full(@s,@c)",cn);cmd.Parameters.AddWithValue("s",s!.SocietyId!.Value);cmd.Parameters.AddWithValue("c",id);await using var r=await cmd.ExecuteReaderAsync(c);if(!await r.ReadAsync(c))return Results.NotFound();return Results.Json(r.GetFieldValue<JsonDocument>(0).RootElement);});
        app.MapGet("/api/sm/customer/{id:long}/documents",async(long id,AuthService a,HttpContext h,CancellationToken c)=>await QueryCustomer(a,h,c,id,"BACKOFFICE_DOCUMENT","fn_customer_documents"));
        app.MapGet("/api/sm/customer/{id:long}/service-history",async(long id,AuthService a,HttpContext h,CancellationToken c)=>await QueryCustomer(a,h,c,id,"CRM_CUSTOMER_ACCOUNT","fn_customer_service_history_requested"));

        app.MapPost("/api/sm/building/save",async(BuildingRequest x,AuthService a,HttpContext h,CancellationToken c)=>await Call(a,h,c,"SOC_NEW_BUILDING","select society_manager.sp_save_building(@s,@id,@code,@name,@floor,@u,@r)",new[]{("id",(object)x.Id),("code",(object)x.Code),("name",(object)x.Name),("floor",(object)x.FloorCount),("u",(object)0L),("r",(object)(x.Remark??""))}));
        app.MapPost("/api/sm/wing/save",async(WingRequest x,AuthService a,HttpContext h,CancellationToken c)=>await Call(a,h,c,"SOC_NEW_WING","select society_manager.sp_save_wing(@s,@id,@building,@code,@name,@u,@r)",new[]{("id",(object)x.Id),("building",(object)x.BuildingId),("code",(object)x.Code),("name",(object)x.Name),("u",(object)0L),("r",(object)(x.Remark??""))}));
        app.MapPost("/api/sm/flat/save",async(FlatRequest x,AuthService a,HttpContext h,CancellationToken c)=>await Call(a,h,c,"SOC_NEW_FLAT","select society_manager.sp_save_flat(@s,@id,@building,@wing,@flat,@floor,@type,@area,@occ,@u,@r)",new[]{("id",(object)x.Id),("building",(object?)x.BuildingId??DBNull.Value),("wing",(object?)x.WingId??DBNull.Value),("flat",(object)x.FlatNo),("floor",(object?)x.FloorNo??DBNull.Value),("type",(object)(x.UnitType??"Residential")),("area",(object)x.Area),("occ",(object)(x.Occupancy??"Vacant")),("u",(object)0L),("r",(object)(x.Remark??""))}));
        app.MapPost("/api/sm/parking/save",async(ParkingRequest x,AuthService a,HttpContext h,CancellationToken c)=>await Call(a,h,c,"SOC_NEW_PARKING","select society_manager.sp_save_parking(@s,@id,@slot,@type,@charge,@u,@r)",new[]{("id",(object)x.Id),("slot",(object)x.SlotNo),("type",(object)x.SlotType),("charge",(object)x.Charge),("u",(object)0L),("r",(object)(x.Remark??""))}));
        app.MapPost("/api/sm/customer/save",async(CustomerRequest x,AuthService a,HttpContext h,CancellationToken c)=>await Call(a,h,c,"SOC_CUSTOMER_MASTER","select society_manager.sp_save_customer(@s,@id,@code,@name,@type,@phone,@email,@flat,@u,@r)",new[]{("id",(object)x.Id),("code",(object)(x.Code??"")),("name",(object)x.Name),("type",(object)(x.CustomerType??"Owner")),("phone",(object)(x.Phone??"")),("email",(object)(x.Email??"")),("flat",(object?)x.FlatId??DBNull.Value),("u",(object)0L),("r",(object)(x.Remark??""))}));
        app.MapPost("/api/sm/customer/attribute",async(AttributeRequest x,AuthService a,HttpContext h,CancellationToken c)=>await Call(a,h,c,"BACKOFFICE_SERVICE","select society_manager.sp_update_customer_attribute(@s,@customer,@code,@name,@value,@u,@r)",new[]{("customer",(object)x.CustomerId),("code",(object)x.AttributeCode),("name",(object)x.AttributeName),("value",(object)x.NewValue),("u",(object)0L),("r",(object)(x.Remark??""))}));
        app.MapPost("/api/sm/customer/area",async(AreaRequest x,AuthService a,HttpContext h,CancellationToken c)=>await Call(a,h,c,"BACKOFFICE_SERVICE","select society_manager.sp_update_flat_area(@s,@customer,@flat,@area,@u,@r)",new[]{("customer",(object)x.CustomerId),("flat",(object)x.FlatId),("area",(object)x.Area),("u",(object)0L),("r",(object)(x.Remark??""))}));
        app.MapPost("/api/sm/payment",async(PaymentRequest x,AuthService a,HttpContext h,CancellationToken c)=>await Call(a,h,c,"COL_ACCEPT_PAYMENT","select society_manager.sp_accept_payment(@s,@customer,@flat,@amount,@mode,@ref,@remark,@u)",new[]{("customer",(object)x.CustomerId),("flat",(object)x.FlatId),("amount",(object)x.Amount),("mode",(object)x.PaymentMode),("ref",(object)(x.ReferenceNo??"")),("remark",(object)(x.Remarks??"")),("u",(object)0L)}));
        app.MapGet("/api/sm/payment/{id:long}/receipt",async(long id,AuthService a,HttpContext h,CancellationToken c)=>await QueryPayment(a,h,c,id));
        app.MapPost("/api/sm/service-payment",async(ServicePaymentRequest x,AuthService a,HttpContext h,CancellationToken c)=>await Call(a,h,c,"COL_SERVICE_PAYMENT","select society_manager.sp_save_service_charge(@s,@customer,@flat,@type,@amount,@ref,@remark,@u)",new[]{("customer",(object)x.CustomerId),("flat",(object?)x.FlatId??DBNull.Value),("type",(object)x.TypeId),("amount",(object)x.Amount),("ref",(object)(x.ReferenceNo??"")),("remark",(object)(x.Remarks??"")),("u",(object)0L)}));
        app.MapPost("/api/sm/bank/save",async(BankRequest x,AuthService a,HttpContext h,CancellationToken c)=>await Call(a,h,c,"COL_BANK_DETAILS","select society_manager.sp_save_bank_detail(@s,@id,@name,@account,@number,@ifsc,@branch,@type,@upi,@active,@u,@r)",new[]{("id",(object)x.Id),("name",(object)x.BankName),("account",(object)(x.AccountName??"")),("number",(object)(x.AccountNumber??"")),("ifsc",(object)(x.IfscCode??"")),("branch",(object)(x.BranchName??"")),("type",(object)(x.AccountType??"")),("upi",(object)(x.UpiId??"")),("active",(object)x.Active),("u",(object)0L),("r",(object)(x.Remark??""))}));
        app.MapPost("/api/sm/cheque",async(ChequeRequest x,AuthService a,HttpContext h,CancellationToken c)=>await Call(a,h,c,"COL_DISHONORED","select society_manager.sp_record_dishonored_cheque(@s,@payment,@reason,@charge,@u,@r)",new[]{("payment",(object)x.PaymentId),("reason",(object)x.ReasonId),("charge",(object)x.BankCharge),("u",(object)0L),("r",(object)(x.Remarks??""))}));
        app.MapPost("/api/sm/ticket",async(TicketRequest x,AuthService a,HttpContext h,CancellationToken c)=>await Call(a,h,c,"BACKOFFICE_TICKET","select society_manager.sp_save_ticket(@s,@id,@title,@description,@status,@priority,@u)",new[]{("id",(object)x.Id),("title",(object)x.Title),("description",(object)(x.Description??"")),("status",(object)x.StatusCode),("priority",(object)x.Priority),("u",(object)0L)}));
        app.MapPost("/api/sm/complaint",async(ComplaintRequest x,AuthService a,HttpContext h,CancellationToken c)=>await Call(a,h,c,"CRM_CUSTOMER_INTERACTION","select society_manager.sp_raise_complaint(@s,@customer,@flat,@category,@title,@description,@u)",new[]{("customer",(object)x.CustomerId),("flat",(object?)x.FlatId??DBNull.Value),("category",(object)x.Category),("title",(object)x.Title),("description",(object)(x.Description??"")),("u",(object)0L)}));
        app.MapPost("/api/sm/document",UploadDocument);
    }
    static async Task<IResult> Call(AuthService a,HttpContext h,CancellationToken c,string module,string sql,(string,object)[] args)
    {
        var g=await Guard(a,h,c,module,"EDIT");if(g is not null)return g;var s=await Session(a,h,c);try{await using var cn=await Open();await using var cmd=new NpgsqlCommand(sql,cn);cmd.Parameters.AddWithValue("s",s!.SocietyId!.Value);foreach(var p in args)cmd.Parameters.AddWithValue(p.Item1,p.Item1=="u"?s.UserId:p.Item2);var id=await cmd.ExecuteScalarAsync(c);return Results.Ok(new{success=true,id});}catch(PostgresException e){return Results.BadRequest(new{message=e.MessageText});}
    }
    static async Task<IResult> QueryCustomer(AuthService a,HttpContext h,CancellationToken c,long id,string module,string fn)
    {var g=await Guard(a,h,c,module);if(g is not null)return g;var s=await Session(a,h,c);await using var cn=await Open();await using var cmd=new NpgsqlCommand($"select * from society_manager.{fn}(@s,@c)",cn);cmd.Parameters.AddWithValue("s",s!.SocietyId!.Value);cmd.Parameters.AddWithValue("c",id);return await Rows(cmd,c);}
    static async Task<IResult> QueryPayment(AuthService a,HttpContext h,CancellationToken c,long id)
    {var g=await Guard(a,h,c,"COL_ACCEPT_PAYMENT");if(g is not null)return g;var s=await Session(a,h,c);await using var cn=await Open();await using var cmd=new NpgsqlCommand("select * from society_manager.fn_payment_receipt(@s,@p)",cn);cmd.Parameters.AddWithValue("s",s!.SocietyId!.Value);cmd.Parameters.AddWithValue("p",id);return await Rows(cmd,c);}
    static async Task<IResult> UploadDocument(HttpRequest req,AuthService a,HttpContext h,CancellationToken c)
    {var g=await Guard(a,h,c,"BACKOFFICE_DOCUMENT","ADD");if(g is not null)return g;var s=await Session(a,h,c);var form=await req.ReadFormAsync(c);if(!long.TryParse(form["customerId"],out var customerId)||!long.TryParse(form["documentTypeId"],out var typeId))return Results.BadRequest(new{message="Customer and document type are required."});var file=form.Files["file"];if(file is null||file.Length==0||file.Length>10*1024*1024)return Results.BadRequest(new{message="Document is required and must be 10 MB or less."});await using var ms=new MemoryStream();await file.CopyToAsync(ms,c);try{await using var cn=await Open();await using var cmd=new NpgsqlCommand("select society_manager.sp_save_document(@s,@customer,@flat,@type,@name,@content,@size,@data,@u)",cn);cmd.Parameters.AddWithValue("s",s!.SocietyId!.Value);cmd.Parameters.AddWithValue("customer",customerId);cmd.Parameters.AddWithValue("flat",long.TryParse(form["flatId"],out var flat)?flat:(object)DBNull.Value);cmd.Parameters.AddWithValue("type",typeId);cmd.Parameters.AddWithValue("name",file.FileName);cmd.Parameters.AddWithValue("content",file.ContentType??"application/octet-stream");cmd.Parameters.AddWithValue("size",file.Length);cmd.Parameters.AddWithValue("data",ms.ToArray());cmd.Parameters.AddWithValue("u",s.UserId);var id=await cmd.ExecuteScalarAsync(c);return Results.Ok(new{success=true,id});}catch(PostgresException e){return Results.BadRequest(new{message=e.MessageText});}
    }
}
public sealed record BuildingRequest(long Id,string Code,string Name,int FloorCount,string? Remark);
public sealed record CustomerRequest(long Id,string? Code,string Name,string? CustomerType,string? Phone,string? Email,long? FlatId,string? Remark);
public sealed record AreaRequest(long CustomerId,long FlatId,decimal Area,string? Remark);
public sealed record WingRequest(long Id,long BuildingId,string Code,string Name,string? Remark);
public sealed record FlatRequest(long Id,long? BuildingId,long? WingId,string FlatNo,int? FloorNo,string? UnitType,decimal Area,string? Occupancy,string? Remark);
public sealed record ParkingRequest(long Id,string SlotNo,string SlotType,decimal Charge,string? Remark);
public sealed record AttributeRequest(long CustomerId,string AttributeCode,string AttributeName,string NewValue,string? Remark);
public sealed record PaymentRequest(long CustomerId,long FlatId,decimal Amount,string PaymentMode,string? ReferenceNo,string? Remarks);
public sealed record ServicePaymentRequest(long CustomerId,long? FlatId,long TypeId,decimal Amount,string? ReferenceNo,string? Remarks);
public sealed record BankRequest(long Id,string BankName,string? AccountName,string? AccountNumber,string? IfscCode,string? BranchName,string? AccountType,string? UpiId,bool Active,string? Remark);
public sealed record ChequeRequest(long PaymentId,long ReasonId,decimal BankCharge,string? Remarks);
public sealed record TicketRequest(long Id,string Title,string? Description,string StatusCode,string Priority);
public sealed record ComplaintRequest(long CustomerId,long? FlatId,string Category,string Title,string? Description);
