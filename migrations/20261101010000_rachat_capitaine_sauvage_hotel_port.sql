-- Rachat du Capitaine Sauvage et de l'Hôtel du Port (PSM), décision de Fred (01/11/2026) :
-- mêmes prix que leurs équivalents de Montrouge, Capitaine Sauvage 120 000 FR (comme la
-- Brasserie des Voyageurs), Hôtel du Port 80 000 FR (comme l'Hôtel de la Victoire).
-- Indépendante de l'écran : ajouter un prix au miroir ne change rien tant que l'écran ne propose
-- pas ces commerces ; aucune donnée de joueur touchée. Miroir aligné sur PRIX_RACHAT_COMMERCE
-- (plateau-actions-illegales-rumeurs.js), lu par entreprise_prix_rachat (clé = buildingId).
BEGIN;

INSERT INTO public.entreprises_prix_rachat (batiment, prix) VALUES
  ('capitaine-sauvage', 120000),
  ('hotel-port', 80000)
ON CONFLICT (batiment) DO UPDATE SET prix = EXCLUDED.prix;

DO $$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.entreprises_prix_rachat
   WHERE (batiment, prix) IN (('capitaine-sauvage', 120000), ('hotel-port', 80000),
                              ('brasserie-voyageurs-montrouge', 120000), ('hotel-mineur', 80000));
  IF n <> 4 THEN RAISE EXCEPTION 'miroir_prix_rachat_inattendu: % lignes sur 4', n; END IF;
END $$;

COMMIT;
