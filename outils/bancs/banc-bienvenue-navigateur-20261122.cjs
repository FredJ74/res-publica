'use strict';
// Moteur i18next réel, vrais textes et rendu ; aucun RPC ou serveur métier.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),zlib=require('node:zlib');
const acorn=require('../e2e/node_modules/acorn');
const {avecJeu,page,R}=require('./mobile-navigateur.cjs');
const s=fs.readFileSync(path.join(R,'plateau-personnage.js'),'utf8'),ast=acorn.parse(s,{ecmaVersion:'latest'});
const morceaux=ast.body.filter(n=>
 (n.type==='VariableDeclaration'&&n.declarations.some(d=>d.id.name==='REGLES'))||
 (n.type==='FunctionDeclaration'&&['renderRulesContent','rafraichirGuideOuvert'].includes(n.id.name))||
 (['ExpressionStatement','IfStatement'].includes(n.type)&&s.slice(n.start,n.end).includes('push(rafraichirGuideOuvert)'))
).map(n=>s.slice(n.start,n.end)).join('\n');
const base=JSON.parse(zlib.gunzipSync(fs.readFileSync(path.join(__dirname,'fixtures/guide-marque-relue-20261122.json.gz')))).guide;

for(const largeur of [320,390,1440])test(`bienvenue, langues à chaud et état conservé à ${largeur}px`,async()=>avecJeu(async(b,o)=>{
 const p=await page(b,o,largeur,900);
 await p.evaluate(()=>{localStorage.setItem('respublica_language','fr');window.RP_I18N_GAME_ENABLED=true;});
 for(const f of ['i18n/i18next.min.js','i18n/resources.js','i18n/guide-resources.js','i18n/guide-integrity.js','i18n/plateau-bridge.js'])await p.addScriptTag({content:fs.readFileSync(path.join(R,f),'utf8')});
 await p.addScriptTag({content:morceaux});
 await p.addScriptTag({content:fs.readFileSync(path.join(R,'i18n/plateau-init.js'),'utf8')});
 await p.evaluate(()=>{
  window.appels=0;window.fetch=()=>{appels++;throw Error('requête métier interdite');};
  window.etatFixture={pa:20,argent:100,position:'fictive'};
  const draft=document.createElement('textarea');draft.id='brouillon-fixture';draft.value='Saisie conservée';document.body.append(draft);
  document.querySelectorAll('.vue').forEach(v=>v.classList.remove('active'));document.getElementById('vue-rules').classList.add('active');
 });
 for(const section of ['tuto','intro']){
  await p.evaluate(x=>renderRulesContent(x),section);
  for(const lang of Object.keys(base)){
   await p.evaluate(l=>i18next.changeLanguage(l),lang);
   const el=p.locator('#rules-content');
   const texte=await el.innerText();
   assert.ok(texte.includes('Human Gambit'),lang+'/'+section);
   assert.doesNotMatch(texte,/Res Publica/);
   const premiere=base[lang][section].contenu.split('\n')[0].replaceAll('Res Publica','Human Gambit');
   assert.ok(texte.includes(premiere),lang+'/'+section+' traduction utilisée');
   assert.equal(await el.getAttribute('dir'),lang==='ar'?'rtl':null);
   assert.ok(await p.locator('#rules-content').evaluate(e=>e.scrollWidth<=e.clientWidth+1),lang+' débordement');
   assert.equal(await p.locator('#brouillon-fixture').inputValue(),'Saisie conservée');
   assert.equal(await p.evaluate(()=>JSON.stringify(etatFixture)),JSON.stringify({pa:20,argent:100,position:'fictive'}));
   assert.equal(await p.evaluate(()=>appels),0);
  }
 }
}));
