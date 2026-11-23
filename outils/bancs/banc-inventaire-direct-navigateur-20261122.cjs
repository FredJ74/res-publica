'use strict';
// Chromium réel, DEUX pages = deux joueurs (Tom Tom, chef ; Arnie, membre de son groupe), dans la même pièce de la forêt
// de Krasnov (Fred, 22/11/2026, fin de nuit, points 2, 3 et 4). Vrai code du navigateur (plateau-divers.js,
// plateau-personnage.js, plateau-pnj.js, plateau-communication.js, plateau-temps-reel.js, plateau-multijoueur.js,
// supabase.js) ; seul le serveur est simulé, avec les règles de la migration 20261122200000 (capacité, piles au sol,
// refus nommés) et ses signaux (salles_signaux, personnages_signaux) envoyés comme le temps réel de Supabase.
// Aucune page n'est rechargée : tout doit apparaître en direct chez le joueur concerné et chez l'autre.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), os = require('node:os'), http = require('node:http');
const { chromium } = require('../e2e/node_modules/playwright');
const acorn = require('../vercel/node_modules/acorn');
const { lancerChromium } = require('./fixtures/chromium-cdp.cjs');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');

// Déclarations de premier niveau (fonctions, const/let) extraites telles quelles des fichiers du jeu.
function extraire(fichier, noms) {
  const s = lire(fichier), corps = acorn.parse(s, { ecmaVersion: 'latest' }).body, vus = new Set(), morceaux = [];
  for (const n of corps) {
    const nom = n.type === 'FunctionDeclaration' ? n.id.name
      : n.type === 'VariableDeclaration' ? n.declarations.map(d => d.id && d.id.name).find(x => noms.includes(x)) : null;
    if (nom && noms.includes(nom)) { morceaux.push(s.slice(n.start, n.end)); vus.add(nom); }
  }
  const manquants = noms.filter(n => !vus.has(n));
  assert.deepEqual(manquants, [], fichier + ' : déclarations introuvables');
  return morceaux.join('\n');
}
const CODE = [
  extraire('supabase.js', ['RP_INVENTAIRE_ORIGINE', 'sbEmpreinteInventaire', 'sbContexteInventaire', 'sbMarquerInventaires', 'sbAdopterInventaireServeur',
    'sbRpc', 'sbRpcVerdict', 'verdictRpc', 'sbInventaireAbandonner', 'sbObjetAbandonneRamasser', 'sbInventaireDonner', 'sbGetObjetsAbandonnesDansPiece',
    'sbGetPresencesInRoom', 'RP_RAISONS_ETAT_PERIME', 'sbInventaireReceptionEtat', 'sbGetLivraisonsEnAttente', 'sbInventaireReclamerLivraison']),
  extraire('plateau-divers.js', ['PLAFOND_INVENTAIRE_EMPILABLE', 'capaciteInventaire', 'adopterCapaciteInventaire', 'placeInventaireLibre', 'getTotalInventaire',
    'MOTIFS_SORTIE_INVENTAIRE', 'signatureObjetInventaire', 'removeFromInventory', 'texteInventaire', 'messageRefusSortieInventaire',
    'rafraichirOngletInventaireSiOuvert', 'renderInventory']),
  // L'onglet Inventaire de la fiche est devenu la fenêtre Inventaire du panneau de gauche (Fred, 23/11/2026, point 18).
  extraire('plateau-personnage.js', ['fermerFenetreCommune', 'fermerPanneauMobile', 'echapperFenetrePanneau', 'htmlFenetreInventaire', 'ouvrirFenetreInventaire',
    'fenetreInventaireAffichee', 'rafraichirFenetreInventaireSiOuverte', 'RP_FENETRE_QUANTITE', 'echapperTexteInventaire', 'fermerFenetreQuantite', 'ouvrirFenetreQuantite',
    'validerFenetreQuantite', 'quantiteDetenueInventaire', 'jeterObjetInventaire', 'deposerObjetInventaire', 'chargerObjetsAbandonnesDansPiece',
    'ramasserObjetAbandonne', 'ramasserObjetAbandonneQuantite', 'donnerObjetQuantite', 'confirmerDonObjetQuantite']),
  extraire('plateau-pnj.js', ['ouvrirDonPnjChoix', 'ouvrirDonObjetJoueurModal']),
  extraire('plateau-communication.js', ['RP_OBJETS_RECUS_EN_COURS', 'verifierObjetsRecus'])
].join('\n');

