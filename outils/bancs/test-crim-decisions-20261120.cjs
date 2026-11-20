'use strict';
// Criminalité — décisions de Fred du 20/11/2026 sur les valeurs provisoires (GAME-DESIGN-CRIMINALITE.md, « Décisions du 20/11/2026 »).
// Trois niveaux :
//  1. formules recalculées ici et comparées aux valeurs RENDUES PAR LA PRODUCTION après application (relevé du 20/11 recopié) ;
//  2. lecture de la migration 20261120170000_crim_decisions_fred (raccords, paramètres, protections) ;
//  3. écran : aucun calcul du poison, type « document », porte crochetée ouverte, tenue ninja au marché, faux laissez-passer.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const racine = path.join(__dirname, '../..');
const lire = (f) => fs.readFileSync(path.join(racine, f), 'utf8');
const sql = lire('migrations/20261120170000_crim_decisions_fred.sql');

// Relevé de la production (20/11/2026, après application).
const RELEVE = {
  peines: { ass_sov: 4, ref_sov: 2, ass_rep: 2, vol_sov: 2, corr_sov: 2, corr_rep: 1, rebel_rep: 2, rebel_sov: 4, matee_sov: 8, narco: 2 },
  dis: { 47: -1, 49: 0, 56: 2 }, croch: { 40: 25, 60: 35 }, rumeur41: 57, poison: { 41: 37, 50: 40 },
  categories: { laissez_passer: 'document', dotation: 'arme', extrait: 'document', quete: null, poste: null },
  prix: { ninja_rep: 110, ninja_sov: 32, polonium: 150 },
};

