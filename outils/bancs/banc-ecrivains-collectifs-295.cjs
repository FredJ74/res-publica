'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const os=require('node:os');
const path=require('node:path');
const cp=require('node:child_process');
const scanner=path.join(__dirname,'../audits/inventorier-ecrivains-collectifs.cjs');
function invoke(source, enforce=false) {
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'hg-295-'));
 try {
  fs.writeFileSync(path.join(dir,'client.js'),source);
  return cp.spawnSync(process.execPath,[scanner,'--root',dir,...(enforce?['--enforce']:[])],{encoding:'utf8'});
 } finally { fs.rmSync(dir,{recursive:true,force:true}); }
}
test('repere les deux facades, retourne le JSON et ne bloque pas sans mode enforce',()=>{
 const result=invoke("sbSaveOrganisation(orga); sbSaveBudgetClub('club',data);");
 assert.equal(result.status,0,result.stderr);
 const rows=JSON.parse(result.stdout).occurrences;
 assert.deepEqual(rows.map(x=>x.symbol).sort(),['sbSaveBudgetClub','sbSaveOrganisation']);
});
test('refuse upsert direct des clubs en mode enforce',()=>{
 const result=invoke("sbUpsert('budgets_clubs',{id:'club'});",true);
 assert.equal(result.status,1);
 assert.equal(JSON.parse(result.stdout).occurrences.length,1);
});
test('refuse delete et doubles guillemets des organisations',()=>{
 const result=invoke('sbDelete("organisations", "id=eq.x");',true);
 assert.equal(result.status,1);
 assert.equal(JSON.parse(result.stdout).occurrences[0].table,'organisations');
});
test('la lecture seule et les ecritures sans cible ne sont pas bloquees',()=>{
 const result=invoke("sbGet('organisations','select=*'); sbUpsert('other_table',{id:1});",true);
 assert.equal(result.status,0,result.stderr);
 assert.equal(JSON.parse(result.stdout).occurrences.length,0);
});

test('signale les acces REST et from sur les tables financieres sans les classer a tort comme ecriture',()=>{
 const result=invoke("fetch('/rest/v1/organisations'); client.from('budgets_clubs').select('*');",true);
 assert.equal(result.status,0,result.stderr);
 const rows=JSON.parse(result.stdout).occurrences;
 assert.equal(rows.length,2);
 assert.deepEqual(rows.map(x=>x.table).sort(),['budgets_clubs','organisations']);
});
test('une reference alternative ne duplique pas les vrais appels sbUpsert',()=>{
 const result=invoke("sbUpsert('organisations',{id:'x'}); fetch('/rest/v1/organisations');",false);
 assert.equal(result.status,0,result.stderr);
 const rows=JSON.parse(result.stdout).occurrences;
 assert.equal(rows.filter(x=>x.symbol==="sbUpsert('organisations'").length,1);
});
