-- GRANT sur tables, colonnes et fonctions
-- ============================================================================
-- BASELINE Human Gambit -- domaine justice -- phase 70 : droits
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- DROITS SUR LES FUNCTIONS
GRANT EXECUTE ON FUNCTION public.affaire_autorite_de(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.affaire_autorite_de(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.affaire_autorite_de(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.affaire_delai_expire(jsonb,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.affaire_delai_expire(jsonb,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.affaire_infraction_de(jsonb) TO postgres;
GRANT EXECUTE ON FUNCTION public.affaire_infraction_de(jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.affaire_me_concerne(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.affaire_me_concerne(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.affaire_me_concerne(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.affaire_statut(text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.affaire_statut(text) TO anon;
GRANT EXECUTE ON FUNCTION public.affaire_statut(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.affaire_statut(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.affaire_statut(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.affaire_transmettre(text,text,text,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.affaire_transmettre(text,text,text,jsonb) TO postgres;
GRANT EXECUTE ON FUNCTION public.affaire_transmettre(text,text,text,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.arrestation_urgence(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.arrestation_urgence(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.arrestation_urgence(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.commissaire_enqueter(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.commissaire_enqueter(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.commissaire_enqueter(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.detention_active(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.detention_active(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.detention_active(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.detention_cible_pnj(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.detention_cible_pnj(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.detention_clore_evasion() TO authenticated;
GRANT EXECUTE ON FUNCTION public.detention_clore_evasion() TO postgres;
GRANT EXECUTE ON FUNCTION public.detention_clore_evasion() TO service_role;
GRANT EXECUTE ON FUNCTION public.detention_clore_interne(text,text,integer) TO postgres;
GRANT EXECUTE ON FUNCTION public.detention_clore_interne(text,text,integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.detention_clore_motif_eteint(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.detention_clore_motif_eteint(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.detention_clore_motif_eteint(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.detention_clore_purgee() TO authenticated;
GRANT EXECUTE ON FUNCTION public.detention_clore_purgee() TO postgres;
GRANT EXECUTE ON FUNCTION public.detention_clore_purgee() TO service_role;
GRANT EXECUTE ON FUNCTION public.detention_ouvrir_interne(text,text,integer,text,text,jsonb,text,text,jsonb) TO postgres;
GRANT EXECUTE ON FUNCTION public.detention_ouvrir_interne(text,text,integer,text,text,jsonb,text,text,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.detention_ouvrir_soi(text,integer,text,jsonb,boolean,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.detention_ouvrir_soi(text,integer,text,jsonb,boolean,jsonb) TO postgres;
GRANT EXECUTE ON FUNCTION public.detention_ouvrir_soi(text,integer,text,jsonb,boolean,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.detention_prolonger_interne(text,jsonb,boolean) TO postgres;
GRANT EXECUTE ON FUNCTION public.detention_prolonger_interne(text,jsonb,boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.detention_prolonger_soi(jsonb,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.detention_prolonger_soi(jsonb,boolean) TO postgres;
GRANT EXECUTE ON FUNCTION public.detention_prolonger_soi(jsonb,boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.detention_qhs_poser_interne(text,text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.detention_qhs_poser_interne(text,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.detention_reduire_peine(boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.detention_reduire_peine(boolean) TO postgres;
GRANT EXECUTE ON FUNCTION public.detention_reduire_peine(boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.detention_transferer_qhs(text,integer,text,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.detention_transferer_qhs(text,integer,text,jsonb) TO postgres;
GRANT EXECUTE ON FUNCTION public.detention_transferer_qhs(text,integer,text,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.detentions_pnj_liberer_echues() TO postgres;
GRANT EXECUTE ON FUNCTION public.detentions_pnj_liberer_echues() TO service_role;
GRANT EXECUTE ON FUNCTION public.dossier_acte_consigner(text,text,text,text,text,text,text,text,jsonb) TO postgres;
GRANT EXECUTE ON FUNCTION public.dossier_acte_consigner(text,text,text,text,text,text,text,text,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.dossiers_actes_append_only() TO postgres;
GRANT EXECUTE ON FUNCTION public.dossiers_actes_append_only() TO service_role;
GRANT EXECUTE ON FUNCTION public.dossiers_auditions_append_only() TO postgres;
GRANT EXECUTE ON FUNCTION public.dossiers_auditions_append_only() TO service_role;
GRANT EXECUTE ON FUNCTION public.enquete_garde_a_vue(text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.enquete_garde_a_vue(text,text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.enquete_garde_a_vue(text,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.fraude_electorale_sanctionner(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fraude_electorale_sanctionner(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.fraude_electorale_sanctionner(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.geoles_detenus(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.geoles_detenus(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.geoles_detenus(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.impact_deposer(text,text,text,integer,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.impact_deposer(text,text,text,integer,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.impact_deposer(text,text,text,integer,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.impact_marquer_traite(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.impact_marquer_traite(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.impact_marquer_traite(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.infraction_canonique(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.infraction_canonique(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.infraction_canonique(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.infraction_peine_bornes(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.infraction_peine_bornes(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.infraction_peine_bornes(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.infractions_empreinte_reelle() TO postgres;
GRANT EXECUTE ON FUNCTION public.infractions_empreinte_reelle() TO service_role;
GRANT EXECUTE ON FUNCTION public.juge_de_la_ville(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.juge_de_la_ville(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.juge_de_la_ville(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.juge_dossiers() TO authenticated;
GRANT EXECUTE ON FUNCTION public.juge_dossiers() TO postgres;
GRANT EXECUTE ON FUNCTION public.juge_dossiers() TO service_role;
GRANT EXECUTE ON FUNCTION public.juge_moi() TO postgres;
GRANT EXECUTE ON FUNCTION public.juge_moi() TO service_role;
GRANT EXECUTE ON FUNCTION public.juge_suite_apres_abandon(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.juge_suite_apres_abandon(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.juge_suite_apres_abandon(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_affaires_vivantes_avec_pv(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_affaires_vivantes_avec_pv(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_appel_juger(text,text,text,text,integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.justice_appel_juger(text,text,text,text,integer,integer) TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_appel_juger(text,text,text,text,integer,integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_appel_ouvrir(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.justice_appel_ouvrir(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_appel_ouvrir(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_avocat_commis(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_avocat_commis(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_cha_personnel(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_cha_personnel(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_condamner(text,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.justice_condamner(text,jsonb) TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_condamner(text,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_defense_part_relaxe() TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_defense_part_relaxe() TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_defense_taux(integer,integer,boolean) TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_defense_taux(integer,integer,boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_delai_jugement_jours() TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_delai_jugement_jours() TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_delais_echus() TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_delais_echus() TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_est_recherche(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_est_recherche(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_executer_condamnation(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.justice_executer_condamnation(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_executer_condamnation(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_fenetre_appel_jours() TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_fenetre_appel_jours() TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_indemnite_naitre(text,text,text,text,integer) TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_indemnite_naitre(text,text,text,text,integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_indemnite_par_jour() TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_indemnite_par_jour() TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_indemnites_payer_depuis_finances(text,boolean) TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_indemnites_payer_depuis_finances(text,boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_indemnites_sur_alimentation() TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_indemnites_sur_alimentation() TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_jours_purges(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_jours_purges(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_juge_titulaire(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_juge_titulaire(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_mes_indemnites() TO authenticated;
GRANT EXECUTE ON FUNCTION public.justice_mes_indemnites() TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_mes_indemnites() TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_peine_calcul(text,text,text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_peine_calcul(text,text,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_peine_proposer(text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.justice_peine_proposer(text,text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_peine_proposer(text,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_preuve_reelle(text,text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_preuve_reelle(text,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_prolonger_peine(text,jsonb,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.justice_prolonger_peine(text,jsonb,boolean) TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_prolonger_peine(text,jsonb,boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_recherches(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.justice_recherches(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_recherches(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_relaxer(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.justice_relaxer(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_relaxer(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_rendre_sentence(text,text,text,integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.justice_rendre_sentence(text,text,text,integer,integer) TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_rendre_sentence(text,text,text,integer,integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_seuil_procedure_simplifiee_jours() TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_seuil_procedure_simplifiee_jours() TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_statuts_publics() TO authenticated;
GRANT EXECUTE ON FUNCTION public.justice_statuts_publics() TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_statuts_publics() TO service_role;
GRANT EXECUTE ON FUNCTION public.parquet_abandonner(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.parquet_abandonner(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.parquet_abandonner(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.parquet_dossiers() TO authenticated;
GRANT EXECUTE ON FUNCTION public.parquet_dossiers() TO postgres;
GRANT EXECUTE ON FUNCTION public.parquet_dossiers() TO service_role;
GRANT EXECUTE ON FUNCTION public.parquet_enqueter(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.parquet_enqueter(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.parquet_enqueter(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.parquet_garde(text,text[]) TO postgres;
GRANT EXECUTE ON FUNCTION public.parquet_garde(text,text[]) TO service_role;
GRANT EXECUTE ON FUNCTION public.parquet_moi() TO authenticated;
GRANT EXECUTE ON FUNCTION public.parquet_moi() TO postgres;
GRANT EXECUTE ON FUNCTION public.parquet_moi() TO service_role;
GRANT EXECUTE ON FUNCTION public.parquet_non_lieu(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.parquet_non_lieu(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.parquet_non_lieu(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.parquet_poursuivre(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.parquet_poursuivre(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.parquet_poursuivre(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.parquet_site_competent(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.parquet_site_competent(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.parquet_transmettre_juge(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.parquet_transmettre_juge(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.parquet_transmettre_juge(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.plainte_defendre(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.plainte_defendre(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.plainte_defendre(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.plainte_deposer(text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.plainte_deposer(text,text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.plainte_deposer(text,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.plainte_instruire_interne(text,text,text,text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.plainte_instruire_interne(text,text,text,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.plainte_traiter(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.plainte_traiter(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.plainte_traiter(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.plaintes_epingler_verdict() TO postgres;
GRANT EXECUTE ON FUNCTION public.plaintes_epingler_verdict() TO service_role;
GRANT EXECUTE ON FUNCTION public.police_autorite_de_perimetre(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.police_autorite_de_perimetre(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.police_caracteristiques_metier() TO postgres;
GRANT EXECUTE ON FUNCTION public.police_caracteristiques_metier() TO service_role;
GRANT EXECUTE ON FUNCTION public.police_delai_intervention_secondes() TO postgres;
GRANT EXECUTE ON FUNCTION public.police_delai_intervention_secondes() TO service_role;
GRANT EXECUTE ON FUNCTION public.police_payer_effectifs(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.police_payer_effectifs(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.police_payer_effectifs(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.police_pnj_id(text,text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.police_pnj_id(text,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.police_signalement_resoudre(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.police_signalement_resoudre(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.police_signalement_resoudre(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.police_signaler(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.police_signaler(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.police_signaler(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.presidence_gracier(text,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.presidence_gracier(text,integer) TO postgres;
GRANT EXECUTE ON FUNCTION public.presidence_gracier(text,integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.pv_audition_realiser(text,text,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pv_audition_realiser(text,text,boolean) TO postgres;
GRANT EXECUTE ON FUNCTION public.pv_audition_realiser(text,text,boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.qhs_pouvoir(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.qhs_pouvoir(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.qhs_pouvoir(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.recherche_inscrire(jsonb,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recherche_inscrire(jsonb,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.recherche_inscrire(jsonb,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.recherche_retirer(text[],text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recherche_retirer(text[],text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.recherche_retirer(text[],text,text) TO service_role;

-- DROITS SUR LES SEQUENCES
GRANT SELECT, USAGE ON SEQUENCE public.justice_indemnites_rang_seq TO anon;
GRANT SELECT, USAGE ON SEQUENCE public.justice_indemnites_rang_seq TO authenticated;
GRANT SELECT, UPDATE, USAGE ON SEQUENCE public.justice_indemnites_rang_seq TO postgres;
GRANT SELECT, UPDATE, USAGE ON SEQUENCE public.justice_indemnites_rang_seq TO service_role;

-- DROITS SUR LES TABLES
GRANT SELECT ON TABLE public.actions_tracables TO anon;
GRANT DELETE, INSERT, SELECT ON TABLE public.actions_tracables TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.actions_tracables TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.actions_tracables TO service_role;
GRANT INSERT, SELECT, UPDATE ON TABLE public.demandes_grace TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.demandes_grace TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.demandes_grace TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.detentions TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.detentions TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.dossiers_auditions TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.dossiers_auditions TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.dossiers_judiciaires_actes TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.dossiers_judiciaires_actes TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.dossiers_judiciaires_actes_types TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.dossiers_judiciaires_actes_types TO service_role;
GRANT SELECT ON TABLE public.impacts_indices_attente TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.impacts_indices_attente TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.impacts_indices_attente TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.infractions TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.infractions TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.infractions_alias TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.infractions_alias TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.infractions_categories TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.infractions_categories TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.infractions_empreinte TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.infractions_empreinte TO service_role;
GRANT SELECT ON TABLE public.jugements TO anon;
GRANT SELECT ON TABLE public.jugements TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.jugements TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.jugements TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.justice_avocats_commis TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.justice_avocats_commis TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.justice_indemnites TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.justice_indemnites TO service_role;
GRANT SELECT ON TABLE public.niveaux_prison TO anon;
GRANT INSERT, SELECT, UPDATE ON TABLE public.niveaux_prison TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.niveaux_prison TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.niveaux_prison TO service_role;
GRANT SELECT ON TABLE public.plaintes_en_cours TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.plaintes_en_cours TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.plaintes_en_cours TO service_role;
GRANT SELECT ON TABLE public.prisonniers_qhs TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.prisonniers_qhs TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.prisonniers_qhs TO service_role;
GRANT INSERT, SELECT, UPDATE ON TABLE public.rumeurs_actives TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.rumeurs_actives TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.rumeurs_actives TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.signalements_police TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.signalements_police TO service_role;
GRANT SELECT ON TABLE public.vols_en_attente TO anon;
GRANT INSERT, SELECT, UPDATE ON TABLE public.vols_en_attente TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.vols_en_attente TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.vols_en_attente TO service_role;
-- DROIT AU NIVEAU COLONNE : invisible dans relacl, a ne jamais oublier
GRANT SELECT (autorite) ON TABLE public.detentions TO authenticated;
-- DROIT AU NIVEAU COLONNE : invisible dans relacl, a ne jamais oublier
GRANT SELECT (city) ON TABLE public.detentions TO authenticated;
-- DROIT AU NIVEAU COLONNE : invisible dans relacl, a ne jamais oublier
GRANT SELECT (country) ON TABLE public.detentions TO authenticated;
-- DROIT AU NIVEAU COLONNE : invisible dans relacl, a ne jamais oublier
GRANT SELECT (created_at) ON TABLE public.detentions TO authenticated;
-- DROIT AU NIVEAU COLONNE : invisible dans relacl, a ne jamais oublier
GRANT SELECT (date_fin_effective) ON TABLE public.detentions TO authenticated;
-- DROIT AU NIVEAU COLONNE : invisible dans relacl, a ne jamais oublier
GRANT SELECT (detention_precedente_id) ON TABLE public.detentions TO authenticated;
-- DROIT AU NIVEAU COLONNE : invisible dans relacl, a ne jamais oublier
GRANT SELECT (id) ON TABLE public.detentions TO authenticated;
-- DROIT AU NIVEAU COLONNE : invisible dans relacl, a ne jamais oublier
GRANT SELECT (issue_judiciaire) ON TABLE public.detentions TO authenticated;
-- DROIT AU NIVEAU COLONNE : invisible dans relacl, a ne jamais oublier
GRANT SELECT (jour_affaire) ON TABLE public.detentions TO authenticated;
-- DROIT AU NIVEAU COLONNE : invisible dans relacl, a ne jamais oublier
GRANT SELECT (jour_debut) ON TABLE public.detentions TO authenticated;
-- DROIT AU NIVEAU COLONNE : invisible dans relacl, a ne jamais oublier
GRANT SELECT (jour_fin) ON TABLE public.detentions TO authenticated;
-- DROIT AU NIVEAU COLONNE : invisible dans relacl, a ne jamais oublier
GRANT SELECT (jour_fin_effective) ON TABLE public.detentions TO authenticated;
-- DROIT AU NIVEAU COLONNE : invisible dans relacl, a ne jamais oublier
GRANT SELECT (mode_fin) ON TABLE public.detentions TO authenticated;
-- DROIT AU NIVEAU COLONNE : invisible dans relacl, a ne jamais oublier
GRANT SELECT (motifs) ON TABLE public.detentions TO authenticated;
-- DROIT AU NIVEAU COLONNE : invisible dans relacl, a ne jamais oublier
GRANT SELECT (nom) ON TABLE public.detentions TO authenticated;
-- DROIT AU NIVEAU COLONNE : invisible dans relacl, a ne jamais oublier
GRANT SELECT (provenance) ON TABLE public.detentions TO authenticated;
-- DROIT AU NIVEAU COLONNE : invisible dans relacl, a ne jamais oublier
GRANT SELECT (raison) ON TABLE public.detentions TO authenticated;
-- DROIT AU NIVEAU COLONNE : invisible dans relacl, a ne jamais oublier
GRANT SELECT (reduction_jours) ON TABLE public.detentions TO authenticated;
-- DROIT AU NIVEAU COLONNE : invisible dans relacl, a ne jamais oublier
GRANT SELECT (reliquat_jours) ON TABLE public.detentions TO authenticated;
-- DROIT AU NIVEAU COLONNE : invisible dans relacl, a ne jamais oublier
GRANT SELECT (ville_condamnation) ON TABLE public.detentions TO authenticated;
