SET search_path TO society_manager, public;

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
       ah.attribute_name||' updated','Updated',coalesce(u.display_name,''),NULL,NULL,ah.remarks,
       'Service Attribute Change',ah.attribute_name,ah.old_value,ah.new_value,coalesce(u.display_name,''),ah.changed_at
FROM t_customer_service_attribute_history ah
JOIN m_customer c ON c.society_id=ah.society_id AND c.customer_id=ah.customer_id AND c.consumer_id=p_consumer_id
LEFT JOIN m_user u ON u.user_id=ah.changed_by
WHERE ah.society_id=p_society_id

UNION ALL

SELECT (al.audit_log_id * 1000 + row_number() OVER (PARTITION BY al.audit_log_id ORDER BY k.key))::bigint,
       'AUDIT-'||al.audit_log_id||'-'||k.key,al.created_at,al.entity_name,k.key,
       al.action||' on '||al.entity_name,al.action,coalesce(u.display_name,''),NULL,NULL,NULL,
       'Account Audit',k.key,al.old_data->>k.key,al.new_data->>k.key,coalesce(u.display_name,''),al.created_at
FROM t_audit_log al
CROSS JOIN LATERAL jsonb_object_keys(coalesce(al.old_data,'{}'::jsonb) || coalesce(al.new_data,'{}'::jsonb)) k(key)
LEFT JOIN m_user u ON u.user_id=al.user_id
WHERE al.society_id=p_society_id
  AND (al.old_data->>'consumer_id'=p_consumer_id::text OR al.new_data->>'consumer_id'=p_consumer_id::text)
  AND coalesce(al.old_data->>k.key,'') IS DISTINCT FROM coalesce(al.new_data->>k.key,'')
  AND k.key NOT IN ('society_id','created_at','created_by','modified_at','modified_by','modify_date','modify_by','modify_remark')
ORDER BY 3 DESC,1 DESC;
$$;

CREATE OR REPLACE FUNCTION sp_customer_timeline(p_society_id bigint,p_consumer_id bigint)
RETURNS TABLE(
 event_at timestamptz,event_type varchar,event_title varchar,event_description text,reference_no varchar,
 amount numeric,status varchar,field_name varchar,old_value text,new_value text,changed_by varchar
)
LANGUAGE sql STABLE AS $$
SELECT b.bill_date::timestamptz,'Billing','Bill Generated','Bill '||b.bill_no,b.bill_no,b.total_amount,b.status,NULL,NULL,NULL,NULL
FROM t_bill b WHERE b.society_id=p_society_id AND b.consumer_id=p_consumer_id

UNION ALL

SELECT p.payment_date,'Payment','Payment Received','Payment '||p.payment_no,coalesce(r.receipt_no,p.payment_no),p.amount,p.status,NULL,NULL,NULL,NULL
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
       'Account data changed on '||al.entity_name,'AUDIT-'||al.audit_log_id,NULL,al.action,
       k.key,al.old_data->>k.key,al.new_data->>k.key,u.display_name
FROM t_audit_log al
CROSS JOIN LATERAL jsonb_object_keys(coalesce(al.old_data,'{}'::jsonb) || coalesce(al.new_data,'{}'::jsonb)) k(key)
LEFT JOIN m_user u ON u.user_id=al.user_id
WHERE al.society_id=p_society_id
  AND (al.old_data->>'consumer_id'=p_consumer_id::text OR al.new_data->>'consumer_id'=p_consumer_id::text)
  AND coalesce(al.old_data->>k.key,'') IS DISTINCT FROM coalesce(al.new_data->>k.key,'')
  AND k.key NOT IN ('society_id','created_at','created_by','modified_at','modified_by','modify_date','modify_by','modify_remark')

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
