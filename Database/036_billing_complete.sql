SET search_path TO society_manager, public;

-- Society-scoped Billing architecture. Safe to re-run.
CREATE TABLE IF NOT EXISTS m_billing_config(
 billing_config_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 billing_frequency_months integer NOT NULL DEFAULT 1 CHECK(billing_frequency_months BETWEEN 1 AND 12),
 dpc_applicable boolean NOT NULL DEFAULT false,
 dpc_apply_on varchar(40) NOT NULL DEFAULT 'ARREAR',
 dpc_rate numeric(18,6) NOT NULL DEFAULT 0,
 dpc_calculation_type varchar(30) NOT NULL DEFAULT 'Percentage',
 effective_from date NOT NULL DEFAULT current_date,
 effective_to date,
 is_active boolean NOT NULL DEFAULT true,
 modify_by bigint REFERENCES m_user(user_id),
 modify_date timestamptz NOT NULL DEFAULT now(),
 modify_remark text DEFAULT '',
 UNIQUE(society_id,effective_from)
);

CREATE TABLE IF NOT EXISTS t_billing_config_history(
 billing_config_history_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 billing_config_id bigint REFERENCES m_billing_config(billing_config_id),
 old_frequency_months integer,
 new_frequency_months integer,
 old_dpc_applicable boolean,
 new_dpc_applicable boolean,
 old_dpc_apply_on varchar(40),
 new_dpc_apply_on varchar(40),
 old_dpc_rate numeric(18,6),
 new_dpc_rate numeric(18,6),
 effective_from date NOT NULL,
 effective_to date,
 active boolean NOT NULL DEFAULT true,
 modify_by bigint REFERENCES m_user(user_id),
 modify_date timestamptz NOT NULL DEFAULT now(),
 modify_remark text DEFAULT ''
);

CREATE TABLE IF NOT EXISTS m_billing_property_type(
 billing_property_type_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 property_type_code varchar(50) NOT NULL,
 property_type_name varchar(120) NOT NULL,
 is_active boolean NOT NULL DEFAULT true,
 visible boolean NOT NULL DEFAULT true,
 modify_by bigint REFERENCES m_user(user_id),
 modify_date timestamptz NOT NULL DEFAULT now(),
 modify_remark text DEFAULT '',
 UNIQUE(society_id,property_type_code)
);

CREATE TABLE IF NOT EXISTS m_billing_rate(
 billing_rate_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 billing_property_type_id bigint REFERENCES m_billing_property_type(billing_property_type_id),
 charge_code varchar(50) NOT NULL,
 charge_name varchar(150) NOT NULL,
 rate_type varchar(30) NOT NULL CHECK(rate_type IN('PER_FLAT','PER_SQFT','PER_PARKING','FIXED')),
 rate numeric(18,6) NOT NULL DEFAULT 0 CHECK(rate>=0),
 effective_from date NOT NULL,
 effective_to date,
 is_active boolean NOT NULL DEFAULT true,
 visible boolean NOT NULL DEFAULT true,
 modify_by bigint REFERENCES m_user(user_id),
 modify_date timestamptz NOT NULL DEFAULT now(),
 modify_remark text DEFAULT ''
);

CREATE TABLE IF NOT EXISTS m_billing_arrear(
 billing_arrear_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 consumer_id bigint NOT NULL,
 customer_id bigint NOT NULL REFERENCES m_customer(customer_id),
 flat_id bigint REFERENCES m_flat(flat_id),
 bill_month char(6) NOT NULL CHECK(bill_month ~ '^[0-9]{6}$'),
 raw_arrear numeric(18,2) NOT NULL DEFAULT 0,
 calculated_arrear numeric(18,2) NOT NULL DEFAULT 0,
 raw_interest numeric(18,2) NOT NULL DEFAULT 0,
 calculated_interest numeric(18,2) NOT NULL DEFAULT 0,
 adjustment numeric(18,2) NOT NULL DEFAULT 0,
 status varchar(30) NOT NULL DEFAULT 'OPEN',
 is_active boolean NOT NULL DEFAULT true,
 modify_by bigint REFERENCES m_user(user_id),
 modify_date timestamptz NOT NULL DEFAULT now(),
 modify_remark text DEFAULT '',
 CONSTRAINT fk_billing_arrear_consumer FOREIGN KEY(society_id,consumer_id) REFERENCES m_customer(society_id,consumer_id),
 UNIQUE(society_id,consumer_id,bill_month)
);

ALTER TABLE t_payment ADD COLUMN IF NOT EXISTS processed_billing_month char(6);
ALTER TABLE t_payment ADD COLUMN IF NOT EXISTS processed_date timestamptz;
ALTER TABLE t_payment ADD COLUMN IF NOT EXISTS modify_by bigint REFERENCES m_user(user_id);
ALTER TABLE t_payment ADD COLUMN IF NOT EXISTS modify_date timestamptz NOT NULL DEFAULT now();
ALTER TABLE t_payment ADD COLUMN IF NOT EXISTS modify_remark text DEFAULT '';

ALTER TABLE t_bill ADD COLUMN IF NOT EXISTS maintenance_amount numeric(18,2) NOT NULL DEFAULT 0;
ALTER TABLE t_bill ADD COLUMN IF NOT EXISTS sinking_fund_amount numeric(18,2) NOT NULL DEFAULT 0;
ALTER TABLE t_bill ADD COLUMN IF NOT EXISTS parking_amount numeric(18,2) NOT NULL DEFAULT 0;
ALTER TABLE t_bill ADD COLUMN IF NOT EXISTS other_charge_amount numeric(18,2) NOT NULL DEFAULT 0;
ALTER TABLE t_bill ADD COLUMN IF NOT EXISTS arrear_amount numeric(18,2) NOT NULL DEFAULT 0;
ALTER TABLE t_bill ADD COLUMN IF NOT EXISTS interest_arrear_amount numeric(18,2) NOT NULL DEFAULT 0;
ALTER TABLE t_bill ADD COLUMN IF NOT EXISTS outstanding_amount numeric(18,2) NOT NULL DEFAULT 0;
ALTER TABLE t_bill ADD COLUMN IF NOT EXISTS modify_by bigint REFERENCES m_user(user_id);
ALTER TABLE t_bill ADD COLUMN IF NOT EXISTS modify_date timestamptz NOT NULL DEFAULT now();
ALTER TABLE t_bill ADD COLUMN IF NOT EXISTS modify_remark text DEFAULT '';

CREATE TABLE IF NOT EXISTS t_billing_run(
 billing_run_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 billing_month char(6) NOT NULL,
 run_status varchar(30) NOT NULL DEFAULT 'PREPARED',
 prepared_at timestamptz NOT NULL DEFAULT now(),
 prepared_by bigint REFERENCES m_user(user_id),
 finalized_at timestamptz,
 finalized_by bigint REFERENCES m_user(user_id),
 is_active boolean NOT NULL DEFAULT true,
 modify_by bigint REFERENCES m_user(user_id),
 modify_date timestamptz NOT NULL DEFAULT now(),
 modify_remark text DEFAULT '',
 UNIQUE(society_id,billing_month)
);

CREATE TABLE IF NOT EXISTS t_billing_run_detail(
 billing_run_detail_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 billing_run_id bigint NOT NULL REFERENCES t_billing_run(billing_run_id) ON DELETE CASCADE,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 consumer_id bigint NOT NULL,
 customer_id bigint NOT NULL REFERENCES m_customer(customer_id),
 flat_id bigint REFERENCES m_flat(flat_id),
 billing_month char(6) NOT NULL,
 maintenance_amount numeric(18,2) NOT NULL DEFAULT 0,
 sinking_fund_amount numeric(18,2) NOT NULL DEFAULT 0,
 parking_amount numeric(18,2) NOT NULL DEFAULT 0,
 other_charge_amount numeric(18,2) NOT NULL DEFAULT 0,
 arrear_amount numeric(18,2) NOT NULL DEFAULT 0,
 interest_arrear_amount numeric(18,2) NOT NULL DEFAULT 0,
 total_amount numeric(18,2) NOT NULL DEFAULT 0,
 payment_amount numeric(18,2) NOT NULL DEFAULT 0,
 balance_amount numeric(18,2) NOT NULL DEFAULT 0,
 status varchar(30) NOT NULL DEFAULT 'PREVIEW',
 is_active boolean NOT NULL DEFAULT true,
 modify_by bigint REFERENCES m_user(user_id),
 modify_date timestamptz NOT NULL DEFAULT now(),
 modify_remark text DEFAULT '',
 UNIQUE(billing_run_id,consumer_id)
);

CREATE TABLE IF NOT EXISTS t_billing_payment_adjustment(
 billing_payment_adjustment_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 billing_run_id bigint NOT NULL REFERENCES t_billing_run(billing_run_id) ON DELETE CASCADE,
 payment_id bigint NOT NULL REFERENCES t_payment(payment_id),
 consumer_id bigint NOT NULL,
 billing_month char(6) NOT NULL,
 interest_adjusted numeric(18,2) NOT NULL DEFAULT 0,
 arrear_adjusted numeric(18,2) NOT NULL DEFAULT 0,
 adjustment_total numeric(18,2) NOT NULL DEFAULT 0,
 is_active boolean NOT NULL DEFAULT true,
 modify_by bigint REFERENCES m_user(user_id),
 modify_date timestamptz NOT NULL DEFAULT now(),
 modify_remark text DEFAULT '',
 UNIQUE(billing_run_id,payment_id)
);

