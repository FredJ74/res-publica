// Bloc 2 (Fred, 23/11/2026, GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, points 21 à 23), vrai Chromium et vrai plateau.html
// (feuilles de style comprises, mobiles aussi) :
//  - 21 : plus de « Rapports de combat » dans le journal ; croix de fermeture en vrai bouton, grande et contrastée ; plus
//         d'entrées ni de sorties de bâtiments dans le journal ;
//  - 22 : boutons ronds du journal et du chat en bas à droite, l'un au-dessus de l'autre ; ni le journal ni le chat ouverts
//         ne recouvrent ces boutons, et les deux panneaux ne sont jamais ouverts ensemble ;
//  - 23 : dans toutes les rues, « avancer » (↑) en bas de l'image légèrement à gauche, la flèche latérale (›) tout en bas à droite.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const { avecJeu, page, R } = require('./mobile-navigateur.cjs');
const lire = f => fs.readFileSync(path.join(R, f), 'utf8');

test('21 : journal sans « Rapports de combat » ni entrées/sorties de bâtiments ; croix en vrai bouton', () => {
  const html = lire('plateau.html');
  assert.doesNotMatch(html, /onclick="ouvrirCalepinCampagne\(\)"/);
  assert.match(html, /<button type="button" id="journal-fermer" class="hg-journal-fermer" onclick="toggleJournalStore\(\)" aria-label="Fermer le journal"/);
  const nav = lire('plateau-navigation.js');
  assert.doesNotMatch(nav, /addJournalEntry\(`Vous entrez dans/);
  assert.doesNotMatch(nav, /addJournalEntry\(`Vous sortez du batiment/);
  // Le calepin des combats reste accessible par son ordre (R4 : redirection, pas de lien mort).
  assert.match(lire('plateau-router.js'), /fn === 'calepin_campagne'\) \{ ouvrirCalepinCampagne\(\); return; \}/);
  assert.match(lire('plateau-politique.js'), /async function ouvrirCalepinCampagne\(\)/);
});

test('23 : positions imposées des flèches dans toutes les rues', () => {
  const src = lire('plateau-rue-centrale.js');
  assert.match(src, /const RC_FLECHE_AVANCER_BAS = 'bottom:14px; left:42%; transform:translateX\(-50%\);';/);
  assert.match(src, /const RC_FLECHE_DROITE_BAS = 'bottom:14px; right:14px;';/);
  assert.match(src, /style: imposees\[f\.dir\] \|\| noeud\.flechesStyle\?\.\[f\.dir\] \|\| stylesParDefaut\[f\.dir\]/);
});

const rect = (p, sel) => p.evaluate(s => { const e = document.querySelector(s); if (!e) return null; const r = e.getBoundingClientRect();
  return { l: r.left, r: r.right, t: r.top, b: r.bottom, w: innerWidth, h: innerHeight, vu: getComputedStyle(e).display !== 'none' && r.width > 0 }; }, sel);
const chevauche = (a, b) => a && b && a.l < b.r - 0.5 && b.l < a.r - 0.5 && a.t < b.b - 0.5 && b.t < a.b - 0.5;

