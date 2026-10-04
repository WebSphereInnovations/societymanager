SET search_path TO society_manager, public;
DROP FUNCTION IF EXISTS sp_customer_service_history(bigint,bigint);
DROP FUNCTION IF EXISTS sp_customer_timeline(bigint,bigint);

CREATE OR REPLACE FUNCTION sp_customer_service_history(p_society_id bigint,p_consumer_id bigint)
RETURNS TABLE(
 service_history_id bigint,service_no varchar,performed_at timestamptz,service_type varchar,category varchar,
 description text,status varchar,assigned_to varchar,resolution text,closed_date timestamptz,remarks varchar,
 activity_type varchar,field_name varchar,old_value text,new_value text,changed_by varchar,changed_at timestamptz
)
LANGUAGE sql STABLE AS $$
SELECT h.service_history_id,h.reference_no,h.performed_at,h.event_type,h.event_sub_type,h.event_description,
       coalesce(h.event_data->>'status','Recorded'),coalesce(u.display_name,''),h.event_data->>'resolution',
       CASE WHEN h.event_data ? 'closedAt' THEN (h.event_data->>'closedAt')::timestamptz ELSE NULL END,
       h.modify_remark,'Service Activity',NULL,NULL,NULL,coalesce(u.display_name,''),h.performed_at
FROM t_service_history h
LEFT JOIN m_user u ON u.user_id=h.performed_by
WHERE h.society_id=p_society_id AND h.consumer_id=p_consumer_id
UNION ALL
SELECT ah.service_attribute_history_id,
       'ATTRIBUTE-'||ah.service_attribute_history_id,ah.changed_at,'Service Attribute',ah.attribute_name,
       ah.attribute_name||' updated', 'Updated',coalesce(u.display_name,''),NULL,NULL,ah.remarks,
       'Service Attribute Change',ah.attribute_name,ah.old_value,ah.new_value,coalesce(u.display_name,''),ah.changed_at
FROM t_customer_service_attribute_history ah
JOIN m_customer c ON c.society_id=ah.society_id AND c.customer_id=ah.customer_id AND c.consumer_id=p_consumer_id
LEFT JOIN m_user u ON u.user_id=ah.changed_by
WHERE ah.society_id=p_society_id
UNION ALL
SELECT al.audit_log_id,'AUDIT-'||al.audit_log_id,al.created_at,al.entity_name,'Account Change',
       al.action||' on '||al.entity_name,al.action,coalesce(u.display_name,''),NULL,NULL,NULL,
       'Account Audit',
       COALESCE(al.old_data->>'field',al.old_data->>'attribute',al.old_data->>'column'),
       COALESCE(al.old_data->>'value',al.old_data->>'old_value'),
       COALESCE(al.new_data->>'value',al.new_data->>'new_value'),
       coalesce(u.display_name,''),al.created_at
FROM t_audit_log al
JOIN m_customer c ON c.society_id=al.society_id AND c.customer_id=al.entity_id AND c.consumer_id=p_consumer_id
LEFT JOIN m_user u ON u.user_id=al.user_id
WHERE al.society_id=p_society_id
  AND lower(al.entity_name) IN ('customer','consumer','m_customer')
ORDER BY 3 DESC,1 DESC;
$$;

CREATE OR REPLACE FUNCTION sp_customer_timeline(p_society_id bigint,p_consumer_id bigint)
RETURNS TABLE(
 event_at timestamptz,event_type varchar,event_title varchar,event_description text,reference_no varchar,
 amount numeric,status varchar,field_name varchar,old_value text,new_value text,changed_by varchar
)
LANGUAGE sql STABLE AS $$
SELECT b.bill_date::timestamptz,'Billing','Bill Generated','Bill '||b.bill_no,b.bill_no,b.total_amount,b.status,
       NULL,NULL,NULL,NULL
FROM t_bill b WHERE b.society_id=p_society_id AND b.consumer_id=p_consumer_id
UNION ALL
SELECT p.payment_date,'Payment','Payment Received','Payment '||p.payment_no,coalesce(r.receipt_no,p.payment_no),p.amount,p.status,
       NULL,NULL,NULL,NULL
