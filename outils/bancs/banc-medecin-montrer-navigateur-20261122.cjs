// Chromium réel, vrai plateau.html (HTML et toutes les feuilles de style, mobiles comprises) : Santé et forêt (Fred,
// 22/11/2026, GAME-DESIGN-SANTE-20261122.md), points 12, 14, 17, 18 et 22, à 1280 et à 390 px.
//  - Point 14 : jauges Santé et Moral à côté des PA, infobulle au survol (1280) et au toucher (390), texte ≥ texte courant.
//  - Points 17 et 18 : dans les quatre vues de la forêt, seulement « Couper du bois », « Retour au campement », « Se cacher » ;
//    nouveaux titres et textes ; ailleurs, « Inspecter la pièce » et « Désinstaller du matériel » restent.
//  - Point 22 : « Montrer un objet » depuis la carte d'un joueur ; la fenêtre reçue montre nom, image et description.
//  - Point 12 : « Diagnostiquer » d'un médecin (tarif libre envoyé au serveur), fenêtre du patient (prix, accepter, refuser).
// Vrais fichiers : data.js, plateau-climat.js, plateau-surveillance.js, plateau-texte-minimum.js,
// plateau-evenements-personnage.js, plateau-medecin-montrer.js ; seul le serveur (sbRpc) est simulé.
const test = require('node:test'), assert = require('node:assert/strict');
const { avecJeu, page } = require('./mobile-navigateur.cjs');

const SCRIPTS = ['data.js', 'plateau-climat.js', 'plateau-surveillance.js', 'plateau-texte-minimum.js', 'plateau-evenements-personnage.js', 'plateau-medecin-montrer.js'];
const PLANCHER = 15.2;   // 0,95 rem

async function preparer(b, o, largeur, hauteur) {
  const p = await page(b, o, largeur, hauteur);
  const erreurs = []; p.on('pageerror', e => erreurs.push(e.message));
  await p.evaluate(() => {
    window.state = { char: { name: 'Tom', career: 'doctor' }, country: 'soviet', currentCity: 'ville_b', currentBuilding: 'hopital-krasnov', currentRoom: 'accueil',
      inventory: [{ id: 'l-1', name: 'Lettre scellée', desc: 'Une lettre au sceau du Tsar.', imageUrl: 'images/militaire-trousse-secours.png', icon: 'ti-mail' }] };
    window.__appels = []; window.__toasts = []; window.__journal = [];
    window.showToast = (a, c, ok) => window.__toasts.push([a, c, !!ok]);
    window.addJournalEntry = t => window.__journal.push(t);
    window.sbRpc = async (fn, a) => {
      window.__appels.push([fn, a]);
      if (fn === 'sante_paliers_lire') return { ok: true, moral_seuil_haut: 75, moral_seuil_bas: 25, moral_mult_haut: 1.5, moral_mult_bas: 0.5 };
      if (fn === 'medecin_etat') return { ok: true, medecin: true, pa: 10, pa_diagnostic: 1, pa_soin: 2, sante_soin: 12, tarif_max: 100000, trousses: 1, monnaie: 'PSK' };
      if (fn === 'medecin_proposer') return { ok: true, id: 9, patient: a.p_patient, acte: a.p_acte, prix: a.p_prix, monnaie: 'PSK' };
      if (fn === 'medecin_repondre') return a.p_accepte ? { ok: true, statut: 'acceptee', acte: 'diagnostic', paye: 50,
        diagnostic: { sante: 40, maladies: [{ cle: 'grippe', nom: 'Grippe', medicament_nom: 'Antigrippal', traitee: false }] } } : { ok: true, statut: 'refusee' };
      if (fn === 'objet_montrer') return { ok: true, nom: a.p_nom };
      if (fn === 'medecin_propositions_lire') return { ok: true, propositions: [] };
      if (fn === 'personnage_evenements_lire') return { ok: true, evenements: [] };
      return null;
    };
    document.getElementById('r-hp').textContent = '40';
    document.getElementById('r-moral').textContent = '80';
  });
  for (const s of SCRIPTS) await p.addScriptTag({ url: o + '/' + s });
  await p.waitForFunction(() => typeof window.hgMedecinMontrerBoutonsCarte === 'function' && window.RPClimat && typeof ordresFouillerVoler === 'function');
  return { p, erreurs };
}
const taille = (p, sel) => p.evaluate(s => Array.from(document.querySelectorAll(s)).filter(e => e.offsetParent || getComputedStyle(e).position === 'fixed')
  .map(e => parseFloat(getComputedStyle(e).fontSize)), sel);
