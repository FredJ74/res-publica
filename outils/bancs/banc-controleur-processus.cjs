// Cycle de vie réel des sous-processus Linux du contrôleur CI, sans accès distant.
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
test('le contrôleur conserve les diagnostics et arrête son groupe sans faux succès', () => {
  const r = spawnSync('python3', [path.join(__dirname, 'test-controleur-processus.py'), '-v'],
    {encoding: 'utf8', timeout: 45000});
  assert.equal(r.error, undefined, String(r.error));
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.match(r.stderr, /Ran 7 tests/);
  assert.match(r.stderr, /\nOK\s*$/);
});
