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
GRANT EXECUTE ON FUNCTION public.justice_condamner(text,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.justice_condamner(text,jsonb) TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_condamner(text,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_executer_condamnation(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.justice_executer_condamnation(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_executer_condamnation(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_prolonger_peine(text,jsonb,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.justice_prolonger_peine(text,jsonb,boolean) TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_prolonger_peine(text,jsonb,boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_recherches(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.justice_recherches(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_recherches(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.justice_rendre_sentence(jsonb,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.justice_rendre_sentence(jsonb,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.justice_rendre_sentence(jsonb,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.plainte_classer_ministere(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.plainte_classer_ministere(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.plainte_classer_ministere(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.plainte_defendre(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.plainte_defendre(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.plainte_defendre(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.plainte_deposer(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.plainte_deposer(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.plainte_deposer(text,text) TO service_role;
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
GRANT EXECUTE ON FUNCTION public.police_payer_effectifs(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.police_payer_effectifs(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.police_payer_effectifs(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.police_pnj_id(text,text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.police_pnj_id(text,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.presidence_gracier(text,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.presidence_gracier(text,integer) TO postgres;
GRANT EXECUTE ON FUNCTION public.presidence_gracier(text,integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.qhs_pouvoir(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.qhs_pouvoir(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.qhs_pouvoir(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.recherche_inscrire(jsonb,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recherche_inscrire(jsonb,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.recherche_inscrire(jsonb,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.recherche_retirer(text[],text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recherche_retirer(text[],text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.recherche_retirer(text[],text,text) TO service_role;

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
GRANT SELECT ON TABLE public.impacts_indices_attente TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.impacts_indices_attente TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.impacts_indices_attente TO service_role;
GRANT SELECT ON TABLE public.jugements TO anon;
GRANT SELECT ON TABLE public.jugements TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.jugements TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.jugements TO service_role;
GRANT SELECT ON TABLE public.niveaux_prison TO anon;
GRANT INSERT, SELECT, UPDATE ON TABLE public.niveaux_prison TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.niveaux_prison TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.niveaux_prison TO service_role;
GRANT INSERT, SELECT, UPDATE ON TABLE public.plaintes_en_cours TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.plaintes_en_cours TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.plaintes_en_cours TO service_role;
GRANT SELECT ON TABLE public.prisonniers_qhs TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.prisonniers_qhs TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.prisonniers_qhs TO service_role;
GRANT INSERT, SELECT, UPDATE ON TABLE public.rumeurs_actives TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.rumeurs_actives TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.rumeurs_actives TO service_role;
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
