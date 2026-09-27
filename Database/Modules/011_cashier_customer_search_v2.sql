SET search_path TO society_manager, public;
CREATE OR REPLACE FUNCTION fn_cashier_customer_search_v2(p_society_id bigint,p_search varchar)
RETURNS TABLE(customer_id bigint,customer_code varchar,full_name varchar,phone varchar,flat_id bigint,flat_no varchar,wing varchar,area_sqft numeric,outstanding numeric)
LANGUAGE sql AS $$
SELECT c.customer_id,c.customer_code,c.full_name,c.phone,f.flat_id,f.flat_no,coalesce(w.wing_name,w.wing_code,''),f.area_sqft,
coalesce((SELECT sum(b.total_amount-b.paid_amount) FROM t_bill b WHERE b.society_id=p_society_id AND b.flat_id=f.flat_id AND b.total_amount>b.paid_amount),0)
FROM m_customer c JOIN m_customer_flat cf ON cf.customer_id=c.customer_id AND cf.is_primary JOIN m_flat f ON f.flat_id=cf.flat_id LEFT JOIN m_wing w ON w.wing_id=f.wing_id
WHERE c.society_id=p_society_id AND c.is_active AND (trim(coalesce(p_search,''))='' OR c.full_name ILIKE trim(p_search)||'%' OR c.full_name ILIKE '%'||trim(p_search)||'%' OR f.flat_no ILIKE '%'||trim(p_search)||'%' OR c.phone ILIKE '%'||trim(p_search)||'%') ORDER BY c.full_name LIMIT 100;
$$;