const PAGE = '<!doctype html><meta charset="utf-8"><body>'
  + '<div id="vue-self" class="vue active"><div class="piece-tab"></div><div class="piece-tab active"></div><div id="self-content"></div></div>'
  + '<div id="inv-items"></div><div id="persons-list"><div class="person-card" onclick="openSelfView()"><div class="person-avatar"></div><div><div class="person-name">Moi (Vous)</div></div></div></div>'
  + '<div id="modal-pnj"></div><div id="modal-postes"><div id="postes-modal-title"></div><div id="postes-body"></div></div></body>';

// ------------------------------------------------------------------------------------------------------------
// Serveur simulé : règles de la migration 20261122200000.
// ------------------------------------------------------------------------------------------------------------
const bois = q => ({ name: 'Bois', icon: 'ti-tree', type: 'matiere_premiere', stackable: true, stackKey: 'bois', qty: q });
function unites(inv) {
  const e = v => (typeof v === 'number' && Number.isInteger(v) && v >= 0) || (typeof v === 'string' && /^[0-9]+$/.test(v));
  return (inv || []).reduce((n, o) => n + (e(o.quantite) ? +o.quantite : e(o.qty) ? +o.qty : e(o.encombrement) ? +o.encombrement : 1), 0);
}
function serveurNeuf() {
  const S = {
    persos: {
      'Tom Tom': { inv: [bois(30), { name: 'Hache', type: 'outil', icon: 'ti-axe' }], rev: 1, cap: 100 },
      'Arnie': { inv: [bois(90), { name: 'Revolver .38', type: 'arme' }, { name: 'Peau', stackable: true, stackKey: 'peaux', qty: 4 }], rev: 1, cap: 100 }
    },
    sol: [], recus: [], pages: {}, appels: [], n: 0, version: 1
  };
  const signal = (topic, qui) => {
    S.version++;
    for (const [nom, page] of Object.entries(S.pages)) {
      if (qui && qui !== nom) continue;
      setTimeout(() => page.evaluate(m => window.RPTempsReel.traiterMessage(m), { event: 'postgres_changes', topic, payload: { data: { record: { version: S.version } } } }).catch(() => {}), 40);
    }
  };
  const salle = () => signal('realtime:hg-salle', null);
  const perso = nom => signal('realtime:hg-personnage', nom);
  const ecrire = (nom, inv) => { S.persos[nom].inv = inv; S.persos[nom].rev++; perso(nom); salle(); };
  const localiser = (inv, i, sig) => {
    const ok = (o) => (o.name || '') === (sig.name || '') && (o.type || '') === (sig.type || '') && (o.stackKey || '') === (sig.stackKey || '');
    if (inv[i] && ok(inv[i])) return i; return inv.findIndex(ok);
  };
  const sortir = (inv, i, sig, q) => {
    const pos = localiser(inv, i, sig); if (pos < 0) return { ok: false, raison: 'objet_absent' };
    const it = inv[pos];
    if (it.stackable && it.stackKey) {
      const det = inv.filter(o => o.stackKey === it.stackKey).reduce((n, o) => n + (o.qty || 1), 0);
      if (det < q) return { ok: false, raison: 'quantite_insuffisante', detenu: det };
      let reste = q; const n = inv.map(o => ({ ...o }));
      for (const o of n) if (o.stackKey === it.stackKey && reste > 0) { const p = Math.min(o.qty || 1, reste); o.qty = (o.qty || 1) - p; reste -= p; }
      return { ok: true, inventory: n.filter(o => o.stackKey !== it.stackKey || o.qty > 0), objet: { ...it, qty: q } };
    }
    if (q !== 1) return { ok: false, raison: 'quantite_insuffisante', detenu: 1 };
    return { ok: true, inventory: inv.filter((_, k) => k !== pos), objet: it };
  };
  const ajouter = (inv, o) => {
    if (o.stackable && o.stackKey) { const p = inv.find(x => x.stackKey === o.stackKey); if (p) { return inv.map(x => x === p ? { ...x, qty: (x.qty || 1) + o.qty } : x); } }
    return inv.concat([o]);
  };
  const rep = nom => ({ inventory: S.persos[nom].inv, revision: S.persos[nom].rev, capacite: S.persos[nom].cap });
  S.rpc = (moi, fn, p) => {
    S.appels.push({ moi, fn, p });
    const P = S.persos;
    if (fn === 'inventaire_abandonner') {
      const r = sortir(P[moi].inv, p.p_index, p.p_signature, p.p_qte || 1); if (!r.ok) return r;
      let pile = r.objet.stackable ? S.sol.find(s => s.stackKey === r.objet.stackKey) : null;
      if (pile) pile.qty += r.objet.qty; else { pile = { ...r.objet, id: 'objet-abandonne-' + (++S.n) }; S.sol.push(pile); }
      ecrire(moi, r.inventory);
      return { ok: true, objet: r.objet, objet_id: pile.id, qte: p.p_qte || 1, sol_qte: pile.qty || 1, ...rep(moi) };
    }
    if (fn === 'objet_abandonne_ramasser') {
      const k = S.sol.findIndex(s => s.id === p.p_id); if (k < 0) return { ok: false, raison: 'objet_disparu' };
      const o = S.sol[k], dispo = o.stackable ? o.qty : 1, place = Math.max(0, P[moi].cap - unites(P[moi].inv));
      const q = p.p_qte == null ? dispo : p.p_qte;
      if (q < 1 || q > dispo) return { ok: false, raison: 'quantite_invalide', dispo, place };
      if (q > place) return { ok: false, raison: place === 0 ? 'inventaire_plein' : 'place_insuffisante', place, dispo, capacite: P[moi].cap };
      const pris = { ...o, qty: q }; delete pris.id;
      if (q < dispo) o.qty -= q; else S.sol.splice(k, 1);
      ecrire(moi, ajouter(P[moi].inv, pris));
      return { ok: true, objet: pris, qte: q, reste: dispo - q, place: P[moi].cap - unites(P[moi].inv), ...rep(moi) };
    }
    if (fn === 'inventaire_donner') {
      const d = p.p_destinataire; if (!P[d]) return { ok: false, raison: 'destinataire_introuvable' };
      const r = sortir(P[moi].inv, p.p_index, p.p_signature, p.p_qte || 1); if (!r.ok) return r;
      const place = Math.max(0, P[d].cap - unites(P[d].inv) - unites(S.recus.filter(x => x.dest === d).map(x => x.objet)));
      const u = Math.max(1, unites([r.objet]));
      if (u > place) return { ok: false, raison: 'destinataire_plein', place, destinataire: d, demande: u };
      S.recus.push({ id: 'objet-recu-' + (++S.n), token: 'jeton-' + S.n, dest: d, exp: moi, objet: r.objet });
      ecrire(moi, r.inventory); perso(d);
      return { ok: true, objet: r.objet, ...rep(moi) };
    }
    if (fn === 'inventaire_reception_etat') return { ok: true, contrat: 1, inventory: P[moi].inv, revision: P[moi].rev, capacite: P[moi].cap, place: Math.max(0, P[moi].cap - unites(P[moi].inv)) };
    if (fn === 'inventaire_reclamer_livraison') {
      const k = S.recus.findIndex(x => x.id === p.p_id && x.dest === moi); if (k < 0) return { ok: false, raison: 'livraison_absente' };
      if (p.p_revision !== P[moi].rev) return { ok: false, raison: 'inventaire_perime', revision: P[moi].rev };
      const l = S.recus.splice(k, 1)[0];
      P[moi].inv = ajouter(P[moi].inv, l.objet); P[moi].rev++; salle();
      return { ok: true, contrat: 1, rejeu: false, inventory: P[moi].inv, revision: P[moi].rev, objet: l.objet, expediteur: l.exp };
    }
    if (fn === 'presents_ici') {
      const autre = moi === 'Tom Tom' ? 'Arnie' : 'Tom Tom';
      return { ok: true, presents: [{ name: autre, connecte: true, groupe: 'g1', est_chef: autre === 'Tom Tom', mon_groupe: true, groupe_libelle: 'Groupe Tom Tom' }],
               moi: { masque: false, groupe: 'g1', est_chef: moi === 'Tom Tom', groupe_libelle: 'Groupe Tom Tom' } };
    }
    return null;
  };
  S.get = (moi, table, filtre) => {
    if (table === 'objets_abandonnes') return S.sol.map(o => ({ data: JSON.stringify(o) }));
    if (table === 'objets_recus') return S.recus.filter(x => x.dest === moi).map(x => ({ id: x.id, reception_token: x.token }));
    return [];
  };
  return S;
}

