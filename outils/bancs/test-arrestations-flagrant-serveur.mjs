// Garde du 03/11/2026 : les arrestations en flagrant délit sont décidées par le serveur.
// L'écran n'appelle plus les portes « sur soi » (fermées en base) et ne tire plus aucun jet
// d'arrestation : il appelle les portes serveur et adopte leur verdict.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const lire = f => readFileSync(new URL('../../' + f, import.meta.url), 'utf8');
const fichiers = ['plateau-justice-economie.js', 'plateau-communication.js', 'plateau-politique.js',
                  'plateau-actions-illegales-rumeurs.js', 'supabase.js'];
const sans_commentaires = src => src.split('\n').filter(l => !l.trim().startsWith('//')).join('\n');

test('aucun appel aux portes de détention « sur soi »', () => {
  for (const f of fichiers) {
    const src = sans_commentaires(lire(f));
    assert.ok(!/sbRpc\(\s*'detention_ouvrir_soi'/.test(src), f + ' appelle detention_ouvrir_soi');
    assert.ok(!/sbRpc\(\s*'detention_prolonger_soi'/.test(src), f + ' appelle detention_prolonger_soi');
  }
});

test('les arrestations passent par les portes serveur', () => {
  const justice = lire('plateau-justice-economie.js');
  const politique = lire('plateau-politique.js');
  assert.match(justice, /sbRpc\('arrestation_flagrant_choisir'/);
  // 03/11 : patrouille et detachement joues par le deplacement serveur (navigation_interieure).
  assert.ok(!/sbRpc\('couvre_feu_patrouille'/.test(politique));
  assert.ok(!/sbRpc\('militaire_detachement_arrestation'/.test(politique));
  assert.match(lire('plateau-navigation.js'), /r\.arrestation&&r\.arrestation\.ok===true/);
  assert.match(lire('plateau-communication.js'), /adopterArrestationServeur\(res\.arrestation\)/);
  assert.match(lire('plateau-actions-illegales-rumeurs.js'), /placerAuQHS\(verdict\.arrestation\)/);
});

test('plus de jet d’arrestation à l’écran pour la corruption, la fuite et la résistance', () => {
  const justice = sans_commentaires(lire('plateau-justice-economie.js'));
  for (const nom of ['tenterCorruptionArrestation', 'tenterFuite', 'tenterResistance', 'procederArrestation']) {
    const m = justice.match(new RegExp('function ' + nom + '\\([^)]*\\) \\{([^\\n]*)'));
    assert.ok(m && /choisirFlagrantDelit\(/.test(m[1]), nom + ' doit déléguer au serveur');
  }
});
