-- MALADIES — LOT 1 : nom lisible (français) des médicaments déposés en inventaire ; l'écran le traduit (plateau-maladies.js).
-- Déjà intégré à 20261118060000 pour une base neuve ; ce correctif ne s'applique qu'à une base qui a reçu la première version.
DO $$
DECLARE d text; a text;
BEGIN
  d := pg_get_functiondef('public.pharmacie_acheter_interne(text,text,integer)'::regprocedure);
  IF position('Anti-nauséeux' IN d) > 0 THEN RETURN; END IF;
  a := $a$jsonb_build_object('name', p_medicament, 'icon', 'ti-pill',$a$;
  IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'pharmacie_acheter_interne : ancrage'; END IF;
  EXECUTE replace(d, a, $b$jsonb_build_object('name', CASE p_medicament WHEN 'antinauseeux' THEN 'Anti-nauséeux' WHEN 'aspirine' THEN 'Aspirine' WHEN 'antigrippal' THEN 'Antigrippal' WHEN 'sels_rehydratation' THEN 'Sels de réhydratation' ELSE p_medicament END, 'icon', 'ti-pill',$b$);
END $$;