async function avecDeuxJoueurs(fn) {
  const serveurHttp = http.createServer((req, res) => { res.setHeader('Content-Type', 'text/html; charset=utf-8'); res.end(PAGE); });
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'hg-inventaire-')); let nav, browser;
  const S = serveurNeuf();
  try {
    await new Promise((r, j) => { serveurHttp.once('error', j); serveurHttp.listen(0, '127.0.0.1', r); });
    nav = await lancerChromium({ executable: process.env.HG_CHROMIUM || ['/usr/bin/chromium', '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable'].find(p => fs.existsSync(p)), profil });
    browser = await chromium.connectOverCDP('http://127.0.0.1:' + nav.port);
    const ctx = browser.contexts()[0], pages = {};
    for (const nom of ['Tom Tom', 'Arnie']) {
      const page = await ctx.newPage(); await page.setViewportSize({ width: 390, height: 800 });
      page.on('pageerror', e => { S.erreurs = (S.erreurs || []).concat(nom + ' : ' + e.message); });
      await page.exposeFunction('__serveurRpc', (f, p) => JSON.stringify(S.rpc(nom, f, JSON.parse(p))));
      await page.exposeFunction('__serveurGet', (t, f) => JSON.stringify(S.get(nom, t, f)));
      await page.goto('http://127.0.0.1:' + serveurHttp.address().port);
      await page.addScriptTag({ content: `
        var state = { country: 'soviet', currentCity: 'ville_b', currentBuilding: 'zone-production', currentRoom: 'foret_vue_2',
                      char: { name: ${JSON.stringify(nom)} }, inventory: ${JSON.stringify(S.persos[nom].inv)}, pa: 30 };
        var COUNTRIES = { soviet: { col: '#cc3333', cur: 'RB' } };
        window.__toasts = []; window.__journal = [];
        function showToast(t, m) { window.__toasts.push(t + ' — ' + m); }
        function addJournalEntry(t) { window.__journal.push(t); } function addExternalEvent() {} function updateUI() {}
        function rpAuthUid() { return 'uid-' + state.char.name; } function rpAuthJeton() { return 'jeton'; }
        function resumeFortune() { return { liquide: 0, comptes: 0, placements: 0, poches: 0, arg: 0, ecart: 0 }; }
        function encodePnjSafe(o) { return encodeURIComponent(JSON.stringify(o)).replace(/'/g, '%27'); }
        function escapeHtmlText(t) { return String(t).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]); }
        function openSelfView() {} function openPnjModal() {}
        async function sbTransportRpc(fn, params) { return { etat: 'ok', donnees: JSON.parse(await window.__serveurRpc(fn, JSON.stringify(params || {}))) }; }
        async function sbGet(table, filtre) { return JSON.parse(await window.__serveurGet(table, filtre || '')); }
        async function sbGroupePjLire() { return null; }
      ` });
      await page.addScriptTag({ content: CODE });
      await page.addScriptTag({ content: lire('plateau-multijoueur.js') });
      await page.addScriptTag({ content: lire('plateau-temps-reel.js') });
      await page.evaluate(async () => { renderInventory(); await verifierObjetsRecus(); await chargerVraisJoueursPresents(); await chargerObjetsAbandonnesDansPiece(); });
      pages[nom] = page; S.pages[nom] = page;
    }
    await fn(pages, S);
    assert.deepEqual(S.erreurs || [], [], 'aucune erreur JavaScript');
  } finally {
    if (browser) await browser.close(); if (nav) await nav.arreter(); serveurHttp.closeAllConnections(); await new Promise(r => serveurHttp.close(r)); fs.rmSync(profil, { recursive: true, force: true });
  }
}
const texte = (page, sel) => page.evaluate(s => Array.from(document.querySelectorAll(s)).map(e => e.innerText.replace(/\s+/g, ' ').trim()).join(' | '), sel);
// Ce que montre la fenêtre Inventaire : affichée, on la lit ; sinon on lit le rendu qu'elle afficherait à l'ouverture.
const ongletBois = page => page.evaluate(() => {
  let racine = fenetreInventaireAffichee() ? document.getElementById('postes-body') : null;
  if (!racine) { racine = document.createElement('div'); racine.innerHTML = htmlFenetreInventaire(); }
  return Array.from(racine.querySelectorAll('.hg-inventaire-nom')).map(e => e.textContent).find(t => /^Bois/.test(t)) || '';
});
const solTexte = page => texte(page, '.objet-abandonne-card .person-name');
async function attendre(f, msg, delai = 4000) {
  const t0 = Date.now(); let v;
  while (Date.now() - t0 < delai) { v = await f(); if (v) return v; await new Promise(r => setTimeout(r, 60)); }
  assert.fail(msg + ' (dernière valeur : ' + JSON.stringify(v) + ')');
}

