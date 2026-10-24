-- Additive receipt-detail read model. Preserves existing fn_payment_receipt contract.
-- Breakdown is based only on the actual bill allocations linked to the saved payment.
BEGIN;
CREATE OR REPLACE FUNCTION society_manager.fn_payment_receipt_details(p_society_id bigint,p_payment_id bigint)
RETURNS TABLE(
 receipt_no varchar,payment_no varchar,receipt_date timestamptz,payment_date timestamptz,amount numeric,
 payment_mode varchar,reference_no varchar,payment_status varchar,society_name varchar,society_logo text,
 society_address text,society_phone varchar,society_email varchar,customer_name varchar,customer_code varchar,
 consumer_no text,flat_no varchar,wing_name varchar,charge_breakdown jsonb,bill_allocations jsonb
)
LANGUAGE sql STABLE AS $function$
WITH payment_context AS (
 SELECT r.receipt_no,p.payment_no,r.receipt_date,p.payment_date,r.amount,p.payment_mode,p.reference_no,p.status AS payment_status,
        s.society_name,sb.logo_url AS society_logo,s.address AS society_address,s.phone AS society_phone,s.email AS society_email,
        c.full_name AS customer_name,c.customer_code,c.consumer_id::text AS consumer_no,f.flat_no,w.wing_name,
        p.society_id,p.payment_id
 FROM society_manager.t_receipt r
 JOIN society_manager.t_payment p ON p.society_id=r.society_id AND p.payment_id=r.payment_id
 JOIN society_manager.m_society s ON s.society_id=p.society_id
 LEFT JOIN society_manager.m_society_branding sb ON sb.society_id=s.society_id
 LEFT JOIN society_manager.m_customer c ON c.society_id=p.society_id AND c.customer_id=p.customer_id
 LEFT JOIN society_manager.m_flat f ON f.society_id=p.society_id AND f.flat_id=p.flat_id
 LEFT JOIN society_manager.m_wing w ON w.society_id=f.society_id AND w.wing_id=f.wing_id
 WHERE r.society_id=p_society_id AND r.payment_id=p_payment_id AND p.society_id=p_society_id
), allocations AS (
 SELECT a.allocated_amount,b.bill_id,b.bill_no,b.bill_month,b.total_amount,
        COALESCE(b.maintenance_amount,0)::numeric AS maintenance_amount,
        COALESCE(b.parking_amount,0)::numeric AS parking_amount,
        COALESCE(b.sinking_fund_amount,0)::numeric AS sinking_fund_amount,
        COALESCE(b.arrear_amount,0)::numeric AS arrear_amount,
        COALESCE(b.dpc_amount,0)::numeric AS dpc_amount,
        COALESCE(b.interest_arrear_amount,0)::numeric AS interest_arrear_amount,
        COALESCE(b.other_charge_amount,0)::numeric AS other_charge_amount,
        COALESCE(b.tax_amount,0)::numeric AS tax_amount,
        COALESCE(b.rebate_amount,0)::numeric AS rebate_amount
 FROM society_manager.t_payment_allocation a
 JOIN society_manager.t_bill b ON b.society_id=a.society_id AND b.bill_id=a.bill_id
 WHERE a.society_id=p_society_id AND a.payment_id=p_payment_id
), raw AS (
 SELECT a.*,
   (maintenance_amount+parking_amount+sinking_fund_amount+arrear_amount+dpc_amount+interest_arrear_amount+other_charge_amount+tax_amount-rebate_amount) AS net_components
 FROM allocations a
), scaled AS (
 SELECT r.*,
   CASE WHEN net_components>allocated_amount AND net_components>0 THEN allocated_amount/net_components ELSE 1::numeric END AS factor
 FROM raw r
), component_rows AS (
 SELECT 'Maintenance'::text AS label,round(sum(maintenance_amount*factor),2) AS amount FROM scaled
 UNION ALL SELECT 'Parking',round(sum(parking_amount*factor),2) FROM scaled
 UNION ALL SELECT 'Sinking Fund',round(sum(sinking_fund_amount*factor),2) FROM scaled
 UNION ALL SELECT 'Arrears',round(sum(arrear_amount*factor),2) FROM scaled
 UNION ALL SELECT 'DPC',round(sum(dpc_amount*factor),2) FROM scaled
 UNION ALL SELECT 'Interest on Arrears',round(sum(interest_arrear_amount*factor),2) FROM scaled
 UNION ALL SELECT 'Other Charges',round(sum(other_charge_amount*factor),2) FROM scaled
 UNION ALL SELECT 'Tax',round(sum(tax_amount*factor),2) FROM scaled
 UNION ALL SELECT 'Rebate',-round(sum(rebate_amount*factor),2) FROM scaled
 UNION ALL SELECT 'Current Dues / Unclassified',round(sum(allocated_amount)-sum((maintenance_amount+parking_amount+sinking_fund_amount+arrear_amount+dpc_amount+interest_arrear_amount+other_charge_amount+tax_amount-rebate_amount)*factor),2) FROM scaled
), nonzero_components AS (
 SELECT label,amount FROM component_rows WHERE COALESCE(amount,0)<>0
), breakdown AS (
 SELECT COALESCE(jsonb_agg(jsonb_build_object('label',label,'amount',amount) ORDER BY CASE label
   WHEN 'Current Dues / Unclassified' THEN 1 WHEN 'Maintenance' THEN 2 WHEN 'Parking' THEN 3 WHEN 'Sinking Fund' THEN 4
   WHEN 'Arrears' THEN 5 WHEN 'DPC' THEN 6 WHEN 'Interest on Arrears' THEN 7 WHEN 'Other Charges' THEN 8 WHEN 'Tax' THEN 9 WHEN 'Rebate' THEN 10 ELSE 99 END),'[]'::jsonb) AS data
 FROM nonzero_components
), bill_rows AS (
 SELECT COALESCE(jsonb_agg(jsonb_build_object('bill_no',bill_no,'bill_month',to_char(bill_month,'YYYY-MM'),'allocated_amount',allocated_amount) ORDER BY bill_month,bill_no),'[]'::jsonb) AS data
 FROM allocations
)
SELECT pc.receipt_no,pc.payment_no,pc.receipt_date,pc.payment_date,pc.amount,pc.payment_mode,pc.reference_no,pc.payment_status,
 pc.society_name,pc.society_logo,pc.society_address,pc.society_phone,pc.society_email,pc.customer_name,pc.customer_code,pc.consumer_no,
 pc.flat_no,pc.wing_name,breakdown.data,bill_rows.data
FROM payment_context pc CROSS JOIN breakdown CROSS JOIN bill_rows;
$function$;
COMMIT;
