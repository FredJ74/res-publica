/* Bandeau mobile : seules des valeurs du personnage déjà affichées dans le DOM. */
(() => {
  'use strict';
  const panel=document.getElementById('hg-mobile-identite-20261117');
  if(!panel) return;
  const sources=[
    [document.getElementById('char-fullname-left'),document.getElementById('hg-identite-personnage')],
    [document.getElementById('r-pa'),document.getElementById('hg-identite-pa')],
    [document.getElementById('r-arg'),document.getElementById('hg-identite-argent')]
  ];
  function update(){
    for(const [source,dest] of sources){
      if(!source||!dest)continue;
      const raw=source.textContent?.trim();
      if(!raw)continue;
      dest.textContent=(dest.id==='hg-identite-pa'?'PA ':'')+raw;
    }
  }
  sources.forEach(([source])=>source&&new MutationObserver(update).observe(source,{childList:true,subtree:true,characterData:true}));
  update();
})();
