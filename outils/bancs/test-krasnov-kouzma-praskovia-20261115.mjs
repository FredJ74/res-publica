// Praskovia et Kouzma (Fred, 15/11/2026) : histoire, église, portraits, rôles référent + social.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { TOUS_PROFILS } from '../../api/_pnj-profils.js';
import { SCENES_PNJ } from '../../api/_pnj-scenes-generes.js';
import { NON_FONCTIONNAIRES } from '../../api/_pnj-fonctionnaires-sovarka.js';
const read = p => fs.readFileSync(new URL('../../' + p, import.meta.url), 'utf8');

test('Église et tserkovny dom : Kouzma présent, noms de Fred', () => {
  const eglise = SCENES_PNJ[JSON.stringify(['soviet', 'ville_b', 'kolkhoze-spirituel', 'grange_sainte'])];
  assert.equal(eglise.batiment, 'Église de la Sainte-Moisson-Commune');
  assert.deepEqual(eglise.personnes, ['Kouzma Lapchine']);
  const maison = SCENES_PNJ[JSON.stringify(['soviet', 'ville_b', 'maison-krasnov-eglise', 'piece_maison'])];
  assert.equal(maison.batiment, 'Tserkovny dom du batiouchka');
});

test('Histoire d’amour dans les fiches de trinquer et de dialogue', () => {
  const t = read('api/_reaction-habitant.js');
  assert.match(t, /'Kouzma Lapchine': "Tu es Kouzma Lapchine, le batiouchka[^\n]*Praskovia Pakhomova[^\n]*juste au-dessus/);
  assert.match(t, /'Praskovia Pakhomova': "[^\n]*jamais mariée[^\n]*remercies le ciel/);
  for (const id of ['kouzma_lapchine', 'praskovia_pakhomova']) {
    const p = TOUS_PROFILS[id];
    assert.ok(p && /HISTOIRE/.test(p.caractere) && /règles réelles/.test(p.savoir), id);
  }
  assert.match(TOUS_PROFILS.kouzma_lapchine.savoir, /Donner à l'Église/);
  assert.match(TOUS_PROFILS.praskovia_pakhomova.savoir, /caisse commune/);
});

test('Référents ET sociaux, hors fonctionnaires ; portraits raccordés', () => {
  assert.match(read('plateau-pnj.js'), /'kouzma_lapchine', 'praskovia_pakhomova'\n\];/);
  const s = read('plateau-social-pnj.js');
  assert.match(s, /'ville_b\|kolkhoze-spirituel\|grange_sainte':\s+'kouzma_lapchine'/);
  assert.match(s, /'ville_b\|maison-krasnov-eglise\|piece_maison':\s+'kouzma_lapchine'/);
  assert.match(s, /'ville_b\|maison-krasnov-bleue\|piece_maison':\s+'praskovia_pakhomova'/);
  const m = read('migrations/20261115120500_krasnov_kouzma_praskovia_roles.sql');
  assert.match(m, /INSERT INTO public\.pnj_referents/);
  assert.match(m, /INSERT INTO public\.pnj_social_jalons_regles/);
  assert.ok(NON_FONCTIONNAIRES.has('kouzma_lapchine') && NON_FONCTIONNAIRES.has('praskovia_pakhomova'));
  const d = read('data.js');
  assert.match(d, /photoUrl: 'images\/Sovarka\/Krasnov\/Kouzma\.webp'/);
  assert.match(d, /'images\/Sovarka\/Krasnov\/Krasnov_maison_bleue_interieur\.webp', 'images\/Sovarka\/Krasnov\/Praskovia\.webp'\]/);
  for (const f of ['Kouzma', 'Praskovia']) assert.ok(fs.existsSync(new URL('../../images/Sovarka/Krasnov/' + f + '.webp', import.meta.url)));
});
