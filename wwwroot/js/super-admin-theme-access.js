(function(){
'use strict';
const root=document.querySelector('#themes');
let csrfToken='';
async function csrf(){const r=await fetch('/api/security/csrf',{credentials:'same-origin',cache:'no-store'});if(!r.ok)throw new Error('Unable to obtain security token');const x=await r.json();csrfToken=x.token; if(!csrfToken)throw new Error('Security token missing');}
function esc(s){return String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
async function load(){
 const me=await fetch('/api/auth/me',{credentials:'same-origin',cache:'no-store'});if(!me.ok){location.href='/login';return;}
 const mx=await me.json();if(mx.session.roleCode!=='SUPER_ADMIN'){location.href='/';return;}
 const r=await fetch('/api/platform/theme-access-policy',{credentials:'same-origin',cache:'no-store'});if(!r.ok)throw new Error(r.status===403?'Super Admin permission required':'Unable to load theme policies');
 const data=await r.json();render(data);
}
function render(data){
 root.innerHTML='';
 data.themes.forEach(theme=>{
  const card=document.createElement('section');card.className='theme';card.dataset.code=theme.themeCode;
  const plans=(data.plans||[]).map(p=>'<label class="plan"><input type="checkbox" value="'+esc(p.planCode)+'" '+((theme.allowedPlanCodes||[]).includes(p.planCode)?'checked':'')+'>'+esc(p.planName)+'</label>').join('');
  card.innerHTML='<div><div class="name">'+esc(theme.themeName)+'</div><div class="meta">'+esc(theme.themeCode)+' ? '+(theme.isCommercial?'Commercial / Premium':'Standard')+'</div></div>'+
   '<div><div class="mode"><label>Access mode</label><select class="mode-select"><option value="FREE">Free for all societies</option><option value="PAID">Paid ? selected plans only</option></select></div>'+
   '<div class="plans" style="margin-top:10px">'+plans+'</div><div class="status" aria-live="polite"></div></div>'+
   '<div><button class="save" type="button">Save policy</button></div>';
  card.querySelector('.mode-select').value=theme.accessMode;
  const updatePlans=()=>{const paid=card.querySelector('.mode-select').value==='PAID';card.querySelector('.plans').style.opacity=paid?'1':'.45';card.querySelectorAll('.plans input').forEach(x=>x.disabled=!paid);};
  card.querySelector('.mode-select').addEventListener('change',updatePlans);updatePlans();
  card.querySelector('.save').addEventListener('click',()=>save(card));
  root.append(card);
 });
}
async function save(card){
 const button=card.querySelector('.save'),status=card.querySelector('.status'),mode=card.querySelector('.mode-select').value;
 const allowedPlanCodes=[...card.querySelectorAll('.plans input:checked')].map(x=>x.value);
 if(mode==='PAID'&&!allowedPlanCodes.length){status.textContent='Select at least one plan for paid access.';status.className='status error';return;}
 button.disabled=true;status.textContent='Saving?';status.className='status';
 try{
  if(!csrfToken)await csrf();
  const r=await fetch('/api/platform/theme-access-policy',{method:'PUT',credentials:'same-origin',headers:{'Content-Type':'application/json','X-CSRF-TOKEN':csrfToken,Accept:'application/json'},body:JSON.stringify({themeCode:card.dataset.code,accessMode:mode,allowedPlanCodes,remark:'Updated by Super Admin in Theme Access & Plans'})});
  const x=await r.json().catch(()=>({}));if(!r.ok)throw new Error(x.message||'Save failed ('+r.status+')');
  status.textContent='Saved successfully';status.className='status';
 }catch(e){status.textContent=e.message;status.className='status error';}
 finally{button.disabled=false;}
}
document.addEventListener('DOMContentLoaded',()=>{load().catch(e=>{root.textContent=e.message;root.className='error';});if(window.Society360I18n)window.Society360I18n.init();});
window.addEventListener('society360-language-changed',()=>window.Society360I18n?.apply());
})();