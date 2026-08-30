
// =====================
// RETROUVER MON PERSONNAGE
// =====================
function retrouverPersonnage() {
  const panel = document.getElementById('retrouver-panel');
  panel.style.display = panel.style.display === 'none' ? 'block' : 'none';
}

async function chargerPersonnageParNom() {
  const nom = document.getElementById('retrouver-nom')?.value?.trim();
  const msg = document.getElementById('retrouver-msg');
  if (!nom) { msg.textContent = t('home.findCharacterEnterName'); return; }

  msg.style.color = '#8a8060';
  msg.textContent = t('home.findCharacterSearching');

  // Chercher dans Supabase
  if (typeof sbLoadPersonnage !== 'function') {
    msg.style.color = '#8a3a2a';
    msg.textContent = t('home.findCharacterUnavailable');
    return;
  }

  try {
    const sbState = await sbLoadPersonnage(nom);
    if (!sbState) {
      msg.style.color = '#8a3a2a';
      msg.textContent = t('home.findCharacterNotFound');
      return;
    }

    // Sauvegarder dans localStorage avec position complète
    const charData = {
      ...sbState.char,
      country: sbState.country,
      currentCity: sbState.currentCity,
      arg: sbState.arg,
      resources: { inf: sbState.inf, pop: sbState.pop, dis: sbState.dis }
    };
    try {
      localStorage.setItem('respublica_char_' + charData.name, JSON.stringify(charData));
      localStorage.setItem('respublica_char', JSON.stringify(charData));
    } catch (e) {
      console.warn('Cache local personnage non sauvegarde (quota depasse) :', e);
    }
    localStorage.setItem('respublica_last_char', charData.name);
    if (sbState.char?.photoUrl) {
      localStorage.setItem('respublica_photo_' + sbState.char.name, sbState.char.photoUrl);
      localStorage.setItem('respublica_photo', sbState.char.photoUrl);
    }

    msg.style.color = '#4a8a4a';
    msg.textContent = t('home.findCharacterFound', { name: nom });

    setTimeout(() => { window.location.href = 'plateau.html'; }, 1000);

  } catch(e) {
    msg.style.color = '#8a3a2a';
    msg.textContent = t('home.findCharacterConnectionError');
  }
}

/* ===========================
   RES PUBLICA — CREATION.JS
   =========================== */

// Accesseur defensif a i18next (Lot 2, i18n) : jamais un second moteur de traduction (i18next
// reste le seul), simplement un repli identique au style deja utilise partout dans ce code
// (typeof X === 'function') pour le cas, en pratique jamais observe vu l'ordre de chargement des
// scripts (index.html : i18next -> resources -> i18n-init -> data.js -> creation.js), ou
// i18next ne serait pas encore pret. Retombe sur la cle brute plutot que de planter l'ecran.
function t(key, opts) {
  return (typeof i18next !== 'undefined' && i18next.isInitialized) ? i18next.t(key, opts) : key;
}

let G = {
  country:null, origin:null, school:null, archetype:null, career:null,
  freeStats:{INT:0,CHA:0,VOL:0,PER:0,DUP:0,ENT:0}, freePts:30,
  photoUrl:null, name:'', bio:'', motto:''
};

/* ---- Navigation ---- */
// Ecran actuellement affiche (Lot 2 i18n) : suivi uniquement pour permettre le rafraichissement
// de l'ecran dynamique visible lors d'un changement de langue (voir
// rafraichirEcranCreationApresChangementLangue ci-dessous) -- n'affecte en rien la navigation
// normale, qui continue de fonctionner exactement comme avant.
let _currentScreenIndex=0;
function goTo(n){
  _currentScreenIndex=n;
  document.querySelectorAll('.screen').forEach(s=>s.classList.remove('active'));
  const ids=['intro','s1','s2','s3','s4','s5','s6','s7','s8','s9'];
  document.getElementById(ids[n]).classList.add('active');
  window.scrollTo(0,0);
  if(n===1) renderCountry();
  if(n===2) renderOrigin();
  if(n===3) renderSchool();
  if(n===4) renderArch();
  if(n===5) renderCareer();
  if(n===6) renderStatsUI();
  if(n===8) renderReview();
  if(n===9) renderSuccess();
  for(let i=1;i<=7;i++){
    const d=document.getElementById('dots'+i);
    if(d) d.innerHTML=Array.from({length:7},(_,j)=>
      `<div class="dot ${j<i-1?'dn':j===i-1?'act':''}"></div>`).join('');
  }
}

