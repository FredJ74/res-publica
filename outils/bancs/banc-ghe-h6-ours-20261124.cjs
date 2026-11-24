'use strict';
// Mission « Purge » (Fred, 24/11/2026), point H.6 : pas d'ordre « Chasser ». L'ours se rencontre au hasard en explorant
// la forêt profonde de Krasnov. Matveï Rybakov, Nina Gorbounova et le commissaire Egor Tikhonov l'expliquent avec la
// phrase de Fred (aucun PNJ « bûcheron » n'existe dans le jeu : rien à ajouter pour eux).
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const R = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(R, f), 'utf8');
const PHRASE = '« L\'ours ne se chasse pas, c\'est l\'ours qui vous chasse… »';
test('H.6 — aucun ordre « Chasser » ; la rencontre de l’ours vient de l’exploration', () => {
  for (const f of ['data.js', 'plateau-router.js', 'plateau-foret-krasnov.js']) {
    if (!fs.existsSync(path.join(R, f))) continue;
    assert.doesNotMatch(lire(f), /label:\s*['"]Chasser\b|fn:\s*['"]chasser\b|fn === ['"]chasser/, f);
  }
  assert.match(lire('migrations/20261122110000_foret_egarement_rencontre_arrivee.sql'), /sovarka_foret_rencontre_arrivee_interne/);
});
test('H.6 — Matveï, Nina et le commissaire disent la phrase de Fred', async () => {
  const { TOUS_PROFILS } = await import(path.join(R, 'api/_pnj-profils.js'));
  const texte = id => { const p = TOUS_PROFILS[id]; assert.ok(p, id); return [p.identite, p.caractere, p.savoir].join('\n'); };
  for (const id of ['matvei_rybakov', 'nina_gorbounova', 'egor_tikhonov']) {
    const t = texte(id);
    assert.ok(t.includes(PHRASE), id + ' : phrase de Fred');
    assert.match(t, /aucun ordre « Chasser »/, id);
    assert.match(t, /au hasard, en explorant la forêt profonde de Krasnov/, id);
  }
  assert.match(texte('egor_tikhonov'), /TÊTE D'OURS DE TON BUREAU/);
});
