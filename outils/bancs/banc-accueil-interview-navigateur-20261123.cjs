// Chromium réel, vrai plateau.html (HTML et feuilles de style, mobiles comprises) : accueil des nouveaux joueurs (Fred,
// 22/11/2026, GAME-DESIGN-INTERFACE-ACCUEIL-20261122.md, points 23 à 26), à 1280 et à 390 px.
//  - 23 : à la connexion, l'interview s'ouvre d'elle-même (une fois) : journaliste, question, six chemins, mot libre.
//  - 25 : fermée sans réponse, la fenêtre se réduit et file vers « Mes objectifs » (bouton du panneau à 1280, accès
//         « Personnage » à 390) ; l'interview reste dans Mes objectifs, en tête : « Reprendre » la rouvre.
//  - 24 : la réponse dépose le parcours de trois étapes (lieu, coche « J'ai fait cette étape » enregistrée au serveur).
//  - 26 : bulle HRP à côté de la jauge des PA (allumée) au premier ordre payant, texte exact, jamais sous le texte courant.
// Vrais fichiers : plateau-texte-minimum.js, plateau-evenements-personnage.js, plateau-accueil-interview.js et la vraie
// fonction afficherObjectifsSecrets (extraite de plateau-politique.js) ; seuls le serveur (sbRpc, /api/journal-interview)
// et l'environnement de la fonction (objectifs d'archétype) sont simulés.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const { avecJeu, page, R } = require('./mobile-navigateur.cjs');
const PLANCHER = 15.2;   // 0,95 rem
const BULLE = 'Vous venez de dépenser 2 PA. Les PA sont votre énergie du jour : chaque action en coûte. Dormir les recharge. À 0, c\'est l\'hôpital.';

function extraire(fichier, debut) {
  const s = fs.readFileSync(path.join(R, fichier), 'utf8');
  const i = s.indexOf(debut);
  if (i < 0) throw new Error(debut + ' introuvable');
  let j = s.indexOf('{', i), prof = 0;
  for (; j < s.length; j++) { if (s[j] === '{') prof++; else if (s[j] === '}' && --prof === 0) break; }
  return s.slice(i, j + 1);
}
const OBJECTIFS = extraire('plateau-politique.js', 'async function afficherObjectifsSecrets()');

// Serveur simulé : même machine d'états que la migration 20261123140000 (le banc PGlite éprouve la vraie).
function serveurSimule() {
  const etapes = { crime: [
    { n: 1, texte: 'Faites un tour au marché noir (ordre « Marché Noir »).', lieu: 'Luthécia, Armurerie Martinon, Magasin', validation: 'ordre', pnj: null },
    { n: 2, texte: 'Faites falsifier un document (ordre « Falsifier un document »).', lieu: 'Luthécia, Tribunal, Greffe', validation: 'ordre', pnj: null },
    { n: 3, texte: 'Allez voir Pat Hounette, référent du milieu : dites-lui que vous cherchez du travail.', lieu: 'Luthécia, Place du Formulaire de la Liberté', validation: 'manuelle', pnj: 'Pat Hounette' }] };
  const S = { etat: 'a_faire', vue: false, chemin: null, mot: null, faites: {}, bulle: false, evenements: [] };
  window.__S = S; window.__appels = [];
  const chemins = [['politique', 'La politique'], ['affaires', 'Les affaires'], ['influence', "L'intrigue et l'influence"], ['crime', 'Le crime'],
    ['uniforme', "L'uniforme (armée ou police)"], ['belle_vie', 'La belle vie']].map(([id, libelle]) => ({ id, libelle }));
  const vue = () => ({ ok: true, personnage: 'Tom', pays: 'republic',
    interview: { etat: S.etat, journaliste: 'Jodie Moitout', journal: "L'Autruche Entravée", question: 'Alors, dites-moi : quel chemin comptez-vous prendre ici ?',
      ouvrir_auto: S.etat === 'a_faire' && !S.vue }, mot_max: 280, chemins,
    chemin: S.chemin ? chemins.find(c => c.id === S.chemin) : null, mot: S.mot,
    etapes: S.chemin ? etapes[S.chemin].map(e => ({ ...e, faite: !!S.faites[e.n] })) : [],
    bulle_pa: { vue: S.bulle, pa: null, active: true } });
  window.sbRpc = async (fn, a) => {
    window.__appels.push([fn, a]);
    if (fn === 'accueil_etat') return vue();
    if (fn === 'accueil_interview_vue') { S.vue = true; return { ok: true }; }
    if (fn === 'accueil_choisir_chemin') { S.chemin = a.p_chemin; S.mot = a.p_mot; S.etat = 'article_a_publier'; S.vue = true; return vue(); }
    if (fn === 'accueil_ignorer') { S.etat = 'ignoree'; return vue(); }
    if (fn === 'accueil_etape_valider') { S.faites[a.p_n] = true; return vue(); }
    if (fn === 'accueil_bulle_pa_signaler') { const m = !S.bulle; S.bulle = true; return { ok: true, montrer: m, pa: a.p_pa }; }
    if (fn === 'personnage_evenements_lire') { const e = S.evenements; S.evenements = []; return { ok: true, evenements: e }; }
    return null;
  };
  const vraiFetch = window.fetch;
  window.fetch = async (url, o) => {
    if (String(url).includes('/api/journal-interview')) {
      window.__appels.push(['api', JSON.parse(o.body)]);
      S.etat = 'faite';
      return { ok: true, json: async () => ({ ok: true, statut: 'publiee', titre: 'Un nouveau visage à Luthécia', texte: 'Tom connaît du monde, et il compte bien le faire savoir.' }) };
    }
    return vraiFetch(url, o);
  };
  window.rpAuthJeton = () => 'jeton';
  window.__journal = [];
  window.addJournalEntry = t => window.__journal.push(t);
  window.showToast = () => {};
  window.__RP_ACCUEIL_SANS_MINUTERIE = true;
  window.state = { char: { name: 'Tom', archetype: 'ambitieux' }, country: 'republic', currentCity: 'capitale', pa: 10 };
  // Environnement de afficherObjectifsSecrets (objectifs d'archétype) : doublures minimales.
  window.queteAccueilObjectifActuel = () => null; window.queteCarriereObjectifActuel = () => null;
  window.contexteGroupePj = () => ({}); window.contexteGroupePjValide = () => true; window.verifierObjectifs = async () => {};
  window.OBJECTIFS_SECRETS = { ambitieux: { label: "L'Ambitieux", objectifs: [{ id: 'o1', desc: 'Atteindre 50 de Popularité', points: 10 }] } };
  document.getElementById('r-pa').textContent = '10';
}

