-- SKYFY NEXUS commercial theme catalog, entitlements and user preferences.
-- Additive and idempotent. Test with an outer transaction + ROLLBACK before deployment.
-- No existing society, user, subscription or business data is rewritten.

SET search_path TO society_manager, public;

CREATE TABLE IF NOT EXISTS society_manager.m_theme (
    theme_id bigserial PRIMARY KEY,
    theme_code varchar(50) NOT NULL UNIQUE,
    theme_name varchar(120) NOT NULL,
    theme_version varchar(32) NOT NULL,
    is_commercial boolean NOT NULL DEFAULT false,
    is_default boolean NOT NULL DEFAULT false,
    is_active boolean NOT NULL DEFAULT true,
    created_by bigint NULL REFERENCES society_manager.m_user(user_id),
    modified_by bigint NULL REFERENCES society_manager.m_user(user_id),
    modified_at timestamptz NULL,
    modify_remark text NOT NULL DEFAULT '',
    created_at timestamptz NOT NULL DEFAULT now(),
    modify_by bigint NULL REFERENCES society_manager.m_user(user_id),
    modify_date timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_m_theme_single_default
    ON society_manager.m_theme(is_default) WHERE is_default;

CREATE TABLE IF NOT EXISTS society_manager.m_theme_configuration (
    theme_config_id bigserial PRIMARY KEY,
    theme_id bigint NOT NULL REFERENCES society_manager.m_theme(theme_id) ON DELETE CASCADE,
    config_version varchar(32) NOT NULL,
    config_json jsonb NOT NULL DEFAULT '{}'::jsonb,
    is_active boolean NOT NULL DEFAULT true,
    created_by bigint NULL REFERENCES society_manager.m_user(user_id),
    modified_by bigint NULL REFERENCES society_manager.m_user(user_id),
    modified_at timestamptz NULL,
    modify_remark text NOT NULL DEFAULT '',
    created_at timestamptz NOT NULL DEFAULT now(),
    modify_by bigint NULL REFERENCES society_manager.m_user(user_id),
    modify_date timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_m_theme_configuration_version UNIQUE(theme_id, config_version)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_m_theme_configuration_one_active
    ON society_manager.m_theme_configuration(theme_id) WHERE is_active;

CREATE TABLE IF NOT EXISTS society_manager.t_society_theme_entitlement (
    entitlement_id bigserial PRIMARY KEY,
    society_id bigint NOT NULL REFERENCES society_manager.m_society(society_id),
    theme_id bigint NOT NULL REFERENCES society_manager.m_theme(theme_id),
    subscription_id bigint NULL REFERENCES society_manager.m_society_subscription(subscription_id),
    grant_source varchar(20) NOT NULL DEFAULT 'SUBSCRIPTION'
        CHECK (grant_source IN ('SUBSCRIPTION','MANUAL','TRIAL')),
    entitlement_status varchar(20) NOT NULL DEFAULT 'PENDING'
        CHECK (entitlement_status IN ('PENDING','ACTIVE','PAUSED','REVOKED','EXPIRED')),
    starts_at timestamptz NOT NULL DEFAULT now(),
    ends_at timestamptz NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_by bigint NULL REFERENCES society_manager.m_user(user_id),
    modified_by bigint NULL REFERENCES society_manager.m_user(user_id),
    modified_at timestamptz NULL,
    modify_remark text NOT NULL DEFAULT '',
    created_at timestamptz NOT NULL DEFAULT now(),
    modify_by bigint NULL REFERENCES society_manager.m_user(user_id),
    modify_date timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_t_society_theme_entitlement_window
        CHECK (ends_at IS NULL OR ends_at > starts_at)
);

CREATE INDEX IF NOT EXISTS ix_t_society_theme_entitlement_lookup
    ON society_manager.t_society_theme_entitlement
       (society_id, theme_id, entitlement_status, is_active, starts_at, ends_at);

CREATE UNIQUE INDEX IF NOT EXISTS ux_t_society_theme_entitlement_active
    ON society_manager.t_society_theme_entitlement(society_id, theme_id)
    WHERE is_active AND entitlement_status = 'ACTIVE';

CREATE TABLE IF NOT EXISTS society_manager.t_user_theme_preference (
    preference_id bigserial PRIMARY KEY,
    user_id bigint NOT NULL,
    society_id bigint NOT NULL,
    theme_id bigint NOT NULL REFERENCES society_manager.m_theme(theme_id),
    created_by bigint NULL REFERENCES society_manager.m_user(user_id),
    modified_by bigint NULL REFERENCES society_manager.m_user(user_id),
    modified_at timestamptz NULL,
    modify_remark text NOT NULL DEFAULT '',
    created_at timestamptz NOT NULL DEFAULT now(),
    modify_by bigint NULL REFERENCES society_manager.m_user(user_id),
    modify_date timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_t_user_theme_preference_membership
        FOREIGN KEY(user_id, society_id)
        REFERENCES society_manager.m_user_society(user_id, society_id)
        ON DELETE CASCADE,
    CONSTRAINT uq_t_user_theme_preference_user_society UNIQUE(user_id, society_id)
);

CREATE OR REPLACE FUNCTION society_manager.fn_skyfy_theme_stamp()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
    v_user bigint;
    v_remark text;
BEGIN
    v_user := NULLIF(current_setting('society_manager.current_user_id', true), '')::bigint;
    v_remark := COALESCE(NULLIF(current_setting('society_manager.modify_remark', true), ''),
                         NEW.modify_remark, '');
    IF TG_OP = 'INSERT' THEN
        NEW.created_at := COALESCE(NEW.created_at, now());
        NEW.created_by := COALESCE(NEW.created_by, v_user);
    END IF;
    NEW.modified_at := now();
    NEW.modified_by := COALESCE(v_user, NEW.modified_by, NEW.modify_by);
    NEW.modify_by := COALESCE(v_user, NEW.modify_by, NEW.modified_by);
    NEW.modify_date := now();
    NEW.modify_remark := v_remark;
    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION society_manager.fn_skyfy_theme_audit()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
    v_new jsonb;
    v_old jsonb;
    v_row jsonb;
    v_society_id bigint;
    v_user_id bigint;
    v_entity_id bigint;
    v_remark text;
BEGIN
    v_new := CASE WHEN TG_OP = 'DELETE' THEN '{}'::jsonb ELSE to_jsonb(NEW) END;
    v_old := CASE WHEN TG_OP = 'INSERT' THEN '{}'::jsonb ELSE to_jsonb(OLD) END;
    v_row := CASE WHEN TG_OP = 'DELETE' THEN v_old ELSE v_new END;
    v_society_id := COALESCE(NULLIF(v_new->>'society_id','')::bigint,
                             NULLIF(v_old->>'society_id','')::bigint);
    v_user_id := COALESCE(NULLIF(v_new->>'modify_by','')::bigint,
                          NULLIF(v_new->>'modified_by','')::bigint,
                          NULLIF(v_old->>'modify_by','')::bigint,
                          NULLIF(v_old->>'modified_by','')::bigint,
                          NULLIF(current_setting('society360.user_id',true),'')::bigint);
    v_entity_id := COALESCE(NULLIF(v_row->>'entitlement_id','')::bigint,
                            NULLIF(v_row->>'preference_id','')::bigint,
                            NULLIF(v_row->>'theme_config_id','')::bigint,
                            NULLIF(v_row->>'theme_id','')::bigint);
    v_remark := COALESCE(NULLIF(v_new->>'modify_remark',''),
                         NULLIF(v_old->>'modify_remark',''),
                         current_setting('society360.remark',true), '');
    INSERT INTO society_manager.t_audit_log
        (society_id,user_id,entity_name,entity_id,action,old_data,new_data,
         created_at,module_code,event_code,remark,
         ip_address,user_agent,request_id)
    VALUES
        (v_society_id,v_user_id,TG_TABLE_NAME,v_entity_id,TG_OP,v_old,v_new,
         now(),'THEME_PREFERENCES',upper(TG_TABLE_NAME)||'_'||TG_OP,v_remark,
         NULLIF(current_setting('society360.ip',true),'')::inet,
         current_setting('society360.user_agent',true),
         NULLIF(current_setting('society360.request_id',true),'')::uuid);
    RETURN COALESCE(NEW, OLD);
END;
$function$;

DO $function$
DECLARE
    v_table text;
BEGIN
    FOREACH v_table IN ARRAY ARRAY[
        'm_theme',
        'm_theme_configuration',
        't_society_theme_entitlement',
        't_user_theme_preference'
    ]
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trg_skyfy_theme_stamp ON society_manager.%I', v_table);
        EXECUTE format('CREATE TRIGGER trg_skyfy_theme_stamp BEFORE INSERT OR UPDATE ON society_manager.%I FOR EACH ROW EXECUTE FUNCTION society_manager.fn_skyfy_theme_stamp()', v_table);
        EXECUTE format('DROP TRIGGER IF EXISTS trg_skyfy_theme_audit ON society_manager.%I', v_table);
        EXECUTE format('CREATE TRIGGER trg_skyfy_theme_audit AFTER INSERT OR UPDATE OR DELETE ON society_manager.%I FOR EACH ROW EXECUTE FUNCTION society_manager.fn_skyfy_theme_audit()', v_table);
    END LOOP;
END;
$function$;

INSERT INTO society_manager.m_theme
    (theme_code,theme_name,theme_version,is_commercial,is_default,is_active,modify_remark)
VALUES
    ('STANDARD','Standard Theme','1.0.0',false,true,true,'Default existing Society360 theme'),
    ('SKYFY_NEXUS','SKYFY NEXUS – Premium Smart Society Experience','1.0.0',true,false,true,'Commercial theme catalog entry')
ON CONFLICT (theme_code) DO NOTHING;

INSERT INTO society_manager.m_theme_configuration
    (theme_id,config_version,config_json,is_active,modify_remark)
SELECT t.theme_id,'1.0.0',
       CASE WHEN t.theme_code='SKYFY_NEXUS'
            THEN '{"theme":"skyfy-nexus","schemaVersion":1,"motion":"respect-reduced-motion","visualization":"lazy-3d"}'::jsonb
            ELSE '{"theme":"standard","schemaVersion":1}'::jsonb
       END,
       true,'Initial theme configuration'
FROM society_manager.m_theme t
WHERE t.theme_code IN ('STANDARD','SKYFY_NEXUS')
ON CONFLICT (theme_id,config_version) DO NOTHING;

INSERT INTO society_manager.m_permission
    (module_code,action_code,permission_name,is_active,visible,created_at,modify_date,modify_remark)
VALUES
    ('THEME_PREFERENCES','VIEW','View available theme preferences',true,true,now(),now(),'SKYFY NEXUS theme access'),
    ('THEME_PREFERENCES','UPDATE','Change user theme preference',true,true,now(),now(),'SKYFY NEXUS theme access'),
    ('THEME_PREFERENCES','MANAGE','Manage society commercial theme entitlements',true,true,now(),now(),'SKYFY NEXUS theme access')
ON CONFLICT (module_code,action_code) DO NOTHING;

INSERT INTO society_manager.m_role_permission
    (role_id,permission_id,created_at,modify_date,modify_remark)
SELECT r.role_id,p.permission_id,now(),now(),'Initial SKYFY NEXUS theme permission'
FROM society_manager.m_role r
JOIN society_manager.m_permission p ON p.module_code='THEME_PREFERENCES'
WHERE r.role_code IN ('SUPER_ADMIN','SOCIETY_ADMIN')
  AND p.action_code IN ('VIEW','UPDATE','MANAGE')
  AND (r.role_code='SUPER_ADMIN' OR p.action_code IN ('VIEW','UPDATE'))
ON CONFLICT (role_id,permission_id) DO NOTHING;

CREATE OR REPLACE FUNCTION society_manager.fn_skyfy_theme_is_entitled(
    p_society_id bigint,
    p_theme_code varchar
)
RETURNS boolean
LANGUAGE sql
STABLE
AS $function$
    SELECT CASE
        WHEN upper(COALESCE(p_theme_code,''))='STANDARD' THEN
            EXISTS (
                SELECT 1 FROM society_manager.m_theme t
                WHERE t.theme_code='STANDARD' AND t.is_active
            )
        ELSE EXISTS (
            SELECT 1
            FROM society_manager.t_society_theme_entitlement e
            JOIN society_manager.m_theme t ON t.theme_id=e.theme_id
            WHERE e.society_id=p_society_id
              AND t.theme_code=upper(p_theme_code)
              AND t.is_active
              AND e.is_active
              AND e.entitlement_status='ACTIVE'
              AND e.starts_at<=now()
              AND (e.ends_at IS NULL OR e.ends_at>now())
              AND (
                  e.subscription_id IS NULL
                  OR EXISTS (
                      SELECT 1
                      FROM society_manager.m_society_subscription s
                      WHERE s.subscription_id=e.subscription_id
                        AND s.society_id=e.society_id
                        AND s.is_active
                        AND s.start_date<=current_date
                        AND s.end_date>=current_date
                  )
              )
        )
    END;
$function$;
