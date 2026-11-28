// Banc statique des réponses de Fred du 28/11/2026 (après-midi) aux 12 questions du teaser : migration porteuse de ses
// marqueurs, assignation à résidence et Tito côté navigateur, PNJ du centre multimodal d'Al Madina, traductions des
// deux capitales dans les neuf langues. Aucun appel distant (l'essai en production est consigné dans RELAIS.md).
const test = require('node:test'), assert = require('node:assert'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const R = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(R, f), 'utf8');
const LANGUES = ['fr', 'en', 'es', 'de', 'ru', 'ko', 'ar', 'pt-BR', 'zh-TW'];
const MIG = 'migrations/20261128100000_reponses_fred_teaser.sql';

test('migration : marqueurs, transaction, aucune rumeur écrite à la main', () => {
  const m = lire(MIG);
  assert.ok(/\nBEGIN;\n/.test(m) && /\nCOMMIT;\n/.test(m));
  for (const k of ['hotel_royal_assignation_v1', 'pa_repos_suites_v1', 'transfert_peine_au_sommeil_v1', 'interrogatoire_48h_v1',
    'renseignement_interrogatoire_passe', 'ciudad_roja_escorts_dormir_v1', 'moeurs_amende_comptes_v1', 'tito_vrai_secret_v1',
    'tito_vrai_secret_decl_v1', 'hotel_secret_vrai_interne(', 'service_etage_tarif_pays_v1', 'organisation_secrete_donnees_interne'])
    assert.ok(m.includes(k), k);
  // Les rumeurs n'apparaissent que dans l'ancrage du remplacement, jamais dans le texte posé.
  const pose = m.split("$q$v_cible text := ''; v_tito jsonb;")[1] || '';
  assert.ok(!pose.includes('Le Caudillo ne dort jamais'), 'rumeur réintroduite');
  // Plus de prison à l'Hôtel Royal : la détention n'est plus ouverte dans le texte posé.
  const forcer = m.split("'hotel_royal_assignation_v1');")[0].split('$q$,\n$q$').pop();
  assert.ok(!forcer.includes('detention_ouvrir_interne') && forcer.includes('hotel_royal_assigner_interne'));
  // Une organisation secrète n'est jamais citée par le moteur des secrets.
  const moteur = m.slice(m.indexOf('FUNCTION public.hotel_secret_vrai_interne'), m.indexOf('REVOKE ALL ON FUNCTION public.hotel_secret_vrai_interne'));
  assert.ok(moteur.includes('NOT public.organisation_secrete_donnees_interne') && moteur.includes('NOT public.organisation_secrete_interne'));
});

test('navigateur : assignation, Tito et journal dans les neuf langues', () => {
  const ctx = vm.createContext({ window: {}, console, document: undefined });
  vm.runInContext(lire('plateau-hotels-teaser.js'), ctx);
  const T = ctx.window.RP_HOTELS_TEASER_T;
  for (const l of LANGUES) for (const k of ['assigne', 'assigneJournal', 'assigneFin', 'assigneRefus', 'tito', 'titoRien', 'forcerNote']) {
    assert.ok(typeof T[l][k] === 'string' && T[l][k].length > 5, l + ' ' + k);
    if (l !== 'fr' && k !== 'forcerNote') assert.notStrictEqual(T[l][k], T.fr[k], l + ' ' + k + ' non traduit');
  }
  for (const l of LANGUES) assert.ok(!/jour de prison|day in prison|día de cárcel|Tag Gefängnis|день тюрьмы|감옥 1일|يوم في السجن|dia de prisão|入獄一天/.test(T[l].forcerNote), l + ' : la note parle encore de prison');
  assert.ok(T.fr.tito.includes('{cible}') && T.fr.tito.includes('{secret}'));
  const g = ctx.window.rpEvenementsPersonnageGestionnaires;
  assert.strictEqual(typeof g.assignation_hotel_royal, 'function');
  assert.strictEqual(typeof g.assignation_hotel_royal_fin, 'function');
  assert.ok(lire('plateau-navigation.js').includes("'reserve_hommes','reserve_femmes','assignation_residence'"));
});

