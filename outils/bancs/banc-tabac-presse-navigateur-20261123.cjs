'use strict';
// Navigateur réel (plateau.html, plateau-fenetres.js) : carte postale et cigarettes du tabac-presse de Krasnov (Fred,
// 22/11/2026, soir, points 27 et 28). Vrai code de plateau-personnage.js et plateau-divers.js ; seul le serveur est
// simulé, avec les réponses de la migration 20261123150000 (carte_postale_envoyer, inventaire_consommer « tabac »).
// Le bug de Fred : l'onglet Inventaire ouvrait une fenêtre de détail sans l'action « Écrire et envoyer ».
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
  // Déclarations rendues globales (window) pour les gestionnaires onclick du HTML produit.
  return morceaux.join('\n') + '\n' + noms.map(n => `window.${n} = ${n};`).join('\n');
}
const CODE = [
  extraire('plateau-divers.js', ['MOTIFS_SORTIE_INVENTAIRE', 'signatureObjetInventaire', 'removeFromInventory', 'texteInventaire', 'messageRefusSortieInventaire']),
  extraire('plateau-personnage.js', ['TEXTES_CARTE_POSTALE', 'texteCartePostale', 'legendeCartePostale', 'rectoCartePostaleHtml', 'boutonsTabacPresseObjet',
    'fumerTabacEnCours', 'fumerTabac', 'ouvrirEcrireCartePostale', 'fermerModalCartePostale', 'envoyerCartePostale', 'lireCartePostale', 'ouvrirDetailObjet'])
].join('\n');

const CARTE = { id: 'carte_krasnov_place_ours_1', type: 'carte_krasnov_place_ours', modele: 'carte_krasnov_place_ours', name: 'Carte postale — Krasnov, la place de l\'Ours',
  icon: 'ti-mail', imageUrl: 'images/Sovarka/Krasnov/Krasnov_place_ours.webp', etatCarte: 'vierge', familleProduitMarche: 'carte_postale',
  desc: 'La statue de l\'Ours, ses bancs et la mairie, sous la pluie d\'automne. À écrire et à envoyer.' };
const CIGARETTE = { id: 'krasnov_papirossy_1', type: 'krasnov_papirossy', name: 'Cigarettes papirossy « Étoile du Nord »', icon: 'ti-smoking', familleProduitMarche: 'tabac' };

async function preparer(b, o, inventaire) {
  const p = await page(b, o, 1280, 900, false, { texteMinimum: true });
  await p.addScriptTag({ content: CODE });
  await p.evaluate(inv => {
    window.COUNTRIES = { soviet: { cur: 'PSK' } };
    window.state = { char: { name: 'Arnie' }, country: 'soviet', moral: 50, inventory: inv };
    window.appels = []; window.toasts = []; window.journal = [];
    window.showToast = (t, m, ok) => toasts.push({ t, m, ok });
    window.addJournalEntry = m => journal.push(m);
    window.escapeHtmlText = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
    window.sbListPersonnages = async () => [{ name: 'Arnie' }, { name: 'Tom Tom' }, { name: 'Jodie Moitout' }];
    window.sbAdopterInventaireServeur = r => { state.inventory = r.inventory; };
    window.updateUI = () => {}; window.renderInventory = () => {};
    // Serveur simulé (réponses de la migration 20261123150000).
    window.sbRpcVerdict = async (fn, prm) => {
      appels.push({ fn, prm });
      if (fn === 'carte_postale_envoyer') {
        if (!prm.p_message.trim()) return { ok: false, raison: 'message_vide' };
        const inv = state.inventory.filter((_, i) => i !== prm.p_index);
        return { ok: true, objet_id: 'objet-recu-1', inventory: inv, revision: 2 };
      }
      return { ok: false, raison: 'refus_serveur' };
    };
    window.sbInventaireConsommer = async (acteur, idx) => {
      appels.push({ fn: 'inventaire_consommer', idx });
      return { ok: true, tabac: true, moral: 52, effets: { moral: 2 }, inventory: state.inventory.filter((_, i) => i !== idx) };
    };
  }, inventaire);
  return p;
}