async function dansEcran(p, sel) {
  const r = await p.evaluate(s => { const e = document.querySelector(s).getBoundingClientRect(); return { l: e.left, r: e.right, t: e.top, b: e.bottom, w: innerWidth, h: innerHeight,
    deborde: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1 }; }, sel);
  assert.ok(r.l >= -0.5 && r.r <= r.w + 0.5 && r.t >= -0.5 && r.b <= r.h + 0.5, sel + ' dans l’écran ' + JSON.stringify(r));
  assert.equal(r.deborde, false, 'aucun défilement horizontal');
}

for (const [largeur, hauteur] of [[1280, 860], [390, 844]]) {
  test(`jauges Santé et Moral à ${largeur} px : à côté des PA, infobulle lisible au survol et au toucher`, async () => avecJeu(async (b, o) => {
    const { p, erreurs } = await preparer(b, o, largeur, hauteur);
    if (largeur < 1024) await p.evaluate(() => { document.body.dataset.mobilePanel = 'personnage'; });
    await p.waitForFunction(() => document.getElementById('hg-jauge-sante-val').textContent === '40');
    assert.equal(await p.locator('#hg-jauge-moral-val').innerText(), '80');
    // À côté des PA : même ligne que la boîte des PA.
    const pos = await p.evaluate(() => ['r-pa', 'hg-jauge-sante', 'hg-jauge-moral'].map(id => { const e = (id === 'r-pa' ? document.getElementById(id).parentElement : document.getElementById(id)).getBoundingClientRect(); return [Math.round(e.top), Math.round(e.left), Math.round(e.width)]; }));
    assert.equal(pos[0][0], pos[1][0]); assert.equal(pos[1][0], pos[2][0]); assert.ok(pos[0][1] < pos[1][1] && pos[1][1] < pos[2][1], JSON.stringify(pos));
    assert.ok(pos.every(x => x[2] > 30), 'trois jauges lisibles ' + JSON.stringify(pos));
    // Survol (souris) ou toucher (téléphone).
    if (largeur < 1024) await p.locator('#hg-jauge-sante').tap(); else await p.hover('#hg-jauge-sante');
    await p.waitForSelector('#hg-jauge-bulle:not([hidden])');
    assert.equal(await p.locator('#hg-jauge-bulle').innerText(), 'Santé 40 : vous perdez un peu plus de PA sous les coups. Mangez, dormez dans un lit ou consultez un médecin.');
    assert.ok((await taille(p, '#hg-jauge-bulle')).every(t => t >= PLANCHER), 'infobulle ≥ texte courant');
    if (process.env.HG_PREUVES) await p.screenshot({ path: process.env.HG_PREUVES + '/jauges-' + largeur + '.png' });
    await dansEcran(p, '#hg-jauge-bulle');
    if (largeur < 1024) await p.locator('#hg-jauge-moral').tap(); else await p.hover('#hg-jauge-moral');
    await p.waitForFunction(() => /^Moral 80 :/.test(document.getElementById('hg-jauge-bulle').textContent));
    assert.match(await p.locator('#hg-jauge-bulle').innerText(), /excellent moral\. Repas, sommeil, soins, médecin et alcool vous rendent 1,5 fois plus de Santé\./);
    await dansEcran(p, '#hg-jauge-bulle');
    if (largeur < 1024) {   // second toucher sur la même jauge : l'infobulle se referme
      await p.waitForTimeout(700); await p.locator('#hg-jauge-moral').tap();
      assert.equal(await p.locator('#hg-jauge-bulle').isHidden(), true, 'second toucher : fermée');
    }
    // Le serveur change la Santé : la jauge et l'infobulle suivent, sans calcul local.
    await p.evaluate(() => { document.getElementById('r-hp').textContent = '12'; document.getElementById('r-moral').textContent = '20'; });
    await p.waitForFunction(() => document.getElementById('hg-jauge-sante-val').textContent === '12');
    assert.equal(await p.evaluate(() => document.getElementById('hg-jauge-sante-barre').style.width), '12%');
    assert.match(await p.evaluate(() => hgSanteTexteJauge('moral', 20)), /ne vous rendent que la moitié de la Santé habituelle/);
    assert.match(await p.evaluate(() => hgSanteTexteJauge('sante', 80)), /vous perdez moins de PA/);
    // Toucher ailleurs : l'infobulle se ferme.
    await p.mouse.click(5, hauteur - 5);
    assert.equal(await p.locator('#hg-jauge-bulle').isHidden(), true);
    assert.deepEqual(erreurs, []);
  }));

  test(`forêt de Krasnov à ${largeur} px : trois actions seulement, nouveaux titres ; pièce ordinaire inchangée`, async () => avecJeu(async (b, o) => {
    const { p, erreurs } = await preparer(b, o, largeur, hauteur);
    const ordres = (bat, piece) => p.evaluate(([bat, piece]) => {
      Object.assign(state, { currentBuilding: bat, currentRoom: piece });
      const ctx = WORLD.soviet.ville_b.buildingContext[bat];
      const room = (BUILDINGS[bat] && BUILDINGS[bat].rooms && BUILDINGS[bat].rooms[piece]) || (ctx && ctx.roomsExtra && ctx.roomsExtra[piece]) || {};
      const dyn = (window.RP_ORDRES_DYNAMIQUES || []).flatMap(f => f(bat, piece, state.currentCity) || []);
      const stat = ordresDeclaresDeLaPiece(room, ctx, piece).filter(x => !dyn.some(d => d.fn === x.fn));
      return { nom: room.name, desc: room.desc, ordres: stat.concat(dyn).map(x => x.label) };
    }, [bat, piece]);
    const attendus = {
      1: ['La piste des débardeurs', 'Des souches fraîches, des grumes empilées au bord d’une piste défoncée. Les bûcherons ne sont pas loin.'],
      2: ['La coupe abandonnée', 'Des souches partout, une odeur de résine. Quelque chose a gratté l’écorce d’un bouleau, bien haut.'],
      3: ['Les grands fûts', 'La forêt se referme. Les fougères montent aux genoux, et des empreintes larges comme une assiette marquent l’humus.'],
      4: ['Le sentier d’Olga', 'Un sentier à peine tracé sous les feuilles mortes. Au loin, une odeur de feu de bois et de soupe aux choux.']
    };
    for (const n of [1, 2, 3, 4]) {
      const v = await ordres('zone-production', 'foret_vue_' + n);
      assert.deepEqual([v.nom, v.desc], attendus[n], 'vue ' + n);
      assert.deepEqual(v.ordres.sort(), ['Couper du bois', 'Retour au campement', 'Se cacher'], 'vue ' + n);
    }
    for (const piece of ['zone_recolte', 'foret_clairiere']) {
      const v = await ordres('zone-production', piece);
      assert.ok(!v.ordres.includes('Inspecter la pièce') && !v.ordres.includes('Désinstaller du matériel'), piece + ' ' + v.ordres);
    }
    const hopital = await p.evaluate(() => ordresFouillerVoler('hopital-krasnov', 'accueil').map(x => x.label));
    // Point 17 (22/11/2026, soir) : « Désinstaller du matériel » n'est plus un bouton de pièce (volet de « Inspecter la pièce »).
    assert.deepEqual(hopital, ['Inspecter la pièce', 'Se cacher'], 'pièce couverte : Inspecter et Se cacher');
    const port = await p.evaluate(() => ordresFouillerVoler('port-sainte-marie', 'quai_nord').map(x => x.label));
    assert.deepEqual(port, ['Se cacher'], 'quai : vue en plein air');
    assert.deepEqual(erreurs, []);
  }));

  test(`montrer un objet et médecin à ${largeur} px : serveur appelé, fenêtres lisibles, prix accepté ou refusé`, async () => avecJeu(async (b, o) => {
    const { p, erreurs } = await preparer(b, o, largeur, hauteur);
    // Carte d'un joueur présent (comme plateau-pnj.js, à côté de « Donner »).
    await p.evaluate(() => {
      const d = document.createElement('div'); d.id = 'carte-test';
      d.innerHTML = hgMedecinMontrerBoutonsCarte({ name: 'Arnie', isPJ: true }); document.body.appendChild(d);
    });
    assert.deepEqual((await p.locator('#carte-test button').allInnerTexts()).map(x => x.trim()), ['Diagnostiquer', 'Soigner', 'Montrer un objet']);
    assert.equal(await p.evaluate(() => hgMedecinMontrerBoutonsCarte({ name: 'X', isPJ: true, masque: true })), '', 'personne masquée : rien');
    // Montrer.
    await p.click('#carte-test .hg-montrer-objet');
    await p.waitForSelector('#hg-montrer-choix .hg-montrer-choix');
    await p.click('#hg-montrer-choix .hg-montrer-choix');
    await p.waitForFunction(() => window.__appels.some(a => a[0] === 'objet_montrer'));
    assert.deepEqual(await p.evaluate(() => window.__appels.find(a => a[0] === 'objet_montrer')[1]), { p_destinataire: 'Arnie', p_index: 0, p_nom: 'Lettre scellée' });
    assert.equal(await p.locator('#hg-montrer-choix').count(), 0, 'fenêtre de choix fermée');
    // Réception chez l'autre joueur (journal d'événements du serveur).
    await p.evaluate(() => window.rpEvenementsPersonnageGestionnaires.objet_montre({ cle: 'objet_montre', params: { de: 'Tom', nom: 'Lettre scellée',
      image: 'images/militaire-trousse-secours.png', desc: 'Une lettre au sceau du Tsar.<img src=x onerror="window.__xss=1">' } }));
    await p.waitForSelector('#hg-objet-montre .hg-montrer-image');
    assert.equal(await p.locator('#hg-objet-montre .modal-title').innerText(), 'Tom vous montre un objet');
    assert.equal(await p.locator('#hg-objet-montre .hg-montrer-nom').innerText(), 'Lettre scellée');
    assert.match(await p.locator('#hg-objet-montre .hg-montrer-desc').innerText(), /^Une lettre au sceau du Tsar\./);
    assert.equal(await p.evaluate(() => window.__xss), undefined, 'description affichée en texte');
    await p.waitForFunction(() => document.querySelector('#hg-objet-montre .hg-montrer-image').naturalWidth > 0);
    assert.ok((await taille(p, '#hg-objet-montre .hg-sante-texte')).every(t => t >= PLANCHER));
    await dansEcran(p, '#hg-objet-montre .modal-box');
    await p.click('#hg-objet-montre .cpj-touche');
    // Médecin : diagnostic à 50 PSK.
    await p.click('#carte-test [data-acte="diagnostic"]');
    await p.waitForSelector('#hg-medecin-acte .hg-medecin-prix');
    assert.match(await p.locator('#hg-medecin-acte').innerText(), /Coût pour vous : 1 PA, seulement si le patient accepte/);
    await p.fill('#hg-medecin-acte .hg-medecin-prix', '50');
    await p.click('#hg-medecin-acte [data-proposer]');
    await p.waitForFunction(() => window.__appels.some(a => a[0] === 'medecin_proposer'));
    assert.deepEqual(await p.evaluate(() => window.__appels.find(a => a[0] === 'medecin_proposer')[1]), { p_patient: 'Arnie', p_acte: 'diagnostic', p_prix: 50 });
    // Patient : la fenêtre montre le prix ; refus, puis nouvelle proposition acceptée.
    const proposer = id => p.evaluate(id => window.rpEvenementsPersonnageGestionnaires.medecin_proposition({ cle: 'medecin_proposition',
      params: { id, medecin: 'Docteur Vlad', acte: 'diagnostic', prix: 50, monnaie: 'PSK' } }), id);
    await proposer(9);
    await p.waitForSelector('#hg-medecin-proposition-9');
    assert.match(await p.locator('#hg-medecin-proposition-9').innerText(), /Prix demandé : 50 PSK\.[\s\S]*Rien n’est prélevé sans votre accord\./);
    assert.ok((await taille(p, '#hg-medecin-proposition-9 .hg-sante-texte, #hg-medecin-proposition-9 .cpj-touche')).every(t => t >= PLANCHER));
    await dansEcran(p, '#hg-medecin-proposition-9 .modal-box');
    await p.click('#hg-medecin-proposition-9 [data-refuser]');
    await p.waitForFunction(() => window.__appels.some(a => a[0] === 'medecin_repondre'));
    assert.deepEqual(await p.evaluate(() => window.__appels.find(a => a[0] === 'medecin_repondre')[1]), { p_proposition: 9, p_accepte: false });
    await proposer(10);
    await p.click('#hg-medecin-proposition-10 [data-accepter]');
    await p.waitForSelector('#hg-medecin-diagnostic');
    assert.match(await p.locator('#hg-medecin-diagnostic').innerText(), /Santé : 40[\s\S]*Grippe — se soigne avec : Antigrippal/);
    assert.deepEqual(await p.evaluate(() => window.__appels.filter(a => a[0] === 'medecin_repondre').pop()[1]), { p_proposition: 10, p_accepte: true });
    await proposer(10);
    assert.equal(await p.locator('#hg-medecin-proposition-10').count(), 0, 'une proposition ne s’ouvre qu’une fois');
    // Un joueur qui n'est pas médecin ne voit que « Montrer un objet ».
    assert.doesNotMatch(await p.evaluate(() => { state.char.career = 'worker'; return hgMedecinMontrerBoutonsCarte({ name: 'Arnie', isPJ: true }); }), /Diagnostiquer|Soigner/);
    assert.deepEqual(erreurs, []);
  }));
}
