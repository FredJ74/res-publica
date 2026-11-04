-- A jouer APRES le corps de la migration 20261104021000, dans la meme transaction annulee.
-- BANC (annulé) : Ben (peu d'argent) reçoit trois employés témoins : un payé, un stagiaire à 0,
-- un trop cher (départ pour impayé) ; une escort n'est pas payée ici.
DO $$
DECLARE n text := 'Ben'; u uuid; r jsonb; f0 numeric; f1 numeric; m record;
BEGIN
  SELECT user_id INTO u FROM public.personnages_donnees WHERE name = n;
  SELECT liquide + coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage=n AND banque='nationale'),0)
    INTO f0 FROM public.personnages_donnees WHERE name = n;
  INSERT INTO public.pnj_membres(id, famille, nom, pays, proprietaire_pj, statut) VALUES
    ('banc-emp-1','employe','Témoin payé','republic',n,'actif'),
    ('banc-emp-2','employe','Témoin stagiaire','republic',n,'actif'),
    ('banc-emp-3','employe','Témoin trop cher','republic',n,'actif'),
    ('banc-emp-4','employe','Témoin escort','republic',n,'actif');
  INSERT INTO public.pnj_employes_metier(pnj_id, job, role_libelle, cout_jour, genre, loyaute, depuis_jour) VALUES
    ('banc-emp-1','informateur','Témoin',100,'H',50,1), ('banc-emp-2','stagiaire','Témoin',0,'H',50,1),
    ('banc-emp-3','garde_du_corps','Témoin',99999999,'H',50,1), ('banc-emp-4','escort','Témoin',800,'F',50,1);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.path', '/rpc/employes_payer_jour', true);
  SET LOCAL ROLE authenticated;
  r := public.employes_payer_jour();
  IF (r->>'ok')::boolean IS NOT TRUE OR jsonb_array_length(r->'paies') <> 2 THEN RAISE EXCEPTION 'paie: %', r; END IF;
  IF NOT (r->'paies' @> '[{"pnj_id":"banc-emp-1","paye":true,"salaire":100}]'
      AND r->'paies' @> '[{"pnj_id":"banc-emp-3","paye":false}]') THEN RAISE EXCEPTION 'detail: %', r; END IF;
  r := public.employes_payer_jour();   -- second réveil du jour : rien
  IF jsonb_array_length(r->'paies') <> 0 THEN RAISE EXCEPTION 'double paie: %', r; END IF;
  RESET ROLE;
  SELECT liquide + coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage=n AND banque='nationale'),0)
    INTO f1 FROM public.personnages_donnees WHERE name = n;
  IF f1 <> f0 - 100 THEN RAISE EXCEPTION 'bilan: % -> %', f0, f1; END IF;
  IF (SELECT statut FROM public.pnj_membres WHERE id='banc-emp-3') <> 'disparu'
     OR (SELECT statut FROM public.pnj_membres WHERE id='banc-emp-1') <> 'actif'
     OR (SELECT statut FROM public.pnj_membres WHERE id='banc-emp-2') <> 'actif'
     OR (SELECT statut FROM public.pnj_membres WHERE id='banc-emp-4') <> 'actif' THEN RAISE EXCEPTION 'statuts'; END IF;
  RAISE EXCEPTION 'banc_ok_rien_ne_reste (fonds % -> %)', f0, f1;
END $$;
