-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913134422
-- Nom original      : chantier_c_paiement_ordres_autoritaire
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-13 13:44:22 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 2a210acdfa1f8abdaf3f472f8740c717
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- ============================================================================
-- CHANTIER C / PHASE 1 — LE PAIEMENT D'UN ORDRE DEVIENT AUTORITAIRE
-- 13 septembre 2026.
-- ============================================================================
-- CE QUI ETAIT OUVERT. deduireCoutOrdre() (plateau-core.js) est le passage
-- oblige de 268 sites du jeu : elle verifie les PA et les fonds, puis preleve.
-- Tout cela se passait DANS LE NAVIGATEUR. Le joueur decidait donc lui-meme ce
-- que son action lui coutait, et rien ne l'empechait d'annoncer 0 PA et 0 FR
-- pour un ordre a 3 PA et 8 000 FR -- ni, plus simplement, de ne jamais appeler
-- la fonction.
--
-- LA BRIQUE EST DEJA LA : on ne cree pas un second circuit economique, on rend
-- autoritaire celui qui existe. Un seul point de bascule cote client couvre les
-- 268 sites.
--
-- CE QUE LE SERVEUR SAIT, ET COMMENT. Il ne peut pas lire data.js : on en extrait
-- donc les couts declares, non par expression reguliere mais en CHARGEANT le vrai
-- fichier dans un moteur JS (voir .scratch/generer_ordres_couts.py, rejouable).
-- 848 declarations parcourues -- pieces, contextes de batiment, surcharges de
-- piece et menu des organisations -- soit 372 ordres distincts.
--
-- SEULS LES ORDRES PAYANTS SONT MIROITES (282 triples). Un ordre gratuit partout
-- n'a rien a proteger ; et un ordre payant reste detecte meme si le client
-- annonce 0, puisque la verification porte sur « cet ordre a-t-il des couts
-- declares ? » avant de verifier « celui-ci en fait-il partie ? ».
--
-- DIX ORDRES COUTENT LEGITIMEMENT DES PRIX DIFFERENTS SELON LE LIEU
-- (acheter_terrain va de 3 500 a 36 000 FR, se_nourrir de 8 a 30). On accepte
-- donc tout couple DECLARE pour cet ordre. Residu assume et mesure : sur ces dix
-- ordres-la, un joueur peut reclamer le tarif le moins cher de la liste. C'est
-- infiniment moins que « tout gratuit », et cela se refermera en miroitant aussi
-- la piece -- ce qui suppose de transmettre le lieu, hors de cette phase.

CREATE TABLE IF NOT EXISTS public.ordres_couts (
  fn   text    NOT NULL,
  pa   integer NOT NULL,
  cost integer NOT NULL,
  PRIMARY KEY (fn, pa, cost)
);
COMMENT ON TABLE public.ordres_couts IS
  'Miroir des couts declares dans data.js. Genere par .scratch/generer_ordres_couts.py, jamais saisi a la main.';

-- Table fermee : elle ne sert qu'a payer_ordre (SECURITY DEFINER).
ALTER TABLE public.ordres_couts ENABLE ROW LEVEL SECURITY;

