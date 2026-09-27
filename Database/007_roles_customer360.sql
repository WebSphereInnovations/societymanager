SET search_path TO society_manager, public;
INSERT INTO m_role(role_code,role_name,description,is_system) VALUES('CASHIER','Cashier','Society collection and receipt operator',true) ON CONFLICT(role_code) DO NOTHING;

