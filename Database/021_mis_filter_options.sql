-- DB-driven MIS filter options
CREATE OR REPLACE FUNCTION society_manager.fn_mis_filter_options(p_society_id bigint)
RETURNS TABLE(option_group varchar,option_code varchar,option_name varchar,sort_order integer)
LANGUAGE sql AS $$
SELECT 'WING'::varchar AS option_group,w.wing_id::varchar AS option_code,w.wing_name AS option_name,w.wing_id::integer AS sort_order
FROM society_manager.m_wing w
WHERE w.society_id=p_society_id AND w.is_active
UNION ALL
SELECT 'MONTH',to_char(x.bill_month,'YYYY-MM-DD'),to_char(x.bill_month,'Mon YYYY'),row_number() OVER(ORDER BY x.bill_month DESC)::integer
FROM (SELECT DISTINCT bill_month FROM society_manager.t_bill WHERE society_id=p_society_id) x
UNION ALL
SELECT 'COLLECTION_STATUS',x.status,x.status,100+row_number() OVER(ORDER BY x.status)::integer
FROM (SELECT DISTINCT status FROM society_manager.t_payment WHERE society_id=p_society_id AND status IS NOT NULL) x
UNION ALL
SELECT 'COMPLAINT_STATUS',x.status,x.status,200+row_number() OVER(ORDER BY x.status)::integer
FROM (SELECT DISTINCT status FROM society_manager.t_complaint WHERE society_id=p_society_id AND status IS NOT NULL) x
ORDER BY option_group,sort_order,option_name;
$$;
