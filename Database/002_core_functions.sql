SET search_path TO society_manager, public;

CREATE OR REPLACE FUNCTION fn_flat_list(p_society_id bigint)
RETURNS TABLE(flat_id bigint,flat_no varchar,wing_name varchar,building_name varchar,area_sqft numeric,occupancy_status varchar,primary_owner varchar)
LANGUAGE sql AS $$
SELECT f.flat_id,f.flat_no,w.wing_name,b.building_name,f.area_sqft,f.occupancy_status,
       COALESCE((SELECT c.full_name FROM m_customer_flat cf JOIN m_customer c ON c.customer_id=cf.customer_id
                 WHERE cf.flat_id=f.flat_id AND cf.society_id=p_society_id AND cf.is_primary
                 ORDER BY cf.customer_flat_id LIMIT 1),'')
FROM m_flat f
LEFT JOIN m_wing w ON w.wing_id=f.wing_id
LEFT JOIN m_building b ON b.building_id=f.building_id
WHERE f.society_id=p_society_id AND f.is_active
ORDER BY f.flat_no;
$$;

CREATE OR REPLACE FUNCTION fn_bill_list(p_society_id bigint,p_month date DEFAULT NULL)
RETURNS TABLE(bill_id bigint,bill_no varchar,flat_no varchar,owner_name varchar,bill_month date,due_date date,total_amount numeric,paid_amount numeric,balance numeric,status varchar)
LANGUAGE sql AS $$
SELECT b.bill_id,b.bill_no,f.flat_no,
       COALESCE((SELECT c.full_name FROM m_customer_flat cf JOIN m_customer c ON c.customer_id=cf.customer_id
                 WHERE cf.flat_id=f.flat_id AND cf.society_id=p_society_id AND cf.is_primary
                 ORDER BY cf.customer_flat_id LIMIT 1),''),
       b.bill_month,b.due_date,b.total_amount,b.paid_amount,
       b.total_amount-b.paid_amount,b.status
FROM t_bill b JOIN m_flat f ON f.flat_id=b.flat_id
WHERE b.society_id=p_society_id AND (p_month IS NULL OR b.bill_month=date_trunc('month',p_month)::date)
ORDER BY b.bill_date DESC,b.bill_id DESC;
$$;

CREATE OR REPLACE FUNCTION fn_collection_summary(p_society_id bigint,p_from date,p_to date)
RETURNS TABLE(payment_count bigint,total_collection numeric)
LANGUAGE sql AS $$
SELECT count(*),COALESCE(sum(amount),0)
FROM t_payment
WHERE society_id=p_society_id AND payment_date>=p_from AND payment_date<p_to + interval '1 day' AND status='Success';
$$;

CREATE OR REPLACE FUNCTION fn_create_migration_batch(p_society_id bigint,p_batch_no varchar,p_file varchar,p_user_id bigint)
RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE v_id bigint;
BEGIN
 INSERT INTO t_migration_batch(society_id,batch_no,source_file_name,created_by)
 VALUES(p_society_id,p_batch_no,p_file,p_user_id)
 RETURNING migration_batch_id INTO v_id;
 RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION fn_log_audit(p_society_id bigint,p_user_id bigint,p_entity varchar,p_entity_id bigint,p_action varchar,p_old jsonb,p_new jsonb)
RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE v_id bigint;
BEGIN
 INSERT INTO t_audit_log(society_id,user_id,entity_name,entity_id,action,old_data,new_data)
 VALUES(p_society_id,p_user_id,p_entity,p_entity_id,p_action,p_old,p_new)
 RETURNING audit_log_id INTO v_id;
 RETURN v_id;
END;
$$;