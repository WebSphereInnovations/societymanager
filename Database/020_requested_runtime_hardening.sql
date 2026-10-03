-- Requested module hardening follow-up
ALTER TABLE society_manager.t_service_charge ADD COLUMN IF NOT EXISTS modify_by bigint REFERENCES society_manager.m_user(user_id);
ALTER TABLE society_manager.t_service_charge ADD COLUMN IF NOT EXISTS modify_date timestamptz NOT NULL DEFAULT now();
ALTER TABLE society_manager.t_service_charge ADD COLUMN IF NOT EXISTS modify_remark text DEFAULT '';
ALTER TABLE society_manager.t_customer_document ADD COLUMN IF NOT EXISTS modify_by bigint REFERENCES society_manager.m_user(user_id);
ALTER TABLE society_manager.t_customer_document ADD COLUMN IF NOT EXISTS modify_date timestamptz NOT NULL DEFAULT now();

DROP FUNCTION IF EXISTS society_manager.sp_accept_payment(bigint,bigint,bigint,numeric,varchar,varchar,text,bigint);
CREATE FUNCTION society_manager.sp_accept_payment(p_society_id bigint,p_customer_id bigint,p_flat_id bigint,p_amount numeric,p_payment_mode varchar,p_reference varchar,p_remarks text,p_payment_date timestamptz,p_user_id bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_payment bigint; v_no varchar; v_receipt varchar; v_receipt_id bigint;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM society_manager.m_customer WHERE customer_id=p_customer_id AND society_id=p_society_id AND is_active) THEN RAISE EXCEPTION 'Customer not found in selected society'; END IF;
 IF NOT EXISTS(SELECT 1 FROM society_manager.m_customer_flat WHERE customer_id=p_customer_id AND flat_id=p_flat_id AND society_id=p_society_id) THEN RAISE EXCEPTION 'Customer is not linked to selected flat'; END IF;
 IF NOT EXISTS(SELECT 1 FROM society_manager.m_flat WHERE flat_id=p_flat_id AND society_id=p_society_id AND is_active) THEN RAISE EXCEPTION 'Flat not found in selected society'; END IF;
 IF p_amount<=0 THEN RAISE EXCEPTION 'Payment amount must be greater than zero'; END IF;
 IF NOT EXISTS(SELECT 1 FROM society_manager.m_collection_payment_mode WHERE society_id=p_society_id AND payment_mode_code=p_payment_mode AND visible AND is_active) THEN RAISE EXCEPTION 'Payment mode is not available'; END IF;
 v_no='PAY-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS');
 INSERT INTO society_manager.t_payment(society_id,customer_id,flat_id,payment_no,payment_date,amount,payment_mode,reference_no,remarks,status,modify_by,modify_date,modify_remark)
 VALUES(p_society_id,p_customer_id,p_flat_id,v_no,coalesce(p_payment_date,now()),p_amount,p_payment_mode,p_reference,p_remarks,'Success',p_user_id,now(),coalesce(p_remarks,'')) RETURNING payment_id INTO v_payment;
 v_receipt='RCT-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS');
 INSERT INTO society_manager.t_receipt(society_id,payment_id,receipt_no,receipt_date,amount,modify_by,modify_date,modify_remark)
 VALUES(p_society_id,v_payment,v_receipt,coalesce(p_payment_date,now()),p_amount,p_user_id,now(),coalesce(p_remarks,'')) RETURNING receipt_id INTO v_receipt_id;
 UPDATE society_manager.t_bill b SET paid_amount=LEAST(b.total_amount,b.paid_amount+p_amount),status=CASE WHEN b.paid_amount+p_amount>=b.total_amount THEN 'Paid' ELSE 'Partial' END,modify_by=p_user_id,modify_date=now(),modify_remark=coalesce(p_remarks,'')
 WHERE b.society_id=p_society_id AND b.flat_id=p_flat_id AND b.status NOT IN('Paid','Cancelled') AND b.total_amount>b.paid_amount
 AND b.bill_id=(SELECT bill_id FROM society_manager.t_bill WHERE society_id=p_society_id AND flat_id=p_flat_id AND status NOT IN('Paid','Cancelled') AND total_amount>paid_amount ORDER BY due_date,bill_date LIMIT 1);
 RETURN v_payment;
END; $$;

