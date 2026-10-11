(function(){
'use strict';
const side=document.querySelector('.side');
const nav=document.querySelector('#dbMenu');
const layoutSelect=document.querySelector('#navigationLayoutSelect');
const settingsButton=document.querySelector('#navSettingsToggle');
const settingsPanel=document.querySelector('#navSettingsPanel');
const collapseButton=document.querySelector('#navCollapseToggle');
const mobileToggle=document.querySelector('#mobileMenuToggle');
const allowedLayouts=new Set(['left','right','top']);
const layoutKey='society360-navigation-layout';
const collapsedKey='society360-navigation-collapsed';
if(!side||!nav||!layoutSelect||!settingsButton||!settingsPanel||!collapseButton)return;
let layout='left';
let collapsed=false;
const t=(key)=>window.Society360I18n?.translateText?.(key)||key;
function validLayout(value){return allowedLayouts.has(value)?value:'left';}
function applyLayout(value,save=true){
 layout=validLayout(value);
 if(save){try{localStorage.setItem(layoutKey,layout)}catch{}}
 document.body.classList.remove('nav-layout-left','nav-layout-right','nav-layout-top');
 document.body.classList.add('nav-layout-'+layout);
 document.body.classList.toggle('nav-collapsed',collapsed&&layout!=='top');
 side.classList.remove('nav-layout-left','nav-layout-right','nav-layout-top');
 side.classList.add('nav-layout-'+layout);
 side.dataset.navLayout=layout;
 layoutSelect.value=layout;
 collapseButton.hidden=layout==='top';
 side.classList.toggle('nav-collapsed',collapsed&&layout!=='top');
 collapseButton.dataset.i18n=collapsed?'Expand sidebar':'Collapse sidebar';
 collapseButton.textContent=t(collapseButton.dataset.i18n);
 collapseButton.setAttribute('aria-expanded',String(!collapsed));
 collapseButton.setAttribute('aria-label',t(collapseButton.dataset.i18n));
 side.classList.remove('mobile-open');
 document.querySelector('#mobileMenuBackdrop')?.classList.remove('visible');
 mobileToggle?.setAttribute('aria-expanded','false');
 closeOpenGroups();
}
function applyCollapsed(value,save=true){
 collapsed=Boolean(value);
 if(save){try{localStorage.setItem(collapsedKey,collapsed?'1':'0')}catch{}}
 side.classList.toggle('nav-collapsed',collapsed&&layout!=='top');
 document.body.classList.toggle('nav-collapsed',collapsed&&layout!=='top');
 collapseButton.dataset.i18n=collapsed?'Expand sidebar':'Collapse sidebar';
 collapseButton.textContent=t(collapseButton.dataset.i18n);
 collapseButton.setAttribute('aria-expanded',String(!collapsed));
 collapseButton.setAttribute('aria-label',t(collapseButton.dataset.i18n));
}
function closeOpenGroups(except){
 nav.querySelectorAll('details[open]').forEach(group=>{if(group!==except&&!group.contains(except))group.open=false;});
}
function closeSettings(restoreFocus=false){
 settingsPanel.hidden=true;settingsButton.setAttribute('aria-expanded','false');
 if(restoreFocus)settingsButton.focus();
}
function toggleSettings(){
 const open=settingsPanel.hidden;
 settingsPanel.hidden=!open;settingsButton.setAttribute('aria-expanded',String(open));
 if(open)layoutSelect.focus();
}
function positionSubmenu(group){
 if(layout!=='top'||!group)return;
 const submenu=group.querySelector(':scope > .nav-submenu');if(!submenu)return;
 const rect=group.getBoundingClientRect(),topLevel=group.parentElement===nav;
 const width=Math.min(window.innerWidth<=760?300:260,window.innerWidth-24);
 if(window.innerWidth<=760){
  const top=topLevel?Math.min(rect.bottom+7,window.innerHeight-140):Math.max(8,Math.min(rect.top,window.innerHeight-140));
  const left=topLevel?Math.max(12,Math.min(rect.left,window.innerWidth-width-12)):(rect.right+width<=window.innerWidth-12?rect.right+4:Math.max(12,rect.left-width-4));
  submenu.style.position='fixed';submenu.style.top=top+'px';submenu.style.left=left+'px';submenu.style.right='auto';submenu.style.width=width+'px';submenu.style.maxHeight=Math.max(120,window.innerHeight-top-12)+'px';
  submenu.dataset.align=left+width>window.innerWidth-12?'right':'left';
  return;
 }
 ['position','top','left','right','width','maxHeight'].forEach(key=>submenu.style[key]='');
 if(topLevel)submenu.dataset.align=(rect.left+width>window.innerWidth-12)?'right':'left';
 else submenu.dataset.align=(rect.right+width>window.innerWidth-12)?'left':'right';
}
function onNavigate(){
 if(layout==='top')closeOpenGroups();
 side.classList.remove('mobile-open');
 document.querySelector('#mobileMenuBackdrop')?.classList.remove('visible');
 mobileToggle?.setAttribute('aria-expanded','false');
}
settingsButton.addEventListener('click',toggleSettings);
layoutSelect.addEventListener('change',()=>applyLayout(layoutSelect.value));
collapseButton.addEventListener('click',()=>applyCollapsed(!collapsed));
document.addEventListener('click',event=>{
 if(!settingsPanel.hidden&&!event.target.closest('.nav-preferences'))closeSettings(false);
});
document.addEventListener('keydown',event=>{
 if(event.key==='Escape'){
  const openGroup=nav.querySelector('details[open]');
  if(openGroup){const summary=openGroup.querySelector(':scope > summary');closeOpenGroups();summary?.focus();event.preventDefault();return;}
  if(!settingsPanel.hidden){closeSettings(true);event.preventDefault();return;}
 }
 if(layout==='top'&&(event.key==='ArrowRight'||event.key==='ArrowLeft')){
  const current=event.target.closest('#dbMenu > button, #dbMenu > details > summary');
  if(!current)return;
  const items=Array.from(nav.children).map(el=>el.matches('details')?el.querySelector(':scope > summary'):el).filter(Boolean);
  const index=items.indexOf(current);if(index<0)return;
  const next=items[(index+(event.key==='ArrowRight'?1:-1)+items.length)%items.length];next?.focus();event.preventDefault();
 }
 if(event.key==='ArrowDown'&&event.target.matches('#dbMenu summary')){
  const group=event.target.parentElement;group.open=true;positionSubmenu(group);
  const first=group.querySelector('.nav-submenu button, .nav-submenu summary');first?.focus();event.preventDefault();
 }
});
nav.addEventListener('focusin',event=>{
 if(layout!=='top')return;
 const group=event.target.closest?.('#dbMenu details');
 if(group?.open){closeOpenGroups(group);positionSubmenu(group);}
});
window.addEventListener('resize',()=>nav.querySelectorAll('details[open]').forEach(positionSubmenu));
window.addEventListener('society360-language-changed',()=>{
 collapseButton.textContent=t(collapseButton.dataset.i18n||'Collapse sidebar');
 collapseButton.setAttribute('aria-label',collapseButton.textContent);
 settingsButton.setAttribute('aria-label',settingsButton.textContent);
 nav.setAttribute('aria-label',t('Application navigation'));
});
window.NavigationLayout={applyLayout,applyCollapsed,positionSubmenu,onNavigate,get layout(){return layout},get collapsed(){return collapsed}};
let savedLayout='left',savedCollapsed=false;
try{savedLayout=validLayout(localStorage.getItem(layoutKey)||'left');savedCollapsed=localStorage.getItem(collapsedKey)==='1';}catch{}
collapsed=savedCollapsed;applyLayout(savedLayout,false);applyCollapsed(savedCollapsed,false);
})();
