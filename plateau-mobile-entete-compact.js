/* En-tête mobile compact. Reprend exclusivement l'identité et la sortie déjà présentes. */
(() => {
 'use strict';
 const top=document.getElementById('topbar');
 const logo=top?.querySelector('.logo');
 const identity=document.getElementById('hg-mobile-identite-20261117');
 const name=document.getElementById('hg-identite-personnage');
 const role=document.getElementById('hg-identite-role');
 const portrait=document.getElementById('hg-identite-portrait');
 const characterButton=top?.querySelector('[data-hg-panneau="personnage"]');
 const building=document.getElementById('vue-batiment');
 const exitOriginal=building?.querySelector('.sortir-btn');
 if(!top||!logo||!identity||!name||!role||!portrait||!characterButton||!building||!exitOriginal)return;
 const brand=document.createElement('button');
 brand.id='hg-mobile-brand';brand.type='button';
 brand.setAttribute('aria-label','Ouvrir mon personnage');
 const pic=document.createElement('span');pic.className='hg-mobile-brand-photo';pic.setAttribute('aria-hidden','true');
 const text=document.createElement('span');text.className='hg-mobile-brand-text';
 const title=document.createElement('strong');title.textContent='Human Gambit';
 const username=document.createElement('span');username.className='hg-mobile-brand-name';
 const position=document.createElement('span');position.className='hg-mobile-brand-role';
 text.append(title,username,position);brand.append(pic,text);
 logo.after(brand);
 brand.addEventListener('click',()=>characterButton.click());

 const exit=document.createElement('button');exit.id='hg-mobile-exit';exit.type='button';exit.className='hg-mobile-acces';
 const arrow=document.createElement('i');arrow.className='ti ti-arrow-left';arrow.setAttribute('aria-hidden','true');
 const exitLabel=document.createElement('span');exitLabel.textContent='Sortir';
 exit.append(arrow,exitLabel);exit.setAttribute('aria-label','Sortir du bâtiment');
 exit.addEventListener('click',()=>exitOriginal.click());
 characterButton.after(exit);

 const mobile=window.matchMedia('(max-width:1023px)');
 function sync(){
   const raw=name.textContent?.trim()||'';
   username.textContent=' : '+(raw&&raw!=='Personnage'?raw:'Personnage');
   position.textContent=role.textContent?.trim()||'';
   const img=portrait.querySelector('img');
   const original=pic.querySelector('img');
   if(img?.getAttribute('src')){
     if(!original||original.src!==img.src){
       const copy=document.createElement('img');copy.src=img.src;copy.alt='';
       pic.replaceChildren(copy);
     }
   }else if(original || !pic.children.length){
     const fallback=document.createElement('i');fallback.className='ti ti-user';pic.replaceChildren(fallback);
   }
 }
 function view(){
   const active=mobile.matches && building.classList.contains('active');
   exit.hidden=!active;
   top.classList.toggle('hg-building-view',active);
 }
 for(const node of [name,role,portrait])new MutationObserver(sync).observe(node,{childList:true,subtree:true,characterData:true});
 new MutationObserver(view).observe(building,{attributes:true,attributeFilter:['class']});
 mobile.addEventListener?.('change',view);
 sync();view();
})();
