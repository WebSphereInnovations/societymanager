SET search_path TO society_manager, public;
WITH generated AS (
 SELECT encode(gen_random_bytes(9),'hex') AS token
)
SELECT token, fn_provision_demo_society_admin('LAKEVIEW','lakeadmin',token,'Lakeview Society Admin') AS user_id
FROM generated;
