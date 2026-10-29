'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict'),vm=require('node:vm'),path=require('node:path');
const s=fs.readFileSync(path.join(__dirname,'../../plateau-pnj.js'),'utf8');
const start=s.indexOf('async function chargerOrganisationsPourRumeur()');
const end=s.indexOf('\n}',start)+2;
assert.ok(start>=0&&end>start);
const fn=s.slice(start,end);
const scope={sbLoadOrganisations:async()=>[
 {id:'cachee',nom:'Société Noire',country:'republic',type:'criminelle',visible:false,chef:'Secret Chef',membres:[{nom:'Membre inconnu'}]},
 {id:'publique',nom:'Association Publique',country:'republic',type:'economique',visible:true},
 {id:'masquee',nom:'Association Cachée',country:'republic',type:'economique',visible:false}
]};
vm.createContext(scope);
vm.runInContext(fn+';globalThis.testCharger=chargerOrganisationsPourRumeur;',scope);
(async()=>{const result=JSON.parse(JSON.stringify(await scope.testCharger()));assert.deepEqual(result.map(x=>x.id),['publique','cachee']);assert.deepEqual(Object.keys(result[1]).sort(),['country','id','nom']);assert.ok(!JSON.stringify(result).includes('Secret Chef'));assert.ok(!JSON.stringify(result).includes('Membre inconnu'));console.log('OK - organisations criminelles ciblables, dirigeants et membres jamais projetés');})().catch(e=>{console.error(e);process.exitCode=1});
