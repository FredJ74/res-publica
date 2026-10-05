-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913182154
-- Nom original      : chantier_c_miroir_complet_et_fail_closed
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-13 18:21:54 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 6e1fa20135fafd934c3827805b7b3fd2
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
-- CHANTIER C — LE MIROIR DES COUTS DEVIENT COMPLET, ET LE REFUS DEVIENT LA REGLE
-- 13 septembre 2026.
-- ============================================================================
-- CE QUI ETAIT RISQUE. Le miroir ne contenait que les ordres PAYANTS : un ordre
-- absent etait donc soit gratuit, soit inconnu, sans moyen de les distinguer. On
-- laissait donc passer les inconnus, en les journalisant. Un ordre payant ajoute
-- demain dans data.js sans regeneration du miroir aurait echappe au controle.
--
-- LE CORRECTIF. On miroite AUSSI les ordres gratuits (0/0). « Connu et gratuit »
-- devient alors distinguable de « inconnu », et l'inconnu peut etre refuse sans
-- refuser le gratuit. 396 triples, 376 ordres.
--
-- QUATRE ORDRES NE VIVENT PAS DANS data.js -- acte_officiel, demander_mariage,
-- demander_naturalisation, officialiser_mariage sont declares en dur dans
-- plateau-politique.js. Les oublier aurait casse l'etat civil des le premier
-- refus. Le generateur les capture desormais (voir generer_ordres_couts.py).
--
-- LE 373e ORDRE, ENFIN IDENTIFIE : 'contrebande' n'est pas un ordre. Il
-- n'apparait que dans un COMMENTAIRE de data.js:3739, qui documente le retrait
-- de l'ordre « Contacter reseau » le 30 aout 2026. L'expression reguliere de la
-- cartographie initiale lisait le commentaire. La couverture reelle est donc
-- complete, et l'ecart n'etait qu'un artefact de mesure.

INSERT INTO public.ordres_couts (fn, pa, cost) VALUES
('accepter_incorporation',0,0),('acheter_accessoire_personnalise',0,0),('acheter_armoire_souvenirs',0,0),('acheter_sels_ammoniaque',0,0),('adresse_a_la_nation',0,0),('aller_douanes_aeroport',0,0),('amender_projet',0,0),('annuler_non_renouvellement_licence',0,0),('blanchiment',0,0),('calendrier_elections',0,0),('compte_offshore',0,0),('conseil_entraineur_adjoint',0,0),('construire_sur_terrain',0,0),('consulter_administration_port',0,0),('consulter_archives_notariales',0,0),('consulter_archives_presse',0,0),('consulter_budget_club',0,0),('consulter_bureau_president',0,0),('consulter_caisse_commissariat',0,0),('consulter_caisse_usine',0,0),('consulter_carte_commerce',0,0),('consulter_dossier_notarial',0,0),('consulter_dossiers_urbanisme',0,0),('consulter_effectifs_douane',0,0),('consulter_elections',0,0),('consulter_etat_civil',0,0),('consulter_faits_armes',0,0),('consulter_indices_locaux',0,0),('consulter_mandats_maires',0,0),('consulter_manifeste',0,0),('consulter_offres_emploi',0,0),('consulter_organigramme_mairie',0,0),('consulter_organigramme_supporters',0,0),('consulter_organigramme_syndicat',0,0),('consulter_palmares',0,0),('consulter_personnalites_musee',0,0),('consulter_stock_usine',0,0),('demandes_naturalisation',0,0),('demissionner_emploi_bne',0,0),('diplomatie_bilaterale',0,0),('diviser_construction',0,0),('dormir_chambre',0,0),('ecouter_rumeurs',0,0),('effort_national',0,0),('emprunter_construction',0,0),('etat_civil',0,0),('faire_achats_marche',0,0),('gerer_budget_caserne',0,0),('gerer_commerce',0,0),('gerer_detachement',0,0),('gerer_effectifs_douane',0,0),('gerer_effectifs_police',0,0),('gerer_finances',0,0),('gerer_fonds_commerce',0,0),('gerer_informateurs',0,0),('gerer_logement_social',0,0),('gerer_logistique_port',0,0),('gerer_lot_loue',0,0),('gerer_offres_transfert',0,0),('gerer_salaires_club',0,0),('gerer_visites_chambre',0,0),('gestion_manifestations',0,0),('gestion_premier_ministre',0,0),('gestion_qhs',0,0),('greve_faim',0,0),('greve_generale_retirer',0,0),('greve_terminer',0,0),('imprimer_tracts_choix',0,0),('inspecter_troupes',0,0),('manger_ration',0,0),('marchandises_non_reclamees',0,0),('mobilisation_nationale',0,0),('modifier_plan_chantier',0,0),('observer_match',0,0),('offrir_tournee',0,0),('ouvrir_chambres_clinique',0,0),('passer_douanes_aeroport',0,0),('payer_versement_chantier',0,0),('plainte',0,0),('postes_par_decret',0,0),('pouls_populaire',0,0),('pouvoirs_exceptionnels',0,0),('produire_arme',0,0),('produire_commerce',0,0),('racheter_entreprise',0,0),('reclamer_heritage',0,0),('reconfigurer_lots',0,0),('regarder_live',0,0),('registre_assemblee',0,0),('relations_bilaterales',0,0),('renseignement_transport_intl',0,0),('retirer_armes_militaires',0,0),('retirer_explosifs_militaires',0,0),('se_porter_candidat',0,0),('se_renseigner',0,0),('se_reposer',0,0),('societe_ecran',0,0),('solliciter_audience_president',0,0),('tableau_effort_guerre',0,0),('tenue_match',0,0),('travailler_chantier',0,0),('vendre_bois_imprimerie',0,0),('vendre_materiaux_chantier',0,0),('vendre_matiere_commerce',0,0),('vendre_matiere_usine',0,0),('vendre_ressource_medicale',0,0),('vente_directe_usine',0,0),('voir_ma_section',0,0),('voter_election',0,0),('voter_loi',0,0)
ON CONFLICT (fn, pa, cost) DO NOTHING;

