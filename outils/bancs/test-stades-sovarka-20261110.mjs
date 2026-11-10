import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';

const root = path.resolve(import.meta.dirname,'../..');
const lire = nom => fs.readFileSync(path.join(root,nom),'utf8');
const data = lire('data.js');
const sport = lire('plateau-organisations-quetes.js');
const commerce = lire('plateau-actions-illegales-rumeurs.js');
const tarifs = lire('migrations/20261110083000_stades_sovarka_carte_tarifs.sql');
const paris = lire('migrations/20261110083100_football_paris_playoffs.sql');
const contexte = vm.createContext({console,window:{}});
vm.runInContext(data,contexte);
const stade = vm.runInContext('BUILDINGS.stade',contexte);
const dynamo = vm.runInContext('WORLD.soviet.capitale.buildingContext.stade',contexte);

test('la buvette du socle ne propose plus Prendre un verre dans aucune ville',()=>{
  assert.equal(stade.rooms.buvette.orders.some(o=>o.fn==='consommer_buvette'),false);
  assert.equal(stade.rooms.buvette.orders.filter(o=>o.fn==='consulter_carte_commerce').length,1);
  assert.equal(data.includes("{fn:'consommer_buvette'"),false);
});

test('adhésion des supporters : Dynamo 25 PSK, autres stades sans modification',()=>{
  assert.ok(dynamo.roomOverrides.siege_supporters.excludeOrders.includes('rejoindre_club_supporters'));
  assert.equal(dynamo.roomOverrides.siege_supporters.orders.find(o=>o.fn==='rejoindre_club_supporters').cost,25);
  assert.equal(stade.rooms.siege_supporters.orders.find(o=>o.fn==='rejoindre_club_supporters').cost,50);
  assert.match(tarifs,/ordres_couts_pays[\s\S]*rejoindre_club_supporters','soviet',1,25/);
  assert.match(tarifs,/v_type='supporters' AND v_pays='soviet' THEN v_montant := 25/);
});

test('quatre produits propres à Novomirsk, avec prix PSK et recettes serveur',()=>{
  for(const [id,prix] of [['the_chaud_sovarka',5],['chocolat_chaud_sovarka',8],['vin_chaud_sovarka',12],['pirojki_sovarka',6]]){
    assert.ok(commerce.includes(id),id+' : recette client');
    assert.ok(tarifs.includes(id),id+' : recette serveur');
    assert.ok(tarifs.includes('"'+id+'":'+prix),id+' : prix de la carte en base');
  }
  assert.match(commerce,/data\.country === 'soviet' && data\.city === 'capitale'/);
  assert.match(tarifs,/WHERE e\.id='buvette-soviet-capitale-stade-buvette'/);
  assert.match(commerce,/prix\.toLocaleString\('fr-FR'\) \+ ' ' \+ monnaie/);
});

test('boutique : prix locaux affichés et facturés par la fonction serveur',()=>{
  assert.match(sport,/enSovarka \? 25 : 80/);
  assert.match(sport,/enSovarka \? 20 : 60/);
  assert.match(sport,/enSovarka \? 45 : 150/);
  assert.match(tarifs,/a\.country='soviet'[\s\S]*'echarpe' THEN 25 WHEN 'casquette' THEN 20 WHEN 'maillot' THEN 45/);
  assert.match(sport,/const monnaie = COUNTRIES\[state\.country\]\?\.cur \|\| 'FR'/);
});

const debut = sport.indexOf('function rencontresPariPlayoff(');
const fin = sport.indexOf('async function doParierMatch(',debut);
assert.ok(debut>0 && fin>debut);
const ctx=vm.createContext({});
vm.runInContext(sport.slice(debut,fin),ctx);

test('bookmaker : les quarts aller et retour sont les vraies paires du serveur',()=>{
  const saison={phase:'quarts',playoffs:{etape:'quarts_aller',prochainKickoffISO:'2030-11-15T19:00:00.000Z',quarts:{paires:[['A','B'],['C','D']]}}};
  assert.deepEqual(JSON.parse(JSON.stringify(ctx.rencontresPariPlayoff(saison).matchs)),[{home:'A',away:'B'},{home:'C',away:'D'}]);
  saison.playoffs.etape='quarts_retour';
  assert.deepEqual(JSON.parse(JSON.stringify(ctx.rencontresPariPlayoff(saison).matchs)),[{home:'B',away:'A'},{home:'D',away:'C'}]);
  saison.playoffs.etape='demies_aller';saison.playoffs.demies={paires:[['A','D']]};
  assert.deepEqual(JSON.parse(JSON.stringify(ctx.rencontresPariPlayoff(saison).matchs)),[{home:'A',away:'D'}]);
  saison.playoffs.etape='finale';saison.playoffs.finale={paire:['A','C']};
  assert.deepEqual(JSON.parse(JSON.stringify(ctx.rencontresPariPlayoff(saison).matchs)),[{home:'A',away:'C'}]);
});

test('serveur refuse les tickets inventés et les mises après le coup d’envoi',()=>{
  assert.match(paris,/v_s#>>'\{playoffs,etape\}' IS DISTINCT FROM p_manche/);
  assert.match(paris,/now\(\)>=v_kickoff/);
  assert.match(paris,/RETURN jsonb_build_object\('ok',false,'raison','match_inconnu'\)/);
  assert.match(paris,/pg_advisory_xact_lock/);
  assert.match(paris,/public\.payer_ordre\(v_moi,'parier_match',1,0\)/);
  assert.match(paris,/public\.argent_debiter_interne\(v_moi,p_mise,'liquide_puis_nationale'\)/);
  assert.match(paris,/FOR UPDATE SKIP LOCKED/);
  assert.match(paris,/jsonb_array_elements\(v_resultats\)/);
  assert.match(sport,/await reglerParisPlayoff\(etapeAvant\)/);
});
