-- Cles primaires, unicite, validation, cles etrangeres
-- ============================================================================
-- BASELINE Human Gambit -- domaine economie -- phase 30 : contraintes
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- CLES PRIMAIRES
ALTER TABLE public.apports_matieres ADD CONSTRAINT apports_matieres_pkey PRIMARY KEY (requete);
ALTER TABLE public.caisses_fret ADD CONSTRAINT caisses_fret_pkey PRIMARY KEY (id);
ALTER TABLE public.catalogue_correspondance_legacy ADD CONSTRAINT catalogue_correspondance_legacy_pkey PRIMARY KEY (id);
ALTER TABLE public.catalogue_familles ADD CONSTRAINT catalogue_familles_pkey PRIMARY KEY (id);
ALTER TABLE public.catalogue_generique_type ADD CONSTRAINT catalogue_generique_type_pkey PRIMARY KEY (generique_id, type_id);
ALTER TABLE public.catalogue_generiques ADD CONSTRAINT catalogue_generiques_pkey PRIMARY KEY (id);
ALTER TABLE public.catalogue_types ADD CONSTRAINT catalogue_types_pkey PRIMARY KEY (id);
ALTER TABLE public.catalogue_variantes ADD CONSTRAINT catalogue_variantes_pkey PRIMARY KEY (id);
ALTER TABLE public.chaines_production_usine ADD CONSTRAINT chaines_production_usine_pkey PRIMARY KEY (produit);
ALTER TABLE public.chantiers_besoins_jour ADD CONSTRAINT chantiers_besoins_jour_pkey PRIMARY KEY (position_cycle);
ALTER TABLE public.chantiers_paliers ADD CONSTRAINT chantiers_paliers_pkey PRIMARY KEY (palier);
ALTER TABLE public.commerces_dotations ADD CONSTRAINT commerces_dotations_pkey PRIMARY KEY (cle);
ALTER TABLE public.commerces_types ADD CONSTRAINT commerces_types_pkey PRIMARY KEY (cle);
ALTER TABLE public.confiscations_douanieres ADD CONSTRAINT confiscations_douanieres_pkey PRIMARY KEY (id);
ALTER TABLE public.contenu_caisses_fret ADD CONSTRAINT contenu_caisses_fret_pkey PRIMARY KEY (id);
ALTER TABLE public.directeurs_usine ADD CONSTRAINT directeurs_usine_pkey PRIMARY KEY (poste_id);
ALTER TABLE public.entrepot_journal ADD CONSTRAINT entrepot_journal_pkey PRIMARY KEY (id);
ALTER TABLE public.entrepot_transits ADD CONSTRAINT entrepot_transits_pkey PRIMARY KEY (id);
ALTER TABLE public.entrepots_par_ville ADD CONSTRAINT entrepots_par_ville_pkey PRIMARY KEY (ville);
ALTER TABLE public.entrepots_reversements ADD CONSTRAINT entrepots_reversements_pkey PRIMARY KEY (id);
ALTER TABLE public.entreprises ADD CONSTRAINT entreprises_pkey PRIMARY KEY (id);
ALTER TABLE public.entreprises_constantes ADD CONSTRAINT entreprises_constantes_pkey PRIMARY KEY (cle);
ALTER TABLE public.entreprises_prix_rachat ADD CONSTRAINT entreprises_prix_rachat_pkey PRIMARY KEY (batiment);
ALTER TABLE public.imprimeries_declarees ADD CONSTRAINT imprimeries_declarees_pkey PRIMARY KEY (pays, ville, batiment);
ALTER TABLE public.investissements ADD CONSTRAINT investissements_pkey PRIMARY KEY (id);
ALTER TABLE public.oeuvres ADD CONSTRAINT oeuvres_pkey PRIMARY KEY (id);
ALTER TABLE public.offres ADD CONSTRAINT offres_pkey PRIMARY KEY (id);
ALTER TABLE public.offres_emploi_bne ADD CONSTRAINT offres_emploi_bne_pkey PRIMARY KEY (id);
ALTER TABLE public.ordres_couts ADD CONSTRAINT ordres_couts_pkey PRIMARY KEY (fn, pa, cost);
ALTER TABLE public.ordres_couts_ecarts ADD CONSTRAINT ordres_couts_ecarts_pkey PRIMARY KEY (fn, pa, cost);
ALTER TABLE public.ordres_couts_empreinte ADD CONSTRAINT ordres_couts_empreinte_pkey PRIMARY KEY (seul);
ALTER TABLE public.ordres_couts_inconnus ADD CONSTRAINT ordres_couts_inconnus_pkey PRIMARY KEY (fn);
ALTER TABLE public.productions_references ADD CONSTRAINT productions_references_pkey PRIMARY KEY (requete);
ALTER TABLE public.produits_manufactures ADD CONSTRAINT produits_manufactures_pkey PRIMARY KEY (produit);
ALTER TABLE public.recettes_commerce ADD CONSTRAINT recettes_commerce_pkey PRIMARY KEY (id);
ALTER TABLE public.recettes_production ADD CONSTRAINT recettes_production_pkey PRIMARY KEY (id);
ALTER TABLE public.ressources_economie ADD CONSTRAINT ressources_economie_pkey PRIMARY KEY (cle);
ALTER TABLE public.ressources_economie_empreinte ADD CONSTRAINT ressources_economie_empreinte_pkey PRIMARY KEY (seul);
ALTER TABLE public.structures_medicales ADD CONSTRAINT structures_medicales_pkey PRIMARY KEY (building_id);
ALTER TABLE public.usines_rachat_config ADD CONSTRAINT usines_rachat_config_pkey PRIMARY KEY (cle);
ALTER TABLE public.ventes_snapshots ADD CONSTRAINT ventes_snapshots_pkey PRIMARY KEY (id);

