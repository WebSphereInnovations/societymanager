BEGIN;
UPDATE society_manager.m_user SET preferred_language='en' WHERE preferred_language IN ('hi','ta') OR preferred_language IS NULL;
UPDATE society_manager.m_society SET default_language='en' WHERE default_language IN ('hi','ta') OR default_language IS NULL;
DELETE FROM society_manager.m_translation WHERE language_code IN ('hi','ta');
DELETE FROM society_manager.m_language WHERE language_code IN ('hi','ta');
INSERT INTO society_manager.m_language(language_code,language_name,native_name,locale_name,is_active,sort_order)
VALUES ('en','English','English','en-IN',true,1),
       ('mr','Marathi','मराठी','mr-IN',true,2),
       ('gu','Gujarati','ગુજરાતી','gu-IN',true,3),
       ('kn','Kannada','ಕನ್ನಡ','kn-IN',true,4),
       ('te','Telugu','తెలుగు','te-IN',true,5)
ON CONFLICT(language_code) DO UPDATE SET language_name=excluded.language_name,native_name=excluded.native_name,locale_name=excluded.locale_name,is_active=true,sort_order=excluded.sort_order;
UPDATE society_manager.m_language SET is_active=(language_code IN ('en','mr','gu','kn','te'));
COMMIT;