// Rafraichissement lors d'un changement de langue (Lot 2 i18n) : re-rend UNIQUEMENT l'ecran
// dynamique actuellement visible, en reutilisant exactement le meme aiguillage que goTo()
// ci-dessus -- jamais goTo() lui-meme (qui changerait d'ecran/reinitialiserait les dots). Les
// render*() appeles ici ne font que LIRE l'etat G existant et reecrire du HTML : aucune mutation
// de G, aucun tirage aleatoire, aucun appel a validateChar()/selCountry() etc. -- un choix deja
// fait, une statistique deja distribuee ou un champ deja saisi restent strictement inchanges.
// Expose sur window pour que i18n-init.js (generique, reutilisable sur d'autres pages) puisse
// l'appeler sans rien connaitre de la creation de personnage.
function rafraichirEcranCreationApresChangementLangue(){
  const n=_currentScreenIndex;
  if(n===1){
    renderCountry();
    // La modale de choix de ville est un ecran superpose, jamais re-rendu par goTo(1) lui-meme
    // (uniquement par selCountry()) -- si elle est ouverte au moment du changement de langue,
    // elle doit etre rafraichie aussi, sans quoi elle resterait dans l'ancienne langue.
    if(document.getElementById('modal-city')?.classList.contains('open')) renderCityChoice();
  }
  if(n===2) renderOrigin();
  if(n===3) renderSchool();
  if(n===4) renderArch();
  if(n===5) renderCareer();
  if(n===6) renderStatsUI();
  if(n===8) renderReview();
  if(n===9) renderSuccess();
}
window.RP_I18N_ON_LANGUAGE_CHANGE=rafraichirEcranCreationApresChangementLangue;

/* ---- Country ---- */
function renderCountry(){
  document.getElementById('country-grid').innerHTML=Object.entries(COUNTRIES).map(([id,d])=>{
    // d.n (nom propre : Republia, El Estado...) toujours lu tel quel depuis data.js, jamais
    // traduit (§3/§9 du chantier i18n) -- seuls tags/description passent par i18next, indexes
    // par l'id technique du pays, jamais par le nom affiche.
    const tags = t(`creation.countries.${id}.tags`, { returnObjects: true });
    const desc = t(`creation.countries.${id}.description`);
    return `
    <div class="cc ${G.country===id?'sel':''}" data-c="${id}" onclick="selCountry('${id}')">
      <div class="icon-c" style="border-color:${d.col};color:${d.col}">
        <i class="ti ${d.icon}" style="font-size:1.2rem"></i>
      </div>
      <div class="cname" style="color:${d.col}">${d.n}</div>
      <div style="margin-bottom:.6rem">
        ${(Array.isArray(tags)?tags:[]).map(tag=>`<span class="ctag" style="color:${d.col};border-color:${d.col}">${tag}</span>`).join('')}
      </div>
      <div class="cdesc">${desc}</div>
    </div>`;
  }).join('');
}
function selCountry(id){
  G.country=id;
  G.city=null;
  G.freeStats={INT:0,CHA:0,VOL:0,PER:0,DUP:0,ENT:0};
  G.freePts=30;
  renderCountry();
  renderCityChoice();
  document.getElementById('n1').disabled=true;
}

