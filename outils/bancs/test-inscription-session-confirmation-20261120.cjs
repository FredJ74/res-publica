'use strict';
// Inscription (retours testeurs du 20/11/2026) :
//  1. un compte non confirmé joue tout de suite (migration 20261120210000_compte_identifiants_poses) ;
//  2. annonce du lien de confirmation après la saisie ; 3. bandeau « non confirmée » dans le jeu ;
//  4. aide explicite à la connexion depuis un autre appareil ; 5. « Retrouver mon personnage » sans saisie de nom.
// Vérifié de bout en bout dans Chrome contre la base le 20/11 (adresse jetable) : annonce affichée, entrée dans le jeu avec
// le personnage (mon_personnage le rend), bandeau et « Renvoyer l'e-mail », « Reprendre la partie avec [nom] », sans session
// ouverture de « Se connecter », connexion d'un autre appareil → invalid_credentials + aide.
// Essai annulé en base : non confirmé → personnage rendu ; anonyme pur → NULL ; confirmé → inchangé.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const racine = path.join(__dirname, '../..');
const lire = (f) => fs.readFileSync(path.join(racine, f), 'utf8');

test('Migration : jeton non anonyme, ou mot de passe et adresse posés ; l\'anonyme pur reste refusé', () => {
  const sql = lire('migrations/20261120210000_compte_identifiants_poses.sql');
  assert.match(sql, /coalesce\(\(auth\.jwt\(\) ->> 'is_anonymous'\)::boolean, false\) = false\s+OR EXISTS \(SELECT 1 FROM auth\.users u/);
  assert.match(sql, /coalesce\(u\.encrypted_password, ''\) <> ''/);
  assert.match(sql, /coalesce\(u\.email_change, ''\) <> '' OR coalesce\(u\.email, ''\) <> ''/);
  for (const f of ["'public.mon_personnage()'", "'public.est_mon_personnage(text)'", 'ia_quota_consommer']) assert.ok(sql.includes(f), f);
});

test('Écran : annonce, aide à la connexion, bandeau, reprise sans saisie de nom', () => {
  const c = lire('creation.js'), core = lire('plateau-core.js'), auth = lire('auth.js'), html = lire('index.html');
  assert.match(c, /if \(r\.encore_anonyme === true\) afficherConfirmationEnvoyee\(r\.enAttente \|\| email\); else goTo\(1\);/);
  assert.match(c, /'auth\.confirmationSent'/);
  assert.match(c, /Pensez à vérifier vos courriers indésirables\./);
  assert.match(c, /raison === 'email_not_confirmed' \|\| r\.raison === 'invalid_credentials'\) && typeof rpAideConfirmationConnexion === 'function'/);
  assert.match(auth, /body: JSON\.stringify\(\{ type: 'signup', email: email \}\)/);
  assert.match(core, /if \(!e \|\| e\.ok !== true \|\| e\.confirmee \|\| !e\.enAttente\) return;/);
  assert.match(core, /rpAuthDemanderConfirmationAdresse\(e\.enAttente\)/);
  assert.doesNotMatch(html, /id="retrouver-nom"/);
  assert.match(c, /nom = await sbRpc\('mon_personnage', \{\}\)/);
  assert.match(c, /'home\.resumeWith'/);
  assert.match(c, /rpAuthLireStockage\(\) : null;/); // jamais de compte anonyme ouvert pour « retrouver »
  assert.doesNotMatch(c, /Ce navigateur possede deja le personnage « ' \+ \(verdict\.personnage/);
});
