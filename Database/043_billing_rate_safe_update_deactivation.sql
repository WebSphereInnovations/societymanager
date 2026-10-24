SET search_path TO society_manager, public;

-- Keep existing rate remarks unless the editor explicitly supplies a non-empty replacement.
-- Add server-side date validation and tenant-scoped safe rate deactivation.
CREATE OR REPLACE FUNCTION sp_billing_save_rate(
 p_society_id bigint,p_rate_id bigint,p_property_type_id bigint,p_charge_type_id bigint,
 p_rate_type varchar,p_rate numeric,p_effective_from date,p_effective_to date,p_user_id bigint,p_remark text
) RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint; v_code varchar; v_name varchar;
BEGIN
 IF p_rate_type NOT IN('PER_FLAT','PER_SQFT','PER_PARKING','FIXED') THEN RAISE EXCEPTION 'Invalid rate type'; END IF;
 IF p_rate<0 THEN RAISE EXCEPTION 'Rate cannot be negative'; END IF;
 IF p_effective_to IS NOT NULL AND p_effective_to<p_effective_from THEN RAISE EXCEPTION 'Effective To must be on or after Effective From'; END IF;
 SELECT c.charge_code,c.charge_name INTO v_code,v_name
 FROM m_charge_type c
 WHERE c.society_id=p_society_id AND c.charge_type_id=p_charge_type_id AND c.is_active;
 IF v_code IS NULL THEN RAISE EXCEPTION 'Charge type is not configured for this society'; END IF;
 IF NOT EXISTS(SELECT 1 FROM m_billing_property_type WHERE society_id=p_society_id AND billing_property_type_id=p_property_type_id AND is_active AND visible)
 THEN RAISE EXCEPTION 'Property type is not configured for this society'; END IF;
 IF p_rate_id>0 THEN
   UPDATE m_billing_rate
   SET billing_property_type_id=p_property_type_id,charge_type_id=p_charge_type_id,
       charge_code=CASE v_code WHEN 'MAINT' THEN 'MAINTENANCE' WHEN 'SINK' THEN 'SINKING_FUND' WHEN 'PARK' THEN 'PARKING' WHEN 'REPAIR' THEN 'OTHER_CHARGES' ELSE v_code END,
       charge_name=v_name,rate_type=p_rate_type,rate=p_rate,effective_from=p_effective_from,effective_to=p_effective_to,
       modify_by=p_user_id,modify_date=now(),modify_remark=CASE WHEN NULLIF(BTRIM(p_remark),'') IS NULL THEN modify_remark ELSE p_remark END
   WHERE billing_rate_id=p_rate_id AND society_id=p_society_id
   RETURNING billing_rate_id INTO v_id;
 ELSE
   INSERT INTO m_billing_rate(society_id,billing_property_type_id,charge_type_id,charge_code,charge_name,rate_type,rate,effective_from,effective_to,modify_by,modify_date,modify_remark)
   VALUES(p_society_id,p_property_type_id,p_charge_type_id,
       CASE v_code WHEN 'MAINT' THEN 'MAINTENANCE' WHEN 'SINK' THEN 'SINKING_FUND' WHEN 'PARK' THEN 'PARKING' WHEN 'REPAIR' THEN 'OTHER_CHARGES' ELSE v_code END,
       v_name,p_rate_type,p_rate,p_effective_from,p_effective_to,p_user_id,now(),COALESCE(NULLIF(BTRIM(p_remark),''),''))
   RETURNING billing_rate_id INTO v_id;
 END IF;
 IF v_id IS NULL THEN RAISE EXCEPTION 'Billing rate not found in selected society'; END IF;
 RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION sp_billing_set_rate_active(
 p_society_id bigint,p_rate_id bigint,p_active boolean,p_user_id bigint,p_remark text
) RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint;
BEGIN
 IF p_rate_id<=0 THEN RAISE EXCEPTION 'Billing rate not found in selected society'; END IF;
 UPDATE m_billing_rate
 SET is_active=p_active,modify_by=p_user_id,modify_date=now(),
     modify_remark=CASE WHEN NULLIF(BTRIM(p_remark),'') IS NULL THEN modify_remark ELSE p_remark END
 WHERE society_id=p_society_id AND billing_rate_id=p_rate_id
 RETURNING billing_rate_id INTO v_id;
 IF v_id IS NULL THEN RAISE EXCEPTION 'Billing rate not found in selected society'; END IF;
 RETURN v_id;
END $$;