-- Compatibility with the existing billing configuration table already present in this project.
ALTER TABLE m_billing_config ADD COLUMN IF NOT EXISTS billing_frequency_months integer;
ALTER TABLE m_billing_config ADD COLUMN IF NOT EXISTS dpc_applicable boolean;
ALTER TABLE m_billing_config ADD COLUMN IF NOT EXISTS dpc_apply_on varchar(40);
ALTER TABLE m_billing_config ADD COLUMN IF NOT EXISTS dpc_rate numeric(18,6);
ALTER TABLE m_billing_config ADD COLUMN IF NOT EXISTS dpc_calculation_type varchar(30);
ALTER TABLE m_billing_config ADD COLUMN IF NOT EXISTS effective_from date;
ALTER TABLE m_billing_config ADD COLUMN IF NOT EXISTS effective_to date;
UPDATE m_billing_config SET billing_frequency_months=coalesce(billing_frequency_months,1),
 dpc_applicable=coalesce(dpc_applicable,auto_dpc,false),dpc_apply_on=coalesce(dpc_apply_on,'ARREAR'),
 dpc_rate=coalesce(dpc_rate,0),dpc_calculation_type=coalesce(dpc_calculation_type,'Percentage'),
 effective_from=coalesce(effective_from,current_date)
WHERE billing_frequency_months IS NULL OR dpc_applicable IS NULL OR dpc_apply_on IS NULL OR dpc_rate IS NULL
   OR dpc_calculation_type IS NULL OR effective_from IS NULL;
ALTER TABLE m_billing_config ALTER COLUMN billing_frequency_months SET DEFAULT 1;
ALTER TABLE m_billing_config ALTER COLUMN billing_frequency_months SET NOT NULL;
ALTER TABLE m_billing_config ALTER COLUMN dpc_applicable SET DEFAULT false;
ALTER TABLE m_billing_config ALTER COLUMN dpc_applicable SET NOT NULL;
ALTER TABLE m_billing_config ALTER COLUMN dpc_apply_on SET DEFAULT 'ARREAR';
ALTER TABLE m_billing_config ALTER COLUMN dpc_apply_on SET NOT NULL;
ALTER TABLE m_billing_config ALTER COLUMN dpc_rate SET DEFAULT 0;
ALTER TABLE m_billing_config ALTER COLUMN dpc_rate SET NOT NULL;
ALTER TABLE m_billing_config ALTER COLUMN dpc_calculation_type SET DEFAULT 'Percentage';
ALTER TABLE m_billing_config ALTER COLUMN dpc_calculation_type SET NOT NULL;
ALTER TABLE m_billing_config ALTER COLUMN effective_from SET DEFAULT current_date;
ALTER TABLE m_billing_config ALTER COLUMN effective_from SET NOT NULL;

CREATE INDEX IF NOT EXISTS ix_m_billing_config_society ON m_billing_config(society_id,is_active,effective_from);
CREATE INDEX IF NOT EXISTS ix_t_billing_config_history_society ON t_billing_config_history(society_id,modify_date DESC);
CREATE INDEX IF NOT EXISTS ix_m_billing_rate_lookup ON m_billing_rate(society_id,billing_property_type_id,charge_code,effective_from,effective_to);
CREATE INDEX IF NOT EXISTS ix_m_billing_arrear_lookup ON m_billing_arrear(society_id,consumer_id,bill_month,calculated_interest,calculated_arrear);
CREATE INDEX IF NOT EXISTS ix_t_payment_unprocessed ON t_payment(society_id,processed_billing_month,processed_date,payment_date);
CREATE INDEX IF NOT EXISTS ix_t_billing_run_society ON t_billing_run(society_id,billing_month,run_status);
CREATE INDEX IF NOT EXISTS ix_t_billing_run_detail_society ON t_billing_run_detail(society_id,billing_month,consumer_id);

-- Bootstrap a safe default configuration/property types for each existing society.
INSERT INTO m_billing_config(society_id,billing_frequency_months,dpc_applicable,dpc_apply_on,effective_from,modify_remark)
SELECT s.society_id,1,false,'ARREAR',current_date,'Initial billing configuration'
FROM m_society s
WHERE NOT EXISTS(SELECT 1 FROM m_billing_config x WHERE x.society_id=s.society_id);

INSERT INTO m_billing_property_type(society_id,property_type_code,property_type_name,modify_remark)
SELECT s.society_id,v.code,v.name,'Initial billing property type'
FROM m_society s
CROSS JOIN (VALUES('FLAT','Flat'),('SHOP','Shop'),('OTHER','Other')) v(code,name)
WHERE NOT EXISTS(SELECT 1 FROM m_billing_property_type p WHERE p.society_id=s.society_id AND p.property_type_code=v.code);

CREATE OR REPLACE FUNCTION fn_billing_get_configuration(p_society_id bigint)
RETURNS TABLE(
 billing_config_id bigint,billing_frequency_months integer,dpc_applicable boolean,dpc_apply_on varchar,
 dpc_rate numeric,dpc_calculation_type varchar,effective_from date,effective_to date,
 modify_by bigint,modify_date timestamptz,modify_remark text
)
LANGUAGE sql STABLE AS $$
SELECT billing_config_id,billing_frequency_months,dpc_applicable,dpc_apply_on,dpc_rate,dpc_calculation_type,
       effective_from,effective_to,modify_by,modify_date,modify_remark
FROM m_billing_config
WHERE society_id=p_society_id AND is_active AND effective_from<=current_date
  AND (effective_to IS NULL OR effective_to>=current_date)
ORDER BY effective_from DESC,billing_config_id DESC
LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION fn_billing_configuration_history(p_society_id bigint)
RETURNS TABLE(
 billing_config_history_id bigint,old_frequency_months integer,new_frequency_months integer,
 old_dpc_applicable boolean,new_dpc_applicable boolean,old_dpc_apply_on varchar,new_dpc_apply_on varchar,
 old_dpc_rate numeric,new_dpc_rate numeric,effective_from date,effective_to date,modify_by bigint,
 modify_date timestamptz,modify_remark text,active boolean
)
LANGUAGE sql STABLE AS $$
SELECT h.billing_config_history_id,h.old_frequency_months,h.new_frequency_months,h.old_dpc_applicable,h.new_dpc_applicable,
       h.old_dpc_apply_on,h.new_dpc_apply_on,h.old_dpc_rate,h.new_dpc_rate,h.effective_from,h.effective_to,
       h.modify_by,h.modify_date,h.modify_remark,h.active
FROM t_billing_config_history h
WHERE h.society_id=p_society_id
ORDER BY h.modify_date DESC,h.billing_config_history_id DESC;
$$;

CREATE OR REPLACE FUNCTION sp_billing_save_configuration(
 p_society_id bigint,p_frequency_months integer,p_dpc_applicable boolean,p_dpc_apply_on varchar,
 p_dpc_rate numeric,p_dpc_calculation_type varchar,p_effective_from date,p_effective_to date,
 p_user_id bigint,p_remark text
) RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE
 v_old m_billing_config%ROWTYPE;
 v_id bigint;
BEGIN
 IF p_frequency_months NOT BETWEEN 1 AND 12 THEN RAISE EXCEPTION 'Billing frequency must be between 1 and 12 months'; END IF;
 IF p_dpc_apply_on NOT IN('ARREAR','ARREAR_AND_INTEREST') THEN RAISE EXCEPTION 'Invalid DPC apply-on option'; END IF;
 IF p_dpc_rate<0 THEN RAISE EXCEPTION 'DPC rate cannot be negative'; END IF;
 IF NOT EXISTS(SELECT 1 FROM m_society WHERE society_id=p_society_id AND is_active) THEN RAISE EXCEPTION 'Society not found'; END IF;

 SELECT * INTO v_old FROM m_billing_config
 WHERE society_id=p_society_id AND is_active
 ORDER BY effective_from DESC,billing_config_id DESC LIMIT 1
 FOR UPDATE;

 IF v_old.billing_config_id IS NOT NULL THEN
   UPDATE m_billing_config SET is_active=false,effective_to=LEAST(coalesce(effective_to,p_effective_from-1),p_effective_from-1),
     modify_by=p_user_id,modify_date=now(),modify_remark=coalesce(p_remark,'')
   WHERE billing_config_id=v_old.billing_config_id;
 END IF;

 INSERT INTO m_billing_config(society_id,billing_frequency_months,dpc_applicable,dpc_apply_on,dpc_rate,dpc_calculation_type,
   effective_from,effective_to,is_active,modify_by,modify_date,modify_remark)
 VALUES(p_society_id,p_frequency_months,p_dpc_applicable,p_dpc_apply_on,p_dpc_rate,p_dpc_calculation_type,
   p_effective_from,p_effective_to,true,p_user_id,now(),coalesce(p_remark,'')) RETURNING billing_config_id INTO v_id;

 INSERT INTO t_billing_config_history(
   society_id,billing_config_id,old_frequency_months,new_frequency_months,old_dpc_applicable,new_dpc_applicable,
   old_dpc_apply_on,new_dpc_apply_on,old_dpc_rate,new_dpc_rate,effective_from,effective_to,active,modify_by,modify_date,modify_remark)
 VALUES(p_society_id,v_id,v_old.billing_frequency_months,p_frequency_months,v_old.dpc_applicable,p_dpc_applicable,
   v_old.dpc_apply_on,p_dpc_apply_on,v_old.dpc_rate,p_dpc_rate,p_effective_from,p_effective_to,true,p_user_id,now(),coalesce(p_remark,''));

 RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION fn_billing_property_types(p_society_id bigint)
RETURNS TABLE(billing_property_type_id bigint,property_type_code varchar,property_type_name varchar,is_active boolean,visible boolean)
LANGUAGE sql STABLE AS $$
SELECT billing_property_type_id,property_type_code,property_type_name,is_active,visible
FROM m_billing_property_type WHERE society_id=p_society_id AND is_active AND visible ORDER BY property_type_name;
$$;

CREATE OR REPLACE FUNCTION fn_billing_rates(p_society_id bigint,p_property_type_id bigint DEFAULT NULL,p_as_of date DEFAULT current_date)
RETURNS TABLE(
 billing_rate_id bigint,property_type_id bigint,property_type_name varchar,charge_code varchar,charge_name varchar,
 rate_type varchar,rate numeric,effective_from date,effective_to date,is_active boolean,visible boolean
)
LANGUAGE sql STABLE AS $$
SELECT r.billing_rate_id,r.billing_property_type_id,p.property_type_name,r.charge_code,r.charge_name,r.rate_type,r.rate,
       r.effective_from,r.effective_to,r.is_active,r.visible
