(function(){
'use strict';
function boot(){
 if(document.getElementById('society360-support')) return;
 const root=document.createElement('div');root.id='society360-support';
 root.innerHTML='<button class="support-launch" aria-label="Support Assistant" title="Support Assistant">?</button>'+
 '<section class="support-panel" role="dialog" aria-label="Support Assistant">'+
 '<header class="support-head"><div><strong>Support Assistant</strong><small>Help for common Society360 tasks</small></div><button class="support-close" type="button" aria-label="Close">×</button></header>'+
 '<div class="support-body"><div class="support-search"><input id="supportQuery" autocomplete="off" placeholder="Ask a question..."></div><div id="supportList" class="support-list"></div></div>'+
 '<footer class="support-foot">Answers are configuration-based. Private customer data is not shown here.</footer></section>';
 document.body.appendChild(root);
 const panel=root.querySelector('.support-panel'),query=root.querySelector('#supportQuery'),list=root.querySelector('#supportList');
 let timer=0;
 function lang(){return window.Society360I18n?.current || document.documentElement.lang || 'en'}
 function esc(v){return String(v??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]))}
 async function load(q=''){
  list.innerHTML='<div class="support-state">Loading...</div>';
  try{
   const r=await fetch('/api/support/faq?lang='+encodeURIComponent(lang())+'&q='+encodeURIComponent(q),{cache:'no-store'});
   if(!r.ok) throw new Error();
   const rows=await r.json();
   list.innerHTML=rows.length?rows.map((x,i)=>'<article class="support-item" data-i="'+i+'"><b>'+esc(x.question)+'</b><div class="support-answer">'+esc(x.answer)+'</div></article>').join(''):'<div class="support-state">No matching answer found. Try words like payment, visitor, complaint, dues or receipt.</div>';
   list.querySelectorAll('.support-item').forEach(el=>el.onclick=()=>el.classList.toggle('selected'));
  }catch{list.innerHTML='<div class="support-state">Support answers are temporarily unavailable. Please try again.</div>'}
 }
 root.querySelector('.support-launch').onclick=()=>{root.classList.add('open');load(query.value);setTimeout(()=>query.focus(),30)};
 root.querySelector('.support-close').onclick=()=>root.classList.remove('open');
 query.oninput=()=>{clearTimeout(timer);timer=setTimeout(()=>load(query.value.trim()),250)};
 window.addEventListener('society360-language-changed',()=>{if(root.classList.contains('open'))load(query.value.trim())});
}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot);else boot();
})();