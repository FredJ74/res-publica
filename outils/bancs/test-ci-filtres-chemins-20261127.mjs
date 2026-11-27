// Mission de nuit du 27/11/2026, étape 4 : les contrôles se lancent selon les fichiers modifiés, sans perdre en fiabilité.
// Garde-fous : un fichier partagé relance tout contrôle filtré ; chaque contrôle filtré tourne aussi chaque nuit sur main ;
// la suite « Cohérence client » et le parcours immobilier ignorent seulement les envois d'images seules.
// Les workflows qui écrivent dans le dépôt (conversions d'images) ne sont pas des contrôles : ils restent tels quels.
// Lancer : node --test outils/bancs/test-ci-filtres-chemins-20261127.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const dossier = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', '.github', 'workflows');
const PARTAGES = ['data.js', 'plateau-core.js', 'plateau-router.js', 'migrations/**', '.github/workflows/**', 'i18n/**',
  'auth.js', 'supabase.js', 'sens-saisie.js', 'style.css', 'rue-centrale.css', 'vercel.json'];
const flux = readdirSync(dossier).filter(f => f.endsWith('.yml')).map(f => ({ f, s: readFileSync(path.join(dossier, f), 'utf8') }));
const tete = s => s.split('\njobs:')[0];
const ecrivain = s => /contents: write|git push|git commit/.test(s);

test('chaque contrôle filtré par chemins est relancé par tous les fichiers partagés et tourne chaque nuit', () => {
  const filtres = flux.filter(({ s }) => !ecrivain(s) && /^\s+paths:/m.test(tete(s)));
  assert.ok(filtres.length >= 140, 'contrôles filtrés : ' + filtres.length);
  for (const { f, s } of filtres) {
    const blocs = [...tete(s).matchAll(/^\s+paths:([^\n]*(?:\n\s+- [^\n]*)*)/gm)].map(m => m[1]);
    for (const b of blocs) for (const p of PARTAGES) assert.ok(b.includes("'" + p + "'") || b.includes('"' + p + '"') || b.includes('- ' + p), f + ' : ' + p);
    assert.match(tete(s), /^\s+schedule:/m, f + ' : passage de nuit');
  }
});

test('images seules : la suite complète et le parcours immobilier ne partent pas ; ils tournent chaque nuit', () => {
  for (const nom of ['coherence-client.yml', 'test-parcours-immobilier-135.yml']) {
    const s = tete(flux.find(x => x.f === nom).s);
    assert.equal((s.match(/paths-ignore: \['images\/\*\*', '\*\*\/\*\.webp', '\*\*\/\*\.png', '\*\*\/\*\.jpg', '\*\*\/\*\.jpeg', '\*\*\/\*\.gif'\]/g) || []).length, 2, nom);
    assert.match(s, /^\s+schedule:/m, nom);
    assert.doesNotMatch(s, /\.js'|\.html'|\.sql'/, nom + ' : aucun code ignoré');
  }
});
