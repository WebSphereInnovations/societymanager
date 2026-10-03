-- 026_support_assistant.sql
-- Database-driven multilingual FAQ/support assistant. No private resident data is exposed.
SET search_path TO society_manager, public;

CREATE TABLE IF NOT EXISTS m_support_faq (
    faq_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    society_id bigint NULL REFERENCES m_society(society_id) ON DELETE CASCADE,
    faq_code varchar(80) NOT NULL,
    question_en text NOT NULL,
    answer_en text NOT NULL,
    question_hi text,
    answer_hi text,
    question_mr text,
    answer_mr text,
    question_gu text,
    answer_gu text,
    question_kn text,
    answer_kn text,
    question_ta text,
    answer_ta text,
    keywords_en text,
    keywords_hi text,
    keywords_mr text,
    keywords_gu text,
    keywords_kn text,
    keywords_ta text,
    display_order integer NOT NULL DEFAULT 100,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    modified_by bigint NULL REFERENCES m_user(user_id),
    modified_at timestamptz NOT NULL DEFAULT now(),
    modify_remark varchar(500) NOT NULL DEFAULT '',
    UNIQUE(society_id, faq_code)
);

CREATE INDEX IF NOT EXISTS ix_m_support_faq_scope
ON m_support_faq(society_id,is_active,display_order);

CREATE OR REPLACE FUNCTION fn_support_faq(
    p_society_id bigint,
    p_language varchar DEFAULT 'en',
    p_query varchar DEFAULT ''
)
RETURNS TABLE(
    faq_id bigint,
    faq_code varchar,
    question text,
    answer text,
    display_order integer
)
LANGUAGE sql AS $$
SELECT
    f.faq_id,
    f.faq_code,
    CASE lower(coalesce(p_language,'en'))
      WHEN 'hi' THEN coalesce(f.question_hi,f.question_en)
      WHEN 'mr' THEN coalesce(f.question_mr,f.question_en)
      WHEN 'gu' THEN coalesce(f.question_gu,f.question_en)
      WHEN 'kn' THEN coalesce(f.question_kn,f.question_en)
      WHEN 'ta' THEN coalesce(f.question_ta,f.question_en)
      ELSE f.question_en END,
    CASE lower(coalesce(p_language,'en'))
      WHEN 'hi' THEN coalesce(f.answer_hi,f.answer_en)
      WHEN 'mr' THEN coalesce(f.answer_mr,f.answer_en)
      WHEN 'gu' THEN coalesce(f.answer_gu,f.answer_en)
      WHEN 'kn' THEN coalesce(f.answer_kn,f.answer_en)
      WHEN 'ta' THEN coalesce(f.answer_ta,f.answer_en)
      ELSE f.answer_en END,
    f.display_order
FROM m_support_faq f
WHERE f.is_active
  AND (f.society_id IS NULL OR f.society_id=p_society_id)
  AND (
      coalesce(trim(p_query),'')=''
      OR f.question_en ILIKE '%'||p_query||'%'
      OR f.answer_en ILIKE '%'||p_query||'%'
      OR coalesce(f.keywords_en,'') ILIKE '%'||p_query||'%'
      OR coalesce(f.keywords_hi,'') ILIKE '%'||p_query||'%'
      OR coalesce(f.keywords_mr,'') ILIKE '%'||p_query||'%'
      OR coalesce(f.keywords_gu,'') ILIKE '%'||p_query||'%'
      OR coalesce(f.keywords_kn,'') ILIKE '%'||p_query||'%'
      OR coalesce(f.keywords_ta,'') ILIKE '%'||p_query||'%'
  )
ORDER BY f.society_id NULLS FIRST, f.display_order, f.faq_id
LIMIT 12;
$$;