test('bug corrigé : l’onglet Inventaire propose « Écrire et envoyer » ; le serveur écrit et envoie la carte', async () => avecJeu(async (b, o) => {
  const p = await preparer(b, o, [CARTE]);
  await p.evaluate(() => ouvrirDetailObjet(0));
  await p.locator('#modal-postes .hg-carte-ecrire').click();
  await p.waitForSelector('#modal-carte-postale.open #carte-postale-destinataire option[value="Tom Tom"]', { state: 'attached' });
  assert.equal(await p.locator('#modal-postes').evaluate(e => e.classList.contains('open')), false, 'une seule fenêtre visible');
  assert.equal((await p.locator('#carte-postale-body .hg-carte-legende').textContent()).trim(), 'Krasnov, capitale de l’ours');
  assert.equal(await p.locator('#carte-postale-destinataire option[value="Arnie"]').count(), 0, 'on ne s’écrit pas à soi-même');
  await p.locator('#carte-postale-destinataire').selectOption('Tom Tom');
  await p.locator('#carte-postale-message').fill('Grosses bises de Krasnov !');
  await p.locator('#carte-postale-envoyer-btn').click();
  await p.waitForFunction(() => toasts.length > 0);
  const r = await p.evaluate(() => ({ appels, toasts, inv: state.inventory, ouverte: document.getElementById('modal-carte-postale').classList.contains('open') }));
  assert.equal(r.appels[0].fn, 'carte_postale_envoyer');
  assert.deepEqual({ ...r.appels[0].prm, p_signature: undefined }, { p_acteur: 'Arnie', p_index: 0, p_destinataire: 'Tom Tom', p_message: 'Grosses bises de Krasnov !', p_signature: undefined });
  assert.equal(r.appels[0].prm.p_signature.type, 'carte_krasnov_place_ours');
  assert.equal(r.toasts[0].ok, true); assert.match(r.toasts[0].m, /Tom Tom/);
  assert.equal(r.inv.length, 0, 'inventaire du serveur adopté'); assert.equal(r.ouverte, false);
}));

test('carte reçue : recto avec l’image et la légende, un clic la retourne sur le message signé', async () => avecJeu(async (b, o) => {
  const ecrite = { ...CARTE, etatCarte: 'ecrite', auteur: 'Tom Tom', destinataireInitial: 'Arnie', message: 'Viens voir l’Ours <b>sous la pluie</b>.',
    dateEnvoi: '22/11/2026 à 21:40', bonusDeclenche: true };
  const p = await preparer(b, o, [ecrite]);
  await p.evaluate(() => ouvrirDetailObjet(0));
  await p.locator('#modal-postes .hg-carte-lire').click();
  const carte = p.locator('#carte-postale-retournable');
  assert.equal(await carte.getAttribute('data-face'), 'recto');
  assert.ok(await p.locator('.hg-carte-recto img').isVisible());
  assert.equal((await p.locator('.hg-carte-recto .hg-carte-legende').textContent()).trim(), 'Krasnov, capitale de l’ours');
  assert.equal(await p.locator('.hg-carte-verso').isVisible(), false);
  await carte.click();
  assert.equal(await carte.getAttribute('data-face'), 'verso');
  assert.ok(await p.locator('.hg-carte-verso').isVisible());
  assert.equal((await p.locator('.hg-carte-signature').textContent()).trim(), '— Tom Tom');
  assert.match(await p.locator('.hg-carte-verso').textContent(), /Viens voir l’Ours <b>sous la pluie<\/b>\./, 'message échappé, jamais interprété');
  await p.locator('#carte-postale-body .hg-carte-retourner').click();
  assert.equal(await carte.getAttribute('data-face'), 'recto');
  // Carte écrite : plus d'« Écrire et envoyer ».
  await p.evaluate(() => { document.getElementById('modal-carte-postale').classList.remove('open'); ouvrirDetailObjet(0); });
  assert.equal(await p.locator('#modal-postes .hg-carte-ecrire').count(), 0);
}));

test('cigarettes : « Fumer » depuis l’inventaire, Moral recopié du serveur', async () => avecJeu(async (b, o) => {
  const p = await preparer(b, o, [CIGARETTE]);
  await p.evaluate(() => ouvrirDetailObjet(0));
  await p.locator('#modal-postes .hg-tabac-fumer').click();
  await p.waitForFunction(() => toasts.length > 0);
  const r = await p.evaluate(() => ({ appels, toasts, moral: state.moral, inv: state.inventory }));
  assert.equal(r.appels[0].fn, 'inventaire_consommer');
  assert.equal(r.moral, 52); assert.equal(r.inv.length, 0);
  assert.match(r.toasts[0].m, /\+2 Moral/);
}));

test('légendes : une clé par carte postale existante, seule Krasnov a son texte', () => {
  const s = fs.readFileSync(path.join(R, 'plateau-actions-illegales-rumeurs.js'), 'utf8');
  const cartes = [...s.matchAll(/^\s+(carte_[a-z_]+): \{\s*\n\s+id: '\1', label: 'Carte postale/gm)].map(m => m[1]);
  assert.equal(cartes.length, 10);
  const p = fs.readFileSync(path.join(R, 'plateau-personnage.js'), 'utf8');
  for (const c of cartes) assert.ok(p.includes('legende_' + c + ':'), 'légende prévue : ' + c);
  assert.match(p, /legende_carte_krasnov_place_ours: 'Krasnov, capitale de l’ours'/);
});
