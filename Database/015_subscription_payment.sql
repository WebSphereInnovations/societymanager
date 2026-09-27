SET search_path TO society_manager, public;

CREATE OR REPLACE FUNCTION fn_record_subscription_payment(
 p_society_id bigint,p_subscription_id bigint,p_amount numeric,p_payment_mode varchar,
 p_reference_no varchar,p_user_id bigint
)
RETURNS TABLE(payment_id bigint,subscription_id bigint,payment_status varchar)
LANGUAGE plpgsql AS $$
DECLARE v_payment_id bigint;
BEGIN
 IF p_amount <= 0 THEN RAISE EXCEPTION 'Payment amount must be greater than zero'; END IF;
 IF NOT EXISTS (
   SELECT 1 FROM m_society_subscription
   WHERE subscription_id=p_subscription_id AND society_id=p_society_id AND is_active
 ) THEN RAISE EXCEPTION 'Active subscription not found'; END IF;
 IF p_amount <> (SELECT amount FROM m_society_subscription WHERE subscription_id=p_subscription_id) THEN
   RAISE EXCEPTION 'Payment amount does not match subscription amount';
 END IF;
 INSERT INTO t_subscription_payment(
   society_id,subscription_id,amount,payment_mode,reference_no,status,created_by
 ) VALUES (
   p_society_id,p_subscription_id,p_amount,upper(trim(p_payment_mode)),
   nullif(trim(p_reference_no),''),'Success',p_user_id
 ) RETURNING t_subscription_payment.subscription_payment_id INTO v_payment_id;
 UPDATE m_society_subscription
 SET payment_status='Paid',
     payment_reference=nullif(trim(p_reference_no),'')
 WHERE subscription_id=p_subscription_id;
 PERFORM fn_log_audit(
   p_society_id,p_user_id,'m_society_subscription',p_subscription_id,'PAYMENT',
   NULL,jsonb_build_object('amount',p_amount,'mode',upper(trim(p_payment_mode)))
 );
 RETURN QUERY
 SELECT v_payment_id,p_subscription_id,'Paid'::varchar;
END;
$$;CREATE OR REPLACE FUNCTION fn_current_society_subscription(p_society_id bigint)
RETURNS TABLE(subscription_id bigint,plan_code varchar,plan_name varchar,start_date date,end_date date,amount numeric,payment_status varchar,payment_reference varchar,days_remaining integer)
LANGUAGE sql AS $$
SELECT ss.subscription_id,sp.plan_code,sp.plan_name,ss.start_date,ss.end_date,ss.amount,
 ss.payment_status,ss.payment_reference,(ss.end_date-current_date)::integer
FROM m_society_subscription ss
JOIN m_subscription_plan sp ON sp.subscription_plan_id=ss.subscription_plan_id
WHERE ss.society_id=p_society_id AND ss.is_active
ORDER BY ss.end_date DESC
LIMIT 1;
$$;
