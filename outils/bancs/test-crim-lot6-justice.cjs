'use strict';
// Criminalité, lot 6 : Justice (GAME-DESIGN-CRIMINALITE.md §§ 3 et 14). Trois niveaux, sans se faire passer l'un pour l'autre :
//  1. règles du document recalculées ici et comparées aux valeurs RENDUES PAR LA PRODUCTION lors de l'essai annulé du 20/11
//     (migration appliquée, puis scénario en transaction annulée : Arnie commissaire de Luthécia le temps de l'essai, affaires
//     d'Angie Porcelana contre Jean Jaaj et Moustafa Kheimal, jets imposés) : relevé recopié ci-dessous ;
//  2. lecture de la migration, du canon pénal (plateau-core.js) et du générateur ;
//  3. module d'écran chargé dans une machine virtuelle (aucun calcul, pop-ups cpj-*, appels RPC).
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const racine = path.join(__dirname, '../..');
const lire = (f) => fs.readFileSync(path.join(racine, f), 'utf8');
const sql = lire('migrations/20261120030000_crim_lot6_justice.sql');
const js = lire('plateau-criminalite.js');
const core = lire('plateau-core.js');
const justice = lire('plateau-justice-economie.js');
const politique = lire('plateau-politique.js');

// Règles du document.
const plafond = (issue) => (issue === 'reussite' ? 5 : 15);
const chances = (pl, pistes, n) => Math.round(Math.min(pl, pl / 2 + (pl / 2) * pistes / n) * 100) / 100;
const bornesJuge = (ref) => [Math.max(1, Math.round(ref * 0.5)), Math.round(ref * 1.5)];
const bornesSeuil = (total, office) => [Math.max(0, Math.round(total * 0.5) - office), Math.max(0, Math.round(total * 1.5) - office)];
const seuil = (auto, deja = 0, s = 4) => ({ garde: Math.min(auto, Math.max(0, s - deja)), reporte: Math.max(0, deja + auto - s) - Math.max(0, deja - s) });

// Relevé de l'essai en production (transaction annulée, 20/11/2026).
const RELEVE = {
  bareme: { assassiner_feu_soviet: 2, vol_narco: 1, corrompre_juge: 1, gav: 2, rebellion: 1, matee: 4, evasion: 2, evasion_echouee: 1,
    effraction: 1, resistance: 2, acte_mains: { jours: 2, libelle: 'Assassinat' }, acte_bombe_khalija: { jours: 2, libelle: 'Crime' },
    crime_peine_vol_demasque: { jours: 2, amende: 1000 }, canon_meurtre: 'assassinat', canon_corrompre: 'corruption_fonctionnaire',
    empreinte: 'ac8ead42d4f8134e', categories: { crime: 2, delit: 1, crime_etat: 2, delit_grave: 1, delit_mineur: 1 }, non_detectables: 0,
    minuit: { ok: true, decouvertes: 0 } },
  plaintes: { jean_liee: true, mous_liee: true },
  lire: { n: 2, neutraliser: { chances: 3.33, pistes: { trace: true, rumeurs: false, informateur: false }, indices: { arme: 'revolver' }, masque: true },
          empoisonner: { chances: 7.5, indices: { poison: 'ghb' }, masque: false } },
  e1: { reussi: false, averti: true, taux: 3.33, dis: 75, moral: 85, mail: 1 },
  e2: 'une_tentative_par_jour', e1_rejoue: false,
  e3: { reussi: false, averti: false, dis: 75, moral: 85 },
  e4: { reussi: true, taux: 7.5, jours: 4, coupable: 'Angie Porcelana', plainte_vise: 'Angie Porcelana',
        office: { id: 'office-45-demasque', jours: 4, motif: "Tentative d'empoisonnement (démasqué par enquête)" }, recherches_vues: 1, recherche_apres_exec: [] },
  office_simple: { jours: 1, juge: "Peine d'office", motif: 'Vol' },
  seuil_ouvrir: { jours: 4, motifs: [3, 1], reporte: 2, total: 6, qualification: 'vol', statut: 'saisie' },
  seuil_prolonger: { jours_ajoutes: 0, reportes: 2, total: 8 }, jugement_non_plafonne: 5,
  juge: { assassinat: [1, 3], vol_soviet: [1, 2], seuil: [0, 8], urgence: [1, 365], amende_max: 750 },
  eu1: { renouvele: false, jours_restants: 7 }, eu2: { renouvele: true, jours_restants: 14, renouvellements: 1 },
  eu_echu_actif: false, eu_lever_echu: 'pas_en_vigueur', nuit_urgences: 1,
  reb1: { reussi: true, degats: 6, niveau: 94, bonus: 6, ajoutes: 0, proces: true },
  reb2: { reussi: false, grilles: null, qhs: false, hp: 65 },
  bonus_plafond: 25, reparation: { avant: 60, apres: 74, caisse_avant: 107940, caisse_apres: 107840, sans_argent: 87 }, nuit2: 0,
  banc_flagrant: 'BANC OK', banc_cacher: 'banc_ok_rien_ne_reste'
};

