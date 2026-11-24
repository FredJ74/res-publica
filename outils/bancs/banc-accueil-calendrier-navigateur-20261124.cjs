// Chromium réel, vrai plateau.html : bienvenue (purge A.2) et portier des fenêtres automatiques (A.3), à 1280 et 390 px.
//  - A.2 : texte exact, icône réelle du bouton d'aide, fermeture par la croix seule (ni Échap, ni clic à côté), jamais
//          recouverte par une autre fenêtre, grande croix sur téléphone, mémorisée au serveur, emplacement de signature vide.
//  - A.3 : arrivée de Bernard — pendant la première heure aucune fenêtre automatique (journal du jour et climat au badge),
//          l'interview due arrive quand même mais attend que la fenêtre ouverte soit fermée ; après la première heure,
//          une seule fenêtre automatique par connexion, les autres au badge, jamais deux superposées.
// Vrais fichiers : plateau-evenements-personnage.js, plateau-accueil-progressif.js (module de #1188 repris), plateau-accueil-interview.js ; serveur simulé.
const test = require('node:test'), assert = require('node:assert/strict');
const { avecJeu, page } = require('./mobile-navigateur.cjs');

function serveurSimule() {
  const S = { bienvenue: true, premiere: true, due: false, etat: 'a_faire', vue: false, evenements: [] };
  window.__S = S; window.__appels = [];
  const chemins = [['politique', 'La politique'], ['affaires', 'Les affaires'], ['influence', "L'intrigue et l'influence"], ['crime', 'Le crime'],
    ['uniforme', "L'uniforme (armée ou police)"], ['belle_vie', 'La belle vie']].map(([id, libelle]) => ({ id, libelle }));
  const vue = () => ({ ok: true, personnage: 'Bernard', pays: 'soviet',
    interview: { etat: S.etat, journaliste: 'Vera Pravdina', journal: 'La Voix de Sovarka', question: 'Que voulez-vous être ?', ouvrir_auto: S.etat === 'a_faire' && !S.vue && S.due },
    calendrier: { actif: true, secondes_jeu: 0, premiere_heure: S.premiere, interview_due: S.due, decouverte_finie: !!S.decouverte, interview_forcee: false },
    bienvenue: { a_voir: S.bienvenue, pays: 'soviet', ville: 'ville_b', signataire: null, portrait: null },
    mot_max: 280, chemins, chemin: null, mot: null, etapes: [], bulle_pa: { vue: true, pa: null, active: true } });
  window.sbRpc = async (fn, a) => {
    window.__appels.push([fn, a]);
    if (fn === 'accueil_etat') return vue();
    if (fn === 'accueil_bienvenue_vue') { S.bienvenue = false; return { ok: true }; }
    if (fn === 'accueil_interview_vue') { S.vue = true; return { ok: true }; }
    if (fn === 'personnage_evenements_lire') { const e = S.evenements; S.evenements = []; return { ok: true, evenements: e }; }
    return null;
  };
  window.rpAuthJeton = () => 'jeton';
  window.addJournalEntry = () => {}; window.showToast = () => {};
  window.__RP_ACCUEIL_SANS_MINUTERIE = true;
  window.state = { char: { name: 'Bernard' }, country: 'soviet', currentCity: 'ville_b', pa: 10 };
}
async function preparer(b, o, l, h) {
  const p = await page(b, o, l, h, false, { texteMinimum: true });
  const erreurs = []; p.on('pageerror', e => erreurs.push(e.message));
  await p.evaluate(serveurSimule);
  // Noms de ville et de pays : les vraies fonctions du jeu (data.js, plateau-core.js), extraites telles quelles.
  { const lireJeu = f => require('node:fs').readFileSync(require('node:path').join(__dirname, '../..', f), 'utf8');
    const bloc = (src, debut, fin) => { const i = src.indexOf(debut); return src.slice(i, src.indexOf(fin, i) + fin.length); };
    const d = lireJeu('data.js'), c = lireJeu('plateau-core.js');
    await p.addScriptTag({ content: 'if (typeof villeNom !== "function") { var VILLES = ' + bloc(d, 'const VILLES = {', '\n};').slice('const VILLES = '.length)
      + '\nwindow.villeNom = ' + bloc(d, 'function villeNom(', '\n}') + '; }\nif (typeof nomPaysAffiche !== "function") window.nomPaysAffiche = '
      + bloc(c, 'function nomPaysAffiche(', '\n}') + ';' }); }
  for (const s of ['plateau-evenements-personnage.js', 'plateau-accueil-progressif.js', 'plateau-accueil-interview.js']) await p.addScriptTag({ url: o + '/' + s });
  await p.waitForFunction(() => window.RPAccueil && window.RPFenetresAuto);
  await p.evaluate(() => window.RPAccueil.verifier());
  return { p, erreurs };
}
const appels = (p, fn) => p.evaluate(f => window.__appels.filter(a => a[0] === f).length, fn);
const TEXTE = ["Bienvenue à Krasnov en Sovarka,",
  "Ça doit faire bizarre d'arriver en terre inconnue, mais sache que tu n'es pas seul : on est là pour t'aider.",
  "Demande aussi aux personnages que tu croiseras : ils seront très probablement en mesure de t'aider, de t'orienter.",
  "Je te laisse découvrir un peu la ville, on reviendra vers toi très rapidement. Et si tu as besoin d'aide, n'oublie pas : on est là."];