DROP FUNCTION IF EXISTS society_manager.sp_save_service_charge(bigint,bigint,bigint,bigint,numeric,varchar,text,bigint);
CREATE FUNCTION society_manager.sp_save_service_charge(p_society_id bigint,p_customer_id bigint,p_flat_id bigint,p_type_id bigint,p_amount numeric,p_reference varchar,p_remarks text,p_charge_date timestamptz,p_user bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM society_manager.m_customer WHERE customer_id=p_customer_id AND society_id=p_society_id AND is_active) THEN RAISE EXCEPTION 'Customer not found in selected society'; END IF;
 IF p_flat_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM society_manager.m_customer_flat WHERE customer_id=p_customer_id AND flat_id=p_flat_id AND society_id=p_society_id) THEN RAISE EXCEPTION 'Customer is not linked to selected flat'; END IF;
 IF NOT EXISTS(SELECT 1 FROM society_manager.m_service_charge_type WHERE service_charge_type_id=p_type_id AND society_id=p_society_id AND is_active AND visible) THEN RAISE EXCEPTION 'Service charge type not found'; END IF;
 IF p_amount<=0 THEN RAISE EXCEPTION 'Service payment amount must be greater than zero'; END IF;
 INSERT INTO society_manager.t_service_charge(society_id,customer_id,flat_id,service_charge_type_id,amount,charge_date,reference_no,remarks,created_by,modify_by,modify_date,modify_remark)
 VALUES(p_society_id,p_customer_id,p_flat_id,p_type_id,p_amount,coalesce(p_charge_date,now()),p_reference,p_remarks,p_user,p_user,now(),coalesce(p_remarks,'')) RETURNING service_charge_id INTO v_id;
 RETURN v_id;
END; $$;

DROP FUNCTION IF EXISTS society_manager.sp_save_document(bigint,bigint,bigint,bigint,varchar,varchar,bigint,bytea,bigint);
CREATE FUNCTION society_manager.sp_save_document(p_society_id bigint,p_customer_id bigint,p_flat_id bigint,p_type_id bigint,p_file_name varchar,p_content_type varchar,p_file_size bigint,p_file_data bytea,p_user bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint; v_allowed text; v_ext text; v_ok boolean:=false;
BEGIN
 IF p_file_size<=0 OR p_file_size>10485760 THEN RAISE EXCEPTION 'Document size must be between 1 byte and 10 MB'; END IF;
 IF p_file_name IS NULL OR p_file_name='' OR p_file_name ~ '[\\/\x00-\x1F]' THEN RAISE EXCEPTION 'Invalid document file name'; END IF;
 IF NOT EXISTS(SELECT 1 FROM society_manager.m_customer WHERE customer_id=p_customer_id AND society_id=p_society_id AND is_active) THEN RAISE EXCEPTION 'Customer not found in selected society'; END IF;
 IF p_flat_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM society_manager.m_customer_flat WHERE customer_id=p_customer_id AND flat_id=p_flat_id AND society_id=p_society_id) THEN RAISE EXCEPTION 'Flat is not linked to selected customer'; END IF;
 SELECT lower(allowed_extensions) INTO v_allowed FROM society_manager.m_document_type WHERE document_type_id=p_type_id AND society_id=p_society_id AND is_active AND visible;
 IF v_allowed IS NULL THEN RAISE EXCEPTION 'Document type not found'; END IF;
 v_ext=lower(regexp_replace(p_file_name,'.*\\.',''));
 IF position(','||replace(v_allowed,' ','')||',' in ','||v_ext||',')=0 THEN RAISE EXCEPTION 'File extension is not allowed for selected document type'; END IF;
 IF v_ext='pdf' AND (get_byte(p_file_data,0),get_byte(p_file_data,1),get_byte(p_file_data,2),get_byte(p_file_data,3))=(37,80,68,70) THEN v_ok:=true;
 ELSIF v_ext IN('jpg','jpeg') AND get_byte(p_file_data,0)=255 AND get_byte(p_file_data,1)=216 AND get_byte(p_file_data,2)=255 THEN v_ok:=true;
 ELSIF v_ext='png' AND substring(p_file_data from 1 for 8)=decode('89504E470D0A1A0A','hex') THEN v_ok:=true;
 END IF;
 IF NOT v_ok THEN RAISE EXCEPTION 'File content does not match the allowed image/PDF type'; END IF;
 INSERT INTO society_manager.t_customer_document(society_id,customer_id,flat_id,document_type_id,file_name,content_type,file_size,file_data,uploaded_by,modify_by,modify_date,modify_remark)
 VALUES(p_society_id,p_customer_id,p_flat_id,p_type_id,left(p_file_name,255),left(p_content_type,120),p_file_size,p_file_data,p_user,p_user,now(),'Document uploaded') RETURNING document_id INTO v_id;
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION society_manager.fn_document_content(p_society_id bigint,p_document_id bigint)
RETURNS TABLE(file_name varchar,content_type varchar,file_data bytea)
LANGUAGE sql AS $$
SELECT d.file_name,d.content_type,d.file_data
FROM society_manager.t_customer_document d
JOIN society_manager.m_document_type dt ON dt.document_type_id=d.document_type_id AND dt.society_id=p_society_id AND dt.is_active AND dt.visible
WHERE d.society_id=p_society_id AND d.document_id=p_document_id AND d.is_active AND d.visible;
$$;