function renderCityChoice(){
  const modal = document.getElementById('modal-city');
  const grid = document.getElementById('city-grid');
  if (!G.country || !WORLD[G.country]) { modal.classList.remove('open'); return; }
  const villes = Object.entries(WORLD[G.country]).filter(([k,v]) => v && v.isCapitale !== undefined && !v.isSpecial);
  grid.innerHTML = villes.map(([key,v]) => {
    // v.name (nom propre : Luthecia, Montrouge...) jamais traduit -- seule la description passe
    // par i18next, indexee par pays + cle technique de ville (capitale/ville_a/ville_b).
    const desc = t(`creation.cities.${G.country}.${key}.description`);
    return `
    <div class="cc ${G.city===key?'sel':''}" onclick="selCity('${key}')" style="display:flex;gap:.9rem;align-items:center;text-align:left;padding:.8rem;cursor:pointer">
      ${v.imageUrl ? `<img src="${v.imageUrl}" style="width:110px;height:80px;object-fit:cover;border:1px solid #3a2a10;flex-shrink:0"/>` : ''}
      <div>
        <div class="cname">${v.name}${v.isCapitale ? ` <span style="font-size:.7rem;color:#8a8060">${t('creation.city.capitalBadge')}</span>` : ''}</div>
        <div class="cdesc">${desc || ''}</div>
      </div>
    </div>`;
  }).join('');
  modal.classList.add('open');
}

function selCity(key){
  G.city = key;
  document.getElementById('modal-city').classList.remove('open');
  document.getElementById('n1').disabled = !(G.country && G.city);
}

/* ---- Origin ---- */
function renderOrigin(){
  const cur=COUNTRIES[G.country]?.cur||'FR';
  document.getElementById('origin-grid').innerHTML=ORIGINS.map(o=>`
    <div class="oc ${G.origin===o.id?'sel':''}" onclick="selOrigin('${o.id}')">
      <div class="checkmark"><i class="ti ti-check"></i></div>
      <div class="oname"><i class="ti ${o.icon}" style="font-size:1rem;color:#8a6a20"></i> ${t('creation.origins.'+o.id+'.name')}</div>
      <div class="obonus">
        ${t('creation.common.capitalLabel')} : <strong>${o.arg.toLocaleString('fr-FR')} ${cur}</strong><br>
        ${Object.entries(o.bonuses).map(([k,v])=>`<strong>+${v} ${k}</strong>`).join('  ')}
        ${Object.entries(o.malus).map(([k,v])=>`<span style="color:#8a4020">${v} ${k}</span>`).join('  ')}
      </div>
      <div style="font-size:.72rem;color:#7a6040;margin-top:.3rem;font-style:italic">${t('creation.common.traitLabel')} : ${t('creation.origins.'+o.id+'.trait')}</div>
    </div>`).join('');
}
function selOrigin(id){
  G.origin=id;
  renderOrigin();
  document.getElementById('n2').disabled=false;
}

/* ---- School ---- */
function renderSchool(){
  const cur=COUNTRIES[G.country]?.cur||'FR';
  document.getElementById('school-grid').innerHTML=SCHOOLS.map(s=>`
    <div class="oc ${G.school===s.id?'sel':''}" onclick="selSchool('${s.id}')">
      <div class="checkmark"><i class="ti ti-check"></i></div>
      <div class="oname"><i class="ti ${s.icon}" style="font-size:1rem;color:#8a6a20"></i> ${t('creation.schools.'+s.id+'.name')}</div>
      <div class="obonus">
        ${s.argBonus?`<strong>+${s.argBonus.toLocaleString('fr-FR')} ${cur}</strong><br>`:''}
        ${Object.entries(s.bonuses).map(([k,v])=>`<strong>+${v} ${k}</strong>`).join('  ')}
        ${Object.entries(s.malus||{}).map(([k,v])=>`<span style="color:#8a4020">${v} ${k}</span>`).join('  ')}
      </div>
      <div class="oblock"><i class="ti ti-lock" style="font-size:.7rem;vertical-align:-1px"></i> ${t('creation.schools.'+s.id+'.blockLabel')}</div>
    </div>`).join('');
}
function selSchool(id){
  G.school=id;
  G.career=null;
  renderSchool();
  document.getElementById('n3').disabled=false;
}

