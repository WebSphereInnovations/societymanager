-- Existing submenu CRUD hardening
DROP FUNCTION IF EXISTS society_manager.fn_society_management(bigint,varchar);
CREATE OR REPLACE FUNCTION society_manager.fn_society_management(p_society_id bigint,p_search varchar)
RETURNS TABLE(entity_type varchar,entity_id bigint,code varchar,name varchar,parent_name varchar,details text,is_active boolean)
LANGUAGE sql AS $$
SELECT x.entity_type,x.entity_id,x.code,x.name,x.parent_name,x.details,x.is_active
FROM (
 SELECT 'BUILDING' entity_type,building_id entity_id,building_code code,building_name name,NULL::varchar parent_name,floor_count::text details,is_active FROM society_manager.m_building WHERE society_id=p_society_id
 UNION ALL
 SELECT 'WING',w.wing_id,w.wing_code,w.wing_name,b.building_name,NULL,w.is_active FROM society_manager.m_wing w LEFT JOIN society_manager.m_building b ON b.building_id=w.building_id AND b.society_id=p_society_id WHERE w.society_id=p_society_id
 UNION ALL
 SELECT 'FLAT',f.flat_id,f.flat_no,f.flat_no,w.wing_name,concat('Area ',f.area_sqft,' / ',f.occupancy_status),f.is_active FROM society_manager.m_flat f LEFT JOIN society_manager.m_wing w ON w.wing_id=f.wing_id AND w.society_id=p_society_id WHERE f.society_id=p_society_id
 UNION ALL
 SELECT 'PARKING',parking_slot_id,slot_no,slot_no,slot_type,charge::text,is_active FROM society_manager.m_parking_slot WHERE society_id=p_society_id
 UNION ALL
 SELECT 'CUSTOMER',customer_id,customer_code,full_name,NULL::varchar,concat(phone,' / ',coalesce(email,'')),is_active FROM society_manager.m_customer WHERE society_id=p_society_id
) x
WHERE coalesce(p_search,'')='' OR x.entity_type ILIKE '%'||p_search||'%' OR x.code ILIKE '%'||p_search||'%' OR x.name ILIKE '%'||p_search||'%';
$$;

CREATE OR REPLACE FUNCTION society_manager.sp_set_building_active(p_society_id bigint,p_id bigint,p_active boolean,p_user bigint)
RETURNS bigint LANGUAGE plpgsql AS $$ DECLARE v bigint; BEGIN UPDATE society_manager.m_building SET is_active=p_active,modify_by=p_user,modify_date=now(),modify_remark=CASE WHEN p_active THEN 'Activated' ELSE 'Deactivated' END WHERE society_id=p_society_id AND building_id=p_id RETURNING building_id INTO v; IF v IS NULL THEN RAISE EXCEPTION 'Building not found'; END IF; RETURN v; END; $$;
CREATE OR REPLACE FUNCTION society_manager.sp_set_wing_active(p_society_id bigint,p_id bigint,p_active boolean,p_user bigint)
RETURNS bigint LANGUAGE plpgsql AS $$ DECLARE v bigint; BEGIN UPDATE society_manager.m_wing SET is_active=p_active,modify_by=p_user,modify_date=now(),modify_remark=CASE WHEN p_active THEN 'Activated' ELSE 'Deactivated' END WHERE society_id=p_society_id AND wing_id=p_id RETURNING wing_id INTO v; IF v IS NULL THEN RAISE EXCEPTION 'Wing not found'; END IF; RETURN v; END; $$;
CREATE OR REPLACE FUNCTION society_manager.sp_set_flat_active(p_society_id bigint,p_id bigint,p_active boolean,p_user bigint)
RETURNS bigint LANGUAGE plpgsql AS $$ DECLARE v bigint; BEGIN UPDATE society_manager.m_flat SET is_active=p_active,modify_by=p_user,modify_date=now(),modify_remark=CASE WHEN p_active THEN 'Activated' ELSE 'Deactivated' END WHERE society_id=p_society_id AND flat_id=p_id RETURNING flat_id INTO v; IF v IS NULL THEN RAISE EXCEPTION 'Flat not found'; END IF; RETURN v; END; $$;
CREATE OR REPLACE FUNCTION society_manager.sp_set_parking_active(p_society_id bigint,p_id bigint,p_active boolean,p_user bigint)
RETURNS bigint LANGUAGE plpgsql AS $$ DECLARE v bigint; BEGIN UPDATE society_manager.m_parking_slot SET is_active=p_active,modify_by=p_user,modify_date=now(),modify_remark=CASE WHEN p_active THEN 'Activated' ELSE 'Deactivated' END WHERE society_id=p_society_id AND parking_slot_id=p_id RETURNING parking_slot_id INTO v; IF v IS NULL THEN RAISE EXCEPTION 'Parking slot not found'; END IF; RETURN v; END; $$;
CREATE OR REPLACE FUNCTION society_manager.sp_set_customer_active(p_society_id bigint,p_id bigint,p_active boolean,p_user bigint)
RETURNS bigint LANGUAGE plpgsql AS $$ DECLARE v bigint; BEGIN UPDATE society_manager.m_customer SET is_active=p_active,modify_by=p_user,modify_date=now(),modify_remark=CASE WHEN p_active THEN 'Activated' ELSE 'Deactivated' END WHERE society_id=p_society_id AND customer_id=p_id RETURNING customer_id INTO v; IF v IS NULL THEN RAISE EXCEPTION 'Customer not found'; END IF; RETURN v; END; $$;
