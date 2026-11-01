'use strict';
// Positions PJ après actualisation F5 — clôture Luthécia (01/11/2026), mission limitée :
// vérifier sur main que la position affichée au rechargement est celle du serveur et
// qu'aucun ancien chemin local ne peut la remplacer. Ne corrige aucun moteur de déplacement
// (#219, #318, #324). Lecture du code réel ; aucun réseau, aucune donnée de joueur.
// Usage : node --test outils/bancs/banc-position-f5-luthecia-20261101.cjs
//         CONTRE=<ref git> … : rejoue contre une ancienne version (d5be731^ : fusion absente).
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),{execFileSync}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),ref=process.env.CONTRE;
const lire=f=>ref?execFileSync('git',['show',ref+':'+f],{cwd:root,encoding:'utf8'}):fs.readFileSync(path.join(root,f),'utf8');
function fonction(source,signature){
 const a=source.indexOf(signature);assert.ok(a>=0,signature+' introuvable');
 const b=source.indexOf('\nfunction ',a+signature.length),c=source.indexOf('\nasync function ',a+signature.length);
 const fin=[b,c].filter(x=>x>0).sort((x,y)=>x-y)[0]||source.length;return source.slice(a,fin);
}
const sansCommentaires=s=>s.replace(/\/\*[\s\S]*?\*\//g,'').replace(/(^|[^:'"\\])\/\/.*$/gm,'$1');
const core=lire('plateau-core.js'),supa=lire('supabase.js'),rue=lire('plateau-rue-centrale.js');

test('chargement : la position n est restaurée qu une fois, après la réponse du serveur',()=>{
 const f=sansCommentaires(fonction(core,'function loadCharacter()'));
 const appels=[...f.matchAll(/restaurerPositionApresChargement\(/g)].map(m=>m.index);
 assert.equal(appels.length,1,'un seul appel de restauration dans loadCharacter');
 const reconciliation=f.indexOf('Object.assign(state, sbState)');
 assert.ok(reconciliation>=0&&appels[0]>reconciliation,'restauration postérieure à la réconciliation serveur');
 assert.ok(appels[0]>f.indexOf('applyCharToState(state.char)',reconciliation),'sur la fiche rendue par le serveur');
});

test('le cache local ne fournit jamais bâtiment ni pièce',()=>{
 const f=sansCommentaires(fonction(core,'function applyCharToState('));
 assert.doesNotMatch(f,/state\.currentBuilding\s*=/,'applyCharToState ne pose pas le bâtiment');
 assert.doesNotMatch(f,/state\.currentRoom\s*=/,'applyCharToState ne pose pas la pièce');
 const l=sansCommentaires(fonction(core,'function loadCharacter()'));
 assert.doesNotMatch(l,/positionLocale|currentBuilding\s*=\s*char\.|currentRoom\s*=\s*char\./,'aucune réimposition locale');
});

test('rue de Républia : position relue au serveur, le cache ne sert qu à l orientation',()=>{
 const f=fonction(rue,'async function initialiserRueCentrale(');
 const branche=f.slice(f.indexOf("if (pays === 'republic')"));
 assert.match(branche,/sbRpc\('rue_position_lire'/,'lecture serveur de la rue');
 assert.ok(branche.indexOf('rue_position_lire')<(branche.indexOf('obtenirNoeudRueCentraleMemorise')>>>0),'lecture serveur avant tout souvenir local');
 assert.match(branche,/position\.city !== state\.currentCity/,'refus nommé si la ville ne correspond pas');
});

test('sauvegarde générique : position en fusion à trois voies (une copie ancienne ne la défait pas)',()=>{
 for(const champ of ['current_city','current_building','current_room'])
  assert.match(supa,new RegExp('SB_FICHE_FUSION[\\s\\S]*?\\b'+champ+':'),champ+' fusionné à trois voies');
 assert.match(supa,/state\.personnageChargeDepuisServeur !== false/,'aucune position écrite avant la lecture serveur');
});

// Dépendance extérieure : l'autorité serveur sur toute écriture de position (garde
// navigation_positions_garder) et la restauration sans commande de navigation après F5
// (representerPositionServeur, #318) arrivent avec #219 + #318. Ce test passera seul quand
// elles seront dans main ; il ne duplique pas leur correction.
test('dépendance #219/#318 : garde serveur des positions et restauration sans renavigation',{todo:'livré par #219 et #318 (non fusionnés)'},()=>{
 const migrations=fs.readdirSync(path.join(root,'migrations')).filter(f=>f.endsWith('.sql')).map(f=>fs.readFileSync(path.join(root,'migrations',f),'utf8')).join('\n');
 assert.match(migrations,/navigation_positions_garder/);
 assert.match(core,/representerPositionServeur/);
});
