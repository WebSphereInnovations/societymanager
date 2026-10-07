SET search_path TO society_manager, public;

-- Billing hardening: dynamic extra charges, last-payment metadata, and DPC apply-on semantics.
ALTER TABLE t_billing_run_detail ADD COLUMN IF NOT EXISTS last_payment_amount numeric(18,2) NOT NULL DEFAULT 0;
ALTER TABLE t_billing_run_detail ADD COLUMN IF NOT EXISTS last_payment_date timestamptz;
ALTER TABLE t_bill ADD COLUMN IF NOT EXISTS last_payment_amount numeric(18,2) NOT NULL DEFAULT 0;
ALTER TABLE t_bill ADD COLUMN IF NOT EXISTS last_payment_date timestamptz;

-- Expose every 1..12 month interval dynamically through the frequency master.
INSERT INTO m_billing_frequency(frequency_months,frequency_name,is_active,visible)
SELECT n,
       CASE n
         WHEN 1 THEN 'Monthly'
         WHEN 2 THEN 'Bi-monthly'
         ELSE 'Every '||n||' Months'
       END,
       true,true
FROM generate_series(1,12) n
ON CONFLICT(frequency_months) DO UPDATE
SET frequency_name=excluded.frequency_name,is_active=true,visible=true;

CREATE INDEX IF NOT EXISTS ix_t_billing_run_detail_payment
  ON t_billing_run_detail(society_id,consumer_id,billing_month,last_payment_date DESC);

CREATE OR REPLACE FUNCTION sp_billing_prepare(p_society_id bigint,p_user_id bigint)
RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE
 v_month char(6); v_run bigint; v_cfg m_billing_config%ROWTYPE; r record;
 v_m numeric;v_s numeric;v_p numeric;v_o numeric;v_a numeric;v_i numeric;v_total numeric;
 v_payment numeric;v_last_payment_amount numeric;v_last_payment_date timestamptz;
 v_dpc_base numeric;
