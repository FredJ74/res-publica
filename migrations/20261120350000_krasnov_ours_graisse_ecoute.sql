-- LOT DE KRASNOV (1re partie), points rapides (Fred, 20/11/2026). GAME-DESIGN-KRASNOV-LOT-20261120.md.
--  1. Forêt des bûcherons : un ours tué donne EN PLUS 10 pots de graisse d'ours (le bocal existant, qui protège aussi
--     du blizzard), avec viande, peau et 2 dents.
--  4. Kolkhoze S. M. Kirov : caisse commune ergonomique — on saisit la quantité de chaque matière, puis un seul ordre
--     « Donner » (kolkhoze_caisse_donner_lot). Tout ou rien : un seul refus annule le lot entier.
-- Idempotente.
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN
    RAISE EXCEPTION '% : ancrage introuvable ou multiple (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

SELECT pg_temp.rp_raccorder('public.sovarka_foret_issue_combat_interne(text,text,text)'::regprocedure,
  $a$              WHERE c ? 'dents' AND p_issue <> 'fuite' LOOP$a$,
  $b$              WHERE c ? 'dents' AND p_issue <> 'fuite'
             UNION ALL  /* krasnov_graisse_ours_v1 : 10 pots de graisse d'ours par ours tué */
             SELECT public.graisse_objet_interne('graisse_ours', 10) WHERE e.creature = 'ours' AND p_issue <> 'fuite' LOOP$b$,
  'krasnov_graisse_ours_v1');

CREATE OR REPLACE FUNCTION public.kolkhoze_caisse_donner_lot(p_requete uuid, p_lot jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('lot', p_lot); v jsonb; d text;
  k text; q integer; n integer := 0; total integer := 0; pop integer := 0; lignes jsonb := '[]'::jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_lot IS NULL OR jsonb_typeof(p_lot) <> 'object' THEN RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'kolkhoze_caisse_donner_lot', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    FOR k, q IN SELECT key, CASE WHEN jsonb_typeof(value) = 'number' THEN floor((value #>> '{}')::numeric)::integer END
                  FROM jsonb_each(p_lot) ORDER BY key LOOP
      IF q IS NULL OR q < 0 THEN RAISE EXCEPTION 'refus' USING ERRCODE = 'HG001', DETAIL = jsonb_build_object('ok', false, 'raison', 'quantite_invalide', 'cle', k)::text; END IF;
      CONTINUE WHEN q = 0;
      v := public.kolkhoze_caisse_donner_interne(a, k, q);
      IF (v->>'ok')::boolean IS DISTINCT FROM true THEN
        RAISE EXCEPTION 'refus' USING ERRCODE = 'HG001', DETAIL = (coalesce(v, '{"ok":false}'::jsonb) || jsonb_build_object('cle', k))::text; END IF;
      n := n + 1; total := total + coalesce((v->>'quantite')::integer, q); pop := pop + coalesce((v->>'gain_pop')::integer, 0);
      lignes := lignes || jsonb_build_object('cle', k, 'nom', v->>'nom', 'quantite', coalesce((v->>'quantite')::integer, q));
    END LOOP;
    IF n = 0 THEN RAISE EXCEPTION 'refus' USING ERRCODE = 'HG001', DETAIL = '{"ok":false,"raison":"quantite_invalide"}'; END IF;
    v := v || jsonb_build_object('lignes', lignes, 'quantite', total, 'gain_pop', pop);
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'kolkhoze_caisse_donner_lot', prm, v);
END $$;
REVOKE ALL ON FUNCTION public.kolkhoze_caisse_donner_lot(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kolkhoze_caisse_donner_lot(uuid, jsonb) TO authenticated;

COMMIT;
