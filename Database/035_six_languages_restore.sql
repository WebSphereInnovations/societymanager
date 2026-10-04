BEGIN;

-- Restore the six-language catalog after the legacy five-language cleanup migration.
INSERT INTO society_manager.m_language(language_code,language_name,native_name,locale_name,is_active,sort_order)
VALUES
 ('en','English','English','en-IN',true,1),
 ('hi','Hindi','हिन्दी','hi-IN',true,2),
 ('mr','Marathi','मराठी','mr-IN',true,3),
 ('kn','Kannada','ಕನ್ನಡ','kn-IN',true,4),
 ('ta','Tamil','தமிழ்','ta-IN',true,5),
 ('te','Telugu','తెలుగు','te-IN',true,6)
ON CONFLICT(language_code) DO UPDATE
SET language_name=excluded.language_name,native_name=excluded.native_name,
    locale_name=excluded.locale_name,is_active=true,sort_order=excluded.sort_order;

UPDATE society_manager.m_language SET is_active=(language_code IN ('en','hi','mr','kn','ta','te'));
UPDATE society_manager.m_user SET preferred_language='en'
WHERE preferred_language IS NULL OR preferred_language NOT IN ('en','hi','mr','kn','ta','te');
UPDATE society_manager.m_society SET default_language='en'
WHERE default_language IS NULL OR default_language NOT IN ('en','hi','mr','kn','ta','te');

ALTER TABLE society_manager.m_support_faq ADD COLUMN IF NOT EXISTS question_te text;
ALTER TABLE society_manager.m_support_faq ADD COLUMN IF NOT EXISTS answer_te text;
ALTER TABLE society_manager.m_support_faq ADD COLUMN IF NOT EXISTS keywords_te text;

CREATE OR REPLACE FUNCTION society_manager.fn_support_faq(
 p_society_id bigint,p_language varchar DEFAULT 'en',p_query varchar DEFAULT ''
)
RETURNS TABLE(faq_id bigint,faq_code varchar,question text,answer text,display_order integer)
LANGUAGE sql AS $$
SELECT f.faq_id,f.faq_code,
 CASE lower(coalesce(p_language,'en'))
  WHEN 'hi' THEN coalesce(f.question_hi,f.question_en)
  WHEN 'mr' THEN coalesce(f.question_mr,f.question_en)
  WHEN 'gu' THEN coalesce(f.question_gu,f.question_en)
  WHEN 'kn' THEN coalesce(f.question_kn,f.question_en)
  WHEN 'ta' THEN coalesce(f.question_ta,f.question_en)
  WHEN 'te' THEN coalesce(f.question_te,f.question_en)
  ELSE f.question_en END,
 CASE lower(coalesce(p_language,'en'))
  WHEN 'hi' THEN coalesce(f.answer_hi,f.answer_en)
  WHEN 'mr' THEN coalesce(f.answer_mr,f.answer_en)
  WHEN 'gu' THEN coalesce(f.answer_gu,f.answer_en)
  WHEN 'kn' THEN coalesce(f.answer_kn,f.answer_en)
  WHEN 'ta' THEN coalesce(f.answer_ta,f.answer_en)
  WHEN 'te' THEN coalesce(f.answer_te,f.answer_en)
  ELSE f.answer_en END,
 f.display_order
FROM society_manager.m_support_faq f
WHERE f.is_active AND (f.society_id IS NULL OR f.society_id=p_society_id)
 AND (coalesce(trim(p_query),'')='' OR f.question_en ILIKE '%'||p_query||'%' OR f.answer_en ILIKE '%'||p_query||'%'
      OR coalesce(f.keywords_en,'') ILIKE '%'||p_query||'%' OR coalesce(f.keywords_hi,'') ILIKE '%'||p_query||'%'
      OR coalesce(f.keywords_mr,'') ILIKE '%'||p_query||'%' OR coalesce(f.keywords_gu,'') ILIKE '%'||p_query||'%'
      OR coalesce(f.keywords_kn,'') ILIKE '%'||p_query||'%' OR coalesce(f.keywords_ta,'') ILIKE '%'||p_query||'%'
      OR coalesce(f.keywords_te,'') ILIKE '%'||p_query||'%')
