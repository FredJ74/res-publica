// Déclarations et vrais profils : aucun compte ni appel externe.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { createRequire } from 'node:module';
import { profilExiste } from '../../api/_pnj-profils.js';
const require=createRequire(import.meta.url),{analyser,verifierImage}=require('../audits/auditer-republia-complet.cjs');
const root=new URL('../../',import.meta.url),lire=f=>fs.readFileSync(new URL(f,root),'utf8');
test('le catalogue réel des trois villes est examiné sans chemin cassé',()=>{
 const a=analyser();assert.equal(a.compteurs.villes,3);assert.ok(a.compteurs.batiments>=102);assert.ok(a.compteurs.pieces>=305);
 assert.deepEqual(a.anomalies.filter(x=>x.code==='image_introuvable'),[]);
});
test('chemins URL : espaces encodés admis, casse et références manquantes refusées',()=>{
 const fichiers=new Set(['images/Salle presse.png']);
 assert.equal(verifierImage('images/Salle%20presse.png?v=2',fichiers).statut,'locale_presente');
 assert.equal(verifierImage('images/salle%20presse.png',fichiers).statut,'casse_incorrecte');
 assert.equal(verifierImage('images/absente.webp',fichiers).statut,'fichier_absent');
 assert.equal(verifierImage('images/%xx.png',fichiers).statut,'url_invalide');
});
test('PSM : quatre images locales libres, sans mutation des variantes Luthécia ou des loyers',()=>{
 const c=vm.createContext({state:{country:'republic',currentCity:'ville_a'}});
 vm.runInContext(lire('data.js')+'\n'+lire('plateau-variantes-pieces.js'),c);
 for(const piece of ['vitrine_principale','boutique_milieu','arriere_boutique','cave_reserve']){
  c.piece=piece;
  // Interroge le vrai moteur pour chacun des deux états.
  vm.runInContext("PIECE_FAMILLES_ETAT.location.etat=()=> 'libre'",c);
  assert.match(vm.runInContext("varianteImagePiece('centre-commercial',piece,'ville_a')",c),/^images\/port-sainte-marie-centre-commercial-local-.*\.png$/);
  assert.match(vm.runInContext("varianteImagePiece('centre-commercial',piece,'capitale')",c),/^images\/luthecia-/);
  vm.runInContext("PIECE_FAMILLES_ETAT.location.etat=()=> 'occupee'",c);
  assert.equal(vm.runInContext("varianteImagePiece('centre-commercial',piece,'ville_a')",c),vm.runInContext("varianteImagePiece('centre-commercial',piece,'capitale')",c));
 }
});
test('les avocats volontairement non implantés ne reçoivent aucune personnalité inventée',()=>{
 assert.equal(profilExiste('maitre_ali_bihanbeton'),false);
 assert.equal(profilExiste('maitre_henri_nossant'),false);
 assert.match(lire('outils/bancs/banc-dialogue-pnj-republia.js'),/var MUETS_DECLARES/);
});
test('raccordements : profils de dialogue, routes et liens déclaratifs',async()=>{
 const {analyserRaccordements}=require('../audits/auditer-raccordements-republia.cjs');const a=await analyserRaccordements();
 assert.deepEqual(a.profils.filter(p=>!p.existe&&!p.agence&&!p.silenceDeclare),[]);
 assert.deepEqual(a.routes.filter(p=>p.chemin==='non_identifie'),[]);
 assert.deepEqual(a.graphe.liensInvalides,[]);
 assert.deepEqual(a.routeur.appelsSansDeclaration,[]);assert.deepEqual(a.routeur.erreursAnalyse,[]);
 assert.equal(a.graphe.carrefourPSM&&Object.keys(a.graphe.carrefourPSM.imagesParArrivee).length,4);
});
test('directions d’usine #351 : les actes conservent leur ordre de paiement hors du menu',()=>{
 const acorn=require('../vercel/node_modules/acorn');const source=lire('plateau-politique.js');
 const n=acorn.parse(source,{ecmaVersion:'latest'}).body.filter(n=>n.type==='VariableDeclaration'&&n.declarations.some(d=>d.id.name==='ACTIONS_POSTE_NOMME')||n.type==='FunctionDeclaration'&&n.id.name==='coutActionPosteNomme');
 const c=vm.createContext({state:{_ordreEnCours:'gestion_industrielle_portuaire'}});vm.runInContext(n.map(n=>source.slice(n.start,n.end)).join('\n'),c);
 for(const poste of ['directeur_pharma','directeur_tabac_alcools','directeur_raffinerie'])for(const [action,pa]of [['nommer',3],['revoquer',1]]){
  c.poste=poste;c.action=action;
  assert.deepEqual(JSON.parse(vm.runInContext('JSON.stringify(coutActionPosteNomme(poste,action,99,999))',c)),{fn:action+'_'+poste,pa,cost:0});
  assert.deepEqual(JSON.parse(vm.runInContext("JSON.stringify(coutActionPosteNomme(poste,'candidatures',0,0))",c)),{pa:0,cost:0},'lecture des candidatures inchangée');
 }
 assert.deepEqual(JSON.parse(vm.runInContext("JSON.stringify(coutActionPosteNomme('commissaire','candidatures',0,0))",c)),{fn:'nommer_commissaire',pa:3,cost:0},'ancien contrat municipal conservé');
 const audit=analyser();for(const v of audit.villes)for(const b of v.batiments)if(['usine-pharmaceutique-luthecia','pole-tabac-alcools-psm','raffinerie-montrouge'].includes(b.id))
 assert.ok(!b.pieces.flatMap(r=>r.ordres).some(o=>/^nommer_directeur_|^revoquer_directeur_/.test(o.fn)),'les boutons ne reviennent pas dans les usines');
});
test('#352 : la salle des ventes de la raffinerie conserve son image locale',()=>{
 const r=analyser().villes.find(v=>v.id==='ville_b').batiments.find(b=>b.id==='raffinerie-montrouge').pieces.find(r=>r.id==='salle_ventes');
 assert.equal(r.image,'images/montrouge/Montrouge_raffinerie_salle_ventes.png');
});
