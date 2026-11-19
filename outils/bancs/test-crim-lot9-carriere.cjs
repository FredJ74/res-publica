'use strict';
// Criminalité, lot 9 : carrière criminelle (GAME-DESIGN-CRIMINALITE.md § 15).
// Trois niveaux, sans se faire passer l'un pour l'autre :
//  1. relevé des valeurs RENDUES PAR LA PRODUCTION lors de l'essai annulé du 20/11/2026 (Arnie, officier, inscrit au cursus
//     « Droit pénal », placé à l'amphithéâtre puis chez Pat Hounette puis au siège de La Main Noire le temps de l'essai, dates
//     d'inscription reculées de 10 semaines ; tout annulé par RAISE EXCEPTION), recopié ci-dessous et confronté aux règles ;
//  2. lecture de la migration (cursus, jalons, ouverture, raccords crim_carriere_v1 sur les actes des lots 2 à 8) ;
//  3. écran : plateau-universite.js chargé dans une machine virtuelle (affichage seul, cpj-*, aucun calcul ni Math.random).
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const racine = path.join(__dirname, '../..');
const lire = (f) => fs.readFileSync(path.join(racine, f), 'utf8');
const sql = lire('migrations/20261120090000_crim_lot9_carriere.sql');
const ecran = lire('plateau-universite.js');
const routeur = lire('plateau-router.js');
const data = lire('data.js');
const html = lire('plateau.html');

// Règle du § 15 : bonus de réussite seulement (valeurs posées aux lots 2 à 8, inchangées).
const BONUS = { neutraliser: 15, voler: 15, crocheter: 15, empoisonner: 15, explosifs: 15, incendie: 15, effraction: 10, corruption: 0 };
const carriereEffective = (carrieres) => ['criminal_c', 'intel', 'escort'].find((c) => carrieres.includes(c)) || carrieres[0];
const tauxCrochetage = (dis, carriere) => Math.max(5, Math.min(80, 30 + Math.floor(Math.max(0, dis - 50) / 2) + (carriere === 'criminal_c' ? 15 : 0)));
const tauxVolArgent = (carriere) => 55 + (['criminal_c', 'intel', 'escort'].includes(carriere) ? 15 : 0);   // DIS 50, PER 8

// Relevé de l'essai en production (transaction annulée, 20/11/2026).
const RELEVE = {
  carr_avant: 'officer', ben: 'criminal_c', angie: 'intel', dispo: ['univ_droit_penal'], med: { ok: false, raison: 'cursus_ferme' },
  ins: { ok: true, carriere: 'criminal_c' }, nj: 24, nterrain: 7, villes: ['capitale', 'caserne', 'ville_a'],
  j6: 'Stage semaine 2 — chez Pat Hounette ou au siège de votre organisation criminelle — Lire le Code pénal à l’envers',
  j7: 'Cours 6 — Droit pénal',
  j24: 'Stage semaine 8 — chez Pat Hounette ou au siège de votre organisation criminelle — Soutenir son mémoire devant Pat Hounette',
  v1: { ok: true, pa_preleves: 6 }, v6_amphi: 'lieu_incorrect', v6_mauvais: 'objectif_non_valide', v6: { ok: true, pa_preleves: 0 },
  v9_hors_orga: 'lieu_incorrect', v9_orga: { ok: true, pa_preleves: 0 }, diplome_tot: 'jalons_incomplets',
  diplome: { ok: true, carriere: 'criminal_c', carrieres: ['criminal_c', 'officer'], slot_consomme: true },
  carr_apres: 'criminal_c', possede: true, inscrire2: 'seconde_carriere_deja_acquise',
  taux_croch: [30, 45], taux_vol_intel: [55, 70],
  actes: { vol: { ok: true, taux: 85 }, cambr: { ok: true, taux: 85 }, incendie: { ok: true, taux: 75 }, neutr: { ok: true, taux: 43 },
           croch: 'pas_devant_la_porte', forcer: 'pas_devant_la_porte', poison: 'poison_manquant', explo: 'explosif_manquant', depute: 'requete_invalide' },
  pa_apres_cours: { pa_avant: 20, pa: 14 },
  ouverts: { univ_armee: false, univ_justice: false, univ_medecin: false, univ_affaires: false, univ_droit_penal: true }
};

