CREATE TABLE IF NOT EXISTS t_migration_unit_staging(
 staging_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 migration_batch_id bigint NOT NULL REFERENCES t_migration_batch(migration_batch_id) ON DELETE CASCADE,
 society_id bigint NOT NULL REFERENCES m_society(society_id),
 source_row_number int NOT NULL,
 wing_code varchar(30),
 unit_no varchar(60) NOT NULL,
 owner_name varchar(180),
 area_sqft numeric(12,2),
 maintenance_amount numeric(18,2),
 unit_type varchar(30) NOT NULL DEFAULT 'Flat',
 raw_data jsonb NOT NULL DEFAULT '{}'::jsonb,
 status varchar(30) NOT NULL DEFAULT 'Ready',
 error_message text,
 UNIQUE(migration_batch_id,source_row_number)
);
CREATE INDEX IF NOT EXISTS ix_t_migration_unit_staging_batch ON t_migration_unit_staging(migration_batch_id,status);
CREATE INDEX IF NOT EXISTS ix_t_migration_unit_staging_unit ON t_migration_unit_staging(society_id,unit_no);

CREATE OR REPLACE FUNCTION fn_import_migration_units(p_batch_id bigint,p_user_id bigint)
RETURNS TABLE(imported_flats bigint,imported_customers bigint,skipped_rows bigint)
LANGUAGE plpgsql AS $$
DECLARE r record; v_society bigint; v_building bigint; v_wing bigint; v_flat bigint; v_customer bigint;
BEGIN
 SELECT society_id INTO v_society FROM t_migration_batch WHERE migration_batch_id=p_batch_id FOR UPDATE;
 IF v_society IS NULL THEN RAISE EXCEPTION 'Migration batch not found'; END IF;
 FOR r IN SELECT * FROM t_migration_unit_staging WHERE migration_batch_id=p_batch_id AND status='Ready' ORDER BY source_row_number LOOP
   SELECT building_id INTO v_building FROM m_building WHERE society_id=v_society ORDER BY building_id LIMIT 1;
   IF r.wing_code IS NULL OR r.wing_code='' THEN
     v_wing := NULL;
   ELSE
     INSERT INTO m_wing(society_id,building_id,wing_code,wing_name) VALUES(v_society,v_building,r.wing_code,r.wing_code||' Wing')
     ON CONFLICT(society_id,wing_code) DO UPDATE SET wing_name=excluded.wing_name
     RETURNING wing_id INTO v_wing;
     IF v_wing IS NULL THEN SELECT wing_id INTO v_wing FROM m_wing WHERE society_id=v_society AND wing_code=r.wing_code; END IF;
   END IF;
   INSERT INTO m_flat(society_id,building_id,wing_id,flat_no,floor_no,unit_type,area_sqft,occupancy_status)
   VALUES(v_society,v_building,v_wing,r.unit_no,CASE WHEN r.unit_no ~ '[0-9]+' THEN regexp_replace(r.unit_no,'^.*?([0-9]+).*$','\1')::int ELSE NULL END,r.unit_type,r.area_sqft,'Occupied')
   ON CONFLICT(society_id,flat_no) DO UPDATE SET wing_id=excluded.wing_id,area_sqft=COALESCE(excluded.area_sqft,m_flat.area_sqft),unit_type=excluded.unit_type;
   SELECT flat_id INTO v_flat FROM m_flat WHERE society_id=v_society AND flat_no=r.unit_no;
   IF NULLIF(trim(r.owner_name),'') IS NOT NULL THEN
     INSERT INTO m_customer(society_id,customer_code,full_name,customer_type) VALUES(v_society,'MIG-'||p_batch_id||'-'||r.source_row_number,r.owner_name,'Owner')
     ON CONFLICT(society_id,customer_code) DO NOTHING;
     SELECT customer_id INTO v_customer FROM m_customer WHERE society_id=v_society AND customer_code='MIG-'||p_batch_id||'-'||r.source_row_number;
     INSERT INTO m_customer_flat(society_id,customer_id,flat_id,relation_type,is_primary,start_date)
     VALUES(v_society,v_customer,v_flat,'Owner',true,current_date)
     ON CONFLICT(customer_id,flat_id,relation_type) DO NOTHING;
   END IF;
   UPDATE t_migration_unit_staging SET status='Imported' WHERE staging_id=r.staging_id;
 END LOOP;
 UPDATE t_migration_batch b SET status='Imported',
   total_rows=(SELECT count(*) FROM t_migration_unit_staging WHERE migration_batch_id=p_batch_id),
   valid_rows=(SELECT count(*) FROM t_migration_unit_staging WHERE migration_batch_id=p_batch_id AND status='Imported'),
   error_rows=(SELECT count(*) FROM t_migration_unit_staging WHERE migration_batch_id=p_batch_id AND status='Error')
 WHERE b.migration_batch_id=p_batch_id;
 SELECT count(*) FROM m_flat WHERE society_id=v_society AND flat_id IN (SELECT f.flat_id FROM m_flat f JOIN t_migration_unit_staging s ON s.unit_no=f.flat_no WHERE s.migration_batch_id=p_batch_id) INTO imported_flats;
 SELECT count(*) FROM m_customer WHERE society_id=v_society AND customer_code LIKE 'MIG-'||p_batch_id||'-%' INTO imported_customers;
 SELECT count(*) FROM t_migration_unit_staging WHERE migration_batch_id=p_batch_id AND status='Error' INTO skipped_rows;
 RETURN NEXT;
END; $$;