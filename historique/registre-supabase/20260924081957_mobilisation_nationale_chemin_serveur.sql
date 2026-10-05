-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260924081957
-- Nom original      : mobilisation_nationale_chemin_serveur
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-24 08:19:57 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 4c3534c6c3e7a06284c3fc07790d0dff
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
-- =============================================================================================
-- MOBILISATION NATIONALE : UN CHEMIN SERVEUR, PLUS UNE ECRITURE DE BLOB (24 septembre 2026)
-- =============================================================================================
-- CE QUI EXISTAIT. mobilisationNationaleActive etait ecrite UNIQUEMENT depuis le navigateur, en
-- relisant puis en reecrivant le blob budgets_nationaux.data tout entier, a deux endroits
-- (confirmerMobilisation et doDemobiliser). La seule garde etait le trigger d'epinglage, qui
-- restaure la valeur si le poste de l'acteur n'est pas min_def -- une protection reelle, mais qui
-- repose sur une table de regles partielle et sur un droit d'UPDATE accorde au navigateur sur la
-- ligne entiere.
--
-- CE QUE FAIT CETTE RPC. Elle ecrit CETTE CLE ET ELLE SEULE, sous l'autorite du serveur :
-- exiger_poste('min_def') tranche, le pays est deduit de l'acteur et jamais transmis, et
-- jsonb_set ne touche a rien d'autre -- contrairement a une reecriture de blob, qui peut emporter
-- silencieusement toute modification concurrente faite entre la lecture et l'ecriture.
--
-- LA REGLE DE JEU NE CHANGE PAS : le ministre de la Defense mobilise et demobilise, et lui seul.
-- Le cout en PA reste preleve par le client via payer_ordre, comme avant.
-- =============================================================================================

CREATE OR REPLACE FUNCTION public.militaire_mobilisation_fixer(p_actif boolean)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE v_moi text; v_pays text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  -- AUTORITE. exiger_poste leve si le poste n'est pas atteste : on ne se contente pas de lire
  -- poste->>'id' sur la fiche, qui est ce que le navigateur affiche.
  PERFORM public.exiger_poste('min_def');

  SELECT coalesce(country, 'republic') INTO v_pays
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  -- ECRITURE CHIRURGICALE : une seule cle, sous verrou, sans relire ni reecrire le reste du blob.
  UPDATE public.budgets_nationaux
     SET data = jsonb_set(coalesce(data, '{}'::jsonb), '{mobilisationNationaleActive}',
                          to_jsonb(coalesce(p_actif, false)), true),
         updated_at = now()
   WHERE id = v_pays;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'budget_introuvable', 'pays', v_pays);
  END IF;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'actif', coalesce(p_actif, false));
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_mobilisation_fixer(boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_mobilisation_fixer(boolean) TO authenticated, service_role;