TRUNCATE public.ordres_couts;
INSERT INTO public.ordres_couts (fn, pa, cost) VALUES
('acheter_bombe_illegale',2,0),('acheter_criee',1,0),('acheter_entreprise',3,8000),('acheter_ghb',1,300),('acheter_gilet',1,600),('acheter_polonium',2,600),('acheter_relique',1,500),('acheter_ressources_entrepot',1,0),('acheter_terrain',2,3500),('acheter_terrain',2,18000),('acheter_terrain',2,21600),('acheter_terrain',2,22200),('acheter_terrain',2,25000),('acheter_terrain',2,25800),('acheter_terrain',2,26400),('acheter_terrain',2,27600),('acheter_terrain',2,30000),('acheter_terrain',2,33000),('acheter_terrain',2,36000),('acheter_vipere',1,350),('acte_officiel_juge',1,0),('acte_officiel_mairie',1,0),('acte_officiel_notaire',1,100),('acte_rachat_entreprise_preemption',1,0),('activer_cessez_le_feu',2,0),('affecter_engage',2,0),('annuler_poursuites',2,0),('appeler_police_terrain',1,0),('archives',1,0),('archives_police',1,0),('arreter',3,500),('article',1,500),('assigner_mission',1,0),('banquet_diplo',3,2000),('blocus_portuaire',3,0),('boire_verre',0,50),('bourrer_urnes',1,0),('cambrioler_caisse_commissariat',3,0),('campagne_securite',2,500),('censurer_media',2,0),('centre_anti_poison',1,60),('centre_anti_poison',1,150),('choisir_accessoire_club',1,0),('choisir_arme',1,0),('choisir_suite',1,0),('commanditer_sondage',1,200),('conference_presse',2,0),('consommer_buvette',1,50),('consulter_carte_commerce',1,0),('consulter_classement_joueurs_club',0,75),('consulter_dossiers_gouv',2,0),('consulter_info_4',1,0),('consulter_lobbyiste',1,150),('consulter_registre_armes',1,0),('contester_resultats',2,200),('contrebande_port',3,0),('controler_caisse_douane',1,0),('corrompre_chantier',2,1500),('corrompre_douanier',1,300),('corrompre_fonct',2,200),('corrompre_fonct',3,500),('corrompre_fonct',3,1500),('corrompre_fonctionnaire_permis',2,800),('corrompre_gardien',2,800),('corrompre_homologue_local',2,800),('corrompre_journaliste',2,500),('corrompre_rdv_notaire',2,800),('declencher_election_club',1,0),('declencher_election_syndicat',1,0),('declencher_vote_confiance',3,0),('defense',2,300),('deliberer_loge',2,0),('demander_asile_politique',2,0),('demander_audience_ambassadeur',1,0),('demander_autorisation_manifester',1,0),('demander_divorce',1,200),('demander_juge_instruction',1,0),('demander_logement_social',1,0),('demander_non_renouvellement_licence',1,0),('demander_parler_loge',1,0),('dementi',2,0),('demettre_lieutenant',2,0),('deposer_demande_permis',2,0),('deposer_petite_annonce',1,0),('diner_affaires',2,150),('diner_affaires',2,300),('donner_argent_pnj',1,0),('donner_conf',2,0),('ecouter_rumeurs',1,0),('emprunter',1,0),('emprunter_prive',1,0),('engager_officier',2,0),('entrainer_section',2,0),('equiper_section',1,0),('escort_piege',3,800),('etouffer',1,1000),('expedier_colis',2,200),('fabriquer_armoire_souvenirs',3,0),('fabriquer_scandale',3,800),('faire_disparaitre_cadavre',2,0),('faire_don',1,200),('falsifier_document',3,300),('falsifier_listes_electorales',2,0),('financer_communal',1,0),('financer_oeuvre_culturelle',1,600),('fixer_impots_locaux',2,0),('fixer_prix_achat_entrepot',1,0),('fixer_prix_vente_directe',1,0),('fixer_repartition_production',1,0),('fuite_info',3,0),('gerer_ambassades',2,0),('gerer_box',1,0),('gerer_candidature_directeur_entrepot',1,0),('gerer_candidature_maire_adjoint',1,0),('gerer_chef_douanes',1,0),('gerer_commandement',1,0),('gerer_couvre_feu',2,0),('gerer_finances',1,0),('gerer_juges',1,0),('gerer_local',1,0),('gerer_testament',1,200),('gestion_industrielle_portuaire',1,0),('gracier',2,0),('greve_generale_appeler',1,0),('greve_lancer',1,0),('imprimer_tracts_calomnieux',1,150),('imprimer_tracts_electoraux',1,150),('inspecter_cargaisons',2,0),('interroger',2,0),('interview',1,0),('investir',1,0),('lancer_rumeur_cible',1,0),('louer_box',1,0),('louer_local',1,0),('louer_lot_ici',1,0),('marchander_vote',1,100),('marche_noir',1,0),('mener_enquete',2,250),('mobiliser',2,0),('mobiliser_police',2,0),('negocier_squatteurs',1,0),('nommer_capitaine',2,0),('nommer_commissaire',3,0),('nommer_directeur_entrepot',3,0),('nommer_directeur_pharma',3,0),('nommer_directeur_raffinerie',3,0),('nommer_directeur_tabac_alcools',3,0),('nommer_lieutenant',2,0),('nommer_ministre_pm',2,0),('objet_trouve',1,0),('observer_debats',1,0),('officialiser_transaction',1,0),('orga_anatheme',2,200),('orga_audit',2,500),('orga_benediction',2,200),('orga_blanchiment',2,0),('orga_blocus',3,1000),('orga_campagne_presse',2,500),('orga_coalition',1,0),('orga_collecte',2,0),('orga_contrat',2,2000),('orga_contrebande',3,500),('orga_cooptation',2,1000),('orga_coup_force',4,2000),('orga_dividendes',1,0),('orga_election_loge',1,0),('orga_excommunier',1,0),('orga_fake_news',2,300),('orga_financer_cand',2,5000),('orga_fusion',2,5000),('orga_hooliganisme',3,0),('orga_intimidation',2,0),('orga_kompromat_loge',3,0),('orga_meeting',3,500),('orga_motion_supporters',1,0),('orga_pelerinage',3,1000),('orga_petition',2,0),('orga_racket',2,0),('orga_rehabilitation',3,1000),('orga_reseau',2,300),('orga_rituel',2,500),('orga_scoop',2,0),('orga_silence',3,2000),('orga_torpiller',3,1000),('organiser_boycott',2,0),('organiser_chasse_homme',3,300),('organiser_filature',2,150),('organiser_manifestation',2,0),('organiser_manifestation_syndicat',2,0),('organiser_reception_diplomatique',2,1200),('ouvrir_enquete',2,0),('parier_match',1,0),('pelerin',2,0),('pilotage_fiscal_budgetaire',2,0),('plainte',1,0),('plainte_police',1,0),('postuler',2,0),('postuler_president_club',2,0),('preempter_entreprise',2,0),('prendre_avion',2,300),('prendre_bateau',5,100),('prendre_bus_taxi',1,150),('prendre_licence_sportive',1,150),('prendre_train',2,75),('presenter_autorisation_coffre',1,0),('prier',1,0),('produire_alcool',1,0),('produire_carburant',1,0),('produire_desinfectant',1,0),('produire_fuite',2,0),('produire_medicaments',1,0),('produire_tabac',1,0),('projet_loi',1,0),('propagande_etat',3,500),('proposer_abrogation',1,0),('proposer_grace',2,0),('proposer_transfert',2,0),('proposer_treve',3,0),('racheter_terrain',2,0),('reception_etat',2,1000),('receptionner_commande',1,0),('recherche_militaire',2,0),('recolter_matiere',2,0),('recruter_compagnie',3,0),('recruter_douanier',1,0),('recruter_douanier_cynophile',1,0),('recruter_etud',2,0),('recruter_info_4',3,0),('recruter_informateur_2',1,400),('recruter_informateur_pnj',1,150),('recruter_policier',1,0),('recruter_policier_cynophile',1,0),('recruter_section',2,0),('rejoindre_club_supporters',1,50),('remonter_renseignement',1,0),('rendre_sentence',2,0),('renseignement',3,500),('repartir_armement',1,0),('repartition_budget_local',2,0),('requete_avocat',1,0),('reserver_chambre_hotel',0,60),('reserver_chambre_hotel',0,80),('reserver_salle_reception',1,0),('reveiller_depute',1,0),('revoquer_commissaire',1,0),('revoquer_directeur_entrepot',1,0),('revoquer_directeur_pharma',1,0),('revoquer_directeur_raffinerie',1,0),('revoquer_directeur_tabac_alcools',1,0),('revoquer_maire_adjoint',1,0),('revoquer_ministre_pm',1,0),('se_confesser',2,0),('se_former',2,100),('se_justifier',1,0),('se_nourrir',0,8),('se_nourrir',1,30),('se_presenter_affectation',1,0),('se_rebeller',2,0),('se_syndiquer',1,50),('service_etage',0,150),('signer_compromis',2,1000),('sinscrire_demandeur_emploi',1,0),('soin_public',0,25),('soins',0,100),('soins_discrets',1,800),('soins_urgence',0,500),('sponsoriser_club',1,0),('stage_caserne',3,0),('subvention',2,0),('taxi_caserne',1,200),('taxi_qhs',1,200),('tentative_evasion',3,0),('tenue_entrainement',2,0),('traiter_demandes_logement_social',1,0),('traiter_demandes_permis',1,0),('traiter_engagements',1,0),('transfert_clinique_privee',0,1000),('transfert_compromis',1,0),('truquer_depouillement',2,0),('virement_usine_ministere',1,0),('visiter_prisonnier',1,0),('voler_materiel_chantier',2,0);

