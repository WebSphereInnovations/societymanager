[Reading 16 lines from start (total: 16 lines, 0 remaining)]

BEGIN;
-- Legacy migration retained for deployment ordering. It is intentionally non-destructive.
-- The application now supports six languages; no existing language or translation rows are deleted.
INSERT INTO society_manager.m_language(language_code,language_name,native_name,locale_name,is_active,sort_order)
VALUES ('en','English','English','en-IN',true,1),
       ('hi','Hindi','हिन्दी','hi-IN',true,2),
       ('mr','Marathi','मराठी','mr-IN',true,3),
       ('kn','Kannada','ಕನ್ನಡ','kn-IN',true,4),
       ('ta','Tamil','தமிழ்','ta-IN',true,5),
       ('te','Telugu','తెలుగు','te-IN',true,6)
ON CONFLICT(language_code) DO UPDATE SET
 language_name=excluded.language_name,native_name=excluded.native_name,locale_name=excluded.locale_name,
 is_active=true,sort_order=excluded.sort_order;
UPDATE society_manager.m_language SET is_active=true
WHERE language_code IN ('en','hi','mr','kn','ta','te');
COMMIT;

[executed on device: Sandman (3c28f028-a467-4934-be2f-752a8db6b6a8)]