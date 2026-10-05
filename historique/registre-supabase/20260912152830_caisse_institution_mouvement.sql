-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260912152830
-- Nom original      : caisse_institution_mouvement
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-12 15:28:30 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 2f7fda4f90454f976854c7b3b2543577
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
-- MOUVEMENT ATOMIQUE D'UNE CAISSE INSTITUTIONNELLE (12 septembre 2026)
-- caisses_batiments porte les caisses des institutions ('<pays>_gouvernement-min_fin', etc.), lues
-- et reecrites jusqu'ici par le client en deux appels HTTP (chargerCaisseBatiment puis
-- sbSaveCaisseBatiment) : deux mouvements simultanes s'ecrasaient. Pour encaisser le prix d'une
-- cession (180 000 FR), un credit perdu serait inacceptable : lecture, calcul et ecriture ont donc
-- lieu dans UNE SEULE instruction, sous le verrou de ligne. Meme semantique et meme forme que
-- batiment_caisse_mouvement, qui fait la meme chose pour batiments_etat.
CREATE OR REPLACE FUNCTION public.caisse_institution_mouvement(
  p_id              text,
  p_delta           numeric,
  p_exiger_existant boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_data   jsonb;
  v_solde  numeric;
  v_existe boolean;
BEGIN
  IF COALESCE(btrim(p_id), '') = '' OR p_delta IS NULL OR abs(p_delta) > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  SELECT data INTO v_data FROM public.caisses_batiments WHERE id = p_id FOR UPDATE;
  v_existe := FOUND;
  IF p_exiger_existant AND NOT v_existe THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_absente');
  END IF;

  v_solde := CASE WHEN v_existe AND jsonb_typeof(v_data -> 'solde') = 'number'
                  THEN (v_data ->> 'solde')::numeric ELSE 0 END;
  IF v_solde + p_delta < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'solde_insuffisant', 'solde', v_solde);
  END IF;

  IF v_existe THEN
    UPDATE public.caisses_batiments
       SET data = COALESCE(v_data, '{}'::jsonb) || jsonb_build_object('solde', v_solde + p_delta),
           updated_at = now()
     WHERE id = p_id;
  ELSE
    INSERT INTO public.caisses_batiments (id, data, updated_at)
    VALUES (p_id, jsonb_build_object('solde', v_solde + p_delta), now());
  END IF;

  RETURN jsonb_build_object('ok', true, 'solde', v_solde + p_delta);
END;
$$;
REVOKE ALL ON FUNCTION public.caisse_institution_mouvement(text, numeric, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.caisse_institution_mouvement(text, numeric, boolean) TO anon, authenticated, service_role;