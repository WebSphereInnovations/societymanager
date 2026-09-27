SET search_path TO society_manager, public;
INSERT INTO m_society_subscription(society_id,subscription_plan_id,start_date,end_date,amount,payment_status,is_active)
SELECT s.society_id,p.subscription_plan_id,current_date-30,current_date+334,p.price,'Paid',true
FROM m_society s JOIN m_subscription_plan p ON p.plan_code=CASE WHEN s.society_code='LAKEVIEW' THEN 'PRO' ELSE 'STARTER' END
WHERE NOT EXISTS(SELECT 1 FROM m_society_subscription x WHERE x.society_id=s.society_id AND x.is_active);
CREATE OR REPLACE FUNCTION fn_super_admin_subscription_payments()
RETURNS TABLE(subscription_payment_id bigint,society_name varchar,plan_name varchar,payment_date date,amount numeric,payment_mode varchar,reference_no varchar,status varchar)
LANGUAGE sql AS $$ SELECT p.subscription_payment_id,s.society_name,sp.plan_name,p.payment_date::date,p.amount,p.payment_mode,p.reference_no,p.status FROM t_subscription_payment p JOIN m_society s ON s.society_id=p.society_id JOIN m_society_subscription ss ON ss.subscription_id=p.subscription_id JOIN m_subscription_plan sp ON sp.subscription_plan_id=ss.subscription_plan_id ORDER BY p.payment_date DESC,p.subscription_payment_id DESC; $$;
CREATE OR REPLACE FUNCTION fn_super_admin_record_subscription_payment(p_subscription_id bigint,p_amount numeric,p_mode varchar,p_reference varchar,p_user_id bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint; v_society bigint;
BEGIN SELECT society_id INTO v_society FROM m_society_subscription WHERE subscription_id=p_subscription_id; IF v_society IS NULL THEN RAISE EXCEPTION 'Subscription not found'; END IF;
INSERT INTO t_subscription_payment(society_id,subscription_id,amount,payment_mode,reference_no,created_by) VALUES(v_society,p_subscription_id,p_amount,p_mode,p_reference,p_user_id) RETURNING subscription_payment_id INTO v_id;
UPDATE m_society_subscription SET payment_status='Paid',payment_reference=p_reference WHERE subscription_id=p_subscription_id;
RETURN v_id; END; $$;