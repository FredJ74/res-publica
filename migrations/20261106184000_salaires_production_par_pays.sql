-- Salaire de production des usines par pays (decision de Fred du 06/11/2026) : en Sovarka, ou un PA
-- vaut environ 15 PSK, le salaire de production se situe entre 15 et 20 PSK par PA (au lieu des 84 et
-- 70 de Republia). Valeurs retenues dans cette fourchette : medicaments 18 PSK, desinfectant 15 PSK
-- (meme ordre que la Republia). Sans ligne pour un pays, le salaire du gabarit
-- (chaines_production_usine, miroir de data.js) s'applique, inchange.
-- produire_en_usine est patchee en place (fragment exact, jamais retapee).
BEGIN;

CREATE TABLE IF NOT EXISTS public.salaires_production_pays (
  pays text NOT NULL, produit text NOT NULL, salaire_pa numeric NOT NULL CHECK (salaire_pa >= 0),
  PRIMARY KEY (pays, produit));
ALTER TABLE public.salaires_production_pays ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.salaires_production_pays FROM anon, authenticated;
GRANT SELECT ON public.salaires_production_pays TO authenticated;
DROP POLICY IF EXISTS "salaires production lecture" ON public.salaires_production_pays;
CREATE POLICY "salaires production lecture" ON public.salaires_production_pays FOR SELECT TO authenticated USING (true);

INSERT INTO public.salaires_production_pays (pays, produit, salaire_pa) VALUES
  ('soviet', 'medicaments', 18), ('soviet', 'desinfectant', 15)
ON CONFLICT (pays, produit) DO UPDATE SET salaire_pa = EXCLUDED.salaire_pa;

DO $$
DECLARE f text; frag text := 'FROM public.chaines_production_usine WHERE produit = p_produit;'; n integer;
BEGIN
  f := pg_get_functiondef('public.produire_en_usine(text,text,text)'::regprocedure);
  IF position('salaires_production_pays' IN f) = 0 THEN
    n := (length(f) - length(replace(f, frag, ''))) / length(frag);
    IF n <> 1 THEN RAISE EXCEPTION 'produire_en_usine_definition_non_examinee (%)', n; END IF;
    f := replace(f, frag, frag || E'\n  v_salaire := coalesce((SELECT s.salaire_pa FROM public.salaires_production_pays s WHERE s.pays = p_pays AND s.produit = p_produit), v_salaire); /* salaires_production_pays */');
    EXECUTE f;
  END IF;
  IF position('salaires_production_pays' IN pg_get_functiondef('public.produire_en_usine(text,text,text)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'produire_en_usine_non_patchee';
  END IF;
END $$;

COMMIT;
