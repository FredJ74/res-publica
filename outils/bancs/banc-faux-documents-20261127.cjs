'use strict';
// Mission du 27/11/2026 (soir), étape 6 : « Falsifier un document » ne propose que les documents qui ont un effet en jeu
// (laissez-passer des archives d'écoute ou du QHS, carton d'invitation de la Grande Salle du Pavillon avec date au choix).
// Permis de construire et compromis de vente : la banque ne les exige pas (question notée). Règles des faux inchangées.
// Usage : node --test outils/bancs/banc-faux-documents-20261127.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG = lire('migrations/20261127236000_faux_documents_effectifs.sql');

test('serveur : laissez-passer et carton seulement ; carton identique à un vrai ; anciens faux sans effet refusés', () => {
  const objet = MIG.slice(MIG.indexOf('FUNCTION public.faux_document_objet_interne'), MIG.indexOf('FUNCTION public.faux_document_final_interne'));
  assert.match(objet, /faux_laissez_passer/);
  assert.match(objet, /pavillon_carton_objet_interne\(d, c ->> 'nom', NULL\)/);
  assert.doesNotMatch(objet, /fausse_identite|faux_permis|faux_contrat|fausse_convocation/);
  assert.match(objet, /RETURN NULL;/);
  const fin = MIG.slice(MIG.indexOf('FUNCTION public.faux_document_final_interne'));
  assert.match(fin, /jsonb_set\(p_doc_objet, '\{carton,id\}'/);
  assert.doesNotMatch(MIG, /FUNCTION public\.(crime_falsifier|faux_document_imprimer)\(/, 'règles des faux (PA, prix, taux) inchangées');
});

test('écran : liste du greffe et de l’imprimante, choix de la date, description fidèle', () => {
  const data = lire('data.js'), liste = data.slice(data.indexOf('const DOCUMENTS_FALSIFIABLES = ['), data.indexOf('];', data.indexOf('const DOCUMENTS_FALSIFIABLES = [')));
  assert.deepEqual([...liste.matchAll(/id:'([a-z_]+)'/g)].map(m => m[1]), ['faux_laissez_passer', 'faux_carton']);
  for (const l of data.split('\n').filter(l => l.includes("{fn:'falsifier_document'"))) {
    assert.match(l, /pa:3, cost:300/);
    assert.doesNotMatch(l, /Fausse identité|faux contrat|convocation/);
    assert.match(l, /carton d\\'invitation/);
  }
  assert.match(lire('plateau-justice-economie.js'), /doc\.id === 'faux_carton' && typeof fauxCartonOuvrir === 'function'/);
  const info = lire('plateau-informatique.js');
  assert.match(info, /\['faux_laissez_passer', [^\]]*\], \['faux_carton',/);
  assert.doesNotMatch(info, /'fausse_identite'/);
  const cartons = lire('plateau-pavillon-cartons.js');
  assert.match(cartons, /\['faux_carton', date, nom\]\.join\('\|'\)/);
});

test('textes du faux carton : neuf langues, mêmes clés', () => {
  const ctx = { window: {} };
  vm.runInNewContext(lire('plateau-pavillon-cartons.js'), ctx);
  const TF = ctx.window.RP_FAUX_CARTON_T;
  assert.deepEqual(Object.keys(TF), ['fr', 'en', 'es', 'zh-TW', 'ru', 'ko', 'ar', 'pt-BR', 'de']);
  for (const l of Object.keys(TF)) assert.equal(Object.keys(TF[l]).sort().join(), Object.keys(TF.fr).sort().join(), l);
});
