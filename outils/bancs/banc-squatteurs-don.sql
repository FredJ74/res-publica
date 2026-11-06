-- A jouer APRES le corps de la migration 20261104020000, dans la meme transaction annulee.
-- BANC (annulé) : Jean Jaaj placé sur le terrain 1 (Luthécia) le temps de la transaction ;
-- les jets sont rendus déterministes en remplaçant terrain_negociation_jet_interne (annulé aussi).
DO $$
DECLARE n text := 'Jean Jaaj'; u uuid; r jsonb; occ text; q uuid := gen_random_uuid(); fonds0 numeric; fonds numeric;
  pa0 integer; hp0 integer;
BEGIN
  -- Jets déterministes : la fonction de jet est remplacée le temps de la transaction annulée.
  EXECUTE $j$CREATE OR REPLACE FUNCTION public.terrain_negociation_jet_interne() RETURNS integer
   LANGUAGE plpgsql SET search_path TO 'public','pg_temp' AS $f$
  DECLARE s text := current_setting('banc.jets', true); v integer;
  BEGIN
    v := split_part(s, ',', 1)::integer;
    PERFORM set_config('banc.jets', CASE WHEN position(',' in s) > 0 THEN substr(s, position(',' in s) + 1) ELSE '' END, true);
    RETURN v;
  END $f$$j$;
  SELECT user_id INTO u FROM public.personnages_donnees WHERE name = n;
  UPDATE public.personnages_donnees SET country='republic', current_city='capitale', current_building='terrain-a-batir-1',
         pa = greatest(coalesce(pa,0), 10), hp = 100, hospitalisation = NULL WHERE name = n;
  UPDATE public.terrains_etat SET data = (data::jsonb - 'policeAppellee' - 'enqueteJusqua' - 'succession_gel'
         || '{"pnj":"squatter_cool","pnjData":null,"city":"capitale"}')::text WHERE id = 'republic_terrain-a-batir-1';
  SELECT liquide + coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage=n AND banque='nationale'),0), pa
    INTO fonds0, pa0 FROM public.personnages_donnees WHERE name = n;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.path', '/rpc/terrain_squatteurs_don', true);
  SET LOCAL ROLE authenticated;

  -- A. Squatteurs tranquilles, 1 000 FR, départ réussi.
  occ := public.terrain_occupation_action_preparer('terrain-a-batir-1','police')->>'occupation';
  PERFORM set_config('banc.jets', '100,1', true);
  r := public.terrain_squatteurs_don('terrain-a-batir-1', 1000, occ, q);
  IF r->>'issue' IS DISTINCT FROM 'depart' OR (r->>'preleve')::numeric <> 1000 OR r->'etat'->>'pnj' IS NOT NULL THEN
    RAISE EXCEPTION 'A depart: %', r - 'etat'; END IF;
  -- Rejeu de la même demande : aucun second prélèvement.
  r := public.terrain_squatteurs_don('terrain-a-batir-1', 1000, occ, q);
  IF (r->>'rejeu')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'A rejeu: %', r - 'etat'; END IF;
  r := public.terrain_squatteurs_don('terrain-a-batir-1', 900, occ, q);
  IF r->>'raison' IS DISTINCT FROM 'requete_reutilisee' THEN RAISE EXCEPTION 'A requete detournee: %', r; END IF;
  -- Plus de squatteurs : refus nommé.
  r := public.terrain_squatteurs_don('terrain-a-batir-1', 1000, occ, gen_random_uuid());
  IF (r->>'ok')::boolean IS NOT FALSE THEN RAISE EXCEPTION 'A apres depart: %', r; END IF;
  RESET ROLE;
  SELECT liquide + coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage=n AND banque='nationale'),0)
    INTO fonds FROM public.personnages_donnees WHERE name = n;
  IF fonds <> fonds0 - 1000 THEN RAISE EXCEPTION 'A bilan argent: % -> %', fonds0, fonds; END IF;

  -- B. Agressifs, 300 FR : billets jetés, rien n'est pris, 1 PA engagé.
  UPDATE public.terrains_etat SET data = (data::jsonb || '{"pnj":"squatter_agr"}')::text WHERE id = 'republic_terrain-a-batir-1';
  SELECT pa INTO pa0 FROM public.personnages_donnees WHERE name = n;
  SET LOCAL ROLE authenticated;
  occ := public.terrain_occupation_action_preparer('terrain-a-batir-1','police')->>'occupation';
  PERFORM set_config('banc.jets', '100', true);
  r := public.terrain_squatteurs_don('terrain-a-batir-1', 300, occ, gen_random_uuid());
  IF r->>'issue' IS DISTINCT FROM 'insulte' OR (r->>'preleve')::numeric <> 0 OR (r->>'pa')::int <> pa0 - 1 THEN
    RAISE EXCEPTION 'B insulte: %', r - 'etat'; END IF;
  -- C. Agressifs, 600 FR, échec : argent pris et −10 PV, ils restent.
  PERFORM set_config('banc.jets', '100,100', true);
  r := public.terrain_squatteurs_don('terrain-a-batir-1', 600, occ, gen_random_uuid());
  IF r->>'issue' IS DISTINCT FROM 'restent' OR (r->>'preleve')::numeric <> 600 OR (r->>'hp')::int <> 90
     OR r->'etat'->>'pnj' IS DISTINCT FROM 'squatter_agr' THEN RAISE EXCEPTION 'C echec: %', r - 'etat'; END IF;
  -- D. Fonds insuffisants : refus avant tout paiement.
  r := public.terrain_squatteurs_don('terrain-a-batir-1', 99999999, occ, gen_random_uuid());
  IF r->>'raison' IS DISTINCT FROM 'fonds_insuffisants' THEN RAISE EXCEPTION 'D fonds: %', r; END IF;
  -- E. Occupation périmée.
  r := public.terrain_squatteurs_don('terrain-a-batir-1', 600, 'ancienne:squatter_cool', gen_random_uuid());
  IF r->>'raison' IS DISTINCT FROM 'occupation_modifiee' THEN RAISE EXCEPTION 'E occupation: %', r - 'etat'; END IF;
  RESET ROLE;
  -- F. Cadavre : on ne lui donne rien.
  UPDATE public.terrains_etat SET data = (data::jsonb || '{"pnj":"cadavre"}')::text WHERE id = 'republic_terrain-a-batir-1';
  SET LOCAL ROLE authenticated;
  occ := public.terrain_occupation_action_preparer('terrain-a-batir-1','police')->>'occupation';
  r := public.terrain_squatteurs_don('terrain-a-batir-1', 600, occ, gen_random_uuid());
  IF r->>'raison' IS DISTINCT FROM 'aucun_squatteur' THEN RAISE EXCEPTION 'F cadavre: %', r - 'etat'; END IF;
  RESET ROLE;
  SELECT liquide + coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage=n AND banque='nationale'),0), pa
    INTO fonds, pa0 FROM public.personnages_donnees WHERE name = n;
  IF fonds <> fonds0 - 1600 THEN RAISE EXCEPTION 'bilan argent: % -> %', fonds0, fonds; END IF;
  RAISE EXCEPTION 'banc_ok_rien_ne_reste (fonds % -> %, PA restants %)', fonds0, fonds, pa0;
END $$;
