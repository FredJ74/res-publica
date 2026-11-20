// Banc : économie de la distillerie et des alcools (Fred, 20/11/2026). GAME-DESIGN-DISTILLERIE-ALCOOLS.md.
const test = require('node:test'); const assert = require('node:assert'); const fs = require('fs'); const path = require('path');
const racine = path.join(__dirname, '..', '..'); const lire = f => fs.readFileSync(path.join(racine, f), 'utf8');
const sql = lire('migrations/20261120340000_distilleries_alcools.sql');

test('Matières : alcool pur (clé historique), spiritueux, sucre — serveur et client', () => {
  assert.match(sql, /\('spiritueux', 14, 7, 100, 'transformation'\),\s*\('sucre', 5, 2\.5, 150, 'transformation'\)/);
  const d = lire('data.js');
  assert.match(d, /alcool: +\{ label: 'Alcool pur'/);
  assert.match(d, /spiritueux: +\{ label: 'Spiritueux'/);
  assert.match(d, /sucre: +\{ label: 'Sucre', +icon: 'ti-cube', +prixBase: 5/);
  const g = lire('api/_referentiels-generes.js');
  assert.match(g, /"spiritueux": \{/); assert.match(g, /"sucre": \{/);
  assert.match(lire('api/_journal-collecte.js'), /"spiritueux": \{/);
});

test('Chaînes : PSM (céréales → spiritueux, fruits → sucre) et Krasnov (fruits), jour et nuit', () => {
  assert.match(sql, /'spiritueux', 'ville_a', 'pole-tabac-alcools-psm', 'cereales', 55/);
  assert.match(sql, /'sucre', 'ville_a', 'pole-tabac-alcools-psm', 'fruits_legumes', 30/);
  assert.match(sql, /'soviet', 'spiritueux', 'ville_b', 'distillerie-krasnov', 'fruits_legumes', 15, 6/);
  assert.match(sql, /'soviet', 'sucre', 'ville_b', 'distillerie-krasnov', 'fruits_legumes', 15, 7/);
  assert.match(sql, /VALUES \('produire_spiritueux'\), \('produire_sucre'\)/);
  const j = lire('plateau-justice-economie.js');
  assert.match(j, /spiritueux: +\{ buildingId: 'pole-tabac-alcools-psm', +city: 'ville_a', +matiere: 'cereales', salairePA: 55 \}/);
  assert.match(j, /sucre: +\{ buildingId: 'distillerie-krasnov', +city: 'ville_b', +matiere: 'fruits_legumes', salairePA: 15 \}/);
  const r = lire('plateau-router.js');
  assert.match(r, /fn === 'produire_spiritueux'\) \{ doProduireUsine\('spiritueux'\)/);
  assert.match(r, /fn === 'produire_sucre'\) \{ doProduireUsine\('sucre'\)/);
  const c = lire('api/cron-minuit.js');
  assert.match(c, /\{ matiere: 'cereales', produit: 'spiritueux' \}, \{ matiere: 'fruits_legumes', produit: 'sucre' \}/);
  assert.match(c, /ville_a: +\{ buildingId: 'pole-tabac-alcools-psm', +matieres: \['cereales', 'plantes', 'fruits_legumes'\] \}/);
  // Le désinfectant reste sur l'alcool pur (clé « alcool »).
  assert.match(c, /\{ matiere: 'alcool', produit: 'desinfectant' \}/);
});

test('Bars et buvettes : spiritueux ; stocks migrés ; flux internationaux de Fred', () => {
  assert.match(sql, /UPDATE public\.recettes_commerce SET materiaux = \(materiaux - 'alcool'\) \|\| jsonb_build_object\('spiritueux'/);
  assert.match(sql, /data -> 'stockMatieres' \? 'alcool'/);
  assert.match(sql, /'alcool', ceil\(.*\/ 2\),\s*'spiritueux'/s);
  const a = lire('plateau-actions-illegales-rumeurs.js');
  assert.doesNotMatch(a, /materiaux: ?\{ ?alcool/);
  for (const f of ["('republic', 'khalija', 'alcool', 50)", "('republic', 'khalija', 'spiritueux', 50)", "('soviet', 'khalija', 'alcool', 50)",
                   "('soviet', 'khalija', 'spiritueux', 50)", "('narco', 'khalija', 'fruits_legumes', 100)", "('republic', 'khalija', 'fruits_legumes', 50)"])
    assert.ok(sql.includes(f), f);
  assert.match(sql, /SET cle = 'spiritueux'[^;]*WHERE origine = 'republic' AND destination = 'soviet' AND cle = 'alcool'/);
});

test('Distillerie d’État de Krasnov : jamais à louer, directeur PNJ nommé par min_fin', () => {
  assert.match(sql, /DELETE FROM public\.sovarka_locaux WHERE batiment = 'distillerie-krasnov' AND entreprise_id IS NULL/);
  assert.match(sql, /'soviet_directeur_tabac_alcools_national', 'soviet', 'directeur_tabac_alcools', NULL, 'Anatoli Pokhmelkine \(PNJ\)'/);
  const d = lire('data.js');
  assert.doesNotMatch(d, /ordresLocal/);
  assert.match(d, /min_fin: +\{ label: 'Ministre des Finances'/);
});

test('Spiritueux de la maison : trois par distillerie, aucun à Al-Khalija, rejeu sans double paiement', () => {
  assert.match(sql, /WHEN 'soviet' THEN ARRAY\['Vodka', 'Slivovitz', 'Samogon'\]/);
  assert.match(sql, /WHEN 'republic' THEN ARRAY\['Champagne', 'Cognac', 'Pastis'\]/);
  assert.match(sql, /ELSE ARRAY\[\]::text\[\] END;/);
  assert.match(sql, /mineur_refus_interne\(p_acteur, NULL, 'alcool'\)/);
  assert.match(sql, /achat_requete_ouvrir_interne\(p_acteur, p_requete, 'distillerie_bouteille_acheter', prm\)/);
  assert.match(sql, /'boisson', 'alcoolisee', 'type', 'spiritueux_local'/);
  assert.match(lire('plateau-justice-economie.js'), /executerReceptionInventaire\('distillerie_bouteille_acheter', \{ p_acteur: state\.char\?\.name, p_nom: nom \}/);
  assert.match(lire('plateau-router.js'), /fn === 'acheter_spiritueux_local'\) \{ doOuvrirSpiritueuxLocaux\(\)/);
});

test('Pénuries du MJ : zone, intensité, durée, destruction, annonce, levée ; branchées partout', () => {
  assert.match(sql, /intensite integer NOT NULL CHECK \(intensite BETWEEN 1 AND 100\)/);
  assert.match(sql, /PERFORM public\.admin_exiger\(\);[\s\S]*admin_penurie_declarer|admin_penurie_declarer[\s\S]*PERFORM public\.admin_exiger\(\);/);
  assert.match(sql, /INSERT INTO public\.evenements_globaux/);
  assert.match(sql, /'penurie-' \|\| v_id/);
  assert.match(sql, /UPDATE public\.penuries SET levee_le = now\(\)/);
  for (const m of ['penuries_v1 \\*\\/\\n  IF v_produits <= 0', "penurie_coef_interne\\('soviet', r\\.ville, r\\.cle\\)", 'penuries_v1_chaines', 'penuries_v1_vd'])
    assert.match(sql, new RegExp(m));
  const c = lire('api/cron-minuit.js');
  assert.match(c, /sbRpc\('penuries_actives_lire', \{\}, HEADERS_SERVICE\)/);
  assert.match(c, /coefPenurie\('republic', transfo\.city, chaine\.produit\)/);
  assert.match(c, /Math\.floor\(besoin \* facteurBudget \* coefPenurie\('republic', city, cle\)\)/);
  assert.match(c, /await chargerPenuries\(\);\n    const livraisons/);
  assert.match(lire('admin.html'), /<script src="admin-penuries\.js\?v=1"><\/script>/);
  const a = lire('admin-penuries.js');
  for (const f of ['admin_penuries_lire', 'admin_penurie_declarer', 'admin_penurie_lever']) assert.ok(a.includes(f), f);
});

test('coefPenurie (nuit de la Républia) : pénurie la plus forte, zone ville ou pays', () => {
  const c = lire('api/cron-minuit.js');
  const src = c.slice(c.indexOf('function coefPenurie'), c.indexOf('async function produireUneChaine'));
  const coefPenurie = new Function('PENURIES_ACTIVES', src + '; return coefPenurie;');
  const f = coefPenurie([{ pays: 'republic', matiere: 'cereales', ville: null, intensite: 30 }, { pays: 'republic', matiere: 'cereales', ville: 'ville_a', intensite: 100 }]);
  assert.strictEqual(f('republic', 'ville_a', 'cereales'), 0);
  assert.strictEqual(f('republic', 'capitale', 'cereales'), 0.7);
  assert.strictEqual(f('republic', 'capitale', 'plantes'), 1);
  assert.strictEqual(f('soviet', 'ville_a', 'cereales'), 1);
});