test('Plafonds 5 / 15 ; départ à la moitié ; pistes jusqu’au plafond (relevé de l’essai)', () => {
  assert.equal(RELEVE.lire.neutraliser.chances, chances(plafond('reussite'), 1, 3));
  assert.equal(RELEVE.lire.empoisonner.chances, chances(plafond('echec'), 0, 3));
  assert.equal(chances(15, 4, 4), 15);
  assert.equal(chances(5, 0, 4), 2.5);
  assert.match(sql, /v_n := CASE WHEN v_effr THEN 4 ELSE 3 END;/);
  assert.match(sql, /v_effr := f\.acte IN \('crocheter', 'forcer_porte', 'cambrioler', 'ramasser'\);/);
  assert.match(sql, /jsonb_array_length\(d\.informateurs\) > 0/);
  assert.match(sql, /FROM public\.actions_tracables a WHERE a\.auteur = f\.auteur/);
  assert.match(sql, /FROM public\.crim_traces_achat t WHERE t\.acheteur = f\.auteur/);
});

test('Enquête : 2 PA, une par jour et par plainte, message une seule fois (−20 DIS, −15 moral), réussite = peine doublée', () => {
  assert.equal(RELEVE.e1.averti, true);
  assert.equal(95 - RELEVE.e1.dis, 20);
  assert.equal(100 - RELEVE.e1.moral, 15);
  assert.equal(RELEVE.e1.mail, 1);
  assert.equal(RELEVE.e2, 'une_tentative_par_jour');
  assert.equal(RELEVE.e3.averti, false);
  assert.equal(RELEVE.e3.dis, RELEVE.e1.dis);
  assert.equal(RELEVE.e4.jours, 2 * 2);   // tentative d'empoisonnement 2 j (crime), doublée car démasquée par l'enquête
  assert.equal(RELEVE.e4.plainte_vise, RELEVE.e4.coupable);
  assert.deepEqual(RELEVE.e4.recherche_apres_exec, []);
  assert.match(sql, /\('enqueter_plainte', 2, 0\)/);
  assert.match(sql, /'Le commissaire ' \|\| a \|\| ' est sur vos traces\. Vous n''êtes pas identifié pour l''instant, mais vous n''avez plus droit à l''erreur\.'/);
  assert.match(sql, /crim_peine_office_interne\(f\.auteur, v_acte, true, f\.id, f\.ville\)/);
  assert.match(sql, /achat_requete_ouvrir_interne\(a, p_requete, 'enqueter_plainte', prm\)/);
});