-- CONTRAINTES D'UNICITE
ALTER TABLE public.catalogue_correspondance_legacy ADD CONSTRAINT catalogue_correspondance_legacy_motif_valeur_key UNIQUE (motif, valeur);
ALTER TABLE public.catalogue_variantes ADD CONSTRAINT catalogue_variantes_generique_id_cle_key UNIQUE (generique_id, cle);
ALTER TABLE public.ventes_snapshots ADD CONSTRAINT ventes_snapshots_requete_key UNIQUE (requete);

-- CONTRAINTES DE VALIDATION
ALTER TABLE public.apports_matieres ADD CONSTRAINT apports_matieres_mode_check CHECK ((mode = ANY (ARRAY['vente'::text, 'don'::text])));
ALTER TABLE public.apports_matieres ADD CONSTRAINT apports_matieres_quantite_check CHECK ((quantite > 0));
ALTER TABLE public.catalogue_correspondance_legacy ADD CONSTRAINT catalogue_correspondance_legacy_motif_check CHECK ((motif = ANY (ARRAY['type_soustype'::text, 'type'::text, 'produit_militaire'::text, 'type_produit_militaire'::text, 'type_tracttype'::text, 'type_originequete'::text, 'famille_produit_marche'::text, 'recette_id'::text, 'stack_key'::text, 'ordre'::text, 'objet_id'::text])));
ALTER TABLE public.catalogue_generiques ADD CONSTRAINT catalogue_generiques_regime_check CHECK ((regime = ANY (ARRAY['libre'::text, 'reglemente'::text, 'illegal'::text, 'institutionnel'::text])));
ALTER TABLE public.catalogue_variantes ADD CONSTRAINT catalogue_variantes_regime_check CHECK ((regime = ANY (ARRAY['libre'::text, 'reglemente'::text, 'illegal'::text, 'institutionnel'::text])));
ALTER TABLE public.entrepot_journal ADD CONSTRAINT entrepot_journal_sens_check CHECK ((sens = ANY (ARRAY['entree'::text, 'sortie'::text])));
ALTER TABLE public.entrepot_transits ADD CONSTRAINT entrepot_transits_fret_unitaire_check CHECK ((fret_unitaire >= (0)::numeric));
ALTER TABLE public.entrepot_transits ADD CONSTRAINT entrepot_transits_montant_total_check CHECK ((montant_total >= (0)::numeric));
ALTER TABLE public.entrepot_transits ADD CONSTRAINT entrepot_transits_prix_unitaire_check CHECK ((prix_unitaire >= (0)::numeric));
ALTER TABLE public.entrepot_transits ADD CONSTRAINT entrepot_transits_quantite_check CHECK ((quantite > 0));
ALTER TABLE public.entrepots_reversements ADD CONSTRAINT entrepots_reversements_mode_check CHECK ((mode = ANY (ARRAY['automatique'::text, 'volontaire'::text])));
ALTER TABLE public.offres ADD CONSTRAINT offres_parties CHECK ((emetteur <> destinataire));
ALTER TABLE public.offres ADD CONSTRAINT offres_statut_valide CHECK ((statut = ANY (ARRAY['ouverte'::text, 'acceptee'::text, 'refusee'::text, 'expiree'::text, 'annulee'::text])));
ALTER TABLE public.offres ADD CONSTRAINT offres_type_valide CHECK ((type = ANY (ARRAY['vente_objet'::text, 'vente_fonds'::text, 'resiliation_amiable'::text, 'prestation'::text])));
ALTER TABLE public.ordres_couts_empreinte ADD CONSTRAINT ordres_couts_empreinte_seul_check CHECK (seul);
ALTER TABLE public.ressources_economie_empreinte ADD CONSTRAINT ressources_economie_empreinte_seul_check CHECK (seul);
ALTER TABLE public.ventes_snapshots ADD CONSTRAINT ventes_snapshots_montant_total_check CHECK ((montant_total > 0));
ALTER TABLE public.ventes_snapshots ADD CONSTRAINT ventes_snapshots_prix_unitaire_check CHECK ((prix_unitaire > 0));
ALTER TABLE public.ventes_snapshots ADD CONSTRAINT ventes_snapshots_quantite_check CHECK ((quantite > 0));

-- CLES ETRANGERES
ALTER TABLE public.catalogue_correspondance_legacy ADD CONSTRAINT catalogue_correspondance_legacy_generique_id_fkey FOREIGN KEY (generique_id) REFERENCES catalogue_generiques(id);
ALTER TABLE public.catalogue_correspondance_legacy ADD CONSTRAINT catalogue_correspondance_legacy_variante_id_fkey FOREIGN KEY (variante_id) REFERENCES catalogue_variantes(id);
ALTER TABLE public.catalogue_generique_type ADD CONSTRAINT catalogue_generique_type_generique_id_fkey FOREIGN KEY (generique_id) REFERENCES catalogue_generiques(id);
ALTER TABLE public.catalogue_generique_type ADD CONSTRAINT catalogue_generique_type_type_id_fkey FOREIGN KEY (type_id) REFERENCES catalogue_types(id);
ALTER TABLE public.catalogue_generiques ADD CONSTRAINT catalogue_generiques_famille_id_fkey FOREIGN KEY (famille_id) REFERENCES catalogue_familles(id);
ALTER TABLE public.catalogue_variantes ADD CONSTRAINT catalogue_variantes_generique_id_fkey FOREIGN KEY (generique_id) REFERENCES catalogue_generiques(id);
ALTER TABLE public.contenu_caisses_fret ADD CONSTRAINT contenu_caisses_fret_caisse_id_fkey FOREIGN KEY (caisse_id) REFERENCES caisses_fret(id);
