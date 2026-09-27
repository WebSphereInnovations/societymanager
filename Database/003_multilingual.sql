CREATE TABLE IF NOT EXISTS society_manager.m_language (
 language_code varchar(10) PRIMARY KEY, language_name varchar(100) NOT NULL, native_name varchar(100) NOT NULL, locale_name varchar(30) NOT NULL, is_active boolean NOT NULL DEFAULT true, sort_order integer NOT NULL DEFAULT 0
);
INSERT INTO society_manager.m_language(language_code,language_name,native_name,locale_name,sort_order) VALUES
('en','English','English','en-IN',1),('hi','Hindi','हिन्दी','hi-IN',2),('mr','Marathi','मराठी','mr-IN',3),('gu','Gujarati','ગુજરાતી','gu-IN',4),('kn','Kannada','ಕನ್ನಡ','kn-IN',5),('ta','Tamil','தமிழ்','ta-IN',6)
ON CONFLICT(language_code) DO UPDATE SET language_name=excluded.language_name,native_name=excluded.native_name,locale_name=excluded.locale_name,sort_order=excluded.sort_order;

CREATE TABLE IF NOT EXISTS society_manager.m_translation (
 translation_id bigserial PRIMARY KEY, society_id bigint NULL REFERENCES society_manager.m_society(society_id),
 resource_type varchar(80) NOT NULL, resource_key varchar(200) NOT NULL, language_code varchar(10) NOT NULL REFERENCES society_manager.m_language(language_code),
 translated_text text NOT NULL, updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(society_id,resource_type,resource_key,language_code)
);
CREATE INDEX IF NOT EXISTS ix_m_translation_lookup ON society_manager.m_translation(society_id,resource_type,resource_key,language_code);

ALTER TABLE society_manager.m_society ADD COLUMN IF NOT EXISTS default_language varchar(10) NOT NULL DEFAULT 'en' REFERENCES society_manager.m_language(language_code);
ALTER TABLE society_manager.m_user ADD COLUMN IF NOT EXISTS preferred_language varchar(10) NOT NULL DEFAULT 'en' REFERENCES society_manager.m_language(language_code);

CREATE OR REPLACE FUNCTION society_manager.fn_available_languages()
RETURNS TABLE(language_code varchar,language_name varchar,native_name varchar,locale_name varchar)
LANGUAGE sql AS $$ SELECT language_code,language_name,native_name,locale_name FROM society_manager.m_language WHERE is_active ORDER BY sort_order; $$;

CREATE OR REPLACE FUNCTION society_manager.fn_translation(p_society_id bigint,p_resource_type varchar,p_resource_key varchar,p_language_code varchar)
RETURNS text LANGUAGE sql AS $$
SELECT COALESCE(
 (SELECT translated_text FROM society_manager.m_translation WHERE society_id=p_society_id AND resource_type=p_resource_type AND resource_key=p_resource_key AND language_code=p_language_code),
 (SELECT translated_text FROM society_manager.m_translation WHERE society_id IS NULL AND resource_type=p_resource_type AND resource_key=p_resource_key AND language_code=p_language_code),
 (SELECT translated_text FROM society_manager.m_translation WHERE society_id IS NULL AND resource_type=p_resource_type AND resource_key=p_resource_key AND language_code='en'),
 p_resource_key);
$$;
