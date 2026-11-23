'use strict';
// Navigateur réel (plateau.html, plateau-fenetres.js, plancher de texte) : une seule fiche d'objet, fenêtre Inventaire et
// fenêtre Argent du panneau de gauche (Fred, 23/11/2026, GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, points 1, 17, 18).
// Vrai code de plateau-personnage.js ; seuls le serveur et les actions elles-mêmes sont simulés (chaque action note son
// appel : le banc prouve que chaque action des deux anciennes fiches est atteignable d'un clic dans la fiche unique).
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const { avecJeu, page, R } = require('./mobile-navigateur.cjs');
let acorn;
for (const m of ['acorn', '../e2e/node_modules/acorn', '../vercel/node_modules/acorn']) { try { acorn = require(m); break; } catch (_) {} }

function extraire(fichier, noms) {
  const s = fs.readFileSync(path.join(R, fichier), 'utf8'), vus = new Set(), morceaux = [];
  for (const n of acorn.parse(s, { ecmaVersion: 'latest' }).body) {
    const nom = n.type === 'FunctionDeclaration' ? n.id.name
      : n.type === 'VariableDeclaration' ? n.declarations.map(d => d.id && d.id.name).find(x => noms.includes(x)) : null;
    if (nom && noms.includes(nom)) { morceaux.push(s.slice(n.start, n.end)); vus.add(nom); }
  }
  assert.deepEqual(noms.filter(n => !vus.has(n)), [], fichier + ' : déclarations introuvables');
  return morceaux.join('\n') + '\n' + noms.map(n => `window.${n} = ${n};`).join('\n');
}
const CODE = extraire('plateau-personnage.js', ['TEXTES_CARTE_POSTALE', 'texteCartePostale', 'boutonsTabacPresseObjet',
  'STYLE_ACTION_FICHE', 'STYLE_DANGER_FICHE', 'RP_FICHE_OBJET_JETON', 'fermerFenetreCommune', 'ouvrirFicheObjet',
  'ouvrirDetailObjetInventaire', 'ouvrirDetailObjet', 'fermerPanneauMobile', 'echapperFenetrePanneau', 'htmlFenetreInventaire',
  'ouvrirFenetreInventaire', 'fenetreInventaireAffichee', 'rafraichirFenetreInventaireSiOuverte', 'montrerPanneauPersonnage',
  'NOMS_BANQUES_PATRIMOINE', 'nomBanquePatrimoine', 'datePatrimoine', 'RP_PATRIMOINE_JETON', 'ouvrirFenetreArgent']);

// Actions (fonctions appelées par un clic) à simuler ; chacune note son nom et ses arguments.
const ACTIONS = ['consommerDrogue', 'mangerOeufs', 'consommerAliment', 'lireGuideBaies', 'ouvrirEcrireCartePostale', 'lireCartePostale',
  'fumerTabac', 'ouvrirSerrureObjet', 'hgMontrerDepuisFiche', 'donnerObjetAJoueur', 'jeterObjetInventaire', 'supprimerItemInventaire',
  'ouvrirModalEmpoisonner', 'doSesoigner', 'doObserverJumelles', 'doConsommerRationCombat', 'ouvrirSoinTrousse', 'doUtiliserExplosifs',
  'enigme1AfficherCalepin', 'ouvrirPopupArmoireSouvenirs', 'actionAide'];
// Boutons fabriqués par d'autres modules (plateau-maladies.js, plateau-criminalite.js…) : la fiche doit les appeler.
const AIDES = ['boutonMangerMatiereBrute', 'boutonMangerProduitMarche', 'boutonsTresorTsarsObjet', 'boutonRevetir', 'boutonPoserSacs',
  'boutonDeposerGraisse', 'boutonRenifler', 'boutonBandelettes', 'boutonBoire', 'boutonMedicamentMaladie'];

