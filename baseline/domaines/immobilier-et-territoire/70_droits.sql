-- GRANT sur tables, colonnes et fonctions
-- ============================================================================
-- BASELINE Human Gambit -- domaine immobilier et territoire -- phase 70 : droits
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- DROITS SUR LES FUNCTIONS
GRANT EXECUTE ON FUNCTION public.bail_autorite_de(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.bail_autorite_de(jsonb) TO postgres;
GRANT EXECUTE ON FUNCTION public.bail_autorite_de(jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.bail_autorite_municipale(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.bail_autorite_municipale(jsonb) TO postgres;
GRANT EXECUTE ON FUNCTION public.bail_autorite_municipale(jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.bail_cle_coherente() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.bail_cle_coherente() TO anon;
GRANT EXECUTE ON FUNCTION public.bail_cle_coherente() TO authenticated;
GRANT EXECUTE ON FUNCTION public.bail_cle_coherente() TO postgres;
GRANT EXECUTE ON FUNCTION public.bail_cle_coherente() TO service_role;
GRANT EXECUTE ON FUNCTION public.bail_destination_attestee(jsonb) TO postgres;
GRANT EXECUTE ON FUNCTION public.bail_destination_attestee(jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.bail_je_suis_locataire(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.bail_je_suis_locataire(jsonb) TO postgres;
GRANT EXECUTE ON FUNCTION public.bail_je_suis_locataire(jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.bail_proprietaire_des_murs(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.bail_proprietaire_des_murs(jsonb) TO postgres;
GRANT EXECUTE ON FUNCTION public.bail_proprietaire_des_murs(jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.batiment_caisse_mouvement(text,text,text,text,numeric,text,numeric,numeric,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.batiment_caisse_mouvement(text,text,text,text,numeric,text,numeric,numeric,boolean) TO postgres;
GRANT EXECUTE ON FUNCTION public.batiment_caisse_mouvement(text,text,text,text,numeric,text,numeric,numeric,boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.batiment_etat_lire(jsonb) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.batiment_etat_lire(jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public.batiment_etat_lire(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.batiment_etat_lire(jsonb) TO postgres;
GRANT EXECUTE ON FUNCTION public.batiment_etat_lire(jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.batiment_etat_sous_cle_ecrire(text,text,text,text,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.batiment_etat_sous_cle_ecrire(text,text,text,text,jsonb) TO postgres;
GRANT EXECUTE ON FUNCTION public.batiment_etat_sous_cle_ecrire(text,text,text,text,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.eviction_indemniser(text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.eviction_indemniser(text,text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.eviction_indemniser(text,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.prelever_loyer_bail(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.prelever_loyer_bail(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.resilier_bail_volontaire(text,text) TO anon;
GRANT EXECUTE ON FUNCTION public.resilier_bail_volontaire(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resilier_bail_volontaire(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.resilier_bail_volontaire(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.terminer_bail(text,text,text,integer) TO postgres;
GRANT EXECUTE ON FUNCTION public.terminer_bail(text,text,text,integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.terrain_etat_lire(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.terrain_etat_lire(text) TO service_role;

-- DROITS SUR LES SEQUENCES
GRANT SELECT, UPDATE, USAGE ON SEQUENCE public.batiments_fermes_id_seq TO anon;
GRANT SELECT, UPDATE, USAGE ON SEQUENCE public.batiments_fermes_id_seq TO authenticated;
GRANT SELECT, UPDATE, USAGE ON SEQUENCE public.batiments_fermes_id_seq TO postgres;
GRANT SELECT, UPDATE, USAGE ON SEQUENCE public.batiments_fermes_id_seq TO service_role;

-- DROITS SUR LES TABLES
GRANT MAINTAIN, SELECT ON TABLE public.batiments_etat TO anon;
GRANT MAINTAIN, REFERENCES, SELECT, TRIGGER ON TABLE public.batiments_etat TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.batiments_etat TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.batiments_etat TO service_role;
GRANT INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, UPDATE ON TABLE public.batiments_fermes TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.batiments_fermes TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.batiments_fermes TO service_role;
GRANT MAINTAIN, SELECT ON TABLE public.dossiers_urbanisme TO anon;
GRANT INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, UPDATE ON TABLE public.dossiers_urbanisme TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.dossiers_urbanisme TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.dossiers_urbanisme TO service_role;
GRANT MAINTAIN, SELECT ON TABLE public.locations_actives TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, UPDATE ON TABLE public.locations_actives TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.locations_actives TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.locations_actives TO service_role;
GRANT MAINTAIN, SELECT ON TABLE public.locations_archives TO anon;
GRANT INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, UPDATE ON TABLE public.locations_archives TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.locations_archives TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.locations_archives TO service_role;
GRANT MAINTAIN, SELECT ON TABLE public.logements_attributions_historique TO anon;
GRANT INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, UPDATE ON TABLE public.logements_attributions_historique TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.logements_attributions_historique TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.logements_attributions_historique TO service_role;
GRANT MAINTAIN, SELECT ON TABLE public.logements_demandes TO anon;
GRANT INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, UPDATE ON TABLE public.logements_demandes TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.logements_demandes TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.logements_demandes TO service_role;
GRANT INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, UPDATE ON TABLE public.reservations_salle_reception TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.reservations_salle_reception TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.reservations_salle_reception TO service_role;
GRANT MAINTAIN, SELECT ON TABLE public.terrains_etat TO anon;
GRANT INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, UPDATE ON TABLE public.terrains_etat TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.terrains_etat TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.terrains_etat TO service_role;
GRANT MAINTAIN, SELECT ON TABLE public.terrains_historique_ventes TO anon;
GRANT INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, UPDATE ON TABLE public.terrains_historique_ventes TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.terrains_historique_ventes TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.terrains_historique_ventes TO service_role;
