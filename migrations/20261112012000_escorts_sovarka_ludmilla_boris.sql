-- Contenu de l'agence internationale Roxanne Velours pour Sovarka.
-- Aucun changement aux mécanismes de recrutement, aux tarifs et aux autres empires.
-- Appliquer seulement quand les quatre WebP sont déployés et accessibles.
INSERT INTO public.escorts_agences (pays, nom)
VALUES ('soviet', 'Agence internationale Roxanne Velours')
ON CONFLICT (pays) DO NOTHING;

INSERT INTO public.escorts_catalogue
  (escort_id, pays, nom, genre, portrait, vignette, cadrage, rang, actif)
VALUES
  ('escort_sovarka_ludmilla_bonaskova', 'soviet', 'Ludmilla Bonaskova', 'F',
   'images/Sovarka/Novomirsk/Sovarka_escort_Ludmilla_Bonaskova.webp',
   'images/Sovarka/Novomirsk/Sovarka_escort_Ludmilla_Bonaskova_vignette.webp',
   '50% 12%', 1, true),
  ('escort_sovarka_boris_kostof', 'soviet', 'Boris Kostof', 'H',
   'images/Sovarka/Novomirsk/Sovarka_escort_Boris_Kostof.webp',
   'images/Sovarka/Novomirsk/Sovarka_escort_Boris_Kostof_vignette.webp',
   '50% 12%', 1, true)
ON CONFLICT (escort_id) DO NOTHING;

DO $garde$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.escorts_catalogue
  WHERE escort_id IN ('escort_sovarka_ludmilla_bonaskova','escort_sovarka_boris_kostof')
    AND pays='soviet' AND actif AND portrait LIKE 'images/Sovarka/Novomirsk/%.webp'
    AND vignette LIKE 'images/Sovarka/Novomirsk/%_vignette.webp';
  IF n <> 2 THEN RAISE EXCEPTION 'Casting Sovarka incomplet : %/2',n; END IF;
  SELECT count(*) INTO n FROM public.escorts_catalogue
  WHERE pays='republic';
  IF n <> 7 THEN RAISE EXCEPTION 'Le casting de Republia a changé : %/7',n; END IF;
  SELECT count(*) INTO n FROM public.escorts_agences WHERE pays='soviet';
  IF n<>1 THEN RAISE EXCEPTION 'Agence Sovarka absente'; END IF;
END $garde$;
