-- A jouer APRES le corps de la migration 20261104090000, dans la meme transaction annulee.
-- Lecture comme le navigateur, puis fabrication d'une armoire a souvenirs par Jean Jaaj.
DO $$
DECLARE n text := 'Jean Jaaj'; u uuid; r jsonb; e jsonb; pa0 integer; pa1 integer;
BEGIN
  SELECT user_id INTO u FROM public.personnages_donnees WHERE name = n;
  UPDATE public.personnages_donnees SET pa = greatest(coalesce(pa,0), 10) WHERE name = n;
  SELECT pa INTO pa0 FROM public.personnages_donnees WHERE name = n;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.path', '/rpc/fabriquer_produit_manufacture', true);
  SET LOCAL ROLE authenticated;
  -- Lecture du catalogue (meme requete que sbGetBatimentEtat).
  SELECT (data #>> '{}')::jsonb INTO e FROM public.batiments_etat WHERE id = 'republic_ville_a_zone-production';
  IF e->'usine'->'stockMatieres'->>'bois' IS DISTINCT FROM '150' THEN RAISE EXCEPTION 'lecture: %', e; END IF;
  r := public.fabriquer_produit_manufacture(n, 'republic', 'armoire_souvenirs');
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'fabrication: %', r; END IF;
  RESET ROLE;
  SELECT public.batiment_etat_lire(data) INTO e FROM public.batiments_etat WHERE id = 'republic_ville_a_zone-production';
  SELECT pa INTO pa1 FROM public.personnages_donnees WHERE name = n;
  IF (e#>>'{usine,stockMatieres,bois}')::numeric <> 148 OR (e#>>'{usine,stockMatieres,minerai}')::numeric <> 18
     OR (e#>>'{usine,stockProduits,armoire_souvenirs}')::numeric <> 1 OR pa1 <> pa0 - 3 THEN
    RAISE EXCEPTION 'bilan: % PA % -> %', e, pa0, pa1; END IF;
  RAISE EXCEPTION 'banc_ok_rien_ne_reste (bois 148, minerai 18, armoire 1, PA % -> %)', pa0, pa1;
END $$;