// Inventaire réel de l'ancienne fiche du panneau de gauche (ouvrirDetailObjetInventaire, A) et de l'ancienne fiche de
// l'onglet Inventaire (ouvrirDetailObjet, B), relevé dans origin/main avant fusion : [objet, action attendue, fiches].
const CAS = [
  [{ name: 'Brume', type: 'drogue', drogue: 'brume' }, 'consommerDrogue', 'A B'],
  [{ name: 'Œufs', stackKey: 'oeufs', qty: 3 }, 'mangerOeufs', 'A B'],
  [{ name: 'Sandwich', familleProduitMarche: 'aliment' }, 'consommerAliment', 'A B'],
  [{ name: 'Guide des baies', type: 'guide_baies_krasnov' }, 'lireGuideBaies', 'A'],
  [{ name: 'Carte vierge', familleProduitMarche: 'carte_postale', etatCarte: 'vierge' }, 'ouvrirEcrireCartePostale', 'A B'],
  [{ name: 'Carte écrite', familleProduitMarche: 'carte_postale', etatCarte: 'ecrite' }, 'lireCartePostale', 'A B'],
  [{ name: 'Papirossy', familleProduitMarche: 'tabac' }, 'fumerTabac', 'A B'],
  [{ name: 'Serrure', type: 'serrure_cle' }, 'ouvrirSerrureObjet', 'A'],
  [{ name: 'Clé', type: 'cle_serrure' }, 'ouvrirSerrureObjet', 'A'],
  [{ name: 'Clé vierge', type: 'cle_vierge' }, 'ouvrirSerrureObjet', 'A'],
  [{ name: 'Montre' }, 'donnerObjetAJoueur', 'A'],
  [{ name: 'Montre' }, 'hgMontrerDepuisFiche', 'A'],
  [{ name: 'Colis secret', protege: true }, 'hgMontrerDepuisFiche', 'A'],
  [{ name: 'Montre' }, 'jeterObjetInventaire', 'A'],
  [{ name: 'Montre' }, 'supprimerItemInventaire', 'A B (Jeter = destruction)'],
  [{ name: 'Fiole', type: 'poison' }, 'ouvrirModalEmpoisonner', 'B'],
  [{ name: 'Aspirine', type: 'medicament' }, 'doSesoigner', 'B'],
  [{ name: 'Jumelles', produitMilitaire: 'jumelles' }, 'doObserverJumelles', 'B'],
  [{ name: 'Ration', produitMilitaire: 'ration_combat' }, 'doConsommerRationCombat', 'B'],
  [{ name: 'Trousse', produitMilitaire: 'trousse_secours' }, 'ouvrirSoinTrousse', 'B'],
  [{ name: 'Dynamite', type: 'explosif' }, 'doUtiliserExplosifs', 'B'],
  ...AIDES.map(a => [{ name: 'Objet ' + a, aide: a, type: a === 'boutonMedicamentMaladie' ? 'medicament_maladie' : undefined }, 'actionAide:' + a, a === 'boutonMedicamentMaladie' ? 'B' : 'A B'])
];

async function preparer(b, o, inventaire, w = 1280, h = 900) {
  const p = await page(b, o, w, h, false, { texteMinimum: true });
  await p.addScriptTag({ content: CODE });
  await p.evaluate(([inv, actions, aides]) => {
    window.COUNTRIES = { republic: { cur: 'FR' } };
    window.state = { char: { name: 'Arnie', country: 'republic' }, country: 'republic', currentCity: 'capitale', currentBuilding: 'mairie',
      currentRoom: 'hall', liquide: 1250, inventory: inv };
    window.appels = [];
    for (const a of actions) window[a] = (...args) => { appels.push(a + (a === 'actionAide' ? ':' + args[0] : '')); };
    for (const a of aides) window[a] = item => item && item.aide === a ? '<button class="hg-aide" onclick="actionAide(\'' + a + '\')">' + a + '</button>' : '';
    window.colisSecretProtege = item => !!(item && item.protege);
    window.sbGetPresencesInRoom = async () => [{ name: 'Arnie' }, { name: 'Tom Tom' }];
    window.showToast = () => {};
  }, [inventaire, ACTIONS, AIDES]);
  return p;
}
const fenetresOuvertes = p => p.evaluate(() => [...document.querySelectorAll('.modal-overlay.open')].map(e => e.id));

test('fiche unique : chaque action des deux anciennes fiches est atteignable d’un clic', async () => avecJeu(async (b, o) => {
  const p = await preparer(b, o, []);
  for (const [objet, action, fiches] of CAS) {
    await p.evaluate(o2 => { state.inventory = [o2]; appels.length = 0; document.getElementById('modal-postes').classList.remove('open'); }, objet);
    await p.evaluate(() => ouvrirFicheObjet(0));
    await p.waitForSelector('#modal-postes.open .hg-fiche-objet');
    const fn = action.startsWith('actionAide:') ? 'actionAide' : action;
    const bouton = action.startsWith('actionAide:')
      ? p.locator('#postes-body .hg-aide', { hasText: action.slice(11) })
      : p.locator('#postes-body button[onclick*="' + fn + '("]');
    assert.ok(await bouton.count() >= 1, objet.name + ' : bouton « ' + action + ' » absent (ancienne fiche ' + fiches + ')');
    await bouton.first().click();
    const notes = await p.evaluate(() => appels.slice());
    assert.ok(notes.includes(action), objet.name + ' : le clic n’a pas appelé ' + action + ' (' + notes.join(', ') + ')');
  }
}));

