// node --test outils/bancs/banc-annuaire-territoires.cjs
const test=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'../..');
const politique=fs.readFileSync(path.join(root,'plateau-politique.js'),'utf8');
const a=politique.indexOf('async function consulterAnnuaireDeputes()');
const b=politique.indexOf('// =====================',a);
assert.ok(a>=0&&b>a);
for(const [country,noms] of Object.entries({
 republic:['Luthécia','Port-Sainte-Marie','Montrouge'],
 soviet:['Novomirsk','Starovka','Krasnov'],
 narco:['Ciudad Roja','Puerto Negro','Villa Sangre'],
 khalija:['Al Madina','Oasis City','Al-Petrol']
}))test(`${country} : trois villes issues du referentiel, aucun nom d’un autre empire`,async()=>{
 const dom=new Map();
 const ctx=vm.createContext({console,state:{country},
  document:{getElementById:id=>{if(!dom.has(id))dom.set(id,{classList:{add(){}},innerHTML:''});return dom.get(id);}},
  assembleeOccupation:()=>['capitale','ville_a','ville_b'].map(city=>({city,rang:1,pnjNom:'Temoin'})),
  renderTitreSectionOrganigramme:nom=>'<section>'+nom+'</section>',escapeHtmlText:String});
 vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8'),ctx);
 vm.runInContext(politique.slice(a,b),ctx);await ctx.consulterAnnuaireDeputes();
 const html=dom.get('postes-body').innerHTML;
 const sections=[...html.matchAll(/<section>(.*?)<\/section>/g)].map(m=>m[1]);
 assert.deepEqual(sections,noms);
 assert.equal(vm.runInContext("villeNom('inconnu','capitale')",ctx),null);
});
