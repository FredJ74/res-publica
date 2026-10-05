-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913230229
-- Nom original      : caisse_institution_mouvement_plafonne
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 23:02:29 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : d3ad267cac02c58d6395550426e6cc44
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
-- CHANTIER C — CAISSES INSTITUTIONNELLES, VARIANTE PLAFONNEE (14 septembre 2026).
--
-- caisse_institution_mouvement est tout-ou-rien. Or une partie du jeu verse DELIBEREMENT un
-- montant partiel quand la caisse ne suit pas : salaires politiques et religieux, virements,
-- subventions, reparations. C'est une regle existante (debiterCaisseBatimentPlafonne), pas une
-- tolerance a corriger -- on lui donne donc sa primitive, plutot que de la forcer dans un
-- tout-ou-rien qui changerait le jeu.
--
-- Extension propre de la primitive existante : meme table, meme verrou, meme semantique de
-- solde jamais negatif. Elle rend le montant REELLEMENT verse, comme la fonction cliente
-- qu'elle remplace -- l'appelant continue de decider quoi faire d'un versement partiel.
CREATE OR REPLACE FUNCTION public.caisse_institution_mouvement_plafonne(
  p_id text, p_montant numeric)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_data jsonb; v_solde numeric; v_verse numeric; v_existe boolean;
BEGIN
  IF COALESCE(btrim(p_id), '') = '' OR p_montant IS NULL OR p_montant < 0
     OR p_montant > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  SELECT data INTO v_data FROM public.caisses_batiments WHERE id = p_id FOR UPDATE;
  v_existe := FOUND;

  v_solde := CASE WHEN v_existe AND jsonb_typeof(v_data -> 'solde') = 'number'
                  THEN (v_data ->> 'solde')::numeric ELSE 0 END;
  v_verse := LEAST(GREATEST(v_solde, 0), p_montant);

  IF v_verse > 0 THEN
    IF v_existe THEN
      UPDATE public.caisses_batiments
         SET data = COALESCE(v_data, '{}'::jsonb) || jsonb_build_object('solde', v_solde - v_verse),
             updated_at = now()
       WHERE id = p_id;
    END IF;
  END IF;

  RETURN jsonb_build_object('ok', true, 'verse', v_verse, 'solde', v_solde - v_verse);
END; $$;

REVOKE EXECUTE ON FUNCTION public.caisse_institution_mouvement_plafonne(text, numeric)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.caisse_institution_mouvement_plafonne(text, numeric)
  TO authenticated, service_role;

-- La primitive tout-ou-rien existait deja mais n'etait accordee a personne cote front.
REVOKE EXECUTE ON FUNCTION public.caisse_institution_mouvement(text, numeric, boolean)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.caisse_institution_mouvement(text, numeric, boolean)
  TO authenticated, service_role;
