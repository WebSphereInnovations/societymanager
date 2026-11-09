-- Central Super Admin theme pricing and plan access policy.
-- Current launch policy: every active theme is free for every society.
ALTER TABLE society_manager.m_theme
  ADD COLUMN IF NOT EXISTS access_mode varchar(10) NOT NULL DEFAULT 'FREE',
  ADD COLUMN IF NOT EXISTS allowed_plan_codes varchar(50)[] NOT NULL DEFAULT '{}';

ALTER TABLE society_manager.m_theme
  DROP CONSTRAINT IF EXISTS ck_m_theme_access_mode;
ALTER TABLE society_manager.m_theme
  ADD CONSTRAINT ck_m_theme_access_mode CHECK (access_mode IN ('FREE','PAID'));

UPDATE society_manager.m_theme
SET access_mode='FREE', allowed_plan_codes='{}',
    modify_remark='Launch offer: all themes free for all societies'
WHERE is_active;

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
      EXISTS (SELECT 1 FROM society_manager.m_theme t
              WHERE t.theme_code='STANDARD' AND t.is_active)
    ELSE EXISTS (
      SELECT 1 FROM society_manager.m_theme t
      WHERE t.theme_code=upper(p_theme_code) AND t.is_active
        AND (
          t.access_mode='FREE'
          OR EXISTS (
            SELECT 1
            FROM society_manager.t_society_theme_entitlement e
            WHERE e.society_id=p_society_id AND e.theme_id=t.theme_id
              AND e.is_active AND e.entitlement_status='ACTIVE'
              AND e.starts_at<=now() AND (e.ends_at IS NULL OR e.ends_at>now())
              AND (e.subscription_id IS NULL OR EXISTS (
                SELECT 1 FROM society_manager.m_society_subscription ss
                WHERE ss.subscription_id=e.subscription_id
                  AND ss.society_id=e.society_id AND ss.is_active
                  AND ss.start_date<=current_date AND ss.end_date>=current_date
              ))
          )
          OR EXISTS (
            SELECT 1
            FROM society_manager.m_society_subscription ss
            JOIN society_manager.m_subscription_plan sp
              ON sp.subscription_plan_id=ss.subscription_plan_id
            WHERE ss.society_id=p_society_id AND ss.is_active
              AND ss.start_date<=current_date AND ss.end_date>=current_date
              AND upper(sp.plan_code)=ANY(t.allowed_plan_codes)
          )
        )
    )
  END;
$function$;
