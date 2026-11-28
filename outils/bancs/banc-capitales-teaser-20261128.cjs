// Banc statique des capitales en teaser (28/11/2026) : ordres déclarés = tarifs du miroir, neuf langues complètes,
// répliques fixes, PNJ adressables, migrations porteuses de leurs marqueurs. Aucun appel distant.
const test = require('node:test'), assert = require('node:assert'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const R = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(R, f), 'utf8');
const LANGUES = ['fr', 'en', 'es', 'de', 'ru', 'ko', 'ar', 'pt-BR', 'zh-TW'];

function charger() {
  const ctx = vm.createContext({ console, state: { country: 'narco', currentCity: 'capitale' }, window: {} });
  vm.runInContext(lire('data.js') + ';this.__W=WORLD;this.__O=ordresDeclaresDeLaPiece;', ctx);
  return ctx;
}

test('ordres des hôtels et de la douane : déclarés dans data.js avec le tarif du miroir des coûts', () => {
  const ctx = charger(), W = ctx.__W;
  const seed = lire('baseline/seeds/95_a-regenerer/ordres_couts.sql');
  const cr = W.narco.capitale.buildingContext['hotel-republica'], am = W.khalija.capitale.buildingContext['hotel-republica'];
  const cm = W.narco.capitale.buildingContext['centre-multinodal-luthecia'];
  const ordres = [].concat(...Object.values(cr.roomsExtra).map(r => r.orders), ...Object.values(cr.roomOverrides).map(r => r.orders || []),
    ...Object.values(am.roomsExtra).map(r => r.orders), ...Object.values(am.roomOverrides).map(r => r.orders || []), cm.roomOverrides.hall_douanes.orders);
  const propres = ordres.filter(o => /^(cr|am)_/.test(o.fn));
  assert.strictEqual(new Set(propres.map(o => o.fn)).size, 13);
  for (const o of propres) assert.ok(seed.includes("('" + o.fn + "'," + o.pa + ',' + o.cost + ')'), o.fn + ' absent du miroir');
  assert.ok(ordres.some(o => o.fn === 'escort_standard'), 'escort de la suite de Ciudad Roja');
  assert.deepStrictEqual(Object.keys(am.roomsExtra).sort(), ['hammam_femmes', 'hammam_hommes', 'salon_gentlemen']);
  assert.strictEqual(am.name, "Hôtel Royal d'Al-Khalija");
  for (const r of [...Object.values(am.roomsExtra), ...Object.values(am.roomOverrides)])
    assert.ok(r.imageUrl.startsWith('images/Al-Khalija/Al Madina/Al_Madina_hotel_') && fs.existsSync(path.join(R, r.imageUrl)), r.imageUrl);
  const noms = JSON.stringify([cr, am, cm]);
  for (const ancien of ['Pedro Tequila', 'Lupe Cantina', 'Lola Discreta', 'Hassan Marchandage', 'Yasmine Épices'])
    assert.ok(!noms.includes(ancien), ancien + ' encore à l’hôtel');
});

test('neuf langues complètes : fenêtres des hôtels et compteur d’ouverture', () => {
  for (const [fichier, globale] of [['plateau-hotels-teaser.js', 'RP_HOTELS_TEASER_T'], ['plateau-teaser-capitales.js', 'RP_TEASER_CAPITALES_T']]) {
    const ctx = vm.createContext({ window: {}, console });
    vm.runInContext(lire(fichier), ctx);
    const T = ctx.window[globale];
    assert.deepStrictEqual(Object.keys(T).sort(), [...LANGUES].sort(), fichier);
    const cles = o => Object.entries(o).flatMap(([k, v]) => (v && typeof v === 'object') ? cles(v).map(c => k + '.' + c) : [k]).sort();
    for (const l of LANGUES) assert.deepStrictEqual(cles(T[l]), cles(T.fr), fichier + ' : ' + l);
  }
});

test('répliques fixes et PNJ adressables', async () => {
  const h = await import(path.join(R, 'api/_hotels-teaser.js'));
  assert.ok(h.repliqueAugusto('fr').includes("Dis donc Gringo, tu ne serais pas en train d'essayer de me voler mes filles ?!"));
  assert.ok(h.repliqueAugusto('fr').includes('Ton arrogance me plaît, gringo !'));
  for (const l of LANGUES) { assert.ok(h.repliqueAugusto(l).length > 100 && h.repliqueAugusto(l) !== h.repliqueAugusto('fr') || l === 'fr', l); assert.ok(h.repliqueDouanier(l), l); }
  assert.strictEqual(h.repliqueDouanier('fr'), 'Voyez avec la cheffe.');
  const p = await import(path.join(R, 'api/_pnj-profils.js'));
  for (const id of ['rosario_esmeralda', 'bruno_macizo', 'tito_maletas', 'svetlana_zolotova', 'valentina_fuego', 'don_augusto_bigotes', 'rafael_toro',
    'matias_bandeja', 'carlos_retraso', 'juanita_soborno', 'douanier_moustachu_uno', 'douanier_moustachu_dos', 'amira_miftah', 'said_chanta',
    'karim_sahn', 'nabil_naana', 'faris_dukhan', 'jabbar_bawwab', 'hamid_bukhar', 'oum_saboun']) assert.ok(p.profilExiste(id), id);
});

test('migrations : marqueurs et transactions', () => {
  const a = lire('migrations/20261128020000_capitales_teaser_frontiere_acces.sql'), b = lire('migrations/20261128030000_capitales_teaser_hotels.sql');
  for (const m of ['teaser_transport_v1', 'hotel_royal_genre_v1', 'hotel_royal_forcer_v1', 'teaser_ouverture_compteur']) assert.ok(a.includes(m), m);
  for (const m of ['ciudad_roja_escorts_v1', 'hotel_protection_chaleur_v1', 'hotel_protection_chaleur_v2', 'hotel_royal_navigation_v1', 'hotel_teaser_agir',
    'hotel_backgammon_repondre', 'ciudad_roja_augusto_tirade', 'hotel_teaser_habitues']) assert.ok(b.includes(m), m);
  for (const s of [a, b, lire('migrations/20261128040000_hotel_royal_tarifs_doubles.sql')]) { assert.ok(/\nBEGIN;\n/.test(s)); assert.ok(/\nCOMMIT;\n/.test(s)); }
});
