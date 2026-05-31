/* ===========================
   RES PUBLICA — CREATION.JS
   =========================== */

let G = {
  country:null, origin:null, school:null, archetype:null, career:null,
  freeStats:{INT:0,CHA:0,VOL:0,PER:0,DUP:0,ENT:0}, freePts:30,
  photoUrl:null, name:'', bio:'', motto:''
};

/* ---- Navigation ---- */
function goTo(n){
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

/* ---- Country ---- */
function renderCountry(){
  document.getElementById('country-grid').innerHTML=Object.entries(COUNTRIES).map(([id,d])=>`
    <div class="cc ${G.country===id?'sel':''}" data-c="${id}" onclick="selCountry('${id}')">
      <div class="icon-c" style="border-color:${d.col};color:${d.col}">
        <i class="ti ${d.icon}" style="font-size:1.2rem"></i>
      </div>
      <div class="cname" style="color:${d.col}">${d.n}</div>
      <div style="margin-bottom:.6rem">
        ${d.tags.map(t=>`<span class="ctag" style="color:${d.col};border-color:${d.col}">${t}</span>`).join('')}
      </div>
      <div class="cdesc">${d.desc}</div>
    </div>`).join('');
}
function selCountry(id){
  G.country=id;
  G.freeStats={INT:0,CHA:0,VOL:0,PER:0,DUP:0,ENT:0};
  G.freePts=30;
  renderCountry();
  document.getElementById('n1').disabled=false;
}

/* ---- Origin ---- */
function renderOrigin(){
  const cur=COUNTRIES[G.country]?.cur||'FR';
  document.getElementById('origin-grid').innerHTML=ORIGINS.map(o=>`
    <div class="oc ${G.origin===o.id?'sel':''}" onclick="selOrigin('${o.id}')">
      <div class="checkmark"><i class="ti ti-check"></i></div>
      <div class="oname"><i class="ti ${o.icon}" style="font-size:1rem;color:#8a6a20"></i> ${o.name}</div>
      <div class="odesc">${o.desc}</div>
      <div class="obonus">
        Capital : <strong>${o.arg.toLocaleString('fr-FR')} ${cur}</strong><br>
        ${Object.entries(o.bonuses).map(([k,v])=>`<strong>+${v} ${k}</strong>`).join('  ')}
        ${Object.entries(o.malus).map(([k,v])=>`<span style="color:#8a4020">${v} ${k}</span>`).join('  ')}
      </div>
      <div style="font-size:.72rem;color:#7a6040;margin-top:.3rem;font-style:italic">Trait : ${o.trait}</div>
    </div>`).join('');
}
function selOrigin(id){
  G.origin=id;
  renderOrigin();
  document.getElementById('n2').disabled=false;
}

/* ---- School ---- */
function renderSchool(){
  document.getElementById('school-grid').innerHTML=SCHOOLS.map(s=>`
    <div class="oc ${G.school===s.id?'sel':''}" onclick="selSchool('${s.id}')">
      <div class="checkmark"><i class="ti ti-check"></i></div>
      <div class="oname"><i class="ti ${s.icon}" style="font-size:1rem;color:#8a6a20"></i> ${s.name}</div>
      <div class="odesc">${s.desc}</div>
      <div class="obonus">
        <strong>${s.compPts} pts</strong> de competences<br>
        ${Object.entries(s.bonuses).map(([k,v])=>`<strong>+${v} ${k}</strong>`).join('  ')}
        ${Object.entries(s.malus||{}).map(([k,v])=>`<span style="color:#8a4020">${v} ${k}</span>`).join('  ')}
      </div>
      <div class="oblock"><i class="ti ti-lock" style="font-size:.7rem;vertical-align:-1px"></i> ${s.blockLabel}</div>
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
      <div class="oname"><i class="ti ${a.icon}" style="font-size:1rem;color:#8a6a20"></i> ${a.name}</div>
      <div class="odesc">${a.desc}</div>
      <div class="obonus">
        ${Object.entries(a.bonuses).map(([k,v])=>`<strong>+${v} ${k}</strong>`).join('  ')}
        ${Object.entries(a.malus).map(([k,v])=>`<span style="color:#8a4020">${v} ${k}</span>`).join('  ')}<br>
        Capital : <strong>+${a.argBonus.toLocaleString('fr-FR')} ${cur}</strong>
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
      title="${bl?"Non disponible avec votre niveau d'etudes":''}">
      <div class="checkmark"><i class="ti ti-check"></i></div>
      <div class="oname"><i class="ti ${c.icon}" style="font-size:1rem;color:#8a6a20"></i> ${c.name}</div>
      <div class="obonus">+${c.argBonus.toLocaleString('fr-FR')} ${cur} &middot; <strong>+1 ${c.statKey}</strong></div>
      <div class="odesc" style="margin-top:.3rem">${c.comp}</div>
      <div class="oblock">Contact : ${c.contact}</div>
      <div class="owarn">Casserole : ${c.casserole}</div>
    </div>`;
  }).join('');
  const sc=SCHOOLS.find(x=>x.id===G.school);
  document.getElementById('career-info').textContent=
    sc?`Carrieres disponibles selon votre niveau d'etudes (${sc.name}).`:'';
}
function selCareer(id){
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
  document.getElementById('stats-wrap').innerHTML=STAT_DEFS.map(({k,n,d,i})=>{
    const base=getBase(k), free=G.freeStats[k]||0, eff=Math.min(20,base+free), bonus=getBonus(k);
    return`<div class="srow">
      <div>
        <div class="sname"><i class="ti ${i}" style="font-size:.9rem;vertical-align:-1px;margin-right:.3rem"></i>${n}</div>
        <div class="sdesc">${d}</div>
        <div class="sbar"><div class="sbarfill" style="width:${(eff/20)*100}%"></div></div>
      </div>
      <div class="sbonus">${bonus>0?`+${bonus} bonus`:bonus<0?`${bonus} malus`:''}</div>
      <div class="sadj">
        <button class="sbtn" onclick="adjStat('${k}',-1)" ${free<=0?'disabled':''}>-</button>
        <span class="sval">${eff}</span>
        <button class="sbtn" onclick="adjStat('${k}',1)" ${G.freePts<=0||base+free>=16?'disabled':''}>+</button>
      </div>
    </div>`;
  }).join('');
  document.getElementById('pts-left').textContent=G.freePts;
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

async function genBio(){
  const name=document.getElementById('cname').value.trim();
  const btn=document.getElementById('aibtn');
  const err=document.getElementById('aierr');
  err.style.display='none';
  if(!name){err.textContent="Entrez d'abord un nom.";err.style.display='block';return;}
  const co=COUNTRIES[G.country];
  const ar=ARCHETYPES.find(x=>x.id===G.archetype);
  const ca=CAREERS.find(x=>x.id===G.career);
  const or=ORIGINS.find(x=>x.id===G.origin);
  const sc=SCHOOLS.find(x=>x.id===G.school);
  btn.innerHTML='<span class="spin"></span> Generation en cours...';
  btn.disabled=true;
  const prompt=`Tu es le narrateur d'un jeu de role politique parodique et satirique. Genere une biographie courte (3-4 phrases, ton satirique et cynique) pour un personnage nomme "${name}". Nature profonde : ${ar?.name||'inconnue'}. Origine : ${or?.name||'inconnue'}. Scolarite : ${sc?.name||'inconnue'}. Carriere : ${ca?.name||'inconnue'}. Empire : "${co?.n||'inconnu'}" (parodie ${G.country==='republic'?'de la Ve Republique francaise':G.country==='narco'?"d'un narco-etat":G.country==='soviet'?"d'un regime communiste":"d'une monarchie petroliere"}). Style : ironique, memorable, ambitions politiques troubles. Reponds UNIQUEMENT avec la biographie, sans titre ni introduction.`;
  try{
    const resp=await fetch('https://api.anthropic.com/v1/messages',{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify({model:'claude-sonnet-4-20250514',max_tokens:1000,messages:[{role:'user',content:prompt}]})
    });
    const data=await resp.json();
    if(data.content?.[0]?.text){
      document.getElementById('cbio').value=data.content[0].text;
      G.bio=data.content[0].text;
      chkId();
    } else {
      err.textContent='Erreur de generation. Ecrivez votre biographie manuellement.';
      err.style.display='block';
    }
  } catch(e){
    err.textContent='API inaccessible. Ecrivez votre biographie manuellement.';
    err.style.display='block';
  }
  btn.innerHTML='<i class="ti ti-sparkles" style="font-size:14px;vertical-align:-2px"></i> Regenerer la biographie';
  btn.disabled=false;
}

/* ---- Review ---- */
function palier(a){
  if(a<600)  return'1 - Denument';
  if(a<1500) return'2 - Modeste';
  if(a<3500) return'3 - Aise';
  if(a<7000) return'4 - Riche';
  return'5 - Oligarque';
}

function totalArg(){
  const or=ORIGINS.find(x=>x.id===G.origin);
  const ar=ARCHETYPES.find(x=>x.id===G.archetype);
  const ca=CAREERS.find(x=>x.id===G.career);
  return (or?.arg||0)+(ar?.argBonus||0)+(ca?.argBonus||0);
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
  document.getElementById('rcard').innerHTML=`
    <div class="rhead">
      ${photo}
      <div class="rname playfair">${G.name}</div>
      <div class="rsub">${ar?.name||''} &middot; ${co?.n||''}</div>
      ${G.motto?`<div style="font-style:italic;color:#5a5040;font-size:.82rem;margin-top:.5rem">"${G.motto}"</div>`:''}
      <div class="rbadge" style="color:${co?.col};border-color:${co?.col}">${co?.n} &middot; ${co?.cur}</div>
    </div>
    <div class="rsec">
      <div class="rsectitle">Parcours de vie</div>
      <div class="rbadge-wrap">
        ${or?`<div class="rbadge-item"><i class="ti ${or.icon}" style="font-size:.85rem"></i> ${or.name}</div>`:''}
        ${sc?`<div class="rbadge-item"><i class="ti ${sc.icon}" style="font-size:.85rem"></i> ${sc.name}</div>`:''}
        ${ar?`<div class="rbadge-item"><i class="ti ${ar.icon}" style="font-size:.85rem"></i> ${ar.name}</div>`:''}
        ${ca?`<div class="rbadge-item"><i class="ti ${ca.icon}" style="font-size:.85rem"></i> ${ca.name}</div>`:''}
      </div>
    </div>
    <div class="rsec">
      <div class="rsectitle">Caracteristiques</div>
      <div class="rsgrid">
        ${STAT_DEFS.map(({k,n,i})=>`
          <div class="rsitem">
            <div class="rsiname"><i class="ti ${i}" style="font-size:.7rem"></i> ${n}</div>
            <div class="rsival">${eff[k]}</div>
          </div>`).join('')}
      </div>
    </div>
    <div class="rsec">
      <div class="rsectitle">Ressources de depart</div>
      <div class="resgrid">
        <div class="resitem"><div class="reslbl">Argent</div><div class="resval">${arg.toLocaleString('fr-FR')} ${co?.cur||'FR'}</div><div class="resmax">Palier ${palier(arg)}</div></div>
        <div class="resitem"><div class="reslbl">Influence</div><div class="resval">${res.inf} / 100</div><div class="resmax">Max 100 en jeu</div></div>
        <div class="resitem"><div class="reslbl">Popularite</div><div class="resval">${res.pop} / 100</div><div class="resmax">Max 100 en jeu</div></div>
        <div class="resitem"><div class="reslbl">Discretion</div><div class="resval">${res.dis} / 100</div><div class="resmax">Max 100 en jeu</div></div>
      </div>
    </div>
    <div class="rsec" style="border:none">
      <div class="rsectitle">Biographie</div>
      <div class="rbio">${G.bio}</div>
      ${ca?`
        <div style="margin-top:.8rem;font-size:.75rem;color:#6a4020;font-style:italic">
          <i class="ti ti-alert-triangle" style="font-size:.75rem"></i> Casserole : ${ca.casserole}
        </div>
        <div style="font-size:.75rem;color:#4a6030;margin-top:.2rem">
          <i class="ti ti-user-check" style="font-size:.75rem"></i> Contact de depart : ${ca.contact}
        </div>`:''}
    </div>`;
}

function validateChar(){
  // Sauvegarde du personnage en localStorage pour le plateau
  const char={
    country:G.country, origin:G.origin, school:G.school,
    archetype:G.archetype, career:G.career,
    stats:{}, freeStats:G.freeStats,
    photoUrl:G.photoUrl, name:G.name, bio:G.bio, motto:G.motto,
    arg:totalArg(), resources:resources(),
    createdAt:new Date().toISOString()
  };
  STAT_DEFS.forEach(({k})=>{char.stats[k]=Math.min(20,getBase(k)+(G.freeStats[k]||0))});
  try{ localStorage.setItem('respublica_char', JSON.stringify(char)); }
  catch(e){ console.warn('localStorage non disponible'); }
  goTo(9);
}

function renderSuccess(){
  const co=COUNTRIES[G.country];
  document.getElementById('sctext').textContent=
    `${G.name} entre dans l'arene de ${co?.n||'ce monde'}. Le Grand Jeu commence. Alliances, trahisons, corruption, kompromat - que le plus impitoyable gagne.`;
}

// Init
goTo(0);
