-- Krasnov : immeuble collectif face à l'Universam.
-- Réutilise les baux sociaux existants de Novomirsk, scoped sur ville_b.
-- Aucun droit de propriété supplémentaire et aucune mutation de personnage.
BEGIN;
DO $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.rue_noeuds_serveur
 WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-immeubles-centre-commercial')
 THEN RAISE EXCEPTION 'Rue de Krasnov introuvable'; END IF;
 IF EXISTS(SELECT 1 FROM public.logements_sociaux_historiques
 WHERE pays='soviet' AND ville='ville_b' AND batiment='logements-novomirsk')
 THEN RAISE EXCEPTION 'Logements de Krasnov déjà enregistrés : ne pas écraser les baux existants'; END IF;
END $$;

INSERT INTO public.logements_sociaux_historiques
 (pays,ville,batiment,piece,label,type_logement,loyer,bonus_moral,bonus_sante)
VALUES
 ('soviet','ville_b','logements-novomirsk','petit_appartement_1','Appartement une chambre n°1','petit',10,3,4),
 ('soviet','ville_b','logements-novomirsk','petit_appartement_2','Appartement une chambre n°2','petit',10,3,4),
 ('soviet','ville_b','logements-novomirsk','petit_appartement_3','Appartement une chambre n°3','petit',10,3,4),
 ('soviet','ville_b','logements-novomirsk','petit_appartement_4','Appartement une chambre n°4','petit',10,3,4),
 ('soviet','ville_b','logements-novomirsk','grand_appartement_1','Appartement deux chambres n°1','grand',20,5,7),
 ('soviet','ville_b','logements-novomirsk','grand_appartement_2','Appartement deux chambres n°2','grand',20,5,7),
 ('soviet','ville_b','logements-novomirsk','grand_appartement_3','Appartement deux chambres n°3','grand',20,5,7),
 ('soviet','ville_b','logements-novomirsk','grand_appartement_4','Appartement deux chambres n°4','grand',20,5,7);

INSERT INTO public.navigation_lieux_regles(pays,ville,batiment,pieces,ferme,membership)
VALUES ('soviet','ville_b','logements-novomirsk',
 '["salle","petit_appartement_1","petit_appartement_2","petit_appartement_3","petit_appartement_4","grand_appartement_1","grand_appartement_2","grand_appartement_3","grand_appartement_4"]'::jsonb,false,NULL)
ON CONFLICT(pays,ville,batiment) DO NOTHING;

INSERT INTO public.rue_sorties_batiments(country,city,noeud,building)
VALUES ('soviet','ville_b','krasnov-rue-immeubles-centre-commercial','logements-novomirsk')
ON CONFLICT DO NOTHING;

DO $$
BEGIN
 IF (SELECT count(*) FROM public.logements_sociaux_historiques
 WHERE pays='soviet' AND ville='ville_b' AND batiment='logements-novomirsk')<>8
 OR NOT EXISTS(SELECT 1 FROM public.navigation_lieux_regles
 WHERE pays='soviet' AND ville='ville_b' AND batiment='logements-novomirsk'
 AND jsonb_array_length(pieces)=9 AND pieces ? 'salle')
 OR NOT EXISTS(SELECT 1 FROM public.rue_sorties_batiments
 WHERE country='soviet' AND city='ville_b'
 AND noeud='krasnov-rue-immeubles-centre-commercial' AND building='logements-novomirsk')
 THEN RAISE EXCEPTION 'Immeuble de Krasnov mal raccordé'; END IF;
END $$;
COMMIT;