CREATE OR REPLACE PROCEDURE sp_support_faq_save(
    IN p_faq_id bigint,
    IN p_society_id bigint,
    IN p_faq_code varchar,
    IN p_question_en text,
    IN p_answer_en text,
    IN p_question_hi text DEFAULT NULL,
    IN p_answer_hi text DEFAULT NULL,
    IN p_question_mr text DEFAULT NULL,
    IN p_answer_mr text DEFAULT NULL,
    IN p_question_gu text DEFAULT NULL,
    IN p_answer_gu text DEFAULT NULL,
    IN p_question_kn text DEFAULT NULL,
    IN p_answer_kn text DEFAULT NULL,
    IN p_question_ta text DEFAULT NULL,
    IN p_answer_ta text DEFAULT NULL,
    IN p_modified_by bigint DEFAULT NULL,
    IN p_remark varchar DEFAULT ''
)
LANGUAGE plpgsql AS $$
BEGIN
    IF nullif(trim(p_faq_code),'') IS NULL OR nullif(trim(p_question_en),'') IS NULL OR nullif(trim(p_answer_en),'') IS NULL THEN
        RAISE EXCEPTION 'FAQ code, English question and English answer are required';
    END IF;

    IF p_faq_id IS NULL OR p_faq_id=0 THEN
        INSERT INTO m_support_faq(
          society_id,faq_code,question_en,answer_en,question_hi,answer_hi,question_mr,answer_mr,
          question_gu,answer_gu,question_kn,answer_kn,question_ta,answer_ta,modified_by,modify_remark)
        VALUES(
          p_society_id,p_faq_code,trim(p_question_en),trim(p_answer_en),p_question_hi,p_answer_hi,p_question_mr,p_answer_mr,
          p_question_gu,p_answer_gu,p_question_kn,p_answer_kn,p_question_ta,p_answer_ta,p_modified_by,coalesce(p_remark,''));
    ELSE
        UPDATE m_support_faq
        SET society_id=p_society_id,faq_code=p_faq_code,question_en=trim(p_question_en),answer_en=trim(p_answer_en),
            question_hi=p_question_hi,answer_hi=p_answer_hi,question_mr=p_question_mr,answer_mr=p_answer_mr,
            question_gu=p_question_gu,answer_gu=p_answer_gu,question_kn=p_question_kn,answer_kn=p_answer_kn,
            question_ta=p_question_ta,answer_ta=p_answer_ta,modified_by=p_modified_by,modified_at=now(),
            modify_remark=coalesce(p_remark,'')
        WHERE faq_id=p_faq_id;
    END IF;
END $$;

INSERT INTO m_support_faq(
  society_id,faq_code,question_en,answer_en,question_hi,answer_hi,question_mr,answer_mr,
  question_gu,answer_gu,question_kn,answer_kn,question_ta,answer_ta,
  keywords_en,keywords_hi,keywords_mr,keywords_gu,keywords_kn,keywords_ta,display_order)
