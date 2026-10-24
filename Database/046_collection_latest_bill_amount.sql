BEGIN;
CREATE OR REPLACE FUNCTION society_manager.fn_collection_account_summary(p_society_id bigint,p_flat_id bigint)
RETURNS TABLE(current_dues numeric,arrears_component numeric,dpc_component numeric,rebate_component numeric,current_period_billed numeric,paid_to_date numeric,pending_service_charges numeric,due_date date,unpaid_bill_count bigint)
LANGUAGE sql STABLE AS $function$
WITH latest_period AS (
 SELECT max(b.bill_month) AS bill_month
 FROM society_manager.t_bill b
 WHERE b.society_id=p_society_id AND b.flat_id=p_flat_id
   AND b.status NOT IN ('Cancelled','Void','Reversed')
)
SELECT
 COALESCE(sum(GREATEST(b.total_amount-b.paid_amount,0)) FILTER (WHERE b.status NOT IN ('Paid','Cancelled','Void','Reversed') AND b.total_amount>b.paid_amount),0)::numeric(18,2),
 COALESCE(sum(b.arrear_amount) FILTER (WHERE b.status NOT IN ('Paid','Cancelled','Void','Reversed') AND b.total_amount>b.paid_amount),0)::numeric(18,2),
 COALESCE(sum(b.dpc_amount) FILTER (WHERE b.status NOT IN ('Paid','Cancelled','Void','Reversed') AND b.total_amount>b.paid_amount),0)::numeric(18,2),
 COALESCE(sum(b.rebate_amount) FILTER (WHERE b.status NOT IN ('Paid','Cancelled','Void','Reversed') AND b.total_amount>b.paid_amount),0)::numeric(18,2),
 COALESCE(sum(GREATEST(b.subtotal + b.tax_amount - b.rebate_amount,0)) FILTER (WHERE b.status NOT IN ('Cancelled','Void','Reversed') AND b.bill_month=lp.bill_month),0)::numeric(18,2),
 COALESCE(sum(b.paid_amount) FILTER (WHERE b.status NOT IN ('Cancelled','Void','Reversed')),0)::numeric(18,2),
 COALESCE((SELECT sum(sc.amount) FROM society_manager.t_service_charge sc WHERE sc.society_id=p_society_id AND sc.flat_id=p_flat_id AND sc.status='Pending'),0)::numeric(18,2),
 min(b.due_date) FILTER (WHERE b.total_amount>b.paid_amount AND b.status NOT IN ('Paid','Cancelled','Void','Reversed')),
 count(*) FILTER (WHERE b.total_amount>b.paid_amount AND b.status NOT IN ('Paid','Cancelled','Void','Reversed'))
FROM society_manager.t_bill b CROSS JOIN latest_period lp
WHERE b.society_id=p_society_id AND b.flat_id=p_flat_id;
$function$;
COMMIT;