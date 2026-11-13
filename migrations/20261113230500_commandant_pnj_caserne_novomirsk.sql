-- Commandant de Novomirsk : même source de vérité que le Commandant de Républia.
-- Le décor et les profils PNJ présentent « Commandant Igor Saveliev », mais le
-- registre des titulaires PNJ ne contenait aucun commandant en Sovarka.
-- Ne jamais remplacer un PJ déjà titulaire ni une nomination PNJ existante.
DO $commandant$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.postes_attribues
    WHERE country='soviet' AND poste_id='commandant'
  ) AND NOT EXISTS (
    SELECT 1 FROM public.titulaires_pnj
    WHERE country='soviet' AND poste_id='commandant'
  ) THEN
    INSERT INTO public.titulaires_pnj
      (id,country,poste_id,city,nom_pnj,updated_at)
    VALUES
      ('soviet_commandant_national','soviet','commandant',
       NULL,'Commandant Igor Saveliev',now())
    ON CONFLICT (id) DO NOTHING;
  END IF;
END $commandant$;
