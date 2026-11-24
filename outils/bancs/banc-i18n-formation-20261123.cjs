'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),cp=require('node:child_process');
const {avecJeu,page,R}=require('./mobile-navigateur.cjs');
const read=f=>fs.readFileSync(path.join(R,f),'utf8'),manifest=JSON.parse(read('outils/audits/i18n/FORMATION-20261123-sources.json'));
const original=cp.execFileSync('git',['show',manifest.base+':plateau-universite.js'],{cwd:R,encoding:'utf8'}),locales=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
const catalogue=JSON.parse(read('outils/audits/i18n/FORMATION-CATALOGUE-20261123.json')).cursus;
const commun={};commun.window=commun;vm.createContext(commun);vm.runInContext(read('i18n/resources.js'),commun);
const nomsCarriere=JSON.parse(JSON.stringify(Object.fromEntries(locales.map(l=>[l,commun.RP_I18N_RESOURCES[l].translation.creation.careers]))));
const dtoCatalogue=rows=>rows.map(({lecture_seule,ouvert,...row})=>row);
const c={};c.window=c;vm.createContext(c);vm.runInContext(read('i18n/university-resources.js'),c);const words=JSON.parse(JSON.stringify(c.RPUniversityI18n.words));
test('formation : 41 français originaux exacts, cinq libellés réels, 368 traductions et cinq carrières réutilisées',()=>{
 assert.deepEqual(words.fr,{...manifest.fr,...Object.fromEntries(catalogue.map(c=>['catalogue_'+c.id,c.libelle]))});assert.equal(Object.keys(words.fr).length,46);assert.equal(catalogue.filter(c=>c.ouvert).length,1);assert.ok(catalogue.every(c=>c.lecture_seule==='on'));for(const row of catalogue){assert.equal(c.RPUniversityI18n.careers[row.carriere].fr,row.carriere_libelle);assert.equal(c.RPUniversityI18n.careers[row.carriere].key,'creation.careers.'+row.carriere+'.name');for(const lang of locales)assert.ok(nomsCarriere[lang][row.carriere].name);}assert.deepEqual(Object.keys(words),locales);
 for(const lang of locales){assert.deepEqual(Object.keys(words[lang]),Object.keys(words.fr));for(const [key,fr]of Object.entries(words.fr)){const value=words[lang][key];assert.ok(value.trim());if(lang!=='fr')assert.notEqual(value,fr);assert.deepEqual([...value.matchAll(/\{\w+\}/g)].map(m=>m[0]).sort(),[...fr.matchAll(/\{\w+\}/g)].map(m=>m[0]).sort());}}
 const x={};x.window=x;vm.createContext(x);vm.runInContext(read('plateau-universite.js'),x);assert.deepEqual(JSON.parse(JSON.stringify(x.RP_UNIVERSITE_TEXTES.fr)),manifest.fr);
});
const fixture=`var state={country:'republic',currentCity:'capitale',currentBuilding:'universite',currentRoom:'hall',pa:70,arg:200};var calls=[],updates=0,example={};var VILLES={republic:{capitale:{nom:'Luthécia'}},soviet:{capitale:{nom:'Novomirsk'}}};var BUILDINGS={universite:{name:'Université municipale',rooms:{hall:{name:'Hall des études'}}}};
 window.RP_I18N_GAME_ENABLED=true;
 window.updateUI=()=>{updates++;};
 window.showToast=(a,b,ok)=>{document.getElementById('toast-result').textContent=a;document.getElementById('toast-sub').textContent=b;};
 window.sbRpc=async(fn,args)=>{calls.push([fn,JSON.parse(JSON.stringify(args))]);if(fn==='universite_mon_etat')return structuredClone(example.s);if(fn==='universite_prochaine_etape')return {ok:true,etape:structuredClone(example.e||null)};if(['universite_inscrire','universite_valider_etape','universite_diplomer'].includes(fn))return example.refus?{ok:false,raison:example.refus}:{ok:true,pa:64};throw Error('RPC inconnue '+fn);};`;
