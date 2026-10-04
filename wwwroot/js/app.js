(async function ensureAuthenticated(){
  try{
    const r=await fetch('/api/auth/me',{cache:'no-store'});
    if(!r.ok){location.href='/login';return;}
    const x=await r.json();
    window.Society360Session=x;
    const user=document.querySelector('#dashboardUser'); if(user) user.textContent=x.session.displayName;
    const dashboardAdmin=document.querySelector('#dashboardAdminName'); if(dashboardAdmin) dashboardAdmin.textContent=x.session.displayName;
    const dashboardAvatar=document.querySelector('#dashboardAvatar'); if(dashboardAvatar) dashboardAvatar.textContent=x.session.displayName.split(' ').map(v=>v[0]).slice(0,2).join('').toUpperCase();
    const name=document.querySelector('.topbar h1');
    if(name) name.querySelector('#dashboardUser').textContent=x.session.displayName;
    const admin=document.querySelector('.admin b');
    if(admin) admin.textContent=x.session.displayName;
    const role=document.querySelector('.admin small');
    if(role) role.textContent=x.session.roleCode.replaceAll('_',' ');
    const society=x.societies.find(s=>s.societyId===x.session.societyId) || x.societies[0];
    const societyName=document.querySelector('.society-switch b');
    if(societyName) societyName.textContent=society ? society.societyName : 'All Societies';
  }catch{location.href='/login';}
})();
async function loadSystemHealth(){
  try{
    const r=await fetch('/api/health',{cache:'no-store'});
    const h=await r.json();
    const live=document.querySelector('.live');
    live.innerHTML='<span></span><span>'+Society360I18n.t('liveSystem')+'</span>';
  }catch{
    document.querySelector('.live').innerHTML='<span style="background:#ef6b77"></span><span>'+Society360I18n.t('apiUnavailable')+'</span>';
  }
}
function clock(){const d=new Date();document.querySelector('#clock').textContent=d.toLocaleDateString(Society360I18n.locale(),{weekday:'short',day:'2-digit',month:'short',year:'numeric'})+' · '+d.toLocaleTimeString(Society360I18n.locale(),{hour:'2-digit',minute:'2-digit',second:'2-digit'});}
function refreshLocalized(){Society360I18n.apply();Society360I18n.apply();loadSystemHealth();clock();}
Society360I18n.init();
document.querySelector('#language-select').addEventListener('change',e=>Society360I18n.setLanguage(e.target.value));
window.addEventListener('society360-language-changed',refreshLocalized);
clock();setInterval(clock,1000);loadSystemHealth();
document.querySelectorAll('nav a').forEach(a=>a.addEventListener('click',()=>{document.querySelectorAll('nav a').forEach(x=>x.classList.remove('active'));a.classList.add('active');}));
// The dashboard action is intentionally not a fake success. Module actions are wired by their operational screens.