BEGIN
 SELECT * INTO v_cfg FROM m_billing_config
 WHERE society_id=p_society_id AND is_active AND effective_from<=current_date
 ORDER BY effective_from DESC,billing_config_id DESC LIMIT 1;
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
   DELETE FROM t_billing_payment_adjustment WHERE billing_run_id=v_run;
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
   SELECT coalesce(sum(CASE
       WHEN br.rate_type='PER_FLAT' THEN br.rate
       WHEN br.rate_type='PER_SQFT' THEN br.rate*r.area_sqft
       WHEN br.rate_type='FIXED' THEN br.rate
       WHEN br.rate_type='PER_PARKING' THEN br.rate*(SELECT count(*) FROM t_parking_assignment pa WHERE pa.society_id=p_society_id AND pa.consumer_id=r.consumer_id AND pa.is_active)
       ELSE 0 END),0)
   INTO v_m FROM m_billing_rate br
   WHERE br.society_id=p_society_id AND br.charge_code='MAINTENANCE' AND br.is_active
     AND br.effective_from<=current_date AND (br.effective_to IS NULL OR br.effective_to>=current_date)
     AND br.billing_property_type_id=(SELECT pt.billing_property_type_id FROM m_billing_property_type pt
       WHERE pt.society_id=p_society_id AND lower(pt.property_type_code)=r.property_type LIMIT 1);

   SELECT coalesce(sum(CASE
       WHEN br.rate_type='PER_FLAT' THEN br.rate
       WHEN br.rate_type='PER_SQFT' THEN br.rate*r.area_sqft
       WHEN br.rate_type='FIXED' THEN br.rate
       WHEN br.rate_type='PER_PARKING' THEN br.rate*(SELECT count(*) FROM t_parking_assignment pa WHERE pa.society_id=p_society_id AND pa.consumer_id=r.consumer_id AND pa.is_active)
       ELSE 0 END),0)
   INTO v_s FROM m_billing_rate br
   WHERE br.society_id=p_society_id AND br.charge_code='SINKING_FUND' AND br.is_active
     AND br.effective_from<=current_date AND (br.effective_to IS NULL OR br.effective_to>=current_date)
     AND br.billing_property_type_id=(SELECT pt.billing_property_type_id FROM m_billing_property_type pt
       WHERE pt.society_id=p_society_id AND lower(pt.property_type_code)=r.property_type LIMIT 1);

   SELECT coalesce(sum(CASE
       WHEN br.rate_type='PER_FLAT' THEN br.rate
       WHEN br.rate_type='PER_SQFT' THEN br.rate*r.area_sqft
       WHEN br.rate_type='FIXED' THEN br.rate
       WHEN br.rate_type='PER_PARKING' THEN br.rate*(SELECT count(*) FROM t_parking_assignment pa WHERE pa.society_id=p_society_id AND pa.consumer_id=r.consumer_id AND pa.is_active)
       ELSE 0 END),0)
   INTO v_p FROM m_billing_rate br
   WHERE br.society_id=p_society_id AND br.charge_code='PARKING' AND br.is_active
     AND br.effective_from<=current_date AND (br.effective_to IS NULL OR br.effective_to>=current_date)
     AND br.billing_property_type_id=(SELECT pt.billing_property_type_id FROM m_billing_property_type pt
       WHERE pt.society_id=p_society_id AND lower(pt.property_type_code)=r.property_type LIMIT 1);

   -- All configured charge codes beyond the core three are included in Other Charges.
   SELECT coalesce(sum(CASE
       WHEN br.rate_type='PER_FLAT' THEN br.rate
       WHEN br.rate_type='PER_SQFT' THEN br.rate*r.area_sqft
       WHEN br.rate_type='FIXED' THEN br.rate
       WHEN br.rate_type='PER_PARKING' THEN br.rate*(SELECT count(*) FROM t_parking_assignment pa WHERE pa.society_id=p_society_id AND pa.consumer_id=r.consumer_id AND pa.is_active)
       ELSE 0 END),0)
   INTO v_o FROM m_billing_rate br
   WHERE br.society_id=p_society_id AND br.charge_code NOT IN('MAINTENANCE','SINKING_FUND','PARKING')
     AND br.is_active AND br.effective_from<=current_date
     AND (br.effective_to IS NULL OR br.effective_to>=current_date)
     AND br.billing_property_type_id=(SELECT pt.billing_property_type_id FROM m_billing_property_type pt
       WHERE pt.society_id=p_society_id AND lower(pt.property_type_code)=r.property_type LIMIT 1);

   v_a:=greatest(r.arrear-r.staged_arrear,0);
   v_i:=greatest(r.interest-r.staged_interest,0);

   IF v_cfg.dpc_applicable AND v_cfg.dpc_rate>0 THEN
      v_dpc_base:=v_a;
      IF v_cfg.dpc_apply_on='ARREAR_AND_INTEREST' THEN
         v_dpc_base:=v_a+v_i;
      END IF;
      v_i:=v_i+round(v_dpc_base*v_cfg.dpc_rate/100,2);
   END IF;

   SELECT coalesce(p.amount,0),p.payment_date
   INTO v_last_payment_amount,v_last_payment_date
   FROM t_payment p
   WHERE p.society_id=p_society_id AND p.consumer_id=r.consumer_id AND p.status='Success'
   ORDER BY p.payment_date DESC,p.payment_id DESC LIMIT 1;

   v_total:=v_m+v_s+v_p+v_o+v_a+v_i;
   v_payment:=r.staged_payment;

   INSERT INTO t_billing_run_detail(
     billing_run_id,society_id,consumer_id,customer_id,flat_id,billing_month,
     maintenance_amount,sinking_fund_amount,parking_amount,other_charge_amount,
     arrear_amount,interest_arrear_amount,total_amount,payment_amount,balance_amount,
     last_payment_amount,last_payment_date,modify_by,modify_remark)
   VALUES(v_run,p_society_id,r.consumer_id,r.customer_id,r.flat_id,v_month,
          v_m,v_s,v_p,v_o,v_a,v_i,v_total,v_payment,greatest(v_total-v_payment,0),
          coalesce(v_last_payment_amount,0),v_last_payment_date,p_user_id,
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
     last_payment_amount,last_payment_date,billing_run_detail_id,billing_run_id,modify_by,modify_date,modify_remark)
   VALUES(
     p_society_id,r.flat_id,r.consumer_id,v_no,v_bill_month,current_date,current_date+15,
     greatest(r.total_amount-r.interest_arrear_amount,0),r.interest_arrear_amount,r.total_amount,0,'Pending',
     r.maintenance_amount,r.sinking_fund_amount,r.parking_amount,r.other_charge_amount,r.arrear_amount,r.interest_arrear_amount,
     greatest(r.balance_amount,0),r.last_payment_amount,r.last_payment_date,r.billing_run_detail_id,p_run_id,
     p_user_id,now(),'Billing finalization')
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
          'Bill '||v_no||' generated for '||v_month||' - Amount INR '||to_char(r.total_amount,'FM999999999990.00'),
          jsonb_build_object('billId',v_bill_id,'billMonth',v_month,'amount',r.total_amount),
          p_user_id,now(),'Billing finalization');
 END LOOP;

 UPDATE t_billing_run SET run_status='FINALIZED',finalized_at=now(),finalized_by=p_user_id,
   modify_by=p_user_id,modify_date=now(),modify_remark='Billing finalized'
 WHERE society_id=p_society_id AND billing_run_id=p_run_id;
 RETURN p_run_id;