/* ---- Archetype ---- */
function renderArch(){
  const cur=COUNTRIES[G.country]?.cur||'FR';
  document.getElementById('arch-grid').innerHTML=ARCHETYPES.map(a=>`
    <div class="oc ${G.archetype===a.id?'sel':''}" onclick="selArch('${a.id}')">
      <div class="checkmark"><i class="ti ti-check"></i></div>
      <div class="oname"><i class="ti ${a.icon}" style="font-size:1rem;color:#8a6a20"></i> ${t('creation.archetypes.'+a.id+'.name')}</div>
      <div class="odesc">${t('creation.archetypes.'+a.id+'.description')}</div>
      <div class="obonus">
        ${Object.entries(a.bonuses).map(([k,v])=>`<strong>+${v} ${k}</strong>`).join('  ')}
        ${Object.entries(a.malus).map(([k,v])=>`<span style="color:#8a4020">${v} ${k}</span>`).join('  ')}<br>
        ${t('creation.common.capitalLabel')} : <strong>+${a.argBonus.toLocaleString('fr-FR')} ${cur}</strong>
      </div>
    </div>`).join('');
}
function selArch(id){
  G.archetype=id;
  renderArch();
  document.getElementById('n4').disabled=false;
}

/* ---- Career ---- */
function isBlocked(c){
  if(!G.school) return false;
  return c.blocks.includes(G.school);
}
function renderCareer(){
  const cur=COUNTRIES[G.country]?.cur||'FR';
  document.getElementById('career-grid').innerHTML=CAREERS.map(c=>{
    const bl=isBlocked(c);
    return`<div class="oc ${G.career===c.id?'sel':''} ${bl?'locked':''}"
      onclick="${bl?'':` selCareer('${c.id}')`}"
      title="${bl?t('creation.career.locked'):''}">
      <div class="checkmark"><i class="ti ti-check"></i></div>
      <div class="oname"><i class="ti ${c.icon}" style="font-size:1rem;color:#8a6a20"></i> ${t('creation.careers.'+c.id+'.name')}</div>
      <div class="obonus">+${c.argBonus.toLocaleString('fr-FR')} ${cur} &middot; <strong>+1 ${c.statKey}</strong></div>
      <div class="odesc" style="margin-top:.3rem">${t('creation.careers.'+c.id+'.comp')}</div>
    </div>`;
  }).join('');
  const sc=SCHOOLS.find(x=>x.id===G.school);
  document.getElementById('career-info').textContent=
    sc?t('creation.career.info',{school:t('creation.schools.'+sc.id+'.name')}):'';
}
// Revalidation cote logique (bêta, faille corrigee) : isBlocked() ne protegeait jusqu'ici que
// l'affichage (onclick vide sur une carte bloquee) -- selCareer() elle-meme ne verifiait rien,
// donc appelable directement depuis la console (ex. selCareer('business') sans le bon niveau
// d'etudes) pour contourner le prerequis. Desormais revalidee ici, au meme titre que l'IHM.
function selCareer(id){
  const c=CAREERS.find(x=>x.id===id);
  if(!c || isBlocked(c)) return;
  G.career=id;
  renderCareer();
  document.getElementById('n5').disabled=false;
}

/* ---- Stats ---- */
function getBase(k){
  const co=COUNTRIES[G.country]?.bases||{INT:8,CHA:7,VOL:6,PER:7,DUP:7,ENT:7};
  const or=ORIGINS.find(x=>x.id===G.origin);
  const sc=SCHOOLS.find(x=>x.id===G.school);
  const ar=ARCHETYPES.find(x=>x.id===G.archetype);
  const ca=CAREERS.find(x=>x.id===G.career);
  let v=co[k]||8;
  if(or){v+=(or.bonuses[k]||0)+(or.malus[k]||0)}
  if(sc){v+=(sc.bonuses[k]||0)+(sc.malus[k]||0)}
  if(ar){v+=(ar.bonuses[k]||0)+(ar.malus[k]||0)}
  if(ca&&ca.statKey===k) v+=1;
  return Math.max(1,v);
}
function getBonus(k){
  const co=COUNTRIES[G.country]?.bases||{INT:8,CHA:7,VOL:6,PER:7,DUP:7,ENT:7};
  return getBase(k)-(co[k]||8);
}

