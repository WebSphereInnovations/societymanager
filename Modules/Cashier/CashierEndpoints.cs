using Npgsql;
using Society360.Data;using Society360.Security;
namespace Society360.Modules.Cashier;
public static class CashierEndpoints{
 public static void MapCashierEndpoints(this WebApplication app){
  app.MapGet("/api/cashier/bills",async(AuthService a,HttpContext h,CancellationToken c)=>await Q(a,h,c,"bills","",10));
  app.MapGet("/api/cashier/collection",async(AuthService a,HttpContext h,CancellationToken c)=>await Q(a,h,c,"collection","",8));
 }
 static async Task<IResult> Q(AuthService a,HttpContext h,CancellationToken c,string fn,string q,int n){var s=await AuthGuard.Get(h,a,c);if(s is null)return Results.Unauthorized();if(s.RoleCode is not ("COLLECTOR" or "BILLING_ADMIN"))return Results.Forbid();if(s.SocietyId is null)return Results.BadRequest();
 await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));await cn.OpenAsync(c);await using var cmd=new NpgsqlCommand(fn=="collection"?"select * from society_manager.fn_society_admin_collection(@sid,current_date-30,current_date)":"select * from society_manager.fn_society_admin_bill_list(@sid,@q)",cn);cmd.Parameters.AddWithValue("sid",s.SocietyId.Value);if(fn!="collection")cmd.Parameters.AddWithValue("q",q);
 await using var r=await cmd.ExecuteReaderAsync(c);var rows=new List<Dictionary<string,object?>>();while(await r.ReadAsync(c)){var d=new Dictionary<string,object?>();for(var i=0;i<n;i++)d[r.GetName(i)]=r.IsDBNull(i)?null:r.GetValue(i);rows.Add(d);}return Results.Ok(rows);}
}