test('Tom Tom dépose 10 bois depuis sa fiche : son stock baisse aussitôt, la pile apparaît chez lui et chez Arnie ; Arnie ramasse ce qui tient, la pile diminue chez Tom Tom', async () => {
  await avecDeuxJoueurs(async (P, S) => {
    const tom = P['Tom Tom'], arnie = P['Arnie'];
    assert.equal(await ongletBois(tom), 'Bois × 30');
    // Le bouton « Déposer » de la fiche ouvre la fenêtre de quantité (plus une unité par clic).
    await tom.evaluate(() => { ouvrirFenetreInventaire(); Array.from(document.querySelectorAll('.hg-inventaire-ligne')).find(l => /Bois/.test(l.textContent)).querySelector('.hg-inventaire-deposer').click(); });
    assert.match(await texte(tom, '#postes-body'), /Vous avez 30 × Bois\. Combien voulez-vous en déposer ici \?/);
    assert.match(await texte(tom, '#postes-body'), /Tout \(30\)/);
    await tom.fill('#hg-quantite', '31'); await tom.click('#hg-quantite-ok');
    assert.match(await texte(tom, '#hg-quantite-erreur'), /entre 1 et 30/);
    await tom.fill('#hg-quantite', '10'); await tom.click('#hg-quantite-ok');
    await attendre(async () => (await ongletBois(tom)) === 'Bois × 20', 'stock de Tom Tom après dépôt (fiche ouverte, sans recharger)');
    assert.equal(S.appels.find(a => a.fn === 'inventaire_abandonner').p.p_qte, 10);
    await attendre(async () => (await solTexte(tom)) === 'Bois × 10', 'pile au sol chez Tom Tom');
    await attendre(async () => (await solTexte(arnie)) === 'Bois × 10', 'pile au sol chez Arnie, par le seul signal de la pièce');
    // Arnie porte 95 unités (capacité 100) : la fenêtre plafonne à 5 et le dit.
    await arnie.click('.objet-abandonne-card button');
    const corps = await texte(arnie, '#postes-body');
    assert.match(corps, /Il y a 10 × Bois au sol/); assert.match(corps, /peut encore accueillir 5 unité\(s\) \(capacité : 100\)/); assert.match(corps, /Tout \(5\)/);
    await arnie.click('#hg-quantite-tout'); await arnie.click('#hg-quantite-ok');
    await attendre(async () => (await ongletBois(arnie)) === 'Bois × 95', 'stock d’Arnie après ramassage');
    await attendre(async () => (await solTexte(tom)) === 'Bois × 5', 'la pile diminue chez Tom Tom sans qu’il bouge');
    // Inventaire plein : la fenêtre l'explique et n'offre que « Fermer » (jamais d'action sans issue).
    await arnie.click('.objet-abandonne-card button');
    assert.match(await texte(arnie, '#postes-body'), /Votre inventaire est plein\. Déposez ou donnez quelque chose/);
    assert.equal(await arnie.evaluate(() => !!document.getElementById('hg-quantite')), false);
    await arnie.click('#postes-body button');
    assert.equal(S.persos['Arnie'].inv.find(o => o.stackKey === 'bois').qty, 95);
  });
});

