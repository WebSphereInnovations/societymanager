SET search_path TO society_manager, public;
SELECT fn_provision_demo_society_admin(
    'LAKEVIEW',
    'lakeadmin',
    convert_from(decode('U29jaWV0eUAxMjM0NQ==','base64'),'UTF8'),
    'Lakeview Society Admin'
) AS user_id;