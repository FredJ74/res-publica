-- PRÉPARATION NON APPLIQUÉE : rapprochement exhaustif de tarifs existants.
-- Capture indépendante examinée ; sources du générateur, aucun montant inventé.
-- Ne touche ni aux personnages, ni aux comptes, ni aux fonctions financières.
DO $couts219$
DECLARE h text;apres text;n integer;sentinelle text;
BEGIN
 LOCK TABLE public.ordres_couts IN SHARE ROW EXCLUSIVE MODE;
 SELECT count(*) INTO n FROM public.ordres_couts;
 h:=(SELECT md5(string_agg(fn||'|'||pa||'|'||cost,E'\n' ORDER BY fn COLLATE "C",pa,cost)) FROM public.ordres_couts);
 SELECT empreinte INTO STRICT sentinelle FROM public.ordres_couts_empreinte WHERE seul;
 IF h='1e69581b8020f7375f95d7cdf5dd6c39' AND n=459 THEN
  IF sentinelle<>left(h,16) THEN RAISE EXCEPTION 'couts219_sentinelle_incoherente_apres_installation';END IF;
  RETURN;
 END IF;
 IF h IS DISTINCT FROM '870e48d44fcaeabdbadbac31060570ce' OR n<>439 OR sentinelle<>'6de4a84c58ed9b2b' THEN RAISE EXCEPTION 'couts219_capture_ou_sentinelle_modifiee_prevol_requis';END IF;
 DELETE FROM public.ordres_couts c USING (VALUES
('acheter_criee',1,0),
('acheter_ghb',1,300),
('acheter_gilet',0,600),
('acheter_relique',1,500),
('acheter_ressources_entrepot',1,0),
('acheter_vipere',1,350),
('boire_verre',0,50),
('choisir_accessoire_club',1,0),
('consulter_indices_locaux',0,0),
('corrompre_fonct',2,200),
('corrompre_fonct#reussite',0,200),
('corrompre_fonct#tentative',2,0),
('demettre_lieutenant',2,0),
('entrainer_section',2,0),
('gerer_finances',1,0),
('investir',1,0),
('nommer_capitaine',2,0),
('nommer_lieutenant',2,0),
('plainte',0,0),
('plainte',1,0),
('proposer_abrogation',1,0),
('renseignement',3,500),
('renseignement_transport_intl',0,0),
('requete_avocat',1,0),
('se_nourrir',1,30),
('se_porter_candidat',0,0)) v(fn,pa,cost) WHERE (c.fn,c.pa,c.cost)=(v.fn,v.pa,v.cost);
 -- Les déclarations viennent des sources, pas d'une duplication de la capture privée.
 INSERT INTO public.ordres_couts(fn,pa,cost) VALUES
('acheter_entreprise',3,8000),
('audience_juge',0,0),
('audience_salle',0,0),
('avocat_barreau',0,0),
('avocat_dossiers',0,0),
('caisse_caserne',0,0),
('calepin_campagne',0,0),
('camion_a_vide',0,0),
('camion_conduire',0,0),
('camion_descendre',0,0),
('camion_militaire',0,0),
('commerce_personnaliser',0,0),
('commerce_pj',0,0),
('corrompre_chantier',2,1500),
('declencher_mutinerie',0,0),
('decorer_militaire',0,0),
('garde_republicaine',0,0),
('gerer_budget_interieur',0,0),
('gerer_budget_justice',0,0),
('gestion_caserne',0,0),
('greffe_affaires',0,0),
('greffe_archives',0,0),
('installer_equipements',0,0),
('laisser_legumes_jardins',0,0),
('lois_votees_an',0,0),
('nominations_municipales',0,0),
('organiser_manifestation_spontanee',1,0),
('parquet',0,0),
('prendre_legumes_jardins',0,0),
('prix_chantier',0,0),
('publicite_premium',0,0),
('receptionner_chantier',0,0),
('renseignement_militaire',0,0),
('repas_clinique',1,30),
('repas_hopital',1,0),
('reposer_section',0,0),
('retirer_equipement_militaire',0,0),
('retirer_rations',0,0),
('retirer_trousse',0,0),
('seance_parlementaire',0,0),
('sortie_hopital',0,0),
('suivre_formation',0,0),
('syndicat_etudiant_gerer',0,0),
('taux_chantier',0,0),
('temoin_deposition',0,0),
('temoins_mes_convocations',0,0) ON CONFLICT DO NOTHING;
 apres:=(SELECT md5(string_agg(fn||'|'||pa||'|'||cost,E'\n' ORDER BY fn COLLATE "C",pa,cost)) FROM public.ordres_couts);
 IF apres IS DISTINCT FROM '1e69581b8020f7375f95d7cdf5dd6c39' OR (SELECT count(*) FROM public.ordres_couts)<>459 THEN RAISE EXCEPTION 'couts219_resultat_different_source';END IF;
 -- Sentinelle posée SEULEMENT après modification réelle et comparaison complète.
 UPDATE public.ordres_couts_empreinte SET empreinte=left(apres,16),pose_le=now() WHERE seul;
 IF NOT FOUND THEN RAISE EXCEPTION 'couts219_sentinelle_absente';END IF;
END $couts219$;