-- Empreinte du miroir attendu, calculee par le generateur sur les memes sources.
-- Le banc la relit et la compare a celle du contenu REEL : une declaration
-- ajoutee dans data.js sans regeneration fait diverger les deux.
CREATE TABLE IF NOT EXISTS public.ordres_couts_empreinte (
  seul boolean PRIMARY KEY DEFAULT true CHECK (seul),
  empreinte text NOT NULL, pose_le timestamptz DEFAULT now()
);
ALTER TABLE public.ordres_couts_empreinte ENABLE ROW LEVEL SECURITY;
INSERT INTO public.ordres_couts_empreinte (seul, empreinte) VALUES (true, 'ad84cdcc2905b3d7')
ON CONFLICT (seul) DO UPDATE SET empreinte = excluded.empreinte, pose_le = now();

-- ============================================================================
-- FAIL CLOSED : un ordre inconnu est desormais REFUSE, et toujours journalise.
CREATE OR REPLACE FUNCTION public.payer_ordre(
  p_acteur text, p_fn text, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_fn text := coalesce(nullif(btrim(coalesce(p_fn,'')), ''), '(non transmis)');
  v_connu boolean; v_valide boolean;
  v_pa integer; v_liquide numeric; v_arg numeric;
  v_compte_id text; v_solde numeric := 0;
  v_pris_liquide numeric; v_pris_national numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF coalesce(p_pa, 0) < 0 OR coalesce(p_cost, 0) < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_negatif');
  END IF;

  SELECT EXISTS (SELECT 1 FROM public.ordres_couts o WHERE o.fn = v_fn) INTO v_connu;

  IF NOT v_connu THEN
    -- On journalise AVANT de refuser : c'est ce journal qui dira quel ordre a
    -- ete ajoute sans regenerer le miroir, plutot qu'un ticket sans indice.
    INSERT INTO public.ordres_couts_inconnus (fn, pa, cost)
    VALUES (v_fn, coalesce(p_pa,0), coalesce(p_cost,0))
    ON CONFLICT (fn) DO UPDATE SET occurrences = public.ordres_couts_inconnus.occurrences + 1;
    RETURN jsonb_build_object('ok', false, 'raison', 'ordre_inconnu', 'fn', v_fn);
  END IF;

  SELECT EXISTS (SELECT 1 FROM public.ordres_couts o
                 WHERE o.fn = v_fn AND o.pa = coalesce(p_pa,0) AND o.cost = coalesce(p_cost,0))
    INTO v_valide;
  IF NOT v_valide THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_non_declare',
                              'fn', v_fn, 'pa', p_pa, 'cost', p_cost);
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
  IF coalesce(v_liquide,0) + v_solde < coalesce(p_cost, 0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants',
                              'disponible', coalesce(v_liquide,0) + v_solde);
  END IF;

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