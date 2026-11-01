-- Églises de Républia (décisions de Fred, 01/11/2026, audit AUDIT-EGLISES-REPUBLIA-20261101) :
-- +500 FR dans la caisse de chacune des trois églises (une seule fois : marque
-- « dotation_20261101 » dans la caisse) ; l'église de Montrouge s'appelle désormais
-- « Église Progressiste de Montrouge » (libellé du salaire de son prêtre). Indépendante de l'écran.
BEGIN;

UPDATE public.caisses_batiments
   SET data = jsonb_set(data, '{solde}', to_jsonb(coalesce((data->>'solde')::numeric, 0) + 500))
              || jsonb_build_object('dotation_20261101', 500),
       updated_at = now()
 WHERE id IN ('republic_tabernacle-impots', 'republic_notre-dame-mer', 'republic_eglise-montrouge')
   AND NOT (data ? 'dotation_20261101');

UPDATE public.salaires_religieux_declares
   SET libelle = 'Prêtre de l''Église Progressiste de Montrouge'
 WHERE cle = 'pretre:ville_b';

DO $$ BEGIN
  IF (SELECT count(*) FROM public.caisses_batiments
       WHERE id IN ('republic_tabernacle-impots', 'republic_notre-dame-mer', 'republic_eglise-montrouge')
         AND data ? 'dotation_20261101') <> 3 THEN
    RAISE EXCEPTION 'dotation_eglises_incomplete'; END IF;
END $$;

COMMIT;
