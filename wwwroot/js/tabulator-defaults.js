(()=>{
  const language=()=>window.Society360I18n?.currentLanguage?.()||localStorage.getItem('society360-language')||'en';
  const copy={
    en:{page_size:'Rows per page',page_title:'Show page',first:'First',first_title:'First page',last:'Last',last_title:'Last page',prev:'Previous',prev_title:'Previous page',next:'Next',next_title:'Next page',all:'All',counter:{showing:'Showing',of:'of',rows:'rows',pages:'pages'}},
    hi:{page_size:'प्रति पृष्ठ पंक्तियाँ',page_title:'पृष्ठ दिखाएँ',first:'पहला',first_title:'पहला पृष्ठ',last:'अंतिम',last_title:'अंतिम पृष्ठ',prev:'पिछला',prev_title:'पिछला पृष्ठ',next:'अगला',next_title:'अगला पृष्ठ',all:'सभी',counter:{showing:'दिखा रहे हैं',of:'में से',rows:'पंक्तियाँ',pages:'पृष्ठ'}},
    mr:{page_size:'प्रति पृष्ठ ओळी',page_title:'पृष्ठ दाखवा',first:'पहिले',first_title:'पहिले पृष्ठ',last:'शेवटचे',last_title:'शेवटचे पृष्ठ',prev:'मागील',prev_title:'मागील पृष्ठ',next:'पुढील',next_title:'पुढील पृष्ठ',all:'सर्व',counter:{showing:'दाखवत आहे',of:'पैकी',rows:'ओळी',pages:'पृष्ठे'}},
    gu:{page_size:'પ્રતિ પૃષ્ઠ પંક્તિઓ',page_title:'પૃષ્ઠ બતાવો',first:'પ્રથમ',first_title:'પ્રથમ પૃષ્ઠ',last:'છેલ્લું',last_title:'છેલ્લું પૃષ્ઠ',prev:'પાછળ',prev_title:'પાછલું પૃષ્ઠ',next:'આગળ',next_title:'આગળનું પૃષ્ઠ',all:'બધું',counter:{showing:'દર્શાવે છે',of:'માંથી',rows:'પંક્તિઓ',pages:'પૃષ્ઠો'}},
    kn:{page_size:'ಪ್ರತಿ ಪುಟದ ಸಾಲುಗಳು',page_title:'ಪುಟ ತೋರಿಸಿ',first:'ಮೊದಲ',first_title:'ಮೊದಲ ಪುಟ',last:'ಕೊನೆಯ',last_title:'ಕೊನೆಯ ಪುಟ',prev:'ಹಿಂದಿನ',prev_title:'ಹಿಂದಿನ ಪುಟ',next:'ಮುಂದಿನ',next_title:'ಮುಂದಿನ ಪುಟ',all:'ಎಲ್ಲಾ',counter:{showing:'ತೋರಿಸಲಾಗುತ್ತಿದೆ',of:'ರಲ್ಲಿ',rows:'ಸಾಲುಗಳು',pages:'ಪುಟಗಳು'}},
    ta:{page_size:'ஒரு பக்கத்திற்கான வரிசைகள்',page_title:'பக்கத்தைக் காட்டு',first:'முதல்',first_title:'முதல் பக்கம்',last:'கடைசி',last_title:'கடைசி பக்கம்',prev:'முந்தைய',prev_title:'முந்தைய பக்கம்',next:'அடுத்து',next_title:'அடுத்த பக்கம்',all:'அனைத்தும்',counter:{showing:'காட்டப்படுகிறது',of:'இல்',rows:'வரிசைகள்',pages:'பக்கங்கள்'}}
  };
  function apply(){if(!window.Tabulator)return;const lang=language();Tabulator.defaultOptions=Tabulator.defaultOptions||{};Tabulator.defaultOptions.paginationSizeSelector=[10,25,50,100];Tabulator.defaultOptions.paginationCounter='rows';Tabulator.defaultOptions.paginationButtonCount=5;Tabulator.defaultOptions.locale=lang;if(!window.__s360TabulatorLangs){Tabulator.extendModule('localize','langs',Object.fromEntries(Object.entries(copy).map(([k,v])=>[k,{pagination:v}])));window.__s360TabulatorLangs=true;}document.querySelectorAll('.tabulator').forEach(el=>{try{const t=Tabulator.findTable(el)?.[0];t?.setLocale(lang)}catch{}})}
  function relocalize(){apply();if(!window.Tabulator)return;const t=window.Society360I18n?.translateText?.bind(window.Society360I18n);if(!t)return;document.querySelectorAll('.tabulator').forEach(el=>{try{const table=Tabulator.findTable(el)?.[0];if(!table)return;const source=table.__s360SourceColumns||table.getColumnDefinitions();const defs=source.map(c=>c.title?({...c,title:t(c.title)}):c);table.setColumns(defs);table.setOptions({placeholder:t('No matching records'),headerFilterPlaceholder:t('Filter...')});table.setLocale(language())}catch{}})}
  async function exportTableXlsx(el,id,moduleCode,button,overrideRows,overrideColumns,fileName){
    const table=Tabulator.findTable(el)?.[0];if(!table)return;
    // Server-paginated views (for example Customer Account sections) must pass
    // the complete, already-authorized filtered result set explicitly. Local
    // grids continue exporting all rows matching their active filters.
    const rows=Array.isArray(overrideRows)?overrideRows:table.getData('active');
    const t=window.Society360I18n?.translateText?.bind(window.Society360I18n)||((x)=>x);
    if(!rows.length){window.Society360I18n?.toast?.(t('No matching records to export.'),'info');return}
    const columns=(Array.isArray(overrideColumns)?overrideColumns:table.getColumns().map(c=>({field:c.getField(),title:c.getDefinition().title}))).filter(c=>c.field&&!String(c.field).startsWith('__'));
    if(!columns.length){window.Society360I18n?.toast?.(t('No exportable columns are available.'),'error');return}
    const bar=el.previousElementSibling?.classList.contains('s360-table-toolbar')?el.previousElementSibling:null;
    const original=button.textContent;button.disabled=true;button.textContent=t('Exporting…');
    try{
      const exportName=fileName||id;
      const response=await fetch('/api/society-admin/export/xlsx',{method:'POST',credentials:'same-origin',headers:{'Content-Type':'application/json'},body:JSON.stringify({moduleCode,fileName:'Society360-'+exportName,sheetName:exportName.slice(0,31),columns:columns.map(c=>({key:c.field,title:t(c.title)})),rows})});
      if(response.status===401){location.href='/login';return}
      if(!response.ok){const body=await response.json().catch(()=>({}));throw new Error(body.message||'Excel export failed.')}
      const blob=await response.blob(),url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='Society360-'+exportName+'.xlsx';document.body.appendChild(a);a.click();a.remove();URL.revokeObjectURL(url);
      window.Society360I18n?.toast?.(t('Export successful.'),'success');
    }catch(err){window.Society360I18n?.toast?.(t(err.message||'Excel export failed.'),'error')}
    finally{button.disabled=false;button.textContent=t('Export to Excel')}
  }
  window.exportTabulatorXlsx=window.exportTabulatorXlsx||((id,button,rows,columns,moduleCode,fileName)=>exportTableXlsx(document.getElementById(id),id,moduleCode||'CRM_CUSTOMER_ACCOUNT',button,rows,columns,fileName));
  window.ensureTableExportToolbar=window.ensureTableExportToolbar||function(el,id,moduleCode){
    if(!el||!el.parentNode)return;
    let bar=el.previousElementSibling;
    if(!bar?.classList.contains('s360-table-toolbar')){bar=document.createElement('div');bar.className='s360-table-toolbar';bar.dataset.forTable=id;el.parentNode.insertBefore(bar,el)}
    if(moduleCode)bar.dataset.moduleCode=moduleCode;
    let button=bar.querySelector('.s360-export-xlsx');
    if(!button){button=document.createElement('button');button.type='button';button.className='s360-export-xlsx';button.addEventListener('click',()=>exportTableXlsx(el,id,bar.dataset.moduleCode||'CRM_CUSTOMER_ACCOUNT',button));bar.appendChild(button)}
    const t=window.Society360I18n?.translateText?.bind(window.Society360I18n)||((x)=>x);button.textContent=t('Export to Excel');button.title=button.textContent;button.setAttribute('aria-label',button.textContent);
  };
  apply();window.addEventListener('society360-language-changed',()=>{relocalize();document.querySelectorAll('.s360-export-xlsx').forEach(b=>{const t=window.Society360I18n?.translateText?.bind(window.Society360I18n)||((x)=>x);b.textContent=t('Export to Excel');b.title=b.textContent;b.setAttribute('aria-label',b.textContent)})});
})();