test('anciens noms : ouvrirDetailObjet et ouvrirDetailObjetInventaire ouvrent la même fiche ; routages calepin et armoire', async () => avecJeu(async (b, o) => {
  const p = await preparer(b, o, [{ name: 'Fiole', type: 'poison', desc: 'Un liquide trouble.' }]);
  const rendu = async f => { await p.evaluate(f); await p.waitForSelector('#modal-postes.open .hg-fiche-objet'); return p.locator('#postes-body').innerHTML(); };
  const a = await rendu(() => ouvrirDetailObjet(0));
  const b2 = await rendu(() => ouvrirDetailObjetInventaire(0));
  const c = await rendu(() => ouvrirFicheObjet(0));
  assert.equal(a, c); assert.equal(b2, c);
  await p.evaluate(() => { state.inventory = [{ name: 'Calepin', calepinEnigme1: true }, { name: 'Armoire', type: 'armoire_souvenirs' }]; appels.length = 0; });
  await p.evaluate(() => ouvrirDetailObjet(0)); await p.evaluate(() => ouvrirDetailObjetInventaire(1));
  assert.deepEqual(await p.evaluate(() => appels), ['enigme1AfficherCalepin', 'ouvrirPopupArmoireSouvenirs']);
}));

test('objet de mission : ni Donner, ni Déposer, ni Détruire ; une seule fenêtre ; texte jamais sous le texte courant', async () => avecJeu(async (b, o) => {
  const p = await preparer(b, o, [{ name: 'Colis secret', protege: true, desc: 'À remettre.' }], 390, 844);
  await p.evaluate(() => ouvrirFicheObjet(0));
  await p.waitForSelector('#modal-postes.open .hg-fiche-objet');
  assert.equal(await p.locator('#postes-body button[onclick*="donnerObjetAJoueur("]').count(), 0);
  assert.equal(await p.locator('#postes-body button[onclick*="jeterObjetInventaire("]').count(), 0);
  assert.equal(await p.locator('#postes-body button[onclick*="supprimerItemInventaire("]').count(), 0);
  assert.deepEqual(await fenetresOuvertes(p), ['modal-postes']);
  await p.waitForTimeout(100);
  const petits = await p.evaluate(() => { const plancher = RPTexteMinimum.plancherPx() - 0.1; return [...document.querySelectorAll('#postes-body *')]
    .filter(e => e.childNodes.length && [...e.childNodes].some(n => n.nodeType === 3 && n.nodeValue.trim()) && e.tagName !== 'I')
    .filter(e => parseFloat(getComputedStyle(e).fontSize) < plancher).map(e => e.textContent.trim().slice(0, 40)); });
  assert.deepEqual(petits, [], 'texte plus petit que le texte courant');
}));

