// Recette web mobile isolée. Aucun compte réel, aucune transaction de jeu.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const zlib = require('node:zlib');
const acorn = require('../vercel/node_modules/acorn');
const { R, avecJeu, page } = require('./mobile-navigateur.cjs');
const archive = fs.readFileSync(path.join(__dirname, 'fixtures/mobile-certification-temoin-520630bd.json.gz'));
assert.equal(crypto.createHash('sha256').update(archive).digest('hex'), '6e0a56feaba4d50f731551e2440f9f2962b50559ec6eabdb63960e3c70289f9c');
const temoin = JSON.parse(zlib.gunzipSync(archive));
assert.equal(temoin.commit, '520630bd');
const profils = [
  { nom: 'iPhone simulé', w: 390, h: 844, contexte: { isMobile: true, hasTouch: true, deviceScaleFactor: 3 } },
  { nom: 'Android simulé', w: 360, h: 800, contexte: { isMobile: true, hasTouch: true, deviceScaleFactor: 2 } }
];
async function telephone(b, o, profil, ancien = false) {
  return page(b, o, profil.w, profil.h, false, {
    contexte: profil.contexte,
    mobileSource: ancien ? temoin.fichiers['plateau-mobile.js'] : undefined
  });
}
async function preparerReprise(p) {
  await p.evaluate(() => {
    window.ordres = 0;
    window.lectures = 0;
    window.loadCharacter = async () => { lectures++; return new Promise(r => window.finLecture = r); };
    const bouton = document.createElement('button');
    bouton.id = 'ordre-certification'; bouton.textContent = 'Ordre fixture';
    bouton.onclick = () => ordres++;
    bouton.style.cssText = 'position:fixed;top:120px;left:20px;z-index:40';
    document.body.append(bouton);
    window.dispatchEvent(new StorageEvent('storage', { key: 'respublica_char_Fixture' }));
    bouton.click();
  });
  await p.waitForFunction(() => lectures === 1);
}
async function invalider(p, cause) {
  await p.evaluate(c => {
    if (c === 'masquage') {
      Object.defineProperty(document, 'hidden', { configurable: true, value: true });
      document.dispatchEvent(new Event('visibilitychange'));
    } else {
      window.dispatchEvent(new StorageEvent('storage', { key: 'respublica_char_Fixture' }));
    }
    finLecture(true);
  }, cause);
  await p.waitForTimeout(50);
}
for (const profil of profils) {
  for (const cause of ['masquage', 'autre onglet']) {
    test(`${profil.nom} : une invalidation pendant la lecture garde le prochain ordre bloqué (${cause})`, () => avecJeu(async (b, o) => {
      const p = await telephone(b, o, profil);
      await preparerReprise(p);
      await invalider(p, cause);
      assert.equal(await p.locator('#hg-reprise').isVisible(), true);
      if (cause === 'masquage') await p.evaluate(() => {
        Object.defineProperty(document, 'hidden', { configurable: true, value: false });
        document.dispatchEvent(new Event('visibilitychange'));
      });
      else await p.locator('#ordre-certification').click();
      await p.waitForFunction(() => lectures === 2);
      assert.equal(await p.evaluate(() => ordres), 0);
      await p.evaluate(() => finLecture(true));
      await p.waitForFunction(() => document.getElementById('hg-reprise').hidden);
      assert.equal(await p.evaluate(() => ordres), 0, 'aucun rejeu du premier clic');
      await p.locator('#ordre-certification').click();
      assert.equal(await p.evaluate(() => ordres), 1);
    }));
  }
}
for (const cause of ['masquage', 'autre onglet']) test(`Contre-épreuve : le contrôleur main perdait l’invalidation (${cause})`, () => avecJeu(async (b, o) => {
  const p = await telephone(b, o, profils[0], true);
  await preparerReprise(p);
  await invalider(p, cause);
  assert.equal(await p.locator('#hg-reprise').isVisible(), false, 'défaut historique reproduit');
  if (cause === 'masquage') await p.evaluate(() => {
    Object.defineProperty(document, 'hidden', { configurable: true, value: false });
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await p.locator('#ordre-certification').click();
  assert.equal(await p.evaluate(() => lectures), 1, 'aucune seconde lecture dans l’ancien code');
  assert.equal(await p.evaluate(() => ordres), 1, 'ancien ordre exécuté prématurément');
}));

// Le vrai lecteur de presse et les vrais boutons de fermeture, pas une imitation du journal.
const presse = fs.readFileSync(path.join(R, 'plateau-politique.js'), 'utf8');
const ast = acorn.parse(presse, { ecmaVersion: 'latest' });
const debut = ast.body.find(n => n.type === 'FunctionDeclaration' && n.id.name === 'formaterDateEditionFr').start;
const fin = ast.body.find(n => n.type === 'FunctionDeclaration' && n.id.name === 'afficherJournalDuJour').end;
const lecteur = presse.slice(debut, fin);
for (const profil of profils) test(`${profil.nom} : fermer le journal d’accueil conserve personnage, position, URL et cache`, () => avecJeu(async (b, o) => {
  const p = await telephone(b, o, profil);
  await p.evaluate(() => {
    window.state = { char: { name: 'Fixture mobile' }, country: 'republic', currentCity: 'capitale', currentBuilding: 'hotel-de-ville', currentRoom: 'accueil' };
    window.COUNTRIES = { republic: { n: 'Républia' } };
    window.MOIS_FR_JOURNAL = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];
    window.escapeHtmlText = s => String(s || '').replace(/[&<>"']/g, c => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' }[c]));
    window.addJournalEntry = () => {};
    window.sbLirePresseEdition = async () => ({ journal: { nom: 'Journal fixture', pays: 'republic' }, date_edition: '2026-11-08', une: { sujets: [{ titre: 'Une fixture' }] } });
    localStorage.setItem('respublica_char', JSON.stringify(state.char));
    window.etatAvant = JSON.stringify(state);
    window.cacheAvant = localStorage.getItem('respublica_char');
    window.fetch = () => { throw Error('Réseau interdit dans cette recette'); };
  });
  await p.addScriptTag({ content: lecteur });
  const url = p.url();
  for (const nombre of [0, 1, 2]) {
    await p.evaluate(n => { window.sbGetKiosqueDuJour = async () => Array.from({ length: n }, (_, i) => ({ id: 'fixture-' + i, date_edition: '2026-11-08', journaux: { nom: 'Journal fixture', pays: 'republic' } })); return afficherJournalDuJour(true); }, nombre);
    const fermer = p.locator(nombre === 1 ? '#modal-postes .tribune-fronton-close' : '#modal-postes .modal-close');
    await fermer.tap();
    await p.waitForFunction(() => !document.getElementById('modal-postes').classList.contains('open'));
    assert.equal(p.url(), url, 'pas de retour vers accueil/création');
    assert.equal(await p.evaluate(() => JSON.stringify(state)), await p.evaluate(() => etatAvant));
    assert.equal(await p.evaluate(() => localStorage.getItem('respublica_char')), await p.evaluate(() => cacheAvant));
  }
  // Le journal d’événements porte un autre bouton ; il doit aussi rester dans le plateau.
  const html = fs.readFileSync(path.join(R, 'plateau.html'), 'utf8');
  const script = [...html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)].map(m => m[1]).find(s => s.includes('async function toggleJournalStore()'));
  assert.ok(script);
  await p.addScriptTag({ content: script });
  await p.locator('#journal-open-btn').tap();
  await p.locator('#journal-store button').first().tap();
  assert.equal(p.url(), url);
  assert.equal(await p.evaluate(() => JSON.stringify(state)), await p.evaluate(() => etatAvant));
}));

test('Bureau 1440 : rendu strictement identique au main de certification', () => avecJeu(async (b, o) => {
  const avant = await page(b, o, 1440, 900, false, { mobileSource: temoin.fichiers['plateau-mobile.js'] });
  await avant.locator('link[rel=stylesheet]').evaluateAll(es => es.forEach(e => e.remove()));
  for (const fichier of ['style.css', 'rue-centrale.css']) await avant.addStyleTag({ content: temoin.fichiers[fichier] });
  const apres = await page(b, o, 1440, 900);
  await avant.waitForTimeout(300);
  assert.ok((await avant.screenshot({ animations: 'disabled', caret: 'hide' })).equals(await apres.screenshot({ animations: 'disabled', caret: 'hide' })));
  await formulaireReconnexion(avant, false);
  await formulaireReconnexion(apres, false);
  assert.ok((await avant.screenshot({ animations: 'disabled', caret: 'hide' })).equals(await apres.screenshot({ animations: 'disabled', caret: 'hide' })), 'reconnexion bureau inchangée');
}));

const core = fs.readFileSync(path.join(R, 'plateau-core.js'), 'utf8');
const reconnexion = acorn.parse(core, { ecmaVersion: 'latest' }).body.find(n => n.type === 'FunctionDeclaration' && n.id.name === 'afficherBandeauReconnexion');
async function formulaireReconnexion(p, tactile = true) {
  await p.evaluate(() => {
    window.state = { char: { name: 'Fixture mobile' } };
    window.rpAuthIdentiteMemorisee = () => ({ email: 'fixture@example.invalid' });
  });
  await p.addScriptTag({ content: core.slice(reconnexion.start, reconnexion.end) });
  await p.evaluate(() => afficherBandeauReconnexion());
  const ouvrir = p.locator('#bandeau-reconnexion button').first();
  if (tactile) await ouvrir.tap(); else await ouvrir.click();
}
for (const profil of profils) test(`${profil.nom} : reconnexion défilante avec clavier simulé, champs lisibles`, () => avecJeu(async (b, o) => {
  const p = await telephone(b, o, profil);
  await formulaireReconnexion(p);
  await p.setViewportSize({ width: profil.w, height: 350 });
  const valider = p.locator('#bandeau-reconnexion button[type=submit]');
  await valider.scrollIntoViewIfNeeded();
  assert.ok(await valider.evaluate(e => { const r = e.getBoundingClientRect(); return r.top >= 0 && r.bottom <= innerHeight; }), 'bouton de reconnexion accessible');
  assert.ok(await p.locator('#bandeau-reconnexion input').first().evaluate(e => parseFloat(getComputedStyle(e).fontSize) >= 16), 'pas de zoom automatique nécessaire à la saisie');
  assert.ok(await valider.evaluate(e => e.getBoundingClientRect().height >= 44));
}));
test('Contre-épreuve : bouton de reconnexion hors écran avec le CSS main et clavier simulé', () => avecJeu(async (b, o) => {
  const p = await telephone(b, o, profils[0], true);
  await p.locator('link[rel=stylesheet]').evaluateAll(es => es.forEach(e => e.remove()));
  for (const fichier of ['style.css', 'rue-centrale.css']) await p.addStyleTag({ content: temoin.fichiers[fichier] });
  await formulaireReconnexion(p);
  await p.setViewportSize({ width: 390, height: 350 });
  const valider = p.locator('#bandeau-reconnexion button[type=submit]');
  await valider.scrollIntoViewIfNeeded();
  assert.equal(await valider.evaluate(e => { const r = e.getBoundingClientRect(); return r.top >= 0 && r.bottom <= innerHeight; }), false);
}));

const creation = fs.readFileSync(path.join(R, 'creation.js'), 'utf8');
const fonctionsConnexion = acorn.parse(creation, { ecmaVersion: 'latest' }).body
  .filter(n => n.type === 'FunctionDeclaration' && ['ouvrirConnexionCompte', 'connecterAvecMotDePasse'].includes(n.id.name))
  .map(n => creation.slice(n.start, n.end)).join('\n');
for (const profil of profils) test(`${profil.nom} : accueil, connexion refusée puis compte existant, sans créer de personnage`, () => avecJeu(async (b, o) => {
  const p = await telephone(b, o, profil);
  const accueil = fs.readFileSync(path.join(R, 'index.html'), 'utf8').replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, '');
  await p.route('**/index.html', r => r.fulfill({ contentType: 'text/html', body: accueil }));
  await p.goto(o + '/index.html');
  await p.addScriptTag({ content: fonctionsConnexion });
  await p.evaluate(() => {
    window.authentifications = 0;
    window.lecturesCompte = 0;
    window.rpAuthSeConnecter = async () => { authentifications++; return { ok: false }; };
    window.sbRpc = async n => { if (n !== 'mon_personnage') throw Error('Écriture interdite'); lecturesCompte++; return 'Fixture mobile'; };
    window.sbLoadPersonnage = async () => ({ char: { name: 'Fixture mobile' }, country: 'republic', currentCity: 'capitale', arg: 0, inf: 0, pop: 0, dis: 0 });
    window.rpMarquerProprietaireCache = () => {};
  });
  await p.locator('button[onclick="ouvrirConnexionCompte()"]').first().tap();
  await p.locator('#connexion-email').fill('fixture@example.invalid');
  await p.locator('#connexion-mdp').fill('mot-de-passe-fixture');
  await p.locator('#connexion-valider').tap();
  await p.waitForFunction(() => document.getElementById('connexion-msg').textContent.includes('incorrect'));
  assert.equal(await p.evaluate(() => lecturesCompte), 0);
  assert.equal(await p.locator('#connexion-valider').isEnabled(), true);
  await p.evaluate(() => { window.rpAuthSeConnecter = async () => { authentifications++; return { ok: true }; }; });
  await p.locator('#connexion-valider').tap();
  await p.waitForURL('**/plateau.html');
  assert.equal(await p.evaluate(() => localStorage.getItem('respublica_last_char')), 'Fixture mobile');
  assert.equal(await p.evaluate(() => JSON.parse(localStorage.getItem('respublica_char')).name), 'Fixture mobile');
}));
