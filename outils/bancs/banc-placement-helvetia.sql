-- Banc de 20261031151000_placement_helvetia_gain_unique (à jouer en production, tout est annulé).
-- Applique la correction (si elle ne l'est pas déjà), avance l'échéance du placement Helvetia
-- actif le plus ancien, le résout comme la passe de nuit et mesure les écarts.
-- Attendu : caisse + (frais + gain net) = + gain brut - impôt ; compte Helvetia + montant final ;
-- arg inchangé. Le résultat sort dans le message d'erreur final « BANC … ».
BEGIN;
DO $banc$
DECLARE d text; h text; p record; c0 numeric; c1 numeric; k0 numeric; k1 numeric;
  a0 numeric; a1 numeric; r record;
BEGIN
  SELECT md5(prosrc), pg_get_functiondef(oid) INTO h, d FROM pg_proc
   WHERE oid = 'public.resoudre_placement_helvetia(text)'::regprocedure;
  IF h = 'b81e7fdddb348bdabc34639429b1a139' THEN
    d := regexp_replace(d, $m$numeric, 0\) \+ v_frais\)$m$, $r$numeric, 0) + v_frais + v_gain_net)$r$);
    d := regexp_replace(d, $m$jsonb_build_object\('solde', v_frais\)$m$, $r$jsonb_build_object('solde', v_frais + v_gain_net)$r$);
    d := regexp_replace(d, $m$\n\s*UPDATE public\.personnages_donnees\s+set arg = coalesce\(arg, 0\) \+ v_gain_net\s+where name = v_placement\.personnage;$m$,
      E'\n  -- Le gain net va sur le compte Helvetia seul : `arg` (liquide + Banque nationale) ne bouge pas.');
    EXECUTE d;
    SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid = 'public.resoudre_placement_helvetia(text)'::regprocedure;
  END IF;

  SELECT * INTO p FROM public.placements_bancaires WHERE banque = 'helvetia' AND statut = 'actif'
   ORDER BY date_placement LIMIT 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'BANC empreinte=% : aucun placement actif', h; END IF;
  UPDATE public.placements_bancaires SET prochaine_echeance = now() - interval '1 minute' WHERE id = p.id;

  SELECT COALESCE((data->>'solde')::numeric, 0) INTO c0 FROM public.caisses_batiments
   WHERE id = COALESCE(p.pays, 'republic') || '_banque-privee';
  SELECT solde INTO k0 FROM public.comptes_bancaires WHERE personnage = p.personnage AND banque = 'helvetia';
  SELECT arg INTO a0 FROM public.personnages_donnees WHERE name = p.personnage;

  SELECT * INTO r FROM public.resoudre_placement_helvetia(p.id);

  SELECT COALESCE((data->>'solde')::numeric, 0) INTO c1 FROM public.caisses_batiments
   WHERE id = COALESCE(p.pays, 'republic') || '_banque-privee';
  SELECT solde INTO k1 FROM public.comptes_bancaires WHERE personnage = p.personnage AND banque = 'helvetia';
  SELECT arg INTO a1 FROM public.personnages_donnees WHERE name = p.personnage;

  RAISE EXCEPTION 'BANC empreinte=% placement=% type=% montant=% final=% caisse=%+ compte=%+ arg=%+',
    h, p.id, p.type, p.montant, r.montant_final, c1 - COALESCE(c0, 0), k1 - k0, a1 - a0;
END $banc$;
ROLLBACK;
