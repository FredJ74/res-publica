-- Cles primaires, unicite, validation, cles etrangeres
-- ============================================================================
-- BASELINE Human Gambit -- domaine socle PNJ -- phase 30 : contraintes
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- CLES PRIMAIRES
ALTER TABLE public.pnj_axes_autorite ADD CONSTRAINT pnj_axes_autorite_pkey PRIMARY KEY (famille, axe);
ALTER TABLE public.pnj_candidats_catalogue ADD CONSTRAINT pnj_candidats_catalogue_pkey PRIMARY KEY (candidat_id);
ALTER TABLE public.pnj_employes_metier ADD CONSTRAINT pnj_employes_metier_pkey PRIMARY KEY (pnj_id);
ALTER TABLE public.pnj_employeurs ADD CONSTRAINT pnj_employeurs_pkey PRIMARY KEY (employeur_id);
ALTER TABLE public.pnj_evenements ADD CONSTRAINT pnj_evenements_pkey PRIMARY KEY (id);
ALTER TABLE public.pnj_familles_classes ADD CONSTRAINT pnj_familles_classes_pkey PRIMARY KEY (famille);
ALTER TABLE public.pnj_fonctions ADD CONSTRAINT pnj_fonctions_pkey PRIMARY KEY (fonction);
ALTER TABLE public.pnj_force_publique_metier ADD CONSTRAINT pnj_force_publique_metier_pkey PRIMARY KEY (pnj_id);
ALTER TABLE public.pnj_institutions ADD CONSTRAINT pnj_institutions_pkey PRIMARY KEY (institution);
ALTER TABLE public.pnj_membres ADD CONSTRAINT pnj_membres_pkey PRIMARY KEY (id);
ALTER TABLE public.pnj_metiers_profils ADD CONSTRAINT pnj_metiers_profils_pkey PRIMARY KEY (metier);
ALTER TABLE public.pnj_militants_metier ADD CONSTRAINT pnj_militants_metier_pkey PRIMARY KEY (pnj_id);
ALTER TABLE public.pnj_mouvement_individuel ADD CONSTRAINT pnj_mouvement_individuel_pkey PRIMARY KEY (famille);
ALTER TABLE public.pnj_possessions ADD CONSTRAINT pnj_possessions_pkey PRIMARY KEY (id);
ALTER TABLE public.pnj_referents ADD CONSTRAINT pnj_referents_pkey PRIMARY KEY (referent_id);
ALTER TABLE public.pnj_referents_pedagogie ADD CONSTRAINT pnj_referents_pedagogie_pkey PRIMARY KEY (referent_id, joueur);
ALTER TABLE public.pnj_referents_sujets_connus ADD CONSTRAINT pnj_referents_sujets_connus_pkey PRIMARY KEY (referent_id, sujet);
ALTER TABLE public.pnj_social_escort_choisi ADD CONSTRAINT pnj_social_escort_choisi_pkey PRIMARY KEY (joueur);
ALTER TABLE public.pnj_social_jalons_regles ADD CONSTRAINT pnj_social_jalons_regles_pkey PRIMARY KEY (pnj_id, jalon);
ALTER TABLE public.pnj_social_relations ADD CONSTRAINT pnj_social_relations_pkey PRIMARY KEY (pnj_id, joueur);
ALTER TABLE public.pnj_soldats_metier ADD CONSTRAINT pnj_soldats_metier_pkey PRIMARY KEY (pnj_id);
ALTER TABLE public.pnj_transitions ADD CONSTRAINT pnj_transitions_pkey PRIMARY KEY (cle);

