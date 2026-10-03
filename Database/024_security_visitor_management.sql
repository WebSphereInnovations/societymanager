SET search_path TO society_manager, public;

ALTER TABLE t_notification ADD COLUMN IF NOT EXISTS recipient_user_id bigint REFERENCES m_user(user_id);
ALTER TABLE t_notification ADD COLUMN IF NOT EXISTS notification_type varchar(60);
ALTER TABLE t_notification ADD COLUMN IF NOT EXISTS title varchar(180);
ALTER TABLE t_notification ADD COLUMN IF NOT EXISTS reference_entity varchar(80);
ALTER TABLE t_notification ADD COLUMN IF NOT EXISTS reference_id bigint;
ALTER TABLE t_notification ADD COLUMN IF NOT EXISTS is_read boolean NOT NULL DEFAULT false;
ALTER TABLE t_notification ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE TABLE IF NOT EXISTS m_security_master(
 security_master_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 master_group varchar(50) NOT NULL,
 master_code varchar(60) NOT NULL,
 master_name varchar(150) NOT NULL,
 visible boolean NOT NULL DEFAULT true,
 is_active boolean NOT NULL DEFAULT true,
 created_by bigint REFERENCES m_user(user_id),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_by bigint REFERENCES m_user(user_id),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(society_id,master_group,master_code)
);

CREATE TABLE IF NOT EXISTS m_security_guard(
 guard_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 guard_code varchar(50) NOT NULL,
 guard_name varchar(150) NOT NULL,
 mobile varchar(30),
 government_id varchar(80),
 agency_name varchar(150),
 guard_type varchar(60),
 joining_date date,
 shift_notes varchar(200),
 is_active boolean NOT NULL DEFAULT true,
 created_by bigint REFERENCES m_user(user_id),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_by bigint REFERENCES m_user(user_id),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(society_id,guard_code)
);

CREATE TABLE IF NOT EXISTS m_security_shift(
 shift_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 shift_code varchar(50) NOT NULL,
 shift_name varchar(100) NOT NULL,
 shift_type varchar(60) NOT NULL,
 start_time time NOT NULL,
 end_time time NOT NULL,
 visible boolean NOT NULL DEFAULT true,
 is_active boolean NOT NULL DEFAULT true,
 created_by bigint REFERENCES m_user(user_id),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_by bigint REFERENCES m_user(user_id),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(society_id,shift_code)
);

CREATE TABLE IF NOT EXISTS t_security_roster(
 roster_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 guard_id bigint NOT NULL REFERENCES m_security_guard(guard_id),
 shift_id bigint NOT NULL REFERENCES m_security_shift(shift_id),
 roster_date date NOT NULL,
 attendance_status varchar(40) NOT NULL DEFAULT 'Scheduled',
 check_in timestamptz,
 check_out timestamptz,
 remarks text,
 created_by bigint REFERENCES m_user(user_id),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_by bigint REFERENCES m_user(user_id),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(society_id,guard_id,roster_date)
);

CREATE TABLE IF NOT EXISTS m_security_gate(
 gate_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 gate_code varchar(50) NOT NULL,
 gate_name varchar(120) NOT NULL,
 gate_type varchar(60) NOT NULL,
 assigned_guard_id bigint REFERENCES m_security_guard(guard_id),
 visible boolean NOT NULL DEFAULT true,
 is_active boolean NOT NULL DEFAULT true,
 created_by bigint REFERENCES m_user(user_id),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_by bigint REFERENCES m_user(user_id),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(society_id,gate_code)
);

ALTER TABLE t_visitor_entry ADD COLUMN IF NOT EXISTS customer_id bigint REFERENCES m_customer(customer_id);
ALTER TABLE t_visitor_entry ADD COLUMN IF NOT EXISTS gate_id bigint REFERENCES m_security_gate(gate_id);
ALTER TABLE t_visitor_entry ADD COLUMN IF NOT EXISTS guard_id bigint REFERENCES m_security_guard(guard_id);
ALTER TABLE t_visitor_entry ADD COLUMN IF NOT EXISTS id_type varchar(60);
ALTER TABLE t_visitor_entry ADD COLUMN IF NOT EXISTS id_number varchar(100);
ALTER TABLE t_visitor_entry ADD COLUMN IF NOT EXISTS photo_data bytea;
ALTER TABLE t_visitor_entry ADD COLUMN IF NOT EXISTS photo_content_type varchar(80);
ALTER TABLE t_visitor_entry ADD COLUMN IF NOT EXISTS vehicle_type varchar(50);
ALTER TABLE t_visitor_entry ADD COLUMN IF NOT EXISTS approval_status varchar(40) NOT NULL DEFAULT 'Verified';
ALTER TABLE t_visitor_entry ADD COLUMN IF NOT EXISTS visitor_source varchar(40) NOT NULL DEFAULT 'WalkIn';
ALTER TABLE t_visitor_entry ADD COLUMN IF NOT EXISTS expected_at timestamptz;
ALTER TABLE t_visitor_entry ADD COLUMN IF NOT EXISTS updated_by bigint REFERENCES m_user(user_id);
ALTER TABLE t_visitor_entry ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE t_visitor_entry ADD COLUMN IF NOT EXISTS created_by bigint REFERENCES m_user(user_id);

