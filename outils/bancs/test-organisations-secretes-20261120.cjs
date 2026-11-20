'use strict';
// Organisations secrètes (décisions de Fred du 20/11/2026).
// Essai annulé en base le 20/11 (Main Noire, chef Angie Porcelana, membres ajoutés Arnie et Tom Tom) :
// membre en mode cloisonné → membres = [lui seul], chef masqué, table brute illisible (0 ligne) ; extérieur (Jean Népa) →
// nom, nature, description, aucun membre ni compteur ; chef → 3 membres, table brute lisible ; mode « connus » → un
// membre voit les 3 ; message de forum signé par l'organisation → author_real vide, auteur rangé dans auteurs_secrets,
// le chef peut encore le modifier.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const lire = (f) => fs.readFileSync(path.join(__dirname, '../..', f), 'utf8');
const sql = lire('migrations/20261120330000_organisations_secretes.sql');

test('Serveur : une vue par lecteur, jamais un membre ni un compteur pour l\'extérieur', () => {
  assert.match(sql, /IF p_moi IS NOT NULL AND p_moi IN \(p_data ->> 'chef', p_data ->> 'fondateur'\) THEN/);
  assert.match(sql, /coalesce\(p_data ->> 'cloisonnement', 'connus'\) = 'connus'/);
  assert.match(sql, /jsonb_build_object\('membres', jsonb_build_array\(v_moi_entree\), 'secrete', true, 'membres_masques', true\)/);
  const ext = sql.slice(sql.indexOf('-- Extérieur'), sql.indexOf('END $$;', sql.indexOf('-- Extérieur')));
  assert.match(ext, /'membres', '\[\]'::jsonb/);
  for (const champ of ['chef', 'fondateur', 'president', 'tresorier', 'caisse', 'localId', 'influence']) assert.doesNotMatch(ext, new RegExp("'" + champ + "'"), champ);
  assert.match(sql, /OR \(public\.mon_personnage\(\) IS NOT NULL AND data IS JSON OBJECT\s+AND public\.mon_personnage\(\) IN \(data::jsonb ->> 'chef', data::jsonb ->> 'fondateur'\)\)\);/);
  assert.match(sql, /'cloisonnement', CASE WHEN \(v_def->>'secret'\)::boolean AND p_parametres->>'cloisonnement' = 'cloisonne' THEN 'cloisonne' ELSE 'connus' END/);
});

test('Fuites indirectes : vrai auteur des contenus signés par une secrète hors de la ligne publique', () => {
  assert.match(sql, /IF TG_TABLE_NAME = 'mails' THEN NEW\.from_real := NULL; ELSE NEW\.author_real := NULL; END IF;/);
  for (const t of ['forum_posts', 'forum_topics', 'mails']) assert.match(sql, new RegExp('CREATE TRIGGER zz_auteurs_secrets BEFORE INSERT OR UPDATE ON public\\.' + t));
  assert.match(sql, /REVOKE ALL ON public\.auteurs_secrets FROM anon, authenticated;/);
  assert.match(sql, /public\.contenu_organisation_est_moi\(author_org_id\)/);
});

test('Écran : lecture par organisations_lire, cloisonnement à la création, chef qui garde la main', () => {
  assert.match(lire('supabase.js'), /rows = await sbRpc\('organisations_lire', \{\}\);/);
  const q = lire('plateau-organisations-quetes.js');
  assert.match(q, /<select id="orga-membres-connus-select"/);
  assert.match(q, /<select id="orga-chef-connu-select"/);
  assert.match(q, /parametres\.membres_se_connaissent = document\.getElementById\('orga-membres-connus-select'\)\?\.value !== 'non';/);
  assert.match(q, /parametres\.chef_connu = document\.getElementById\('orga-chef-connu-select'\)\?\.value !== 'non';/);
  assert.match(q, /m\.chef_anonyme === true/);
  assert.match(q, /o\.chef_masque === true \? '<span data-i18n="organizationMembers\.hiddenLeader">le chef<\/span>'/);
  assert.match(q, /const masquer = !o\.visible && \(!suisMembreDe\(o\) \|\| o\.membres_masques === true\) && o\.chef !== state\.char\?\.name;/);
  assert.match(lire('forum.js'), /p\.authorIsOrg && p\.authorOrgId && getMesOrganisations\(\)\.some\(o => o\.id === p\.authorOrgId\)/);
  assert.match(lire('GAME-DESIGN-CRIMINALITE.md'), /## 3 bis\. Organisations secrètes/);
});

test('Deux options indépendantes (correction du 20/11) : quatre configurations, chef « le chef » sans nom', () => {
  const sql = lire('migrations/20261120335000_organisations_secretes_deux_options.sql');
  assert.match(sql, /v_connus := CASE WHEN jsonb_typeof\(p_data -> 'membres_se_connaissent'\) = 'boolean'/);
  assert.match(sql, /v_chef_connu := CASE WHEN jsonb_typeof\(p_data -> 'chef_connu'\) = 'boolean'/);
  assert.match(sql, /v_out := v_out - 'chef' - 'fondateur' - 'election';/);
  assert.match(sql, /jsonb_build_object\('chef_anonyme', true\)/);
  assert.match(sql, /'membres_masques', NOT v_connus, 'chef_masque', NOT v_chef_connu/);
  assert.match(sql, /organisations_secretes_v2/);
  // L'extérieur ne voit toujours aucun membre.
  assert.match(sql, /'membres', '\[\]'::jsonb, 'demandesAdhesion', '\[\]'::jsonb/);
});
