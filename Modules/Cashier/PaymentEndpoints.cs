using Npgsql;
using Society360.Data;
using Society360.Security;
namespace Society360.Modules.Cashier;
public static class PaymentEndpoints
{
 public static void MapPaymentEndpoints(this WebApplication app)
 {
  app.MapGet("/api/cashier/customer/{customerId:long}/360",async(long id,AuthService a,HttpContext h,CancellationToken c)=>await Customer360(id,a,h,c));
  app.MapPost("/api/cashier/payment",async(PaymentRequest x,AuthService a,HttpContext h,CancellationToken c)=>await Accept(x,a,h,c));
 }
 static async Task<IResult> Customer360(long id,AuthService a,HttpContext h,CancellationToken c){var s=await Guard(a,h,c);if(s is null)return Results.Unauthorized();await using var cn=await Open(c);await using var cmd=new NpgsqlCommand("select * from society_manager.fn_cashier_customer_360(@society,@customer)",cn);cmd.Parameters.AddWithValue("society",s.SocietyId!.Value);cmd.Parameters.AddWithValue("customer",id);return Results.Ok(await One(cmd,18,c));}
 static async Task<IResult> Accept(PaymentRequest x,AuthService a,HttpContext h,CancellationToken c){var s=await Guard(a,h,c);if(s is null)return Results.Unauthorized();await using var cn=await Open(c);await using var cmd=new NpgsqlCommand("select society_manager.fn_cashier_accept_payment(@society,@customer,@flat,@amount,@mode,@reference,@remarks,@user)",cn);cmd.Parameters.AddWithValue("society",s.SocietyId!.Value);cmd.Parameters.AddWithValue("customer",x.CustomerId);cmd.Parameters.AddWithValue("flat",x.FlatId);cmd.Parameters.AddWithValue("amount",x.Amount);cmd.Parameters.AddWithValue("mode",x.PaymentMode);cmd.Parameters.AddWithValue("reference",(object?)x.ReferenceNo??DBNull.Value);cmd.Parameters.AddWithValue("remarks",(object?)x.Remarks??DBNull.Value);cmd.Parameters.AddWithValue("user",s.UserId);return Results.Ok(new{success=true,paymentId=await cmd.ExecuteScalarAsync(c)});}
 static async Task<SessionContext?> Guard(AuthService a,HttpContext h,CancellationToken c){var s=await AuthGuard.Get(h,a,c);if(s is null||s.SocietyId is null||s.RoleCode is not("COLLECTOR" or "BILLING_ADMIN"))return null;return s;}
 static async Task<NpgsqlConnection> Open(CancellationToken c){var cn=new NpgsqlConnection(Environment.GetEnvironmentVariable("SOCIETY360_DB_CONNECTION"));await cn.OpenAsync(c);return cn;}
 static async Task<object?> One(NpgsqlCommand cmd,int n,CancellationToken c){await using var r=await cmd.ExecuteReaderAsync(c);if(!await r.ReadAsync(c))return null;var row=new Dictionary<string,object?>();for(var i=0;i<n;i++)row[r.GetName(i)]=r.IsDBNull(i)?null:r.GetValue(i);return row;}
}
public sealed record PaymentRequest(long CustomerId,long FlatId,decimal Amount,string PaymentMode,string? ReferenceNo,string? Remarks);