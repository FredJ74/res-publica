-- Lecture seule, aucun changement persistant.
BEGIN;
SET TRANSACTION READ ONLY;
-- Empreintes md5 des fonctions du parcours d achat : a executer sur la production ET sur la base jetable, puis comparer.
SELECT string_agg(x, ' ' ORDER BY x) FROM (
 SELECT p.proname||'('||pg_get_function_identity_arguments(p.oid)||')='||left(md5(rtrim(pg_get_functiondef(p.oid),E'\n')),8) x
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND (p.proname IN ('acheter_a_entrepot','achat_requete_ouvrir_interne','achat_requete_clore_interne','inventaire_action_rejouer_interne','payer_ordre','exiger_acteur','est_mon_personnage','mon_personnage','inventaire_place_restante','batiment_etat_lire','matiere_refus_circuit_legal_lot','est_appel_serveur','objet_acheter','inventaire_deposer_interne','helvetia_debiter_fonds_ordinaires')
   OR p.oid IN (SELECT tgfoid FROM pg_trigger WHERE NOT tgisinternal AND tgrelid IN ('public.personnages_donnees'::regclass,'public.comptes_bancaires'::regclass,'public.batiments_etat'::regclass,'public.inventaire_actions_recus'::regclass)))) s;

ROLLBACK;