for (const [largeur, hauteur] of [[1280, 860], [390, 844]]) {
  test(`${largeur} px : bienvenue — texte exact, icône d'aide, croix seule, jamais recouverte`, async () => avecJeu(async (b, o) => {
    const { p, erreurs } = await preparer(b, o, largeur, hauteur);
    await p.waitForSelector('#hg-bienvenue');
    assert.equal(await p.locator('#hg-bienvenue-titre').innerText(), TEXTE[0]);
    assert.deepEqual(await p.locator('#hg-bienvenue p').allInnerTexts(), TEXTE.slice(1));
    // L'icône du vrai bouton d'aide de la barre du haut, recopiée et inerte.
    assert.equal(await p.locator('#hg-bienvenue .hg-bienvenue-aide .forum-btn i.ti-book').count(), 1);
    assert.equal(await p.locator('#hg-bienvenue .hg-bienvenue-aide [onclick]').count(), 0, 'inerte');
    assert.equal(await p.locator('#hg-bienvenue [data-bienvenue-signature]').count(), 1, 'emplacement de signature prévu');
    assert.equal(await p.locator('#hg-bienvenue [data-bienvenue-signature]').innerText(), '', 'signature vide (PNJ à créer)');
    // Échap et clic à côté : rien.
    await p.keyboard.press('Escape');
    await p.mouse.click(4, hauteur - 4);
    assert.equal(await p.locator('#hg-bienvenue').count(), 1, 'ni Échap ni clic à côté');
    // Une autre fenêtre ajoutée ensuite ne la recouvre pas.
    await p.evaluate(() => { const m = document.getElementById('modal-postes'); m && m.classList.add('open'); });
    await p.waitForTimeout(100);
    assert.equal(await p.evaluate(() => document.body.lastElementChild.id), 'hg-bienvenue');
    const z = await p.evaluate(() => Number(getComputedStyle(document.getElementById('hg-bienvenue')).zIndex));
    assert.ok(z >= 20000);
    await p.evaluate(() => document.getElementById('modal-postes')?.classList.remove('open'));
    // Rien d'autre ne s'ouvre pendant qu'elle est là.
    assert.equal(await p.evaluate(() => window.RPFenetresAuto.fenetreOuverte()), true);
    const croix = await p.evaluate(() => { const r = document.querySelector('.hg-bienvenue-croix').getBoundingClientRect(); return [r.width, r.height]; });
    assert.ok(croix[0] >= (largeur < 600 ? 56 : 44) && croix[1] >= (largeur < 600 ? 56 : 44), 'croix ' + croix);
    const r = await p.evaluate(() => { const e = document.querySelector('#hg-bienvenue .hg-bienvenue-carte').getBoundingClientRect(); return [e.left, e.right, innerWidth, document.documentElement.scrollWidth > document.documentElement.clientWidth + 1]; });
    assert.ok(r[0] >= 0 && r[1] <= r[2] && !r[3], 'dans l’écran ' + r);
    if (process.env.HG_PREUVES) await p.screenshot({ path: process.env.HG_PREUVES + '/bienvenue-' + largeur + '.png' });
    await p.locator('.hg-bienvenue-croix').click();
    assert.equal(await p.locator('#hg-bienvenue').count(), 0);
    await p.waitForFunction(() => window.__appels.some(a => a[0] === 'accueil_bienvenue_vue'));
    await p.evaluate(() => window.RPAccueil.charger().then(() => window.RPAccueil.verifier()));
    assert.equal(await p.locator('#hg-bienvenue').count(), 0, 'ne revient pas');
    assert.deepEqual(erreurs, []);
  }));
}

