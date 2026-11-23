// Renommages de PNJ validés par Fred le 23/11/2026 (GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, points 26, 37, 42, 44) :
// 20 PNJ, base et client.
//  - client : chaque nouveau nom est dans sa pièce, avec son portrait quand il en avait un, l'ancien nom gardé en
//    `aliasInformateur` (Novomirsk) ; les trois PNJ du point 42 sont au féminin et ont une fiche au féminin ; aucun ancien
//    libellé ne reste affiché ; Starovka et Krasnov gardent leurs propres PNJ ;
//  - base : la migration finale renomme exactement les 7 lignes d'informateurs_pnj relevées en lecture, et seulement elles.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const R = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(R, f), 'utf8');

// [ville, bâtiment, pièce, nouveau nom affiché, ancien nom, en base ?]
const RENOMMAGES = [
  ['capitale', 'centre-multinodal-luthecia', 'hall_gare', 'Vassili Sukhoï (PNJ)', 'Camarade Horaire', true],
  ['capitale', 'centre-multinodal-luthecia', 'hall_douanes', 'Lioudmila Proverkina (PNJ)', 'Agente Nadejda', true],
  ['ville_b', 'musee-novomirsk', 'hall', 'Zoïa Biletova (PNJ)', 'Hôtesse du musée de Krasnov', true],
  ['capitale', 'stade', 'buvette', 'Zinaïda Kvassova (PNJ)', 'Tenancier de Buvette', true],
  ['capitale', 'mairie-capitale', 'hall_mairie', 'Valentina Petchatkina', 'Secrétaire municipal Arseni Krylov', true],
  ['capitale', 'mairie-capitale', 'salle_archives', 'Ksenia Arkhipova (PNJ)', 'Archiviste municipale', false],
  ['capitale', 'palais-presidentiel', 'salle_presse_elysee', 'Rodion Glasnov (PNJ)', 'Porte-parole presidentiel', false],
  ['capitale', 'palais-gouvernement', 'hall', 'Timour Stoïkov (PNJ)', 'Garde du Peuple', false],
  ['capitale', 'dispensaire-public', 'salle_attente', 'Ekaterina Bintova (PNJ)', 'Infirmière de Novomirsk', false],
  ['capitale', 'dispensaire-public', 'salle_attente', 'Docteur Lev Poulsov (PNJ)', 'Médecin de garde de Novomirsk', false],
  ['capitale', 'loge-maconnique', 'hall_loge', 'Gavriil Zamkov', 'Frere Gardien', false],
  ['capitale', 'mairie-capitale', 'hall_mairie', 'Varvara Nakhodkina (PNJ)', 'Hotesse Objets Trouves', false],
  ['capitale', 'centre-affaires', 'tribune_republia', 'Efim Zametkov (PNJ)', 'Correspondant Local', false],
  ['capitale', 'stade', 'guichet_paris', 'Arkadi Stavkov (PNJ)', 'Bookmaker Officiel', false],
  ['capitale', 'stade', 'boutique', 'Alla Charfova (PNJ)', 'Vendeuse du Dynamo', false],
  ['capitale', 'imprimerie-librairie', 'atelier', 'Platon Chriftov (PNJ)', 'Ouvrier typographe', false],
  ['capitale', 'palais-ambassades-novomirsk', 'accueil_ambassades_novomirsk', 'Elvira Priomova (PNJ)', "Hôtesse d'Accueil", true],
  ['capitale', 'palais-ambassades-novomirsk', 'accueil_ambassades_novomirsk', 'Gleb Okhranov (PNJ)', 'Agent de Sécurité', true],
  ['capitale', 'caserne-militaire', 'armurerie_militaire', 'Sergent Bogdan Zatvorov (PNJ)', 'Armurier Militaire', false],
  ['capitale', 'caserne-militaire', 'salle_faits_armes', 'Lieutenant Nestor Medalev (PNJ)', 'Archiviste Militaire', false]
];
const sansPnj = n => n.replace(' (PNJ)', '');

function monde() {
  const c = vm.createContext({ console, window: {}, state: { country: 'soviet' } });
  vm.runInContext(lire('data.js').replace(/^const (WORLD|BUILDINGS) =/mg, 'var $1 ='), c);
  return c;
}
function personnes(c, ville, bat, piece) {
  const cite = c.WORLD.soviet[ville], ctx = cite.buildingContext[bat] || {};
  const ro = (ctx.roomOverrides || {})[piece];
  if (ro && ro.persons && ro.persons.length) return ro.persons;
  if (ctx.roomsExtra && ctx.roomsExtra[piece]) return ctx.roomsExtra[piece].persons || [];
  return (c.BUILDINGS[bat].rooms[piece] || {}).persons || [];
}

