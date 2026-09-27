SET search_path TO society_manager, public;
CREATE OR REPLACE FUNCTION fn_customer_flats(p_user_id bigint)
RETURNS TABLE(flat_id bigint,flat_no varchar,wing varchar,building varchar,area_sqft numeric,occupancy_status varchar,relation_type varchar,is_primary boolean,start_date date,end_date date)
LANGUAGE sql AS $$
SELECT f.flat_id,f.flat_no,coalesce(w.wing_name,w.wing_code,''),coalesce(b.building_name,b.building_code,''),f.area_sqft,f.occupancy_status,cf.relation_type,cf.is_primary,cf.start_date,cf.end_date
FROM m_user u JOIN m_customer_flat cf ON cf.customer_id=u.customer_id AND cf.society_id=u.society_id
JOIN m_flat f ON f.flat_id=cf.flat_id AND f.society_id=u.society_id
LEFT JOIN m_wing w ON w.wing_id=f.wing_id LEFT JOIN m_building b ON b.building_id=f.building_id
WHERE u.user_id=p_user_id AND u.role_code='RESIDENT' AND u.is_active ORDER BY cf.is_primary DESC,f.flat_no;
$$;