FROM t_payment p LEFT JOIN t_receipt r ON r.society_id=p.society_id AND r.payment_id=p.payment_id
WHERE p.society_id=p_society_id AND p.consumer_id=p_consumer_id
UNION ALL
SELECT c.created_at,'Complaint','Complaint Raised',c.title,c.complaint_no,NULL,c.status,NULL,NULL,NULL,NULL
FROM t_complaint c WHERE c.society_id=p_society_id AND c.consumer_id=p_consumer_id
UNION ALL
SELECT c.resolved_at,'Complaint','Complaint Resolved',c.title,c.complaint_no,NULL,'Resolved',NULL,NULL,NULL,NULL
FROM t_complaint c WHERE c.society_id=p_society_id AND c.consumer_id=p_consumer_id AND c.resolved_at IS NOT NULL
UNION ALL
SELECT h.performed_at,h.event_type,h.event_title,h.event_description,h.reference_no,NULL,
       coalesce(h.event_data->>'status','Recorded'),NULL,NULL,NULL,u.display_name
FROM t_service_history h LEFT JOIN m_user u ON u.user_id=h.performed_by
WHERE h.society_id=p_society_id AND h.consumer_id=p_consumer_id
UNION ALL
SELECT ah.changed_at,'Service Attribute','Service Attribute Updated',ah.attribute_name||' changed',
       'ATTRIBUTE-'||ah.service_attribute_history_id,NULL,'Updated',ah.attribute_name,ah.old_value,ah.new_value,u.display_name
FROM t_customer_service_attribute_history ah
JOIN m_customer c ON c.society_id=ah.society_id AND c.customer_id=ah.customer_id AND c.consumer_id=p_consumer_id
LEFT JOIN m_user u ON u.user_id=ah.changed_by
WHERE ah.society_id=p_society_id
UNION ALL
SELECT al.created_at,'Account Audit',al.action||' on '||al.entity_name,
       'Account data changed', 'AUDIT-'||al.audit_log_id,NULL,al.action,
       COALESCE(al.old_data->>'field',al.old_data->>'attribute',al.old_data->>'column'),
       COALESCE(al.old_data->>'value',al.old_data->>'old_value'),
       COALESCE(al.new_data->>'value',al.new_data->>'new_value'),u.display_name
FROM t_audit_log al JOIN m_customer c ON c.society_id=al.society_id AND c.customer_id=al.entity_id AND c.consumer_id=p_consumer_id
LEFT JOIN m_user u ON u.user_id=al.user_id
WHERE al.society_id=p_society_id AND lower(al.entity_name) IN ('customer','consumer','m_customer')
UNION ALL
SELECT a.created_at,'Adjustment','Adjustment Created',a.reason,b.bill_no,a.amount,a.status,NULL,NULL,NULL,u.display_name
FROM t_adjustment a LEFT JOIN t_bill b ON b.society_id=a.society_id AND b.bill_id=a.bill_id
LEFT JOIN m_user u ON u.user_id=a.approved_by
WHERE a.society_id=p_society_id AND a.consumer_id=p_consumer_id
UNION ALL
SELECT d.created_at,'Document','Document Uploaded',d.file_name,NULL,NULL,'Available',NULL,NULL,NULL,u.display_name
FROM t_document d LEFT JOIN m_user u ON u.user_id=d.uploaded_by
JOIN m_customer c ON c.society_id=d.society_id AND c.customer_id=d.customer_id AND c.consumer_id=p_consumer_id
WHERE d.society_id=p_society_id
UNION ALL
SELECT i.interaction_date,'Interaction',coalesce(i.subject,i.interaction_type),i.description,NULL,NULL,'Recorded',NULL,NULL,NULL,u.display_name
FROM t_customer_interaction i LEFT JOIN m_user u ON u.user_id=i.employee_user_id
JOIN m_customer c ON c.society_id=i.society_id AND c.consumer_id=i.consumer_id AND c.consumer_id=p_consumer_id
WHERE i.society_id=p_society_id
ORDER BY 1 DESC;
$$;

