-- 042_login_history_write_path.sql
-- Repair login event history and keep the one-row-per-user login summary.
-- Idempotent schema additions and CREATE OR REPLACE procedures only.
ALTER TABLE society_manager.t_user_login_history
    ADD COLUMN IF NOT EXISTS society_id bigint;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_user_login_history_society'
          AND conrelid = 'society_manager.t_user_login_history'::regclass
    ) THEN
        ALTER TABLE society_manager.t_user_login_history
            ADD CONSTRAINT fk_user_login_history_society
            FOREIGN KEY (society_id) REFERENCES society_manager.m_society(society_id);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS ix_user_login_history_society_created
    ON society_manager.t_user_login_history (society_id, created_at DESC);

UPDATE society_manager.t_user_login_history h
SET society_id = u.society_id
FROM society_manager.m_user u
WHERE h.user_id = u.user_id
  AND h.society_id IS NULL
  AND u.society_id IS NOT NULL;

CREATE OR REPLACE PROCEDURE society_manager.sp_record_login_success_v2(
    IN p_user_id bigint,
    IN p_society_id bigint,
    IN p_login varchar,
    IN p_ip varchar,
    IN p_user_agent varchar
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_ip inet;
    v_society_id bigint;
    v_login_count bigint;
BEGIN
    v_ip := NULLIF(trim(p_ip), '')::inet;
    SELECT COALESCE(p_society_id, u.society_id)
      INTO v_society_id
      FROM society_manager.m_user u
     WHERE u.user_id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    INSERT INTO society_manager.t_user_login_audit
        (user_id, last_login_ip, last_login_at, login_count, last_user_agent,
         last_login_status, modified_by, modified_at, modify_remark)
    VALUES
        (p_user_id, v_ip, now(), COALESCE((SELECT u.login_count FROM society_manager.m_user u WHERE u.user_id = p_user_id), 0) + 1, left(COALESCE(p_user_agent, ''), 500),
         'SUCCESS', p_user_id, now(), '')
    ON CONFLICT (user_id) DO UPDATE
       SET last_login_ip = EXCLUDED.last_login_ip,
           last_login_at = EXCLUDED.last_login_at,
           login_count = GREATEST(society_manager.t_user_login_audit.login_count, COALESCE((SELECT u.login_count FROM society_manager.m_user u WHERE u.user_id = p_user_id), 0)) + 1,
           last_user_agent = EXCLUDED.last_user_agent,
           last_login_status = 'SUCCESS',
           modified_by = p_user_id,
           modified_at = now(),
           modify_remark = ''
    RETURNING login_count INTO v_login_count;

    UPDATE society_manager.m_user
       SET last_login_ip = v_ip,
           last_login_at = now(),
           login_count = v_login_count,
           modified_by = p_user_id,
           modified_at = now(),
           modify_remark = ''
     WHERE user_id = p_user_id;

    INSERT INTO society_manager.t_user_login_history
        (society_id, user_id, login_name, login_ip, user_agent, status, failure_reason, trace_id)
    VALUES
        (v_society_id, p_user_id, left(COALESCE(p_login, ''), 100), v_ip,
         left(COALESCE(p_user_agent, ''), 500), 'SUCCESS', NULL, NULL);
END $$;

CREATE OR REPLACE PROCEDURE society_manager.sp_record_login_failure_v2(
    IN p_user_id bigint,
    IN p_society_id bigint,
    IN p_login varchar,
    IN p_ip varchar,
    IN p_user_agent varchar,
    IN p_reason varchar
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_ip inet;
    v_society_id bigint;
BEGIN
    v_ip := NULLIF(trim(p_ip), '')::inet;
    v_society_id := p_society_id;

    IF v_society_id IS NULL AND p_user_id IS NOT NULL THEN
        SELECT u.society_id INTO v_society_id
          FROM society_manager.m_user u
         WHERE u.user_id = p_user_id;
    END IF;

    INSERT INTO society_manager.t_user_login_history
        (society_id, user_id, login_name, login_ip, user_agent, status, failure_reason, trace_id)
    VALUES
        (v_society_id, p_user_id, left(COALESCE(p_login, ''), 100), v_ip,
         left(COALESCE(p_user_agent, ''), 500), 'FAILURE',
         left(COALESCE(p_reason, 'Login failed'), 200), NULL);
END $$;