-- Journal des ordres inconnus du miroir : plutot que de refuser un ordre qu'on
-- ne connait pas -- et donc de casser une fonctionnalite -- on laisse passer et
-- on l'inscrit ici. C'est la liste de travail pour refermer la derniere maille,
-- avec des faits plutot que des suppositions.
CREATE TABLE IF NOT EXISTS public.ordres_couts_inconnus (
  fn text PRIMARY KEY, pa integer, cost integer,
  vu_le timestamptz DEFAULT now(), occurrences bigint DEFAULT 1
);
ALTER TABLE public.ordres_couts_inconnus ENABLE ROW LEVEL SECURITY;

-- ============================================================================
CREATE OR REPLACE FUNCTION public.payer_ordre(
  p_acteur text, p_fn text, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_connu boolean; v_valide boolean;
  v_pa integer; v_liquide numeric; v_arg numeric;
  v_compte_id text; v_solde numeric := 0;
  v_pris_liquide numeric; v_pris_national numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF coalesce(p_pa, 0) < 0 OR coalesce(p_cost, 0) < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_negatif');
  END IF;

  -- Le cout annonce est-il un cout REELLEMENT declare pour cet ordre ?
  SELECT EXISTS (SELECT 1 FROM public.ordres_couts o WHERE o.fn = p_fn) INTO v_connu;
  IF v_connu THEN
    SELECT EXISTS (SELECT 1 FROM public.ordres_couts o
                   WHERE o.fn = p_fn AND o.pa = coalesce(p_pa,0) AND o.cost = coalesce(p_cost,0))
      INTO v_valide;
    IF NOT v_valide THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cout_non_declare',
                                'fn', p_fn, 'pa', p_pa, 'cost', p_cost);
    END IF;
  ELSE
    INSERT INTO public.ordres_couts_inconnus (fn, pa, cost)
    VALUES (p_fn, coalesce(p_pa,0), coalesce(p_cost,0))
    ON CONFLICT (fn) DO UPDATE SET occurrences = public.ordres_couts_inconnus.occurrences + 1;
  END IF;

  SELECT pa, liquide, arg INTO v_pa, v_liquide, v_arg
  FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_pa IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  SELECT id, solde INTO v_compte_id, v_solde FROM public.comptes_bancaires
  WHERE personnage = p_acteur AND banque = 'nationale' FOR UPDATE;
  v_solde := coalesce(v_solde, 0);

  IF v_pa < coalesce(p_pa, 0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'pa_reel', v_pa);
  END IF;

  -- Meme regle que getFondsDisponiblesOrdinaires() : liquide + Banque nationale,
  -- jamais Helvetia ni un placement.
  IF coalesce(v_liquide,0) + v_solde < coalesce(p_cost, 0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants',
                              'disponible', coalesce(v_liquide,0) + v_solde);
  END IF;

  -- Meme ordre de ponction que debiterFondsOrdinaires() : le liquide d'abord.
  v_pris_liquide := least(coalesce(v_liquide,0), coalesce(p_cost,0));
  v_pris_national := coalesce(p_cost,0) - v_pris_liquide;

  UPDATE public.personnages_donnees
     SET pa = v_pa - coalesce(p_pa,0),
         liquide = coalesce(v_liquide,0) - v_pris_liquide,
         arg = coalesce(v_arg,0) - coalesce(p_cost,0)
   WHERE name = p_acteur;

  IF v_pris_national > 0 AND v_compte_id IS NOT NULL THEN
    UPDATE public.comptes_bancaires SET solde = solde - v_pris_national,
           updated_at = now() WHERE id = v_compte_id;
  END IF;

  RETURN jsonb_build_object(
    'ok', true, 'pa', v_pa - coalesce(p_pa,0),
    'liquide', coalesce(v_liquide,0) - v_pris_liquide,
    'arg', coalesce(v_arg,0) - coalesce(p_cost,0),
    'solde_national', v_solde - v_pris_national,
    'pa_preleves', coalesce(p_pa,0), 'montant_preleve', coalesce(p_cost,0));
END;
$$;
REVOKE ALL ON FUNCTION public.payer_ordre(text, text, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.payer_ordre(text, text, integer, integer) TO authenticated;