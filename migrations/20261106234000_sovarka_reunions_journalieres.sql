-- Novomirsk : reservation journaliere et atomique des salles du centre d'affaires.
-- Decision : grandes 150 PSK, moyennes 100 PSK. Jour civil Europe/Paris,
-- minuit cloture naturellement les reservations. Aucune autorite cliente.
CREATE TABLE IF NOT EXISTS public.sovarka_reunions_reservations (
  jour date NOT NULL,
  salle text NOT NULL CHECK (salle IN ('reunion_grande_a','reunion_grande_b','reunion_moyenne_a','reunion_moyenne_b')),
  reserve_par text NOT NULL,
  montant integer NOT NULL CHECK (montant IN (100,150)),
  reserve_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (jour,salle)
);
ALTER TABLE public.sovarka_reunions_reservations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.sovarka_reunions_reservations FROM PUBLIC,anon,authenticated;

INSERT INTO public.ordres_couts (fn,pa,cost) VALUES
  ('sovarka_reunion_grande_reserver',0,150),
  ('sovarka_reunion_moyenne_reserver',0,100)
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION public.sovarka_reunion_reserver(p_salle text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $$
DECLARE
  v_moi text;
  v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_existing public.sovarka_reunions_reservations%ROWTYPE;
  v_cout integer;
  v_fn text;
  v_paie jsonb;
  v_caisse text;
  v_credit jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  IF p_salle NOT IN ('reunion_grande_a','reunion_grande_b','reunion_moyenne_a','reunion_moyenne_b')
    OR p_salle IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','salle_inconnue'); END IF;

  -- L'emplacement est fourni uniquement par la position persistée côté serveur.
  IF NOT EXISTS (
    SELECT 1 FROM public.personnages_donnees p
     WHERE p.name=v_moi AND p.country='soviet' AND p.current_city='capitale'
       AND p.current_building='centre-affaires' AND p.current_room=p_salle
  ) THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;

  PERFORM pg_advisory_xact_lock(hashtext('sovarka:reunion:'||v_jour::text||':'||p_salle));
  SELECT * INTO v_existing FROM public.sovarka_reunions_reservations
   WHERE jour=v_jour AND salle=p_salle FOR UPDATE;
  IF FOUND THEN
    IF v_existing.reserve_par=v_moi THEN
      -- Une réponse réseau perdue n'entraîne jamais une deuxième facturation.
      RETURN jsonb_build_object('ok',true,'deja_reservee',true,'jour',v_jour,
        'salle',p_salle,'montant',v_existing.montant,'monnaie','PSK');
    END IF;
    RETURN jsonb_build_object('ok',false,'raison','salle_deja_reservee','jour',v_jour);
  END IF;

  v_cout := CASE WHEN p_salle LIKE 'reunion_grande_%' THEN 150 ELSE 100 END;
  v_fn := CASE WHEN v_cout=150 THEN 'sovarka_reunion_grande_reserver'
              ELSE 'sovarka_reunion_moyenne_reserver' END;
  -- Refus ferme si la caisse municipale n'est pas trouvée ; aucun argent perdu.
  v_caisse := public.salaire_caisse_de('maire','soviet','capitale');
  IF v_caisse IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','caisse_absente'); END IF;

  -- Le débit, l'écriture de réservation et le crédit de caisse sont une seule transaction.
  v_paie := public.payer_ordre_interne(v_moi,v_fn,0,v_cout);
  IF coalesce((v_paie->>'ok')::boolean,false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_credit := public.caisse_institution_mouvement(v_caisse,v_cout,true);
  IF coalesce((v_credit->>'ok')::boolean,false) IS NOT TRUE THEN
    RAISE EXCEPTION 'echec_credit_caisse_reunion_%',coalesce(v_credit->>'raison','inconnu');
  END IF;
  INSERT INTO public.sovarka_reunions_reservations(jour,salle,reserve_par,montant)
  VALUES(v_jour,p_salle,v_moi,v_cout);
  RETURN jsonb_build_object('ok',true,'deja_reservee',false,'jour',v_jour,
    'salle',p_salle,'montant',v_cout,'monnaie','PSK',
    'pa',v_paie->'pa','liquide',v_paie->'liquide',
    'arg',v_paie->'arg','solde_national',v_paie->'solde_national');
END $$;

REVOKE ALL ON FUNCTION public.sovarka_reunion_reserver(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sovarka_reunion_reserver(text) TO authenticated;
