// Bloc 4 (Fred, 23/11/2026, GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, points 29 à 34) : lieux de Krasnov.
//  - 29 : musée sans directeur ; le guide Arkadi Pamiatnikov présente les cinq salles et reçoit la solution de l'énigme
//         (jugement serveur inchangé) ; carnet « Soumettez votre solution au guide du musée. » ;
//  - 30 : hôpital : salle d'attente des visiteurs, chambre des hospitalisés (dormir, repas, transfert, sortir) ;
//  - 31 : locaux libres de Sovarka : encadré exact, « Demander ce local à la mairie — 1 PA », ordres d'exploitant masqués ;
//  - 32 : centre d'affaires : quatre bureaux dans sovarka_locaux (40 PSK), plus de location à 500 PSK, fantômes retirés ;
//  - 33 : « Chanter l'hymne au Tracteur » : karaoké en vrai Chromium (tracteur, étoile, cierges, Passer, exclamation) ;
//  - 34 : la station-service de Krasnov ouvre la boutique « Équipements contre les intempéries ».
// R4 : aucun renvoi vers ce qui n'existe plus (directeur, ordre de réponse, « Ce commerce », « Louer ce bureau »).
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const R = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(R, f), 'utf8');
const SQL = lire('migrations/20261123214000_bloc4_lieux_krasnov.sql');

function jeu() {
  const ctx = { console, window: {}, document: { getElementById: () => null, addEventListener() {}, querySelector: () => null }, localStorage: { getItem: () => null } };
  ctx.window = ctx; ctx.globalThis = ctx; vm.createContext(ctx);
  vm.runInContext(lire('data.js') + ';globalThis.__W=WORLD;globalThis.__B=BUILDINGS;globalThis.__o=ordresDeclaresDeLaPiece;', ctx);
  return ctx;
}
const fns = l => Array.from(l, o => o.fn);