FROM m_billing_rate r
LEFT JOIN m_billing_property_type p ON p.society_id=r.society_id AND p.billing_property_type_id=r.billing_property_type_id
WHERE r.society_id=p_society_id AND r.is_active AND r.visible
  AND (p_property_type_id IS NULL OR r.billing_property_type_id=p_property_type_id)
  AND r.effective_from<=p_as_of AND (r.effective_to IS NULL OR r.effective_to>=p_as_of)
ORDER BY p.property_type_name,r.charge_name,r.effective_from DESC;
$$;

CREATE OR REPLACE FUNCTION sp_billing_save_rate(
 p_society_id bigint,p_rate_id bigint,p_property_type_id bigint,p_charge_code varchar,p_charge_name varchar,
 p_rate_type varchar,p_rate numeric,p_effective_from date,p_effective_to date,p_user_id bigint,p_remark text
) RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint;
BEGIN
 IF p_rate_type NOT IN('PER_FLAT','PER_SQFT','PER_PARKING','FIXED') THEN RAISE EXCEPTION 'Invalid rate type'; END IF;
 IF p_rate<0 THEN RAISE EXCEPTION 'Rate cannot be negative'; END IF;
 IF NOT EXISTS(SELECT 1 FROM m_billing_property_type WHERE society_id=p_society_id AND billing_property_type_id=p_property_type_id AND is_active)
 THEN RAISE EXCEPTION 'Property type is not configured for this society'; END IF;
 IF p_rate_id>0 THEN
   UPDATE m_billing_rate SET billing_property_type_id=p_property_type_id,charge_code=p_charge_code,charge_name=p_charge_name,
     rate_type=p_rate_type,rate=p_rate,effective_from=p_effective_from,effective_to=p_effective_to,
     modify_by=p_user_id,modify_date=now(),modify_remark=coalesce(p_remark,'')
   WHERE billing_rate_id=p_rate_id AND society_id=p_society_id RETURNING billing_rate_id INTO v_id;
 ELSE
   INSERT INTO m_billing_rate(society_id,billing_property_type_id,charge_code,charge_name,rate_type,rate,effective_from,effective_to,modify_by,modify_date,modify_remark)
   VALUES(p_society_id,p_property_type_id,p_charge_code,p_charge_name,p_rate_type,p_rate,p_effective_from,p_effective_to,p_user_id,now(),coalesce(p_remark,'')) RETURNING billing_rate_id INTO v_id;
 END IF;
 IF v_id IS NULL THEN RAISE EXCEPTION 'Billing rate not found in selected society'; END IF;
 RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION fn_billing_get_next_month(p_society_id bigint)
RETURNS char(6)
LANGUAGE plpgsql STABLE AS $$
DECLARE v_last date; v_months integer; v_next date;
BEGIN
 SELECT max(bill_month) INTO v_last FROM t_bill WHERE society_id=p_society_id;
 SELECT billing_frequency_months INTO v_months FROM m_billing_config
 WHERE society_id=p_society_id AND is_active ORDER BY effective_from DESC LIMIT 1;
 v_months:=coalesce(v_months,1);
 IF v_last IS NULL THEN v_next=date_trunc('month',current_date)::date;
 ELSE v_next=(date_trunc('month',v_last)+make_interval(months=>v_months))::date; END IF;
 RETURN to_char(v_next,'YYYYMM')::char(6);
END $$;

CREATE OR REPLACE FUNCTION fn_billing_required_rate_count(p_society_id bigint,p_as_of date DEFAULT current_date)
RETURNS TABLE(property_type_id bigint,property_type_name varchar,missing_count integer)
LANGUAGE sql STABLE AS $$
WITH pt AS (
 SELECT billing_property_type_id,property_type_name FROM m_billing_property_type
 WHERE society_id=p_society_id AND is_active AND visible
), required(code,name) AS (
 VALUES('MAINTENANCE','Maintenance'),('SINKING_FUND','Sinking Fund'),('PARKING','Parking')
), x AS (
 SELECT pt.billing_property_type_id,pt.property_type_name,r.code
 FROM pt CROSS JOIN required r
 LEFT JOIN m_billing_rate br ON br.society_id=p_society_id AND br.billing_property_type_id=pt.billing_property_type_id
   AND br.charge_code=r.code AND br.is_active AND br.effective_from<=p_as_of
   AND (br.effective_to IS NULL OR br.effective_to>=p_as_of)
)
SELECT billing_property_type_id,property_type_name,count(*) FILTER(WHERE code IS NOT NULL AND NOT EXISTS(
 SELECT 1 FROM m_billing_rate z WHERE z.society_id=p_society_id AND z.billing_property_type_id=x.billing_property_type_id
 AND z.charge_code=x.code AND z.is_active AND z.effective_from<=p_as_of AND (z.effective_to IS NULL OR z.effective_to>=p_as_of)
))::integer
FROM x GROUP BY billing_property_type_id,property_type_name;
$$;

-- Rebuild/prepare is intentionally separate from finalization.
CREATE OR REPLACE FUNCTION sp_billing_prepare(p_society_id bigint,p_user_id bigint)
RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE
 v_month char(6); v_run bigint; v_cfg m_billing_config%ROWTYPE; r record; v_m numeric;v_s numeric;v_p numeric;v_o numeric;v_a numeric;v_i numeric;v_total numeric;
BEGIN
 SELECT * INTO v_cfg FROM m_billing_config WHERE society_id=p_society_id AND is_active AND effective_from<=current_date
 ORDER BY effective_from DESC LIMIT 1;
 IF v_cfg.billing_config_id IS NULL THEN RAISE EXCEPTION 'Billing configuration is not available'; END IF;
 v_month:=fn_billing_get_next_month(p_society_id);
 IF EXISTS(SELECT 1 FROM t_billing_run WHERE society_id=p_society_id AND billing_month=v_month AND run_status='FINALIZED') THEN RAISE EXCEPTION 'Billing month is already finalized'; END IF;
 IF EXISTS(SELECT 1 FROM t_billing_run WHERE society_id=p_society_id AND billing_month=v_month AND run_status='PREPARED') THEN
   SELECT billing_run_id INTO v_run FROM t_billing_run WHERE society_id=p_society_id AND billing_month=v_month AND run_status='PREPARED' LIMIT 1;
   DELETE FROM t_billing_run_detail WHERE billing_run_id=v_run;
   DELETE FROM t_billing_payment_adjustment WHERE billing_run_id=v_run;
 ELSE
   INSERT INTO t_billing_run(society_id,billing_month,run_status,prepared_by,modify_by,modify_remark)
   VALUES(p_society_id,v_month,'PREPARED',p_user_id,p_user_id,'Billing preparation') RETURNING billing_run_id INTO v_run;
 END IF;

 FOR r IN
   SELECT c.consumer_id,c.customer_id,cf.flat_id,coalesce(f.area_sqft,0) area_sqft,
          coalesce((SELECT sum(greatest(a.calculated_arrear,0)) FROM m_billing_arrear a WHERE a.society_id=p_society_id AND a.consumer_id=c.consumer_id AND a.is_active),0) arrear,
          coalesce((SELECT sum(greatest(a.calculated_interest,0)) FROM m_billing_arrear a WHERE a.society_id=p_society_id AND a.consumer_id=c.consumer_id AND a.is_active),0) interest
   FROM m_customer c JOIN m_customer_flat cf ON cf.society_id=c.society_id AND cf.customer_id=c.customer_id AND cf.is_primary
   JOIN m_flat f ON f.society_id=c.society_id AND f.flat_id=cf.flat_id
   WHERE c.society_id=p_society_id AND c.is_active AND f.is_active
 LOOP
   SELECT coalesce(sum(CASE WHEN br.rate_type='PER_FLAT' THEN br.rate WHEN br.rate_type='PER_SQFT' THEN br.rate*r.area_sqft WHEN br.rate_type='FIXED' THEN br.rate WHEN br.rate_type='PER_PARKING' THEN br.rate*(SELECT count(*) FROM t_parking_assignment pa WHERE pa.society_id=p_society_id AND pa.consumer_id=r.consumer_id AND pa.is_active) ELSE 0 END),0)
   INTO v_m FROM m_billing_rate br WHERE br.society_id=p_society_id AND br.charge_code='MAINTENANCE' AND br.is_active AND br.effective_from<=current_date AND (br.effective_to IS NULL OR br.effective_to>=current_date)
   AND br.billing_property_type_id=(SELECT billing_property_type_id FROM m_billing_property_type pt WHERE pt.society_id=p_society_id AND lower(pt.property_type_code)=lower(coalesce((SELECT unit_type FROM m_flat WHERE flat_id=r.flat_id),'FLAT')) LIMIT 1);
   SELECT coalesce(sum(CASE WHEN br.rate_type='PER_FLAT' THEN br.rate WHEN br.rate_type='PER_SQFT' THEN br.rate*r.area_sqft WHEN br.rate_type='FIXED' THEN br.rate WHEN br.rate_type='PER_PARKING' THEN br.rate*(SELECT count(*) FROM t_parking_assignment pa WHERE pa.society_id=p_society_id AND pa.consumer_id=r.consumer_id AND pa.is_active) ELSE 0 END),0)
   INTO v_s FROM m_billing_rate br WHERE br.society_id=p_society_id AND br.charge_code='SINKING_FUND' AND br.is_active AND br.effective_from<=current_date AND (br.effective_to IS NULL OR br.effective_to>=current_date)
   AND br.billing_property_type_id=(SELECT billing_property_type_id FROM m_billing_property_type pt WHERE pt.society_id=p_society_id AND lower(pt.property_type_code)=lower(coalesce((SELECT unit_type FROM m_flat WHERE flat_id=r.flat_id),'FLAT')) LIMIT 1);
   SELECT coalesce(sum(CASE WHEN br.rate_type='PER_FLAT' THEN br.rate WHEN br.rate_type='PER_SQFT' THEN br.rate*r.area_sqft WHEN br.rate_type='FIXED' THEN br.rate WHEN br.rate_type='PER_PARKING' THEN br.rate*(SELECT count(*) FROM t_parking_assignment pa WHERE pa.society_id=p_society_id AND pa.consumer_id=r.consumer_id AND pa.is_active) ELSE 0 END),0)
   INTO v_p FROM m_billing_rate br WHERE br.society_id=p_society_id AND br.charge_code='PARKING' AND br.is_active AND br.effective_from<=current_date AND (br.effective_to IS NULL OR br.effective_to>=current_date)
   AND br.billing_property_type_id=(SELECT billing_property_type_id FROM m_billing_property_type pt WHERE pt.society_id=p_society_id AND lower(pt.property_type_code)=lower(coalesce((SELECT unit_type FROM m_flat WHERE flat_id=r.flat_id),'FLAT')) LIMIT 1);
   v_o:=0;
   v_a:=r.arrear;
   v_i:=CASE WHEN v_cfg.dpc_applicable AND v_cfg.dpc_apply_on IN('ARREAR','ARREAR_AND_INTEREST') THEN round(v_a*v_cfg.dpc_rate/100,2) + CASE WHEN v_cfg.dpc_apply_on='ARREAR_AND_INTEREST' THEN r.interest ELSE 0 END ELSE r.interest END;
   v_total:=v_m+v_s+v_p+v_o+v_a+v_i;
   INSERT INTO t_billing_run_detail(billing_run_id,society_id,consumer_id,customer_id,flat_id,billing_month,maintenance_amount,sinking_fund_amount,parking_amount,other_charge_amount,arrear_amount,interest_arrear_amount,total_amount,balance_amount,modify_by)
   VALUES(v_run,p_society_id,r.consumer_id,r.customer_id,r.flat_id,v_month,v_m,v_s,v_p,v_o,v_a,v_i,v_total,v_total,p_user_id);
 END LOOP;
 UPDATE t_billing_run SET modify_by=p_user_id,modify_date=now() WHERE billing_run_id=v_run;
 RETURN v_run;