CREATE OR REPLACE FUNCTION sp_customer_bill_view(p_society_id bigint,p_consumer_id bigint,p_bill_id bigint)
RETURNS jsonb
LANGUAGE sql STABLE AS $$
SELECT CASE WHEN b.bill_id IS NULL THEN NULL ELSE jsonb_build_object(
 'bill',jsonb_build_object(
   'bill_id',b.bill_id,'bill_no',b.bill_no,'billing_period',b.bill_month,'bill_date',b.bill_date,'due_date',b.due_date,
   'subtotal',b.subtotal,'tax_amount',b.tax_amount,'rebate_amount',b.rebate_amount,'dpc_amount',b.dpc_amount,
   'total_amount',b.total_amount,'paid_amount',b.paid_amount,'remaining_due',greatest(b.total_amount-b.paid_amount,0),
   'status',b.status),
 'consumer',jsonb_build_object('consumer_id',c.consumer_id,'consumer_name',c.full_name,'account_no',c.customer_code,
   'phone',c.phone,'email',c.email,'flat_no',f.flat_no,'wing',w.wing_name,'address',s.address),
 'previous_outstanding',coalesce((SELECT sum(greatest(x.total_amount-x.paid_amount,0)) FROM t_bill x
    WHERE x.society_id=b.society_id AND x.consumer_id=b.consumer_id AND
          (x.bill_date<b.bill_date OR (x.bill_date=b.bill_date AND x.bill_id<b.bill_id))),0),
 'line_items',coalesce((SELECT jsonb_agg(to_jsonb(li) ORDER BY li.bill_line_item_id) FROM
    (SELECT li.bill_line_item_id,li.description,li.quantity,li.rate,li.amount FROM t_bill_line_item li
     WHERE li.society_id=b.society_id AND li.bill_id=b.bill_id) li),'[]'::jsonb)
) END
FROM t_bill b
JOIN m_customer c ON c.society_id=b.society_id AND c.consumer_id=p_consumer_id
JOIN m_flat f ON f.society_id=b.society_id AND f.flat_id=b.flat_id
LEFT JOIN m_wing w ON w.society_id=f.society_id AND w.wing_id=f.wing_id
JOIN m_society s ON s.society_id=b.society_id
WHERE b.society_id=p_society_id AND b.consumer_id=p_consumer_id AND b.bill_id=p_bill_id;
$$;

CREATE OR REPLACE FUNCTION sp_customer_receipt_view(p_society_id bigint,p_consumer_id bigint,p_payment_id bigint)
RETURNS jsonb
LANGUAGE sql STABLE AS $$
SELECT CASE WHEN p.payment_id IS NULL THEN NULL ELSE jsonb_build_object(
 'receipt',jsonb_build_object('receipt_no',r.receipt_no,'payment_no',p.payment_no,'payment_date',p.payment_date,'collected_by',u.display_name,
   'amount',p.amount,'payment_mode',p.payment_mode,'reference_no',p.reference_no,'status',p.status,'remarks',p.remarks,
   'previous_due',coalesce((SELECT sum(greatest(x.total_amount-x.paid_amount,0)) FROM t_bill x
      WHERE x.society_id=p.society_id AND x.consumer_id=p.consumer_id AND x.bill_date<=p.payment_date::date),0)+p.amount,
   'remaining_due',coalesce((SELECT sum(greatest(x.total_amount-x.paid_amount,0)) FROM t_bill x
      WHERE x.society_id=p.society_id AND x.consumer_id=p.consumer_id),0)),
 'consumer',jsonb_build_object('consumer_id',c.consumer_id,'consumer_name',c.full_name,'account_no',c.customer_code,
   'flat_no',f.flat_no,'wing',w.wing_name,'address',s.address),
 'related_bills',coalesce((SELECT jsonb_agg(jsonb_build_object('bill_no',b.bill_no,'billing_period',b.bill_month)
    ORDER BY b.bill_date) FROM t_payment_allocation pa JOIN t_bill b ON b.society_id=pa.society_id AND b.bill_id=pa.bill_id
    WHERE pa.society_id=p.society_id AND pa.payment_id=p.payment_id),'[]'::jsonb)
) END
FROM t_payment p
JOIN m_customer c ON c.society_id=p.society_id AND c.consumer_id=p_consumer_id
LEFT JOIN m_flat f ON f.society_id=p.society_id AND f.flat_id=p.flat_id
LEFT JOIN m_wing w ON w.society_id=f.society_id AND w.wing_id=f.wing_id
JOIN m_society s ON s.society_id=p.society_id
LEFT JOIN m_user u ON u.user_id=p.modified_by
LEFT JOIN t_receipt r ON r.society_id=p.society_id AND r.payment_id=p.payment_id
WHERE p.society_id=p_society_id AND p.consumer_id=p_consumer_id AND p.payment_id=p_payment_id;
$$;