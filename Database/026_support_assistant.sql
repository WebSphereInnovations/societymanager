SET search_path TO society_manager, public;

CREATE TABLE IF NOT EXISTS m_support_faq (
 faq_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NULL REFERENCES m_society(society_id) ON DELETE CASCADE,
 faq_code varchar(80) NOT NULL,
 question_en text NOT NULL,
 answer_en text NOT NULL,
 question_hi text, answer_hi text,
 question_mr text, answer_mr text,
 question_gu text, answer_gu text,
 question_kn text, answer_kn text,
 question_ta text, answer_ta text,
 keywords_en text, keywords_hi text, keywords_mr text, keywords_gu text, keywords_kn text, keywords_ta text,
 display_order integer NOT NULL DEFAULT 100,
 is_active boolean NOT NULL DEFAULT true,
 created_at timestamptz NOT NULL DEFAULT now(),
 modified_by bigint NULL REFERENCES m_user(user_id),
 modified_at timestamptz NOT NULL DEFAULT now(),
 modify_remark varchar(500) NOT NULL DEFAULT '',
 UNIQUE(society_id,faq_code)
);

CREATE INDEX IF NOT EXISTS ix_support_faq_scope ON m_support_faq(society_id,is_active,display_order);

CREATE OR REPLACE FUNCTION fn_support_faq(p_society_id bigint,p_language varchar DEFAULT 'en',p_query varchar DEFAULT '')
RETURNS TABLE(faq_id bigint,faq_code varchar,question text,answer text,display_order integer)
LANGUAGE sql AS $$
SELECT f.faq_id,f.faq_code,
 CASE lower(coalesce(p_language,'en')) WHEN 'hi' THEN coalesce(f.question_hi,f.question_en) WHEN 'mr' THEN coalesce(f.question_mr,f.question_en) WHEN 'gu' THEN coalesce(f.question_gu,f.question_en) WHEN 'kn' THEN coalesce(f.question_kn,f.question_en) WHEN 'ta' THEN coalesce(f.question_ta,f.question_en) ELSE f.question_en END,
 CASE lower(coalesce(p_language,'en')) WHEN 'hi' THEN coalesce(f.answer_hi,f.answer_en) WHEN 'mr' THEN coalesce(f.answer_mr,f.answer_en) WHEN 'gu' THEN coalesce(f.answer_gu,f.answer_en) WHEN 'kn' THEN coalesce(f.answer_kn,f.answer_en) WHEN 'ta' THEN coalesce(f.answer_ta,f.answer_en) ELSE f.answer_en END,
 f.display_order
FROM m_support_faq f
WHERE f.is_active AND (f.society_id IS NULL OR f.society_id=p_society_id)
AND (coalesce(trim(p_query),'')='' OR f.question_en ILIKE '%'||p_query||'%' OR f.answer_en ILIKE '%'||p_query||'%' OR coalesce(f.keywords_en,'') ILIKE '%'||p_query||'%')
ORDER BY f.society_id NULLS FIRST,f.display_order,f.faq_id LIMIT 12;
$$;

CREATE OR REPLACE PROCEDURE sp_support_faq_save(IN p_faq_id bigint,IN p_society_id bigint,IN p_faq_code varchar,IN p_question_en text,IN p_answer_en text,IN p_modified_by bigint DEFAULT NULL,IN p_remark varchar DEFAULT '')
LANGUAGE plpgsql AS $$
BEGIN
 IF p_faq_id IS NULL OR p_faq_id=0 THEN
  INSERT INTO m_support_faq(society_id,faq_code,question_en,answer_en,modified_by,modify_remark)
  VALUES(p_society_id,p_faq_code,p_question_en,p_answer_en,p_modified_by,coalesce(p_remark,''));
 ELSE
  UPDATE m_support_faq SET society_id=p_society_id,faq_code=p_faq_code,question_en=p_question_en,answer_en=p_answer_en,modified_by=p_modified_by,modified_at=now(),modify_remark=coalesce(p_remark,'') WHERE faq_id=p_faq_id;
 END IF;
END $$;

INSERT INTO m_support_faq(society_id,faq_code,question_en,answer_en,keywords_en,display_order)
SELECT NULL,'PAYMENT','How do I make a payment?','Open Collection or My Billing, select the bill, choose an available payment method and complete the payment.','payment,pay,bill,receipt',10
WHERE NOT EXISTS(SELECT 1 FROM m_support_faq WHERE society_id IS NULL AND faq_code='PAYMENT');
INSERT INTO m_support_faq(society_id,faq_code,question_en,answer_en,keywords_en,display_order)
SELECT NULL,'VISITOR','How do I add a visitor?','Use Visitor Management to create a pre-approved visitor invite. Security verifies the visitor at the gate and records entry and exit.','visitor,invite,guest',20
WHERE NOT EXISTS(SELECT 1 FROM m_support_faq WHERE society_id IS NULL AND faq_code='VISITOR');
INSERT INTO m_support_faq(society_id,faq_code,question_en,answer_en,keywords_en,display_order)
SELECT NULL,'COMPLAINT','How do I raise a complaint?','Open Complaints or the Customer Portal, enter the category and issue details, then submit. Track the complaint number and status from history.','complaint,issue,service',30
WHERE NOT EXISTS(SELECT 1 FROM m_support_faq WHERE society_id IS NULL AND faq_code='COMPLAINT');
INSERT INTO m_support_faq(society_id,faq_code,question_en,answer_en,keywords_en,display_order)
SELECT NULL,'DUES','How do I check my dues?','Open My Billing or Customer 360. The bill list shows billed amount, paid amount, balance and due date.','dues,outstanding,balance,arrears',40
WHERE NOT EXISTS(SELECT 1 FROM m_support_faq WHERE society_id IS NULL AND faq_code='DUES');
INSERT INTO m_support_faq(society_id,faq_code,question_en,answer_en,keywords_en,display_order)
SELECT NULL,'RECEIPT','How do I download a receipt?','Open Collection or Payment History, select the payment and open its receipt/details.','receipt,download,payment history',50
WHERE NOT EXISTS(SELECT 1 FROM m_support_faq WHERE society_id IS NULL AND faq_code='RECEIPT');
INSERT INTO m_support_faq(society_id,faq_code,question_en,answer_en,keywords_en,display_order)
SELECT NULL,'CUSTOMER','How do I add a customer?','Authorized society staff can open CRM or Residents and use the customer creation workflow. The record is stored against the selected society.','customer,resident,owner,tenant',60
WHERE NOT EXISTS(SELECT 1 FROM m_support_faq WHERE society_id IS NULL AND faq_code='CUSTOMER');