END $$;

CREATE OR REPLACE FUNCTION fn_billing_preview(p_society_id bigint,p_run_id bigint)
RETURNS TABLE(
 billing_run_detail_id bigint,consumer_id bigint,customer_id bigint,customer_name varchar,customer_number varchar,flat_no varchar,
 billing_month char(6),maintenance_amount numeric,sinking_fund_amount numeric,parking_amount numeric,other_charge_amount numeric,
 arrear_amount numeric,interest_arrear_amount numeric,total_amount numeric,payment_amount numeric,balance_amount numeric,status varchar
)
LANGUAGE sql STABLE AS $$
SELECT d.billing_run_detail_id,d.consumer_id,d.customer_id,c.full_name,c.customer_code,f.flat_no,d.billing_month,
 d.maintenance_amount,d.sinking_fund_amount,d.parking_amount,d.other_charge_amount,d.arrear_amount,d.interest_arrear_amount,
 d.total_amount,d.payment_amount,d.balance_amount,d.status
FROM t_billing_run_detail d JOIN m_customer c ON c.society_id=d.society_id AND c.customer_id=d.customer_id
LEFT JOIN m_flat f ON f.society_id=d.society_id AND f.flat_id=d.flat_id
WHERE d.society_id=p_society_id AND d.billing_run_id=p_run_id
ORDER BY d.billing_month,c.full_name,d.consumer_id;
$$;

CREATE OR REPLACE FUNCTION sp_billing_finalize(p_society_id bigint,p_run_id bigint,p_user_id bigint,p_confirm boolean)
RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE v_month char(6); v_bill_month date; r record; v_bill_id bigint; v_no varchar; v_pay record; v_remaining numeric; v_adj numeric;
BEGIN
 IF NOT p_confirm THEN RAISE EXCEPTION 'Billing finalization requires confirmation'; END IF;
 SELECT billing_month INTO v_month FROM t_billing_run WHERE society_id=p_society_id AND billing_run_id=p_run_id AND run_status='PREPARED' FOR UPDATE;
 IF v_month IS NULL THEN RAISE EXCEPTION 'Prepared billing run not found'; END IF;
 v_bill_month:=to_date(v_month||'01','YYYYMMDD');
 IF EXISTS(SELECT 1 FROM t_bill WHERE society_id=p_society_id AND bill_month=v_bill_month) THEN RAISE EXCEPTION 'Billing month already exists'; END IF;

 -- Payment adjustment: oldest interest first, then oldest calculated arrear. Raw values are never changed.
 FOR v_pay IN
   SELECT p.* FROM t_payment p WHERE p.society_id=p_society_id AND p.status='Success'
   AND p.processed_billing_month IS NULL AND p.processed_date IS NULL
   ORDER BY p.payment_date,p.payment_id
 LOOP
   v_remaining:=v_pay.amount;
   FOR r IN SELECT * FROM m_billing_arrear WHERE society_id=p_society_id AND consumer_id=v_pay.consumer_id AND is_active
     AND (calculated_interest>0 OR calculated_arrear>0) ORDER BY bill_month,billing_arrear_id FOR UPDATE
   LOOP
     EXIT WHEN v_remaining<=0;
     v_adj:=least(v_remaining,greatest(r.calculated_interest,0));
     IF v_adj>0 THEN
       UPDATE m_billing_arrear SET calculated_interest=calculated_interest-v_adj,adjustment=adjustment+v_adj,modify_by=p_user_id,modify_date=now(),modify_remark='Payment adjustment - interest first'
       WHERE billing_arrear_id=r.billing_arrear_id;
       INSERT INTO t_billing_payment_adjustment(society_id,billing_run_id,payment_id,consumer_id,billing_month,interest_adjusted,adjustment_total,modify_by)
       VALUES(p_society_id,p_run_id,v_pay.payment_id,v_pay.consumer_id,r.bill_month,v_adj,v_adj,p_user_id)
       ON CONFLICT(billing_run_id,payment_id) DO UPDATE SET interest_adjusted=t_billing_payment_adjustment.interest_adjusted+excluded.interest_adjusted,adjustment_total=t_billing_payment_adjustment.adjustment_total+excluded.adjustment_total;
       v_remaining:=v_remaining-v_adj;
     END IF;
     v_adj:=least(v_remaining,greatest(r.calculated_arrear,0));
     IF v_adj>0 THEN
       UPDATE m_billing_arrear SET calculated_arrear=calculated_arrear-v_adj,adjustment=adjustment+v_adj,modify_by=p_user_id,modify_date=now(),modify_remark='Payment adjustment - arrear'
       WHERE billing_arrear_id=r.billing_arrear_id;
       INSERT INTO t_billing_payment_adjustment(society_id,billing_run_id,payment_id,consumer_id,billing_month,arrear_adjusted,adjustment_total,modify_by)
       VALUES(p_society_id,p_run_id,v_pay.payment_id,v_pay.consumer_id,r.bill_month,v_adj,v_adj,p_user_id)
       ON CONFLICT(billing_run_id,payment_id) DO UPDATE SET arrear_adjusted=t_billing_payment_adjustment.arrear_adjusted+excluded.arrear_adjusted,adjustment_total=t_billing_payment_adjustment.adjustment_total+excluded.adjustment_total;
       v_remaining:=v_remaining-v_adj;
     END IF;
   END LOOP;
   UPDATE t_payment SET processed_billing_month=v_month,processed_date=now(),modify_by=p_user_id,modify_date=now(),modify_remark='Processed by billing finalization'
   WHERE payment_id=v_pay.payment_id AND society_id=p_society_id;
 END LOOP;

 FOR r IN SELECT * FROM t_billing_run_detail WHERE billing_run_id=p_run_id AND society_id=p_society_id ORDER BY consumer_id
 LOOP
   v_no:='BILL-'||v_month||'-'||lpad(r.consumer_id::text,8,'0');
   INSERT INTO t_bill(society_id,flat_id,consumer_id,bill_no,bill_month,bill_date,due_date,subtotal,dpc_amount,total_amount,paid_amount,status,
     maintenance_amount,sinking_fund_amount,parking_amount,other_charge_amount,arrear_amount,interest_arrear_amount,outstanding_amount,modify_by,modify_date,modify_remark)
   VALUES(p_society_id,r.flat_id,r.consumer_id,v_no,v_bill_month,current_date,(current_date+15),r.total_amount-r.interest_arrear_amount,r.interest_arrear_amount,
     r.total_amount,0,'Pending',r.maintenance_amount,r.sinking_fund_amount,r.parking_amount,r.other_charge_amount,r.arrear_amount,r.interest_arrear_amount,r.total_amount,p_user_id,now(),'Billing finalization')
   RETURNING bill_id INTO v_bill_id;

   INSERT INTO t_bill_line_item(society_id,bill_id,consumer_id,description,quantity,rate,amount,historical_rule)
   VALUES
   (p_society_id,v_bill_id,r.consumer_id,'Maintenance',1,r.maintenance_amount,r.maintenance_amount,jsonb_build_object('billing_month',v_month)),
   (p_society_id,v_bill_id,r.consumer_id,'Sinking Fund',1,r.sinking_fund_amount,r.sinking_fund_amount,jsonb_build_object('billing_month',v_month)),
   (p_society_id,v_bill_id,r.consumer_id,'Parking',1,r.parking_amount,r.parking_amount,jsonb_build_object('billing_month',v_month)),
   (p_society_id,v_bill_id,r.consumer_id,'Other Charges',1,r.other_charge_amount,r.other_charge_amount,jsonb_build_object('billing_month',v_month)),
   (p_society_id,v_bill_id,r.consumer_id,'Arrear',1,r.arrear_amount,r.arrear_amount,jsonb_build_object('billing_month',v_month)),
   (p_society_id,v_bill_id,r.consumer_id,'Interest Arrear',1,r.interest_arrear_amount,r.interest_arrear_amount,jsonb_build_object('billing_month',v_month));

   INSERT INTO m_billing_arrear(society_id,consumer_id,customer_id,flat_id,bill_month,raw_arrear,calculated_arrear,raw_interest,calculated_interest,modify_by,modify_remark)
   VALUES(p_society_id,r.consumer_id,r.customer_id,r.flat_id,v_month,r.arrear_amount,r.arrear_amount,r.interest_arrear_amount,r.interest_arrear_amount,p_user_id,'Carry-forward billing arrear')
   ON CONFLICT(society_id,consumer_id,bill_month) DO NOTHING;

   INSERT INTO t_service_history(society_id,consumer_id,performed_by,reference_no,event_type,event_sub_type,event_title,event_description,event_data,modify_remark)
   VALUES(p_society_id,r.consumer_id,p_user_id,v_no,'Billing','Bill Generated','Bill Generated',
     'Bill '||v_no||' generated for '||v_month,jsonb_build_object('billId',v_bill_id,'billMonth',v_month,'amount',r.total_amount),'Billing finalization');
 END LOOP;

 UPDATE t_billing_run SET run_status='FINALIZED',finalized_at=now(),finalized_by=p_user_id,modify_by=p_user_id,modify_date=now(),modify_remark='Billing finalized'
 WHERE billing_run_id=p_run_id AND society_id=p_society_id;
 RETURN p_run_id;
