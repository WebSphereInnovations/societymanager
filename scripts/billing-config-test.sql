BEGIN;
SELECT society_manager.sp_billing_save_configuration(1,2,true,'ARREAR',1.5,'Percentage',current_date,NULL,1,'Same-day config test') AS config_id;
SELECT count(*) AS history_rows FROM society_manager.t_billing_config_history WHERE society_id=1 AND modify_remark='Same-day config test';
ROLLBACK;