-- CONTRAINTES DE VALIDATION
ALTER TABLE public.pnj_axes_autorite ADD CONSTRAINT pnj_axes_autorite_autorite_check CHECK ((autorite = ANY (ARRAY['socle'::text, 'blob'::text, 'institution'::text])));
ALTER TABLE public.pnj_candidats_catalogue ADD CONSTRAINT pnj_candidat_genre_connu CHECK (((genre IS NULL) OR (genre = ANY (ARRAY['H'::text, 'F'::text]))));
ALTER TABLE public.pnj_evenements ADD CONSTRAINT pnj_evt_type CHECK ((type = 'mort'::text));
ALTER TABLE public.pnj_familles_classes ADD CONSTRAINT pnj_familles_classes_classe_check CHECK ((classe = ANY (ARRAY['alpha'::text, 'beta'::text, 'gamma'::text])));
ALTER TABLE public.pnj_fonctions ADD CONSTRAINT pnj_fonctions_classe_decor_check CHECK ((classe_decor = ANY (ARRAY['alpha'::text, 'beta'::text, 'gamma'::text])));
ALTER TABLE public.pnj_fonctions ADD CONSTRAINT pnj_fonctions_role_fonctionnel_check CHECK ((role_fonctionnel = ANY (ARRAY['decor'::text, 'dialogue'::text, 'acces'::text, 'referent'::text, 'institutionnel'::text, 'mecanique'::text])));
ALTER TABLE public.pnj_force_publique_metier ADD CONSTRAINT pnj_fp_cyno CHECK (((type_unite <> 'cynophile'::text) OR (chien_nom IS NOT NULL)));
ALTER TABLE public.pnj_force_publique_metier ADD CONSTRAINT pnj_fp_type CHECK ((type_unite = ANY (ARRAY['standard'::text, 'cynophile'::text])));
ALTER TABLE public.pnj_membres ADD CONSTRAINT pnj_car_bornes CHECK ((((COALESCE(car_int, 0) >= 0) AND (COALESCE(car_int, 0) <= 100)) AND ((COALESCE(car_cha, 0) >= 0) AND (COALESCE(car_cha, 0) <= 100)) AND ((COALESCE(car_vol, 0) >= 0) AND (COALESCE(car_vol, 0) <= 100)) AND ((COALESCE(car_per, 0) >= 0) AND (COALESCE(car_per, 0) <= 100)) AND ((COALESCE(car_dup, 0) >= 0) AND (COALESCE(car_dup, 0) <= 100)) AND ((COALESCE(car_ent, 0) >= 0) AND (COALESCE(car_ent, 0) <= 100))));
ALTER TABLE public.pnj_membres ADD CONSTRAINT pnj_famille_connue CHECK ((famille = ANY (ARRAY['soldat'::text, 'employe'::text, 'agent'::text, 'policier'::text, 'douanier'::text, 'militant'::text])));
ALTER TABLE public.pnj_membres ADD CONSTRAINT pnj_membres_classe_connue CHECK (((classe IS NULL) OR (classe = ANY (ARRAY['alpha'::text, 'beta'::text, 'gamma'::text]))));
ALTER TABLE public.pnj_membres ADD CONSTRAINT pnj_mort_sans_leader CHECK (((statut <> 'mort'::text) OR ((leader_pj IS NULL) AND (leader_pnj_id IS NULL))));
ALTER TABLE public.pnj_membres ADD CONSTRAINT pnj_pa_positif CHECK ((pa >= 0));
ALTER TABLE public.pnj_membres ADD CONSTRAINT pnj_pas_son_propre_leader CHECK ((leader_pnj_id IS DISTINCT FROM id));
ALTER TABLE public.pnj_membres ADD CONSTRAINT pnj_position_deux_etats CHECK (((((leader_pj IS NOT NULL) OR (leader_pnj_id IS NOT NULL)) AND (ville IS NULL) AND (building_id IS NULL) AND (room_id IS NULL) AND (rue_noeud_id IS NULL)) OR ((leader_pj IS NULL) AND (leader_pnj_id IS NULL))));
ALTER TABLE public.pnj_membres ADD CONSTRAINT pnj_propriete_exclusive CHECK ((((classe = 'gamma'::text) AND (proprietaire_pj IS NULL) AND (proprietaire_institution IS NULL) AND (proprietaire_perimetre IS NULL)) OR ((classe IS DISTINCT FROM 'gamma'::text) AND (((proprietaire_pj IS NOT NULL) AND (proprietaire_institution IS NULL) AND (proprietaire_perimetre IS NULL)) OR ((proprietaire_pj IS NULL) AND (proprietaire_institution IS NOT NULL) AND (proprietaire_perimetre IS NOT NULL))))));
ALTER TABLE public.pnj_membres ADD CONSTRAINT pnj_statut_connu CHECK ((statut = ANY (ARRAY['actif'::text, 'detenu'::text, 'mort'::text, 'disparu'::text])));
ALTER TABLE public.pnj_membres ADD CONSTRAINT pnj_un_seul_leader CHECK (((leader_pj IS NULL) OR (leader_pnj_id IS NULL)));
ALTER TABLE public.pnj_metiers_profils ADD CONSTRAINT pnj_metiers_profils_bornes CHECK ((((car_int >= 0) AND (car_int <= 100)) AND ((car_cha >= 0) AND (car_cha <= 100)) AND ((car_vol >= 0) AND (car_vol <= 100)) AND ((car_per >= 0) AND (car_per <= 100)) AND ((car_dup >= 0) AND (car_dup <= 100)) AND ((car_ent >= 0) AND (car_ent <= 100))));
ALTER TABLE public.pnj_metiers_profils ADD CONSTRAINT pnj_metiers_profils_classe_connue CHECK (((classe IS NULL) OR (classe = ANY (ARRAY['alpha'::text, 'beta'::text, 'gamma'::text]))));
ALTER TABLE public.pnj_metiers_profils ADD CONSTRAINT pnj_metiers_profils_quota_positif CHECK (((quota_par_joueur IS NULL) OR (quota_par_joueur >= 1)));
ALTER TABLE public.pnj_possessions ADD CONSTRAINT pnj_possessions_origine_connue CHECK ((origine = ANY (ARRAY['socle'::text, 'blob_accessoires'::text])));
ALTER TABLE public.pnj_soldats_metier ADD CONSTRAINT pnj_soldats_compteurs_bien_formes CHECK ((((dernier_ration IS NULL) OR (dernier_ration ~ '^\d{4}-\d{2}-\d{2}$'::text)) AND ((dernier_bivouac IS NULL) OR (dernier_bivouac ~ '^\d{4}-\d{2}-\d{2}$'::text)) AND ((dernier_sommeil IS NULL) OR (dernier_sommeil ~ '^\d{4}-\d{2}-\d{2}$'::text)) AND ((nb_ration IS NULL) OR (nb_ration >= 0))));
ALTER TABLE public.pnj_soldats_metier ADD CONSTRAINT pnj_soldats_section_dans_sa_compagnie CHECK ((((en_reserve = true) AND (section_id IS NULL)) OR ((en_reserve = false) AND (section_id IS NOT NULL) AND ((compagnie_id IS NULL) OR (section_id ~~ (compagnie_id || '-%'::text))))));
ALTER TABLE public.pnj_soldats_metier ADD CONSTRAINT soldat_reserve_coherente CHECK ((en_reserve = (section_id IS NULL)));

