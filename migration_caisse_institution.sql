-- =====================================================================
-- MOUVEMENT ATOMIQUE D'UNE CAISSE INSTITUTIONNELLE (12 septembre 2026)
-- =====================================================================
-- caisses_batiments porte les caisses des institutions ('<pays>_gouvernement-min_fin', mairies,
-- commissariats, hopitaux...), lues et reecrites jusqu'ici par le client en deux appels HTTP
-- (chargerCaisseBatiment puis sbSaveCaisseBatiment) : deux mouvements simultanes lisaient le meme
-- solde et la derniere ecriture ecrasait l'autre. Pour encaisser le prix d'une cession
-- (180 000 FR), un credit perdu serait inacceptable : lecture, calcul et ecriture ont donc lieu
-- dans UNE SEULE instruction, sous le verrou de ligne.
--
-- Meme semantique et meme forme que batiment_caisse_mouvement (migration_caisses_batiments_etat.sql),
-- qui fait la meme chose pour les caisses vivant dans batiments_etat : tout-ou-rien, jamais de
-- decouvert, et p_exiger_existant pour refuser de creer une caisse fantome quand l'appelant sait
-- que la caisse doit deja exister.
--
-- Les primitives historiques (crediterCaisseBatiment, debiterCaisseBatimentPlafonne,
-- debiterCaisseBatimentAtomique) ne sont PAS reroutees ici : elles restent en place pour leurs
-- dizaines d'appelants existants. Tout nouveau flux portant des montants significatifs doit passer
-- par cette RPC.
-- =====================================================================

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
