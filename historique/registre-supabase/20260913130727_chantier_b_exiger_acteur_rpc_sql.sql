-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913130727
-- Nom original      : chantier_b_exiger_acteur_rpc_sql
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 13:07:27 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : e15de13a4808ee3965b225b7a3e97047
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- Complement : les quatre points d'entree ecrits en langage SQL, ou l'on ne peut
-- pas inserer un PERFORM. Ils sont reecrits en plpgsql, corps identique, avec le
-- controle d'acteur en tete. Definitions d'origine conservees dans
-- sauvegarde_beta_20260913.definitions_fonctions.

-- Qui peut deposer un texte a l'Assemblee ? Un joueur ne peut desormais poser la
-- question que sur son propre personnage.
CREATE OR REPLACE FUNCTION public.assemblee_peut_deposer(p_nom text, p_country text DEFAULT 'republic'::text)
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM public.exiger_acteur(p_nom);
  RETURN EXISTS (
    SELECT 1 FROM public.personnages p
    WHERE p.name = p_nom
      AND p.country = p_country
      AND (
        (p.poste_depute IS NOT NULL AND p.poste_depute->>'id' = 'depute')
        OR (p.poste IS NOT NULL AND p.poste->>'id' IN
              ('pm','min_int','min_fin','min_just','min_def','min_info','min_ae'))
      )
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.calomnie_distribuer(p_requete text, p_joueur text, p_cible text, p_pnj_nom text, p_vol_pnj integer DEFAULT 10)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM public.exiger_acteur(p_joueur);
  RETURN public.calomnie_distribuer_interne(p_requete, p_joueur, p_cible, p_pnj_nom, p_vol_pnj, now());
END;
$function$;

CREATE OR REPLACE FUNCTION public.tracts_electoraux_distribuer(p_requete text, p_joueur text, p_cycle_id text, p_candidat text, p_sens text, p_pnj_nom text, p_vol_pnj integer)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM public.exiger_acteur(p_joueur);
  RETURN public.tracts_electoraux_distribuer_interne(p_requete, p_joueur, p_cycle_id, p_candidat, p_sens, p_pnj_nom, p_vol_pnj, now());
END;
$function$;

-- Reclamer un don de tracts : le destinataire est ici l'ACTEUR -- c'est lui qui
-- vient chercher ce qui lui a ete envoye. C'est donc sur lui que porte le controle.
CREATE OR REPLACE FUNCTION public.tracts_reclamer_don(p_id text, p_destinataire text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_resultat jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_destinataire);
  DELETE FROM public.objets_recus
   WHERE id = p_id AND destinataire = p_destinataire
     AND id LIKE 'don-tracts-%'
  RETURNING jsonb_build_object('id', id, 'expediteur', expediteur, 'data', data)
  INTO v_resultat;
  RETURN v_resultat;
END;
$function$;