-- CLES ETRANGERES
ALTER TABLE public.pnj_candidats_catalogue ADD CONSTRAINT pnj_candidats_catalogue_employeur_id_fkey FOREIGN KEY (employeur_id) REFERENCES pnj_employeurs(employeur_id) ON DELETE CASCADE;
ALTER TABLE public.pnj_candidats_catalogue ADD CONSTRAINT pnj_candidats_catalogue_metier_fkey FOREIGN KEY (metier) REFERENCES pnj_metiers_profils(metier);
ALTER TABLE public.pnj_employes_metier ADD CONSTRAINT pnj_employes_metier_candidat_id_fkey FOREIGN KEY (candidat_id) REFERENCES pnj_candidats_catalogue(candidat_id);
ALTER TABLE public.pnj_employes_metier ADD CONSTRAINT pnj_employes_metier_pnj_id_fkey FOREIGN KEY (pnj_id) REFERENCES pnj_membres(id) ON DELETE CASCADE;
ALTER TABLE public.pnj_force_publique_metier ADD CONSTRAINT pnj_force_publique_metier_pnj_id_fkey FOREIGN KEY (pnj_id) REFERENCES pnj_membres(id) ON DELETE CASCADE;
ALTER TABLE public.pnj_membres ADD CONSTRAINT pnj_membres_leader_pnj_id_fkey FOREIGN KEY (leader_pnj_id) REFERENCES pnj_membres(id) ON DELETE SET NULL;
ALTER TABLE public.pnj_militants_metier ADD CONSTRAINT pnj_militants_metier_pnj_id_fkey FOREIGN KEY (pnj_id) REFERENCES pnj_membres(id) ON DELETE CASCADE;
ALTER TABLE public.pnj_possessions ADD CONSTRAINT pnj_possessions_pnj_id_fkey FOREIGN KEY (pnj_id) REFERENCES pnj_membres(id) ON DELETE CASCADE;
ALTER TABLE public.pnj_referents_sujets_connus ADD CONSTRAINT pnj_referents_sujets_connus_referent_id_fkey FOREIGN KEY (referent_id) REFERENCES pnj_referents(referent_id) ON DELETE CASCADE;
ALTER TABLE public.pnj_soldats_metier ADD CONSTRAINT pnj_soldats_metier_pnj_id_fkey FOREIGN KEY (pnj_id) REFERENCES pnj_membres(id) ON DELETE CASCADE;
