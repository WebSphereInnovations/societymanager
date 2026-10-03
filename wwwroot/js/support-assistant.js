(function(){
'use strict';
function boot(){
 if(document.getElementById('society360-support')) return;
 const root=document.createElement('div'); root.id='society360-support';
 root.innerHTML='<button class="support-launch" type="button" aria-label="Support Assistant">?</button><section class="support-panel"><header class="support-head"><strong>Support Assistant</strong><button class="support-close" type="button">×</button></header><div class="support-body"><div class="support-search"><input id="supportQuery" placeholder="Ask a question..."></div><div id="supportList"></div></div><footer class="support-foot">Private customer data is not shown here.</footer></section>';
 document.body.appendChild(root);
 const query=root.querySelector('#supportQuery'), list=root.querySelector('#supportList'); let timer=0;
 const esc=v=>String(v||'').replace(/[&<>\"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;',"'":'&#39;'}[m]));
 const lang=()=>window.Society360I18n?.current||document.documentElement.lang||'en';
 async function load(q){
  list.innerHTML='<div class="support-state">Loading...</div>';
  try{const r=await fetch('/api/support/faq?lang='+encodeURIComponent(lang())+'&q='+encodeURIComponent(q||''),{cache:'no-store'});if(!r.ok)throw 0;const rows=await r.json();list.innerHTML=rows.length?rows.map(x=>'<article class="support-item"><b>'+esc(x.question)+'</b><div class="support-answer">'+esc(x.answer)+'</div></article>').join(''):'<div class="support-state">No matching answer found.</div>';list.querySelectorAll('.support-item').forEach(x=>x.onclick=()=>x.classList.toggle('selected'));}
  catch{list.innerHTML='<div class="support-state">Support answers are temporarily unavailable.</div>';}
 }
 root.querySelector('.support-launch').onclick=()=>{root.classList.add('open');load(query.value);setTimeout(()=>query.focus(),30)};
 root.querySelector('.support-close').onclick=()=>root.classList.remove('open');
 query.oninput=()=>{clearTimeout(timer);timer=setTimeout(()=>load(query.value.trim()),250)};
 window.addEventListener('society360-language-changed',()=>{if(root.classList.contains('open'))load(query.value.trim())});
}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot);else boot();
})();