END $$;

CREATE OR REPLACE FUNCTION fn_billing_required_rates_missing(p_society_id bigint,p_as_of date DEFAULT current_date)
RETURNS TABLE(property_type_id bigint,property_type_name varchar,charge_code varchar,charge_name varchar)
LANGUAGE sql STABLE AS $$
WITH req(code,name) AS (VALUES('MAINTENANCE','Maintenance'),('SINKING_FUND','Sinking Fund'),('PARKING','Parking'))
SELECT p.billing_property_type_id,p.property_type_name,q.code,q.name
FROM m_billing_property_type p CROSS JOIN req q
WHERE p.society_id=p_society_id AND p.is_active AND p.visible
AND NOT EXISTS(SELECT 1 FROM m_billing_rate r WHERE r.society_id=p_society_id AND r.billing_property_type_id=p.billing_property_type_id
 AND r.charge_code=q.code AND r.is_active AND r.effective_from<=p_as_of AND (r.effective_to IS NULL OR r.effective_to>=p_as_of))
ORDER BY p.property_type_name,q.code;
$$;


-- Payment staging is allocation-level (one payment can span many arrears/months).
ALTER TABLE t_billing_payment_adjustment ADD COLUMN IF NOT EXISTS billing_arrear_id bigint REFERENCES m_billing_arrear(billing_arrear_id);
ALTER TABLE t_billing_payment_adjustment ADD COLUMN IF NOT EXISTS allocation_order integer;
ALTER TABLE t_billing_payment_adjustment DROP CONSTRAINT IF EXISTS t_billing_payment_adjustment_billing_run_id_payment_id_key;

CREATE INDEX IF NOT EXISTS ix_t_billing_payment_adjustment_run
 ON t_billing_payment_adjustment(society_id,billing_run_id,payment_id,billing_arrear_id);

CREATE OR REPLACE FUNCTION sp_billing_stage_payment_adjustments(p_society_id bigint,p_run_id bigint)
RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
 p record; a record; v_remaining numeric; v_adj numeric; v_order integer;
BEGIN
 DELETE FROM t_billing_payment_adjustment WHERE society_id=p_society_id AND billing_run_id=p_run_id;
 FOR p IN
   SELECT payment_id,consumer_id,amount FROM t_payment
   WHERE society_id=p_society_id AND status='Success'
     AND processed_billing_month IS NULL AND processed_date IS NULL
     AND consumer_id IS NOT NULL
   ORDER BY payment_date,payment_id
 LOOP
   v_remaining:=greatest(p.amount,0); v_order:=0;
   FOR a IN
     SELECT billing_arrear_id,bill_month,calculated_interest,calculated_arrear
     FROM m_billing_arrear
     WHERE society_id=p_society_id AND consumer_id=p.consumer_id AND is_active
       AND (calculated_interest>0 OR calculated_arrear>0)
     ORDER BY bill_month,billing_arrear_id
   LOOP
     EXIT WHEN v_remaining<=0;
     v_adj:=least(v_remaining,greatest(a.calculated_interest,0));
     IF v_adj>0 THEN
       v_order:=v_order+1;
       INSERT INTO t_billing_payment_adjustment(
         society_id,billing_run_id,payment_id,consumer_id,billing_arrear_id,billing_month,
         interest_adjusted,arrear_adjusted,adjustment_total,allocation_order,modify_remark)
       VALUES(p_society_id,p_run_id,p.payment_id,p.consumer_id,a.billing_arrear_id,a.bill_month,
              v_adj,0,v_adj,v_order,'Preview allocation - oldest interest first');
       v_remaining:=v_remaining-v_adj;
     END IF;
     v_adj:=least(v_remaining,greatest(a.calculated_arrear,0));
     IF v_adj>0 THEN
       v_order:=v_order+1;
       INSERT INTO t_billing_payment_adjustment(
         society_id,billing_run_id,payment_id,consumer_id,billing_arrear_id,billing_month,
         interest_adjusted,arrear_adjusted,adjustment_total,allocation_order,modify_remark)
       VALUES(p_society_id,p_run_id,p.payment_id,p.consumer_id,a.billing_arrear_id,a.bill_month,
              0,v_adj,v_adj,v_order,'Preview allocation - oldest arrear first');
       v_remaining:=v_remaining-v_adj;
     END IF;
   END LOOP;
 END LOOP;
END $$;

CREATE OR REPLACE FUNCTION sp_billing_prepare(p_society_id bigint,p_user_id bigint)
RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE
 v_month char(6); v_run bigint; v_cfg m_billing_config%ROWTYPE; r record;
 v_m numeric;v_s numeric;v_p numeric;v_o numeric;v_a numeric;v_i numeric;v_total numeric;
 v_payment numeric;
BEGIN
 SELECT * INTO v_cfg FROM m_billing_config
 WHERE society_id=p_society_id AND is_active AND effective_from<=current_date
 ORDER BY effective_from DESC LIMIT 1;
 IF v_cfg.billing_config_id IS NULL THEN RAISE EXCEPTION 'Billing configuration is not available'; END IF;

 v_month:=fn_billing_get_next_month(p_society_id);
 IF EXISTS(SELECT 1 FROM t_billing_run WHERE society_id=p_society_id AND billing_month=v_month AND run_status='FINALIZED')
 THEN RAISE EXCEPTION 'Billing month is already finalized'; END IF;

 SELECT billing_run_id INTO v_run FROM t_billing_run
 WHERE society_id=p_society_id AND billing_month=v_month AND run_status='PREPARED'
 ORDER BY billing_run_id DESC LIMIT 1;

 IF v_run IS NULL THEN
   INSERT INTO t_billing_run(society_id,billing_month,run_status,prepared_by,modify_by,modify_remark)
   VALUES(p_society_id,v_month,'PREPARED',p_user_id,p_user_id,'Billing preparation')
   RETURNING billing_run_id INTO v_run;
 ELSE
   DELETE FROM t_billing_run_detail WHERE billing_run_id=v_run;
 END IF;

 PERFORM sp_billing_stage_payment_adjustments(p_society_id,v_run);

 FOR r IN
   SELECT c.consumer_id,c.customer_id,cf.flat_id,coalesce(f.area_sqft,0) area_sqft,
          lower(coalesce(f.unit_type,'flat')) property_type,
          coalesce((SELECT sum(greatest(a.calculated_arrear,0))
                    FROM m_billing_arrear a
                    WHERE a.society_id=p_society_id AND a.consumer_id=c.consumer_id AND a.is_active),0) arrear,
          coalesce((SELECT sum(greatest(a.calculated_interest,0))
                    FROM m_billing_arrear a
                    WHERE a.society_id=p_society_id AND a.consumer_id=c.consumer_id AND a.is_active),0) interest,
          coalesce((SELECT sum(x.arrear_adjusted) FROM t_billing_payment_adjustment x
                    WHERE x.society_id=p_society_id AND x.billing_run_id=v_run AND x.consumer_id=c.consumer_id),0) staged_arrear,
          coalesce((SELECT sum(x.interest_adjusted) FROM t_billing_payment_adjustment x
                    WHERE x.society_id=p_society_id AND x.billing_run_id=v_run AND x.consumer_id=c.consumer_id),0) staged_interest,
          coalesce((SELECT sum(x.adjustment_total) FROM t_billing_payment_adjustment x
                    WHERE x.society_id=p_society_id AND x.billing_run_id=v_run AND x.consumer_id=c.consumer_id),0) staged_payment
   FROM m_customer c
   JOIN m_customer_flat cf ON cf.society_id=c.society_id AND cf.customer_id=c.customer_id AND cf.is_primary
   JOIN m_flat f ON f.society_id=c.society_id AND f.flat_id=cf.flat_id
   WHERE c.society_id=p_society_id AND c.is_active AND f.is_active
 LOOP
   SELECT coalesce(sum(CASE WHEN br.rate_type='PER_FLAT' THEN br.rate
                            WHEN br.rate_type='PER_SQFT' THEN br.rate*r.area_sqft
                            WHEN br.rate_type='FIXED' THEN br.rate
                            WHEN br.rate_type='PER_PARKING' THEN br.rate*(
                              SELECT count(*) FROM t_parking_assignment pa
                              WHERE pa.society_id=p_society_id AND pa.consumer_id=r.consumer_id AND pa.is_active)
                            ELSE 0 END),0)
   INTO v_m FROM m_billing_rate br
   WHERE br.society_id=p_society_id AND br.charge_code='MAINTENANCE' AND br.is_active
     AND br.effective_from<=current_date AND (br.effective_to IS NULL OR br.effective_to>=current_date)
     AND br.billing_property_type_id=(SELECT pt.billing_property_type_id FROM m_billing_property_type pt
       WHERE pt.society_id=p_society_id AND lower(pt.property_type_code)=r.property_type LIMIT 1);

   SELECT coalesce(sum(CASE WHEN br.rate_type='PER_FLAT' THEN br.rate
                            WHEN br.rate_type='PER_SQFT' THEN br.rate*r.area_sqft
                            WHEN br.rate_type='FIXED' THEN br.rate
                            WHEN br.rate_type='PER_PARKING' THEN br.rate*(
                              SELECT count(*) FROM t_parking_assignment pa
                              WHERE pa.society_id=p_society_id AND pa.consumer_id=r.consumer_id AND pa.is_active)
                            ELSE 0 END),0)
   INTO v_s FROM m_billing_rate br
   WHERE br.society_id=p_society_id AND br.charge_code='SINKING_FUND' AND br.is_active
     AND br.effective_from<=current_date AND (br.effective_to IS NULL OR br.effective_to>=current_date)
     AND br.billing_property_type_id=(SELECT pt.billing_property_type_id FROM m_billing_property_type pt
       WHERE pt.society_id=p_society_id AND lower(pt.property_type_code)=r.property_type LIMIT 1);

   SELECT coalesce(sum(CASE WHEN br.rate_type='PER_FLAT' THEN br.rate
                            WHEN br.rate_type='PER_SQFT' THEN br.rate*r.area_sqft
                            WHEN br.rate_type='FIXED' THEN br.rate
                            WHEN br.rate_type='PER_PARKING' THEN br.rate*(
                              SELECT count(*) FROM t_parking_assignment pa
                              WHERE pa.society_id=p_society_id AND pa.consumer_id=r.consumer_id AND pa.is_active)
                            ELSE 0 END),0)
   INTO v_p FROM m_billing_rate br
   WHERE br.society_id=p_society_id AND br.charge_code='PARKING' AND br.is_active
     AND br.effective_from<=current_date AND (br.effective_to IS NULL OR br.effective_to>=current_date)
     AND br.billing_property_type_id=(SELECT pt.billing_property_type_id FROM m_billing_property_type pt
       WHERE pt.society_id=p_society_id AND lower(pt.property_type_code)=r.property_type LIMIT 1);

   v_o:=0;
   v_a:=greatest(r.arrear-r.staged_arrear,0);
   v_i:=greatest(r.interest-r.staged_interest,0);
   IF v_cfg.dpc_applicable AND v_cfg.dpc_rate>0 THEN
      v_i:=v_i+round(v_a*v_cfg.dpc_rate/100,2);
   END IF;
   v_total:=v_m+v_s+v_p+v_o+v_a+v_i;

   INSERT INTO t_billing_run_detail(
     billing_run_id,society_id,consumer_id,customer_id,flat_id,billing_month,
     maintenance_amount,sinking_fund_amount,parking_amount,other_charge_amount,
     arrear_amount,interest_arrear_amount,total_amount,payment_amount,balance_amount,modify_by,modify_remark)
   VALUES(v_run,p_society_id,r.consumer_id,r.customer_id,r.flat_id,v_month,
          v_m,v_s,v_p,v_o,v_a,v_i,v_total,r.staged_payment,greatest(v_total-r.staged_payment,0),p_user_id,
          'Database billing calculation');
 END LOOP;

 UPDATE t_billing_run SET modify_by=p_user_id,modify_date=now() WHERE billing_run_id=v_run;
 RETURN v_run;
