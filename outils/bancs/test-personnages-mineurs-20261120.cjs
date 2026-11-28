'use strict';
// Carrières sans métier et personnages mineurs (décisions de Fred du 20/11/2026).
// Essai annulé en base le 20/11 : personnage 'minor' → est_mineur vrai et carrière figée (passage à 'escort' ignoré) ;
// un adulte ne devient pas mineur ; mineur_refus_interne(adulte, [mineur]) → 'action_non_disponible' (neutre),
// adulte seul → NULL ; seconde carrière d'un mineur → 'personnage_mineur_carriere_unique' ; les 23 raccords posés ;
// message_signaler sur une conversation → auteur et destinataire relevés, doublon reconnu.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const racine = path.join(__dirname, '../..');
const lire = (f) => fs.readFileSync(path.join(racine, f), 'utf8');

function careers() {
  const src = lire('data.js');
  const debut = src.indexOf('const CAREERS = [');
  const fin = src.indexOf('];', debut);
  return vm.runInNewContext(src.slice(debut, fin + 2).replace('const CAREERS =', 'CAREERS =') + ';CAREERS', {});
}

test('data.js : deux carrières sans métier, sans bonus ni blocage', () => {
  const c = careers();
  const mineur = c.find(x => x.id === 'minor'), sans = c.find(x => x.id === 'sans_experience');
  assert.equal(mineur.argBonus, 50); assert.equal(mineur.statKey, null); assert.equal(mineur.blocks.length, 0); assert.equal(mineur.mineur, true);
  assert.equal(sans.argBonus, 100); assert.equal(sans.statKey, null); assert.equal(sans.blocks.length, 0); assert.ok(!sans.mineur);
  assert.equal(new Set(c.map(x => x.id)).size, c.length);
  const gen = lire('api/_referentiels-generes.js');
  assert.match(gen, /"id": "minor"/); assert.match(gen, /"id": "sans_experience"/);
});

test('Création : carte sans « +1 null », secours français, mineur jamais conseillé', () => {
  const cr = lire('creation.js');
  assert.match(cr, /\$\{c\.statKey\?` &middot; \$\{htmlModificateurStat\(c\.statKey, 1\)\}`:''\}/);   // nom complet (reliquat #1142)
  assert.match(cr, /t\('creation\.careers\.'\+c\.id\+'\.name',\{defaultValue:c\.name\}\)/);
  assert.match(cr, /if\(ca\.mineur\) return null;/);
  const cons = lire('api/conseiller-creation.js');
  assert.match(cons, /filter\(c => c\.id !== 'minor'\)/);
  assert.match(cons, /prop\.career === 'minor'\) return null;/);
});

test('Serveur : marque permanente, contrôle commun neutre, raccords dans les deux sens', () => {
  const sql = lire('migrations/20261120230000_mineurs_carrieres_garde_fous.sql');
  assert.match(sql, /NEW\.est_mineur := OLD\.est_mineur;/);
  assert.match(sql, /IF OLD\.est_mineur THEN NEW\.career := OLD\.career;/);
  assert.match(sql, /'raison', 'action_non_disponible'/);
  assert.match(sql, /CREATE TRIGGER mineur_sans_autre_carriere BEFORE INSERT OR UPDATE ON public\.carrieres_acquises/);
  assert.match(sql, /CREATE TRIGGER mineur_sans_autre_carriere BEFORE INSERT ON public\.universite_inscriptions/);
  for (const f of ['universite_inscrire', 'mes_carrieres', 'escort_recruter', 'escort_sociale_choisir', 'pnj_debaucher',
    'pnj_employe_debaucher', 'escort_piege_tenter', 'dealer_acheter', 'objet_acheter', 'inventaire_consommer',
    'consommer_sur_place_commerce', 'acheter_produit_commerce_interne', 'jauges_ordre_executer', 'tournee_creer',
    'tournee_repondre', 'restaurant_diner_servir', 'diner_commerce_servir_interne', 'service_etage_commander',
    'residence_acte', 'sovarka_maison_agir', 'pnj_contexte_public'])
    assert.match(sql, new RegExp("rp_raccorder\\('public\\." + f + '\\('), f);
  for (const f of ['escort_standard_devis', 'escort_standard_valider', 'escort_intimite']) assert.match(sql, new RegExp("'public\\." + f + '\\('), f);
  // Dans les deux sens : la cible compte autant que l'acteur.
  assert.match(sql, /mineur_refus_interne\(a\.name, ARRAY\[p_cible\], 'kompromat_intime'\)/);
  assert.match(sql, /mineur_refus_interne\(v_moi, p_invites, 'alcool'\)/);
  // Le contrôle n'est jamais recopié : chaque raccord appelle la même fonction.
  assert.equal((sql.match(/personnage_est_mineur\(c\)/g) || []).length, 1);
});

