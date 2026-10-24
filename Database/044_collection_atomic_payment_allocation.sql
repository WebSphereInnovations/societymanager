-- Collection Management hardening: atomic bill allocation and explicit unprocessed payment metadata.
-- Safe to re-run. Existing historical payment rows are not rewritten.
BEGIN;

ALTER TABLE society_manager.t_payment
    ADD COLUMN IF NOT EXISTS tag text NULL;

ALTER TABLE society_manager.t_payment
    ALTER COLUMN processed_billing_month DROP DEFAULT;

CREATE OR REPLACE FUNCTION society_manager.sp_accept_payment(
    p_society_id bigint,
    p_customer_id bigint,
    p_flat_id bigint,
    p_amount numeric,
    p_payment_mode varchar,
    p_reference varchar,
    p_remarks text,
    p_payment_date timestamptz,
    p_cheque_no varchar,
    p_cheque_date date,
    p_cheque_bank varchar,
    p_user_id bigint
)
RETURNS bigint
LANGUAGE plpgsql
AS $function$
DECLARE
    v_payment_id bigint;
    v_receipt_id bigint;
    v_payment_no varchar;
    v_receipt_no varchar;
    v_due numeric(18,2);
    v_remaining numeric(18,2);
    v_bill record;
    v_alloc numeric(18,2);