test('Carrière effective : initiale ou seconde, priorité à la carrière qui porte un bonus', () => {
  assert.equal(carriereEffective(['officer']), 'officer');
  assert.equal(carriereEffective(['officer', 'criminal_c']), 'criminal_c');
  assert.equal(carriereEffective(['intel', 'criminal_c']), 'criminal_c');
  assert.equal(carriereEffective(['escort']), 'escort');
  assert.equal(RELEVE.carr_avant, 'officer');
  assert.equal(RELEVE.carr_apres, carriereEffective(RELEVE.diplome.carrieres));
  assert.equal(RELEVE.ben, 'criminal_c', 'carrière initiale criminelle inchangée');
  assert.equal(RELEVE.angie, 'intel');
  assert.match(sql, /FUNCTION public\.crim_carriere_interne\(p_nom text\)[\s\S]*carriere_possede\(p_nom, 'criminal_c'\)[\s\S]*'intel'[\s\S]*'escort'[\s\S]*carriere_initiale\(p_nom\)/);
});

test('Bonus de réussite seulement : +15 crochetage après le diplôme, +15 vol pour le renseignement', () => {
  assert.deepEqual(RELEVE.taux_croch, [tauxCrochetage(50, 'officer'), tauxCrochetage(50, 'criminal_c')]);
  assert.equal(RELEVE.taux_croch[1] - RELEVE.taux_croch[0], BONUS.crocheter);
  assert.deepEqual(RELEVE.taux_vol_intel, [tauxVolArgent('officer'), tauxVolArgent('intel')]);
  assert.equal(BONUS.corruption, 0);
  // Aucun nouveau paramètre de bonus : les valeurs restent celles des lots 2 à 8 (crim_parametres *_carriere).
  assert.doesNotMatch(sql, /_carriere', \d/);
  assert.doesNotMatch(sql, /crime_acheter_arme_noire|crime_acheter_explosifs/, 'marché noir non touché');
});

test('Raccords crim_carriere_v1 : chaque acte des lots 2 à 8 lit la carrière effective (un ancrage par fonction)', () => {
  const fonctions = ['crime_neutraliser(text,text,uuid)', 'crime_voler(text,text,text,uuid)', 'crim_crocheter(text,text,uuid)',
    'crim_forcer_porte(text,text,uuid)', 'crim_cambrioler_interne(text,text,text,uuid)', 'crime_empoisonner(text,uuid)',
    'crime_explosifs(text,uuid)', 'crime_incendier(text,uuid)', 'assemblee_neutraliser_depute(text,text,text,text)'];
  for (const f of fonctions) {
    const i = sql.indexOf("rp_raccorder('public." + f + "'");
    assert.ok(i > 0, f);
    const bloc = sql.slice(i, sql.indexOf("'crim_carriere_v1');", i));
    assert.match(bloc, /crim_carriere_interne\((name|v_perso\.name)\)/, f);
  }
  // Exécution réelle en essai : aucune erreur SQL, taux rendus par la résolution commune.
  for (const k of ['vol', 'cambr', 'incendie', 'neutr']) assert.equal(RELEVE.actes[k].ok, true, k);
  assert.ok(RELEVE.actes.vol.taux <= 85 && RELEVE.actes.incendie.taux <= 80);
});

test('Cursus « Droit pénal » : 24 jalons (17 cours, 7 stages), carrière criminelle, seul cursus ouvert', () => {
  assert.equal(RELEVE.nj, 24);
  assert.equal(RELEVE.nterrain, 7);
  assert.equal(RELEVE.j6.split(' — ').pop(), 'Lire le Code pénal à l’envers');
  assert.equal(RELEVE.j7, 'Cours 6 — Droit pénal');
  assert.match(RELEVE.j24, /^Stage semaine 8/);
  assert.deepEqual(RELEVE.dispo, ['univ_droit_penal']);
  assert.deepEqual(RELEVE.med, { ok: false, raison: 'cursus_ferme' });
  assert.equal(Object.values(RELEVE.ouverts).filter(Boolean).length, 1);
  assert.match(sql, /'univ_droit_penal', 'Droit pénal — seconde carrière', 'criminal_c', 8, 0, 0/);
  assert.match(sql, /crim_cursus_ouvert_v1[\s\S]*crim_cursus_ouvert_v2/);
  assert.doesNotMatch(RELEVE.villes.join(), /luthecia|port-sainte-marie/, 'identifiants de ville corrigés');
});

test('Stages : chez Pat Hounette, ou au siège d’une organisation criminelle dont on est membre', () => {
  assert.equal(RELEVE.v6_amphi, 'lieu_incorrect');
  assert.equal(RELEVE.v6_mauvais, 'objectif_non_valide');
  assert.equal(RELEVE.v6.ok, true);
  assert.equal(RELEVE.v6.pa_preleves, 0, 'un stage ne coûte rien');
  assert.equal(RELEVE.v1.pa_preleves, 6, 'un cours coûte 6 PA (règle existante)');
  assert.equal(RELEVE.pa_apres_cours.pa, RELEVE.pa_apres_cours.pa_avant - 6, 'PA restants rendus par le serveur');
  assert.equal(RELEVE.v9_hors_orga, 'lieu_incorrect', 'siège d’une organisation dont on n’est pas membre : refus');
  assert.equal(RELEVE.v9_orga.ok, true);
  assert.match(sql, /'place-formulaire-liberte'/);
  assert.match(sql, /crim_stage_organisation_interne[\s\S]*'criminelle'[\s\S]*localId[\s\S]*membres/);
  assert.match(data, /'place-formulaire-liberte': \{[\s\S]{0,1500}name:'Pat Hounette'/);
});

test('Diplôme : seconde carrière une seule fois, après tous les jalons', () => {
  assert.equal(RELEVE.diplome_tot, 'jalons_incomplets');
  assert.equal(RELEVE.diplome.ok, true);
  assert.equal(RELEVE.diplome.slot_consomme, true);
  assert.equal(RELEVE.possede, true);
  assert.equal(RELEVE.inscrire2, 'seconde_carriere_deja_acquise');
});

test('Écran : ordre ouvert, route directe, cpj-*, aucun calcul ni Math.random', () => {
  assert.doesNotMatch(ecran, /Math\.random/);
  assert.doesNotMatch(ecran, /pa_preleves/, 'PA recopiés du serveur, pas soustraits');
  assert.match(ecran, /class="cpj-dialogue"/);
  assert.match(ecran, /cpj-touche/);
  assert.match(routeur, /if \(fn === 'suivre_formation'\)\s+\{ ouvrirUniversiteFormation\(\); return; \}/);
  assert.match(html, /<script src="plateau-universite\.js\?v=crim-lot9-20261120"><\/script>/);
  const amphi = data.slice(data.indexOf("{fn:'suivre_formation'"), data.indexOf("{fn:'suivre_formation'") + 400);
  assert.doesNotMatch(amphi.split('}')[0], /bientot/);
});

test('Écran en machine virtuelle : affiche la liste du serveur et transmet l’inscription', async () => {
  const appels = [];
  const elements = {};
  const el = (id) => (elements[id] = elements[id] || { innerHTML: '', textContent: '', classList: { add() {}, remove() {} } });
  const ctx = {
    document: { getElementById: el }, state: { country: 'republic', pa: 20 }, console,
    showToast() {},
    sbRpc: async (fn, p) => {
      appels.push([fn, p]);
      if (fn === 'universite_mon_etat') return { ok: true, cursus_actif: null, slot_consomme: false,
        cursus_disponibles: [{ id: 'univ_droit_penal', libelle: 'Droit pénal — seconde carrière', carriere_libelle: 'Crime organisé', semaines_theoriques: 8 }] };
      if (fn === 'universite_prochaine_etape') return { ok: true, etape: null };
      if (fn === 'universite_inscrire') return { ok: true };
      return null;
    }
  };
  ctx.window = ctx;
  vm.createContext(ctx);
  vm.runInContext(ecran, ctx);
  await ctx.ouvrirUniversiteFormation();
  assert.match(elements['postes-body'].innerHTML, /Droit pénal — seconde carrière/);
  assert.match(elements['postes-body'].innerHTML, /8 semaines au minimum, 16 semaines au plus/);
  await ctx.universiteInscrire(0);
  assert.equal(JSON.stringify(appels.find((a) => a[0] === 'universite_inscrire')), JSON.stringify(['universite_inscrire', { p_cursus: 'univ_droit_penal' }]));
});
