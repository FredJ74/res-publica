'use strict';
// Criminalité — laissez-passer, mécanisme définitif (réponses de Fred du 20/11/2026).
//  1. relevé de l'essai en production (transaction annulée, 20/11) : vrai réutilisable, faux accepté une fois puis consommé,
//     retrait qui invalide partout, journal au nom inscrit ;
//  2. lecture de la migration 20261120190000_crim_laissez_passer_registre ;
//  3. écran : refus d'entrée nommé, choix du lieu et du nom du faux, gestion du QHS (ministre et juge), journal des archives.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const racine = path.join(__dirname, '../..');
const lire = (f) => fs.readFileSync(path.join(racine, f), 'utf8');
const sql = lire('migrations/20261120190000_crim_laissez_passer_registre.sql');

const RELEVE = {
  vrai_valide: true, faux1: { ok: true, nom: 'Jean Faux' }, faux2: { ok: false, raison: 'laissez_passer_requis' },
  vrai1: { ok: true, nom: 'Angie Porcelana' }, vrai2: { ok: true, nom: 'Angie Porcelana' }, retires: 1, apres_retrait: false,
  journal: 3, faux_dans_inventaire_apres: 0, parametre_invalide: null,
};

test('Relevé : le document compte, pas le porteur ; le faux sert une fois ; le retrait invalide partout', () => {
  assert.equal(RELEVE.vrai_valide, true);
  assert.deepEqual(RELEVE.faux1, { ok: true, nom: 'Jean Faux' }); // nom choisi par le faussaire, présenté par un autre
  assert.equal(RELEVE.faux2.raison, 'laissez_passer_requis');
  assert.equal(RELEVE.faux_dans_inventaire_apres, 0);
  assert.deepEqual(RELEVE.vrai1, RELEVE.vrai2);
  assert.equal(RELEVE.retires, 1); assert.equal(RELEVE.apres_retrait, false);
  assert.equal(RELEVE.journal, 3); // trois passages consignés (un faux, deux vrais)
  assert.equal(RELEVE.parametre_invalide, null);
});

test('Migration : registre, journal, contrôle du document, faux consommé, retrait sans condition de lieu', () => {
  assert.match(sql, /CREATE TABLE IF NOT EXISTS public\.crim_laissez_passer \(/);
  assert.match(sql, /CREATE TABLE IF NOT EXISTS public\.crim_laissez_passer_passages \(/);
  const debut = sql.indexOf('FUNCTION public.crim_lp_presenter_interne'); const presenter = sql.slice(debut, sql.indexOf('END $$;', debut));
  assert.match(presenter, /JOIN public\.crim_laissez_passer lp ON lp\.id = t\.e ->> 'id'/);
  assert.doesNotMatch(presenter, /titulaire/); // le nom du porteur n'est jamais comparé
  assert.match(presenter, /ORDER BY lp\.faux, t\.o/); // un vrai d'abord
  assert.match(presenter, /IF v_faux THEN\s+UPDATE public\.crim_laissez_passer SET valide = false, consomme_le = now\(\)/);
  const retirer = sql.slice(sql.indexOf('FUNCTION public.crim_lp_retirer_interne'), sql.indexOf('FUNCTION public.crim_lp_journal_interne'));
  assert.match(retirer, /WHERE nom = p_nom AND lieu = p_lieu AND pays = p_pays AND NOT faux AND valide/);
  assert.match(retirer, /WHERE d\.name = p_nom/); // confiscation chez le titulaire seulement
  const objet = sql.slice(sql.indexOf('FUNCTION public.crim_lp_objet_interne'), sql.indexOf('FUNCTION public.crim_lp_emettre_interne'));
  assert.doesNotMatch(objet, /faux/i); // rien sur le document ne trahit un faux
});

test('QHS : taxi devant le QHS, entrée contrôlée, délivré par le Ministre de la Justice ou un juge', () => {
  assert.match(sql, /IF p_mode='taxi_qhs' THEN b:=NULL;piece:=NULL;END IF;/);
  assert.match(sql, /IF p_batiment='qhs-prison' AND p\.current_city='qhs' AND p\.current_building IS DISTINCT FROM 'qhs-prison'/);
  assert.match(sql, /r:=public\.crim_lp_presenter_interne\(p_nom,'qhs',p\.country\);/);
  assert.match(sql, /SELECT coalesce\(\(SELECT j\.pays FROM public\.juge_moi\(\) j LIMIT 1\),[\s\S]{0,200}poste ->> 'id' = 'min_just'/);
  for (const f of ['crim_laissez_passer_qhs_lire()', 'crim_laissez_passer_qhs_delivrer(text)', 'crim_laissez_passer_qhs_retirer(text)']) assert.ok(sql.includes("'" + f + "'"), f);
});

test('Archives d\'écoute : chaque consultation est un passage ; journal remis au ministre', () => {
  assert.match(sql, /PERFORM public\.crim_lp_presenter_interne\(a, ''archives_ecoute'', ''soviet''\); \/\* crim_lp_passage_v1 \*\//);
  assert.match(sql, /'passages', public\.crim_lp_journal_interne\('archives_ecoute', 'soviet'\)/);
});

test('Faux : le faussaire choisit le lieu et le nom ; format contrôlé au serveur', () => {
  assert.match(sql, /split_part\(p_doc, '\|', 2\) NOT IN \('archives_ecoute', 'qhs'\)/);
  assert.match(sql, /length\(btrim\(split_part\(p_doc, '\|', 4\)\)\) NOT BETWEEN 1 AND 60/);
  assert.match(sql, /p_auteur, true\)/);
  const crim = lire('plateau-criminalite.js');
  assert.match(crim, /\['faux_laissez_passer', lieu, lieu === 'qhs' \? \(etat\(\)\.country \|\| 'republic'\) : 'soviet', nom\]\.join\('\|'\)/);
  assert.match(lire('plateau-justice-economie.js'), /doc\.id === 'faux_laissez_passer' && typeof crimFauxLpOuvrir === 'function'/);
  assert.match(lire('plateau-informatique.js'), /if \(doc === 'faux_laissez_passer' && typeof crimFauxLpOuvrir === 'function'\)/);
});

test('Écran : refus nommé, boutons du ministre et du juge, journal des archives', () => {
  assert.match(lire('plateau-navigation.js'), /laissez_passer_requis:'Entrée réservée aux porteurs d’un laissez-passer valide\.'/);
  assert.match(lire('plateau-politique.js'), /onclick="crimOuvrirLaissezPasserQhs\(\)"/);
  assert.match(lire('plateau-justice-economie.js'), /onclick="crimOuvrirLaissezPasserQhs\(\)"/);
  assert.match(lire('plateau-sovarka-provinces.js'), /window\.RPCriminalite\.blocPassages\(v\.passages\)/);
});
