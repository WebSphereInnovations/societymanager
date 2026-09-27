[Reading 6 lines from start (total: 6 lines, 0 remaining)]

SET search_path TO society_manager, public;
WITH generated AS (
 SELECT encode(gen_random_bytes(9),'hex') AS token
)
SELECT token, fn_provision_demo_society_admin('LAKEVIEW','lakeadmin',token,'Lakeview Society Admin') AS user_id
FROM generated;

[executed on device: Sandman (3c28f028-a467-4934-be2f-752a8db6b6a8)]