-- Cles primaires, unicite, validation, cles etrangeres
-- ============================================================================
-- BASELINE Human Gambit -- domaine renseignement -- phase 30 : contraintes
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- CLES PRIMAIRES
ALTER TABLE public.agent_tentatives ADD CONSTRAINT agent_tentatives_pkey PRIMARY KEY (agent_id, cible, canal, jour_paris);
ALTER TABLE public.agents_renseignement ADD CONSTRAINT agents_renseignement_pkey PRIMARY KEY (id);
ALTER TABLE public.cellules_renseignement ADD CONSTRAINT cellules_renseignement_pkey PRIMARY KEY (id);
ALTER TABLE public.contre_espionnage_tentatives ADD CONSTRAINT contre_espionnage_tentatives_pkey PRIMARY KEY (pays, couverture, jour_paris);
ALTER TABLE public.rapports_cellules ADD CONSTRAINT rapports_cellules_pkey PRIMARY KEY (cellule_id, jour);
ALTER TABLE public.rapports_renseignement ADD CONSTRAINT rapports_renseignement_pkey PRIMARY KEY (id);
ALTER TABLE public.renseignement_couvertures ADD CONSTRAINT renseignement_couvertures_pkey PRIMARY KEY (pays, nom);
ALTER TABLE public.renseignement_identites_reelles ADD CONSTRAINT renseignement_identites_reelles_pkey PRIMARY KEY (role);
ALTER TABLE public.renseignements_connus ADD CONSTRAINT renseignements_connus_pkey PRIMARY KEY (id);

-- CONTRAINTES DE VALIDATION
ALTER TABLE public.agents_renseignement ADD CONSTRAINT agent_position_deux_etats CHECK ((((leader_courant IS NOT NULL) AND (ville IS NULL)) OR (leader_courant IS NULL)));
ALTER TABLE public.agents_renseignement ADD CONSTRAINT agents_renseignement_dup_check CHECK (((dup >= 1) AND (dup <= 20)));
ALTER TABLE public.agents_renseignement ADD CONSTRAINT agents_renseignement_role_check CHECK ((role = ANY (ARRAY['conseiller'::text, 'traducteur'::text, 'garde'::text, 'coordinateur'::text])));
ALTER TABLE public.agents_renseignement ADD CONSTRAINT agents_renseignement_statut_check CHECK ((statut = ANY (ARRAY['actif'::text, 'detenu'::text, 'mort'::text, 'disparu'::text])));
ALTER TABLE public.cellules_renseignement ADD CONSTRAINT cellule_fin_coherente CHECK ((((statut = 'active'::text) AND (mode_fin IS NULL) AND (terminee_le IS NULL)) OR ((statut <> 'active'::text) AND (mode_fin IS NOT NULL) AND (terminee_le IS NOT NULL))));
ALTER TABLE public.cellules_renseignement ADD CONSTRAINT cellules_renseignement_mode_fin_check CHECK ((mode_fin = ANY (ARRAY['naturelle'::text, 'volontaire'::text, 'echec_agents'::text])));
ALTER TABLE public.cellules_renseignement ADD CONSTRAINT cellules_renseignement_statut_check CHECK ((statut = ANY (ARRAY['active'::text, 'terminee'::text, 'echec'::text])));
ALTER TABLE public.renseignement_couvertures ADD CONSTRAINT renseignement_couvertures_sexe_check CHECK ((sexe = ANY (ARRAY['H'::text, 'F'::text])));
ALTER TABLE public.renseignement_identites_reelles ADD CONSTRAINT renseignement_identites_reelles_dup_check CHECK (((dup >= 1) AND (dup <= 20)));
ALTER TABLE public.renseignement_identites_reelles ADD CONSTRAINT renseignement_identites_reelles_role_check CHECK ((role = ANY (ARRAY['conseiller'::text, 'traducteur'::text, 'garde'::text, 'coordinateur'::text])));
ALTER TABLE public.renseignement_identites_reelles ADD CONSTRAINT renseignement_identites_reelles_sexe_check CHECK ((sexe = ANY (ARRAY['H'::text, 'F'::text])));
ALTER TABLE public.renseignements_connus ADD CONSTRAINT renseignements_connus_mode_acquisition_check CHECK ((mode_acquisition = ANY (ARRAY['action_personnelle'::text, 'observation'::text, 'document_consulte'::text, 'confidence'::text, 'transmission'::text, 'interrogatoire'::text])));

-- CLES ETRANGERES
ALTER TABLE public.agents_renseignement ADD CONSTRAINT agents_renseignement_cellule_id_fkey FOREIGN KEY (cellule_id) REFERENCES cellules_renseignement(id);
ALTER TABLE public.agents_renseignement ADD CONSTRAINT agents_renseignement_pnj_id_fkey FOREIGN KEY (pnj_id) REFERENCES pnj_membres(id);
ALTER TABLE public.rapports_cellules ADD CONSTRAINT rapports_cellules_cellule_id_fkey FOREIGN KEY (cellule_id) REFERENCES cellules_renseignement(id);
