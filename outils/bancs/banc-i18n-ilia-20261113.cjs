'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),{execFileSync}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),read=p=>fs.readFileSync(path.join(root,p),'utf8');
const fr=JSON.parse(read('outils/bancs/fixtures/ilia-fr-20261113.json'));
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
const stories=Object.keys(fr).filter(k=>k.startsWith('f_'));
function catalogue(){
 const c={RP_I18N_GAME_ENABLED:true,locale:'fr',RP_I18N_RESOURCES:Object.fromEntries(langs.map(l=>[l,{translation:{}}]))};
 c.window=c;c.RPPlateauI18n={language:()=>c.locale};vm.createContext(c);
 vm.runInContext(read('i18n/guide-ilia-resources.js'),c);return c;
}
test('5 récits et 14 messages complets dans les 9 langues, variables et paragraphes conservés',()=>{
 const c=catalogue(); assert.deepEqual([...c.RPGuideIliaI18n.langues],langs);
 assert.equal(stories.length,5);assert.equal(c.RPGuideIliaI18n.cles.length,19);
 for(const l of langs){
  c.locale=l;const entries=c.RP_I18N_RESOURCES[l].translation.guideIlia;
  assert.deepEqual(Object.keys(entries),Object.keys(fr));
  for(const [k,original] of Object.entries(fr)){
   assert.ok(entries[k]?.trim(),l+' '+k);assert.equal(c.texteGuideIlia(k),entries[k]);
   assert.deepEqual(entries[k].match(/\{\w+\}/g),original.match(/\{\w+\}/g));
   if(l!=='fr')assert.notEqual(entries[k],original,l+' '+k);
   if(k.startsWith('f_'))assert.equal(entries[k].split('\n\n').length,original.split('\n\n').length,l+' '+k);
  }
  assert.match(c.texteGuideIlia('q_ask',{n:2}),/2/);
  for(const year of ['1742','1887'])assert.ok(entries.f_hall.includes(year));
  for(const name of ['Sophia Nouiseteskaïa','Viktor Polov','Léonid III','Alexander Aspirine','Ivan Betonov','Anna Mouriskova','Belov'])assert.ok(entries.f_salle_personnalites_discretes.includes(name),l+' '+name);
  for(const name of ['Mikhaïl Dragounov','Piotr Karassov'])assert.ok(entries.f_salle_bataille_fleuve.includes(name));
  assert.ok(entries.f_salle_origines.includes('Sergueï IV'));assert.ok(entries.f_salle_grand_incendie.includes('Grigori Pirogov'));
 }
});
test('français strictement identique au témoin original, catalogue absent et repli par clé',()=>{
 const c=catalogue();
 for(const [k,v] of Object.entries(fr))assert.equal(c.texteGuideIlia(k),v,k);
 vm.runInContext(read('plateau-guide-ilia.js'),c);
 for(const [k,v] of Object.entries(fr))assert.equal(c.iliaMuseeTexte(k),v,k);
 c.locale='inconnue';assert.equal(c.texteGuideIlia('f_hall'),fr.f_hall);
 c.locale='en';c.RP_I18N_GAME_ENABLED=false;assert.equal(c.texteGuideIlia('q_open'),fr.q_open);
 // Supprimer réellement une traduction du catalogue source : le français revient.
 const d={window:null,RP_I18N_GAME_ENABLED:true,RPPlateauI18n:{language:()=> 'en'}};d.window=d;vm.createContext(d);
 vm.runInContext(read('i18n/guide-ilia-resources.js').replace('for(const [lang,labels]',"delete texts.en.f_hall;\nfor(const [lang,labels]"),d);
 assert.equal(d.texteGuideIlia('f_hall'),fr.f_hall);
 const fallback={window:{}};vm.createContext(fallback);vm.runInContext(read('plateau-guide-ilia.js'),fallback);
 for(const [k,v] of Object.entries(fr))assert.equal(fallback.iliaMuseeTexte(k),v,k);
});
test('énigme, données, serveur IA, coûts et appels protégés identiques au départ de main',()=>{
 // Preuve figée sur la PR #849 elle-même (13/11, Claude) : avant = 44c382f (main avant #849), après = 787f256
 // (fusion). L'ancienne comparaison à merge-base(origin/main, HEAD) refusait toute PR ultérieure touchant
 // api/chat.js, data.js ou une migration (même défaut que les bancs #852 et #855, corrigés de la même façon).
 const protectedFiles=['data.js','plateau-enigme-tresor-tsars.js','plateau-router.js','api/chat.js','api/_enigme-tresor-tsars.js','api/_pnj-personnalites.js','i18n/guide-musee-novomirsk-resources.js','migrations'];
 const base='44c382ff3b755994980248213a85ca6a18168da9',tete='787f2563236999754576876799b1088daca659f9';
 assert.equal(execFileSync('git',['diff','--name-only',base,tete,'--',...protectedFiles],{cwd:root,encoding:'utf8'}).trim(),'');
 const source=read('plateau-guide-ilia.js');
 assert.deepEqual([...source.matchAll(/sbRpcVerdict\('([^']+)', \{\}/g)].map(m=>m[1]),['tresor_tsars_guide','guide_musee_dialogue_lire','guide_musee_dialogue_ouvrir']);
 const refresh=source.slice(source.indexOf('function iliaMuseeActualiserTextes'),source.indexOf('(window.RP_I18N_CHANGE_CALLBACKS'));
 assert.doesNotMatch(refresh,/fetch\(|sbRpc|appliquerPaiement|iliaMuseeEtat\[.*=|iliaMuseeEchanges\[.*=/);
 const original=JSON.parse(read('outils/bancs/fixtures/ilia-mecanismes-20261113.json'));
 for(const [name,body] of Object.entries(original)){
  const actual=source.slice(source.indexOf('async function '+name));
  const segment=actual.slice(0,actual.indexOf('\nasync function ')<0?actual.length:actual.indexOf('\nasync function '));
  assert.equal(segment.replace("bouton.innerHTML = iliaMuseeLibelle('q_wait');","bouton.textContent = 'Ilia réfléchit…';"),body,name);
 }
});