END $$;

CREATE OR REPLACE FUNCTION sp_billing_finalize(p_society_id bigint,p_run_id bigint,p_user_id bigint,p_confirm boolean)
RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE v_month char(6);v_bill_month date;r record;a record;v_bill_id bigint;v_no varchar;
BEGIN
 IF NOT p_confirm THEN RAISE EXCEPTION 'Billing finalization requires confirmation'; END IF;
 SELECT billing_month INTO v_month FROM t_billing_run
 WHERE society_id=p_society_id AND billing_run_id=p_run_id AND run_status='PREPARED' FOR UPDATE;
 IF v_month IS NULL THEN RAISE EXCEPTION 'Prepared billing run not found'; END IF;
 v_bill_month:=to_date(v_month||'01','YYYYMMDD');

 IF EXISTS(SELECT 1 FROM t_bill WHERE society_id=p_society_id AND bill_month=v_bill_month)
 THEN RAISE EXCEPTION 'Billing month already exists'; END IF;

 -- Apply only the allocations staged for this run. Raw arrear/interest stay unchanged.
 FOR a IN
   SELECT billing_arrear_id,sum(interest_adjusted) interest_adj,sum(arrear_adjusted) arrear_adj
   FROM t_billing_payment_adjustment
   WHERE society_id=p_society_id AND billing_run_id=p_run_id
   GROUP BY billing_arrear_id
   FOR UPDATE
 LOOP
   UPDATE m_billing_arrear
   SET calculated_interest=greatest(calculated_interest-a.interest_adj,0),
       calculated_arrear=greatest(calculated_arrear-a.arrear_adj,0),
       adjustment=adjustment+a.interest_adj+a.arrear_adj,
       status=CASE WHEN greatest(calculated_interest-a.interest_adj,0)+greatest(calculated_arrear-a.arrear_adj,0)=0 THEN 'CLEARED' ELSE status END,
       modify_by=p_user_id,modify_date=now(),modify_remark='Payment adjustment finalized'
   WHERE billing_arrear_id=a.billing_arrear_id AND society_id=p_society_id;
 END LOOP;

 UPDATE t_payment p SET processed_billing_month=v_month,processed_date=now(),modify_by=p_user_id,modify_date=now(),modify_remark='Processed by billing finalization'
 WHERE p.society_id=p_society_id AND p.processed_billing_month IS NULL AND p.processed_date IS NULL
   AND EXISTS(SELECT 1 FROM t_billing_payment_adjustment x WHERE x.society_id=p_society_id AND x.billing_run_id=p_run_id AND x.payment_id=p.payment_id);

 FOR r IN SELECT * FROM t_billing_run_detail WHERE society_id=p_society_id AND billing_run_id=p_run_id ORDER BY consumer_id
 LOOP
   v_no:='BILL-'||v_month||'-'||lpad(r.consumer_id::text,8,'0');
   INSERT INTO t_bill(
     society_id,flat_id,consumer_id,bill_no,bill_month,bill_date,due_date,subtotal,dpc_amount,total_amount,paid_amount,status,
     maintenance_amount,sinking_fund_amount,parking_amount,other_charge_amount,arrear_amount,interest_arrear_amount,outstanding_amount,
     modify_by,modify_date,modify_remark)
   VALUES(
     p_society_id,r.flat_id,r.consumer_id,v_no,v_bill_month,current_date,current_date+15,
     greatest(r.total_amount-r.interest_arrear_amount,0),r.interest_arrear_amount,r.total_amount,0,'Pending',
     r.maintenance_amount,r.sinking_fund_amount,r.parking_amount,r.other_charge_amount,r.arrear_amount,r.interest_arrear_amount,
     greatest(r.balance_amount,0),p_user_id,now(),'Billing finalization');

   INSERT INTO t_bill_line_item(society_id,bill_id,consumer_id,description,quantity,rate,amount,historical_rule)
   VALUES
    (p_society_id,v_bill_id,r.consumer_id,'Maintenance',1,r.maintenance_amount,r.maintenance_amount,jsonb_build_object('billing_month',v_month)),
    (p_society_id,v_bill_id,r.consumer_id,'Sinking Fund',1,r.sinking_fund_amount,r.sinking_fund_amount,jsonb_build_object('billing_month',v_month)),
    (p_society_id,v_bill_id,r.consumer_id,'Parking',1,r.parking_amount,r.parking_amount,jsonb_build_object('billing_month',v_month)),
    (p_society_id,v_bill_id,r.consumer_id,'Other Charges',1,r.other_charge_amount,r.other_charge_amount,jsonb_build_object('billing_month',v_month)),
    (p_society_id,v_bill_id,r.consumer_id,'Arrear',1,r.arrear_amount,r.arrear_amount,jsonb_build_object('billing_month',v_month)),
    (p_society_id,v_bill_id,r.consumer_id,'Interest Arrear',1,r.interest_arrear_amount,r.interest_arrear_amount,jsonb_build_object('billing_month',v_month));

   INSERT INTO m_billing_arrear(
     society_id,consumer_id,customer_id,flat_id,bill_month,raw_arrear,calculated_arrear,raw_interest,calculated_interest,modify_by,modify_remark)
   VALUES(p_society_id,r.consumer_id,r.customer_id,r.flat_id,v_month,r.arrear_amount,r.arrear_amount,r.interest_arrear_amount,r.interest_arrear_amount,p_user_id,'Carry-forward from finalized billing')
   ON CONFLICT(society_id,consumer_id,bill_month) DO NOTHING;

   INSERT INTO t_service_history(
     society_id,consumer_id,customer_id,flat_id,reference_no,event_type,event_sub_type,event_title,event_description,event_data,
     performed_by,performed_at,modify_remark)
   VALUES(p_society_id,r.consumer_id,r.customer_id,r.flat_id,v_no,'Billing','Bill Generated','Bill Generated',
          'Bill '||v_no||' generated for '||v_month,jsonb_build_object('billId',v_bill_id,'billMonth',v_month,'amount',r.total_amount),
          p_user_id,now(),'Billing finalization');
 END LOOP;

 UPDATE t_billing_run SET run_status='FINALIZED',finalized_at=now(),finalized_by=p_user_id,modify_by=p_user_id,modify_date=now(),modify_remark='Billing finalized'
 WHERE society_id=p_society_id AND billing_run_id=p_run_id;
 RETURN p_run_id;
END $$;