function renderStatsUI(){
  document.getElementById('stats-wrap').innerHTML=STAT_DEFS.map(({k,i})=>{
    const base=getBase(k), free=G.freeStats[k]||0, eff=Math.min(20,base+free), bonus=getBonus(k);
    return`<div class="srow">
      <div>
        <div class="sname"><i class="ti ${i}" style="font-size:.9rem;vertical-align:-1px;margin-right:.3rem"></i>${t('creation.stats.'+k+'.name')}</div>
        <div class="sdesc">${t('creation.stats.'+k+'.description')}</div>
        <div class="sbar"><div class="sbarfill" style="width:${(eff/20)*100}%"></div></div>
      </div>
      <div class="sbonus">${bonus>0?`+${bonus} ${t('creation.common.bonusSuffix')}`:bonus<0?`${bonus} ${t('creation.common.malusSuffix')}`:''}</div>
      <div class="sadj">
        <button class="sbtn" onclick="adjStat('${k}',-1)" ${free<=0?'disabled':''}>-</button>
        <span class="sval">${eff}</span>
        <button class="sbtn" onclick="adjStat('${k}',1)" ${G.freePts<=0||base+free>=16?'disabled':''}>+</button>
      </div>
    </div>`;
  }).join('');
  document.getElementById('pts-left').textContent=G.freePts;
  // Reliquat (bêta) : avertissement clair mais NON bloquant -- aucun point n'est disabled sur
  // le bouton "Suivant" (id="n6", index.html), tout comme aujourd'hui. Le reliquat eventuel
  // est sauvegarde (char.freePtsRestants, validateChar) et reste distribuable plus tard depuis
  // la fiche de personnage (onglet Statistiques).
  const ptsWarn=document.getElementById('pts-warning');
  if(ptsWarn){
    if(G.freePts>0){
      ptsWarn.style.display='block';
      // Pluriel gere par i18next (_one/_other, cle "count") -- jamais la notation "(s)" figee
      // de l'ancien texte francais, qui ne peut pas se traduire proprement en anglais.
      ptsWarn.textContent=t('creation.steps.stats.warning',{count:G.freePts});
    } else {
      ptsWarn.style.display='none';
    }
  }
}
function adjStat(k,dir){
  const base=getBase(k), free=G.freeStats[k]||0;
  if(dir<0&&free<=0) return;
  if(dir>0&&base+free>=16) return;
  const cur=base+free, cost=dir>0?(cur>=12?2:1):(cur>12?2:1);
  if(dir>0&&G.freePts<cost) return;
  G.freeStats[k]=free+dir;
  G.freePts-=dir*cost;
  renderStatsUI();
}

/* ---- Identity ---- */
function handlePhoto(inp){
  const f=inp.files[0]; if(!f) return;
  const r=new FileReader();
  r.onload=e=>{
    G.photoUrl=e.target.result;
    document.getElementById('pprev').innerHTML=`<img src="${G.photoUrl}" class="pphoto" alt="Photo de profil"/>`;
  };
  r.readAsDataURL(f);
}
function chkId(){
  G.name=document.getElementById('cname').value.trim();
  G.bio=document.getElementById('cbio').value.trim();
  document.getElementById('n7').disabled=!G.name||!G.bio;
}

/* ---- Review ---- */
function palier(a){
  if(a<600)  return t('creation.review.wealthTier1');
  if(a<1500) return t('creation.review.wealthTier2');
  if(a<3500) return t('creation.review.wealthTier3');
  if(a<7000) return t('creation.review.wealthTier4');
  return t('creation.review.wealthTier5');
}

function totalArg(){
  const or=ORIGINS.find(x=>x.id===G.origin);
  const sc=SCHOOLS.find(x=>x.id===G.school);
  const ar=ARCHETYPES.find(x=>x.id===G.archetype);
  const ca=CAREERS.find(x=>x.id===G.career);
  return (or?.arg||0)+(sc?.argBonus||0)+(ar?.argBonus||0)+(ca?.argBonus||0);
}
function resources(){
  const ar=ARCHETYPES.find(x=>x.id===G.archetype);
  return{
    inf:Math.min(100,10+(ar?.infBonus||0)),
    pop:Math.min(100,10+(ar?.popBonus||0)),
    dis:Math.min(100,80+(ar?.disBonus||0))
  };
}