async function preparer(b, o, largeur, hauteur) {
  const p = await page(b, o, largeur, hauteur, false, { texteMinimum: true });
  const erreurs = []; p.on('pageerror', e => erreurs.push(e.message));
  await p.evaluate(serveurSimule);
  await p.addScriptTag({ content: OBJECTIFS + '\nwindow.afficherObjectifsSecrets = afficherObjectifsSecrets;' });
  for (const s of ['plateau-evenements-personnage.js', 'plateau-accueil-interview.js']) await p.addScriptTag({ url: o + '/' + s });
  await p.waitForFunction(() => window.RPAccueil);
  return { p, erreurs };
}
const tailles = (p, sel) => p.evaluate(s => {
  const out = [];
  for (const e of document.querySelectorAll(s + ', ' + s + ' *')) {
    if (!e.getClientRects().length) continue;
    const texte = [...e.childNodes].some(n => n.nodeType === 3 && n.nodeValue.trim()) || ['TEXTAREA', 'BUTTON'].includes(e.tagName);
    if (texte) out.push([e.tagName + '.' + e.className, parseFloat(getComputedStyle(e).fontSize)]);
  }
  return out;
}, sel);
async function lisible(p, sel) {
  const t = await tailles(p, sel);
  assert.ok(t.length > 0, sel + ' : du texte');
  const petits = t.filter(x => x[1] < PLANCHER - 0.01);
  assert.deepEqual(petits, [], sel + ' : aucun texte sous le texte courant');
}
async function dansEcran(p, sel) {
  const r = await p.evaluate(s => { const e = document.querySelector(s).getBoundingClientRect(); return { l: e.left, r: e.right, t: e.top, b: e.bottom, w: innerWidth, h: innerHeight,
    deborde: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1 }; }, sel);
  assert.ok(r.l >= -0.5 && r.r <= r.w + 0.5 && r.t >= -0.5 && r.b <= r.h + 0.5, sel + ' dans l’écran ' + JSON.stringify(r));
  assert.equal(r.deborde, false, 'aucun défilement horizontal');
}
const appels = (p, fn) => p.evaluate(f => window.__appels.filter(a => a[0] === f), fn);

