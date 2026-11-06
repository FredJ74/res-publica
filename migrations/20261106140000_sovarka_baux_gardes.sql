-- Sovarka : baux des droits d'exploiter face aux gardes des baux (Claude, 06/11/2026, suite de 20261106133000).
--
-- Les gardes de locations_actives lisent le référentiel des locaux par ville SANS pays : en Sovarka, le
-- centre commercial de Novomirsk (ville « capitale ») était lu comme celui de Luthécia. Deux effets :
--   * location_local_creation_serveur refusait le bail signé chez le notaire (bail_signe_par_le_serveur) ;
--   * location_local_tarif_attester aurait imposé le loyer de Républia (400 FR) au lieu du loyer du maire.
-- Correctif : un bail de Sovarka n'est créé que par sovarka_attribution_signer, qui le marque pour sa
-- transaction (sovarka_baux_internes) ; le loyer d'un local de Sovarka vient toujours de sovarka_locaux.

CREATE TABLE IF NOT EXISTS public.sovarka_baux_internes (txid bigint NOT NULL, bail text NOT NULL, PRIMARY KEY (txid, bail));
ALTER TABLE public.sovarka_baux_internes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_baux_internes FROM anon, authenticated;

DO $$
DECLARE d text; ancre text := '  IF public.est_appel_serveur() OR NEW.data IS NULL THEN RETURN NEW; END IF;';
BEGIN
  d := pg_get_functiondef('public.location_local_creation_serveur'::regproc);
  IF strpos(d, 'sovarka_baux_internes') = 0 THEN
    IF strpos(d, ancre) = 0 THEN RAISE EXCEPTION 'location_local_creation_serveur : ancre introuvable'; END IF;
    EXECUTE replace(d, ancre, ancre||chr(10)||
      '  IF EXISTS (SELECT 1 FROM public.sovarka_baux_internes s WHERE s.txid = txid_current() AND s.bail = NEW.id) THEN RETURN NEW; END IF; -- sovarka_droits_exploiter_v1');
  END IF;
  d := pg_get_functiondef('public.location_local_tarif_attester'::regproc);
  IF strpos(d, 'sovarka_locaux') = 0 THEN
    IF strpos(d, ancre) = 0 THEN RAISE EXCEPTION 'location_local_tarif_attester : ancre introuvable'; END IF;
    EXECUTE replace(d, ancre, ancre||chr(10)||
      '  IF NEW.country = ''soviet'' AND EXISTS (SELECT 1 FROM public.sovarka_locaux s WHERE s.pays = ''soviet'' AND s.ville = NEW.data->>''city'''||
      ' AND s.batiment = NEW.data->>''buildingId'' AND s.piece = NEW.data->>''roomId'') THEN'||chr(10)||
      '    NEW.data := NEW.data || jsonb_build_object(''prix'', (SELECT s.loyer FROM public.sovarka_locaux s WHERE s.pays = ''soviet'''||
      ' AND s.ville = NEW.data->>''city'' AND s.batiment = NEW.data->>''buildingId'' AND s.piece = NEW.data->>''roomId''),'||
      ' ''bonusPOP'', 0, ''bonusINF'', 0, ''bonusDIS'', 0);'||chr(10)||
      '    RETURN NEW;'||chr(10)||
      '  END IF; -- sovarka_droits_exploiter_v1');
  END IF;
  -- La signature marque son bail avant de l'écrire.
  d := pg_get_functiondef('public.sovarka_attribution_signer(text)'::regprocedure);
  IF strpos(d, 'sovarka_baux_internes') = 0 THEN
    ancre := '    INSERT INTO public.locations_actives (id, country, data) VALUES (v_id, ''soviet'', jsonb_build_object(';
    IF strpos(d, ancre) = 0 THEN RAISE EXCEPTION 'sovarka_attribution_signer : ancre introuvable'; END IF;
    EXECUTE replace(d, ancre, '    INSERT INTO public.sovarka_baux_internes VALUES (txid_current(), v_id) ON CONFLICT DO NOTHING;'||chr(10)||ancre);
  END IF;
END $$;
