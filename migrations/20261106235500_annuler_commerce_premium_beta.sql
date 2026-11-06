-- ANNULATION DE 20261106234500_commerce_premium_beta (Fred, 06/11/2026, 23 h 53) : malentendu.
-- Le système freemium / premium des locaux fonctionne déjà à Luthécia et se reprend tel quel ailleurs :
-- freemium = 2 familles, 4 articles, illustration générique avec le nom sur le fronton ;
-- premium = 3 familles, 10 articles et personnalisation complète du local par IA. Pendant la bêta,
-- le premium est offert à tous (plafonds 3 / 10 pour chacun, atelier de décoration gratuit).
-- On rétablit exactement l'état d'avant : constantes, fonctions d'origine, fiches des commerces.
INSERT INTO public.entreprises_constantes (cle, valeur) VALUES ('types_commerce_max_base','3'), ('references_max_base','10')
ON CONFLICT (cle) DO UPDATE SET valeur = EXCLUDED.valeur;
DELETE FROM public.entreprises_constantes
 WHERE cle IN ('types_commerce_max_premium','references_max_premium','commerce_premium_gratuit_beta');

DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.fonds_definir_types(text,text,text[])'::regprocedure);
  v_new := replace(v_def, $a$v_max := public.fonds_types_max_fonds(v_data);$a$,
                          $n$v_max := public.fonds_types_max(v_data ->> 'proprietaire');$n$);
  IF v_new = v_def THEN RAISE EXCEPTION 'retour fonds_definir_types non appliqué'; END IF;
  EXECUTE v_new;
  v_def := pg_get_functiondef('public.fonds_reference_creer(text,text,text,text,text,text)'::regprocedure);
  v_new := replace(v_def, $a$public.fonds_references_max_fonds(v_data)$a$, $n$public.fonds_references_max(v_data->>'proprietaire')$n$);
  IF v_new = v_def THEN RAISE EXCEPTION 'retour fonds_reference_creer non appliqué'; END IF;
  EXECUTE v_new;
END $mig$;

DROP FUNCTION IF EXISTS public.fonds_premium_activer(text);
DROP FUNCTION IF EXISTS public.fonds_types_max_fonds(jsonb);
DROP FUNCTION IF EXISTS public.fonds_references_max_fonds(jsonb);

UPDATE public.entreprises SET data = data - 'premium' - 'premiumDepuis' - 'premiumSource', updated_at = now()
 WHERE id LIKE 'fonds-%' AND data->>'premiumSource' IN ('acquis_avant_option','beta_gratuite');

DO $$
BEGIN
  IF public.fonds_types_max('x') <> 3 OR public.fonds_references_max('x') <> 10 THEN RAISE EXCEPTION 'plafonds non rétablis'; END IF;
  IF EXISTS (SELECT 1 FROM public.entreprises WHERE data ? 'premiumSource') THEN RAISE EXCEPTION 'marques premium restantes'; END IF;
  IF position('fonds_types_max(v_data ->> ''proprietaire'')' IN pg_get_functiondef('public.fonds_definir_types(text,text,text[])'::regprocedure)) = 0
    THEN RAISE EXCEPTION 'fonds_definir_types non rétablie'; END IF;
END $$;