VALUES
(NULL,'PAYMENT','How do I make a payment?','Open Collection or My Billing, select the bill, choose an available payment method and complete the payment. Your receipt is generated after the transaction is recorded.',
'भुगतान कैसे करें?','कलेक्शन या माय बिलिंग खोलें, बिल चुनें, उपलब्ध भुगतान विधि चुनें और भुगतान पूरा करें। लेन-देन दर्ज होने के बाद रसीद उपलब्ध होगी.',
'पेमेंट कसे करावे?','कलेक्शन किंवा माय बिलिंग उघडा, बिल निवडा, उपलब्ध पेमेंट पद्धत निवडा आणि पेमेंट पूर्ण करा. व्यवहार नोंदवल्यानंतर पावती उपलब्ध होईल.',
'ચુકવણી કેવી રીતે કરવી?','કલેક્શન અથવા માય બિલિંગ ખોલો, બિલ પસંદ કરો, ઉપલબ્ધ ચુકવણી પદ્ધતિ પસંદ કરો અને ચુકવણી પૂર્ણ કરો. વ્યવહાર નોંધાયા પછી રસીદ ઉપલબ્ધ થશે.',
'ಪಾವತಿ ಹೇಗೆ ಮಾಡುವುದು?','ಕಲೆಕ್ಷನ್ ಅಥವಾ ಮೈ ಬಿಲ್ಲಿಂಗ್ ತೆರೆಯಿರಿ, ಬಿಲ್ ಆಯ್ಕೆಮಾಡಿ, ಲಭ್ಯವಿರುವ ಪಾವತಿ ವಿಧಾನವನ್ನು ಆಯ್ಕೆಮಾಡಿ ಮತ್ತು ಪಾವತಿ ಪೂರ್ಣಗೊಳಿಸಿ. ವ್ಯವಹಾರ ದಾಖಲಾದ ನಂತರ ರಸೀದಿ ಲಭ್ಯವಾಗುತ್ತದೆ.',
'பணம் செலுத்துவது எப்படி?','கலெக்ஷன் அல்லது மை பில்லிங் திறந்து, பில்லைத் தேர்வு செய்து, கிடைக்கும் கட்டண முறையைத் தேர்ந்தெடுத்து பணம் செலுத்துங்கள். பரிவர்த்தனை பதிவு செய்யப்பட்டதும் ரசீது கிடைக்கும்.',
'payment,pay,bill,receipt','भुगतान,पेमेंट,बिल,रसीद','पेमेंट,बिल,पावती','ચુકવણી,બિલ,રસીદ','ಪಾವತಿ,ಬಿಲ್,ರಸೀದಿ','பணம்,பில்,ரசீது',10),
(NULL,'VISITOR','How do I add a visitor?','Use Visitor Management to create a pre-approved visitor invite. The visitor can then be verified by security at the gate and the entry/exit is recorded.',
'आगंतुक कैसे जोड़ें?','विज़िटर मैनेजमेंट में प्री-अप्रूव्ड विज़िटर आमंत्रण बनाएं। गेट पर सुरक्षा द्वारा सत्यापन के बाद प्रवेश और निकास दर्ज किया जाएगा.',
'अभ्यागत कसा जोडावा?','व्हिजिटर मॅनेजमेंटमध्ये पूर्व-मंजूर अभ्यागत आमंत्रण तयार करा. गेटवर सुरक्षा पडताळणीनंतर प्रवेश आणि निर्गमन नोंदवले जाईल.',
'મુલાકાતી કેવી રીતે ઉમેરવો?','વિઝિટર મેનેજમેન્ટમાં પૂર્વ-મંજૂર મુલાકાતી આમંત્રણ બનાવો. ગેટ પર સુરક્ષા ચકાસણી પછી પ્રવેશ અને બહાર નીકળવાની નોંધ થશે.',
'ಭೇಟಿದಾರರನ್ನು ಹೇಗೆ ಸೇರಿಸುವುದು?','ವಿಸಿಟರ್ ಮ್ಯಾನೇಜ್‌ಮೆಂಟ್‌ನಲ್ಲಿ ಪೂರ್ವ-ಅನುಮೋದಿತ ಭೇಟಿ ಆಹ್ವಾನ ರಚಿಸಿ. ಗೇಟ್‌ನಲ್ಲಿ ಭದ್ರತಾ ಪರಿಶೀಲನೆಯ ನಂತರ ಪ್ರವೇಶ ಮತ್ತು ನಿರ್ಗಮನ ದಾಖಲಾಗುತ್ತದೆ.',
'பார்வையாளரை எப்படி சேர்ப்பது?','விசிட்டர் மேனேஜ்மெண்டில் முன் அங்கீகரிக்கப்பட்ட பார்வையாளர் அழைப்பை உருவாக்குங்கள். வாயிலில் பாதுகாப்பு சரிபார்ப்புக்குப் பிறகு நுழைவு மற்றும் வெளியேற்றம் பதிவு செய்யப்படும்.',
'visitor,invite,guest','आगंतुक,विज़िटर,मेहमान','अभ्यागत,व्हिजिटर,पाहुणे','મુલાકાતી,વિઝિટર,મહેમાન','ಭೇಟಿದಾರ,ವಿಸಿಟರ್,ಅತಿಥಿ','பார்வையாளர்,விருந்தினர்',20),
(NULL,'COMPLAINT','How do I raise a complaint?','Open Complaints or the Customer Portal, enter the category and issue details, then submit. The complaint number and current status can be tracked from the complaint history.',
'शिकायत कैसे दर्ज करें?','शिकायतें या ग्राहक पोर्टल खोलें, श्रेणी और समस्या का विवरण दर्ज करें और सबमिट करें। शिकायत संख्या और स्थिति इतिहास में देखी जा सकती है.',
'तक्रार कशी नोंदवावी?','तक्रारी किंवा ग्राहक पोर्टल उघडा, श्रेणी आणि समस्येचे तपशील भरा आणि सबमिट करा. तक्रार क्रमांक व स्थिती इतिहासात पाहता येईल.',
'ફરિયાદ કેવી રીતે નોંધાવવી?','ફરિયાદો અથવા ગ્રાહક પોર્ટલ ખોલો, શ્રેણી અને સમસ્યાની વિગતો દાખલ કરો અને સબમિટ કરો. ફરિયાદ નંબર અને સ્થિતિ ઇતિહાસમાં જોઈ શકાય છે.',
'ದೂರು ಹೇಗೆ ಸಲ್ಲಿಸುವುದು?','ದೂರುಗಳು ಅಥವಾ ಗ್ರಾಹಕ ಪೋರ್ಟಲ್ ತೆರೆಯಿರಿ, ವರ್ಗ ಮತ್ತು ಸಮಸ್ಯೆಯ ವಿವರಗಳನ್ನು ನಮೂದಿಸಿ ಮತ್ತು ಸಲ್ಲಿಸಿ. ದೂರು ಸಂಖ್ಯೆ ಮತ್ತು ಸ್ಥಿತಿಯನ್ನು ಇತಿಹಾಸದಲ್ಲಿ ನೋಡಬಹುದು.',
'புகாரை எப்படி பதிவு செய்வது?','புகார்கள் அல்லது வாடிக்கையாளர் போர்டலைத் திறந்து, வகை மற்றும் பிரச்சனை விவரங்களை உள்ளிட்டு சமர்ப்பிக்கவும். புகார் எண் மற்றும் நிலையை வரலாற்றில் பார்க்கலாம்.',
'complaint,issue,service','शिकायत,समस्या,सेवा','तक्रार,समस्या,सेवा','ફરિયાદ,સમस्या,સેવા','ದೂರು,ಸಮಸ್ಯೆ,ಸೇವೆ','புகார்,பிரச்சனை,சேவை',30),
(NULL,'DUES','How do I check my dues?','Open My Billing or Customer 360. The bill list shows billed amount, paid amount, balance and due date. Overdue balances are highlighted by status.',
'बकाया कैसे देखें?','माय बिलिंग या ग्राहक 360 खोलें। बिल सूची में बिल राशि, भुगतान, शेष राशि और देय तिथि दिखाई जाती है.',
'बाकी रक्कम कशी पाहावी?','माय बिलिंग किंवा ग्राहक 360 उघडा. बिल यादीत बिल रक्कम, भरलेली रक्कम, शिल्लक आणि देय दिनांक दिसतो.',
'બાકી રકમ કેવી રીતે જોવી?','માય બિલિંગ અથવા ગ્રાહક 360 ખોલો. બિલ યાદીમાં બિલ રકમ, ચૂકવેલી રકમ, બાકી રકમ અને ચૂકવણીની તારીખ દેખાય છે.',
'ಬಾಕಿ ಮೊತ್ತವನ್ನು ಹೇಗೆ ನೋಡುವುದು?','ಮೈ ಬಿಲ್ಲಿಂಗ್ ಅಥವಾ ಗ್ರಾಹಕ 360 ತೆರೆಯಿರಿ. ಬಿಲ್ ಪಟ್ಟಿಯಲ್ಲಿ ಬಿಲ್ ಮೊತ್ತ, ಪಾವತಿಸಿದ ಮೊತ್ತ, ಬಾಕಿ ಮತ್ತು ಪಾವತಿ ದಿನಾಂಕ ಕಾಣುತ್ತದೆ.',
'நிலுவைத் தொகையை எப்படி பார்ப்பது?','மை பில்லிங் அல்லது வாடிக்கையாளர் 360 திறக்கவும். பில் பட்டியலில் பில் தொகை, செலுத்திய தொகை, நிலுவை மற்றும் கடைசி தேதி காணப்படும்.',
'dues,outstanding,balance,arrears','बकाया,बकाया राशि,शेष','बाकी,थकबाकी,शिल्लक','બાકી,બેલેન્સ,લેણું','ಬಾಕಿ,ಉಳಿಕೆ,ಶೇಷ','நிலுவை,மீதம்,பாக்கி',40),
(NULL,'RECEIPT','How do I download a receipt?','Open Collection or Payment History, select the payment and open its receipt/details. The receipt uses the recorded transaction data.',
'रसीद कैसे डाउनलोड करें?','कलेक्शन या भुगतान इतिहास खोलें, भुगतान चुनें और रसीद/विवरण खोलें। रसीद दर्ज किए गए लेन-देन डेटा से बनती है.',
'पावती कशी डाउनलोड करावी?','कलेक्शन किंवा पेमेंट हिस्टरी उघडा, पेमेंट निवडा आणि पावती/तपशील उघडा. पावती नोंदवलेल्या व्यवहाराच्या डेटावर आधारित असते.',
'રસીદ કેવી રીતે ડાઉનલોડ કરવી?','કલેક્શન અથવા પેમેન્ટ હિસ્ટરી ખોલો, ચુકવણી પસંદ કરો અને રસીદ/વિગતો ખોલો. રસીદ નોંધાયેલા વ્યવહારના ડેટાથી બને છે.',
'ರಸೀದಿಯನ್ನು ಹೇಗೆ ಡೌನ್‌ಲೋಡ್ ಮಾಡುವುದು?','ಕಲೆಕ್ಷನ್ ಅಥವಾ ಪಾವತಿ ಇತಿಹಾಸ ತೆರೆಯಿರಿ, ಪಾವತಿ ಆಯ್ಕೆಮಾಡಿ ಮತ್ತು ರಸೀದಿ/ವಿವರಗಳನ್ನು ತೆರೆಯಿರಿ. ರಸೀದಿ ದಾಖಲಾದ ವ್ಯವಹಾರ ಡೇಟಾವನ್ನು ಬಳಸುತ್ತದೆ.',
'ரசீதை எப்படி பதிவிறக்குவது?','கலெக்ஷன் அல்லது கட்டண வரலாற்றைத் திறந்து, கட்டணத்தைத் தேர்ந்தெடுத்து ரசீது/விவரங்களைத் திறக்கவும். பதிவு செய்யப்பட்ட பரிவர்த்தனைத் தரவைப் பயன்படுத்தி ரசீது உருவாக்கப்படும்.',
'receipt,download,payment history','रसीद,डाउनलोड,भुगतान इतिहास','पावती,डाउनलोड,पेमेंट इतिहास','રસીદ,ડાઉનલોડ,ચુકવણી ઇતિહાસ','ರಸೀದಿ,ಡೌನ್‌ಲೋಡ್,ಪಾವತಿ ಇತಿಹಾಸ','ரசீது,பதிவிறக்கம்,கட்டண வரலாறு',50),
(NULL,'CUSTOMER','How do I add a customer?','Authorized society staff can open CRM/Residents and use the customer creation workflow. The record is saved against the selected society and linked flat.',
'ग्राहक कैसे जोड़ें?','अधिकृत सोसायटी स्टाफ CRM/निवासी खोलकर ग्राहक जोड़ने की प्रक्रिया का उपयोग कर सकता है। रिकॉर्ड चयनित सोसायटी और फ्लैट से जुड़ता है.',
'ग्राहक कसा जोडावा?','अधिकृत सोसायटी कर्मचारी CRM/रहिवासी उघडून ग्राहक जोडण्याची प्रक्रिया वापरू शकतो. नोंद निवडलेल्या सोसायटी आणि फ्लॅटशी जोडली जाते.',
'ગ્રાહક કેવી રીતે ઉમેરવો?','અધિકૃત સોસાયટી સ્ટાફ CRM/રહેવાસી ખોલીને ગ્રાહક ઉમેરવાની પ્રક્રિયા વાપરી શકે છે. રેકોર્ડ પસંદ કરેલી સોસાયટી અને ફ્લેટ સાથે જોડાય છે.',
'ಗ್ರಾಹಕರನ್ನು ಹೇಗೆ ಸೇರಿಸುವುದು?','ಅಧಿಕೃತ ಸೊಸೈಟಿ ಸಿಬ್ಬಂದಿ CRM/ನಿವಾಸಿಗಳನ್ನು ತೆರೆಯಿರಿ ಮತ್ತು ಗ್ರಾಹಕ ರಚನೆ ಕಾರ್ಯವಿಧಾನ ಬಳಸಿ. ದಾಖಲೆ ಆಯ್ಕೆ ಮಾಡಿದ ಸೊಸೈಟಿ ಮತ್ತು ಫ್ಲಾಟ್‌ಗೆ ಸಂಪರ್ಕಿಸಲಾಗುತ್ತದೆ.',
'வாடிக்கையாளரை எப்படி சேர்ப்பது?','அங்கீகரிக்கப்பட்ட சொசைட்டி பணியாளர்கள் CRM/குடியிருப்பாளர்களைத் திறந்து வாடிக்கையாளர் உருவாக்கும் செயல்முறையைப் பயன்படுத்தலாம். பதிவு தேர்ந்தெடுத்த சொசைட்டி மற்றும் வீட்டுடன் இணைக்கப்படும்.',
'customer,resident,owner,tenant','ग्राहक,निवासी,मालिक,किरायेदार','ग्राहक,रहिवासी,मालक,भाडेकरू','ગ્રાહક,રહેવાસી,માલિક,ભાડૂત','ಗ್ರಾಹಕ,ನಿವಾಸಿ,ಮಾಲೀಕ,ಬಾಡಿಗೆದಾರ','வாடிக்கையாளர்,குடியிருப்பாளர்,உரிமையாளர்,வாடகையாளர்',60)
ON CONFLICT(society_id,faq_code) DO UPDATE SET
 question_en=excluded.question_en,answer_en=excluded.answer_en,
 question_hi=excluded.question_hi,answer_hi=excluded.answer_hi,
 question_mr=excluded.question_mr,answer_mr=excluded.answer_mr,
 question_gu=excluded.question_gu,answer_gu=excluded.answer_gu,
 question_kn=excluded.question_kn,answer_kn=excluded.answer_kn,
 question_ta=excluded.question_ta,answer_ta=excluded.answer_ta,
 keywords_en=excluded.keywords_en,keywords_hi=excluded.keywords_hi,keywords_mr=excluded.keywords_mr,
 keywords_gu=excluded.keywords_gu,keywords_kn=excluded.keywords_kn,keywords_ta=excluded.keywords_ta,
 display_order=excluded.display_order,is_active=true,modified_at=now();