test('fenêtre Inventaire : vignettes, Déposer, Détruire, clic → fiche dans la même fenêtre, retour, suivi en direct', async () => avecJeu(async (b, o) => {
  const p = await preparer(b, o, [
    { name: 'Carte vierge', familleProduitMarche: 'carte_postale', etatCarte: 'vierge', imageUrl: 'images/arme-fusil-republic.webp' },
    { name: 'Bois', icon: 'ti-tree', stackable: true, stackKey: 'bois', qty: 4 },
    { name: 'Colis secret', protege: true }]);
  await p.evaluate(() => ouvrirFenetreInventaire());
  await p.waitForSelector('#modal-postes.open .hg-fenetre-inventaire');
  assert.equal((await p.locator('#postes-modal-title').textContent()).trim(), 'Inventaire');
  assert.equal(await p.locator('.hg-inventaire-ligne').count(), 3);
  assert.equal(await p.locator('.hg-inventaire-ligne img').count(), 1, 'vignette de l’objet illustré');
  assert.match(await p.locator('.hg-inventaire-ligne').nth(1).textContent(), /Bois × 4/);
  assert.equal(await p.locator('.hg-inventaire-deposer').count(), 2, 'Déposer sauf objet de mission');
  assert.equal(await p.locator('.hg-inventaire-detruire').count(), 2, 'Détruire sauf objet de mission');
  assert.equal(await p.locator('#inventaire-panel').count(), 1, 'carnet secrets et énigmes accueillis');
  await p.locator('.hg-inventaire-deposer').first().click();
  await p.locator('.hg-inventaire-detruire').nth(1).click();
  assert.deepEqual(await p.evaluate(() => appels), ['jeterObjetInventaire', 'supprimerItemInventaire']);
  // Suivi en direct : le bois diminue, la liste suit.
  await p.evaluate(() => { state.inventory[1].qty = 2; rafraichirFenetreInventaireSiOuverte(); });
  assert.match(await p.locator('.hg-inventaire-ligne').nth(1).textContent(), /Bois × 2/);
  // Clic sur un objet : la fiche unique remplace la liste, dans la même fenêtre.
  await p.locator('.hg-inventaire-ligne').first().click();
  await p.waitForSelector('#modal-postes.open .hg-fiche-objet');
  assert.deepEqual(await fenetresOuvertes(p), ['modal-postes']);
  assert.ok(await p.locator('#postes-body .hg-carte-ecrire').count() === 1, 'fiche unique (carte : écrire et envoyer)');
  // Un rafraîchissement d'inventaire n'écrase pas la fiche affichée.
  await p.evaluate(() => rafraichirFenetreInventaireSiOuverte());
  assert.equal(await p.locator('#postes-body .hg-fiche-objet').count(), 1);
  await p.locator('#postes-body .hg-fiche-retour').click();
  await p.waitForSelector('#modal-postes.open .hg-fenetre-inventaire');
  await p.locator('.hg-inventaire-fermer').click();
  assert.deepEqual(await fenetresOuvertes(p), []);
}));

test('fenêtre Argent : liquide, chaque banque, placements (montant, échéance), prêts (restant dû, banque) ; lecture en échec nommée', async () => avecJeu(async (b, o) => {
  const p = await preparer(b, o, []);
  await p.evaluate(() => {
    window.construireMapComptesBancaires = rows => Object.fromEntries(rows.map(r => [r.banque, r]));
    window.TYPES_PRET = { travaux: { label: 'Travaux' } };
    window.sbGetComptesBancaires = async () => [{ banque: 'nationale', solde: 3000 }, { banque: 'helvetia', solde: 12000 }];
    window.sbGetPlacementsBancaires = async () => [{ banque: 'helvetia', type: 'declare', montant: 5000, statut: 'actif', prochaine_echeance: '2026-11-30T10:00:00Z' },
      { banque: 'nationale', montant: 999, statut: 'resolu' }];
    window.sbGet = async (table, filtre) => { appels.push('sbGet:' + table + ':' + filtre); return [{ type_pret: 'travaux', type_banque: 'nationale', montant_restant: 42000, duree_jours: 30, mensualite: 1400, created_at: '2026-11-20T10:00:00Z', jours_impayes: 0 }]; };
  });
  await p.evaluate(() => ouvrirFenetreArgent());
  await p.waitForSelector('#modal-postes.open .hg-fenetre-argent-prete');
  const texte = await p.locator('#postes-body').textContent();
  assert.match(texte, /Liquide\s*1\s250 FR/);
  assert.match(texte, /Banque nationale\s*3\s000 FR/); assert.match(texte, /Banque Helvetia\s*12\s000 FR/);
  assert.equal(await p.locator('.hg-argent-placement').count(), 1, 'seuls les placements actifs');
  assert.match(await p.locator('.hg-argent-placement').textContent(), /5\s000 FR[\s\S]*échéance : 30 novembre 2026/);
  assert.match(await p.locator('.hg-argent-pret').textContent(), /Prêt travaux — Banque nationale\s*42\s000 FR restant dû/);
  assert.deepEqual(await p.evaluate(() => appels), ['sbGet:prets:emprunteur=eq.Arnie&statut=eq.en_cours']);
  assert.equal(await p.evaluate(() => state.comptesBancaires.helvetia.solde), 12000, 'l’écran adopte la lecture du serveur');
  // Lecture impossible : dite, jamais montrée comme « aucun ».
  await p.evaluate(() => { window.sbGetComptesBancaires = async () => { throw new Error('réseau'); }; window.sbGet = async () => null; });
  await p.evaluate(() => ouvrirFenetreArgent());
  await p.waitForSelector('#modal-postes.open .hg-fenetre-argent-prete');
  assert.equal(await p.locator('.hg-argent-indisponible').count(), 2);
  assert.doesNotMatch(await p.locator('#postes-body').textContent(), /Aucun compte|Aucun prêt/);
}));
