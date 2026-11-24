'use strict';
// Mission « Purge » (Fred, 24/11/2026), point H.5 : Matveï Rybakov (Krasnov) est le PÈRE de Prokhor Rybakov (douanes de
// Novomirsk), et non plus son frère aîné. Corrigé à la source : documents de game design (points 28 et 37), fiches DeepSeek,
// réaction des habitants, complément dérivé. Aucun « frère » ne doit revenir entre eux.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const R = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(R, f), 'utf8');
test('H.5 — Matveï père de Prokhor, partout', async () => {
  const { TOUS_PROFILS } = await import(path.join(R, 'api/_pnj-profils.js'));
  const m = TOUS_PROFILS.matvei_rybakov, p = TOUS_PROFILS.sovarka_inspecteur_prokhor_rybakov;
  assert.match(m.caractere, /tu es le père de Prokhor Rybakov/);
  assert.match(m.caractere, /« Mon fils, il fouille des valises toute la journée\./);
  assert.match(p.caractere, /TU ES LE FILS DE MATVEÏ RYBAKOV/);
  assert.match(p.caractere, /nouvelles de ton père Matveï/);
  for (const t of [m.caractere, m.savoir, p.caractere]) assert.doesNotMatch(t, /frère/i);
  assert.match(lire('api/_reaction-habitant.js'), /Tu es le père de Prokhor Rybakov/);
  assert.match(lire('api/_pnj-sovarka.js'), /TON PÈRE, Matveï Rybakov/);
  const gd = lire('GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md');
  assert.match(gd, /28\. \*\*Matveï Rybakov\*\*[^\n]*\*\*père\*\* de \*\*Prokhor Rybakov\*\*/);
  assert.match(gd, /\*\*fils\*\* de Matveï Rybakov/);
  for (const f of ['GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md', 'GAME-DESIGN-NOVOMIRSK.md', 'api/_pnj-personnalites.js', 'api/_reaction-habitant.js', 'api/_pnj-sovarka.js'])
    assert.doesNotMatch(lire(f), /frère (aîné|cadet) (de|DE) (\*\*)?(Prokhor|Matveï|MATVEÏ)/, f);
});