test('Affaires des lots 2 à 5 enquêtables (vol, cambriolage, poison, explosifs, incendie) ; plainte contre X rattachée', () => {
  assert.deepEqual(RELEVE.plaintes, { jean_liee: true, mous_liee: true });
  assert.match(sql, /CASE f\.acte WHEN 'ramasser' THEN 'vol' WHEN 'cambrioler' THEN 'vol' WHEN 'voler' THEN 'vol'\s+WHEN 'crocheter' THEN 'effraction' WHEN 'forcer_porte' THEN 'effraction' ELSE f\.acte END/);
  assert.match(sql, /'indices', f\.indices - 'genre' - 'mode_arme'/);
  assert.deepEqual(RELEVE.lire.empoisonner.indices, { poison: 'ghb' });
  assert.ok(sql.includes("'crim_plainte_x_v1'"));
  for (const k of ['a_voler', 'a_cambrioler', 'a_empoisonner', 'a_utiliser_explosifs', 'a_incendier', 'i_poison', 'i_batiment']) assert.ok(js.includes(k + ':'), k);
});

test('Plus d’enquête automatique : minuit_decouverte_crimes neutralisée', () => {
  assert.deepEqual(RELEVE.bareme.minuit, { ok: true, decouvertes: 0 });
  assert.match(sql, /'decouvertes', 0, 'desactivee', 'criminalite_lot6_pas_d_enquete_automatique'/);
});

