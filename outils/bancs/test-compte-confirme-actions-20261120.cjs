'use strict';
// Actions réservées aux comptes confirmés (décision de Fred du 20/11/2026).
// Essai annulé en base le 20/11 : compte de test non confirmé → candidature 'compte_non_confirme', attribution de poste
// 'titulaire_compte_non_confirme' (action nomination), fondation 'compte_non_confirme' (action fonder) ; compte confirmé →
// contrôle franchi ; PNJ → jamais concerné.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const racine = path.join(__dirname, '../..');
const lire = (f) => fs.readFileSync(path.join(racine, f), 'utf8');

test('Serveur : un contrôle commun, quatre raccords, premium prêt à brancher', () => {
  const sql = lire('migrations/20261120220000_compte_confirme_actions.sql');
  assert.match(sql, /JOIN auth\.users u ON u\.id = d\.user_id\s+WHERE d\.name = p_nom AND u\.email_confirmed_at IS NULL/);
  for (const f of ['candidature_refus_nationalite_interne', 'poste_attribuer_interne', 'ambassade_nommer', 'organisation_vie_commande'])
    assert.match(sql, new RegExp("rp_raccorder\\('public\\." + f + '\\('), f);
  assert.match(sql, /'titulaire_compte_non_confirme'/);
  assert.match(lire('GAME-DESIGN-ELECTIONS.md'), /compte_confirmation_refus_interne\(nom, 'premium'\)/);
});

test('Écran : un seul point d\'écoute, message « Confirmez votre adresse e-mail pour [action]. », renvoi du lien', () => {
  const sb = lire('supabase.js'), core = lire('plateau-core.js');
  assert.match(sb, /v\.raison === 'compte_non_confirme' \|\| v\.raison === 'titulaire_compte_non_confirme'/);
  assert.match(sb, /window\.rpCompteNonConfirme\(v\.action \|\| null, fn, v\.raison\)/);
  assert.match(core, /'Confirmez votre adresse e-mail pour ' \+ libelle \+ '\.'/);
  assert.match(core, /rpVerifierConfirmationAdresse\(message\)/);
  assert.match(core, /window\.rpCompteNonConfirme = rpCompteNonConfirme;/);
});