test('donner entre chef et membre (deux sens) : « Donner » → « Un objet » mène au don entre joueurs, quantité au choix, réception en direct ; capacité du destinataire', async () => {
  await avecDeuxJoueurs(async (P, S) => {
    const tom = P['Tom Tom'], arnie = P['Arnie'];
    const enc = nom => encodeURIComponent(JSON.stringify({ name: nom, role: 'Joueur', isPJ: true }));
    // Membre → chef : Arnie donne 5 bois à Tom Tom.
    await arnie.evaluate(e => ouvrirDonPnjChoix(e), enc('Tom Tom'));
    const choix = await texte(arnie, '#postes-body');
    assert.doesNotMatch(choix, /n'est pas à votre service/); assert.match(choix, /arrive aussitôt dans son inventaire/);
    await arnie.evaluate(() => Array.from(document.querySelectorAll('#postes-body button')).find(b => /Un objet/.test(b.textContent)).click());
    assert.match(await texte(arnie, '#postes-modal-title'), /Donner un objet à Tom Tom/);
    await arnie.evaluate(() => Array.from(document.querySelectorAll('.hg-don-objet')).find(b => /Bois/.test(b.textContent)).click());
    assert.match(await texte(arnie, '#postes-body'), /Vous avez 90 × Bois\. Combien voulez-vous en donner à Tom Tom \?/);
    await arnie.fill('#hg-quantite', '5'); await arnie.click('#hg-quantite-ok');
    const appel = S.appels.find(a => a.fn === 'inventaire_donner');
    assert.equal(appel.p.p_destinataire, 'Tom Tom'); assert.equal(appel.p.p_qte, 5);
    await attendre(async () => (await ongletBois(arnie)) === 'Bois × 85', 'stock d’Arnie après le don');
    await attendre(async () => (await ongletBois(tom)) === 'Bois × 35', 'Tom Tom reçoit en direct (signal du personnage)');
    assert.ok((await tom.evaluate(() => window.__toasts)).some(t => /Arnie vous a donné/.test(t)));
    // Chef → membre : Tom Tom donne sa hache (objet unique : pas de fenêtre de quantité).
    await tom.evaluate(e => ouvrirDonPnjChoix(e), enc('Arnie'));
    await tom.evaluate(() => Array.from(document.querySelectorAll('#postes-body button')).find(b => /Un objet/.test(b.textContent)).click());
    await tom.evaluate(() => Array.from(document.querySelectorAll('.hg-don-objet')).find(b => /Hache/.test(b.textContent)).click());
    await attendre(async () => (await arnie.evaluate(() => state.inventory.some(o => o.name === 'Hache'))), 'Arnie reçoit la hache en direct');
    // Capacité : Arnie porte 91 unités ; Tom Tom veut lui donner 12 bois → refus nommé, rien ne bouge.
    await tom.evaluate(e => ouvrirDonPnjChoix(e), enc('Arnie'));
    await tom.evaluate(() => Array.from(document.querySelectorAll('#postes-body button')).find(b => /Un objet/.test(b.textContent)).click());
    await tom.evaluate(() => Array.from(document.querySelectorAll('.hg-don-objet')).find(b => /Bois/.test(b.textContent)).click());
    await tom.fill('#hg-quantite', '12'); await tom.click('#hg-quantite-ok');
    await attendre(async () => /Arnie ne peut recevoir que 9 unité\(s\) de plus/.test(await texte(tom, '#hg-quantite-erreur')), 'message de place du destinataire');
    assert.equal(await ongletBois(tom), 'Bois × 35');
  });
});

test('capacité réglée par le MJ : la nouvelle capacité arrive en direct dans le navigateur et sert aux plafonds', async () => {
  await avecDeuxJoueurs(async (P, S) => {
    const arnie = P['Arnie'];
    assert.equal(await arnie.evaluate(() => capaciteInventaire()), 100);
    S.persos['Arnie'].cap = 120;
    await arnie.evaluate(() => window.RPTempsReel.traiterMessage({ event: 'postgres_changes', topic: 'realtime:hg-personnage', payload: { data: { record: { version: 99 } } } }));
    await attendre(() => arnie.evaluate(() => capaciteInventaire() === 120 && placeInventaireLibre() === 25), 'capacité 120 adoptée');
  });
});
