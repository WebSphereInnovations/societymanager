using Npgsql;
using Society360.Data;
using Society360.Security;

namespace Society360.Modules.Customer;
public static class CustomerEndpoints{
 public static void MapCustomerEndpoints(this WebApplication app){
  app.MapGet("/api/customer/me",async(AuthService auth,HttpContext http,CancellationToken ct)=>await Query(auth,http,ct,"fn_customer_portal",1,9));
  app.MapGet("/api/customer/bills",async(AuthService auth,HttpContext http,CancellationToken ct)=>await Query(auth,http,ct,"fn_customer_portal_bills",1,8));
  app.MapGet("/api/customer/complaints",async(AuthService auth,HttpContext http,CancellationToken ct)=>await Query(auth,http,ct,"fn_customer_portal_complaints",1,8));
  app.MapPost("/api/customer/complaints",async(CustomerComplaintRequest x,AuthService auth,HttpContext http,CancellationToken ct)=>{
   var s=await AuthGuard.Get(http,auth,ct);if(s is null)return Results.Unauthorized();if(s.RoleCode!="RESIDENT")return Results.Forbid();
   await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));await cn.OpenAsync(ct);
   await using var cmd=new NpgsqlCommand("select society_manager.fn_customer_portal_create_complaint(@u,@cat,@title,@desc,@priority)",cn);
   cmd.Parameters.AddWithValue("u",s.UserId);cmd.Parameters.AddWithValue("cat",x.Category);cmd.Parameters.AddWithValue("title",x.Title);cmd.Parameters.AddWithValue("desc",x.Description);cmd.Parameters.AddWithValue("priority",x.Priority);
   var id=await cmd.ExecuteScalarAsync(ct);return Results.Ok(new{complaintId=id});
  });
 }
 static async Task<IResult> Query(AuthService auth,HttpContext http,CancellationToken ct,string fn,int skip,int columns){
  var s=await AuthGuard.Get(http,auth,ct);if(s is null)return Results.Unauthorized();if(s.RoleCode!="RESIDENT")return Results.Forbid();
  await using var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));await cn.OpenAsync(ct);
  await using var cmd=new NpgsqlCommand($"select * from society_manager.{fn}(@u)",cn);cmd.Parameters.AddWithValue("u",s.UserId);
  await using var r=await cmd.ExecuteReaderAsync(ct);var rows=new List<Dictionary<string,object?>>();
  while(await r.ReadAsync(ct)){var d=new Dictionary<string,object?>();for(var i=0;i<columns;i++)d[r.GetName(i)]=r.IsDBNull(i)?null:r.GetValue(i);rows.Add(d);}return Results.Ok(rows);
 }
}
public sealed record CustomerComplaintRequest(string Category,string Title,string Description,string Priority);
