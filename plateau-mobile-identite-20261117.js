/* Barre de personnage mobile : valeurs issues des éléments métier, jamais simulées. */
(() => {
 'use strict';
 const panel=document.getElementById('hg-mobile-identite-20261117');
 if (!panel) return;
 const src={
   name:document.getElementById('char-fullname-left'),
   role:document.getElementById('char-arch-left'),
   portrait:document.getElementById('char-photo-left'),
   pa:document.getElementById('r-pa'),
   cash:document.getElementById('r-arg'),
   health:document.getElementById('r-hp'),
   moral:document.getElementById('r-moral')
 };
 const dst={
   name:document.getElementById('hg-identite-personnage'),
   role:document.getElementById('hg-identite-role'),
   portrait:document.getElementById('hg-identite-portrait'),
   pa:document.getElementById('hg-identite-pa'),
   cash:document.getElementById('hg-identite-argent'),
   health:document.getElementById('hg-identite-sante'),
   moral:document.getElementById('hg-identite-moral')
 };
 function write(el,label,val){
   if (!el)return;
   el.textContent='';
   const small=document.createElement('small');small.textContent=label;
   el.append(small,document.createTextNode(val||'—'));
 }
 function update(){
   const name=src.name?.textContent?.trim()||'';
   const active=name && name!=='Mon Personnage';
   dst.name.textContent=active?name:'Personnage';
   dst.role.textContent=active?(src.role?.textContent?.trim()||''):'';
   write(dst.pa,'PA',active?(src.pa?.textContent?.trim()||'—'):'—');
   write(dst.cash,'Argent',active?(src.cash?.textContent?.trim()||'—'):'—');
   for(const [key,label] of [['health','Santé'],['moral','Moral']]){
     const raw=src[key]?.textContent?.trim()||'';
     const good=active && /^\d+(?:[.,]\d+)?$/.test(raw);
     // Toujours visibles (Fred, 23/11/2026, point 4) : « — » tant que la valeur du serveur n'est pas lue.
     dst[key].hidden=false;
     write(dst[key],label,good?raw+' %':'—');
   }
   const photo=active?src.portrait?.querySelector('img'):null;
   const shown=dst.portrait?.querySelector('img');
   if(photo?.getAttribute('src')){
     if(!shown || shown.src!==photo.src){
       const img=document.createElement('img');
       img.src=photo.src;img.alt='';
       dst.portrait.replaceChildren(img);
     }
   }else if(shown){
     const fallback=document.createElement('i');fallback.className='ti ti-user';
     dst.portrait.replaceChildren(fallback);
   }
 }
 const observed=Object.values(src).filter(Boolean);
 for(const node of observed)new MutationObserver(update).observe(node,{subtree:true,childList:true,characterData:true,attributes:node===src.portrait,attributeFilter:node===src.portrait?['src','style']:undefined});
 update();
})();