CREATE OR REPLACE FUNCTION sp_billing_finalize(p_society_id bigint,p_run_id bigint,p_user_id bigint,p_confirm boolean)
RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE v_month char(6);v_bill_month date;r record;a record;v_bill_id bigint;v_no varchar;
BEGIN
 IF NOT p_confirm THEN RAISE EXCEPTION 'Billing finalization requires confirmation'; END IF;
 SELECT billing_month INTO v_month FROM t_billing_run
 WHERE society_id=p_society_id AND billing_run_id=p_run_id AND run_status='PREPARED' FOR UPDATE;
 IF v_month IS NULL THEN RAISE EXCEPTION 'Prepared billing run not found'; END IF;
 v_bill_month:=to_date(v_month||'01','YYYYMMDD');
 IF EXISTS(SELECT 1 FROM t_bill WHERE society_id=p_society_id AND bill_month=v_bill_month)
 THEN RAISE EXCEPTION 'Billing month already exists'; END IF;

 FOR a IN
   SELECT billing_arrear_id,sum(interest_adjusted) interest_adj,sum(arrear_adjusted) arrear_adj
   FROM t_billing_payment_adjustment
   WHERE society_id=p_society_id AND billing_run_id=p_run_id
   GROUP BY billing_arrear_id
 LOOP
   UPDATE m_billing_arrear
   SET calculated_interest=greatest(calculated_interest-a.interest_adj,0),
       calculated_arrear=greatest(calculated_arrear-a.arrear_adj,0),
       adjustment=adjustment+a.interest_adj+a.arrear_adj,
       status=CASE WHEN greatest(calculated_interest-a.interest_adj,0)+greatest(calculated_arrear-a.arrear_adj,0)=0 THEN 'CLEARED' ELSE status END,
       modify_by=p_user_id,modify_date=now(),modify_remark='Payment adjustment finalized'
   WHERE billing_arrear_id=a.billing_arrear_id AND society_id=p_society_id;
 END LOOP;

 UPDATE t_payment p
 SET processed_billing_month=v_month,processed_date=now(),modify_by=p_user_id,modify_date=now(),
     modify_remark='Processed by billing finalization'
 WHERE p.society_id=p_society_id AND p.processed_billing_month IS NULL AND p.processed_date IS NULL
   AND EXISTS(SELECT 1 FROM t_billing_payment_adjustment x
              WHERE x.society_id=p_society_id AND x.billing_run_id=p_run_id AND x.payment_id=p.payment_id);

 FOR r IN SELECT * FROM t_billing_run_detail WHERE society_id=p_society_id AND billing_run_id=p_run_id ORDER BY consumer_id
 LOOP
   v_no:='BILL-'||v_month||'-'||lpad(r.consumer_id::text,8,'0');
   INSERT INTO t_bill(
     society_id,flat_id,consumer_id,bill_no,bill_month,bill_date,due_date,subtotal,dpc_amount,total_amount,paid_amount,status,
     maintenance_amount,sinking_fund_amount,parking_amount,other_charge_amount,arrear_amount,interest_arrear_amount,outstanding_amount,
     modify_by,modify_date,modify_remark)
   VALUES(
     p_society_id,r.flat_id,r.consumer_id,v_no,v_bill_month,current_date,current_date+15,
     greatest(r.total_amount-r.interest_arrear_amount,0),r.interest_arrear_amount,r.total_amount,0,'Pending',
     r.maintenance_amount,r.sinking_fund_amount,r.parking_amount,r.other_charge_amount,r.arrear_amount,r.interest_arrear_amount,
     greatest(r.balance_amount,0),p_user_id,now(),'Billing finalization')
   RETURNING bill_id INTO v_bill_id;

   INSERT INTO t_bill_line_item(society_id,bill_id,consumer_id,description,quantity,rate,amount,historical_rule)
   VALUES
    (p_society_id,v_bill_id,r.consumer_id,'Maintenance',1,r.maintenance_amount,r.maintenance_amount,jsonb_build_object('billing_month',v_month)),
    (p_society_id,v_bill_id,r.consumer_id,'Sinking Fund',1,r.sinking_fund_amount,r.sinking_fund_amount,jsonb_build_object('billing_month',v_month)),
    (p_society_id,v_bill_id,r.consumer_id,'Parking',1,r.parking_amount,r.parking_amount,jsonb_build_object('billing_month',v_month)),
    (p_society_id,v_bill_id,r.consumer_id,'Other Charges',1,r.other_charge_amount,r.other_charge_amount,jsonb_build_object('billing_month',v_month)),
    (p_society_id,v_bill_id,r.consumer_id,'Arrear',1,r.arrear_amount,r.arrear_amount,jsonb_build_object('billing_month',v_month)),
    (p_society_id,v_bill_id,r.consumer_id,'Interest Arrear',1,r.interest_arrear_amount,r.interest_arrear_amount,jsonb_build_object('billing_month',v_month));

   INSERT INTO m_billing_arrear(
     society_id,consumer_id,customer_id,flat_id,bill_month,raw_arrear,calculated_arrear,raw_interest,calculated_interest,modify_by,modify_remark)
   VALUES(p_society_id,r.consumer_id,r.customer_id,r.flat_id,v_month,r.arrear_amount,r.arrear_amount,r.interest_arrear_amount,r.interest_arrear_amount,p_user_id,'Carry-forward from finalized billing')
   ON CONFLICT(society_id,consumer_id,bill_month) DO NOTHING;

   INSERT INTO t_service_history(
     society_id,consumer_id,customer_id,flat_id,reference_no,event_type,event_sub_type,event_title,event_description,event_data,
     performed_by,performed_at,modify_remark)
   VALUES(p_society_id,r.consumer_id,r.customer_id,r.flat_id,v_no,'Billing','Bill Generated','Bill Generated',
          'Bill '||v_no||' generated for '||v_month,jsonb_build_object('billId',v_bill_id,'billMonth',v_month,'amount',r.total_amount),
          p_user_id,now(),'Billing finalization');
 END LOOP;

 UPDATE t_billing_run SET run_status='FINALIZED',finalized_at=now(),finalized_by=p_user_id,
   modify_by=p_user_id,modify_date=now(),modify_remark='Billing finalized'
 WHERE society_id=p_society_id AND billing_run_id=p_run_id;
 RETURN p_run_id;
END $$;


CREATE TABLE IF NOT EXISTS m_billing_frequency(
 billing_frequency_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 frequency_months integer NOT NULL UNIQUE CHECK(frequency_months BETWEEN 1 AND 12),
 frequency_name varchar(80) NOT NULL,
 is_active boolean NOT NULL DEFAULT true,
 visible boolean NOT NULL DEFAULT true,
 modify_by bigint REFERENCES m_user(user_id),
 modify_date timestamptz NOT NULL DEFAULT now(),
 modify_remark text DEFAULT ''
);
INSERT INTO m_billing_frequency(frequency_months,frequency_name) VALUES
(1,'Monthly'),(2,'Bi-monthly'),(3,'Every 3 Months'),(6,'Every 6 Months')
ON CONFLICT(frequency_months) DO UPDATE SET frequency_name=excluded.frequency_name,is_active=true,visible=true;

CREATE TABLE IF NOT EXISTS m_billing_dpc_apply_on(
 dpc_apply_on_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 apply_code varchar(40) NOT NULL UNIQUE,
 apply_name varchar(120) NOT NULL,
 is_active boolean NOT NULL DEFAULT true,
 visible boolean NOT NULL DEFAULT true,
 modify_by bigint REFERENCES m_user(user_id),
 modify_date timestamptz NOT NULL DEFAULT now(),
 modify_remark text DEFAULT ''
);
INSERT INTO m_billing_dpc_apply_on(apply_code,apply_name) VALUES
('ARREAR','Arrear only'),('ARREAR_AND_INTEREST','Arrear + Previous Interest/DPC Arrear')
ON CONFLICT(apply_code) DO UPDATE SET apply_name=excluded.apply_name,is_active=true,visible=true;

CREATE OR REPLACE FUNCTION fn_billing_frequencies()
RETURNS TABLE(frequency_months integer,frequency_name varchar)
LANGUAGE sql STABLE AS $$
SELECT frequency_months,frequency_name FROM m_billing_frequency
WHERE is_active AND visible ORDER BY frequency_months;
$$;

CREATE OR REPLACE FUNCTION fn_billing_dpc_apply_on()
RETURNS TABLE(apply_code varchar,apply_name varchar)
LANGUAGE sql STABLE AS $$
SELECT apply_code,apply_name FROM m_billing_dpc_apply_on
WHERE is_active AND visible ORDER BY dpc_apply_on_id;
$$;