for (const [largeur, hauteur] of [[1280, 860], [390, 844]]) {
  test(`${largeur} px : boutons ronds en bas à droite, empilés ; panneaux sans chevauchement ; croix lisible`, async () => avecJeu(async (b, o) => {
    const p = await page(b, o, largeur, hauteur);
    const j = await rect(p, '#journal-open-btn'), c = await rect(p, '#hg-chat-toggle');
    assert.ok(j.vu && c.vu, 'deux boutons visibles');
    for (const x of [j, c]) { assert.ok(x.r <= x.w - 8 && x.r >= x.w - 40, 'collé à droite ' + JSON.stringify(x)); assert.ok(x.b <= x.h - 8 && x.b >= x.h - 160, 'en bas ' + JSON.stringify(x)); }
    assert.ok(j.b <= c.t + 0.5, 'journal au-dessus du chat'); assert.ok(Math.abs((j.l + j.r) / 2 - (c.l + c.r) / 2) < 2, 'même colonne');
    // Journal ouvert : ne recouvre pas les boutons ; la croix est un vrai bouton d'au moins 40 px, contrasté.
    await p.evaluate(() => { document.getElementById('journal-store').style.display = 'flex'; });
    const js = await rect(p, '#journal-store');
    assert.ok(!chevauche(js, j) && !chevauche(js, c), 'le journal laisse les boutons libres ' + JSON.stringify({ js, j, c }));
    const croix = await p.evaluate(() => { const e = document.getElementById('journal-fermer'), r = e.getBoundingClientRect(), s = getComputedStyle(e);
      return { tag: e.tagName, w: r.width, h: r.height, couleur: s.color, fond: s.backgroundColor, bord: s.borderTopWidth }; });
    assert.equal(croix.tag, 'BUTTON'); assert.ok(croix.w >= 40 && croix.h >= 40, 'croix grande ' + JSON.stringify(croix));
    assert.notEqual(croix.fond, 'rgba(0, 0, 0, 0)', 'fond contrasté'); assert.ok(parseFloat(croix.bord) >= 2, 'bord visible');
    await p.evaluate(() => { document.getElementById('journal-store').style.display = 'none'; document.getElementById('chat-piece-panel').style.display = 'flex'; });
    const cp = await rect(p, '#chat-piece-panel');
    assert.ok(!chevauche(cp, j) && !chevauche(cp, c), 'le chat laisse les boutons libres ' + JSON.stringify({ cp, j, c }));
  }));
}

test('22 : ouvrir le journal ferme le chat, ouvrir le chat ferme le journal (code)', () => {
  const html = lire('plateau.html');
  assert.match(html, /if \(!isOpen && chat && chat\.style\.display !== 'none' && typeof toggleChatPiece === 'function'\) toggleChatPiece\(\);/);
  assert.match(lire('plateau-multijoueur.js'), /if \(journal && journal\.style\.display === 'flex'\) journal\.style\.display = 'none';\n    panel\.style\.display = 'flex';/);
});

for (const [largeur, hauteur] of [[1280, 860], [390, 844]]) {
  test(`${largeur} px : flèches « avancer » et « droite » en bas de l'image`, async () => avecJeu(async (b, o) => {
    const p = await page(b, o, largeur, hauteur);
    const src = lire('plateau-rue-centrale.js');
    const av = src.match(/const RC_FLECHE_AVANCER_BAS = '([^']+)'/)[1], dr = src.match(/const RC_FLECHE_DROITE_BAS = '([^']+)'/)[1];
    const r = await p.evaluate(([av, dr]) => {
      const scene = document.createElement('div'); scene.className = 'rc-scene'; scene.style.cssText = 'position:relative;width:800px;height:450px;max-width:100%';
      scene.innerHTML = '<div class="rc-fleche" id="f-av" style="' + av + '"><i class="ti ti-arrow-up"></i></div><div class="rc-fleche" id="f-dr" style="' + dr + '"><i class="ti ti-chevron-right"></i></div>';
      document.body.prepend(scene);
      const s = scene.getBoundingClientRect(), a = document.getElementById('f-av').getBoundingClientRect(), d = document.getElementById('f-dr').getBoundingClientRect();
      return { s: { l: s.left, r: s.right, t: s.top, b: s.bottom }, a: { l: a.left, r: a.right, t: a.top, b: a.bottom }, d: { l: d.left, r: d.right, t: d.top, b: d.bottom } };
    }, [av, dr]);
    const larg = r.s.r - r.s.l, haut = r.s.b - r.s.t, cx = (r.a.l + r.a.r) / 2 - r.s.l;
    assert.ok(r.s.b - r.a.b <= 20 && r.s.b - r.a.b >= 0, '« avancer » en bas ' + JSON.stringify(r));
    assert.ok(cx < larg / 2 && cx > larg * 0.3, '« avancer » légèrement à gauche du centre ' + JSON.stringify(r));
    assert.ok(r.s.b - r.d.b <= 20 && r.s.b - r.d.b >= 0 && r.s.r - r.d.r <= 20 && r.s.r - r.d.r >= 0, '« › » tout en bas à droite ' + JSON.stringify(r));
    assert.ok(r.a.r < r.d.l, 'les deux flèches ne se chevauchent pas');
    assert.ok(haut > 100);
  }));
}
