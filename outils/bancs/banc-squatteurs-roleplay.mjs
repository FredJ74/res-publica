import test from 'node:test';
import assert from 'node:assert/strict';
import {construirePromptSysteme,filtrerReponseSquatteur} from '../../api/_pnj-profils.js';
const agressifs=['la_bande_a_rotule','los_violentos','miliciens_zeles','clan_al_resistant'];
const tous=[...agressifs,'les_gars_du_bas','los_relajados','famille_kolkhozov','famille_al_bedouin'];
test('squatteurs : savoir diegetique et priorite immersion',()=>{
 for(const id of tous){
  const p=construirePromptSysteme(id,'fr');assert.ok(p.includes('IMMERSION PRIORITAIRE'));
  assert.ok(p.includes('CE QUE TU SAIS DE TA VIE ET DE CE LIEU'));
  assert.ok(!p.includes('regles REELLES de Res Publica'));
  assert.ok(!p.includes('dans le jeu satirique'));
 }
});
test('squatteurs : sortie HRP remplacee sans suggerer une transaction',()=>{
 for(const id of tous)for(const reponse of ['Cliquez sur les ordres du terrain.','Dans le jeu, les joueurs utilisent les boutons.','Il faut 3 PA pour cette action.']){
  const r=filtrerReponseSquatteur(id,reponse);assert.notEqual(r,reponse);
  assert.doesNotMatch(r,/ordres|boutons|joueurs|\bPA\b/);
 }
});
test('agressifs : pas de bonjour automatique ; replique RP preservee',()=>{
 for(const id of agressifs){
  assert.notEqual(filtrerReponseSquatteur(id,'Bonjour ! Bienvenue !'),'Bonjour ! Bienvenue !');
  const rp="Tu cherches quoi, ici ?";assert.equal(filtrerReponseSquatteur(id,rp),rp);
 }
 assert.equal(filtrerReponseSquatteur('sabri_coledur','Bonjour !'),'Bonjour !');
 assert.equal(filtrerReponseSquatteur('les_gars_du_bas','Bonjour !'),'Bonjour !');
 assert.match(filtrerReponseSquatteur('la_bande_a_rotule','Bonjour !','en'),/What/);
});
