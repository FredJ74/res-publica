'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict'),vm=require('node:vm'),path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'../../plateau-pnj.js'),'utf8');
const sql=fs.readFileSync(path.join(__dirname,'../../historique/migrations-appliquees/20261029184923_rumeurs_organisations_confidentialite.sql'),'utf8');
const begin=source.indexOf('async function chargerOrganisationsPourRumeur()');
const end=source.indexOf('\n}',begin)+2;
assert.ok(begin>=0&&end>begin);
const fn=source.slice(begin,end);
assert.ok(!fn.includes('sbLoadOrganisations'), 'aucun chargement de fiches privees');
assert.ok(fn.includes("sbRpc('rumeurs_organisations_cibles'"), 'projection serveur');
const scope={sbRpc:async()=>[
{id:'secret',nom:'Réseau secret',country:'republic',chef:'NE_PAS_EXPOSER',membres:[{nom:'SECRET'}]},
{id:'public',nom:'Commerce public',country:'republic'}
]};
vm.createContext(scope);
vm.runInContext(fn+';globalThis.charger=chargerOrganisationsPourRumeur;',scope);
(async()=>{
const a=JSON.parse(JSON.stringify(await scope.charger()));
assert.deepEqual(a.map(x=>x.id),['public','secret']);
assert.deepEqual(Object.keys(a[1]).sort(),['country','id','nom']);
assert.ok(!JSON.stringify(a).includes('NE_PAS_EXPOSER')&&!JSON.stringify(a).includes('SECRET'));
scope.sbRpc=async()=>null;
assert.equal((await scope.charger()).length,0,'fail closed sans RPC');
assert.match(sql,/RETURNS TABLE \(id text, nom text, country text\)/);
assert.match(sql,/REVOKE ALL ON FUNCTION public\.rumeurs_organisations_cibles\(\) FROM PUBLIC/);
assert.match(sql,/DROP POLICY IF EXISTS organisations_lecture_publique/);
assert.match(sql,/membre\.obj->>'nom' = public\.mon_personnage\(\)/);
console.log('OK — cibles anonymisées par RPC, aucun fallback indiscret, RLS préparée');
})().catch(e=>{console.error(e);process.exitCode=1});