END $$;


DROP FUNCTION IF EXISTS fn_billing_preview(bigint,bigint);

CREATE FUNCTION fn_billing_preview(p_society_id bigint,p_run_id bigint)
RETURNS TABLE(
 billing_run_detail_id bigint,consumer_id bigint,customer_id bigint,customer_name varchar,customer_number varchar,flat_no varchar,
 billing_month char(6),maintenance_amount numeric,sinking_fund_amount numeric,parking_amount numeric,other_charge_amount numeric,
 arrear_amount numeric,interest_arrear_amount numeric,total_amount numeric,payment_amount numeric,balance_amount numeric,
 last_payment_amount numeric,last_payment_date timestamptz,status varchar
)
LANGUAGE sql STABLE AS $$
SELECT d.billing_run_detail_id,d.consumer_id,d.customer_id,c.full_name,c.customer_code,f.flat_no,d.billing_month,
 d.maintenance_amount,d.sinking_fund_amount,d.parking_amount,d.other_charge_amount,d.arrear_amount,d.interest_arrear_amount,
 d.total_amount,d.payment_amount,d.balance_amount,d.last_payment_amount,d.last_payment_date,d.status
FROM t_billing_run_detail d
JOIN m_customer c ON c.society_id=d.society_id AND c.customer_id=d.customer_id
LEFT JOIN m_flat f ON f.society_id=d.society_id AND f.flat_id=d.flat_id
WHERE d.society_id=p_society_id AND d.billing_run_id=p_run_id
ORDER BY d.billing_month,c.full_name,d.consumer_id;
$$;

CREATE OR REPLACE FUNCTION sp_billing_save_configuration(
 p_society_id bigint,p_frequency_months integer,p_dpc_applicable boolean,p_dpc_apply_on varchar,
 p_dpc_rate numeric,p_dpc_calculation_type varchar,p_effective_from date,p_effective_to date,
 p_user_id bigint,p_remark text
) RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE v_old m_billing_config%ROWTYPE; v_id bigint;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM m_billing_frequency WHERE frequency_months=p_frequency_months AND is_active AND visible)
 THEN RAISE EXCEPTION 'Billing frequency is not configured'; END IF;
 IF NOT EXISTS(SELECT 1 FROM m_billing_dpc_apply_on WHERE apply_code=p_dpc_apply_on AND is_active AND visible)
 THEN RAISE EXCEPTION 'DPC apply-on option is not configured'; END IF;
 IF p_dpc_rate<0 THEN RAISE EXCEPTION 'DPC rate cannot be negative'; END IF;
 IF NOT EXISTS(SELECT 1 FROM m_society WHERE society_id=p_society_id AND is_active)
 THEN RAISE EXCEPTION 'Society not found'; END IF;

 SELECT * INTO v_old FROM m_billing_config
 WHERE society_id=p_society_id AND is_active
 ORDER BY effective_from DESC,billing_config_id DESC LIMIT 1 FOR UPDATE;

 IF v_old.billing_config_id IS NOT NULL AND v_old.effective_from=p_effective_from THEN
   INSERT INTO t_billing_config_history(
     society_id,billing_config_id,old_frequency_months,new_frequency_months,old_dpc_applicable,new_dpc_applicable,
     old_dpc_apply_on,new_dpc_apply_on,old_dpc_rate,new_dpc_rate,effective_from,effective_to,active,modify_by,modify_date,modify_remark)
   VALUES(
     p_society_id,v_old.billing_config_id,v_old.billing_frequency_months,p_frequency_months,v_old.dpc_applicable,p_dpc_applicable,
     v_old.dpc_apply_on,p_dpc_apply_on,v_old.dpc_rate,p_dpc_rate,p_effective_from,p_effective_to,true,p_user_id,now(),coalesce(p_remark,''));

   UPDATE m_billing_config SET
     billing_frequency_months=p_frequency_months,dpc_applicable=p_dpc_applicable,dpc_apply_on=p_dpc_apply_on,
     dpc_rate=p_dpc_rate,dpc_calculation_type=p_dpc_calculation_type,effective_to=p_effective_to,
     modify_by=p_user_id,modify_date=now(),modify_remark=coalesce(p_remark,'')
   WHERE billing_config_id=v_old.billing_config_id
   RETURNING billing_config_id INTO v_id;
   RETURN v_id;
 END IF;

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
