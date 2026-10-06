-- GRANT sur tables, colonnes et fonctions
-- ============================================================================
-- BASELINE Human Gambit -- domaine renseignement -- phase 70 : droits
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- DROITS SUR LES FUNCTIONS
GRANT EXECUTE ON FUNCTION public.agent_au_bureau_min_def(text,text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.agent_au_bureau_min_def(text,text) TO anon;
GRANT EXECUTE ON FUNCTION public.agent_au_bureau_min_def(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.agent_au_bureau_min_def(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.agent_au_bureau_min_def(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.agent_conseillere_observer(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.agent_conseillere_observer(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.agent_coordinateur_multimodal(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.agent_coordinateur_multimodal(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.agent_coordinateur_port(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.agent_coordinateur_port(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.agent_deposer(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.agent_deposer(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.agent_deposer(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.agent_garde_observer(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.agent_garde_observer(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.agent_portrait_chemin(text,text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.agent_portrait_chemin(text,text) TO anon;
GRANT EXECUTE ON FUNCTION public.agent_portrait_chemin(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.agent_portrait_chemin(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.agent_portrait_chemin(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.agent_position_effective(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.agent_position_effective(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.agent_position_effective(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.agent_prendre(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.agent_prendre(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.agent_prendre(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.agent_trace_deposer(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.agent_trace_deposer(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.agent_traducteur_ecouter(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.agent_traducteur_ecouter(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.agent_transferer(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.agent_transferer(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.agent_transferer(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.agents_couverture_de_mon_groupe() TO authenticated;
GRANT EXECUTE ON FUNCTION public.agents_couverture_de_mon_groupe() TO postgres;
GRANT EXECUTE ON FUNCTION public.agents_couverture_de_mon_groupe() TO service_role;
GRANT EXECUTE ON FUNCTION public.agents_couverture_ici() TO authenticated;
GRANT EXECUTE ON FUNCTION public.agents_couverture_ici() TO postgres;
GRANT EXECUTE ON FUNCTION public.agents_couverture_ici() TO service_role;
GRANT EXECUTE ON FUNCTION public.agents_de_mon_groupe() TO authenticated;
GRANT EXECUTE ON FUNCTION public.agents_de_mon_groupe() TO postgres;
GRANT EXECUTE ON FUNCTION public.agents_de_mon_groupe() TO service_role;
GRANT EXECUTE ON FUNCTION public.agents_renseignement_ici() TO authenticated;
GRANT EXECUTE ON FUNCTION public.agents_renseignement_ici() TO postgres;
GRANT EXECUTE ON FUNCTION public.agents_renseignement_ici() TO service_role;
GRANT EXECUTE ON FUNCTION public.cellule_alerter_ministre(text,text,text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.cellule_alerter_ministre(text,text,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.cellule_rapports_mes_cellules(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cellule_rapports_mes_cellules(integer) TO postgres;
GRANT EXECUTE ON FUNCTION public.cellule_rapports_mes_cellules(integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.cellule_renseignement_clore(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.cellule_renseignement_clore(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.cellule_renseignement_creer(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cellule_renseignement_creer(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.cellule_renseignement_creer(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.cellule_renseignement_mes_cellules() TO authenticated;
GRANT EXECUTE ON FUNCTION public.cellule_renseignement_mes_cellules() TO postgres;
GRANT EXECUTE ON FUNCTION public.cellule_renseignement_mes_cellules() TO service_role;
GRANT EXECUTE ON FUNCTION public.cellule_renseignement_terminer(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cellule_renseignement_terminer(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.cellule_renseignement_terminer(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.cellules_rapports_generer() TO postgres;
GRANT EXECUTE ON FUNCTION public.cellules_rapports_generer() TO service_role;
GRANT EXECUTE ON FUNCTION public.cellules_renseignement_balayer() TO postgres;
GRANT EXECUTE ON FUNCTION public.cellules_renseignement_balayer() TO service_role;
GRANT EXECUTE ON FUNCTION public.cellules_renseignement_collecter() TO postgres;
GRANT EXECUTE ON FUNCTION public.cellules_renseignement_collecter() TO service_role;
GRANT EXECUTE ON FUNCTION public.contre_espionnage_approfondir(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.contre_espionnage_approfondir(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.contre_espionnage_approfondir(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.contre_espionnage_dossiers() TO authenticated;
GRANT EXECUTE ON FUNCTION public.contre_espionnage_dossiers() TO postgres;
GRANT EXECUTE ON FUNCTION public.contre_espionnage_dossiers() TO service_role;
GRANT EXECUTE ON FUNCTION public.contre_espionnage_memoriser(text,text,integer,text,text,text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.contre_espionnage_memoriser(text,text,integer,text,text,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.contre_espionnage_modificateur(numeric,numeric,numeric) TO postgres;
GRANT EXECUTE ON FUNCTION public.contre_espionnage_modificateur(numeric,numeric,numeric) TO service_role;
GRANT EXECUTE ON FUNCTION public.contre_espionnage_niveau_connu(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.contre_espionnage_niveau_connu(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.contre_espionnage_palier(integer) TO postgres;
GRANT EXECUTE ON FUNCTION public.contre_espionnage_palier(integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.contre_espionnage_resoudre(text,text,text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.contre_espionnage_resoudre(text,text,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.convocation_douane_emettre(text,text,integer,integer,integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.convocation_douane_emettre(text,text,integer,integer,integer,integer) TO postgres;
GRANT EXECUTE ON FUNCTION public.convocation_douane_emettre(text,text,integer,integer,integer,integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.douane_autorite_de_perimetre(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.douane_autorite_de_perimetre(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.douane_caracteristiques_metier() TO postgres;
GRANT EXECUTE ON FUNCTION public.douane_caracteristiques_metier() TO service_role;
GRANT EXECUTE ON FUNCTION public.douane_effectifs_publics() TO authenticated;
GRANT EXECUTE ON FUNCTION public.douane_effectifs_publics() TO postgres;
GRANT EXECUTE ON FUNCTION public.douane_effectifs_publics() TO service_role;
GRANT EXECUTE ON FUNCTION public.douane_payer_effectifs(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.douane_payer_effectifs(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.douane_payer_effectifs(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.douane_pnj_id(text,text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.douane_pnj_id(text,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.filature_deplacements(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.filature_deplacements(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.filature_deplacements(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.renseignement_agents_disponibles() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.renseignement_agents_disponibles() TO anon;
GRANT EXECUTE ON FUNCTION public.renseignement_agents_disponibles() TO authenticated;
GRANT EXECUTE ON FUNCTION public.renseignement_agents_disponibles() TO postgres;
GRANT EXECUTE ON FUNCTION public.renseignement_agents_disponibles() TO service_role;
GRANT EXECUTE ON FUNCTION public.renseignement_autorite_de_perimetre(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.renseignement_autorite_de_perimetre(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.renseignement_mission_raccorder() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.renseignement_mission_raccorder() TO postgres;
GRANT EXECUTE ON FUNCTION public.renseignement_mission_raccorder() TO service_role;
GRANT EXECUTE ON FUNCTION public.renseignement_pnj_id(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.renseignement_pnj_id(text) TO service_role;

-- DROITS SUR LES TABLES
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.agent_tentatives TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.agent_tentatives TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.agents_renseignement TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.agents_renseignement TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.cellules_renseignement TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.cellules_renseignement TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.contre_espionnage_tentatives TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.contre_espionnage_tentatives TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.rapports_cellules TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.rapports_cellules TO service_role;
GRANT INSERT, SELECT, UPDATE ON TABLE public.rapports_renseignement TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.rapports_renseignement TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.rapports_renseignement TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.renseignement_couvertures TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.renseignement_couvertures TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.renseignement_identites_reelles TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.renseignement_identites_reelles TO service_role;
GRANT SELECT ON TABLE public.renseignements_connus TO anon;
GRANT SELECT ON TABLE public.renseignements_connus TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.renseignements_connus TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.renseignements_connus TO service_role;
