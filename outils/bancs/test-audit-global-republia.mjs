// Déclarations et vrais profils : aucun compte ni appel externe.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { createRequire } from 'node:module';
import { profilExiste, construirePromptSysteme } from '../../api/_pnj-profils.js';
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
test('les deux avocats locaux ont un profil ordinaire correspondant à leur identité et ville',()=>{
 for(const [id,nom,ville]of [['maitre_ali_bihanbeton','Maître Ali Bihanbéton','Port-Sainte-Marie'],['maitre_henri_nossant','Maître Henri Nossant','Montrouge']]){
  assert.equal(profilExiste(id),true);
  const prompt=construirePromptSysteme(id,'fr');assert.match(prompt,new RegExp(nom));assert.match(prompt,new RegExp(ville));
 }
 assert.equal(profilExiste('maitre_local_invente'),false);
});
