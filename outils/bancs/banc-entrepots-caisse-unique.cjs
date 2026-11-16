// Sources exécutables du cron : les commentaires historiques ne sont pas des écritures.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const acorn=require('../e2e/node_modules/acorn');
const lire=f=>fs.readFileSync(new URL('../../'+f,`file://${__filename}`),'utf8');
function anciensChamps(src){
 const ast=acorn.parse(src,{ecmaVersion:'latest',sourceType:'module'}),trouves=[];
 function visit(n){
  if(!n||typeof n!=='object')return;
  if(n.type==='VariableDeclarator'&&/^(entrepot|entrepotCible)$/.test(n.id?.name||'')){
   const scan=x=>{if(!x||typeof x!=='object')return;if(x.type==='Property'&&(x.key?.name||x.key?.value)==='caisse')trouves.push(x.start);for(const v of Object.values(x))if(v&&typeof v==='object')Array.isArray(v)?v.forEach(scan):scan(v);};scan(n.init);
  }
  if(n.type==='MemberExpression'&&(n.property?.name||n.property?.value)==='caisse'&&/entrepot/i.test(src.slice(n.object.start,n.object.end)))trouves.push(n.start);
  for(const v of Object.values(n))if(v&&typeof v==='object')Array.isArray(v)?v.forEach(visit):visit(v);
 }visit(ast);return trouves;
}
test('le cron ne crée ni ne lit une seconde bourse d’entrepôt',()=>assert.deepEqual(anciensChamps(lire('api/cron-minuit.js')),[]));
test('contre-épreuves : dotation et ancien solde détectés, commentaire ignoré',()=>{
 assert.equal(anciensChamps('const entrepotCible=x.entrepot||{stock:{},caisse:8500};').length,1);
 assert.equal(anciensChamps('const n=etat.entrepot.caisse;').length,1);
 assert.deepEqual(anciensChamps('// etat.entrepot.caisse = 8500\nconst entrepotCible=x.entrepot||{stock:{}};'),[]);
});
function portesDansFonction(source,nom){
 const ast=acorn.parse(source,{ecmaVersion:'latest',sourceType:'module'}),n=ast.body.find(x=>x.type==='FunctionDeclaration'&&x.id.name===nom);assert.ok(n,nom);const portes=[];
 function visit(x){if(!x||typeof x!=='object')return;if(x.type==='CallExpression'&&x.callee?.name==='sbRpc'&&['entrepot_caisse_lire','entrepot_caisse_mouvement','commerce_international_passe'].includes(x.arguments[0]?.value))portes.push(x.arguments[0].value);for(const v of Object.values(x))if(v&&typeof v==='object')Array.isArray(v)?v.forEach(visit):visit(v);}visit(n);return portes;
}
test('livraisons, travaux et exportations passent chacun par leur porte canonique actuelle',()=>{
 const s=lire('api/cron-minuit.js');
 assert.deepEqual(portesDansFonction(s,'avancerChantiersQuotidien'),['entrepot_caisse_mouvement']);
 assert.deepEqual(portesDansFonction(s,'livrerEntrepotsQuotidien'),['entrepot_caisse_lire','entrepot_caisse_mouvement']);
 // #1024 : les contrats internationaux sont désormais atomiques au serveur ; aucun ancien paiement exportateur en parallèle.
 assert.deepEqual(portesDansFonction(s,'traiterCommerceInternationalQuotidien'),['commerce_international_passe']);
 const e=lire('plateau-entrepots.js');assert.match(e,/sbGetCaisseBatiment\(state.country \+ '_entrepot_' \+ state.poste.city\)/);
 const mauvais=s.replace("sbRpc('commerce_international_passe'","sbRpc('entrepot_caisse_mouvement'");assert.notDeepEqual(portesDansFonction(mauvais,'traiterCommerceInternationalQuotidien'),['commerce_international_passe']);
});
test('commerce international réel : légalité avant RPC, paramètres transmis une fois, panne et refus sans faux succès',async()=>{
 const vm=require('node:vm'),source=lire('api/cron-minuit.js'),ast=acorn.parse(source,{ecmaVersion:'latest',sourceType:'module'}),n=ast.body.find(x=>x.type==='FunctionDeclaration'&&x.id.name==='traiterCommerceInternationalQuotidien');assert.ok(n);
 function decor({legal=true,resultat={ok:true},panne=false}={}){const appels=[],c={HEADERS_SERVICE:'fixture-service',jourParisISO:()=> '2026-11-16',matieresInterditesPays:async p=>{appels.push(['legalite',p]);return legal?new Set(p==='republic'?['opium']:['cocaine']):null;},sbRpc:async(...a)=>{appels.push(['rpc',...JSON.parse(JSON.stringify(a))]);if(panne)throw Error('fixture reseau');return resultat;}};vm.createContext(c);vm.runInContext(source.slice(n.start,n.end),c);return {appels,run:()=>c.traiterCommerceInternationalQuotidien()};}
 const ok=decor();assert.deepEqual(await ok.run(),{ok:true});assert.deepEqual(ok.appels,[['legalite','republic'],['legalite','soviet'],['rpc','commerce_international_passe',{p_jour:'2026-11-16',p_interdites:{republic:['opium'],soviet:['cocaine']}},'fixture-service']]);
 const loi=decor({legal:false});await assert.rejects(loi.run(),/legalite_non_verifiable/);assert.equal(loi.appels.filter(x=>x[0]==='rpc').length,0);
 for(const cfg of [{resultat:{ok:false,raison:'fixture_refus'}},{panne:true}]){const d=decor(cfg);await assert.rejects(d.run(),/commerce_international:/);assert.equal(d.appels.filter(x=>x[0]==='rpc').length,1);}
});
