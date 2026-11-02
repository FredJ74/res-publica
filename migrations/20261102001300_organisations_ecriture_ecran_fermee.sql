-- ORGANISATIONS, FIN DE LA DOUBLE AUTORITÉ, ÉTAPE B — FERMETURE (Claude, 02/11/2026).
-- À APPLIQUER APRÈS : les portages 20261102000900 à 20261102001200, puis le déploiement READY de
-- l'écran qui les emploie (plus aucune sauvegarde générale d'organisation dans le navigateur).
--
-- L'écran ne crée ni ne modifie plus une organisation par la table : il n'en a plus le droit.
-- Toute écriture passe par une fonction serveur (SECURITY DEFINER) : commandes #219, ordres
-- financiers, cotisations, organisation_vie_commande, greve_generale_synchroniser,
-- club_supporters_adherer, militant_recruter, rumeur_lancer, syndicat_etudiant_domicilier, la nuit.
-- La dissolution reste ouverte au chef (politique organisations_suppression_chef, #300).
-- Les gardes organisations_finances_garder / organisations_champs_commandes_garder restent en
-- place (défense en profondeur ; elles ne concernent que les rôles de l'écran).
BEGIN;

DO $g$ BEGIN
  IF to_regprocedure('public.organisation_vie_commande(text,text,text,jsonb)') IS NULL
     OR to_regprocedure('public.greve_generale_synchroniser(text)') IS NULL
     OR to_regprocedure('public.club_supporters_adherer(text,text,text)') IS NULL
     OR position('etape B des organisations' IN pg_get_functiondef('public.militant_recruter(text,text,text,text,text,text,integer,integer)'::regprocedure)) = 0
     OR position('etape B des organisations' IN pg_get_functiondef('public.rumeur_lancer(text,text,text,text,integer,integer)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'portages_absents : appliquer 20261102000900 a 20261102001200 avant la fermeture';
  END IF;
END $g$;

REVOKE INSERT, UPDATE ON public.organisations FROM anon, authenticated;
DROP POLICY IF EXISTS organisations_ecriture_acteur ON public.organisations;
DROP POLICY IF EXISTS organisations_maj_acteur ON public.organisations;

DO $p$ BEGIN
  IF has_table_privilege('authenticated', 'public.organisations', 'INSERT')
     OR has_table_privilege('authenticated', 'public.organisations', 'UPDATE')
     OR has_table_privilege('anon', 'public.organisations', 'UPDATE')
     OR NOT has_table_privilege('authenticated', 'public.organisations', 'SELECT')
     OR NOT has_table_privilege('authenticated', 'public.organisations', 'DELETE') THEN
    RAISE EXCEPTION 'droits inattendus apres la fermeture';
  END IF;
END $p$;

COMMIT;