test('centre multimodal d’Al Madina : Youssef Safar seul, anciens PNJ retirés', () => {
  const ctx = vm.createContext({ console, state: { country: 'khalija', currentCity: 'capitale' }, window: {} });
  vm.runInContext(lire('data.js') + ';this.__W=WORLD;', ctx);
  const c = ctx.__W.khalija.capitale.buildingContext['centre-multinodal-luthecia'];
  const txt = JSON.stringify(c);
  for (const ancien of ['Chambellan Al-Transit', 'Yasmine Embarquement', 'Prosper Tampon']) assert.ok(!txt.includes(ancien), ancien);
  assert.strictEqual(c.roomOverrides.hall_gare.persons[0].name, 'Youssef Safar (PNJ)');
  assert.strictEqual(c.roomOverrides.hall_douanes.personsVides, true);
  assert.strictEqual(c.roomOverrides.zone_embarquement.personsVides, true);
  assert.ok(lire('api/_pnj-personnalites.js').includes("'youssef_safar': { nom: \"Youssef Safar\""));
  assert.ok(!lire('api/_pnj-scenes-generes.js').includes('Yasmine Embarquement'));
});

test('traductions des deux capitales : chaque description, pièce et rôle dans les neuf langues', () => {
  const w = { RP_I18N_GAME_ENABLED: true, RPPlateauI18n: { language: () => 'de' } }; w.window = w;
  const ctx = vm.createContext(w);
  vm.runInContext('let state={country:"narco",currentCity:"capitale"};' + lire('plateau-teaser-traductions.js'), ctx);
  const { PIECES, ROLES, BATIMENTS, DESCRIPTIONS } = w.RPTeaserCapitalesI18n.tables;
  for (const table of [PIECES, ROLES, BATIMENTS]) for (const [fr, t] of Object.entries(table)) for (const l of LANGUES) assert.ok(t[l] && t[l].trim(), fr + ' ' + l);
  for (const d of DESCRIPTIONS) { assert.strictEqual(d.length, 9); assert.ok(d.every(x => typeof x === 'string' && x.trim()), d[0]); }
  // Chaque ordre propre aux deux capitales a sa description traduite, au mot près.
  const dctx = vm.createContext({ console, state: { country: 'narco', currentCity: 'capitale' }, window: {} });
  vm.runInContext(lire('data.js') + ';this.__W=WORLD;', dctx);
  const W = dctx.__W, fr = new Set(DESCRIPTIONS.map(d => d[0])), roles = new Set(Object.keys(ROLES));
  for (const [p, b] of [['narco', 'hotel-republica'], ['khalija', 'hotel-republica'], ['narco', 'centre-multinodal-luthecia'], ['khalija', 'centre-multinodal-luthecia']]) {
    const c = W[p].capitale.buildingContext[b];
    for (const grp of ['roomsExtra', 'roomOverrides']) for (const r of Object.values(c[grp] || {})) {
      for (const o of r.orders || []) if (/^(cr|am)_|^escort_standard$/.test(o.fn)) assert.ok(fr.has(o.desc), o.fn + ' : description non traduite');
      for (const pe of r.persons || []) assert.ok(roles.has(pe.role.replace(/'/g, '’')), pe.role + ' : rôle non traduit');
      if (r.name) assert.ok(PIECES[r.name], r.name + ' : pièce non traduite');
    }
  }
  assert.strictEqual(w.RPRoomI18n.label('hotel-republica', 'bar', 'Bar extérieur'), 'Außenbar');
  assert.strictEqual(w.RPSovarkaRolesI18n.label('Chef de la sécurité (PNJ)'), 'Sicherheitschef (NSC)');
  assert.ok(lire('plateau.html').includes('plateau-teaser-traductions.js'));
});