test('29 : musée de Krasnov sans directeur ; « Écouter le guide » dans l’accueil et les cinq salles', () => {
  const c = jeu(), k = c.__W.soviet.ville_b.buildingContext['musee-novomirsk'];
  const hall = k.roomOverrides.hall;
  assert.ok(!hall.persons.some(p => /directeur/i.test(p.name + (p.profilId || ''))));
  const ordresHall = c.__o(c.__B['musee-novomirsk'].rooms.hall, k, 'hall');
  assert.deepEqual(fns(ordresHall).sort(), ['acheter_guide_baies_musee', 'ilia_ecouter_guide']);
  assert.match(ordresHall.find(o => o.fn === 'ilia_ecouter_guide').desc, /Arkadi Pamiatnikov/);
  for (const [id, salle] of Object.entries(k.roomsExtra)) {
    assert.deepEqual(fns(salle.orders), ['ilia_ecouter_guide'], id);
    assert.match(salle.orders[0].desc, /Arkadi Pamiatnikov/);
    assert.ok(salle.desc.length > 50, id);
  }
  // Le routeur envoie à Arkadi à Krasnov, à Ilia ailleurs ; l'ancien ordre de réponse est redirigé vers Arkadi.
  const r = lire('plateau-router.js');
  assert.match(r, /fn === 'ilia_ecouter_guide' && state\.country === 'soviet' && state\.currentCity === 'ville_b'\n    && typeof arkadiEcouterGuide === 'function'\) \{ arkadiEcouterGuide\(\); return; \}/);
  assert.ok(r.indexOf('arkadiEcouterGuide(); return;') < r.indexOf("iliaEcouterGuide(false); return;"));
  const e = lire('plateau-enigme-krasnov.js');
  assert.match(e, /function ouvrirReponse\(\) \{\n  if \(typeof global\.arkadiEcouterGuide === 'function'\) global\.arkadiEcouterGuide\(\);/);
  assert.match(e, /const CARNET_ENIGMES = \{ Krasnov: 'Soumettez votre solution au guide du musée\.' \};/);
  assert.doesNotMatch(e, /Directeur du musée de Krasnov/);
  // Fiches DeepSeek : plus de directeur ; l'institutrice parle d'Arkadi.
  const p = lire('api/_pnj-personnalites.js');
  assert.doesNotMatch(p, /'directeur_musee_krasnov':/);
  assert.doesNotMatch(p, /Soumettre la solution de l'énigme au directeur/);
  assert.doesNotMatch(lire('api/_pnj-scenes-generes.js'), /Directeur du musée de Krasnov/);
  // Serveur : réutilise la RPC de l'énigme, retire le tarif de l'ordre supprimé, carnet sur la feuille volante.
  assert.match(SQL, /^-- NON APPLIQUÉE/);
  assert.match(SQL, /DELETE FROM public\.ordres_couts WHERE fn = 'repondre_enigme_krasnov' AND pa = 0 AND cost = 0;/);
  assert.match(SQL, /Soumettez votre solution au guide du musée\.' \/\* carnet_guide_musee_v1 \*\//);
  assert.doesNotMatch(lire('baseline/seeds/95_a-regenerer/ordres_couts.sql'), /repondre_enigme_krasnov/);
});

test('29 : fenêtre d’Arkadi — récit de la salle, réponse à l’énigme envoyée au serveur, une seule fenêtre', () => {
  const vus = [];
  const ctx = { state: { country: 'soviet', currentCity: 'ville_b', currentBuilding: 'musee-novomirsk', currentRoom: 'kolkhozes', inventory: [], enigmesResolues: [] },
    sovModal: (t, h) => vus.push({ t, h }) };
  ctx.window = ctx; vm.createContext(ctx);
  vm.runInContext(lire('plateau-guide-arkadi.js'), ctx);
  assert.deepEqual(Object.keys(ctx.ARKADI_RECITS).sort(), ['ecoute_spatiale', 'exploitation_bois', 'faune_sauvage', 'flore_sauvage', 'hall', 'kolkhozes']);
  ctx.arkadiEcouterGuide();
  assert.equal(vus.length, 1);
  assert.match(vus[0].t, /^Arkadi Pamiatnikov — Guide du musée de Krasnov$/);
  assert.match(vus[0].h, /kolkhoze « Aube de Krasnov »/);
  assert.doesNotMatch(vus[0].h, /soumettreEnigmeKrasnov/, 'sans feuille volante : pas de champ de réponse');
  ctx.state.inventory = [{ type: 'feuille_enigme_krasnov' }];
  ctx.arkadiEcouterGuide();
  assert.match(vus[1].h, /id="enigme-krasnov-reponse"/);
  assert.match(vus[1].h, /onclick="soumettreEnigmeKrasnov\(\)"/);
  ctx.state.enigmesResolues = [{ enigme: 'krasnov' }];
  ctx.arkadiEcouterGuide();
  assert.doesNotMatch(vus[2].h, /enigme-krasnov-reponse/);
  // Hors du musée de Krasnov : rien.
  ctx.state.currentCity = 'capitale'; ctx.arkadiEcouterGuide();
  assert.equal(vus.length, 3);
  // Le jugement reste celui du serveur : krasnov_ecole_agir, action repondre_enigme.
  assert.match(lire('plateau-enigme-krasnov.js'), /const v = await agir\('repondre_enigme', texte\);/);
  assert.match(lire('plateau.html'), /<script src="plateau-guide-arkadi\.js\?v=bloc4-20261123"><\/script>/);
});

test('30 : hôpital de Krasnov — salle d’attente des visiteurs, chambre des hospitalisés', () => {
  const c = jeu(), h = c.__W.soviet.ville_b.buildingContext['dispensaire-public-v'];
  const attente = fns(c.__o(c.__B['dispensaire-public-v'].rooms.attente, h, 'attente')).sort();
  assert.deepEqual(attente, ['centre_anti_poison', 'soin_public', 'vendre_ressource_medicale'].sort());
  assert.doesNotMatch(h.roomOverrides.attente.desc, /bond/i);
  assert.ok(!/Salle bond[ée]e\. Patience requise\./.test(JSON.stringify(h)));
  const chambre = fns(h.roomsExtra.chambre.orders);
  assert.deepEqual(chambre, ['dormir', 'repas_hopital', 'transfert_clinique_privee', 'sortie_hopital']);
  const t = h.roomsExtra.chambre.orders.find(o => o.fn === 'transfert_clinique_privee');
  assert.equal(t.pa, 0);
  // Tarif du pays (table MJ ordres_couts_pays : 400 PSK en Sovarka) affiché sur le bouton et dans le journal.
  assert.match(lire('migrations/20261110003000_sovarka_tarifs_nationaux.sql'), /\('transfert_clinique_privee', 'soviet', 0, 400\)/);
  const perso = lire('plateau-personnage.js');
  assert.match(perso, /const tarif = typeof tarifOrdrePays === 'function' \? tarifOrdrePays\('transfert_clinique_privee', state\.country\) : null;/);
  // Depuis le 24/11/2026 (Fred, point H.1), tous les hôpitaux suivent ce modèle : banc-ghe-h1-hopitaux-20261124.cjs.
  const a = c.__W.soviet.ville_a.buildingContext['dispensaire-public-v'];
  assert.ok(!fns(c.__o(c.__B['dispensaire-public-v'].rooms.attente, a, 'attente')).includes('repas_hopital'));
});

test('31 : locaux libres de Sovarka — encadré exact, demande à 1 PA, ordres d’exploitant masqués, « Ce commerce » supprimé', () => {
  const cat = {}; vm.runInNewContext(lire('i18n/sovarka-droits-resources.js'), cat);
  const freeBox = cat.RPSovarkaDroitsI18n;
  const encadre = "Ce local est libre. En Sovarka, les commerces appartiennent à l'État. Pour exploiter ce local, adressez une demande à la mairie de {ville}. Le maire examine les demandes deux fois par mois. Si la vôtre est acceptée, vous recevrez un courrier et signerez l'attribution chez le notaire.";
  // Texte exact dans le module (repli français ; clé freeBox du catalogue à créer par Codex dans les neuf langues).
  assert.ok(lire('plateau-sovarka-droits.js').includes('const SOV_LOCAL_LIBRE = "' + encadre + '";'));
  assert.equal(freeBox.text('exploitedBy', { nom: 'Ivan' }), 'Ce local est exploité par Ivan.');
  // Source d'ordres : vrai code du module, état serveur simulé.
  const src = lire('plateau-sovarka-droits.js');
  const ctx = { state: { country: 'soviet', currentCity: 'ville_b', currentBuilding: 'centre-commercial', currentRoom: 'vitrine_principale' },
    texteSovDroits: (k, v) => freeBox.text(k, v), VILLES: { soviet: { ville_b: { nom: 'Krasnov' } } }, BUILDINGS: {}, window: null };
  ctx.window = ctx; vm.createContext(ctx);
  vm.runInContext(src + ';globalThis.__fixer=c=>{sovarkaDroitsCache=c;};', Object.assign(ctx, { globalThis: ctx }));
  const local = (x) => ctx.__fixer({ moi: 'Moi', locaux: [Object.assign({ ville: 'ville_b', batiment: 'centre-commercial', piece: 'vitrine_principale', origine: 'centre', loyer: 20 }, x)] });
  local({});
  let o = ctx.ordresLocalSovarka('centre-commercial', 'vitrine_principale', 'ville_b');
  assert.equal(o.length, 1);
  assert.equal(o[0].fn, 'sovarka_demande_location'); assert.equal(o[0].label, 'Demander ce local à la mairie'); assert.equal(o[0].pa, 1);
  assert.deepEqual(Array.from(o[0].masque).sort(), ['commerce_pj', 'gerer_local', 'installer_equipements']);
  assert.deepEqual(Array.from(o[0].masqueTout), ['installer_equipements']);
  assert.equal(ctx.encadreLocalSovarka('centre-commercial', 'vitrine_principale', 'ville_b'),
    '<div class="sov-encadre-local" data-sov-local="libre">' + encadre.replace('{ville}', 'Krasnov') + '</div>');
  local({ exploitant: 'Ivan' });
  o = ctx.ordresLocalSovarka('centre-commercial', 'vitrine_principale', 'ville_b');
  assert.equal(o[0].invisible, true);
  assert.ok(o[0].masque.includes('sovarka_demande_location') && o[0].masque.includes('gerer_local'));
  assert.match(ctx.encadreLocalSovarka('centre-commercial', 'vitrine_principale', 'ville_b'), />Ce local est exploité par Ivan\.</);
  local({ exploitant: 'Moi' });
  o = ctx.ordresLocalSovarka('centre-commercial', 'vitrine_principale', 'ville_b');
  assert.equal(o[0].fn, 'gerer_local'); assert.equal(o[0].enTete, true);
  // Le rendu applique `masqueTout`, remonte l'ordre en tête et affiche les encadrés.
  const pol = lire('plateau-politique.js');
  assert.match(pol, /dynOrders = dynOrders\.filter\(d => !d\.invisible && !dynMasqueTout\.includes\(d\.fn\)\);/);
  assert.match(pol, /allOrders\.sort\(\(x, y\) => \(y\.enTete === true\) - \(x\.enTete === true\)\);/);
  assert.match(pol, /document\.getElementById\('actions-row-bat'\)\.innerHTML = encadres \+ \(/);
  // « Ce commerce » n'existe plus dans les locaux propres à Sovarka ; plus de « Demande de location » comme libellé.
  const data = lire('data.js');
  assert.doesNotMatch(src, /label: 'Ce commerce'/);
  assert.doesNotMatch(data, /label: ?'Demande de location'/);
  assert.match(lire('style.css'), /#actions-row-bat \.sov-encadre-local\{[^}]*\n?[^}]*font-size:1rem\}/);
});

test('32 : centre d’affaires de Krasnov — quatre bureaux demandés à la mairie, 40 PSK, fantômes retirés', () => {
  const c = jeu(), ca = c.__W.soviet.ville_b.buildingContext['centre-affaires'];
  assert.deepEqual(Object.keys(ca.roomsExtra), ['bureau_1', 'bureau_2', 'bureau_3', 'bureau_4']);
  for (const [id, r] of Object.entries(ca.roomsExtra)) {
    assert.ok(!r.orders.some(o => o.fn === 'louer_local' || /500 PSK/.test(o.label)), id);
    const d = r.orders.find(o => o.fn === 'sovarka_demande_location');
    assert.ok(d && /40 PSK par jour au plus/.test(d.desc), id);
  }
  for (const fantome of ['bureau_prestige', 'bureau_standard', 'open_space']) assert.ok(!ca.roomOverrides?.[fantome], fantome);
  assert.ok(c.__W.soviet.ville_a.buildingContext['centre-affaires'].roomOverrides.bureau_prestige, 'Starovka garde ses bureaux');
  assert.match(SQL, /\('soviet', 'ville_b', 'centre-affaires', 'bureau_1', 'Bureau 1 \(côté maison bleue\)', 'centre', 40, 40\)/);
  assert.match(SQL, /\('soviet', 'ville_b', 'centre-affaires', 'bureau_4', 'Bureau 4 \(côté hôpital\)',\s+'centre', 40, 40\)/);
  assert.match(SQL, /AND l\.piece IN \('bureau_prestige', 'bureau_standard', 'open_space'\)\n   AND l\.demande_id IS NULL\n   AND public\.sovarka_exploitant_interne/);
});

test('34 : station-service de Krasnov — boutique « Équipements contre les intempéries »', () => {
  const c = jeu();
  const o = c.__B['station-service-krasnov'].rooms.boutique_station.orders;
  assert.ok(o.some(x => x.fn === 'boutique_climat' && x.label === 'Équipements contre les intempéries'));
  assert.match(SQL, /VALUES \('station-service-krasnov', 'soviet', 'ville_b', 'station-service-krasnov', 'boutique_station', ARRAY\['groupe_electrogene'\]\)/);
});

test('R4 : plus aucun renvoi vers le directeur ni vers les ordres supprimés', () => {
  const fichiers = fs.readdirSync(R).filter(f => /^plateau-.*\.js$/.test(f)).concat(['data.js', 'api/_pnj-personnalites.js', 'api/_pnj-profils.js']);
  for (const f of fichiers) {
    const s = lire(f);
    for (const re of [/'directeur_musee_krasnov'/, /label: ?'Soumettre la solution de l’énigme au directeur'/, /label: ?'Louer ce bureau/,
      /profilId: ?'directeur_musee_krasnov'/]) assert.ok(!re.test(s), f + ' : ' + re);
  }
});

// ----------------------------------------------------------------------------------------------- 33 : vrai Chromium
const { avecJeu, page } = require('./mobile-navigateur.cjs');
async function chant(p, o, langue, ville) {
  await p.addScriptTag({ url: o + '/plateau-hymne-tracteur.js' });
  return p.evaluate(([langue, ville]) => {
    window.state = { country: 'soviet', currentCity: ville, currentBuilding: 'kolkhoze-spirituel' };
    window.langueDuJeu = () => langue;
    document.getElementById('modal-postes')?.classList.add('open');
    window.__fini = false;
    window.jouerHymneTracteur().then(() => { window.__fini = true; });
  }, [langue, ville]);
}
const taillePolice = (p, sel) => p.evaluate(s => Array.from(document.querySelectorAll(s)).map(e => parseFloat(getComputedStyle(e).fontSize)), sel);

for (const [largeur, hauteur] of [[1280, 860], [390, 844]]) {
  test(`33 : ${largeur} px — karaoké : tracteur en bas qui avance, étoile de mot en mot, cierges, Passer, exclamation de Kouzma`, async () => avecJeu(async (b, o) => {
    const p = await page(b, o, largeur, hauteur);
    const base = await p.evaluate(() => parseFloat(getComputedStyle(document.body).fontSize));
    await chant(p, o, 'fr', 'ville_b');
    assert.equal(await p.evaluate(() => document.getElementById('modal-postes')?.classList.contains('open') || false), false, 'une seule fenêtre');
    const paroles = await p.evaluate(() => Array.from(document.querySelectorAll('#hymne-tracteur .ht-paroles > div')).map(d => d.textContent));
    // Un mot par élément : le texte des lignes, espaces retirés, est exactement celui de Fred.
    assert.deepEqual(paroles, ['Ô Tracteur, roue de lumière,', 'Tu laboures nos prières.', 'Gloire au Plan et à ton moteur,', 'Que la moisson remplisse nos cœurs !'].map(l => l.replace(/ /g, '')));
    assert.equal(await p.evaluate(() => document.querySelectorAll('#hymne-tracteur .ht-cierge').length), 2);
    for (const t of [...await taillePolice(p, '#hymne-tracteur .ht-mot'), ...await taillePolice(p, '#hymne-tracteur button')]) assert.ok(t >= base, 'texte ≥ texte courant ' + t + ' / ' + base);
    const bouton = await p.evaluate(() => { const r = document.querySelector('[data-ht-passer]').getBoundingClientRect(); return { h: r.height, txt: document.querySelector('[data-ht-passer]').textContent }; });
    assert.equal(bouton.txt, 'Passer'); assert.ok(bouton.h >= 44);
    const t1 = await p.evaluate(() => { const r = document.querySelector('.ht-tracteur').getBoundingClientRect(); return { x: r.left, b: r.bottom, h: innerHeight }; });
    await p.waitForTimeout(1500);
    const t2 = await p.evaluate(() => { const r = document.querySelector('.ht-tracteur').getBoundingClientRect(); return { x: r.left, b: r.bottom }; });
    assert.ok(t1.b >= t1.h - 40, 'tracteur en bas de l’écran ' + JSON.stringify(t1));
    assert.ok(t2.x > t1.x + 20, 'le tracteur avance ' + JSON.stringify([t1, t2]));
    const etat = await p.evaluate(() => ({ chantes: document.querySelectorAll('.ht-mot.chante').length, total: document.querySelectorAll('.ht-mot').length,
      fumee: document.querySelectorAll('.ht-fumee').length, etoile: getComputedStyle(document.querySelector('.ht-etoile')).transform }));
    assert.ok(etat.chantes > 1 && etat.chantes < etat.total, 'l’étoile avance de mot en mot ' + JSON.stringify(etat));
    assert.ok(etat.fumee >= 1, 'fumée noire en rythme'); assert.notEqual(etat.etoile, 'none');
    // Fin automatique entre 5 et 6 s : exclamation du batiouchka.
    await p.waitForFunction(() => document.querySelector('[data-ht-fermer]'), null, { timeout: 6000 });
    const fin = await p.evaluate(() => document.querySelector('#hymne-tracteur .ht-religieux').textContent);
    assert.match(fin, /Kouzma Lapchine/); assert.match(fin, /PLUS FORT, MON ENFANT ! LE TRACTEUR N’ENTEND PAS !/);
    await p.click('[data-ht-fermer]');
    assert.equal(await p.evaluate(() => [window.__fini, !!document.getElementById('hymne-tracteur')].join()), 'true,false');
  }));
}

test('33 : « Passer » mène directement à l’exclamation du Camarade Pontife Tractorenko (Novomirsk)', async () => avecJeu(async (b, o) => {
  const p = await page(b, o, 1280, 860);
  await chant(p, o, 'fr', 'capitale');
  await p.click('[data-ht-passer]');
  const fin = await p.evaluate(() => document.querySelector('#hymne-tracteur .ht-religieux').textContent);
  assert.match(fin, /Camarade Pontife Tractorenko/);
  assert.match(fin, /Le Tracteur vous a entendus, mes enfants\. Il ronronne de satisfaction\./);
}));

test('33 : en arabe, l’étoile va de droite à gauche', async () => avecJeu(async (b, o) => {
  const p = await page(b, o, 1280, 860);
  await chant(p, o, 'ar', 'ville_b');
  assert.equal(await p.evaluate(() => document.getElementById('hymne-tracteur').dir), 'rtl');
  const x = [];
  for (let i = 0; i < 3; i++) {
    await p.waitForTimeout(260);
    x.push(await p.evaluate(() => new DOMMatrix(getComputedStyle(document.querySelector('.ht-etoile')).transform).m41));
  }
  assert.ok(x[2] < x[0], 'l’étoile se déplace vers la gauche ' + JSON.stringify(x));
}));

test('33 : mouvement réduit — pas de tracteur ni d’étoile, paroles affichées, chant abrégé', async () => avecJeu(async (b, o) => {
  const p = await page(b, o, 390, 844, false, { contexte: { reducedMotion: 'reduce' } });
  await chant(p, o, 'fr', 'ville_b');
  const r = await p.evaluate(() => ({ route: getComputedStyle(document.querySelector('.ht-route')).display,
    tous: Array.from(document.querySelectorAll('.ht-mot')).every(m => m.classList.contains('chante')) }));
  assert.equal(r.route, 'none'); assert.equal(r.tous, true);
  await p.waitForFunction(() => document.querySelector('[data-ht-fermer]'), null, { timeout: 2500 });
}));

test('33 : neuf langues, adaptation rimée de quatre vers ; branchement sur l’ordre « prier » des églises seulement', () => {
  const ctx = { window: null }; ctx.window = ctx; vm.createContext(ctx);
  vm.runInContext(lire('plateau-hymne-tracteur.js'), ctx);
  const P = ctx.HYMNE_TRACTEUR_PAROLES;
  assert.deepEqual(Object.keys(P).sort(), ['ar', 'de', 'en', 'es', 'fr', 'ko', 'pt', 'ru', 'zh']);
  assert.deepEqual(Array.from(P.fr), ['Ô Tracteur, roue de lumière,', 'Tu laboures nos prières.', 'Gloire au Plan et à ton moteur,', 'Que la moisson remplisse nos cœurs !']);
  for (const [l, v] of Object.entries(P)) { assert.equal(v.length, 4, l); for (const x of v) assert.ok(x.trim().length > 5, l); }
  assert.ok(ctx.HYMNE_TRACTEUR_DUREE_MS >= 5000 && ctx.HYMNE_TRACTEUR_DUREE_MS <= 6000);
  const d = lire('plateau-divers.js');
  assert.match(d, /if \(pays === 'soviet' && state\.currentBuilding === 'kolkhoze-spirituel' && typeof jouerHymneTracteur === 'function'\) \{\n      try \{ await jouerHymneTracteur\(\); \}/);
  // Le paiement reste avant le chant ; le résultat (toast) après.
  assert.ok(d.indexOf('const r = await deduireCoutOrdre({ pa, cost });') < d.indexOf('await jouerHymneTracteur()'));
  assert.ok(d.indexOf('await jouerHymneTracteur()') < d.indexOf("showToast('Prière accomplie'"));
  assert.match(lire('plateau.html'), /<script src="plateau-hymne-tracteur\.js\?v=bloc4-20261123"><\/script>\n<script src="plateau-divers\.js/);
});
