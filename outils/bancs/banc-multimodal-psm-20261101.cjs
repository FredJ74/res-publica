'use strict';
// Centre multimodal de Port-Sainte-Marie — clôture Luthécia (01/11/2026).
// Rendu réel de ouvrirModalTransport (plateau-navigation.js) sur le référentiel VILLES de
// data.js, depuis PSM (ville_a) : destinations non vides et nommées, sans PSM elle-même,
// tarifs identiques entre l'ordre du hall, le moteur de transport et le miroir ordres_couts ;
// aucun ordre « Demander conseil à Mireille » dans aucun centre. Ne touche pas au moteur de
// transport ni aux déplacements collectifs (#219). Aucun réseau.
// CONTRE=<ref git> : rejoue contre une ancienne version (77d9436^ : libellés vides, Mireille).
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),{execFileSync}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),ref=process.env.CONTRE;
const lire=f=>ref?execFileSync('git',['show',ref+':'+f],{cwd:root,encoding:'utf8'}):fs.readFileSync(path.join(root,f),'utf8');
const ctx={console};vm.createContext(ctx);
vm.runInContext(lire('data.js')+';this.VILLES=VILLES;this.villesDe=villesDe;this.BUILDINGS=BUILDINGS;this.COUNTRIES=typeof COUNTRIES!=="undefined"?COUNTRIES:{};',ctx);
const nav=lire('plateau-navigation.js');
const extraire=(debut,fin)=>{const a=nav.indexOf(debut),b=nav.indexOf(fin,a+debut.length);assert.ok(a>=0&&b>a,debut);return nav.slice(a,b);};
vm.runInContext(extraire('const TRANSPORT_CONFIG = {','\n};')+'\n};this.TRANSPORT_CONFIG=TRANSPORT_CONFIG;',ctx);
vm.runInContext(extraire('function ouvrirModalTransport(mode)','\nasync function executerVoyage(')+';this.ouvrirModalTransport=ouvrirModalTransport;',ctx);

function ouvrirDepuis(ville,mode){
 const el={postes:{innerHTML:''},titre:{textContent:''},modal:{classList:{add(){}}}};
 Object.assign(ctx,{state:{country:'republic',currentCity:ville,estEmprisonne:false},EMPIRES_CONFIG:{},showToast(){},
  document:{getElementById:id=>id==='postes-body'?el.postes:id==='postes-modal-title'?el.titre:el.modal}});
 ctx.ouvrirModalTransport(mode);
 return [...el.postes.innerHTML.matchAll(/confirmerTransport\('(\w+)','(\w+)','(\w+)'\)[\s\S]*?<div[^>]*>([^<]*)<\/div>/g)].map(m=>({ville:m[3],nom:m[4]}));
}

for(const mode of ['train','bus'])test('depuis Port-Sainte-Marie, '+mode+' : Luthécia et Montrouge, nommées',()=>{
 const d=ouvrirDepuis('ville_a',mode);
 assert.deepEqual(d.map(x=>x.ville).sort(),['capitale','ville_b']);
 assert.deepEqual(d.map(x=>x.nom).sort(),['Luthécia','Montrouge']);
});

test('hall de la gare de PSM : ordres et tarifs de l écran alignés sur le moteur de transport',()=>{
 const hall=ctx.BUILDINGS['centre-multinodal-port-sainte-marie'].rooms.hall_gare_psm;
 const ordres=Object.fromEntries(hall.orders.map(o=>[o.fn,o]));
 assert.deepEqual(Object.keys(ordres).sort(),['prendre_bus_taxi','prendre_train']);
 for(const [fn,mode] of [['prendre_train','train'],['prendre_bus_taxi','bus']]){
  const c=ctx.TRANSPORT_CONFIG[mode];
  assert.equal(c.ordre,fn);assert.deepEqual([ordres[fn].pa,ordres[fn].cost],[c.pa,c.cost],fn+' : écran = moteur');
 }
 const routeur=lire('plateau-router.js');
 assert.match(routeur,/fn === 'prendre_train'\)\s*\{ ouvrirModalTransport\('train'\)/);
 assert.match(routeur,/fn === 'prendre_bus_taxi'\)\s*\{ ouvrirModalTransport\('bus'\)/);
});

test('aucun centre ne propose « Demander conseil à Mireille »',()=>{
 for(const [id,b] of Object.entries(ctx.BUILDINGS))for(const [pid,p] of Object.entries(b.rooms||{}))for(const o of p.orders||[]){
  assert.ok(!/conseil à Mireille/i.test(o.label||''),id+'/'+pid);
  assert.notEqual(o.fn,'renseignement_transport_intl',id+'/'+pid);
 }
});
