'use strict';
// Mission du 27/11/2026 (soir), étape 3 : suppressions et boutons grisés décidés par Fred le 27/11/2026.
// Usage : node --test outils/bancs/banc-ordres-creux-nettoyage-20261127.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const data = lire('data.js'), routeur = lire('plateau-router.js');

test('ordres supprimés : ni bouton, ni route, ni traduction', () => {
  const orders = lire('i18n/orders-resources.js');
  for (const fn of ['deliberer_loge', 'compte_offshore', 'consulter_caisse_usine', 'consulter_stock_usine', 'sovarka_goulag_gestion']) {
    assert.doesNotMatch(data, new RegExp("fn: ?'" + fn + "'"), fn);
    assert.doesNotMatch(routeur, new RegExp("'" + fn + "'"), fn);
    assert.doesNotMatch(orders, new RegExp('"' + fn + '"'), fn);
  }
  assert.doesNotMatch(lire('i18n/sovarka-infobulles-resources.js'), /Le goulag de Starovka doit encore/);
  assert.doesNotMatch(lire('i18n/toast-bodies-resources.js'), /Ce service Helvetia n'est pas encore disponible/);
  // Le ministre de la Justice de Sovarka garde l'accès au goulag (habilitations) : rien d'autre n'est retiré.
  assert.match(data, /fn: 'sovarka_saisir_juge'/);
});

test('Helvetia : blanchiment et société écran grisés « Bientôt disponible », Racheter l’usine inchangé', () => {
  for (const fn of ['blanchiment', 'societe_ecran']) assert.match(data.match(new RegExp("\\{fn:'" + fn + "'[^\\n]*"))[0], /bientot:true/);
  assert.doesNotMatch(routeur, /fn === 'blanchiment'/);
  assert.match(data, /gerer_finances/);
});

test('Propagande d’État : retirée de la seule salle de presse présidentielle ; ministères et Sovarka gardent leur campagne', () => {
  const i = data.indexOf('salle_presse_elysee: {'), salle = data.slice(i, data.indexOf('\n      },', i));
  assert.doesNotMatch(salle, /propagande_etat/);
  assert.match(salle, /conference_presse/);
  assert.ok((data.match(/fn: ?'propagande_etat'/g) || []).length >= 3);
  assert.match(data, /roomsExclues: \['bureau_president', 'salle_presse_elysee'\]/, 'Sovarka n’hérite pas de cette salle');
});

test('serveur : seules les lignes des ordres supprimés partent', () => {
  const m = lire('migrations/20261127233000_ordres_creux_nettoyage.sql');
  assert.match(m, /DELETE FROM public\.ordres_generiques WHERE fn = 'deliberer_loge'/);
  assert.match(m, /DELETE FROM public\.ordres_couts WHERE fn IN \('deliberer_loge', 'compte_offshore', 'consulter_caisse_usine', 'consulter_stock_usine'\)/);
  assert.doesNotMatch(m, /propagande_etat'/);
});