test('Écran : un seul point d\'écoute pour le refus neutre', () => {
  const sb = lire('supabase.js'), core = lire('plateau-core.js');
  assert.match(sb, /v\.raison === 'action_non_disponible' \|\| v\.raison === 'personnage_mineur_carriere_unique'/);
  assert.match(sb, /window\.rpActionNonDisponible\(v\.raison\)/);
  assert.match(core, /trad\('minorGuard\.unavailable', 'Cette action n’est pas disponible\.'\)/);
  assert.match(core, /if \(r\.raison === 'action_non_disponible' \|\| r\.raison === 'personnage_mineur_carriere_unique'\) return;/);
});

test('Dialogue des PNJ : consigne « personne mineure » lue sur la fiche', () => {
  const src = lire('api/_pnj-profils.js');
  const debut = src.indexOf('function blocMineurInterlocuteur(');
  const fin = src.indexOf('\n}\n', debut);
  const mod = vm.runInNewContext(src.slice(debut, fin + 3) + ';({ blocMineurInterlocuteur })', {});
  assert.match(src, /const mineur = blocMineurInterlocuteur\(contextePublic\);/);
  assert.match(src, /\.\.\.\(mineur \? \[mineur, ''\] : \[\]\),/);
  assert.equal(mod.blocMineurInterlocuteur({ nom: 'X', genre: 'H' }), null);
  assert.equal(mod.blocMineurInterlocuteur({ nom: 'X', mineur: 'true' }), null);
  assert.match(mod.blocMineurInterlocuteur({ nom: 'X', mineur: true }), /Tu ne\s+la seduis jamais/);
  const sql = lire('migrations/20261120230000_mineurs_carrieres_garde_fous.sql');
  assert.match(sql, /THEN jsonb_build_object\('mineur', true\) ELSE '\{\}'::jsonb END/);
});

test('Signalement : bouton sur courrier, forum et conversations ; file MJ, mineurs en tête', () => {
  const forum = lire('forum.js'), multi = lire('plateau-multijoueur.js'), core = lire('plateau-core.js');
  assert.match(forum, /rpSignalerMessage\('forum', this\.dataset\.signalerId\)/);
  assert.match(forum, /rpSignalerMessage\('courrier', this\.dataset\.signalerId\)/);
  assert.match(multi, /rpSignalerMessage\(\\'conversation\\', this\.dataset\.signalerId\)/);
  assert.match(core, /sbRpc\('message_signaler', \{ p_source: source, p_message_id: String\(messageId\), p_motif:/);
  const sql = lire('migrations/20261120230000_mineurs_carrieres_garde_fous.sql');
  assert.match(sql, /ORDER BY \(s\.statut = 'ouvert'\) DESC, s\.mineur DESC, s\.cree_le ASC/);
  assert.match(sql, /v_moi IN \(m\.to_player, m\.from_player, m\.from_real\)/);
  const admin = lire('admin.html'), js = lire('admin-signalements.js');
  assert.match(admin, /<script src="admin-signalements\.js\?v=[^"]+"><\/script>/);
  assert.match(admin, /admSignalementsCharger\(false\)/);
  assert.match(js, /\(s\.mineur \? '\[MINEUR\] ' : ''\)/);
  assert.match(js, /rpAdminRpc\('admin_signalement_traiter'/);
});

test('Docs : game design, charte et clés pour Codex', () => {
  const gd = lire('GAME-DESIGN-PERSONNAGES-MINEURS.md'), relais = lire('RELAIS.md');
  assert.match(gd, /mineur_refus_interne\(acteur, cibles, motif\)/);
  assert.match(relais, /### Charte à rédiger avant le 19\/12[\s\S]*bannissement définitif, sans avertissement/);
  assert.match(relais, /`minorGuard\.unavailable`/);
});
