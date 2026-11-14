-- Krasnov, place de l'Ours : huit appartements populaires distincts de l'immeuble commercial.
-- 4 petits (10 PSK) et 4 grands (20 PSK), règles identiques aux logements sociaux de Sovarka.
-- Migration non destructive : arrêter si le bâtiment a déjà des baux pour éviter toute modification.
BEGIN;
DO $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles WHERE pays='soviet' AND ville='ville_b' AND batiment='logements-krasnov-place-ours' AND pieces='["hall"]'::jsonb AND NOT ferme)
 THEN RAISE EXCEPTION 'Hall de la place de l Ours absent ou déjà modifié'; END IF;
 IF EXISTS (SELECT 1 FROM public.logements_sociaux_historiques WHERE pays='soviet' AND ville='ville_b' AND batiment='logements-krasnov-place-ours')
 THEN RAISE EXCEPTION 'Baux déjà présents : migration à ne pas rejouer'; END IF;
END $$;
INSERT INTO public.logements_sociaux_historiques
 (pays,ville,batiment,piece,label,type_logement,loyer,bonus_moral,bonus_sante)
VALUES
 ('soviet','ville_b','logements-krasnov-place-ours','petit_appartement_1','Appartement une chambre n°1','petit',10,3,4),
 ('soviet','ville_b','logements-krasnov-place-ours','petit_appartement_2','Appartement une chambre n°2','petit',10,3,4),
 ('soviet','ville_b','logements-krasnov-place-ours','petit_appartement_3','Appartement une chambre n°3','petit',10,3,4),
 ('soviet','ville_b','logements-krasnov-place-ours','petit_appartement_4','Appartement une chambre n°4','petit',10,3,4),
 ('soviet','ville_b','logements-krasnov-place-ours','grand_appartement_1','Appartement deux chambres n°1','grand',20,5,7),
 ('soviet','ville_b','logements-krasnov-place-ours','grand_appartement_2','Appartement deux chambres n°2','grand',20,5,7),
 ('soviet','ville_b','logements-krasnov-place-ours','grand_appartement_3','Appartement deux chambres n°3','grand',20,5,7),
 ('soviet','ville_b','logements-krasnov-place-ours','grand_appartement_4','Appartement deux chambres n°4','grand',20,5,7);
UPDATE public.navigation_lieux_regles
 SET pieces='["hall","petit_appartement_1","petit_appartement_2","petit_appartement_3","petit_appartement_4","grand_appartement_1","grand_appartement_2","grand_appartement_3","grand_appartement_4"]'::jsonb
 WHERE pays='soviet' AND ville='ville_b' AND batiment='logements-krasnov-place-ours'
 AND pieces='["hall"]'::jsonb;
DO $$
BEGIN
 IF (SELECT count(*) FROM public.logements_sociaux_historiques
 WHERE pays='soviet' AND ville='ville_b' AND batiment='logements-krasnov-place-ours') <> 8
 OR NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles
 WHERE pays='soviet' AND ville='ville_b' AND batiment='logements-krasnov-place-ours'
 AND jsonb_array_length(pieces)=9 AND pieces ? 'hall')
 THEN RAISE EXCEPTION 'Logements place de l Ours : contrôle final échoué'; END IF;
END $$;
COMMIT;
