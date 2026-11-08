-- Novomirsk : la facade gauche de V12 devient la mairie, la caserne conserve V11.
-- Ne change ni les pieces, ni les ordres des deux batiments.
DO $novomirsk_mairie$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.navigation_lieux_regles
    WHERE pays='soviet' AND ville='capitale' AND batiment='mairie-capitale'
  ) OR NOT EXISTS (
    SELECT 1 FROM public.rue_sorties_batiments
    WHERE country='soviet' AND city='capitale'
      AND noeud='novomirsk-vue-11' AND building='caserne-militaire'
  ) THEN
    RAISE EXCEPTION 'novomirsk_mairie_socle_ou_caserne_absent';
  END IF;

  DELETE FROM public.rue_sorties_batiments
  WHERE country='soviet' AND city='capitale'
    AND noeud='novomirsk-vue-12' AND building='caserne-militaire';

  INSERT INTO public.rue_sorties_batiments(country,city,noeud,building)
  VALUES ('soviet','capitale','novomirsk-vue-12','mairie-capitale')
  ON CONFLICT DO NOTHING;

  IF NOT EXISTS (
    SELECT 1 FROM public.rue_sorties_batiments
    WHERE country='soviet' AND city='capitale'
      AND noeud='novomirsk-vue-12' AND building='mairie-capitale'
  ) OR EXISTS (
    SELECT 1 FROM public.rue_sorties_batiments
    WHERE country='soviet' AND city='capitale'
      AND noeud='novomirsk-vue-12' AND building='caserne-militaire'
  ) OR public.caserne_noeud('soviet') IS DISTINCT FROM 'novomirsk-vue-11'
  THEN
    RAISE EXCEPTION 'novomirsk_mairie_raccordement_incomplet';
  END IF;
END $novomirsk_mairie$;