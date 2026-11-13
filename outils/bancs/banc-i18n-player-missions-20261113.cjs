'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),{execFileSync}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),read=p=>fs.readFileSync(path.join(root,p),'utf8');
const fr=JSON.parse(read('outils/bancs/fixtures/player-missions-fr-20261113.json'));
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
function catalogue(){const c={RP_I18N_RESOURCES:Object.fromEntries(langs.map(l=>[l,{translation:{}}]))};c.window=c;vm.createContext(c);vm.runInContext(read('i18n/player-missions-resources.js'),c);return c;}
test('67 textes français exacts, 9 langues, variables, nombres, devises et noms conservés',()=>{
 const c=catalogue();assert.deepEqual([...c.RPPlayerMissionsI18n.languages],langs);assert.equal(c.RPPlayerMissionsI18n.keys.length,67);
 assert.deepEqual(JSON.parse(JSON.stringify(c.RP_I18N_RESOURCES.fr.translation.playerMissions)),fr);
 const vars=s=>(s.match(/\{\{values\.\w+\}\}/g)||[]).sort();
 const numbers=s=>(s.replace(/B-127/g,'').match(/\d+/g)||[]).sort();
 for(const l of langs){const t=c.RP_I18N_RESOURCES[l].translation.playerMissions;assert.deepEqual(Object.keys(t),Object.keys(fr));
  for(const [k,v] of Object.entries(fr)){
   assert.ok(t[k]?.trim(),l+' '+k);assert.deepEqual(vars(t[k]),vars(v),l+' '+k);assert.deepEqual(numbers(t[k]),numbers(v),l+' '+k);
   if(l!=='fr'&&!(l==='en'&&k==='points'))assert.notEqual(t[k],v,l+' '+k);
   for(const name of ['Jérémy','Petit','Pat Hounette','Brigitte Menottes','Jean-Lou Zeure','Laurent Barre','Luthécia','B-127','FR','HP'])if(v.includes(name))assert.ok(t[k].includes(name),l+' '+k+' '+name);
  }
 }
});
test('les consignes et les objectifs réels sont tous couverts sans changer leurs sources',()=>{
 const c=catalogue(),t=c.RP_I18N_RESOURCES.fr.translation.playerMissions,values=new Set(Object.values(t));const ctx=vm.createContext({});
 let s=read('plateau-politique.js');vm.runInContext(s.slice(s.indexOf('const OBJECTIFS_SECRETS ='),s.indexOf('async function afficherObjectifsSecrets'))+';this.goals=OBJECTIFS_SECRETS;',ctx);
 for(const [a,g]of Object.entries(ctx.goals)){assert.equal(t['archetype_'+a],g.label);for(const o of g.objectifs)assert.equal(t[o.id],o.desc);}
 s=read('plateau-quete-accueil.js');vm.runInContext(s.slice(s.indexOf('const QUETE_ACCUEIL_OBJECTIFS ='),s.indexOf('function queteAccueilObjectifActuel'))+';this.welcome=QUETE_ACCUEIL_OBJECTIFS;',ctx);
 assert.equal(Object.keys(ctx.welcome).length,21);for(const v of Object.values(ctx.welcome))assert.ok(values.has(v),v);
 s=read('plateau-pnj.js');s=s.slice(s.indexOf('function queteCarriereObjectifActuel'),s.indexOf('// BRANCHE POLITIQUE —'));
 const objectives=[...s.matchAll(/return "([^"]+)"/g)].map(m=>m[1]);assert.equal(objectives.length,9);for(const v of objectives)assert.ok(values.has(v),v);
});
test('seuls trois appels de présentation ajoutés aux modules métier ; aucun autre changement',()=>{
 // Preuve figée sur la PR #852 elle-même (13/11, Claude) : avant = 7cf66d5, après fusion = c9f8226.
 // L'ancienne comparaison à merge-base(origin/main, HEAD) refusait toute PR ultérieure touchant
 // plateau-politique.js ou data.js. Fichiers actuels : les trois appels doivent rester présents.
 const base='7cf66d5f2d6e399232d67b84146e64507b2ab775',tete='c9f8226dd176dc1390e270d6bbeefeccb5ddbb2b';
 const show=(c,p)=>execFileSync('git',['show',c+':'+p],{cwd:root,encoding:'utf8',maxBuffer:8*1024*1024});
 const appel=/^\s*globalThis\.RPPlayerMissionsI18n\?\.apply\(\);\n/gm;
 const strip=s=>s.replace(appel,'');
 for(const p of ['plateau-politique.js','plateau-enigme-portrait.js'])assert.equal(strip(show(tete,p)),strip(show(base,p)),p);
 assert.equal(['plateau-politique.js','plateau-enigme-portrait.js'].reduce((n,p)=>n+(read(p).match(appel)||[]).length,0),3);
 assert.equal(execFileSync('git',['diff','--name-only',base,tete,'--','api','migrations','baseline','data.js','plateau-pnj.js','plateau-quete-accueil.js','plateau-organisations-quetes.js','plateau-enigme-tresor-tsars.js'],{cwd:root,encoding:'utf8'}).trim(),'');
 const s=read('i18n/player-missions-resources.js');assert.doesNotMatch(s,/fetch\(|sbRpc|sbSave|state\.|verifierObjectifs\(|afficherObjectifsSecrets\(|enigme1AfficherCalepin\(/);
 assert.match(s,/RPI18nPlateau\?\.apply/,'le moteur commun traduit les nœuds balisés');
 assert.ok(!s.includes('new I18n'));
});
