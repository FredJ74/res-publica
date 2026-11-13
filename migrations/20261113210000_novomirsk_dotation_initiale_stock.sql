-- Dotation initiale unique de Novomirsk, sans achat, debit ni creation de caisse.
-- On conserve les lots deja en stock et on n'ajoute que le complement necessaire.
-- Le stock du depot est plafonne a 5 000 unites, y compris en cas de changements concurrents.
DO $dotation$
DECLARE
  v_id text := 'soviet_capitale_entrepot-logistique-novomirsk';
  v_cibles jsonb := '{"bois":500,"metal":250,"tabac":80,"alcool":150,"viande":100,"charbon":450,"minerai":250,"petrole":160,"plantes":140,"poisson":170,"textile":250,"cereales":260,"laitages":100,"carburant":100,"medicaments":70,"desinfectant":90,"fruits_legumes":230}'::jsonb;
  v_donnees jsonb;
  v_stock jsonb;
  v_cle text;
  v_cible integer;
  v_actuel integer;
  v_ajout integer;
  v_total integer;
BEGIN
  SELECT data INTO v_donnees FROM public.batiments_etat
    WHERE id=v_id AND country='soviet' AND city='capitale'
      AND building_id='entrepot-logistique-novomirsk' FOR UPDATE;
  IF NOT FOUND OR jsonb_typeof(v_donnees) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'Entrepot de Novomirsk absent ou format inattendu';
  END IF;
  IF EXISTS (SELECT 1 FROM public.entrepot_journal
     WHERE entrepot_id=v_id AND operation='dotation_initiale_novomirsk_20261113') THEN
    RETURN;
  END IF;
  v_stock := coalesce(v_donnees #> '{entrepot,stock}', '{}'::jsonb);
  IF jsonb_typeof(v_stock) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'Stock entrepot non representable';
  END IF;
  FOR v_cle, v_cible IN SELECT key, value::integer FROM jsonb_each_text(v_cibles)
  LOOP
    v_actuel := greatest(coalesce((v_stock->>v_cle)::integer,0),0);
    v_ajout := greatest(v_cible-v_actuel,0);
    IF v_ajout > 0 THEN
      v_stock := jsonb_set(v_stock,ARRAY[v_cle],to_jsonb(v_actuel+v_ajout),true);
      INSERT INTO public.entrepot_journal
        (entrepot_id,jour,operation,sens,contrepartie,ressource,quantite,statut)
      VALUES (v_id,(now() AT TIME ZONE 'Europe/Paris')::date,
       'dotation_initiale_novomirsk_20261113','entree','État de Sovarka',
       v_cle,v_ajout,'livre');
    END IF;
  END LOOP;
  SELECT sum(value::integer) INTO v_total FROM jsonb_each_text(v_stock);
  IF v_total > 5000 THEN RAISE EXCEPTION 'Capacite depassee : %',v_total; END IF;
  UPDATE public.batiments_etat
    SET data=jsonb_set(v_donnees,'{entrepot,stock}',v_stock,true)
    WHERE id=v_id;
END $dotation$;
