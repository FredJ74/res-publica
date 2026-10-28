-- Audit Luthécia : lecture seule, aucun personnage affiché ou modifié.
BEGIN;
SET TRANSACTION READ ONLY;
-- Références serveur sorties de bâtiments : aucun noeud orphelin.
SELECT s.city, count(*) AS sorties, count(*) FILTER (WHERE n.noeud IS NULL) AS orphelines
FROM public.rue_sorties_batiments s
LEFT JOIN public.rue_noeuds_serveur n
 ON n.country=s.country AND n.city=s.city AND n.noeud=s.noeud
WHERE s.country='republic'
GROUP BY s.city ORDER BY s.city;
-- Fonctions attendues pour sortie et récupération après réponse réseau incertaine.
SELECT proname, pg_get_function_identity_arguments(oid) AS args
FROM pg_proc WHERE pronamespace='public'::regnamespace
AND proname IN ('rue_sortie_batiment_lire','rue_position_enregistrer','rue_position_lire')
ORDER BY proname;
-- Sanité financière agrégée ; rien ne permet d'affirmer à partir de ces
-- comptes que chaque crédit de prêt a été réellement versé.
SELECT 'prets' AS source,count(*) AS n,
 count(*) FILTER(WHERE montant_initial<0 OR montant_restant<0) AS valeurs_negatives
 FROM public.prets
UNION ALL SELECT 'prets_bancaires',count(*),
 count(*) FILTER(WHERE montant_initial<0 OR montant_restant<0)
 FROM public.prets_bancaires
UNION ALL SELECT 'placements_bancaires',count(*),
 count(*) FILTER(WHERE montant<0) FROM public.placements_bancaires;
ROLLBACK;
