-- Separate bill-period and payment-period choices while retaining the combined MONTH group.
-- This keeps the Billing Data and Collection Details reports on their own date semantics.
CREATE OR REPLACE FUNCTION society_manager.fn_mis_filter_options(p_society_id bigint)
RETURNS TABLE(option_group varchar,option_code varchar,option_name varchar,sort_order integer)
LANGUAGE sql AS $$
SELECT 'WING'::varchar AS option_group,w.wing_id::varchar AS option_code,w.wing_name AS option_name,w.wing_id::integer AS sort_order
FROM society_manager.m_wing w
WHERE w.society_id=p_society_id AND w.is_active

UNION ALL

SELECT 'BILL_MONTH'::varchar,
       to_char(x.month_start,'YYYY-MM-DD')::varchar,
       to_char(x.month_start,'Mon YYYY')::varchar,
       row_number() OVER(ORDER BY x.month_start DESC)::integer
FROM (
    SELECT DISTINCT date_trunc('month',b.bill_month)::date AS month_start
    FROM society_manager.t_bill b
    WHERE b.society_id=p_society_id
) x

UNION ALL

SELECT 'PAYMENT_MONTH'::varchar,
       to_char(x.month_start,'YYYY-MM-DD')::varchar,
       to_char(x.month_start,'Mon YYYY')::varchar,
       row_number() OVER(ORDER BY x.month_start DESC)::integer
FROM (
    SELECT DISTINCT date_trunc('month',p.payment_date)::date AS month_start
    FROM society_manager.t_payment p
    WHERE p.society_id=p_society_id AND p.payment_date IS NOT NULL
) x

UNION ALL

SELECT 'MONTH'::varchar,
       to_char(x.month_start,'YYYY-MM-DD')::varchar,
       to_char(x.month_start,'Mon YYYY')::varchar,
       row_number() OVER(ORDER BY x.month_start DESC)::integer
FROM (
    SELECT date_trunc('month',b.bill_month)::date AS month_start
    FROM society_manager.t_bill b
    WHERE b.society_id=p_society_id
    UNION
    SELECT date_trunc('month',p.payment_date)::date AS month_start
    FROM society_manager.t_payment p
    WHERE p.society_id=p_society_id AND p.payment_date IS NOT NULL
) x

UNION ALL

SELECT 'COLLECTION_STATUS'::varchar,x.status::varchar,x.status::varchar,
       100+row_number() OVER(ORDER BY x.status)::integer
FROM (
    SELECT DISTINCT p.status FROM society_manager.t_payment p
    WHERE p.society_id=p_society_id AND p.status IS NOT NULL
) x

UNION ALL

SELECT 'COMPLAINT_STATUS'::varchar,x.status::varchar,x.status::varchar,
       200+row_number() OVER(ORDER BY x.status)::integer
FROM (
    SELECT DISTINCT c.status FROM society_manager.t_complaint c
    WHERE c.society_id=p_society_id AND c.status IS NOT NULL
) x

ORDER BY option_group,sort_order,option_name;
$$;
