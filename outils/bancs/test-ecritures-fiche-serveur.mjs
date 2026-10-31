// GARDE : UNE FONCTION SERVEUR N'ÉCRIT JAMAIS LA FICHE PAR LA VUE DE L'ÉCRAN (30/10/2026).
//
// La vue `personnages` est la porte de l'écran : sa garde corrige en silence l'argent et les
// champs protégés pour tout appel joueur. Une fonction serveur qui écrivait par elle voyait son
// effet annulé sans erreur (150 000 FR de Jean Jaaj perdus au retrait Helvetia). Depuis
// 20261030210000, toutes les fonctions serveur écrivent `personnages_donnees`, et la vue refuse
// bruyamment dans une RPC (20261030211000). Ce test empêche toute nouvelle migration de
// réintroduire une écriture par la vue (UPDATE ou INSERT sur `personnages`).
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';

const DOSSIER = new URL('../../migrations/', import.meta.url);
const DEPUIS = '20261030210000';   // migrations antérieures : historique, nettoyé par celle-ci
const ECRITURE_VUE = /\b(update|insert\s+into)\s+(public\.)?"?personnages"?(?![_a-z0-9])/gi;

function sansCommentaires(sql) {
  return sql.split('\n').map((l) => l.replace(/--.*$/, '')).join('\n');
}

export function ecrituresParLaVue(sql) {
  return [...sansCommentaires(sql).matchAll(ECRITURE_VUE)].map((m) => m[0]);
}

test('le détecteur reconnaît une écriture par la vue, pas par la table', () => {
  assert.deepEqual(ecrituresParLaVue('UPDATE public.personnages SET liquide = 1;'), ['UPDATE public.personnages']);
  assert.deepEqual(ecrituresParLaVue('update personnages\n set arg = 0;'), ['update personnages']);
  assert.deepEqual(ecrituresParLaVue('UPDATE public.personnages_donnees SET liquide = 1;'), []);
  assert.deepEqual(ecrituresParLaVue("-- UPDATE public.personnages dans un commentaire"), []);
  assert.deepEqual(ecrituresParLaVue("regexp_replace(d, '\\mupdate\\s+(public\\.)?personnages\\M', 'x')"), []);
});

test('aucune migration récente n\'écrit la fiche par la vue de l\'écran', () => {
  const fautifs = [];
  for (const nom of readdirSync(DOSSIER).filter((f) => f.endsWith('.sql') && f.slice(0, 14) >= DEPUIS).sort()) {
    const trouves = ecrituresParLaVue(readFileSync(new URL(nom, DOSSIER), 'utf8'));
    if (trouves.length) fautifs.push(nom + ' : ' + trouves.join(', '));
  }
  assert.deepEqual(fautifs, [], 'Écrire public.personnages_donnees, pas la vue personnages :\n' + fautifs.join('\n'));
});

test('les correctifs du 30/10 sont présents', () => {
  const m210 = readFileSync(new URL('../../historique/migrations-appliquees/20261030210000_argent_fonctions_serveur_table.sql', import.meta.url), 'utf8');
  const m211 = readFileSync(new URL('../../historique/migrations-appliquees/20261030211000_fiche_vue_refus_bruyant.sql', import.meta.url), 'utf8');
  assert.match(m210, /'UPDATE public\.personnages_donnees'/);
  assert.equal((m210.match(/^    \('public\./gm) || []).length, 19);
  assert.match(m211, /request\.path', true\), ''\) LIKE '\/rpc\/%'/);
  assert.match(m211, /fiche_ecriture_serveur_par_la_vue/);
});
