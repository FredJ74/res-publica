// Chromium réel, vrai plateau.html (HTML et feuilles de style, mobiles comprises) : médicaments, usines d'État et antidote
// (Fred, 22/11/2026, soir, GAME-DESIGN-SANTE-20261122.md, « Suites », point 8), à 1280 et à 390 px.
//  - Fenêtre de production de l'usine pharmaceutique : l'antidote est dans la liste, avec sa recette plus riche (chiffre du
//    serveur), et la production envoie le médicament choisi au serveur.
//  - Bouton du directeur « Virer à la tutelle » : ordre réservé au directeur, fenêtre avec caisse et fonds de roulement lus
//    sur le serveur, virement envoyé au serveur.
//  - Pharmacie : antidote listé (Empoisonnement, prix du serveur), achat, refus « liquide seulement » expliqué.
// Vrais fichiers : data.js, plateau-texte-minimum.js, plateau-maladies.js et les fonctions de plateau-justice-economie.js
// (extraites telles quelles) ; seul le serveur (sbRpc, sbRpcVerdict, sbGetBatimentEtat) est simulé.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const { avecJeu, page } = require('./mobile-navigateur.cjs');
const racine = path.resolve(__dirname, '../..');
const je = fs.readFileSync(path.join(racine, 'plateau-justice-economie.js'), 'utf8');