const scenarios=[
 {name:'aucun',s:{ok:true,cursus_disponibles:[]}},
 {name:'choix',s:{ok:true,cursus_disponibles:dtoCatalogue(catalogue.filter(c=>c.ouvert))}},
 {name:'catalogue cinq références, sans activation',s:{ok:true,cursus_disponibles:dtoCatalogue(catalogue)}},
 {name:'intitulé personnalisé opaque',s:{ok:true,cursus_disponibles:[{...dtoCatalogue(catalogue)[0],libelle:'Nom de cursus personnel — Pat Hounette',carriere_libelle:'Profession personnalisée — Nina'}]}},
 ...catalogue.map(c=>({name:'acquise_'+c.carriere,s:{ok:true,slot_consomme:true,seconde_carriere:{carriere:c.carriere,libelle:c.carriere_libelle}}})),
 ...catalogue.map(c=>({name:'progression_'+c.id,s:{ok:true,cursus_actif:{cursus:c.id,jalons_accomplis:2,jalons_total:24}}})),
 {name:'acquise',s:{ok:true,slot_consomme:true,seconde_carriere:{libelle:'Carrière du serveur'} }},
 ...['cours','stage','fermee'].map(name=>({name,s:{ok:true,cursus_actif:{cursus:'univ_medecin',jalons_accomplis:2,jalons_total:12}},e:{id:'jalon-original',genre:name==='stage'?'terrain':'universite',action:'action-originale',ville:'capitale',batiment:'universite',piece:'hall',libelle:'Mission du serveur — Pat Hounette',ouvre_le:'2026-11-24T12:00:00Z',ouvert:name!=='fermee'}})),
 {name:'diplome',s:{ok:true,cursus_actif:{cursus:'univ_justice',jalons_accomplis:12,jalons_total:12,diplomable:true}}},
 {name:'attendre',s:{ok:true,cursus_actif:{cursus:'univ_armee',jalons_accomplis:12,jalons_total:12}}},
 ...Object.keys(words.fr).filter(k=>k.startsWith('r_')).map(k=>({name:k,s:{ok:false,raison:k.slice(2)}})),
 {name:'refus inconnu',s:{ok:false,raison:'inconnue'}}
];
async function setup(p,o,source){await p.addScriptTag({content:fixture});for(const f of ['i18n/i18next.min.js','i18n/resources.js','i18n/plateau-bridge.js','i18n/plateau-init.js'])await p.addScriptTag({url:o+'/'+f});await p.addScriptTag({content:source});await p.evaluate(()=>{const i=document.createElement('input');i.id='draft-formation';i.value='Saisie conservée — 123';document.body.appendChild(i);});}
async function open(p,e,country){await p.evaluate(async({e,country})=>{state.country=country;example=structuredClone(e);calls=[];await ouvrirUniversiteFormation();},{e,country});}
for(const width of [320,390,1280])test(`formation : neuf langues, deux pays, ${width}px, aucun rejeu métier`,{timeout:180000},async()=>avecJeu(async(browser,o)=>{
 const p=await page(browser,o,width,900,false,{texteMinimum:true}),before=await page(browser,o,width,900,false,{texteMinimum:true});let staticLoads=0,businessRequests=0;
 p.on('request',r=>{if(r.url().includes('university-resources.js'))staticLoads++;if(/\/(api|rest\/v1)\//.test(r.url())||r.method()!=='GET')businessRequests++;});
 await setup(p,o,read('plateau-universite.js'));await setup(before,o,original);await p.waitForFunction(()=>!!window.RPUniversityI18n);
 const seen=new Set();let switches=0;
 for(const country of ['republic','soviet'])for(const e of scenarios){
  await p.evaluate(()=>i18next.changeLanguage('fr'));await open(p,e,country);await open(before,e,country);
  const snapshot=()=>({title:document.getElementById('postes-modal-title').textContent,text:document.getElementById('postes-body').textContent,calls,pa:state.pa,arg:state.arg});
  assert.deepEqual(await p.evaluate(snapshot),await before.evaluate(snapshot),'français '+e.name);
  const initial=await p.evaluate(()=>({calls:structuredClone(calls),state:JSON.stringify(state),draft:document.getElementById('draft-formation').value}));
  for(const lang of locales){await p.evaluate(l=>i18next.changeLanguage(l),lang);
   const got=await p.evaluate(()=>({nodes:[...document.querySelectorAll('[data-university-root] [data-university-key]')].map(n=>({key:n.dataset.universityKey,vars:JSON.parse(n.dataset.universityValues||'{}'),text:n.textContent})),references:[...document.querySelectorAll('[data-university-root] [data-university-reference]')].map(n=>({type:n.dataset.universityReference,id:n.dataset.universityReferenceId,fr:n.dataset.universityReferenceFr,text:n.textContent})),dir:document.querySelector('[data-university-root]').dir,title:document.getElementById('postes-modal-title').textContent,calls:structuredClone(calls),state:JSON.stringify(state),draft:document.getElementById('draft-formation').value,overflow:[...document.querySelectorAll('#modal-postes .modal-box')].some(n=>n.scrollWidth>n.clientWidth+1)}));
   for(const n of got.nodes){
    seen.add(n.key);const expected={...n.vars};
    if(n.key==='progression'){const actif=e.s.cursus_actif;assert.equal(n.vars.cursus,actif.cursus,'identifiant brut conservé');expected.cursus=words[lang]['c_'+actif.cursus]||actif.cursus;expected.faits=actif.jalons_accomplis;expected.total=actif.jalons_total;}
    if(n.key==='deja'){const acquis=e.s.seconde_carriere||{},fr=acquis.libelle||acquis.carriere||'',ref=catalogue.find(c=>c.carriere===acquis.carriere&&c.carriere_libelle===fr);assert.equal(n.vars.carriere,fr);expected.carriere=lang==='fr'||!ref?fr:nomsCarriere[lang][acquis.carriere].name;}
    assert.equal(n.text,words[lang][n.key].replace(/\{(\w+)\}/g,(m,k)=>expected[k]!==undefined?String(expected[k]):m));
   }
   assert.equal(got.references.length,2*(e.s.cursus_disponibles||[]).length);
   for(const n of got.references){const row=(e.s.cursus_disponibles||[]).find(c=>n.type==='cursus'?c.id===n.id:c.carriere===n.id);assert.ok(row);const fr=n.type==='cursus'?row.libelle:row.carriere_libelle;assert.equal(n.fr,fr);let expected=fr;
    if(n.type==='cursus'){const k='catalogue_'+row.id;if(words.fr[k]===fr)expected=words[lang][k];else if(words.fr['c_'+row.id]===fr)expected=words[lang]['c_'+row.id];}
    else if(lang!=='fr'&&catalogue.some(c=>c.carriere===row.carriere&&c.carriere_libelle===fr))expected=nomsCarriere[lang][row.carriere].name;
    assert.equal(n.text,expected,e.name+'/'+lang+'/'+n.type+'/'+n.id);
   }
   assert.equal(got.title,words[lang].titre);assert.equal(got.dir,lang==='ar'?'rtl':'ltr');assert.equal(got.state,initial.state);assert.deepEqual(got.calls,initial.calls);assert.equal(got.draft,initial.draft);assert.equal(got.overflow,false,e.name+' '+lang);switches++;
  }
 }
 // Intention explicite : identifiants et paramètres identiques au module initial.
 for(const name of ['choix','cours','stage','diplome']){const e=scenarios.find(x=>x.name===name);await open(p,e,'republic');await open(before,e,'republic');
  if(name==='choix'){await p.evaluate(()=>universiteInscrire(0));await before.evaluate(()=>universiteInscrire(0));}
  else if(name==='diplome'){await p.evaluate(()=>universiteDiplomer());await before.evaluate(()=>universiteDiplomer());}
  else {await p.evaluate(()=>universiteEtape());await before.evaluate(()=>universiteEtape());if(name==='stage'){const kept=await p.evaluate(()=>JSON.stringify(calls));await p.evaluate(()=>i18next.changeLanguage('ar'));assert.equal(await p.evaluate(()=>JSON.stringify(calls)),kept);await p.evaluate(()=>universiteValider());await before.evaluate(()=>universiteValider());}}
  assert.deepEqual(await p.evaluate(()=>({calls,pa:state.pa,arg:state.arg,updates})),await before.evaluate(()=>({calls,pa:state.pa,arg:state.arg,updates})));
 }
 // Notifications ouvertes, remplacement par un autre message et fermeture sans réouverture.
 await p.evaluate(()=>i18next.changeLanguage('de'));assert.equal(await p.locator('#toast-sub').textContent(),words.de.diplome);
 await p.evaluate(()=>{showToast('Titre voisin','Corps voisin',true);universiteFermer();});await p.evaluate(()=>i18next.changeLanguage('ar'));assert.equal(await p.locator('#toast-sub').textContent(),'Corps voisin');assert.equal(await p.locator('#modal-postes').evaluate(n=>n.classList.contains('open')),false);
 // Repli manquant : le français exact, pas la valeur de la langue précédente.
 await p.evaluate(()=>{delete i18next.getResourceBundle('de','translation').university.intro;});await open(p,scenarios[0],'republic');await p.evaluate(()=>i18next.changeLanguage('de'));assert.equal(await p.locator('[data-university-key="intro"]').textContent(),words.fr.intro);
 // Le repli de carrière doit conserver le français réel, pas celui sans accents du catalogue de création.
 await p.evaluate(()=>{delete i18next.getResourceBundle('de','translation').creation.careers.doctor.name;});
 const acquis=catalogue.find(c=>c.carriere==='doctor');await open(p,{s:{ok:true,slot_consomme:true,seconde_carriere:{carriere:acquis.carriere,libelle:acquis.carriere_libelle}}},'republic');await p.evaluate(()=>i18next.changeLanguage('de'));assert.equal(await p.locator('[data-university-key="deja"]').textContent(),words.de.deja.replace('{carriere}',acquis.carriere_libelle));
 assert.equal(staticLoads,1);assert.equal(businessRequests,0);for(const key of ['intro','deja','duree','inscrire','progression','lieu','ouvre','suivre','stage','diplomer','attendre','fermer',...Object.keys(words.fr).filter(k=>k.startsWith('r_'))])assert.ok(seen.has(key),key);
 console.log(JSON.stringify({width,switches,staticLoads,businessRequests,personnage_connecte:false}));await p.close();await before.close();
}));
for(const missing of [false,true])test(`formation : chargement initial réel, catalogue ${missing?'indisponible':'Brotli conforme'}`,{timeout:30000},async()=>avecJeu(async(browser,o)=>{
 const context=await browser.newContext();let loads=0;
 await context.route('**/*',route=>{
  const u=new URL(route.request().url());if(u.origin!==o)return route.abort();
  if(u.pathname.endsWith('university-resources.js')){loads++;if(missing)return route.abort();}
  if(u.pathname==='/formation-cold.html'){
   const html=read('plateau.html').replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi,'');
   const scripts='<script>'+fixture+"localStorage.setItem('respublica_language','en');example={s:{ok:true,cursus_disponibles:[]}};"+'</script>'+
    ['plateau-universite.js','i18n/i18next.min.js','i18n/resources.js','i18n/plateau-bridge.js','i18n/plateau-init.js'].map(f=>'<script src="'+f+'"></script>').join('')+
    '<script>addEventListener("DOMContentLoaded",()=>ouvrirUniversiteFormation());</script>';
   return route.fulfill({contentType:'text/html',body:html.replace('</body>',scripts+'</body>')});
  }
  return route.continue();
 });
 const p=await context.newPage();await p.goto(o+'/formation-cold.html');await p.waitForSelector('[data-university-root]');
 if(!missing)await p.waitForFunction(()=>document.getElementById('postes-modal-title').textContent==='University — second career');
 else await p.waitForTimeout(100);
 assert.equal(await p.locator('#postes-modal-title').textContent(),missing?words.fr.titre:words.en.titre);
 const callsBefore=await p.evaluate(()=>JSON.stringify(calls));assert.equal(JSON.parse(callsBefore).length,2);await p.evaluate(()=>i18next.changeLanguage('ar'));assert.equal(await p.evaluate(()=>JSON.stringify(calls)),callsBefore);assert.equal(loads,1);
 assert.equal(await p.locator('[data-university-key="intro"]').textContent(),missing?words.fr.intro:words.ar.intro);
 await context.close();
}));
