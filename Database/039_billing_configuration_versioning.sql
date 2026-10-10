SET search_path TO society_manager, public;

-- The original billing table allowed only one configuration row per society.
-- Versioned Billing requires multiple effective-dated rows while keeping one active row.
ALTER TABLE m_billing_config
  DROP CONSTRAINT IF EXISTS m_billing_config_society_id_key;

CREATE UNIQUE INDEX IF NOT EXISTS ux_m_billing_config_society_effective
  ON m_billing_config(society_id,effective_from);