CREATE OR REPLACE FUNCTION sp_billing_save_configuration(
 p_society_id bigint,p_frequency_months integer,p_dpc_applicable boolean,p_dpc_apply_on varchar,
 p_dpc_rate numeric,p_dpc_calculation_type varchar,p_effective_from date,p_effective_to date,
 p_user_id bigint,p_remark text
) RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE v_old m_billing_config%ROWTYPE;v_id bigint;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM m_billing_frequency WHERE frequency_months=p_frequency_months AND is_active AND visible)
 THEN RAISE EXCEPTION 'Billing frequency is not configured'; END IF;
 IF NOT EXISTS(SELECT 1 FROM m_billing_dpc_apply_on WHERE apply_code=p_dpc_apply_on AND is_active AND visible)
 THEN RAISE EXCEPTION 'DPC apply-on option is not configured'; END IF;
 IF p_dpc_rate<0 THEN RAISE EXCEPTION 'DPC rate cannot be negative'; END IF;
 SELECT * INTO v_old FROM m_billing_config WHERE society_id=p_society_id AND is_active
 ORDER BY effective_from DESC,billing_config_id DESC LIMIT 1 FOR UPDATE;
 IF v_old.billing_config_id IS NOT NULL THEN
   UPDATE m_billing_config SET is_active=false,
     effective_to=LEAST(coalesce(effective_to,p_effective_from-1),p_effective_from-1),
     modify_by=p_user_id,modify_date=now(),modify_remark=coalesce(p_remark,'')
   WHERE billing_config_id=v_old.billing_config_id;
 END IF;
 INSERT INTO m_billing_config(
   society_id,billing_frequency_months,dpc_applicable,dpc_apply_on,dpc_rate,dpc_calculation_type,
   effective_from,effective_to,is_active,modify_by,modify_date,modify_remark)
 VALUES(
   p_society_id,p_frequency_months,p_dpc_applicable,p_dpc_apply_on,p_dpc_rate,p_dpc_calculation_type,
   p_effective_from,p_effective_to,true,p_user_id,now(),coalesce(p_remark,''))
 RETURNING billing_config_id INTO v_id;
 INSERT INTO t_billing_config_history(
   society_id,billing_config_id,old_frequency_months,new_frequency_months,old_dpc_applicable,new_dpc_applicable,
   old_dpc_apply_on,new_dpc_apply_on,old_dpc_rate,new_dpc_rate,effective_from,effective_to,active,modify_by,modify_date,modify_remark)
 VALUES(
   p_society_id,v_id,v_old.billing_frequency_months,p_frequency_months,v_old.dpc_applicable,p_dpc_applicable,
   v_old.dpc_apply_on,p_dpc_apply_on,v_old.dpc_rate,p_dpc_rate,p_effective_from,p_effective_to,true,p_user_id,now(),coalesce(p_remark,''));
 RETURN v_id;
END $$;


-- Final Billing navigation: Billing -> Billing Configuration / Billing Process.
INSERT INTO m_module(module_code,module_name,parent_module_code,display_order,visible,is_active)
VALUES
('BILLING','Billing',NULL,80,true,true),
('BILLING_CONFIGURATION','Billing Configuration','BILLING',81,true,true),
('BILLING_PROCESS','Billing Process','BILLING',82,true,true)
ON CONFLICT(module_code) DO UPDATE SET
 module_name=excluded.module_name,parent_module_code=excluded.parent_module_code,
 display_order=excluded.display_order,visible=true,is_active=true;

INSERT INTO m_permission(module_code,action_code,permission_name,is_active,visible)
SELECT m.module_code,a.code,m.module_name||' - '||a.code,true,true
FROM m_module m
CROSS JOIN (VALUES('VIEW'),('ADD'),('EDIT'),('POST'),('PRINT'),('EXPORT')) a(code)
WHERE m.module_code IN('BILLING','BILLING_CONFIGURATION','BILLING_PROCESS')
ON CONFLICT(module_code,action_code) DO UPDATE SET is_active=true,visible=true,permission_name=excluded.permission_name;

INSERT INTO m_role_permission(role_id,permission_id)
SELECT r.role_id,p.permission_id
FROM m_role r JOIN m_permission p ON p.module_code IN('BILLING','BILLING_CONFIGURATION','BILLING_PROCESS')
WHERE r.role_code IN('SOCIETY_ADMIN','SUPER_ADMIN') AND p.is_active
ON CONFLICT DO NOTHING;

-- Retire the previous multi-level Billing Management entries without deleting historical permissions.
UPDATE m_module SET visible=false,is_active=false
WHERE module_code IN(
 'SA_BILLING_DASH','SA_BILL_GENERATION','SA_BILL_REGISTER','SA_BILL_ADJUSTMENT','SA_REBATE','SA_DPC',
 'SA_CHARGE_CONFIG','SA_RATE_PLANS','SA_TAX_CONFIG','BILL_RANGE','BILL_DUMMY_CYCLE','BILL_ERROR_CORRECTION',
 'BILL_COMPUTATION','BILL_DOWNLOAD','BILL_REVERT','BILL_TRACKER','BILL_ADJUSTMENT','BILL_TARIFF','BILL_DUMMY','BILL_ESTIMATE'
);


-- Migrate existing property/rate configuration into the new billing rate model.
INSERT INTO m_billing_property_type(society_id,property_type_code,property_type_name,modify_remark)
SELECT DISTINCT f.society_id,upper(trim(f.unit_type)),trim(f.unit_type),'Migrated from existing flat property type'
FROM m_flat f
WHERE f.is_active AND nullif(trim(f.unit_type),'') IS NOT NULL
  AND NOT EXISTS(
    SELECT 1 FROM m_billing_property_type p
    WHERE p.society_id=f.society_id AND lower(p.property_type_code)=lower(trim(f.unit_type))
  );

CREATE UNIQUE INDEX IF NOT EXISTS ux_m_billing_rate_scope
 ON m_billing_rate(society_id,billing_property_type_id,charge_code,effective_from);

INSERT INTO m_billing_rate(
 society_id,billing_property_type_id,charge_code,charge_name,rate_type,rate,effective_from,effective_to,modify_remark)
SELECT x.society_id,x.billing_property_type_id,x.charge_code,x.charge_name,x.rate_type,x.rate,x.effective_from,x.effective_to,
       'Migrated from existing charge/rate configuration'
FROM (
 SELECT DISTINCT ON (cr.society_id,pt.billing_property_type_id,
   CASE ct.charge_code WHEN 'MAINT' THEN 'MAINTENANCE' WHEN 'SINK' THEN 'SINKING_FUND'
                       WHEN 'PARK' THEN 'PARKING' WHEN 'REPAIR' THEN 'OTHER_CHARGES' END,
   cr.effective_from)
   cr.society_id,pt.billing_property_type_id,
   CASE ct.charge_code WHEN 'MAINT' THEN 'MAINTENANCE' WHEN 'SINK' THEN 'SINKING_FUND'
                       WHEN 'PARK' THEN 'PARKING' WHEN 'REPAIR' THEN 'OTHER_CHARGES' END charge_code,
   CASE ct.charge_code WHEN 'MAINT' THEN 'Maintenance' WHEN 'SINK' THEN 'Sinking Fund'
                       WHEN 'PARK' THEN 'Parking' WHEN 'REPAIR' THEN 'Other Charges' END charge_name,
   CASE lower(cr.calculation_method) WHEN 'persqft' THEN 'PER_SQFT'
        WHEN 'perunit' THEN 'PER_FLAT' WHEN 'fixed' THEN 'PER_FLAT' ELSE 'FIXED' END rate_type,
   cr.rate,cr.effective_from,cr.effective_to
 FROM m_charge_rule cr
 JOIN m_charge_type ct ON ct.society_id=cr.society_id AND ct.charge_type_id=cr.charge_type_id
 JOIN m_billing_property_type pt ON pt.society_id=cr.society_id
 WHERE ct.charge_code IN('MAINT','SINK','PARK','REPAIR') AND ct.is_active
 ORDER BY cr.society_id,pt.billing_property_type_id,
   CASE ct.charge_code WHEN 'MAINT' THEN 'MAINTENANCE' WHEN 'SINK' THEN 'SINKING_FUND'
                       WHEN 'PARK' THEN 'PARKING' WHEN 'REPAIR' THEN 'OTHER_CHARGES' END,
   cr.effective_from DESC,cr.charge_rule_id DESC
) x
ON CONFLICT(society_id,billing_property_type_id,charge_code,effective_from)
DO UPDATE SET charge_name=excluded.charge_name,rate_type=excluded.rate_type,rate=excluded.rate,
              effective_to=excluded.effective_to,modify_date=now(),modify_remark='Migrated from existing charge/rate configuration';

CREATE OR REPLACE FUNCTION fn_billing_required_rates_missing(p_society_id bigint,p_as_of date DEFAULT current_date)
RETURNS TABLE(property_type_id bigint,property_type_name varchar,charge_code varchar,charge_name varchar)
LANGUAGE sql STABLE AS $$
WITH used_types AS (
 SELECT DISTINCT pt.billing_property_type_id,pt.property_type_name
 FROM m_flat f
 JOIN m_billing_property_type pt ON pt.society_id=f.society_id
   AND lower(pt.property_type_code)=lower(coalesce(f.unit_type,''))
 WHERE f.society_id=p_society_id AND f.is_active
), req(code,name) AS (
 VALUES('MAINTENANCE','Maintenance'),('SINKING_FUND','Sinking Fund'),('PARKING','Parking')
)
SELECT p.billing_property_type_id,p.property_type_name,q.code,q.name
FROM used_types p CROSS JOIN req q
WHERE NOT EXISTS(
 SELECT 1 FROM m_billing_rate r
 WHERE r.society_id=p_society_id AND r.billing_property_type_id=p.billing_property_type_id
   AND r.charge_code=q.code AND r.is_active AND r.effective_from<=p_as_of
   AND (r.effective_to IS NULL OR r.effective_to>=p_as_of)
)
ORDER BY p.property_type_name,q.code;
$$;

CREATE OR REPLACE FUNCTION fn_billing_required_rate_count(p_society_id bigint,p_as_of date DEFAULT current_date)
RETURNS TABLE(property_type_id bigint,property_type_name varchar,missing_count integer)
LANGUAGE sql STABLE AS $$
WITH used_types AS (
 SELECT DISTINCT pt.billing_property_type_id,pt.property_type_name
 FROM m_flat f JOIN m_billing_property_type pt
   ON pt.society_id=f.society_id AND lower(pt.property_type_code)=lower(coalesce(f.unit_type,''))
 WHERE f.society_id=p_society_id AND f.is_active
), req(code) AS (VALUES('MAINTENANCE'),('SINKING_FUND'),('PARKING'))
SELECT p.billing_property_type_id,p.property_type_name,count(q.code) FILTER(WHERE NOT EXISTS(
 SELECT 1 FROM m_billing_rate r WHERE r.society_id=p_society_id AND r.billing_property_type_id=p.billing_property_type_id
   AND r.charge_code=q.code AND r.is_active AND r.effective_from<=p_as_of
   AND (r.effective_to IS NULL OR r.effective_to>=p_as_of)
))::integer
FROM used_types p CROSS JOIN req q
GROUP BY p.billing_property_type_id,p.property_type_name;
$$;