CREATE TABLE IF NOT EXISTS t_visitor_invitation(
 invitation_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 customer_id bigint NOT NULL REFERENCES m_customer(customer_id),
 flat_id bigint NOT NULL REFERENCES m_flat(flat_id),
 visitor_name varchar(150) NOT NULL,
 mobile varchar(30),
 purpose varchar(150),
 visitor_type varchar(60) NOT NULL,
 expected_date date NOT NULL,
 expected_time time,
 vehicle_no varchar(30),
 vehicle_type varchar(50),
 approval_status varchar(40) NOT NULL DEFAULT 'Pending',
 pass_code varchar(80),
 approved_by bigint REFERENCES m_user(user_id),
 approved_at timestamptz,
 created_by bigint REFERENCES m_user(user_id),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_by bigint REFERENCES m_user(user_id),
 updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS t_security_incident(
 incident_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 incident_no varchar(70) NOT NULL,
 incident_type varchar(60) NOT NULL,
 gate_id bigint REFERENCES m_security_gate(gate_id),
 flat_id bigint REFERENCES m_flat(flat_id),
 visitor_entry_id bigint REFERENCES t_visitor_entry(visitor_entry_id),
 vehicle_no varchar(30),
 occurred_at timestamptz NOT NULL,
 location varchar(180),
 description text NOT NULL,
 attachment_name varchar(255),
 attachment_content_type varchar(80),
 attachment_data bytea,
 status varchar(40) NOT NULL DEFAULT 'Open',
 created_by bigint REFERENCES m_user(user_id),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_by bigint REFERENCES m_user(user_id),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(society_id,incident_no)
);

CREATE TABLE IF NOT EXISTS t_security_incident_history(
 history_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 incident_id bigint NOT NULL REFERENCES t_security_incident(incident_id) ON DELETE CASCADE,
 old_status varchar(40),
 new_status varchar(40) NOT NULL,
 remarks text,
 changed_by bigint REFERENCES m_user(user_id),
 changed_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS t_visitor_blacklist(
 blacklist_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 visitor_name varchar(150),
 mobile varchar(30),
 vehicle_no varchar(30),
 reason text NOT NULL,
 start_date date,
 end_date date,
 is_active boolean NOT NULL DEFAULT true,
 created_by bigint REFERENCES m_user(user_id),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_by bigint REFERENCES m_user(user_id),
 updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_sec_guard_society ON m_security_guard(society_id,is_active);
CREATE INDEX IF NOT EXISTS ix_sec_roster_society_date ON t_security_roster(society_id,roster_date);
CREATE INDEX IF NOT EXISTS ix_sec_gate_society ON m_security_gate(society_id,is_active);
CREATE INDEX IF NOT EXISTS ix_sec_incident_society_date ON t_security_incident(society_id,occurred_at);
CREATE INDEX IF NOT EXISTS ix_visitor_society_entry ON t_visitor_entry(society_id,entry_at);
CREATE INDEX IF NOT EXISTS ix_visitor_society_active ON t_visitor_entry(society_id,status,entry_at);
CREATE INDEX IF NOT EXISTS ix_invitation_society_date ON t_visitor_invitation(society_id,expected_date,approval_status);
CREATE INDEX IF NOT EXISTS ix_blacklist_society_active ON t_visitor_blacklist(society_id,is_active);

INSERT INTO m_security_master(society_id,master_group,master_code,master_name)
SELECT s.society_id,x.grp,x.code,x.name FROM m_society s CROSS JOIN
(VALUES
('VISITOR_TYPE','GUEST','Guest'),('VISITOR_TYPE','DELIVERY','Delivery'),('VISITOR_TYPE','MAID','Maid'),
('VISITOR_TYPE','DRIVER','Driver'),('VISITOR_TYPE','ELECTRICIAN','Electrician'),('VISITOR_TYPE','PLUMBER','Plumber'),
('VISITOR_TYPE','TECHNICIAN','Technician'),('VISITOR_TYPE','SERVICE_PROVIDER','Service Provider'),
('VISITOR_TYPE','OTHER','Other'),('PURPOSE','PERSONAL','Personal Visit'),('PURPOSE','DELIVERY','Delivery'),
('PURPOSE','SERVICE','Service'),('PURPOSE','OFFICIAL','Official'),('PURPOSE','OTHER','Other'),
('INCIDENT_TYPE','UNAUTHORIZED_ENTRY','Unauthorized Entry'),('INCIDENT_TYPE','SECURITY_BREACH','Security Breach'),
('INCIDENT_TYPE','PROPERTY_DAMAGE','Property Damage'),('INCIDENT_TYPE','VEHICLE_ISSUE','Vehicle Issue'),('INCIDENT_TYPE','OTHER','Other'),
('GUARD_TYPE','IN_HOUSE','In-house'),('GUARD_TYPE','AGENCY','Agency'),
('SHIFT_TYPE','MORNING','Morning'),('SHIFT_TYPE','EVENING','Evening'),('SHIFT_TYPE','NIGHT','Night'),('SHIFT_TYPE','CUSTOM','Custom'),
('GATE_TYPE','MAIN','Main Gate'),('GATE_TYPE','SERVICE','Service Gate'),('GATE_TYPE','PARKING','Parking Gate'),('GATE_TYPE','OTHER','Other'),
('VEHICLE_TYPE','CAR','Car'),('VEHICLE_TYPE','BIKE','Bike'),('VEHICLE_TYPE','SCOOTER','Scooter'),('VEHICLE_TYPE','AUTO','Auto'),('VEHICLE_TYPE','OTHER','Other'),
('ID_TYPE','AADHAAR','Aadhaar'),('ID_TYPE','PAN','PAN'),('ID_TYPE','DRIVING_LICENSE','Driving License'),('ID_TYPE','OTHER','Other'),
('VISITOR_STATUS','PENDING','Pending'),('VISITOR_STATUS','APPROVED','Approved'),('VISITOR_STATUS','VERIFIED','Verified'),('VISITOR_STATUS','REJECTED','Rejected'),
('INCIDENT_STATUS','OPEN','Open'),('INCIDENT_STATUS','IN_PROCESS','In Process'),('INCIDENT_STATUS','RESOLVED','Resolved'),('INCIDENT_STATUS','CLOSED','Closed')
) x(grp,code,name)
ON CONFLICT(society_id,master_group,master_code) DO NOTHING;

INSERT INTO m_security_shift(society_id,shift_code,shift_name,shift_type,start_time,end_time)
SELECT s.society_id,x.code,x.name,x.type,x.start_time::time,x.end_time::time FROM m_society s CROSS JOIN
(VALUES('MORNING','Morning Shift','Morning','06:00','14:00'),('EVENING','Evening Shift','Evening','14:00','22:00'),('NIGHT','Night Shift','Night','22:00','06:00')) x(code,name,type,start_time,end_time)
ON CONFLICT(society_id,shift_code) DO NOTHING;

INSERT INTO m_module(module_code,module_name,parent_module_code,display_order,visible,is_active) VALUES
('SECURITY_VISITOR','Security & Visitor Management',NULL,150,true,true),
('SEC_DASHBOARD','Security Dashboard','SECURITY_VISITOR',151,true,true),
('SEC_GUARDS','Guard Management','SECURITY_VISITOR',152,true,true),
('SEC_ROSTER','Shift / Roster Management','SECURITY_VISITOR',153,true,true),
('SEC_GATES','Gate Management','SECURITY_VISITOR',154,true,true),
('SEC_INCIDENTS','Security Incident Management','SECURITY_VISITOR',155,true,true),
('SEC_REPORTS','Security Reports','SECURITY_VISITOR',156,true,true),
('VIS_DASHBOARD','Visitor Dashboard','SECURITY_VISITOR',157,true,true),
('VIS_PREAPPROVAL','Pre-Approved Visitor','SECURITY_VISITOR',158,true,true),
('VIS_WALKIN','Walk-in Visitor','SECURITY_VISITOR',159,true,true),
('VIS_ENTRY_EXIT','Visitor Entry / Exit','SECURITY_VISITOR',160,true,true),
('VIS_SERVICE','Delivery / Service Provider','SECURITY_VISITOR',161,true,true),
('VIS_VEHICLE','Vehicle Management','SECURITY_VISITOR',162,true,true),
('VIS_HISTORY','Visitor History','SECURITY_VISITOR',163,true,true),
('VIS_BLACKLIST','Blacklist / Restricted Visitor','SECURITY_VISITOR',164,true,true)
ON CONFLICT(module_code) DO UPDATE SET module_name=excluded.module_name,parent_module_code=excluded.parent_module_code,display_order=excluded.display_order,visible=true,is_active=true;

INSERT INTO m_permission(module_code,action_code,permission_name,is_active,visible)
SELECT m.module_code,a.code,m.module_name||' - '||a.code,true,true
FROM m_module m CROSS JOIN (VALUES('VIEW'),('ADD'),('EDIT'),('DELETE'),('APPROVE'),('ASSIGN'),('EXPORT')) a(code)
WHERE m.module_code IN ('SEC_DASHBOARD','SEC_GUARDS','SEC_ROSTER','SEC_GATES','SEC_INCIDENTS','SEC_REPORTS','VIS_DASHBOARD','VIS_PREAPPROVAL','VIS_WALKIN','VIS_ENTRY_EXIT','VIS_SERVICE','VIS_VEHICLE','VIS_HISTORY','VIS_BLACKLIST')
ON CONFLICT(module_code,action_code) DO UPDATE SET is_active=true,visible=true;

INSERT INTO m_role_permission(role_id,permission_id)
SELECT r.role_id,p.permission_id FROM m_role r JOIN m_permission p ON p.module_code IN
('SEC_DASHBOARD','SEC_GUARDS','SEC_ROSTER','SEC_GATES','SEC_INCIDENTS','SEC_REPORTS','VIS_DASHBOARD','VIS_PREAPPROVAL','VIS_WALKIN','VIS_ENTRY_EXIT','VIS_SERVICE','VIS_VEHICLE','VIS_HISTORY','VIS_BLACKLIST')
WHERE r.role_code IN ('SUPER_ADMIN','SOCIETY_ADMIN','SECURITY') AND p.is_active
ON CONFLICT DO NOTHING;

INSERT INTO m_role_permission(role_id,permission_id)
SELECT r.role_id,p.permission_id FROM m_role r JOIN m_permission p ON p.module_code IN ('VIS_DASHBOARD','VIS_PREAPPROVAL','VIS_HISTORY')
WHERE r.role_code='RESIDENT' AND p.is_active ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION fn_security_master(p_society_id bigint,p_group varchar)
RETURNS TABLE(code varchar,name varchar)
LANGUAGE sql AS $$ SELECT master_code,master_name FROM m_security_master WHERE society_id=p_society_id AND master_group=p_group AND visible AND is_active ORDER BY master_name; $$;

CREATE OR REPLACE FUNCTION fn_security_guards(p_society_id bigint,p_q varchar)
RETURNS TABLE(guard_id bigint,guard_code varchar,guard_name varchar,mobile varchar,government_id varchar,agency_name varchar,guard_type varchar,joining_date date,is_active boolean)
LANGUAGE sql AS $$ SELECT guard_id,guard_code,guard_name,mobile,government_id,agency_name,guard_type,joining_date,is_active FROM m_security_guard WHERE society_id=p_society_id AND (coalesce(p_q,'')='' OR guard_name ILIKE '%'||p_q||'%' OR mobile ILIKE '%'||p_q||'%' OR guard_code ILIKE '%'||p_q||'%') ORDER BY guard_name; $$;

CREATE OR REPLACE FUNCTION fn_security_shifts(p_society_id bigint)
RETURNS TABLE(shift_id bigint,shift_code varchar,shift_name varchar,shift_type varchar,start_time time,end_time time,is_active boolean)
LANGUAGE sql AS $$ SELECT shift_id,shift_code,shift_name,shift_type,start_time,end_time,is_active FROM m_security_shift WHERE society_id=p_society_id ORDER BY start_time; $$;

CREATE OR REPLACE FUNCTION fn_security_gates(p_society_id bigint,p_q varchar)
RETURNS TABLE(gate_id bigint,gate_code varchar,gate_name varchar,gate_type varchar,assigned_guard_id bigint,assigned_guard varchar,is_active boolean)
LANGUAGE sql AS $$ SELECT g.gate_id,g.gate_code,g.gate_name,g.gate_type,g.assigned_guard_id,gd.guard_name,g.is_active FROM m_security_gate g LEFT JOIN m_security_guard gd ON gd.guard_id=g.assigned_guard_id AND gd.society_id=p_society_id WHERE g.society_id=p_society_id AND (coalesce(p_q,'')='' OR g.gate_name ILIKE '%'||p_q||'%' OR g.gate_code ILIKE '%'||p_q||'%') ORDER BY g.gate_name; $$;

CREATE OR REPLACE FUNCTION fn_security_roster(p_society_id bigint,p_from date,p_to date)
RETURNS TABLE(roster_id bigint,roster_date date,guard_id bigint,guard_name varchar,shift_id bigint,shift_name varchar,attendance_status varchar,check_in timestamptz,check_out timestamptz,remarks text)
LANGUAGE sql AS $$ SELECT r.roster_id,r.roster_date,r.guard_id,g.guard_name,r.shift_id,s.shift_name,r.attendance_status,r.check_in,r.check_out,r.remarks FROM t_security_roster r JOIN m_security_guard g ON g.guard_id=r.guard_id AND g.society_id=p_society_id JOIN m_security_shift s ON s.shift_id=r.shift_id AND s.society_id=p_society_id WHERE r.society_id=p_society_id AND r.roster_date BETWEEN p_from AND p_to ORDER BY r.roster_date DESC,g.guard_name; $$;

CREATE OR REPLACE FUNCTION fn_security_incidents(p_society_id bigint,p_q varchar,p_status varchar)
RETURNS TABLE(incident_id bigint,incident_no varchar,incident_type varchar,gate_name varchar,location varchar,occurred_at timestamptz,vehicle_no varchar,description text,status varchar,attachment_name varchar)
LANGUAGE sql AS $$ SELECT i.incident_id,i.incident_no,i.incident_type,g.gate_name,i.location,i.occurred_at,i.vehicle_no,i.description,i.status,i.attachment_name FROM t_security_incident i LEFT JOIN m_security_gate g ON g.gate_id=i.gate_id AND g.society_id=p_society_id WHERE i.society_id=p_society_id AND (coalesce(p_q,'')='' OR i.incident_no ILIKE '%'||p_q||'%' OR i.description ILIKE '%'||p_q||'%' OR i.vehicle_no ILIKE '%'||p_q||'%') AND (coalesce(p_status,'')='' OR i.status=p_status) ORDER BY i.occurred_at DESC; $$;

CREATE OR REPLACE FUNCTION fn_visitor_entries(p_society_id bigint,p_q varchar,p_inside_only boolean)
RETURNS TABLE(visitor_entry_id bigint,visitor_name varchar,phone varchar,flat_no varchar,customer_name varchar,visitor_type varchar,purpose varchar,vehicle_no varchar,vehicle_type varchar,gate_name varchar,guard_name varchar,entry_at timestamptz,exit_at timestamptz,status varchar,approval_status varchar,visitor_source varchar)
LANGUAGE sql AS $$ SELECT v.visitor_entry_id,v.visitor_name,v.phone,f.flat_no,c.full_name,v.visitor_type,v.purpose,v.vehicle_no,v.vehicle_type,g.gate_name,gd.guard_name,v.entry_at,v.exit_at,v.status,v.approval_status,v.visitor_source FROM t_visitor_entry v LEFT JOIN m_flat f ON f.flat_id=v.flat_id AND f.society_id=p_society_id LEFT JOIN m_customer c ON c.customer_id=v.customer_id AND c.society_id=p_society_id LEFT JOIN m_security_gate g ON g.gate_id=v.gate_id AND g.society_id=p_society_id LEFT JOIN m_security_guard gd ON gd.guard_id=v.guard_id AND gd.society_id=p_society_id WHERE v.society_id=p_society_id AND (coalesce(p_q,'')='' OR v.visitor_name ILIKE '%'||p_q||'%' OR v.phone ILIKE '%'||p_q||'%' OR f.flat_no ILIKE '%'||p_q||'%' OR v.vehicle_no ILIKE '%'||p_q||'%') AND (NOT p_inside_only OR v.status='Inside') ORDER BY v.entry_at DESC; $$;

CREATE OR REPLACE FUNCTION fn_visitor_invitations(p_society_id bigint,p_customer_id bigint)
RETURNS TABLE(invitation_id bigint,visitor_name varchar,mobile varchar,flat_no varchar,purpose varchar,visitor_type varchar,expected_date date,expected_time time,vehicle_no varchar,vehicle_type varchar,approval_status varchar,pass_code varchar,created_at timestamptz)
LANGUAGE sql AS $$ SELECT i.invitation_id,i.visitor_name,i.mobile,f.flat_no,i.purpose,i.visitor_type,i.expected_date,i.expected_time,i.vehicle_no,i.vehicle_type,i.approval_status,i.pass_code,i.created_at FROM t_visitor_invitation i JOIN m_flat f ON f.flat_id=i.flat_id AND f.society_id=p_society_id WHERE i.society_id=p_society_id AND (p_customer_id=0 OR i.customer_id=p_customer_id) ORDER BY i.created_at DESC; $$;

CREATE OR REPLACE FUNCTION fn_visitor_blacklist(p_society_id bigint)
RETURNS TABLE(blacklist_id bigint,visitor_name varchar,mobile varchar,vehicle_no varchar,reason text,start_date date,end_date date,is_active boolean)
LANGUAGE sql AS $$ SELECT blacklist_id,visitor_name,mobile,vehicle_no,reason,start_date,end_date,is_active FROM t_visitor_blacklist WHERE society_id=p_society_id ORDER BY created_at DESC; $$;

CREATE OR REPLACE FUNCTION fn_security_dashboard(p_society_id bigint,p_day date)
RETURNS TABLE(total_guards bigint,on_duty bigint,off_duty bigint,today_visitors bigint,expected_visitors bigint,inside_visitors bigint,vehicle_entries bigint,open_incidents bigint,pending_approvals bigint)
LANGUAGE sql AS $$
SELECT
(SELECT count(*) FROM m_security_guard WHERE society_id=p_society_id AND is_active),
(SELECT count(DISTINCT r.guard_id) FROM t_security_roster r WHERE r.society_id=p_society_id AND r.roster_date=p_day AND r.attendance_status='Present'),
(SELECT count(*) FROM m_security_guard g WHERE g.society_id=p_society_id AND g.is_active AND NOT EXISTS(SELECT 1 FROM t_security_roster r WHERE r.society_id=p_society_id AND r.guard_id=g.guard_id AND r.roster_date=p_day AND r.attendance_status='Present')),
(SELECT count(*) FROM t_visitor_entry WHERE society_id=p_society_id AND entry_at::date=p_day),
(SELECT count(*) FROM t_visitor_invitation WHERE society_id=p_society_id AND expected_date=p_day AND approval_status IN ('Pending','Approved')),
(SELECT count(*) FROM t_visitor_entry WHERE society_id=p_society_id AND status='Inside'),
(SELECT count(*) FROM t_visitor_entry WHERE society_id=p_society_id AND entry_at::date=p_day AND vehicle_no IS NOT NULL AND vehicle_no<>''),
(SELECT count(*) FROM t_security_incident WHERE society_id=p_society_id AND status NOT IN ('Resolved','Closed')),
(SELECT count(*) FROM t_visitor_invitation WHERE society_id=p_society_id AND expected_date=p_day AND approval_status='Pending');
$$;

CREATE OR REPLACE FUNCTION fn_visitor_dashboard(p_society_id bigint,p_day date)
RETURNS TABLE(today_visitors bigint,expected_visitors bigint,pending_approval bigint,inside_visitors bigint,checked_out bigint,walk_in bigint,delivery_service bigint,visitor_vehicles bigint)
LANGUAGE sql AS $$
SELECT
(SELECT count(*) FROM t_visitor_entry WHERE society_id=p_society_id AND entry_at::date=p_day),
(SELECT count(*) FROM t_visitor_invitation WHERE society_id=p_society_id AND expected_date=p_day),
(SELECT count(*) FROM t_visitor_invitation WHERE society_id=p_society_id AND expected_date=p_day AND approval_status='Pending'),
(SELECT count(*) FROM t_visitor_entry WHERE society_id=p_society_id AND status='Inside'),
(SELECT count(*) FROM t_visitor_entry WHERE society_id=p_society_id AND exit_at::date=p_day),
(SELECT count(*) FROM t_visitor_entry WHERE society_id=p_society_id AND entry_at::date=p_day AND visitor_source='WalkIn'),
(SELECT count(*) FROM t_visitor_entry WHERE society_id=p_society_id AND entry_at::date=p_day AND visitor_type IN ('Delivery','Maid','Driver','Electrician','Plumber','Technician','Service Provider')),
(SELECT count(*) FROM t_visitor_entry WHERE society_id=p_society_id AND entry_at::date=p_day AND vehicle_no IS NOT NULL AND vehicle_no<>'');
$$;

CREATE OR REPLACE FUNCTION sp_security_guard_save(p_society_id bigint,p_id bigint,p_code varchar,p_name varchar,p_mobile varchar,p_govid varchar,p_agency varchar,p_type varchar,p_join date,p_active boolean,p_user bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint;
BEGIN
 IF p_id>0 THEN UPDATE m_security_guard SET guard_code=p_code,guard_name=p_name,mobile=p_mobile,government_id=p_govid,agency_name=p_agency,guard_type=p_type,joining_date=p_join,is_active=p_active,updated_by=p_user,updated_at=now() WHERE guard_id=p_id AND society_id=p_society_id RETURNING guard_id INTO v_id;
 ELSE INSERT INTO m_security_guard(society_id,guard_code,guard_name,mobile,government_id,agency_name,guard_type,joining_date,created_by,updated_by) VALUES(p_society_id,p_code,p_name,p_mobile,p_govid,p_agency,p_type,p_join,p_user,p_user) RETURNING guard_id INTO v_id; END IF;
 IF v_id IS NULL THEN RAISE EXCEPTION 'Guard not found in selected society'; END IF; RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION sp_security_shift_save(p_society_id bigint,p_id bigint,p_code varchar,p_name varchar,p_type varchar,p_start time,p_end time,p_active boolean,p_user bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint;
BEGIN
 IF p_id>0 THEN UPDATE m_security_shift SET shift_code=p_code,shift_name=p_name,shift_type=p_type,start_time=p_start,end_time=p_end,is_active=p_active,updated_by=p_user,updated_at=now() WHERE shift_id=p_id AND society_id=p_society_id RETURNING shift_id INTO v_id;
 ELSE INSERT INTO m_security_shift(society_id,shift_code,shift_name,shift_type,start_time,end_time,created_by,updated_by) VALUES(p_society_id,p_code,p_name,p_type,p_start,p_end,p_user,p_user) RETURNING shift_id INTO v_id; END IF;
 IF v_id IS NULL THEN RAISE EXCEPTION 'Shift not found in selected society'; END IF; RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION sp_security_roster_save(p_society_id bigint,p_id bigint,p_guard bigint,p_shift bigint,p_date date,p_att varchar,p_in timestamptz,p_out timestamptz,p_remark text,p_user bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM m_security_guard WHERE guard_id=p_guard AND society_id=p_society_id AND is_active) THEN RAISE EXCEPTION 'Guard not found'; END IF;
 IF NOT EXISTS(SELECT 1 FROM m_security_shift WHERE shift_id=p_shift AND society_id=p_society_id AND is_active) THEN RAISE EXCEPTION 'Shift not found'; END IF;
 IF p_id>0 THEN UPDATE t_security_roster SET guard_id=p_guard,shift_id=p_shift,roster_date=p_date,attendance_status=p_att,check_in=p_in,check_out=p_out,remarks=p_remark,updated_by=p_user,updated_at=now() WHERE roster_id=p_id AND society_id=p_society_id RETURNING roster_id INTO v_id;
 ELSE INSERT INTO t_security_roster(society_id,guard_id,shift_id,roster_date,attendance_status,check_in,check_out,remarks,created_by,updated_by) VALUES(p_society_id,p_guard,p_shift,p_date,p_att,p_in,p_out,p_remark,p_user,p_user) RETURNING roster_id INTO v_id; END IF;
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION sp_security_gate_save(p_society_id bigint,p_id bigint,p_code varchar,p_name varchar,p_type varchar,p_guard bigint,p_active boolean,p_user bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint;
BEGIN
 IF p_guard IS NOT NULL AND NOT EXISTS(SELECT 1 FROM m_security_guard WHERE guard_id=p_guard AND society_id=p_society_id AND is_active) THEN RAISE EXCEPTION 'Guard not found'; END IF;
 IF p_id>0 THEN UPDATE m_security_gate SET gate_code=p_code,gate_name=p_name,gate_type=p_type,assigned_guard_id=p_guard,is_active=p_active,updated_by=p_user,updated_at=now() WHERE gate_id=p_id AND society_id=p_society_id RETURNING gate_id INTO v_id;
 ELSE INSERT INTO m_security_gate(society_id,gate_code,gate_name,gate_type,assigned_guard_id,created_by,updated_by) VALUES(p_society_id,p_code,p_name,p_type,p_guard,p_user,p_user) RETURNING gate_id INTO v_id; END IF;
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION sp_visitor_invitation_save(p_society_id bigint,p_id bigint,p_customer bigint,p_flat bigint,p_name varchar,p_mobile varchar,p_purpose varchar,p_type varchar,p_date date,p_time time,p_vehicle varchar,p_vehicle_type varchar,p_user bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint;v_pass varchar;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM m_customer_flat cf WHERE cf.society_id=p_society_id AND cf.customer_id=p_customer AND cf.flat_id=p_flat) THEN RAISE EXCEPTION 'Customer and flat do not belong to selected society'; END IF;
 IF EXISTS(SELECT 1 FROM m_user u WHERE u.user_id=p_user AND u.role_code='RESIDENT') AND NOT EXISTS(SELECT 1 FROM m_user_customer uc WHERE uc.society_id=p_society_id AND uc.user_id=p_user AND uc.customer_id=p_customer AND uc.is_active) THEN RAISE EXCEPTION 'Resident is not authorized for this customer account'; END IF;
 IF p_id>0 THEN UPDATE t_visitor_invitation SET visitor_name=p_name,mobile=p_mobile,purpose=p_purpose,visitor_type=p_type,expected_date=p_date,expected_time=p_time,vehicle_no=p_vehicle,vehicle_type=p_vehicle_type,updated_by=p_user,updated_at=now() WHERE invitation_id=p_id AND society_id=p_society_id AND customer_id=p_customer RETURNING invitation_id,pass_code INTO v_id,v_pass;
 ELSE v_pass='VIS-'||upper(substr(md5(random()::text),1,10)); INSERT INTO t_visitor_invitation(society_id,customer_id,flat_id,visitor_name,mobile,purpose,visitor_type,expected_date,expected_time,vehicle_no,vehicle_type,approval_status,pass_code,created_by,updated_by) VALUES(p_society_id,p_customer,p_flat,p_name,p_mobile,p_purpose,p_type,p_date,p_time,p_vehicle,p_vehicle_type,'Pending',v_pass,p_user,p_user) RETURNING invitation_id,pass_code INTO v_id,v_pass; END IF;
 INSERT INTO t_notification(society_id,recipient_user_id,customer_id,channel,message,status,notification_type,title,reference_entity,reference_id)
 SELECT p_society_id,uc.user_id,p_customer,'APP','Visitor approval required for '||p_name,'Pending','VISITOR_APPROVAL','Visitor Approval Required','VISITOR_INVITATION',v_id
 FROM m_user_customer uc WHERE uc.society_id=p_society_id AND uc.customer_id=p_customer AND uc.is_active;
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION sp_visitor_walkin(p_society_id bigint,p_flat bigint,p_customer bigint,p_name varchar,p_phone varchar,p_type varchar,purpose varchar,p_vehicle varchar,p_vehicle_type varchar,p_gate bigint,p_guard bigint,p_id_type varchar,p_id_number varchar,p_photo bytea,p_photo_type varchar,p_user bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint;
BEGIN
 IF p_gate IS NOT NULL AND NOT EXISTS(SELECT 1 FROM m_security_gate WHERE gate_id=p_gate AND society_id=p_society_id AND is_active) THEN RAISE EXCEPTION 'Gate not found'; END IF;
 IF p_guard IS NOT NULL AND NOT EXISTS(SELECT 1 FROM m_security_guard WHERE guard_id=p_guard AND society_id=p_society_id AND is_active) THEN RAISE EXCEPTION 'Guard not found'; END IF;
 IF p_flat IS NOT NULL AND NOT EXISTS(SELECT 1 FROM m_flat WHERE flat_id=p_flat AND society_id=p_society_id AND is_active) THEN RAISE EXCEPTION 'Flat not found'; END IF;
 IF EXISTS(SELECT 1 FROM t_visitor_blacklist b WHERE b.society_id=p_society_id AND b.is_active AND (b.end_date IS NULL OR b.end_date>=current_date) AND ((p_phone<>'' AND b.mobile=p_phone) OR (p_vehicle<>'' AND b.vehicle_no=p_vehicle))) THEN RAISE EXCEPTION 'Restricted visitor or vehicle. Authorized override is required.';
 END IF;
 IF EXISTS(SELECT 1 FROM t_visitor_entry v WHERE v.society_id=p_society_id AND v.status='Inside' AND ((p_phone<>'' AND v.phone=p_phone) OR (p_vehicle<>'' AND v.vehicle_no=p_vehicle))) THEN RAISE EXCEPTION 'Visitor already has an active entry.';
 END IF;
 INSERT INTO t_visitor_entry(society_id,flat_id,customer_id,visitor_name,phone,visitor_type,vehicle_no,vehicle_type,purpose,gate_id,guard_id,id_type,id_number,photo_data,photo_content_type,entry_at,status,approval_status,visitor_source,created_by,updated_by)
 VALUES(p_society_id,p_flat,p_customer,p_name,p_phone,p_type,p_vehicle,p_vehicle_type,purpose,p_gate,p_guard,p_id_type,p_id_number,p_photo,p_photo_type,now(),'Inside','Verified','WalkIn',p_user,p_user) RETURNING visitor_entry_id INTO v_id;
 INSERT INTO t_notification(society_id,recipient_user_id,customer_id,channel,message,status,notification_type,title,reference_entity,reference_id)
 SELECT p_society_id,u.user_id,p_customer,'APP','Visitor '||p_name||' has entered the society.','Pending','VISITOR_ARRIVED','Visitor Arrived','VISITOR_ENTRY',v_id FROM m_user u WHERE u.user_id IN (SELECT user_id FROM m_user WHERE society_id=p_society_id AND is_active) AND u.role_code='SOCIETY_ADMIN';
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION sp_visitor_entry_exit(p_society_id bigint,p_id bigint,p_action varchar,p_gate bigint,p_guard bigint,p_user bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint;
BEGIN
 SELECT visitor_entry_id INTO v_id FROM t_visitor_entry WHERE visitor_entry_id=p_id AND society_id=p_society_id FOR UPDATE;
 IF v_id IS NULL THEN RAISE EXCEPTION 'Visitor record not found in selected society'; END IF;
 IF p_action='EXIT' THEN
  IF EXISTS(SELECT 1 FROM t_visitor_entry WHERE visitor_entry_id=v_id AND status<>'Inside') THEN RAISE EXCEPTION 'Visitor is not currently inside'; END IF;
  UPDATE t_visitor_entry SET exit_at=now(),status='Exited',gate_id=coalesce(p_gate,gate_id),guard_id=coalesce(p_guard,guard_id),updated_by=p_user,updated_at=now() WHERE visitor_entry_id=v_id;
  INSERT INTO t_notification(society_id,recipient_user_id,channel,message,status,notification_type,title,reference_entity,reference_id)
  SELECT p_society_id,u.user_id,'APP','Visitor has exited the society.','Pending','VISITOR_EXIT','Visitor Exit','VISITOR_ENTRY',v_id FROM m_user u WHERE u.society_id=p_society_id AND u.role_code='SOCIETY_ADMIN' AND u.is_active;
 ELSE
  UPDATE t_visitor_entry SET entry_at=coalesce(entry_at,now()),status='Inside',gate_id=coalesce(p_gate,gate_id),guard_id=coalesce(p_guard,guard_id),updated_by=p_user,updated_at=now() WHERE visitor_entry_id=v_id;
 END IF;
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION sp_visitor_approve(p_society_id bigint,p_id bigint,p_status varchar,p_user bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint;v_customer bigint;v_name varchar;
BEGIN
 SELECT invitation_id,customer_id,visitor_name INTO v_id,v_customer,v_name FROM t_visitor_invitation WHERE invitation_id=p_id AND society_id=p_society_id FOR UPDATE;
 IF v_id IS NULL THEN RAISE EXCEPTION 'Invitation not found'; END IF;
 IF p_status NOT IN ('Approved','Rejected') THEN RAISE EXCEPTION 'Invalid approval status'; END IF;
 UPDATE t_visitor_invitation SET approval_status=p_status,approved_by=p_user,approved_at=now(),updated_by=p_user,updated_at=now() WHERE invitation_id=v_id;
 INSERT INTO t_notification(society_id,recipient_user_id,customer_id,channel,message,status,notification_type,title,reference_entity,reference_id)
 SELECT p_society_id,uc.user_id,v_customer,'APP','Visitor '||v_name||' was '||lower(p_status)||'.','Pending','VISITOR_APPROVAL_RESULT','Visitor Approval Updated','VISITOR_INVITATION',v_id FROM m_user_customer uc WHERE uc.society_id=p_society_id AND uc.customer_id=v_customer AND uc.is_active;
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION sp_security_incident_save(p_society_id bigint,p_id bigint,p_type varchar,p_gate bigint,p_flat bigint,p_visitor bigint,p_vehicle varchar,p_when timestamptz,p_location varchar,p_description text,p_status varchar,p_file varchar,p_content_type varchar,p_data bytea,p_user bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint;v_no varchar;
BEGIN
 IF p_gate IS NOT NULL AND NOT EXISTS(SELECT 1 FROM m_security_gate WHERE gate_id=p_gate AND society_id=p_society_id) THEN RAISE EXCEPTION 'Gate not found in selected society'; END IF;
 IF p_flat IS NOT NULL AND NOT EXISTS(SELECT 1 FROM m_flat WHERE flat_id=p_flat AND society_id=p_society_id) THEN RAISE EXCEPTION 'Flat not found in selected society'; END IF;
 IF p_visitor IS NOT NULL AND NOT EXISTS(SELECT 1 FROM t_visitor_entry WHERE visitor_entry_id=p_visitor AND society_id=p_society_id) THEN RAISE EXCEPTION 'Visitor record not found in selected society'; END IF;
 IF p_id>0 THEN UPDATE t_security_incident SET incident_type=p_type,gate_id=p_gate,flat_id=p_flat,visitor_entry_id=p_visitor,vehicle_no=p_vehicle,occurred_at=p_when,location=p_location,description=p_description,status=p_status,attachment_name=p_file,attachment_content_type=p_content_type,attachment_data=p_data,updated_by=p_user,updated_at=now() WHERE incident_id=p_id AND society_id=p_society_id RETURNING incident_id INTO v_id;
 ELSE v_no='INC-'||to_char(now(),'YYYYMMDDHH24MISSMS'); INSERT INTO t_security_incident(society_id,incident_no,incident_type,gate_id,flat_id,visitor_entry_id,vehicle_no,occurred_at,location,description,status,attachment_name,attachment_content_type,attachment_data,created_by,updated_by) VALUES(p_society_id,v_no,p_type,p_gate,p_flat,p_visitor,p_vehicle,p_when,p_location,p_description,p_status,p_file,p_content_type,p_data,p_user,p_user) RETURNING incident_id INTO v_id; INSERT INTO t_security_incident_history(society_id,incident_id,new_status,remarks,changed_by) VALUES(p_society_id,v_id,p_status,'Incident created',p_user); END IF;
 INSERT INTO t_notification(society_id,recipient_user_id,channel,message,status,notification_type,title,reference_entity,reference_id)
 SELECT p_society_id,u.user_id,'APP','Security incident '||coalesce(p_status,'Open')||'.','Pending','SECURITY_INCIDENT','Security Incident','SECURITY_INCIDENT',v_id FROM m_user u WHERE u.society_id=p_society_id AND u.role_code='SOCIETY_ADMIN' AND u.is_active;
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION sp_security_incident_status(p_society_id bigint,p_id bigint,p_status varchar,p_remark text,p_user bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_old varchar;v_id bigint;
BEGIN
 SELECT status INTO v_old FROM t_security_incident WHERE incident_id=p_id AND society_id=p_society_id FOR UPDATE;
 IF v_old IS NULL THEN RAISE EXCEPTION 'Incident not found'; END IF;
 UPDATE t_security_incident SET status=p_status,updated_by=p_user,updated_at=now() WHERE incident_id=p_id AND society_id=p_society_id RETURNING incident_id INTO v_id;
 INSERT INTO t_security_incident_history(society_id,incident_id,old_status,new_status,remarks,changed_by) VALUES(p_society_id,p_id,v_old,p_status,p_remark,p_user);
 INSERT INTO t_notification(society_id,recipient_user_id,channel,message,status,notification_type,title,reference_entity,reference_id)
 SELECT p_society_id,u.user_id,'APP','Security incident status changed to '||p_status,'Pending','SECURITY_INCIDENT','Security Incident Updated','SECURITY_INCIDENT',p_id FROM m_user u WHERE u.society_id=p_society_id AND u.role_code='SOCIETY_ADMIN' AND u.is_active;
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION fn_security_reports(p_society_id bigint,p_report varchar,p_from date,p_to date,p_gate bigint,p_status varchar)
RETURNS TABLE(report_date date,gate_name varchar,guard_name varchar,visitor_name varchar,vehicle_no varchar,status varchar,incident_no varchar)
LANGUAGE sql AS $$
SELECT v.entry_at::date,g.gate_name,gd.guard_name,v.visitor_name,v.vehicle_no,v.status,NULL::varchar
FROM t_visitor_entry v LEFT JOIN m_security_gate g ON g.gate_id=v.gate_id AND g.society_id=p_society_id LEFT JOIN m_security_guard gd ON gd.guard_id=v.guard_id AND gd.society_id=p_society_id
WHERE p_report IN ('VISITOR','VEHICLE','GATE') AND v.society_id=p_society_id AND v.entry_at::date BETWEEN p_from AND p_to AND (p_gate IS NULL OR v.gate_id=p_gate) AND (coalesce(p_status,'')='' OR v.status=p_status)
UNION ALL
SELECT i.occurred_at::date,g.gate_name,NULL,NULL,i.vehicle_no,i.status,i.incident_no
FROM t_security_incident i LEFT JOIN m_security_gate g ON g.gate_id=i.gate_id AND g.society_id=p_society_id
WHERE p_report='INCIDENT' AND i.society_id=p_society_id AND i.occurred_at::date BETWEEN p_from AND p_to AND (p_gate IS NULL OR i.gate_id=p_gate) AND (coalesce(p_status,'')='' OR i.status=p_status)
ORDER BY 1 DESC;
$$;

CREATE OR REPLACE FUNCTION fn_security_recent_activity(p_society_id bigint,p_limit int)
RETURNS TABLE(event_time timestamptz,event_type varchar,description text,gate_name varchar,visitor_name varchar)
LANGUAGE sql AS $$
SELECT entry_at,'VISITOR_ENTRY',visitor_name||' entered',g.gate_name,visitor_name FROM t_visitor_entry v LEFT JOIN m_security_gate g ON g.gate_id=v.gate_id AND g.society_id=p_society_id WHERE v.society_id=p_society_id
UNION ALL SELECT occurred_at,'INCIDENT',incident_no||' - '||description,g.gate_name,NULL FROM t_security_incident i LEFT JOIN m_security_gate g ON g.gate_id=i.gate_id AND g.society_id=p_society_id WHERE i.society_id=p_society_id
ORDER BY 1 DESC LIMIT p_limit;
$$;
ALTER TABLE t_visitor_entry ADD COLUMN IF NOT EXISTS override_reason text;
CREATE TABLE IF NOT EXISTS m_user_customer(
 user_customer_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 user_id bigint NOT NULL REFERENCES m_user(user_id) ON DELETE CASCADE,
 customer_id bigint NOT NULL REFERENCES m_customer(customer_id) ON DELETE CASCADE,
 is_active boolean NOT NULL DEFAULT true,
 UNIQUE(society_id,user_id,customer_id)
);
CREATE INDEX IF NOT EXISTS ix_user_customer_society ON m_user_customer(society_id,user_id,customer_id);

DROP FUNCTION IF EXISTS sp_visitor_walkin(bigint,bigint,bigint,bigint,varchar,varchar,varchar,varchar,varchar,bigint,bigint,varchar,varchar,bytea,varchar,bigint);
CREATE OR REPLACE FUNCTION sp_visitor_walkin(p_society_id bigint,p_flat bigint,p_customer bigint,p_name varchar,p_phone varchar,p_type varchar,purpose varchar,p_vehicle varchar,p_vehicle_type varchar,p_gate bigint,p_guard bigint,p_id_type varchar,p_id_number varchar,p_photo bytea,p_photo_type varchar,p_user bigint,p_override boolean DEFAULT false,p_override_reason text DEFAULT NULL)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint;
BEGIN
 IF p_customer IS NOT NULL AND NOT EXISTS(SELECT 1 FROM m_customer WHERE customer_id=p_customer AND society_id=p_society_id AND is_active) THEN RAISE EXCEPTION 'Customer not found'; END IF;
 IF p_gate IS NOT NULL AND NOT EXISTS(SELECT 1 FROM m_security_gate WHERE gate_id=p_gate AND society_id=p_society_id AND is_active) THEN RAISE EXCEPTION 'Gate not found'; END IF;
 IF p_guard IS NOT NULL AND NOT EXISTS(SELECT 1 FROM m_security_guard WHERE guard_id=p_guard AND society_id=p_society_id AND is_active) THEN RAISE EXCEPTION 'Guard not found'; END IF;
 IF p_flat IS NOT NULL AND NOT EXISTS(SELECT 1 FROM m_flat WHERE flat_id=p_flat AND society_id=p_society_id AND is_active) THEN RAISE EXCEPTION 'Flat not found'; END IF;
 IF p_customer IS NOT NULL AND p_flat IS NOT NULL AND NOT EXISTS(SELECT 1 FROM m_customer_flat WHERE society_id=p_society_id AND customer_id=p_customer AND flat_id=p_flat) THEN RAISE EXCEPTION 'Customer and flat do not belong to selected society';
 END IF;
 IF NOT p_override AND EXISTS(SELECT 1 FROM t_visitor_blacklist b WHERE b.society_id=p_society_id AND b.is_active AND (b.end_date IS NULL OR b.end_date>=current_date) AND ((p_phone<>'' AND b.mobile=p_phone) OR (p_vehicle<>'' AND b.vehicle_no=p_vehicle))) THEN
  INSERT INTO t_notification(society_id,recipient_user_id,channel,message,status,notification_type,title,reference_entity)
  SELECT p_society_id,u.user_id,'APP','Restricted visitor or vehicle entry attempt was blocked.','Pending','RESTRICTED_VISITOR_ATTEMPT','Restricted Visitor Attempt','VISITOR_ENTRY'
  FROM m_user u WHERE u.society_id=p_society_id AND u.role_code='SOCIETY_ADMIN' AND u.is_active;
  RAISE EXCEPTION 'Restricted visitor or vehicle. Authorized override is required.';
 END IF;
 IF EXISTS(SELECT 1 FROM t_visitor_entry v WHERE v.society_id=p_society_id AND v.status='Inside' AND ((p_phone<>'' AND v.phone=p_phone) OR (p_vehicle<>'' AND v.vehicle_no=p_vehicle))) THEN RAISE EXCEPTION 'Visitor already has an active entry.';
 END IF;
 INSERT INTO t_visitor_entry(society_id,flat_id,customer_id,visitor_name,phone,visitor_type,vehicle_no,vehicle_type,purpose,gate_id,guard_id,id_type,id_number,photo_data,photo_content_type,entry_at,status,approval_status,visitor_source,created_by,updated_by,override_reason)
 VALUES(p_society_id,p_flat,p_customer,p_name,p_phone,p_type,p_vehicle,p_vehicle_type,purpose,p_gate,p_guard,p_id_type,p_id_number,p_photo,p_photo_type,now(),'Inside','Verified','WalkIn',p_user,p_user,CASE WHEN p_override THEN p_override_reason END) RETURNING visitor_entry_id INTO v_id;
 INSERT INTO t_notification(society_id,recipient_user_id,customer_id,channel,message,status,notification_type,title,reference_entity,reference_id)
 SELECT p_society_id,uc.user_id,p_customer,'APP','Visitor '||p_name||' has entered the society.','Pending','VISITOR_ARRIVED','Visitor Arrived','VISITOR_ENTRY',v_id
 FROM m_user_customer uc WHERE uc.society_id=p_society_id AND uc.customer_id=p_customer AND uc.is_active;
 INSERT INTO t_notification(society_id,recipient_user_id,channel,message,status,notification_type,title,reference_entity,reference_id)
 SELECT p_society_id,u.user_id,'APP','Visitor entry recorded for security monitoring.','Pending','VISITOR_ENTRY','Visitor Entry Completed','VISITOR_ENTRY',v_id
 FROM m_user u WHERE u.society_id=p_society_id AND u.role_code='SOCIETY_ADMIN' AND u.is_active;
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION sp_visitor_approve(p_society_id bigint,p_id bigint,p_status varchar,p_user bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint;v_customer bigint;v_name varchar;
BEGIN
 SELECT invitation_id,customer_id,visitor_name INTO v_id,v_customer,v_name FROM t_visitor_invitation WHERE invitation_id=p_id AND society_id=p_society_id FOR UPDATE;
 IF v_id IS NULL THEN RAISE EXCEPTION 'Invitation not found'; END IF;
 IF p_status NOT IN ('Approved','Rejected') THEN RAISE EXCEPTION 'Invalid approval status'; END IF;
 UPDATE t_visitor_invitation SET approval_status=p_status,approved_by=p_user,approved_at=now(),updated_by=p_user,updated_at=now() WHERE invitation_id=v_id;
 INSERT INTO t_notification(society_id,recipient_user_id,customer_id,channel,message,status,notification_type,title,reference_entity,reference_id)
 SELECT p_society_id,uc.user_id,v_customer,'APP','Visitor '||v_name||' was '||lower(p_status)||'.','Pending','VISITOR_APPROVAL_RESULT','Visitor Approval Updated','VISITOR_INVITATION',v_id
 FROM m_user_customer uc WHERE uc.society_id=p_society_id AND uc.customer_id=v_customer AND uc.is_active;
 RETURN v_id;
END; $$;
CREATE OR REPLACE FUNCTION sp_blacklist_save(p_society_id bigint,p_id bigint,p_name varchar,p_mobile varchar,p_vehicle varchar,p_reason text,p_from date,p_to date,p_active boolean,p_user bigint)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_id bigint;
BEGIN
 IF coalesce(trim(p_name),'')='' AND coalesce(trim(p_mobile),'')='' AND coalesce(trim(p_vehicle),'')='' THEN RAISE EXCEPTION 'Visitor name, mobile or vehicle is required'; END IF;
 IF p_id>0 THEN
  UPDATE t_visitor_blacklist SET visitor_name=p_name,mobile=p_mobile,vehicle_no=p_vehicle,reason=p_reason,start_date=p_from,end_date=p_to,is_active=p_active,updated_by=p_user,updated_at=now()
  WHERE blacklist_id=p_id AND society_id=p_society_id RETURNING blacklist_id INTO v_id;
 ELSE
  INSERT INTO t_visitor_blacklist(society_id,visitor_name,mobile,vehicle_no,reason,start_date,end_date,is_active,created_by,updated_by)
  VALUES(p_society_id,p_name,p_mobile,p_vehicle,p_reason,p_from,p_to,p_active,p_user,p_user) RETURNING blacklist_id INTO v_id;
 END IF;
 IF v_id IS NULL THEN RAISE EXCEPTION 'Blacklist record not found in selected society'; END IF;
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION fn_security_incident_history(p_society_id bigint,p_id bigint)
RETURNS TABLE(history_id bigint,old_status varchar,new_status varchar,remarks text,changed_by bigint,changed_at timestamptz)
LANGUAGE sql AS $$ SELECT history_id,old_status,new_status,remarks,changed_by,changed_at FROM t_security_incident_history WHERE society_id=p_society_id AND incident_id=p_id ORDER BY changed_at DESC; $$;

CREATE OR REPLACE FUNCTION fn_visitor_photo(p_society_id bigint,p_id bigint)
RETURNS TABLE(content_type varchar,photo_data bytea)
LANGUAGE sql AS $$ SELECT photo_content_type,photo_data FROM t_visitor_entry WHERE society_id=p_society_id AND visitor_entry_id=p_id AND photo_data IS NOT NULL; $$;

CREATE OR REPLACE FUNCTION fn_security_incident_content(p_society_id bigint,p_id bigint)
RETURNS TABLE(file_name varchar,content_type varchar,file_data bytea)
LANGUAGE sql AS $$ SELECT attachment_name,attachment_content_type,attachment_data FROM t_security_incident WHERE society_id=p_society_id AND incident_id=p_id AND attachment_data IS NOT NULL; $$;

UPDATE m_module SET visible=false WHERE module_code IN ('SUBSCRIPTION_PLATFORM','SUB_PLANS','SUB_ACTIVE','SUB_PAYMENT','SUB_RENEWAL','MIGRATION_CONTROL','MIG_PREVIEW','MIG_VALIDATE','MIG_IMPORT','MIG_ERRORS','MIG_BATCH','BACKOFFICE_MIGRATION');
