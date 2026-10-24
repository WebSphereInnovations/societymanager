BEGIN;
CREATE OR REPLACE FUNCTION society_manager.fn_collection_consumer_search(p_society_id bigint, p_search character varying)
RETURNS TABLE(customer_id bigint, customer_code character varying, full_name character varying, phone character varying, email character varying, flat_id bigint, flat_no character varying, wing_name character varying, current_dues numeric, due_date date, last_bill_date date, last_bill_amount numeric, due_status character varying)
LANGUAGE sql AS $function$
WITH q AS (
 SELECT c.customer_id,c.customer_code,c.full_name,c.phone,c.email,f.flat_id,f.flat_no,w.wing_name,
 COALESCE((SELECT sum(GREATEST(b.total_amount-b.paid_amount,0)) FROM society_manager.t_bill b WHERE b.society_id=p_society_id AND b.flat_id=f.flat_id AND b.status NOT IN ('Paid','Cancelled','Void','Reversed')),0)::numeric current_dues,
 (SELECT min(b.due_date) FROM society_manager.t_bill b WHERE b.society_id=p_society_id AND b.flat_id=f.flat_id AND b.status NOT IN ('Paid','Cancelled','Void','Reversed') AND b.total_amount>b.paid_amount) due_date,
 (SELECT max(b.bill_date) FROM society_manager.t_bill b WHERE b.society_id=p_society_id AND b.flat_id=f.flat_id) last_bill_date,
 (SELECT max(b.total_amount) FROM society_manager.t_bill b WHERE b.society_id=p_society_id AND b.flat_id=f.flat_id) last_bill_amount
 FROM society_manager.m_customer c JOIN society_manager.m_customer_flat cf ON cf.customer_id=c.customer_id AND cf.society_id=p_society_id JOIN society_manager.m_flat f ON f.flat_id=cf.flat_id AND f.society_id=p_society_id LEFT JOIN society_manager.m_wing w ON w.wing_id=f.wing_id AND w.society_id=p_society_id
 WHERE c.society_id=p_society_id AND c.is_active AND (coalesce(p_search,'')='' OR c.full_name ILIKE '%'||p_search||'%' OR c.phone ILIKE '%'||p_search||'%' OR c.customer_code ILIKE '%'||p_search||'%' OR f.flat_no ILIKE '%'||p_search||'%')
)
SELECT q.*,CASE WHEN q.due_date IS NULL THEN 'NO_DUE' WHEN current_date<q.due_date THEN 'BEFORE_DUE' WHEN current_date=q.due_date THEN 'DUE_TODAY' ELSE 'OVERDUE' END FROM q ORDER BY full_name,flat_no;
$function$;
CREATE OR REPLACE FUNCTION society_manager.fn_collection_account_summary(p_society_id bigint,p_flat_id bigint)
RETURNS TABLE(current_dues numeric,arrears_component numeric,dpc_component numeric,rebate_component numeric,current_period_billed numeric,paid_to_date numeric,pending_service_charges numeric,due_date date,unpaid_bill_count bigint)
LANGUAGE sql STABLE AS $function$
SELECT
 COALESCE(sum(GREATEST(b.total_amount-b.paid_amount,0)) FILTER (WHERE b.status NOT IN ('Paid','Cancelled','Void','Reversed') AND b.total_amount>b.paid_amount),0)::numeric(18,2),
 COALESCE(sum(b.arrear_amount) FILTER (WHERE b.status NOT IN ('Paid','Cancelled','Void','Reversed') AND b.total_amount>b.paid_amount),0)::numeric(18,2),
 COALESCE(sum(b.dpc_amount) FILTER (WHERE b.status NOT IN ('Paid','Cancelled','Void','Reversed') AND b.total_amount>b.paid_amount),0)::numeric(18,2),
 COALESCE(sum(b.rebate_amount) FILTER (WHERE b.status NOT IN ('Paid','Cancelled','Void','Reversed') AND b.total_amount>b.paid_amount),0)::numeric(18,2),
 COALESCE(sum(b.total_amount) FILTER (WHERE b.status NOT IN ('Cancelled','Void','Reversed') AND b.bill_month>=date_trunc('month',current_date)::date AND b.bill_month<(date_trunc('month',current_date)+interval '1 month')::date),0)::numeric(18,2),
 COALESCE(sum(b.paid_amount) FILTER (WHERE b.status NOT IN ('Cancelled','Void','Reversed')),0)::numeric(18,2),
 COALESCE((SELECT sum(sc.amount) FROM society_manager.t_service_charge sc WHERE sc.society_id=p_society_id AND sc.flat_id=p_flat_id AND sc.status='Pending'),0)::numeric(18,2),
 min(b.due_date) FILTER (WHERE b.total_amount>b.paid_amount AND b.status NOT IN ('Paid','Cancelled','Void','Reversed')),
 count(*) FILTER (WHERE b.total_amount>b.paid_amount AND b.status NOT IN ('Paid','Cancelled','Void','Reversed'))
FROM society_manager.t_bill b WHERE b.society_id=p_society_id AND b.flat_id=p_flat_id;
$function$;CREATE OR REPLACE FUNCTION society_manager.fn_collection_payment_history(p_society_id bigint,p_customer_id bigint,p_flat_id bigint)
RETURNS TABLE(payment_id bigint,payment_no character varying,payment_date timestamptz,amount numeric,payment_mode character varying,reference_no character varying,status character varying,receipt_no character varying,allocated_amount numeric)
LANGUAGE sql STABLE AS $function$
SELECT p.payment_id,p.payment_no,p.payment_date,p.amount,p.payment_mode,p.reference_no,p.status,r.receipt_no,COALESCE(sum(a.allocated_amount),0)::numeric(18,2) FROM society_manager.t_payment p LEFT JOIN society_manager.t_receipt r ON r.society_id=p.society_id AND r.payment_id=p.payment_id LEFT JOIN society_manager.t_payment_allocation a ON a.society_id=p.society_id AND a.payment_id=p.payment_id WHERE p.society_id=p_society_id AND p.customer_id=p_customer_id AND p.flat_id=p_flat_id GROUP BY p.payment_id,p.payment_no,p.payment_date,p.amount,p.payment_mode,p.reference_no,p.status,r.receipt_no ORDER BY p.payment_date DESC,p.payment_id DESC LIMIT 50;
$function$;
COMMIT;