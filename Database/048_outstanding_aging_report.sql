-- Read-only, society-scoped outstanding/aging report based on actual bill balances.
-- Additive migration: does not alter or rewrite financial records.
BEGIN;
CREATE OR REPLACE FUNCTION society_manager.fn_mis_outstanding(p_society_id bigint,p_as_of_date date)
RETURNS TABLE(
 bill_id bigint,bill_no varchar,bill_month date,due_date date,flat_no varchar,customer_name varchar,
 total_amount numeric,paid_amount numeric,outstanding_amount numeric,days_overdue integer,aging_bucket varchar,bill_status varchar
)
LANGUAGE sql STABLE AS $function$
 SELECT b.bill_id,b.bill_no,b.bill_month,b.due_date,f.flat_no,c.full_name,
        COALESCE(b.total_amount,0)::numeric AS total_amount,
        COALESCE(b.paid_amount,0)::numeric AS paid_amount,
        GREATEST(COALESCE(b.total_amount,0)-COALESCE(b.paid_amount,0),0)::numeric AS outstanding_amount,
        CASE WHEN b.due_date IS NULL OR b.due_date>=p_as_of_date THEN 0 ELSE (p_as_of_date-b.due_date)::integer END AS days_overdue,
        CASE WHEN b.due_date IS NULL OR b.due_date>=p_as_of_date THEN 'Not Due'
             WHEN p_as_of_date-b.due_date<=30 THEN '1-30 Days'
             WHEN p_as_of_date-b.due_date<=60 THEN '31-60 Days'
             WHEN p_as_of_date-b.due_date<=90 THEN '61-90 Days'
             ELSE '90+ Days' END::varchar AS aging_bucket,
        b.status::varchar AS bill_status
 FROM society_manager.t_bill b
 JOIN society_manager.m_flat f ON f.society_id=b.society_id AND f.flat_id=b.flat_id
 LEFT JOIN society_manager.m_customer_flat cf ON cf.society_id=b.society_id AND cf.flat_id=b.flat_id AND cf.is_primary=true
 LEFT JOIN society_manager.m_customer c ON c.society_id=b.society_id AND c.customer_id=cf.customer_id
 WHERE b.society_id=p_society_id
   AND GREATEST(COALESCE(b.total_amount,0)-COALESCE(b.paid_amount,0),0)>0
   AND COALESCE(b.status,'') NOT IN ('Paid','Cancelled','Canceled','Void','Voided','Reversed')
 ORDER BY b.due_date NULLS LAST,b.bill_month,f.flat_no,b.bill_id;
$function$;
COMMIT;
