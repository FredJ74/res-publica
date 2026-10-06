-- GRANT sur tables, colonnes et fonctions
-- ============================================================================
-- BASELINE Human Gambit -- domaine banque -- phase 70 : droits
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- DROITS SUR LES FUNCTIONS
GRANT EXECUTE ON FUNCTION public.accepter_accord_helvetia(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.accepter_accord_helvetia(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.accepter_accord_helvetia(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.banque_nationale_mouvement(text,text,numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.banque_nationale_mouvement(text,text,numeric) TO postgres;
GRANT EXECUTE ON FUNCTION public.banque_nationale_mouvement(text,text,numeric) TO service_role;
GRANT EXECUTE ON FUNCTION public.compte_bancaire_initial(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.compte_bancaire_initial(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.compte_bancaire_initial(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.creer_placement_helvetia(text,numeric,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.creer_placement_helvetia(text,numeric,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.creer_placement_helvetia(text,numeric,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.creer_placement_national(text,numeric,integer,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.creer_placement_national(text,numeric,integer,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.creer_placement_national(text,numeric,integer,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.creer_pret_helvetia(text,numeric,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.creer_pret_helvetia(text,numeric,integer) TO postgres;
GRANT EXECUTE ON FUNCTION public.creer_pret_helvetia(text,numeric,integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.deposer_helvetia(text,numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.deposer_helvetia(text,numeric) TO postgres;
GRANT EXECUTE ON FUNCTION public.deposer_helvetia(text,numeric) TO service_role;
GRANT EXECUTE ON FUNCTION public.deposer_helvetia(text,numeric,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.deposer_helvetia(text,numeric,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.deposer_helvetia(text,numeric,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.fermer_compte_helvetia(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fermer_compte_helvetia(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.fermer_compte_helvetia(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.finaliser_achat_bien_helvetia(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.finaliser_achat_bien_helvetia(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.finaliser_achat_bien_helvetia(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.helvetia_assurer_liquidite(text,numeric,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.helvetia_assurer_liquidite(text,numeric,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.helvetia_crediter_destination(text,numeric,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.helvetia_crediter_destination(text,numeric,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.helvetia_debiter_fonds_ordinaires(text,numeric) TO postgres;
GRANT EXECUTE ON FUNCTION public.helvetia_debiter_fonds_ordinaires(text,numeric) TO service_role;
GRANT EXECUTE ON FUNCTION public.helvetia_debiter_source(text,numeric,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.helvetia_debiter_source(text,numeric,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.helvetia_ie_national(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.helvetia_ie_national(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.helvetia_inventaire_sortie(jsonb,jsonb,integer,jsonb,integer) TO postgres;
GRANT EXECUTE ON FUNCTION public.helvetia_inventaire_sortie(jsonb,jsonb,integer,jsonb,integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.helvetia_taux_refinancement_bnr(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.helvetia_taux_refinancement_bnr(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.ouvrir_compte_helvetia(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ouvrir_compte_helvetia(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.ouvrir_compte_helvetia(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.regler_creances_helvetia_quotidien(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.regler_creances_helvetia_quotidien(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.rembourser_pret_helvetia_integral(text,text,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rembourser_pret_helvetia_integral(text,text,jsonb) TO postgres;
GRANT EXECUTE ON FUNCTION public.rembourser_pret_helvetia_integral(text,text,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.resoudre_compromis_helvetia_expire(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.resoudre_compromis_helvetia_expire(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.resoudre_placement_helvetia(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.resoudre_placement_helvetia(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.resoudre_placement_national(text,numeric) TO postgres;
GRANT EXECUTE ON FUNCTION public.resoudre_placement_national(text,numeric) TO service_role;
GRANT EXECUTE ON FUNCTION public.retirer_helvetia(text,numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.retirer_helvetia(text,numeric) TO postgres;
GRANT EXECUTE ON FUNCTION public.retirer_helvetia(text,numeric) TO service_role;
GRANT EXECUTE ON FUNCTION public.retirer_helvetia(text,numeric,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.retirer_helvetia(text,numeric,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.retirer_helvetia(text,numeric,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.signer_compromis_bien_helvetia(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.signer_compromis_bien_helvetia(text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.signer_compromis_bien_helvetia(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.taux_pret_nationale(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.taux_pret_nationale(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.traiter_prets_helvetia_quotidien() TO postgres;
GRANT EXECUTE ON FUNCTION public.traiter_prets_helvetia_quotidien() TO service_role;

-- DROITS SUR LES TABLES
GRANT SELECT ON TABLE public.biens_saisis_helvetia TO anon;
GRANT SELECT ON TABLE public.biens_saisis_helvetia TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.biens_saisis_helvetia TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.biens_saisis_helvetia TO service_role;
GRANT SELECT ON TABLE public.bnr_refinancements_helvetia TO anon;
GRANT SELECT ON TABLE public.bnr_refinancements_helvetia TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.bnr_refinancements_helvetia TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.bnr_refinancements_helvetia TO service_role;
GRANT SELECT ON TABLE public.compromis_historique TO anon;
GRANT SELECT ON TABLE public.compromis_historique TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.compromis_historique TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.compromis_historique TO service_role;
GRANT SELECT ON TABLE public.comptes_bancaires TO anon;
GRANT SELECT ON TABLE public.comptes_bancaires TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.comptes_bancaires TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.comptes_bancaires TO service_role;
GRANT SELECT ON TABLE public.obligations_helvetia TO anon;
GRANT SELECT ON TABLE public.obligations_helvetia TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.obligations_helvetia TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.obligations_helvetia TO service_role;
GRANT SELECT ON TABLE public.placements_bancaires TO anon;
GRANT SELECT ON TABLE public.placements_bancaires TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.placements_bancaires TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.placements_bancaires TO service_role;
GRANT SELECT ON TABLE public.prets TO anon;
GRANT INSERT, SELECT, UPDATE ON TABLE public.prets TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.prets TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.prets TO service_role;
GRANT SELECT ON TABLE public.prets_bancaires TO anon;
GRANT SELECT ON TABLE public.prets_bancaires TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.prets_bancaires TO postgres;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.prets_bancaires TO service_role;
