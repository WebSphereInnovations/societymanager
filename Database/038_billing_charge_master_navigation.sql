SET search_path TO society_manager, public;

-- Billing navigation cleanup: retire the obsolete Billing Management parent without deleting history.
UPDATE m_module
SET visible=false,is_active=false
WHERE module_code='BILLING_MANAGEMENT';

-- Bind Billing rates to the existing society-scoped charge master.
ALTER TABLE m_billing_rate
  ADD COLUMN IF NOT EXISTS charge_type_id bigint;

-- Backfill existing billing rates from the existing charge master.
UPDATE m_billing_rate r
SET charge_type_id=ct.charge_type_id
FROM m_charge_type ct
WHERE r.charge_type_id IS NULL
  AND ct.society_id=r.society_id
  AND ct.is_active
  AND lower(ct.charge_code)=lower(
    CASE r.charge_code
      WHEN 'MAINTENANCE' THEN 'MAINT'
      WHEN 'SINKING_FUND' THEN 'SINK'
      WHEN 'PARKING' THEN 'PARK'
      WHEN 'OTHER_CHARGES' THEN 'REPAIR'
      ELSE r.charge_code
    END
  );

CREATE UNIQUE INDEX IF NOT EXISTS ux_m_charge_type_society_id
  ON m_charge_type(society_id,charge_type_id);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname='fk_m_billing_rate_charge_type'
      AND conrelid='m_billing_rate'::regclass
  ) THEN
    ALTER TABLE m_billing_rate
      ADD CONSTRAINT fk_m_billing_rate_charge_type
      FOREIGN KEY(society_id,charge_type_id)
      REFERENCES m_charge_type(society_id,charge_type_id);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS ix_m_billing_rate_charge_type
  ON m_billing_rate(society_id,charge_type_id,effective_from);

CREATE OR REPLACE FUNCTION fn_billing_charge_types(p_society_id bigint)
RETURNS TABLE(charge_type_id bigint,charge_code varchar,charge_name varchar)
LANGUAGE sql STABLE AS $$
SELECT c.charge_type_id,c.charge_code,c.charge_name
FROM m_charge_type c
WHERE c.society_id=p_society_id AND c.is_active
ORDER BY c.charge_name,c.charge_type_id;
$$;

CREATE OR REPLACE FUNCTION sp_billing_save_rate(
 p_society_id bigint,p_rate_id bigint,p_property_type_id bigint,p_charge_type_id bigint,
 p_rate_type varchar,p_rate numeric,p_effective_from date,p_effective_to date,p_user_id bigint,p_remark text
) RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint; v_code varchar; v_name varchar;
BEGIN
 IF p_rate_type NOT IN('PER_FLAT','PER_SQFT','PER_PARKING','FIXED') THEN RAISE EXCEPTION 'Invalid rate type'; END IF;
 IF p_rate<0 THEN RAISE EXCEPTION 'Rate cannot be negative'; END IF;

 SELECT c.charge_code,c.charge_name INTO v_code,v_name
 FROM m_charge_type c
 WHERE c.society_id=p_society_id AND c.charge_type_id=p_charge_type_id AND c.is_active;
 IF v_code IS NULL THEN RAISE EXCEPTION 'Charge type is not configured for this society'; END IF;

 IF NOT EXISTS(
   SELECT 1 FROM m_billing_property_type
   WHERE society_id=p_society_id AND billing_property_type_id=p_property_type_id AND is_active AND visible
 ) THEN RAISE EXCEPTION 'Property type is not configured for this society'; END IF;

 IF p_rate_id>0 THEN
   UPDATE m_billing_rate
   SET billing_property_type_id=p_property_type_id,charge_type_id=p_charge_type_id,
       charge_code=CASE v_code WHEN 'MAINT' THEN 'MAINTENANCE' WHEN 'SINK' THEN 'SINKING_FUND'
                               WHEN 'PARK' THEN 'PARKING' WHEN 'REPAIR' THEN 'OTHER_CHARGES' ELSE v_code END,
       charge_name=v_name,rate_type=p_rate_type,rate=p_rate,
       effective_from=p_effective_from,effective_to=p_effective_to,
       modify_by=p_user_id,modify_date=now(),modify_remark=coalesce(p_remark,'')
   WHERE billing_rate_id=p_rate_id AND society_id=p_society_id
   RETURNING billing_rate_id INTO v_id;
 ELSE
   INSERT INTO m_billing_rate(
     society_id,billing_property_type_id,charge_type_id,charge_code,charge_name,
     rate_type,rate,effective_from,effective_to,modify_by,modify_date,modify_remark
   )
   VALUES(
     p_society_id,p_property_type_id,p_charge_type_id,
     CASE v_code WHEN 'MAINT' THEN 'MAINTENANCE' WHEN 'SINK' THEN 'SINKING_FUND'
                 WHEN 'PARK' THEN 'PARKING' WHEN 'REPAIR' THEN 'OTHER_CHARGES' ELSE v_code END,
     v_name,p_rate_type,p_rate,p_effective_from,p_effective_to,p_user_id,now(),coalesce(p_remark,'')
   )
   RETURNING billing_rate_id INTO v_id;
 END IF;

 IF v_id IS NULL THEN RAISE EXCEPTION 'Billing rate not found in selected society'; END IF;
 RETURN v_id;
END $$;