function renderReview(){
  G.name=document.getElementById('cname').value.trim();
  G.bio=document.getElementById('cbio').value.trim();
  G.motto=document.getElementById('cmotto').value.trim();
  const co=COUNTRIES[G.country];
  const or=ORIGINS.find(x=>x.id===G.origin);
  const sc=SCHOOLS.find(x=>x.id===G.school);
  const ar=ARCHETYPES.find(x=>x.id===G.archetype);
  const ca=CAREERS.find(x=>x.id===G.career);
  const eff={};
  STAT_DEFS.forEach(({k})=>{eff[k]=Math.min(20,getBase(k)+(G.freeStats[k]||0))});
  const arg=totalArg(), res=resources();
  const photo=G.photoUrl
    ?`<img src="${G.photoUrl}" class="rphoto" alt="Photo"/>`
    :`<div class="rphoto"><i class="ti ti-user" style="font-size:2rem"></i></div>`;
  const arName=ar?t('creation.archetypes.'+ar.id+'.name'):'';
  const maxInGame=t('creation.review.maxInGame');
  document.getElementById('rcard').innerHTML=`
    <div class="rhead">
      ${photo}
      <div class="rname playfair">${G.name}</div>
      <div class="rsub">${arName} &middot; ${co?.n||''}</div>
      ${G.motto?`<div style="font-style:italic;color:#5a5040;font-size:.82rem;margin-top:.5rem">"${G.motto}"</div>`:''}
      <div class="rbadge" style="color:${co?.col};border-color:${co?.col}">${co?.n} &middot; ${co?.cur}</div>
    </div>
    <div class="rsec">
      <div class="rsectitle">${t('creation.review.lifePath')}</div>
      <div class="rbadge-wrap">
        ${or?`<div class="rbadge-item"><i class="ti ${or.icon}" style="font-size:.85rem"></i> ${t('creation.origins.'+or.id+'.name')}</div>`:''}
        ${sc?`<div class="rbadge-item"><i class="ti ${sc.icon}" style="font-size:.85rem"></i> ${t('creation.schools.'+sc.id+'.name')}</div>`:''}
        ${ar?`<div class="rbadge-item"><i class="ti ${ar.icon}" style="font-size:.85rem"></i> ${arName}</div>`:''}
        ${ca?`<div class="rbadge-item"><i class="ti ${ca.icon}" style="font-size:.85rem"></i> ${t('creation.careers.'+ca.id+'.name')}</div>`:''}
      </div>
    </div>
    <div class="rsec">
      <div class="rsectitle">${t('creation.review.characteristics')}</div>
      <div class="rsgrid">
        ${STAT_DEFS.map(({k,i})=>`
          <div class="rsitem">
            <div class="rsiname"><i class="ti ${i}" style="font-size:.7rem"></i> ${t('creation.stats.'+k+'.name')}</div>
            <div class="rsival">${eff[k]}</div>
          </div>`).join('')}
      </div>
    </div>
    <div class="rsec">
      <div class="rsectitle">${t('creation.review.startingResources')}</div>
      <div class="resgrid">
        <div class="resitem"><div class="reslbl">${t('creation.review.money')}</div><div class="resval">${arg.toLocaleString('fr-FR')} ${co?.cur||'FR'}</div><div class="resmax">${t('creation.review.tier',{tier:palier(arg)})}</div></div>
        <div class="resitem"><div class="reslbl">${t('creation.review.influence')}</div><div class="resval">${res.inf} / 100</div><div class="resmax">${maxInGame}</div></div>
        <div class="resitem"><div class="reslbl">${t('creation.review.popularity')}</div><div class="resval">${res.pop} / 100</div><div class="resmax">${maxInGame}</div></div>
        <div class="resitem"><div class="reslbl">${t('creation.review.discretion')}</div><div class="resval">${res.dis} / 100</div><div class="resmax">${maxInGame}</div></div>
      </div>
    </div>
    <div class="rsec" style="border:none">
      <div class="rsectitle">${t('creation.review.biography')}</div>
      <div class="rbio">${G.bio}</div>
    </div>`;
}

