-- ============================================================================
-- CHANTIER 3 -- AUTORITE (3/3) : UNE RPC QUI ECRIT N'EST PAS POUR UN VISITEUR
--
-- Meme cause que la migration 1, autre objet. `ALTER DEFAULT PRIVILEGES`
-- accorde EXECUTE a `anon` sur TOUTE fonction creee dans public : 115
-- fonctions sont ainsi appelables par un visiteur sans compte, dont 34 ECRIVENT
-- (316 fonctions mutantes au total, hors declencheurs).
--
-- Ce piege est deja consigne au projet, mot pour mot, depuis le chantier de la
-- caserne : « ALTER DEFAULT PRIVILEGES accorde EXECUTE a anon sur toute
-- nouvelle fonction du schema public. Un REVOKE ALL FROM PUBLIC ne suffit
-- pas -- il faut nommer anon, authenticated. » On le ferme ici a la source.
--
-- CE QUE CELA NE CHANGE PAS. Les 34 fonctions echouaient DEJA sous `anon` :
-- chacune verifie son acteur (exiger_acteur, est_mon_personnage,
-- mon_poste_est_dans...), et sous `anon` il n'y a pas d'acteur -- auth.uid()
-- est NULL. Le joueur, lui, n'est jamais `anon` : sbRpc ouvre une session
-- anonyme avant tout appel, et une session fait de lui `authenticated`. Ce qui
-- change est le message : « permission denied for function » au lieu de
-- « acteur_non_authentifie ». Les deux sont des refus.
--
-- VERIFIE AVANT ECRITURE : les 34 portent toutes un GRANT EXECUTE explicite a
-- `authenticated`. Aucune ne perd son seul acces client -- verifie sur le
-- baseline, fonction par fonction.
--
-- LES LECTURES RESTENT OUVERTES A `anon`. Un visiteur sans compte doit pouvoir
-- regarder le monde : les 81 fonctions non mutantes gardent leur EXECUTE. Ce
-- n'est pas un oubli, c'est la frontiere -- `anon` LIT, il n'AGIT pas.
--
-- Liste nominative plutot que boucle : une migration doit faire exactement ce
-- qui a ete mesure, et non le redecouvrir avec un critere qui pourrait, demain,
-- attraper autre chose. Les 36 instructions ci-dessous sont les 34 fonctions
-- (deux portent deux surcharges), relevees dans baseline/domaines/*/70_droits.sql.
--
-- Idempotente : un REVOKE sur un privilege absent ne fait rien.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. LE ROBINET : ce qu'une fonction neuve accordera desormais
--    `authenticated` garde le defaut : une RPC creee par un chantier futur
--    reste joignable par le navigateur sans qu'on ait a y penser. Retirer AUSSI
--    ce defaut rendrait toute nouvelle RPC injoignable avec pour seul symptome
--    un 404 PostgREST -- une panne muette, deja rencontree sur ce projet.
-- ----------------------------------------------------------------------------

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM anon;

-- ----------------------------------------------------------------------------
-- 2. LES 34 FONCTIONS MUTANTES DEJA DISTRIBUEES A `anon`
-- ----------------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.accepter_accord_helvetia(text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.agent_transferer(text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.assemblee_amender(text,text,text,text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.assemblee_consulter_lobbyiste(text,text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.assemblee_lier_topic(text,text,text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.assemblee_marchander(text,text,text,text,text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.assemblee_neutraliser_depute(text,text,text,text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.assemblee_retirer(text,text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.assemblee_reveiller_depute(text,text,text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.assemblee_verser_indemnite(text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.assemblee_voter(text,text,text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.corruption_presse_tenter(text,text,text,text,integer,timestamp with time zone) FROM anon;
REVOKE EXECUTE ON FUNCTION public.creer_placement_helvetia(text,numeric,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.creer_placement_national(text,numeric,integer,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.creer_pret_helvetia(text,numeric,integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.deposer_helvetia(text,numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.deposer_helvetia(text,numeric,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.elections_voix_pnj_enregistrer(text,text,text,text,text,text,text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.employe_liberer(text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.employe_recruter(text,text,text,text,integer,integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.employeur_embaucher(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fermer_compte_helvetia(text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.finaliser_achat_bien_helvetia(text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fuite_reserver(text,text,text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.imprimerie_cession_finaliser(text,text,text,numeric,integer) FROM anon;
REVOKE EXECUTE ON FUNCTION public.militaire_arme_recalculer(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.militant_recruter(text,text,text,text,text,text,integer,integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.ouvrir_compte_helvetia(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.rembourser_pret_helvetia_integral(text,text,jsonb) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.retirer_helvetia(text,numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.retirer_helvetia(text,numeric,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.scandale_tenter(text,text,text,text,integer,timestamp with time zone) FROM anon;
REVOKE EXECUTE ON FUNCTION public.signer_compromis_bien_helvetia(text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.tracts_donner_joueur(text,text,text,jsonb) FROM anon;
REVOKE EXECUTE ON FUNCTION public.tracts_reclamer_don(text,text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.vendre_materiaux_chantier(text,text,text,text,integer,integer) FROM anon;
