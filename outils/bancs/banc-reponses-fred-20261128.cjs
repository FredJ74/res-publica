'use strict';
// Mission du 28/11/2026 (nuit), étape 2 : réponses de Fred aux questions du 27/11 (soir). Épreuves SQL passées en
// transaction annulée en production avant application (permis vrai puis refus de réutilisation, faux permis consommé,
// gain réel de l'accessoire au plafond, transfert d'un détenu du QHS, cartons refusés hors ambassadeur).
// Usage : node --test outils/bancs/banc-reponses-fred-20261128.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG = lire('migrations/20261128010000_reponses_fred_27_soir.sql');

test('serveur : les huit réponses sont portées par la migration', () => {
  assert.match(MIG, /IF p_type_pret=''travaux'' THEN PERFORM public\.pret_travaux_permis_consommer_interne/);
  assert.match(MIG, /RAISE EXCEPTION 'permis_construire_requis'/);
  assert.match(MIG, /IF p_doc = 'faux_permis' THEN[\s\S]{0,200}document_urbanisme_acceptation/);
  assert.doesNotMatch(MIG, /faux_compromis/);
  assert.match(MIG, /UPDATE public\.ordres_couts SET pa = 2, cost = 0 WHERE fn = 'fuite_info'/);
  assert.match(MIG, /renseignement_interrogatoires_repetes_v1/);
  assert.match(MIG, /v_jour \+ 30, false\)/);
  assert.match(MIG, /'expireJour', coalesce\(day, 1\) \+ 30/);
  assert.match(MIG, /transfert_detenu_regimes_lever_interne/);
  assert.doesNotMatch(MIG.slice(MIG.indexOf('FUNCTION public.transfert_detenu_refus_interne')), /^\s*RETURN 'regime_particulier'/m);
  assert.match(MIG, /pavillon_cartons_ambassadeur_interne\(moi, r\.pays_payeur\)/);
  assert.match(MIG, /'bonus_pop_applique', v_gain/);
});

test('écran : fuite à 2 PA, faux permis dans les listes, motifs traduits, idée du faux passeport consignée', () => {
  const data = lire('data.js');
  assert.match(data.match(/\{fn:'fuite_info'[^\n]*/)[0], /pa:2, cost:0/);
  assert.match(data, /\{ id:'faux_permis', name:'Faux permis de construire'/);
  assert.match(lire('plateau-informatique.js'), /\['faux_permis', texteEquip\('fauxPermis'/);
  assert.match(lire('plateau-terrain-banque.js'), /permis_construire_requis:/);
  assert.equal((lire('i18n/finance135-resources.js').match(/"reason_permis_construire_requis"/g) || []).length, 9);
  assert.equal((lire('plateau-pavillon-cartons.js').match(/reserve_ambassadeur:/g) || []).length, 9);
  assert.match(lire('GAME-DESIGN-CRIMINALITE.md'), /faux passeport/);
});