const bonusDis = (dis) => Math.trunc((dis - 50) / 3) || 0; // -0 → 0
test('DIS symétrique : +1 / −1 par tranche de 3 autour de 50 (tranches tronquées vers zéro)', () => {
  for (const [dis, v] of Object.entries(RELEVE.dis)) assert.equal(bonusDis(Number(dis)), v, 'DIS ' + dis);
  for (const [dis, v] of Object.entries(RELEVE.croch)) assert.equal(30 + (Math.trunc((Number(dis) - 50) / 2) || 0), v, 'crochetage DIS ' + dis);
  assert.equal(60 + bonusDis(41), RELEVE.rumeur41);
  assert.equal(RELEVE.poison[50] - RELEVE.poison[41], 3); // empoisonnement : DIS 41 → −3
  assert.match(sql, /SELECT trunc\(\(coalesce\(p_dis, 50\) - public\.crim_param_interne\('crim_dis_pivot', 50\)\)/);
  assert.doesNotMatch(sql.slice(sql.indexOf('FUNCTION public.crim_bonus_dis_interne'), sql.indexOf('FUNCTION public.crim_crocheter_taux_interne')), /greatest\(0/);
});

test('Peines : rébellion réussie 2 j ; peines automatiques de Sovarka doublées ; le juge garde la référence', () => {
  const p = RELEVE.peines;
  assert.equal(p.ass_sov, 2 * p.ass_rep); assert.equal(p.vol_sov, 2); assert.equal(p.corr_sov, 2 * p.corr_rep);
  assert.equal(p.rebel_rep, 2); assert.equal(p.rebel_sov, 4); assert.equal(p.matee_sov, 8);
  assert.equal(p.narco, p.ass_rep, 'empires non ouverts = Républia');
  assert.equal(p.ref_sov, p.ass_rep, 'référence du juge non doublée');
  assert.match(sql, /\('peine_jours_se_rebeller_republic', 2\)/);
  assert.match(sql, /\('peine_facteur_soviet', 2\)/);
  assert.match(sql, /crim_peine_reference_interne\(p_calc ->> 'infraction', p_pays\) \/\* crim_peine_juge_reference_v1 \*\//);
});

test('Vol : documents et dotation volables ; quête, revêtu, immobilier et poste protégés', () => {
  const c = RELEVE.categories;
  assert.equal(c.laissez_passer, 'document'); assert.equal(c.dotation, 'arme'); assert.equal(c.extrait, 'document');
  assert.equal(c.quete, null); assert.equal(c.poste, null);
  const f = sql.slice(sql.indexOf('FUNCTION public.crim_vol_categorie_interne'), sql.indexOf('crim_vol_documents_v1 */\n$$;'));
  assert.doesNotMatch(f, /origineMilitaire/);
  assert.match(f, /'calepinEnigme1', 'quete', 'lie_poste', 'liePoste', 'titre_propriete', 'bien_id'/);
  assert.match(f, /porte_par/);
  assert.match(sql, /'graisse', 'document'\) \/\* crim_vol_documents_v1 \*\//);
});

test('Porte crochetée ouverte pour tous jusqu\'à la clé du propriétaire ; plus de fenêtre de 2 h', () => {
  assert.match(sql, /UPDATE public\.serrures SET fermee = false WHERE id = \(po ->> 'serrure'\)::uuid; \/\* crim_porte_ouverte_v1 \*\//);
  assert.match(sql, /FUNCTION public\.crim_passage_valide_interne[\s\S]{0,200}SELECT false;/);
});

test('GHB : toute boisson compte ; accroche commune boisson_bue_interne', () => {
  for (const f of ['maladie_verre_interne', 'inventaire_consommer', 'tournee_cloturer_boire', 'service_etage_commander',
    'consommer_sur_place_commerce', 'diner_commerce_servir_interne']) assert.match(sql, new RegExp("rp_raccorder\\('public\\." + f + '\\('), f);
  assert.match(sql, /FROM public\.boissons_du_jour WHERE nom = p_nom/);
  assert.match(sql, /IF v_boisson='non_alcoolisee' THEN PERFORM public\.boisson_bue_interne\(p_acteur\)/);
});

test('Gilet unique, tenue ninja fabriquée, laissez-passer physique, faux identique, rumeur nationale, marché noir sans bonus', () => {
  assert.match(sql, /'desc', 'Revêtu : −20 % aux attaques à l''arme à feu, −5 % à mains nues ou à l''arme blanche\.'/);
  assert.match(sql, /p_item - 'sousType' - 'desc' - 'name' - 'icon' - 'imageUrl' - 'type'/); // porte_par, lot, id conservés
  assert.match(sql, /'tenue_ninja_marche', 'marche', 'Tenue ninja', 1, 1, '\{"textile":1\}'/);
  assert.equal((5 + 50) * 2, RELEVE.prix.ninja_rep); assert.equal((1 + 15) * 2, RELEVE.prix.ninja_sov);
  assert.match(sql, /array_remove\(cles, 'tenue_ninja'\)[\s\S]{0,120}'armurerie-luthecia'/);
  assert.match(sql, /IF NOT public\.crim_laissez_passer_detenu_interne\(a, 'archives_ecoute'\)/);
  assert.match(sql, /NOT coalesce\(e ->> 'laissez_passer' = p_genre AND e ->> 'titulaire' = p_nom, false\)/); // jamais d'autre objet perdu
  assert.match(sql, /WHEN p_doc = 'faux_laissez_passer' THEN public\.crim_laissez_passer_objet_interne\('archives_ecoute', p_auteur\)/);
  assert.match(sql, /annonce_publique_interne\(coalesce\(\(SELECT country FROM public\.personnages_donnees WHERE name = v_moi\), 'republic'\)/);
  assert.match(sql, /crim_marche_noir_sans_bonus_v2/);
  assert.match(sql, /SELECT 'acheter_polonium', 2, 150/);
});

test('Écran : poison relu du serveur, type document, porte ouverte, tenue au marché, faux laissez-passer, polonium', () => {
  const perso = lire('plateau-personnage.js');
  assert.match(perso, /if \(vRepos\?\.empoisonnement\) \{/);
  assert.doesNotMatch(perso, /state\.hp = Math\.floor\(\(state\.hp \|\| 0\) \/ 2\)/);
  assert.match(sql, /\|\| public\.crim_poison_nuit_interne\(p_acteur\) \/\* crim_poison_nuit_v1 \*\//);
  assert.match(sql, /\|\| public\.crim_poison_nuit_interne\(p_acteur\) \/\* crim_poison_nuit_v2 \*\//);
  const crim = lire('plateau-criminalite.js');
  assert.match(crim, /'graisse', 'document'\]/);
  assert.match(crim, /serruresPassageAccorde\(r\.entrer\.batiment, r\.entrer\.piece, true\)/);
  const ill = lire('plateau-actions-illegales-rumeurs.js');
  assert.match(ill, /tenue_ninja_marche: \{[\s\S]{0,200}familleProduitMarche: 'vetement'/);
  assert.match(ill, /polonium:  \{ name:'Fiole de Polonium',  icon:'ti-radioactive', cout:150,/);
  const data = lire('data.js');
  assert.match(data, /id:'faux_laissez_passer'/);
  assert.doesNotMatch(data, /fn:'acheter_polonium'/);
  assert.match(lire('plateau-informatique.js'), /'faux_laissez_passer'/);
});
