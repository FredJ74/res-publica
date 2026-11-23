// Chromium réel, vrai plateau.html : le portrait de Vera Pravdina s'affiche dans l'interview d'accueil de Sovarka
// (Fred, 23/11/2026, GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, point 15), à la place de la pastille « V ».
// Échoue si le fichier manque, si l'image ne se charge pas (naturalWidth nul) ou si la pastille revient.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const { avecJeu, page, R } = require('./mobile-navigateur.cjs');
const FICHIER = 'images/Sovarka/Novomirsk/Novo_vera_pravdina_portrait.webp';

test('le fichier du portrait existe et le module le raccorde à Vera Pravdina', () => {
  assert.ok(fs.existsSync(path.join(R, FICHIER)), FICHIER);
  const src = fs.readFileSync(path.join(R, 'plateau-accueil-interview.js'), 'utf8');
  assert.match(src, /'Vera Pravdina': 'images\/Sovarka\/Novomirsk\/Novo_vera_pravdina_portrait\.webp'/);
});

function serveurSovarka() {
  const chemins = [['politique', 'La politique'], ['affaires', 'Les affaires']].map(([id, libelle]) => ({ id, libelle }));
  window.__appels = [];
  window.sbRpc = async (fn, a) => {
    window.__appels.push([fn, a]);
    if (fn === 'accueil_etat') return { ok: true, personnage: 'Ivan', pays: 'soviet',
      interview: { etat: 'a_faire', journaliste: 'Vera Pravdina', journal: 'La Pravdovka', question: 'Alors, camarade : quel chemin comptez-vous prendre ici ?', ouvrir_auto: true },
      mot_max: 280, chemins, chemin: null, mot: null, etapes: [], bulle_pa: { vue: true, pa: null, active: true } };
    if (fn === 'accueil_interview_vue') return { ok: true };
    if (fn === 'personnage_evenements_lire') return { ok: true, evenements: [] };
    return null;
  };
  window.rpAuthJeton = () => 'jeton';
  window.addJournalEntry = () => {}; window.showToast = () => {};
  window.__RP_ACCUEIL_SANS_MINUTERIE = true;
  window.state = { char: { name: 'Ivan', archetype: 'ambitieux' }, country: 'soviet', currentCity: 'capitale', pa: 10 };
}

for (const [largeur, hauteur] of [[1280, 860], [390, 844]]) {
  test(`${largeur} px : Vera Pravdina apparaît avec son portrait, sans pastille`, async () => avecJeu(async (b, o) => {
    const p = await page(b, o, largeur, hauteur, false, { texteMinimum: true });
    const erreurs = []; p.on('pageerror', e => erreurs.push(e.message));
    await p.evaluate(serveurSovarka);
    for (const s of ['plateau-evenements-personnage.js', 'plateau-accueil-interview.js']) await p.addScriptTag({ url: o + '/' + s });
    await p.waitForFunction(() => window.RPAccueil);
    await p.evaluate(() => window.RPAccueil.verifier());
    await p.waitForSelector('#hg-accueil-interview .hg-acc-chemin');
    assert.equal(await p.locator('#hg-acc-titre').innerText(), 'Vera Pravdina');
    const img = p.locator('#hg-accueil-interview img.hg-acc-portrait');
    assert.equal(await img.count(), 1, 'une image de portrait');
    assert.match(await img.getAttribute('src'), /Novo_vera_pravdina_portrait\.webp$/);
    await p.waitForFunction(() => { const i = document.querySelector('#hg-accueil-interview img.hg-acc-portrait'); return i && i.complete; });
    const nat = await img.evaluate(i => ({ w: i.naturalWidth, h: i.naturalHeight, vu: i.getBoundingClientRect().width }));
    assert.ok(nat.w >= 256 && nat.h >= 256, 'image chargée ' + JSON.stringify(nat));
    assert.ok(nat.vu > 20, 'image visible');
    const pastille = await p.evaluate(() => [...document.querySelectorAll('#hg-accueil-interview *')].some(e => e.children.length === 0 && e.textContent.trim() === 'V'));
    assert.equal(pastille, false, 'plus de pastille « V »');
    if (process.env.HG_PREUVES) await p.screenshot({ path: process.env.HG_PREUVES + '/accueil-vera-' + largeur + '.png' });
    assert.deepEqual(erreurs, []);
  }));
}