BEGIN
    IF p_society_id IS NULL OR p_customer_id IS NULL OR p_flat_id IS NULL THEN
        RAISE EXCEPTION 'Customer and flat are required';
    END IF;
    IF p_amount IS NULL OR p_amount <= 0 OR p_amount <> round(p_amount, 2) THEN
        RAISE EXCEPTION 'Payment amount must be a positive currency amount with at most two decimals';
    END IF;
    IF p_payment_mode IS NULL OR btrim(p_payment_mode) = '' THEN
        RAISE EXCEPTION 'Payment mode is required';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM society_manager.m_customer c
        WHERE c.society_id=p_society_id AND c.customer_id=p_customer_id AND c.is_active
    ) THEN RAISE EXCEPTION 'Customer not found in selected society'; END IF;
    IF NOT EXISTS (
        SELECT 1 FROM society_manager.m_customer_flat cf
        JOIN society_manager.m_flat f ON f.flat_id=cf.flat_id AND f.society_id=cf.society_id
        WHERE cf.society_id=p_society_id AND cf.customer_id=p_customer_id
          AND cf.flat_id=p_flat_id AND f.is_active
    ) THEN RAISE EXCEPTION 'Customer is not linked to selected flat'; END IF;
    IF NOT EXISTS (
        SELECT 1 FROM society_manager.m_collection_payment_mode
        WHERE society_id=p_society_id AND payment_mode_code=p_payment_mode AND visible AND is_active
    ) THEN RAISE EXCEPTION 'Payment mode is not available'; END IF;
    IF upper(p_payment_mode) IN ('CHEQUE','DD','DEMAND_DRAFT')
       AND coalesce(nullif(btrim(p_cheque_no),''),nullif(btrim(p_reference),'')) IS NULL THEN
        RAISE EXCEPTION 'Cheque or demand draft reference is required';
    END IF;

    -- Serialize collectors for this society/flat, then lock eligible bills in due-date order.
    PERFORM pg_advisory_xact_lock(hashtextextended(p_society_id::text || ':' || p_flat_id::text, 0));
    PERFORM b.bill_id
    FROM society_manager.t_bill b
    WHERE b.society_id=p_society_id AND b.flat_id=p_flat_id
      AND b.status NOT IN ('Paid','Cancelled','Cancelled','Void','Reversed')
      AND b.total_amount > b.paid_amount
    ORDER BY b.due_date NULLS LAST, b.bill_date, b.bill_id
    FOR UPDATE;

    SELECT coalesce(sum(greatest(b.total_amount-b.paid_amount,0)),0)::numeric(18,2)
      INTO v_due
    FROM society_manager.t_bill b
    WHERE b.society_id=p_society_id AND b.flat_id=p_flat_id
      AND b.status NOT IN ('Paid','Cancelled','Void','Reversed')
      AND b.total_amount > b.paid_amount;

    -- Do not silently discard excess cash or invent customer-credit behavior.
    IF p_amount > v_due THEN
        RAISE EXCEPTION 'Payment exceeds eligible bill outstanding amount (%). Excess payments are not enabled', v_due;
    END IF;
    IF v_due <= 0 THEN RAISE EXCEPTION 'No eligible outstanding bill exists for this flat'; END IF;

    v_payment_no := 'PAY-' || to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS') || '-' || lpad((floor(random()*1000))::text,3,'0');
    INSERT INTO society_manager.t_payment(
        society_id,customer_id,flat_id,payment_no,payment_date,amount,payment_mode,reference_no,
        remarks,status,created_by,modify_by,modify_date,modify_remark,cheque_no,cheque_date,cheque_bank,
        processed_billing_month,processed_date,tag
    ) VALUES (
        p_society_id,p_customer_id,p_flat_id,v_payment_no,coalesce(p_payment_date,now()),p_amount,
        p_payment_mode,nullif(btrim(p_reference),''),p_remarks,'Success',p_user_id,p_user_id,now(),
        coalesce(p_remarks,''),nullif(btrim(p_cheque_no),''),p_cheque_date,nullif(btrim(p_cheque_bank),''),
        NULL,NULL,NULL
    ) RETURNING payment_id INTO v_payment_id;

    v_receipt_no := 'RCT-' || to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS') || '-' || lpad((floor(random()*1000))::text,3,'0');
    INSERT INTO society_manager.t_receipt(
        society_id,payment_id,receipt_no,receipt_date,amount,created_by,modify_by,modify_date,modify_remark
    ) VALUES (
        p_society_id,v_payment_id,v_receipt_no,coalesce(p_payment_date,now()),p_amount,p_user_id,p_user_id,now(),coalesce(p_remarks,'')
    ) RETURNING receipt_id INTO v_receipt_id;

    v_remaining := p_amount;
    FOR v_bill IN
        SELECT b.bill_id,b.total_amount,b.paid_amount
        FROM society_manager.t_bill b
        WHERE b.society_id=p_society_id AND b.flat_id=p_flat_id
          AND b.status NOT IN ('Paid','Cancelled','Void','Reversed')
          AND b.total_amount > b.paid_amount
        ORDER BY b.due_date NULLS LAST,b.bill_date,b.bill_id
        FOR UPDATE
    LOOP
        EXIT WHEN v_remaining <= 0;
        v_alloc := least(v_remaining, greatest(v_bill.total_amount-v_bill.paid_amount,0))::numeric(18,2);
        IF v_alloc > 0 THEN
            INSERT INTO society_manager.t_payment_allocation(
                society_id,payment_id,bill_id,allocated_amount,created_by,modify_by,modify_date,modify_remark,consumer_id
            ) VALUES (
                p_society_id,v_payment_id,v_bill.bill_id,v_alloc,p_user_id,p_user_id,now(),coalesce(p_remarks,''),p_customer_id
            );
            UPDATE society_manager.t_bill b
            SET paid_amount=b.paid_amount+v_alloc,
                status=CASE WHEN b.paid_amount+v_alloc >= b.total_amount THEN 'Paid' ELSE 'Partial' END,
                modify_by=p_user_id,modify_date=now(),modify_remark=coalesce(p_remarks,''),
                last_payment_amount=v_alloc,last_payment_date=coalesce(p_payment_date,now())
            WHERE b.society_id=p_society_id AND b.bill_id=v_bill.bill_id
              AND v_alloc <= greatest(b.total_amount-b.paid_amount,0);
            IF NOT FOUND THEN RAISE EXCEPTION 'Bill allocation conflict; payment was rolled back'; END IF;
            v_remaining := v_remaining-v_alloc;
        END IF;
    END LOOP;

    IF v_remaining <> 0 THEN
        RAISE EXCEPTION 'Payment allocation did not reconcile; payment was rolled back';
    END IF;
    RETURN v_payment_id;
END;
$function$;

COMMIT;
