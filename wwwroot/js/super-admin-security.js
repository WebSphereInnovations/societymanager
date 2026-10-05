(function(){
'use strict';
const t=k=>window.Society360I18n?window.Society360I18n.t(k):k;
const msg=(id,key,err=false)=>{const e=document.querySelector(id);if(!e)return;e.textContent=t(key);e.className='msg'+(err?' err':'');e.dataset.i18nMessage=key;};
const apiMsg=(id,x,fallback,err)=>msg(id,x&&x.code||fallback,err);
async function me(){const r=await fetch('/api/auth/me',{cache:'no-store'});if(!r.ok){location.href='/login';return null}const x=await r.json();if(x.session.roleCode!=='SUPER_ADMIN'){location.href='/';return null}return x}
async function changeLogin(){
 const current=loginCurrent.value,n=newLogin.value.trim();
 if(!current||!n)return msg('#loginMsg','enterBothValues',true);
 const r=await fetch('/api/auth/change-login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({currentPassword:current,newLogin:n})});
 const x=await r.json();apiMsg('#loginMsg',x,r.ok?'updated':'operationFailed',!r.ok);
}
async function changePass(){
 const current=passCurrent.value,n=newPass.value,c=confirmPass.value;
 if(n!==c)return msg('#passMsg','passwordsDoNotMatch',true);
 const r=await fetch('/api/auth/change-password',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({currentPassword:current,newPassword:n})});
 const x=await r.json();apiMsg('#passMsg',x,r.ok?'updated':'operationFailed',!r.ok);
}
async function crypt(path){
 const value=connectionValue.value;if(!value)return msg('#connMsg','enterValue',true);
 const r=await fetch(path,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({value})});
 const x=await r.json();
 if(r.ok){connectionValue.value=x.value;msg('#connMsg','completedSuccessfully');}
 else apiMsg('#connMsg',x,'operationFailed',true);
}
document.addEventListener('DOMContentLoaded',()=>{
 document.querySelector('#changeLogin').onclick=changeLogin;
 document.querySelector('#changePass').onclick=changePass;
 document.querySelector('#protect').onclick=()=>crypt('/api/security/protect-connection');
 document.querySelector('#unprotect').onclick=()=>crypt('/api/security/unprotect-connection');
 window.Society360I18n.init();
 me();
});
window.addEventListener('society360-language-changed',()=>{if(window.Society360I18n)window.Society360I18n.apply();});
})();