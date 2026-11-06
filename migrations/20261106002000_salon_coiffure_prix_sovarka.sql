-- Prix de la coupe au salon de Novomirsk, decision de Fred du 06/11/2026
-- (GAME-DESIGN-SALON-COIFFURE.md) : 20 PSK au client. Ne remplace qu'un prix encore absent
-- (un prix deja fixe par un futur proprietaire n'est jamais ecrase). Independante de l'ecran :
-- l'ecran deja en beta affiche l'ordre grise, le serveur accepte simplement la coupe.
BEGIN;
UPDATE public.entreprises
   SET data = jsonb_set(data, '{prestations,coupe,prixVente}', '20'), updated_at = now()
 WHERE id = 'salon-soviet-capitale'
   AND (data->'prestations'->'coupe'->>'prixVente') IS NULL;
DO $$
BEGIN
  IF (SELECT (data->'prestations'->'coupe'->>'prixVente')::numeric FROM public.entreprises
       WHERE id = 'salon-soviet-capitale') IS DISTINCT FROM 20 THEN
    RAISE EXCEPTION 'prix_coupe_novomirsk_inattendu';
  END IF;
END $$;
COMMIT;
