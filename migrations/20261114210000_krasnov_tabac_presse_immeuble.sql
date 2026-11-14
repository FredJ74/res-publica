-- Krasnov : deux commerces distincts et immeuble à droite du tabac sur la même vue de rue.
-- Aucun changement de la navigation historique, aucun bail modifié sur les autres immeubles.
BEGIN;
DO $$
BEGIN
 IF NOT EXISTS (
   SELECT 1 FROM public.rue_noeuds_serveur WHERE country='soviet' AND city='ville_b'
   AND noeud='krasnov-rue-tabac-bar'
 ) THEN RAISE EXCEPTION 'Rue du tabac absente'; END IF;
 IF EXISTS (
   SELECT 1 FROM public.logements_sociaux_historiques WHERE pays='soviet' AND ville='ville_b'
   AND batiment='logements-krasnov-rue-tabac'
 ) THEN RAISE EXCEPTION 'Logements déjà initialisés : ne pas réappliquer'; END IF;
END $$;
INSERT INTO public.navigation_lieux_regles(pays,ville,batiment,pieces,ferme,membership)
VALUES ('soviet','ville_b','tabac-presse-krasnov','["boutique"]'::jsonb,false,NULL),
       ('soviet','ville_b','logements-krasnov-rue-tabac','["hall","petit_appartement_1","petit_appartement_2","petit_appartement_3","petit_appartement_4","grand_appartement_1","grand_appartement_2","grand_appartement_3","grand_appartement_4"]'::jsonb,false,NULL)
ON CONFLICT(pays,ville,batiment) DO NOTHING;
INSERT INTO public.rue_sorties_batiments(country,city,noeud,building)
VALUES ('soviet','ville_b','krasnov-rue-tabac-bar','tabac-presse-krasnov'),
       ('soviet','ville_b','krasnov-rue-tabac-bar','logements-krasnov-rue-tabac')
ON CONFLICT DO NOTHING;
INSERT INTO public.logements_sociaux_historiques
 (pays,ville,batiment,piece,label,type_logement,loyer,bonus_moral,bonus_sante)
VALUES
 ('soviet','ville_b','logements-krasnov-rue-tabac','petit_appartement_1','Appartement une chambre n°1','petit',10,3,4),
 ('soviet','ville_b','logements-krasnov-rue-tabac','petit_appartement_2','Appartement une chambre n°2','petit',10,3,4),
 ('soviet','ville_b','logements-krasnov-rue-tabac','petit_appartement_3','Appartement une chambre n°3','petit',10,3,4),
 ('soviet','ville_b','logements-krasnov-rue-tabac','petit_appartement_4','Appartement une chambre n°4','petit',10,3,4),
 ('soviet','ville_b','logements-krasnov-rue-tabac','grand_appartement_1','Appartement deux chambres n°1','grand',20,5,7),
 ('soviet','ville_b','logements-krasnov-rue-tabac','grand_appartement_2','Appartement deux chambres n°2','grand',20,5,7),
 ('soviet','ville_b','logements-krasnov-rue-tabac','grand_appartement_3','Appartement deux chambres n°3','grand',20,5,7),
 ('soviet','ville_b','logements-krasnov-rue-tabac','grand_appartement_4','Appartement deux chambres n°4','grand',20,5,7);
DO $$
BEGIN
 IF (SELECT count(*) FROM public.logements_sociaux_historiques WHERE pays='soviet' AND ville='ville_b' AND batiment='logements-krasnov-rue-tabac')<>8
 OR NOT EXISTS(SELECT 1 FROM public.navigation_lieux_regles WHERE pays='soviet' AND ville='ville_b' AND batiment='tabac-presse-krasnov' AND pieces='["boutique"]'::jsonb AND NOT ferme)
 OR NOT EXISTS(SELECT 1 FROM public.navigation_lieux_regles WHERE pays='soviet' AND ville='ville_b' AND batiment='logements-krasnov-rue-tabac' AND jsonb_array_length(pieces)=9 AND NOT ferme)
 OR (SELECT count(*) FROM public.rue_sorties_batiments WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-tabac-bar' AND building IN ('tabac-presse-krasnov','logements-krasnov-rue-tabac'))<>2
 THEN RAISE EXCEPTION 'Krasnov : commerce/immeuble mal raccordés'; END IF;
END $$;
COMMIT;