function bloc(src, debut) {
  const i = src.indexOf(debut); assert.ok(i >= 0, debut);
  let n = 0; const depart = /^(async )?function/.test(debut) ? src.indexOf(')', i) : src.indexOf('=', i);
  const ouvrant = depart + src.slice(depart).search(/[[{]/);
  const o = src[ouvrant], f = o === '[' ? ']' : '}';
  for (let k = ouvrant; k < src.length; k++) { if (src[k] === o) n++; else if (src[k] === f && --n === 0) return src.slice(i, k + 1) + ';'; }
}
const SOURCES = ['const PA_PRODUCTION_USINE =', 'const MATIERE_PAR_PA_USINE =', 'const PRODUIT_PAR_PA_USINE =', 'const PLAFOND_VENTE_DIRECTE_USINE =']
  .map(d => je.slice(je.indexOf(d), je.indexOf(';', je.indexOf(d)) + 1))
  .concat(['const CHAINES_PRODUCTION_USINE =', 'const CHAINES_PRODUCTION_PAYS =', 'function chainesUsinePays(', 'async function doProduireUsine(',
    'async function confirmerProductionUsine(', 'const DIRECTEUR_USINE_INFO =', 'const DIRECTEUR_USINE_INFO_PAYS =', 'function directeurUsineInfo(',
    'function doOuvrirVirementUsineMinistere(', 'async function confirmerVirementUsineMinistere('].map(d => bloc(je, d)))
  .join('\n') + '\nObject.assign(window, { doProduireUsine, confirmerProductionUsine, doOuvrirVirementUsineMinistere, confirmerVirementUsineMinistere });';
const PLANCHER = 15.2;   // 0,95 rem

async function preparer(b, o, largeur, hauteur) {
  const p = await page(b, o, largeur, hauteur);
  const erreurs = []; p.on('pageerror', e => erreurs.push(e.message));
  await p.evaluate(() => {
    window.state = { char: { name: 'Tom' }, country: 'republic', currentCity: 'capitale', currentBuilding: 'usine-pharmaceutique-luthecia',
      currentRoom: 'salle_production', poste: null, pa: 10, arg: 500, liquide: 500, inventory: [] };
    window.__appels = []; window.__toasts = []; window.__journal = [];
    window.showToast = (a, c, ok) => window.__toasts.push([a, c, !!ok]);
    window.addJournalEntry = t => window.__journal.push(t);
    window.updateUI = () => {}; window.appliquerPaiementServeur = () => {}; window.signalerRefusCout = v => window.__toasts.push(['refus', v && v.raison, false]);
    window.deduireCoutOrdre = async () => ({ ok: true });
    window.sbGet = async () => [];
    window.sbGetBatimentEtat = async () => ({ usine: { caisse: 900, venteDirecte: {}, stockMatieres: { plantes: 40 } } });
    window.__refusLiquide = false;
    window.sbRpc = async (fn, a) => {
      window.__appels.push([fn, a]);
      if (fn === 'usine_medicaments_etat') return { ok: true, pays: 'republic', stock_max: 50, matiere_par_pa: 5, produits_par_pa: 10, medicaments: [
        { medicament: 'antibiotique', maladie: 'mst', stock: 0, stock_pnj: 20, matiere_par_pa: 5, prix: 44 },
        { medicament: 'aspirine', maladie: 'gueule_de_bois', stock: 2, stock_pnj: 20, matiere_par_pa: 5, prix: 44 },
        { medicament: 'antidote', maladie: 'empoisonnement', stock: 3, stock_pnj: 10, matiere_par_pa: 15, prix: 132 }] };
      if (fn === 'produire_medicament') return { ok: true, medicament: a.p_medicament, produits: 10, salaire: 84, arg: 584, liquide: 584 };
      if (fn === 'usine_tutelle_etat') return { ok: true, caisse: 7350, fonds_roulement: 5000, tutelle: 'min_fin', pays: 'republic' };
      if (fn === 'pharmacie_etat') return { ok: true, point: 'usine-pharma-luthecia', prix_bandelette: 4, paiement: 'liquide', medicaments: [
        { medicament: 'aspirine', maladie: 'gueule_de_bois', nom_mj: null, prix: 44, restant: 22, stock_joueurs: 2, stock_pnj: 20 },
        { medicament: 'antidote', maladie: 'empoisonnement', nom_mj: null, prix: 132, restant: 4, stock_joueurs: 0, stock_pnj: 4 }] };
      if (fn === 'pharmacie_acheter') return window.__refusLiquide
        ? { ok: false, raison: 'fonds_insuffisants', requis: 132, disponible: 20, paiement: 'liquide' }
        : { ok: true, medicament: a.p_medicament, quantite: a.p_qte, prix: 132, paye: 132 * a.p_qte, inventory: [], liquide: 368 };
      return null;
    };
    window.sbRpcVerdict = async (fn, a) => { window.__appels.push([fn, a]); return { ok: true, montant: a.p_montant, paie: { pa: 9 } }; };
  });
  for (const s of ['data.js', 'plateau-texte-minimum.js', 'plateau-maladies.js']) await p.addScriptTag({ url: o + '/' + s });
  await p.addScriptTag({ content: SOURCES });
  await p.waitForFunction(() => window.RPMaladies && typeof window.doProduireUsine === 'function' && typeof ouvrirPharmacie === 'function');
  return { p, erreurs };
}
const taille = (p, sel) => p.evaluate(s => Array.from(document.querySelectorAll(s)).filter(e => e.offsetParent).map(e => parseFloat(getComputedStyle(e).fontSize)), sel);
async function dansEcran(p, sel) {
  const r = await p.evaluate(s => { const e = document.querySelector(s).getBoundingClientRect(); return { l: e.left, r: e.right, w: innerWidth,
    deborde: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1 }; }, sel);
  assert.ok(r.l >= -0.5 && r.r <= r.w + 0.5, sel + ' dans l’écran ' + JSON.stringify(r));
  assert.equal(r.deborde, false, 'aucun défilement horizontal');
}

for (const [largeur, hauteur] of [[1280, 860], [390, 844]]) {
  test(`fenêtre de production à ${largeur} px : l’antidote est dans la liste, recette du serveur, production envoyée`, async () => avecJeu(async (b, o) => {
    const { p, erreurs } = await preparer(b, o, largeur, hauteur);
    await p.evaluate(() => doProduireUsine('medicaments'));
    await p.waitForSelector('#usine-medicament-choix option', { state: 'attached' });
    const options = await p.locator('#usine-medicament-choix option').allInnerTexts();
    const plantes = await p.evaluate(() => RESSOURCES_ECONOMIE.plantes.label);
    assert.deepEqual(options, ['Antibiotique — stock national 0/50', 'Aspirine — stock national 2/50',
      'Antidote — stock national 3/50 — 15 ' + plantes + ' par PA']);
    await p.selectOption('#usine-medicament-choix', 'antidote');
    await dansEcran(p, '#modal-postes .modal-box, #modal-postes');
    await p.click('#postes-body button');
    await p.waitForFunction(() => window.__appels.some(a => a[0] === 'produire_medicament'));
    assert.deepEqual(await p.evaluate(() => window.__appels.find(a => a[0] === 'produire_medicament')[1]),
      { p_acteur: 'Tom', p_pays: 'republic', p_medicament: 'antidote' });
    assert.ok(await p.evaluate(() => window.__toasts.some(t => /Antidote produit/.test(t[1]))), 'toast de production');
    assert.deepEqual(erreurs, []);
  }));

  test(`bouton du directeur à ${largeur} px : « Virer à la tutelle », réservé au directeur, fonds de roulement lu sur le serveur`, async () => avecJeu(async (b, o) => {
    const { p, erreurs } = await preparer(b, o, largeur, hauteur);
    // L'ordre est déclaré dans le bureau de direction, réservé au poste de directeur.
    const ordre = await p.evaluate(() => {
      const rooms = BUILDINGS['usine-pharmaceutique-luthecia'].rooms;
      for (const r of Object.values(rooms)) for (const x of (r.orders || [])) if (x.fn === 'virement_usine_ministere') return x;
      return null;
    });
    assert.equal(ordre.label, 'Virer à la tutelle'); assert.equal(ordre.requiresPost, 'directeur_pharma');
    // Pas directeur : refus, aucune fenêtre ni appel.
    await p.evaluate(() => { state.currentRoom = 'bureau_direction'; doOuvrirVirementUsineMinistere(1, 0); });
    assert.ok(await p.evaluate(() => window.__toasts.some(t => t[0] === 'Accès refusé')));
    assert.equal(await p.locator('#virement-ministere-montant').count(), 0);
    assert.equal(await p.evaluate(() => window.__appels.filter(a => a[0] === 'usine_virer_vers_ministere').length), 0);
    // Directeur.
    await p.evaluate(() => { state.poste = { id: 'directeur_pharma' }; doOuvrirVirementUsineMinistere(1, 0); });
    assert.equal(await p.locator('#postes-modal-title').innerText(), 'Virer à la tutelle');
    await p.waitForFunction(() => /Fonds de roulement/.test(document.getElementById('virement-tutelle-etat').textContent));
    assert.match(await p.locator('#virement-tutelle-etat').innerText(), /Caisse : 7\s?350 FR\. Fonds de roulement : 5\s?000 FR ; chaque nuit, l'excédent est reversé automatiquement à la tutelle\./);
    assert.ok((await taille(p, '#virement-tutelle-etat')).every(t => t >= PLANCHER), 'texte ≥ texte courant');
    await dansEcran(p, '#virement-tutelle-etat');
    if (process.env.HG_PREUVES) await p.screenshot({ path: process.env.HG_PREUVES + '/virer-tutelle-' + largeur + '.png' });
    await p.fill('#virement-ministere-montant', '400');
    await p.click('#postes-body button');
    await p.waitForFunction(() => window.__appels.some(a => a[0] === 'usine_virer_vers_ministere'));
    assert.deepEqual(await p.evaluate(() => window.__appels.find(a => a[0] === 'usine_virer_vers_ministere')[1]), { p_montant: 400 });
    assert.ok(await p.evaluate(() => window.__toasts.some(t => t[0] === 'Virement effectué' && /ministère de tutelle/.test(t[1]))));
    assert.deepEqual(erreurs, []);
  }));

  test(`pharmacie à ${largeur} px : antidote listé et acheté ; refus « liquide seulement » expliqué`, async () => avecJeu(async (b, o) => {
    const { p, erreurs } = await preparer(b, o, largeur, hauteur);
    await p.evaluate(() => ouvrirPharmacie());
    await p.waitForSelector('#pharmacie-medicament option', { state: 'attached' });
    const options = await p.locator('#pharmacie-medicament option').allInnerTexts();
    assert.ok(options.includes('Antidote (Empoisonnement) — 132 FR — reste 4'), JSON.stringify(options));
    await p.selectOption('#pharmacie-medicament', 'antidote');
    await dansEcran(p, '#pharmacie-medicament');
    assert.ok((await taille(p, '#pharmacie-medicament')).every(t => t >= PLANCHER), 'liste ≥ texte courant');
    await p.click('#postes-body .cpj-primaire');
    await p.waitForFunction(() => window.__appels.some(a => a[0] === 'pharmacie_acheter'));
    const appel = await p.evaluate(() => window.__appels.find(a => a[0] === 'pharmacie_acheter')[1]);
    assert.equal(appel.p_medicament, 'antidote'); assert.equal(appel.p_qte, 1);
    assert.ok(await p.evaluate(() => window.__toasts.some(t => t[1] === '1 × Antidote pour 132 FR.')));
    // Refus : pas assez de liquide (la banque ne compte pas).
    await p.evaluate(() => { window.__refusLiquide = true; ouvrirPharmacie(); });
    await p.waitForSelector('#pharmacie-medicament option', { state: 'attached' });
    await p.selectOption('#pharmacie-medicament', 'antidote');
    await p.click('#postes-body .cpj-primaire');
    await p.waitForFunction(() => window.__toasts.some(t => /argent liquide/.test(t[1])));
    assert.ok(await p.evaluate(() => window.__toasts.some(t => t[1] === 'Pas assez d’argent liquide : la pharmacie se paie en liquide.')));
    // L'antidote pris : message propre.
    assert.equal(await p.evaluate(() => RPMaladies.texte('takenAntidote')), 'Antidote pris : le poison sera neutralisé à votre réveil.');
    assert.deepEqual(erreurs, []);
  }));
}