test('Barème unique : catégories 1 / 2 j, alias, onze barèmes rattachés, autres empires = Républia', () => {
  assert.deepEqual(RELEVE.bareme.categories, { crime: 2, delit: 1, crime_etat: 2, delit_grave: 1, delit_mineur: 1 });
  assert.match(core, /delit_grave:\s+\{ jours: 1,/);
  assert.match(core, /crime:\s+\{ jours: 2,/);
  assert.match(core, /crime_etat:\s+\{ jours: 2,/);
  assert.match(core, /assassiner_mains: 'assassinat', assassiner_arme: 'assassinat', assassiner_feu: 'assassinat', meurtre: 'assassinat'/);
  assert.equal(RELEVE.bareme.non_detectables, 0);
  assert.equal(RELEVE.bareme.assassiner_feu_soviet, 2);
  assert.equal(RELEVE.bareme.vol_narco, 1);
  assert.equal(RELEVE.bareme.canon_meurtre, 'assassinat');
  assert.match(sql, /'peine_jours_' \|\| c\.id \|\| '_' \|\| coalesce\(p_pays, 'republic'\)/);
  assert.ok(sql.includes("UPDATE public.infractions_empreinte SET empreinte = '" + RELEVE.bareme.empreinte + "'"));
  assert.ok(lire('outils/baseline/referentiels.json').includes('"reelle": "' + RELEVE.bareme.empreinte + '"'));
  // Plus de durées en dur : garde à vue, évasion, rébellion, résistance, convocations au barème.
  for (const m of ['crim_bareme_gav_v1', 'crim_bareme_gav2_v1', 'crim_bareme_gav3_v1', 'crim_bareme_evasion_v1', 'crim_bareme_evasion2_v1',
    'crim_bareme_resistance_v1', 'crim_bareme_resistance_total_v1', 'crim_bareme_conv1_v1', 'crim_bareme_conv3_v1']) assert.ok(sql.includes("'" + m + "'"), m);
  assert.deepEqual([RELEVE.bareme.gav, RELEVE.bareme.evasion, RELEVE.bareme.rebellion, RELEVE.bareme.resistance], [2, 2, 1, 2]);
});

test('Peines : simple sur le moment, doublée démasqué ; jugement d’office exécutable ; seuil du procès 4 j', () => {
  assert.equal(RELEVE.office_simple.jours, 1);
  assert.equal(RELEVE.bareme.crime_peine_vol_demasque.jours, 2);
  assert.equal(RELEVE.e4.recherches_vues, 1);   // visible par justice_recherches (chasse, patrouille)
  const s = seuil(6);
  assert.deepEqual([RELEVE.seuil_ouvrir.jours, RELEVE.seuil_ouvrir.reporte], [s.garde, s.reporte]);
  assert.deepEqual(RELEVE.seuil_ouvrir.motifs, [3, 1]);
  assert.equal(RELEVE.seuil_ouvrir.total, 6);
  assert.equal(RELEVE.seuil_prolonger.jours_ajoutes, seuil(2, 4).garde);
  assert.equal(RELEVE.seuil_prolonger.total, 8);
  assert.equal(RELEVE.jugement_non_plafonne, 5);
  assert.match(sql, /\('seuil_proces_jours', 4\)/);
  assert.match(sql, /'status', 'saisie', 'origine', 'seuil_proces'/);
});

test('Juge : ±50 % autour de la référence (somme d’un procès de seuil), liberté totale sous l’état d’urgence', () => {
  assert.deepEqual(RELEVE.juge.assassinat, bornesJuge(2));
  assert.deepEqual(RELEVE.juge.vol_soviet, bornesJuge(1));
  assert.deepEqual(RELEVE.juge.seuil, bornesSeuil(8, 4));
  assert.deepEqual(RELEVE.juge.urgence, [1, 365]);
  assert.equal((sql.match(/'crim_juge_bornes_v1'\);/g) || []).length, 3);
});

test('État d’urgence : 7 jours, renouvelable, levé à échéance par la passe de nuit', () => {
  assert.equal(RELEVE.eu1.jours_restants, 7);
  assert.equal(RELEVE.eu2.jours_restants, 14);
  assert.equal(RELEVE.eu2.renouvellements, 1);
  assert.equal(RELEVE.eu_echu_actif, false);
  assert.equal(RELEVE.nuit_urgences, 1);
  assert.match(sql, /v_paie := public\.payer_ordre\(v_moi, 'etat_urgence', 3, 0\);/);
  assert.match(sql, /v_pop := -\(floor\(random\(\) \* 15\)::integer \+ 5\);/);
  assert.match(politique, /texteUrgence\('uRenouveler'\)/);
});

test('Cellule : rébellion réussie abîme les grilles, matée sans dégât ni QHS ; bonus plafonné à 25 ; réparation 1/3 pour 100 FR', () => {
  assert.equal(RELEVE.reb1.niveau, 100 - RELEVE.reb1.degats);
  assert.equal(RELEVE.reb1.bonus, RELEVE.reb1.degats);
  assert.equal(RELEVE.reb2.grilles, null);
  assert.equal(RELEVE.reb2.qhs, false);
  assert.equal(RELEVE.bonus_plafond, Math.min(25, 100 - 60));
  assert.equal(RELEVE.reparation.apres - RELEVE.reparation.avant, 14);   // tranche de réparation posée (1/3 de 40 points de dégâts, arrondi)
  assert.equal(RELEVE.reparation.caisse_avant - RELEVE.reparation.caisse_apres, 100);
  assert.equal(RELEVE.reparation.sans_argent, 87);   // caisse à 50 FR : pas d'argent, pas de réparation
  assert.equal(RELEVE.nuit2, 0);                      // revendication nocturne : une réparation par nuit
  assert.doesNotMatch(sql.split('CREATE OR REPLACE FUNCTION public.detention_se_rebeller')[1].split('$$;')[0], /detention_transferer_qhs/);
  assert.match(sql, /PERFORM cron\.schedule\('crim_justice_nuit', '20 23 \* \* \*'/);
  assert.match(sql, /acte_nocturne_revendiquer\(v_pays, 'crim_grilles_reparation', g\.id, NULL\)/);
});

test('Bancs SQL obsolètes remis à jour (empoisonnement du lot 5) et rejoués en production', () => {
  const flag = lire('outils/bancs/banc-arrestations-flagrant-delit.sql');
  const cacher = lire('outils/bancs/banc-se-cacher.sql');
  assert.doesNotMatch(flag, /flagrant_delit_poser_interne\(n, 'tentative_empoisonnement'/);
  assert.match(flag, /crime_empoisonner\(text,uuid\)'::regprocedure\)\) > 0/);
  assert.doesNotMatch(cacher, /pas_cache' THEN RAISE EXCEPTION 'autre piece/);
  assert.match(cacher, /cachette consommee par l''empoisonnement/);
  assert.equal(RELEVE.banc_flagrant, 'BANC OK');
});

test('Écran : enquêtes du commissaire, pop-ups cpj-*, chances lues du serveur', () => {
  assert.match(justice, /globalThis\.RPCriminalite\.crimBoutonEnquetes\(\)/);
  assert.match(justice, /delete ids\[k\]/);
  assert.doesNotMatch(justice, /Transfere au QHS\. -25 PV/);
  const appels = [];
  const toasts = [];
  const dom = { innerHTML: '', textContent: '', classList: { add() {}, remove() {} } };
  const reponses = {
    crim_enquetes_lire: { ok: true, ville: 'capitale', pa: 2, affaires: [
      { affaire: 44, acte: 'neutraliser', jour: 1, victime: 'Jean Jaaj', masque: true, issue: 'reussite', indices: { arme: 'revolver' },
        chances: 3.33, pistes: { trace: true, rumeurs: false, informateur: false }, tentatives: 0, deja_aujourdhui: false },
      { affaire: 45, acte: 'empoisonner', jour: 1, victime: 'Moustafa Kheimal', masque: false, issue: 'echec', indices: { poison: 'ghb' },
        chances: 7.5, pistes: {}, tentatives: 1, deja_aujourdhui: true }] },
    crim_enqueter: { ok: true, reussi: true, coupable: 'Angie Porcelana', jours: 4 }
  };
  const g = {
    document: { getElementById: () => dom, readyState: 'loading', addEventListener() {} },
    state: { country: 'republic', inventory: [], char: { name: 'Moi' } },
    showToast: (t, b, ok) => toasts.push([t, b, ok]),
    sbRpc: async (fn, p) => { appels.push([fn, p]); return reponses[fn]; },
    crypto: { randomUUID: () => '00000000-0000-4000-8000-000000000000' }
  };
  g.window = g; g.globalThis = g;
  vm.runInNewContext(js.replace(/\(typeof window !== 'undefined' \? window : globalThis\);\s*$/, '(globalThis);'), g);
  assert.match(g.RPCriminalite.crimBoutonEnquetes(), /class="cpj-touche cpj-primaire"[\s\S]*Enquêter sur une plainte contre X \(2 PA\)/);
  assert.deepEqual(JSON.parse(JSON.stringify(g.RPCriminalite.ORDRES_JUSTICE.enqueter)), { fn: 'enqueter_plainte', label: 'Enquêter sur une plainte contre X', pa: 2, cost: 0 });
  return (async () => {
    await g.crimOuvrirEnquetes();
    assert.match(dom.innerHTML, /class="cpj-dialogue"/);
    assert.match(dom.innerHTML, /Agression — victime : Jean Jaaj[\s\S]*un individu masqué[\s\S]*arme : revolver[\s\S]*Pistes : trace[\s\S]*3\.33 %/);
    assert.match(dom.innerHTML, /Empoisonnement[\s\S]*poison : ghb[\s\S]*Déjà tenté aujourd’hui/);
    assert.doesNotMatch(dom.innerHTML, /Angie|genre/);
    await g.crimEnqueter(44);
    assert.deepEqual(JSON.parse(JSON.stringify(appels.at(-1))), ['crim_enqueter', { p_affaire: 44, p_requete: '00000000-0000-4000-8000-000000000000' }]);
    assert.equal(toasts.at(-1)[0], 'Coupable identifié');
    assert.match(toasts.at(-1)[1], /Angie Porcelana est démasqué\(e\)[\s\S]*4 jour/);
    reponses.crim_enqueter = { ok: false, raison: 'une_tentative_par_jour' };
    await g.crimEnqueter(45);
    assert.match(toasts.at(-1)[1], /Une seule tentative par jour et par plainte/);
  })();
});
