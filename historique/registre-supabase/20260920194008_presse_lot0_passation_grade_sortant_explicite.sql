-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920194008
-- Nom original      : presse_lot0_passation_grade_sortant_explicite
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-20 19:40:08 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 54006bcb21f35ab085fe2fb903f49d4e
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
-- ===========================================================================
-- PRESSE — LOT 0, CORRECTIF : LA PASSATION N'IMPOSE PLUS DE GRADE (20/09/2026)
--
-- Arbitrage GD : le jeu ne decide pas du grade que reprend le Directeur
-- sortant. Ce sont des PJ, ils s'organisent entre eux. La constante
-- c_grade_sortant := 'redacteur_chef' est donc supprimee.
--
-- Le grade est desormais FOURNI EXPLICITEMENT a l'action, sans valeur par
-- defaut : la signature l'exige, le serveur le valide. L'ancienne surcharge a
-- deux arguments est SUPPRIMEE -- ajouter un parametre en aurait fait une
-- surcharge, et la version portant la regle codee en dur serait restee
-- appelable.
-- ===========================================================================

DROP FUNCTION IF EXISTS public.presse_designer_successeur(text, text);

CREATE OR REPLACE FUNCTION public.presse_designer_successeur(
  p_groupe_id text, p_personnage text, p_grade_sortant text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_directeur text;
BEGIN
  v_directeur := public.presse_acteur_directeur(p_groupe_id);
  IF v_directeur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_directeur');
  END IF;
  IF p_personnage = v_directeur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'successeur_identique');
  END IF;

  -- GRADE DU SORTANT : exige, valide, sans defaut. 'directeur' est exclu --
  -- ce serait soit deux directeurs, soit une passation qui n'en est pas une.
  IF p_grade_sortant IS NULL
     OR p_grade_sortant NOT IN ('correspondant','journaliste','redacteur_chef') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'grade_sortant_invalide',
                              'recu', p_grade_sortant,
                              'valides', jsonb_build_array('correspondant','journaliste','redacteur_chef'));
  END IF;

  -- Verrou sur les deux lignes, dans un ordre stable, avant toute ecriture.
  PERFORM 1 FROM public.presse_membres
   WHERE groupe_id = p_groupe_id AND personnage IN (v_directeur, p_personnage)
   ORDER BY personnage FOR UPDATE;

  IF NOT EXISTS (SELECT 1 FROM public.presse_membres
                  WHERE groupe_id = p_groupe_id AND personnage = p_personnage) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_membre_du_groupe');
  END IF;

  -- On RETROGRADE d'abord, on PROMEUT ensuite : l'index unique « un seul
  -- directeur » n'est jamais heurte, et aucun etat intermediaire n'est
  -- visible hors de la transaction.
  UPDATE public.presse_membres
     SET grade = p_grade_sortant, grade_depuis = now(), nomme_par = '(passation)'
   WHERE groupe_id = p_groupe_id AND personnage = v_directeur;

  UPDATE public.presse_membres
     SET grade = 'directeur', grade_depuis = now(), nomme_par = v_directeur
   WHERE groupe_id = p_groupe_id AND personnage = p_personnage;

  RETURN jsonb_build_object('ok', true, 'directeur', p_personnage,
                            'ancien_directeur', v_directeur, 'grade_sortant', p_grade_sortant);
END;
$function$;

REVOKE ALL ON FUNCTION public.presse_designer_successeur(text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.presse_designer_successeur(text,text,text) TO authenticated, service_role;