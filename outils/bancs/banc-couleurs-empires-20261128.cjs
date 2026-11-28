// Banc statique des couleurs d'empires (doctrine de Fred, 28/11/2026 : 4 empires, 4 ambiances).
// El Estado passe au vert olive militaire et or doux, Al-Khalija au brun chaud, bronze et or (turquoise secondaire :
// barre des PA et onglet actif du journal). Républia et Sovarka ne changent pas. Aucun appel distant.
const test = require('node:test'), assert = require('node:assert'), fs = require('node:fs'), path = require('node:path');
const R = path.resolve(__dirname, '../..');
const css = fs.readFileSync(path.join(R, 'style.css'), 'utf8');
const sansCommentaires = css.replace(/\/\*[\s\S]*?\*\//g, '');

function variables(selecteur) {
  const blocs = [...sansCommentaires.matchAll(new RegExp(selecteur.replace(/[.]/g, '\\.') + '\\s*\\{([^}]*)\\}', 'g'))];
  assert.strictEqual(blocs.length, 1, selecteur + ' : un seul bloc de variables attendu');
  const v = {};
  for (const m of blocs[0][1].matchAll(/(--[a-z0-9-]+)\s*:\s*([^;]+);/gi)) v[m[1]] = m[2].trim().toLowerCase();
  return v;
}
const lister = s => Object.fromEntries(s.split(';').filter(Boolean).map(x => x.split(':')).map(([k, v]) => [k, v.toLowerCase()]));

const NARCO = lister('--bg:#1a1d16;--bg2:#1c2019;--bg3:#232820;--bg4:#2a3023;--border:#504c34;--border2:#3a3a28;--text:#ece6cc;--text2:#c8c0a0;--text3:#949070;--text4:#686650;--text5:#44442f;--gold:#d9b86a;--gold-light:#f0cd7f;--gold-dark:#8f7a3e;--gold-dim:#3a3420;--accent:#d9b86a;--accent2:#43492d');
const KHALIJA = lister('--bg:#24180f;--bg2:#2b1e15;--bg3:#34241a;--bg4:#3e2c1b;--border:#704827;--border2:#4e321c;--text:#f5e8cc;--text2:#d8bf96;--text3:#a08868;--text4:#6e5a44;--text5:#463626;--gold:#e0b25c;--gold-light:#f3d58a;--gold-dark:#8a5a24;--gold-dim:#3e2a14;--accent:#e0b25c;--accent2:#6f451b');
// Valeurs de origin/main (99e2d2f7), à ne pas toucher.
const REPUBLIA = lister('--bg:#0a0a07;--bg2:#0d0b05;--bg3:#121005;--bg4:#1a1508;--border:#2a2010;--border2:#1a1810;--text:#f0ead6;--text2:#c0b090;--text3:#8a8060;--text4:#6a6050;--text5:#3a3020;--gold:#C9A84C;--gold-light:#E8C97A;--gold-dark:#8a6a20;--gold-dim:#3a2a10;--accent:#C9A84C;--accent2:#8a6a20');
const SOVARKA = lister('--bg:#1a1e22;--bg2:#1e2428;--bg3:#22282e;--bg4:#262e34;--border:#3a4450;--border2:#2a3240;--text:#d8dcd8;--text2:#9aa09a;--text3:#606860;--text4:#404840;--text5:#283028;--gold:#9a2020;--gold-light:#c02828;--gold-dark:#6a1010;--gold-dim:#2a0808;--accent:#9a2020;--accent2:#6a1010');

test('El Estado : exactement les valeurs données par Fred', () => assert.deepStrictEqual(variables('body.empire-narco'), NARCO));
test('Al-Khalija : exactement les valeurs données par Fred', () => assert.deepStrictEqual(variables('body.empire-khalija'), KHALIJA));
test('Républia et Sovarka inchangés', () => {
  assert.deepStrictEqual(variables('body.empire-republic'), REPUBLIA);
  assert.deepStrictEqual(variables('body.empire-soviet'), SOVARKA);
});
test('Al-Khalija : turquoise secondaire sur la barre des PA et l’onglet actif du journal, et nulle part ailleurs', () => {
  assert.match(sansCommentaires, /body\.empire-khalija #hg-jauge-pa \.hg-jauge-barre\{background:#4f9594\}/);
  assert.match(sansCommentaires, /body\.empire-khalija \.hg-chron-onglets button\[aria-selected="true"\]\{background:#1a332c;border-color:#4f9594;[^}]*\}/);
  const regles = sansCommentaires.match(/body\.empire-(narco|khalija)[^{]*\{/g);
  assert.deepStrictEqual(regles.map(r => r.trim()), ['body.empire-narco {', 'body.empire-khalija {',
    'body.empire-khalija #hg-jauge-pa .hg-jauge-barre{', 'body.empire-khalija .hg-chron-onglets button[aria-selected="true"]{']);
});
test('style.css : accolades équilibrées', () => {
  let p = 0;
  for (const c of sansCommentaires) { if (c === '{') p++; else if (c === '}') { p--; assert.ok(p >= 0, 'accolade fermante en trop'); } }
  assert.strictEqual(p, 0);
});
test('plateau.html recharge la feuille (version de cache)', () => {
  assert.match(fs.readFileSync(path.join(R, 'plateau.html'), 'utf8'), /style\.css\?v=[^"]*couleurs-empires-20261128/);
});