function validateChar(){
  // Sauvegarde du personnage en localStorage pour le plateau
  const char={
    country:G.country, origin:G.origin, school:G.school,
    archetype:G.archetype, career:G.career,
    stats:{}, freeStats:G.freeStats,
    freePtsRestants:G.freePts, // reliquat (bêta) : plus jamais obligatoire de tout depenser a la creation
    name:G.name, bio:G.bio, motto:G.motto,
    arg:totalArg(), resources:resources(),
    createdAt:new Date().toISOString(),
    currentCity:G.city || 'capitale',
    queteAccueil:{ etape:'non_commencee' }
  };
  STAT_DEFS.forEach(({k})=>{char.stats[k]=Math.min(20,getBase(k)+(G.freeStats[k]||0))});
  try{
    // Clé par nom (évite écrasement entre personnages)
    try {
      localStorage.setItem('respublica_char_' + char.name, JSON.stringify(char));
      // Clé générique = pointeur vers le dernier personnage actif
      localStorage.setItem('respublica_char', JSON.stringify(char));
      localStorage.setItem('respublica_last_char', char.name);
    } catch (e) {
      console.warn('Cache local personnage non sauvegarde (quota depasse) :', e);
    }
    // Photo sauvegardee separement car peut etre volumineuse
    if(G.photoUrl){
      try{
        localStorage.setItem('respublica_photo_' + char.name, G.photoUrl);
        localStorage.setItem('respublica_photo', G.photoUrl);
      }
      catch(e){ console.warn('Photo trop volumineuse pour localStorage'); }
    }
    // Sauvegarde Supabase
    if (typeof sbSavePersonnage === 'function') {
      // Lot 2 (chantier fiscalite/Helvetia) : repartition initiale 15%/85%, INCHANGEE dans sa
      // formule (deja la convention existante ici), mais la part de 85% n'est plus ecrite sur
      // l'ancien champ plat personnages.banque (legacy, plus source de verite) -- elle cree
      // desormais une vraie ligne comptes_bancaires (Banque nationale), juste apres que le
      // personnage lui-meme existe reellement en base (chainage .then, evite toute course avec
      // la contrainte de personnage referencee par comptes_bancaires.personnage).
      const soldeBanqueNationale = (char.arg || 0) - Math.floor((char.arg||0)*0.15);
      const tempState = {
        char, country: char.country, currentCity: G.city || 'capitale',
        arg: char.arg || 0, liquide: Math.floor((char.arg||0)*0.15),
        inf: char.resources?.inf || 25, pop: char.resources?.pop || 30,
        dis: char.resources?.dis || 85, hp: 100, pa: 10, moral: 75,
        poste: null, inventory: [], informateurs: [], day: 1, recherche: [],
        domicile: { country: char.country, city: G.city || 'capitale', depuis: 1 },
        organisations: [],
        objectifs_completes: [],
        votes_pnj: {},
      };
      sbSavePersonnage(tempState)
        .then(() => {
          if (typeof sbCreerCompteBancaire !== 'function') return;
          return sbCreerCompteBancaire({
            id: 'nationale_' + char.name,
            personnage: char.name,
            pays: char.country,
            banque: 'nationale',
            solde: soldeBanqueNationale
          });
        })
        .catch(e => console.error('Échec de la création du compte Banque nationale pour ' + char.name + ' — le personnage existe mais sans compte bancaire initial, à corriger manuellement.', e));

      // Ville de naissance (17 aout 2026, mini-lot etat-civil) : ecriture separee, une seule
      // fois, dans une table dediee (etat_civil_naissances) -- jamais dans 'personnages', qui
      // est resauvegardee integralement a chaque action ulterieure du joueur et casserait toutes
      // les sauvegardes si une colonne y manquait avant que la migration ne soit appliquee.
      if (typeof sbEnregistrerNaissance === 'function') {
        sbEnregistrerNaissance(char.name, char.country, G.city || 'capitale').catch(e => console.warn('Naissance non enregistree', e));
      }
    }
  }
  catch(e){ console.warn('localStorage non disponible'); }
  goTo(9);
}

function renderSuccess(){
  const co=COUNTRIES[G.country];
  document.getElementById('sctext').textContent=
    t('creation.success.text',{name:G.name,country:co?.n||t('creation.success.fallbackCountry')});
}

// Init
goTo(0);