test('20 renommages : client — nouveau nom dans sa pièce, ancien nom absent, alias et portrait gardés', () => {
  assert.equal(RENOMMAGES.length, 20);
  const c = monde();
  for (const [ville, bat, piece, nouveau, ancien] of RENOMMAGES) {
    const liste = personnes(c, ville, bat, piece), noms = liste.map(p => p.name);
    const p = liste.find(x => x.name === nouveau);
    assert.ok(p, `${nouveau} absent de ${bat}/${piece} : ${JSON.stringify(noms)}`);
    assert.ok(!noms.some(n => sansPnj(n) === ancien), `ancien libellé « ${ancien} » encore affiché dans ${bat}/${piece}`);
    if (ville === 'capitale' && !['Vassili Sukhoï (PNJ)', 'Lioudmila Proverkina (PNJ)'].includes(nouveau))
      assert.equal(p.aliasInformateur, ancien, `${nouveau} : alias de l'ancien nom`);
  }
  // Portraits recadrés conservés sous le nouveau nom.
  for (const n of ['Ekaterina Bintova (PNJ)', 'Elvira Priomova (PNJ)', 'Gleb Okhranov (PNJ)', 'Sergent Bogdan Zatvorov (PNJ)',
    'Varvara Nakhodkina (PNJ)', 'Ksenia Arkhipova (PNJ)', 'Timour Stoïkov (PNJ)', 'Arkadi Stavkov (PNJ)', 'Alla Charfova (PNJ)',
    'Platon Chriftov (PNJ)', 'Gavriil Zamkov', 'Docteur Lev Poulsov (PNJ)']) {
    const r = RENOMMAGES.find(x => x[3] === n), p = personnes(c, r[0], r[1], r[2]).find(x => x.name === n);
    assert.ok(p.photoUrl, n + ' : portrait');
  }
  // Starovka et Krasnov gardent leurs propres PNJ.
  assert.ok(personnes(c, 'ville_a', 'stade', 'buvette').some(p => p.name !== 'Zinaïda Kvassova (PNJ)'));
  assert.ok(!personnes(c, 'ville_a', 'palais-gouvernement', 'hall').some(p => p.name === 'Timour Stoïkov (PNJ)'));
});

test('point 42 : trois PNJ au féminin, fiches au féminin ; anciens identifiants de profil redirigés', () => {
  const c = monde();
  const role = (b, pc, n) => personnes(c, 'capitale', b, pc).find(p => p.name === n).role;
  assert.equal(role('stade', 'buvette', 'Zinaïda Kvassova (PNJ)'), 'Tenancière de la buvette');
  assert.equal(role('mairie-capitale', 'hall_mairie', 'Valentina Petchatkina'), 'Secrétaire municipale');
  assert.equal(role('mairie-capitale', 'salle_archives', 'Ksenia Arkhipova (PNJ)'), 'Archiviste municipale');
  const fiches = lire('api/_pnj-personnalites.js');
  for (const [id, nom, mot] of [['sovarka_zinaida_kvassova', 'Zinaïda Kvassova', 'Tenancière'],
    ['sovarka_valentina_petchatkina', 'Valentina Petchatkina', 'Secrétaire municipale'], ['sovarka_ksenia_arkhipova', 'Ksenia Arkhipova', 'Archiviste municipale']]) {
    const i = fiches.indexOf(`'${id}':`); assert.ok(i > 0, id);
    const bloc = fiches.slice(i, fiches.indexOf('style:', i));
    assert.match(bloc, new RegExp('nom: "' + nom + '"')); assert.match(bloc, new RegExp(mot));
  }
  const alias = lire('api/_pnj-sovarka.js');
  assert.match(alias, /sovarka_secretaire_municipal_arseni_krylov: 'sovarka_valentina_petchatkina'/);
  assert.match(alias, /sovarka_archiviste_municipale: 'sovarka_ksenia_arkhipova'/);
  // Table serveur régénérée : chaque nouveau nom de Novomirsk a sa ligne de profil.
  const gen = lire('api/_pnj-sovarka-genere.js');
  for (const [, , , nouveau] of RENOMMAGES.slice(3)) assert.ok(gen.includes('"nouveau": "' + sansPnj(nouveau) + '"'), nouveau);
});

test('base : la migration finale renomme exactement les 7 lignes d\'informateurs relevées, et seulement elles', () => {
  const sql = lire('migrations/20261123230000_renommages_pnj_finale.sql');
  assert.match(sql, /^-- (NON )?APPLIQUÉE/m);
  const updates = sql.match(/^UPDATE public\.informateurs_pnj/mg) || [];
  assert.equal(updates.length, 7);
  for (const [ville, bat, piece, nouveau, ancien, enBase] of RENOMMAGES) {
    const n = sansPnj(nouveau);
    if (enBase) {
      const pieceBase = nouveau === 'Lioudmila Proverkina (PNJ)' ? 'hall_gare' : piece;
      const ancienId = `soviet:${ville}:${bat}:${pieceBase}:${ancien}`.replace(/'/g, "''");
      assert.ok(sql.includes(`WHERE id = '${ancienId}'`), 'ancien identifiant : ' + ancienId);
      assert.ok(sql.includes(`nom = '${n.replace(/'/g, "''")}'`), 'nouveau nom : ' + n);
    } else {
      assert.ok(!sql.includes(`nom = '${n}'`), n + ' n\'existe que côté client : hors migration');
    }
  }
  assert.doesNotMatch(sql, /\b(DELETE|DROP|TRUNCATE)\b/);
});