test('arrivée de Bernard : première heure sans fenêtre automatique, interview due qui attend, puis une seule fenêtre par connexion', async () => avecJeu(async (b, o) => {
  const { p, erreurs } = await preparer(b, o, 390, 844);
  await p.locator('.hg-bienvenue-croix').click();
  // Première heure : journal du jour et climat partent au badge, rien ne s'ouvre.
  await p.evaluate(() => {
    window.__ouvertes = [];
    window.RPFenetresAuto.demander('journal_du_jour', () => window.__ouvertes.push('journal'));
    window.RPFenetresAuto.demander('climat', () => window.__ouvertes.push('climat'));
  });
  assert.deepEqual(await p.evaluate(() => window.__ouvertes), []);
  assert.deepEqual(await p.evaluate(() => window.RPFenetresAuto.files()), { journal: ['journal_du_jour'], meteo: ['climat'] });
  assert.equal(await p.locator('#hg-fenetres-badges [data-badge="journal"] i.ti-news').count(), 1);
  assert.equal(await p.locator('#hg-fenetres-badges [data-badge="meteo"] i.ti-cloud-storm').count(), 1);
  // Interview due (serveur) pendant qu'une fenêtre est ouverte : elle attend, sans la recouvrir.
  await p.evaluate(() => { document.getElementById('modal-postes').classList.add('open'); window.__S.due = true;
    window.__S.evenements = [{ id: 1, cle: 'accueil_interview', texte: '', params: {} }]; return window.lireEvenementsPersonnage(); });
  await p.waitForTimeout(400);
  assert.equal(await p.locator('#hg-accueil-interview').count(), 0, 'attend la fermeture de la fenêtre ouverte');
  await p.evaluate(() => document.getElementById('modal-postes').classList.remove('open'));
  // Juste après la bienvenue : délai de respiration (jamais deux fenêtres automatiques à la suite).
  await p.evaluate(() => window.RPAccueil.verifier());
  await p.waitForTimeout(200);
  assert.equal(await p.locator('#hg-accueil-interview').count(), 0, 'pas collée à la bienvenue');
  await p.evaluate(() => { const d0 = Date.now; Date.now = () => d0.call(Date) + 180000; });   // trois minutes plus tard
  await p.evaluate(() => window.RPAccueil.verifier());
  await p.waitForSelector('#hg-accueil-interview');
  assert.equal(await appels(p, 'accueil_interview_vue'), 1);
  await p.evaluate(() => document.querySelector('[data-acc="fermer"]').click());
  await p.waitForSelector('#hg-accueil-interview', { state: 'detached' });
  // Quête d'accueil de Luthécia (#1188) : découverte finie au serveur, mais pas juste après l'interview.
  await p.evaluate(() => { window.__S.decouverte = true; return window.RPAccueil.charger().then(e => window.RPAccueilProgressif.initialiser(e)); });
  assert.equal(await p.evaluate(() => window.RPAccueilProgressif.queteInitialeAutorisee()), false, 'respiration après l’interview');
  await p.evaluate(() => { const d1 = Date.now; Date.now = () => d1.call(Date) + 180000; });
  assert.equal(await p.evaluate(() => window.RPAccueilProgressif.queteInitialeAutorisee()), true);
  // Le joueur ouvre lui-même le badge : une fenêtre à la fois.
  await p.locator('#hg-fenetres-badges [data-badge="journal"]').click();
  assert.deepEqual(await p.evaluate(() => window.__ouvertes), ['journal']);
  // Après la première heure (le serveur le dit) : une seule fenêtre automatique pour cette connexion.
  await p.evaluate(() => { window.__S.premiere = false; return window.RPAccueil.charger(); });
  const avant = await p.evaluate(() => window.RPFenetresAuto.montrees());
  await p.evaluate(() => window.RPFenetresAuto.demander('climat_accueil', () => window.__ouvertes.push('climat_accueil')));
  assert.deepEqual(await p.evaluate(() => window.__ouvertes), ['journal'], 'l’interview a déjà été la fenêtre automatique de cette connexion');
  assert.ok(avant >= 1);
  assert.deepEqual(erreurs, []);
}));

test('ancien joueur après la première heure : la première fenêtre s’ouvre, la seconde va au badge, jamais deux à la fois', async () => avecJeu(async (b, o) => {
  const { p, erreurs } = await preparer(b, o, 1280, 860);
  await p.locator('.hg-bienvenue-croix').click();
  await p.evaluate(() => { window.__S.premiere = false; return window.RPAccueil.charger(); });
  await p.evaluate(() => {
    window.__ouvertes = [];
    document.getElementById('modal-postes').classList.add('open');
    window.RPFenetresAuto.demander('journal_du_jour', () => { window.__ouvertes.push('journal'); });
  });
  await p.waitForTimeout(300);
  assert.deepEqual(await p.evaluate(() => window.__ouvertes), [], 'attend : jamais par-dessus');
  await p.evaluate(() => document.getElementById('modal-postes').classList.remove('open'));
  await p.waitForFunction(() => window.__ouvertes.length === 1, null, { timeout: 4000 });
  await p.evaluate(() => window.RPFenetresAuto.demander('climat', () => window.__ouvertes.push('climat')));
  assert.deepEqual(await p.evaluate(() => window.__ouvertes), ['journal']);
  assert.deepEqual(await p.evaluate(() => window.RPFenetresAuto.files().meteo), ['climat']);
  assert.deepEqual(erreurs, []);
}));
