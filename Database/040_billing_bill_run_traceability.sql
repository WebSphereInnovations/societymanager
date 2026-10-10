SET search_path TO society_manager, public;

ALTER TABLE t_bill
  ADD COLUMN IF NOT EXISTS billing_run_detail_id bigint,
  ADD COLUMN IF NOT EXISTS billing_run_id bigint;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname='fk_t_bill_billing_run_detail'
      AND conrelid='t_bill'::regclass
  ) THEN
    ALTER TABLE t_bill
      ADD CONSTRAINT fk_t_bill_billing_run_detail
      FOREIGN KEY(billing_run_detail_id)
      REFERENCES t_billing_run_detail(billing_run_detail_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname='fk_t_bill_billing_run'
      AND conrelid='t_bill'::regclass
  ) THEN
    ALTER TABLE t_bill
      ADD CONSTRAINT fk_t_bill_billing_run
      FOREIGN KEY(billing_run_id)
      REFERENCES t_billing_run(billing_run_id);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS ix_t_bill_billing_run
  ON t_bill(society_id,billing_run_id,billing_run_detail_id);