ORDER BY f.society_id NULLS FIRST,f.display_order,f.faq_id LIMIT 12;
$$;

UPDATE society_manager.m_support_faq
SET question_te=CASE faq_code
 WHEN 'PAYMENT' THEN 'చెల్లింపు ఎలా చేయాలి?'
 WHEN 'VISITOR' THEN 'సందర్శకుడిని ఎలా జోడించాలి?'
 WHEN 'COMPLAINT' THEN 'ఫిర్యాదు ఎలా నమోదు చేయాలి?'
 WHEN 'DUES' THEN 'బకాయిలను ఎలా చూడాలి?'
 WHEN 'RECEIPT' THEN 'రసీదును ఎలా డౌన్‌లోడ్ చేయాలి?'
 WHEN 'CUSTOMER' THEN 'కస్టమర్‌ను ఎలా జోడించాలి?'
 ELSE question_en END,
 answer_te=CASE faq_code
 WHEN 'PAYMENT' THEN 'కలెక్షన్ లేదా మై బిల్లింగ్ తెరిచి, బిల్లును ఎంచుకుని, అందుబాటులో ఉన్న చెల్లింపు విధానాన్ని ఎంచుకుని చెల్లింపును పూర్తి చేయండి. లావాదేవీ నమోదు అయిన తర్వాత రసీదు అందుబాటులో ఉంటుంది.'
 WHEN 'VISITOR' THEN 'విజిటర్ మేనేజ్‌మెంట్‌లో ముందస్తుగా ఆమోదించిన సందర్శకుడి ఆహ్వానాన్ని సృష్టించండి. గేట్ వద్ద భద్రతా తనిఖీ తర్వాత ప్రవేశం మరియు నిష్క్రమణ నమోదు చేయబడుతుంది.'
 WHEN 'COMPLAINT' THEN 'ఫిర్యాదులు లేదా కస్టమర్ పోర్టల్ తెరిచి, వర్గం మరియు సమస్య వివరాలను నమోదు చేసి సమర్పించండి. ఫిర్యాదు సంఖ్య మరియు స్థితిని చరిత్రలో చూడవచ్చు.'
 WHEN 'DUES' THEN 'మై బిల్లింగ్ లేదా కస్టమర్ 360 తెరవండి. బిల్ జాబితాలో బిల్ మొత్తం, చెల్లించిన మొత్తం, బకాయి మరియు గడువు తేదీ కనిపిస్తాయి.'
 WHEN 'RECEIPT' THEN 'కలెక్షన్ లేదా చెల్లింపు చరిత్ర తెరిచి, చెల్లింపును ఎంచుకుని రసీదు లేదా వివరాలను తెరవండి. నమోదు చేసిన లావాదేవీ డేటాతో రసీదు రూపొందుతుంది.'
 WHEN 'CUSTOMER' THEN 'అధికారిక సొసైటీ సిబ్బంది CRM లేదా నివాసుల విభాగాన్ని తెరిచి కస్టమర్ సృష్టి ప్రక్రియను ఉపయోగించవచ్చు. రికార్డు ఎంచుకున్న సొసైటీ మరియు ఫ్లాట్‌కు అనుసంధానించబడుతుంది.'
 ELSE answer_en END,
 keywords_te=CASE faq_code
 WHEN 'PAYMENT' THEN 'చెల్లింపు,బిల్,రసీదు'
 WHEN 'VISITOR' THEN 'సందర్శకుడు,విజిటర్,అతిథి'
 WHEN 'COMPLAINT' THEN 'ఫిర్యాదు,సమస్య,సేవ'
 WHEN 'DUES' THEN 'బకాయి,మొత్తం,లెక్క'
 WHEN 'RECEIPT' THEN 'రసీదు,డౌన్‌లోడ్,చెల్లింపు చరిత్ర'
 WHEN 'CUSTOMER' THEN 'కస్టమర్,నివాసి,యజమాని,అద్దెదారు'
 ELSE keywords_en END
WHERE society_id IS NULL AND faq_code IN ('PAYMENT','VISITOR','COMPLAINT','DUES','RECEIPT','CUSTOMER');

COMMIT;