for (const [largeur, hauteur] of [[1280, 860], [390, 844]]) {
  test(`${largeur} px : ouverture automatique, fermeture qui file vers Mes objectifs, reprise, réponse et parcours`, async () => avecJeu(async (b, o) => {
    const { p, erreurs } = await preparer(b, o, largeur, hauteur);
    await p.evaluate(() => window.RPAccueil.verifier());
    await p.waitForSelector('#hg-accueil-interview .hg-acc-chemin');
    assert.equal(await p.locator('#hg-acc-titre').innerText(), 'Jodie Moitout');
    assert.match(await p.locator('.hg-acc-question').innerText(), /quel chemin comptez-vous prendre ici/);
    assert.deepEqual(await p.locator('.hg-acc-chemin').allInnerTexts(),
      ['La politique', 'Les affaires', "L'intrigue et l'influence", 'Le crime', "L'uniforme (armée ou police)", 'La belle vie']);
    assert.equal(await p.locator('#hg-acc-mot').count(), 1, 'mot libre');
    assert.equal((await appels(p, 'accueil_interview_vue')).length, 1, 'ouverture automatique notée au serveur');
    await lisible(p, '#hg-accueil-interview');
    await dansEcran(p, '#hg-accueil-interview .hg-acc-carte');
    if (process.env.HG_PREUVES) await p.screenshot({ path: process.env.HG_PREUVES + '/accueil-interview-' + largeur + '.png' });
    // Seconde vérification : pas de seconde ouverture.
    await p.evaluate(() => document.querySelector('[data-acc="fermer"]').click());
    const vers = await p.evaluate(() => { const f = document.getElementById('hg-accueil-interview'); const c = f?.querySelector('.hg-acc-carte');
      return f ? { vers: f.dataset.fileVers, transform: c.style.transform, file: c.classList.contains('hg-acc-file') } : null; });
    assert.ok(vers && vers.file, 'animation lancée');
    assert.match(vers.transform, /translate\(.*\) scale\(0\.06\)/, 'se réduit en filant');
    assert.equal(vers.vers, largeur < 1024 ? 'personnage' : 'objectifs');
    await p.waitForSelector('#hg-accueil-interview', { state: 'detached' });
    assert.equal(await p.locator(largeur < 1024 ? '#hg-mobile-brand.hg-acc-cible, #hg-mobile-identite-20261117.hg-acc-cible' : '#left button.hg-acc-cible').count(), 1, 'la cible reçoit la fenêtre');
    await p.evaluate(() => window.RPAccueil.verifier());
    await p.waitForTimeout(200);
    assert.equal(await p.locator('#hg-accueil-interview').count(), 0, 'pas de seconde ouverture automatique');
    // Mes objectifs : l'interview en première étape, à reprendre ou ignorer.
    await p.evaluate(() => window.afficherObjectifsSecrets());
    await p.waitForSelector('#postes-body [data-accueil-objectifs]');
    const premier = await p.evaluate(() => document.querySelector('#postes-body .hg-acc-obj-texte').firstChild.nodeValue);
    assert.equal(premier, 'Jodie Moitout vous attend pour une interview');
    assert.ok(await p.evaluate(() => document.querySelector('#postes-body').textContent.includes('Atteindre 50 de Popularité')), 'objectifs d’archétype toujours là, après');
    await lisible(p, '#postes-body [data-accueil-objectifs]');
    await p.locator('[data-acc-obj="reprendre"]').click();
    await p.waitForSelector('#hg-accueil-interview .hg-acc-chemin');
    assert.equal(await p.locator('[data-acc="repondre"]').isDisabled(), true, 'Répondre attend un chemin');
    await p.locator('.hg-acc-chemin', { hasText: 'Le crime' }).click();
    await p.fill('#hg-acc-mot', 'Je connais du monde.');
    await p.locator('[data-acc="repondre"]').click();
    await p.waitForSelector('.hg-acc-article h3');
    assert.deepEqual((await appels(p, 'accueil_choisir_chemin'))[0][1], { p_chemin: 'crime', p_mot: 'Je connais du monde.' });
    assert.deepEqual((await appels(p, 'api'))[0][1], { action: 'accueil_publier', personnage: 'Tom' }, 'le serveur relit chemin et mot');
    assert.equal(await p.locator('.hg-acc-article h3').innerText(), 'Un nouveau visage à Luthécia');
    assert.match(await p.locator('#hg-accueil-interview').innerText(), /Votre parcours « Le crime » vous attend dans Mes objectifs/);
    await lisible(p, '#hg-accueil-interview');
    await dansEcran(p, '#hg-accueil-interview .hg-acc-carte');
    await p.locator('#hg-accueil-interview .hg-acc-btn', { hasText: 'Fermer' }).click();
    await p.waitForSelector('#hg-accueil-interview', { state: 'detached' });
    await p.evaluate(() => window.afficherObjectifsSecrets());
    await p.waitForSelector('#postes-body [data-etape="3"]');
    const texte = await p.locator('#postes-body [data-accueil-objectifs]').innerText();
    assert.match(texte, /Votre parcours : Le crime/i);
    assert.match(texte, /1\. Faites un tour au marché noir/);
    assert.match(texte, /Où : Luthécia, Armurerie Martinon, Magasin/);
    assert.match(texte, /3\. Allez voir Pat Hounette/);
    assert.doesNotMatch(texte, /vous attend pour une interview/, 'interview faite : plus dans la liste');
    await p.locator('[data-etape="3"] [data-acc-obj="etape"]').click();
    await p.waitForFunction(() => document.querySelector('#postes-body [data-etape="3"] .hg-acc-coche')?.textContent === '✅');
    assert.deepEqual((await appels(p, 'accueil_etape_valider'))[0][1], { p_n: 3 });
    await lisible(p, '#postes-body [data-accueil-objectifs]');
    if (process.env.HG_PREUVES) await p.screenshot({ path: process.env.HG_PREUVES + '/accueil-objectifs-' + largeur + '.png' });
    assert.deepEqual(erreurs, []);
  }));

  test(`${largeur} px : bulle des PA à côté de la jauge allumée, une seule fois (serveur), texte lisible`, async () => avecJeu(async (b, o) => {
    const { p, erreurs } = await preparer(b, o, largeur, hauteur);
    await p.evaluate(() => { window.__S.etat = 'faite'; window.doOrder = () => {}; });
    await p.evaluate(() => window.RPAccueil.verifier());
    // Un ordre payé (commande serveur propre) : les PA affichés baissent de 2 → le navigateur signale, le serveur décide.
    await p.evaluate(() => { window.doOrder('marche_noir'); document.getElementById('r-pa').textContent = '8'; });
    await p.waitForSelector('#hg-bulle-pa', { timeout: 4000 });
    assert.deepEqual((await appels(p, 'accueil_bulle_pa_signaler'))[0][1], { p_pa: 2 });
    assert.equal(await p.locator('#hg-bulle-pa p').innerText(), BULLE);
    assert.equal(await p.locator('#hg-bulle-pa .hg-bulle-hrp').innerText(), 'Hors jeu');
    assert.equal(await p.locator('.hg-pa-allumee').count(), 1, 'jauge des PA allumée');
    await lisible(p, '#hg-bulle-pa');
    await dansEcran(p, '#hg-bulle-pa');
    // À côté de la jauge : la bulle la touche presque (à droite ou dessous).
    const proche = await p.evaluate(() => { const j = document.querySelector('.hg-pa-allumee').getBoundingClientRect(), bl = document.getElementById('hg-bulle-pa').getBoundingClientRect();
      return Math.min(Math.abs(bl.left - j.right), Math.abs(bl.top - j.bottom), Math.abs(bl.bottom - j.top)); });
    assert.ok(proche <= 16, 'bulle à côté de la jauge (' + proche + ' px)');
    if (process.env.HG_PREUVES) await p.screenshot({ path: process.env.HG_PREUVES + '/accueil-bulle-pa-' + largeur + '.png' });
    await p.locator('#hg-bulle-pa button').click();
    assert.equal(await p.locator('#hg-bulle-pa').count(), 0);
    assert.equal(await p.locator('.hg-pa-allumee').count(), 0);
    // Second ordre payant : rien (vue au serveur).
    await p.evaluate(() => { window.doOrder('marche_noir'); document.getElementById('r-pa').textContent = '7'; });
    await p.waitForTimeout(1900);
    assert.equal(await p.locator('#hg-bulle-pa').count(), 0, 'une seule fois');
    // Voie du paiement commun : le serveur écrit l'événement accueil_bulle_pa, le journal d'événements le livre.
    await p.evaluate(() => { document.getElementById('hg-bulle-pa')?.remove(); window.__S.evenements = [{ id: 1, cle: 'accueil_bulle_pa', texte: '', params: { pa: 2 } }]; return window.lireEvenementsPersonnage(); });
    await p.waitForSelector('#hg-bulle-pa');
    assert.equal(await p.locator('#hg-bulle-pa p').innerText(), BULLE);
    assert.deepEqual(await p.evaluate(() => window.__journal), [], 'rien au journal pour la bulle');
    assert.deepEqual(erreurs, []);
  }));
}
