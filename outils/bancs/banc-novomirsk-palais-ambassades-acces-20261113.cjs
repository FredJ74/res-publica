'use strict';
const assert=require('node:assert/strict');
const test=require('node:test');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'../..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const src=read('data.js');
const nav=read('plateau-navigation.js');
const politics=read('plateau-politique.js');
const sql=read('migrations/20261113160500_novomirsk_palais_ambassades_acces.sql');
const {WORLD,BUILDINGS}=Function(src+'\nreturn {WORLD,BUILDINGS};')();
const palais=BUILDINGS['palais-ambassades-novomirsk'];
const pavillon=BUILDINGS['pavillon-ambassadeurs-novomirsk'];
const luthecia=BUILDINGS['quartier-ambassades'];
test('Salle de réception exclusivement au Pavillon à Novomirsk',()=>{
  assert.ok(palais&&pavillon&&luthecia);
  assert.ok(!Object.hasOwn(palais.rooms,'salle_reception'));
  assert.ok(Object.hasOwn(pavillon.rooms,'salle_reception'));
  assert.ok(Object.hasOwn(luthecia.rooms,'salle_reception'),'Luthécia doit rester intacte');
  const m=sql.match(/UPDATE public\.navigation_lieux_regles SET pieces =\s*'([^']+)'::jsonb/);
  assert.ok(m,'liste SQL des pièces');
  assert.deepEqual(JSON.parse(m[1]),Object.keys(palais.rooms));
});
test('Accueil : demandes d’audience et d’asile actives, aucune réservation de la salle du Pavillon',()=>{
  const accueil=palais.rooms.accueil_ambassades_novomirsk;
  assert.deepEqual(accueil.orders.map(o=>o.fn),['demander_audience_ambassadeur','demander_asile_politique']);
  assert.ok(accueil.orders.every(o=>!o.bientot&&o.cost===0));
  assert.deepEqual(accueil.orders.map(o=>o.pa),[1,2]);
  assert.ok(palais.rooms.bureau_republia_novomirsk);
  assert.ok(palais.rooms.bureau_khalija_novomirsk);
  assert.ok(palais.rooms.bureau_estado_novomirsk);
});
test('Le verrou client cible les trois bureaux de Novomirsk et conserve Luthécia',()=>{
  assert.match(nav,/bureau_republia_novomirsk: 'republic'/);
  assert.match(nav,/bureau_khalija_novomirsk: 'khalija'/);
  assert.match(nav,/bureau_estado_novomirsk: 'narco'/);
  assert.match(nav,/verifierAccesBureauAmbassade\(buildingId, roomId, tabEl\)/);
  assert.match(nav,/palais-ambassades-novomirsk/);
  assert.match(politics,/bureau_republia_novomirsk: 'republic'/);
  assert.match(politics,/enterRoom\(buildingId, buildingId === 'palais-ambassades-novomirsk' \? 'accueil_ambassades_novomirsk'/);
});
test('Les deux ordres affichent uniquement les trois ambassades étrangères au pays',()=>{
  assert.match(politics,/Object\.entries\(AMBASSADEURS_PNJ\)\.filter\(\(\[empireId\]\) => empireId !== state\.country\)/);
  assert.match(politics,/republic:\{ name: 'Hubert de La Courtoisie \(PNJ\)'/);
  const hostEmps={republic:['khalija','soviet','narco'],soviet:['khalija','narco','republic']};
  for(const [host,expected] of Object.entries(hostEmps))assert.deepEqual(['khalija','soviet','narco','republic'].filter(e=>e!==host),expected);
});
test('La navigation serveur revalide toutes les entrées, y compris groupes, sans audience',()=>{
  assert.match(sql,/p\.country='soviet' AND p\.current_city='capitale' AND p_batiment='palais-ambassades-novomirsk'/);
  assert.match(sql,/public\.ambassade_acces_bureau_interne\(CASE p_piece/);
  assert.match(sql,/IF NOT coalesce\(\(r->>'ok'\)::boolean,false\) THEN RETURN r; END IF;/);
  assert.match(sql,/pays_hote = v_pays AND empire = p_empire AND statut = 'accordee'/);
  assert.match(sql,/pays_hote = v_pays AND empire = e AND statut = 'accordee'/);
  assert.match(sql,/WHEN 'republic' THEN jsonb_build_object\('ambassadeur','Hubert de La Courtoisie'/);
  assert.match(sql,/WHEN 'soviet' THEN 'palais-ambassades-novomirsk'/);
  assert.match(sql,/PERFORM public\.ambassades_audiences_echoir\(v_moi\)/);
});
test('Parcours Luthécia toujours reconnu et ordres des bureaux toujours différés',()=>{
  assert.deepEqual(luthecia.rooms.accueil_ambassades.orders.map(o=>o.fn),
    ['demander_audience_ambassadeur','demander_asile_politique','reserver_salle_reception']);
  for(const k of ['bureau_republia_novomirsk','bureau_khalija_novomirsk','bureau_estado_novomirsk']){
    assert.ok(palais.rooms[k].orders.every(o=>o.bientot),'ne pas ouvrir des actions inter-empires non raccordées');
  }
});
