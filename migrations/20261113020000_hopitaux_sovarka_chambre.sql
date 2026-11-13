-- Chambres des hôpitaux de Sovarka (décision de Fred, 13/11/2026).
-- Le patient hospitalisé arrive à 0 PA et ne peut pas bouger : il doit être conduit directement
-- dans la chambre, où il trouve Dormir et le repas de l'hôpital (data.js).
-- (1) Starovka et Krasnov reçoivent la pièce « chambre » (Novomirsk l'a depuis le 12/11).
-- (2) L'hospitalisation au dispensaire conduit dans la chambre quand l'hôpital en a une ; sinon,
--     comme avant, dans la première pièce (Républia et autres pays inchangés).
-- Idempotente.

UPDATE public.navigation_lieux_regles
   SET pieces = pieces || '["chambre"]'::jsonb
 WHERE pays = 'soviet' AND ville IN ('ville_a', 'ville_b') AND batiment = 'dispensaire-public-v'
   AND NOT pieces ? 'chambre';

DO $patch$
DECLARE d text := pg_get_functiondef('public.hospitalisation_lieu_rejoindre_interne(text,text,text,boolean,boolean)'::regprocedure);
  v_motif text := '  IF v_bat IS NULL THEN RETURN jsonb_build_object(''ok'',false,''raison'',''lieu_non_reference''); END IF;' || E'\n' || ' END IF;';
BEGIN
  IF position('hopital_chambre_sovarka_v1' IN d) = 0 THEN
    IF position(v_motif IN d) = 0 THEN RAISE EXCEPTION 'motif hospitalisation introuvable'; END IF;
    d := replace(d, v_motif,
      '  IF v_bat IS NULL THEN RETURN jsonb_build_object(''ok'',false,''raison'',''lieu_non_reference''); END IF;' || E'\n'
      || '  -- hopital_chambre_sovarka_v1 (Fred, 13/11/2026) : le patient est conduit dans la chambre, s''il y en a une.' || E'\n'
      || '  IF EXISTS (SELECT 1 FROM public.navigation_lieux_regles WHERE pays = p.country AND ville = v_ville' || E'\n'
      || '               AND batiment = v_bat AND pieces ? ''chambre'') THEN v_piece := ''chambre''; END IF;' || E'\n'
      || ' END IF;');
    EXECUTE d;
  END IF;
END $patch$;
