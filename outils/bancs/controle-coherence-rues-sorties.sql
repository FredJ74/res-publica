-- Contrôle non destructif du réseau des rues et des sorties de bâtiments.
-- Résultat attendu : zéro anomalie de liaison et de sortie.
-- Liaisons à sens unique interdites ; une boucle vers soi-même est signalée.
WITH anomalies AS (
 SELECT 'voisin_inexistant' AS type,a.country,a.city,a.noeud AS source,v.dest AS cible
 FROM public.rue_noeuds_serveur a CROSS JOIN LATERAL unnest(a.voisins) v(dest)
 LEFT JOIN public.rue_noeuds_serveur b ON b.country=a.country AND b.city=a.city AND b.noeud=v.dest
 WHERE b.noeud IS NULL
 UNION ALL
 SELECT 'retour_absent',a.country,a.city,a.noeud,v.dest
 FROM public.rue_noeuds_serveur a CROSS JOIN LATERAL unnest(a.voisins) v(dest)
 JOIN public.rue_noeuds_serveur b ON b.country=a.country AND b.city=a.city AND b.noeud=v.dest
 WHERE a.noeud<>v.dest AND NOT (a.noeud=ANY(b.voisins))
 UNION ALL
 SELECT 'boucle_sur_soi',a.country,a.city,a.noeud,v.dest
 FROM public.rue_noeuds_serveur a CROSS JOIN LATERAL unnest(a.voisins) v(dest)
 WHERE a.noeud=v.dest
 UNION ALL
 SELECT 'sortie_sans_noeud',s.country,s.city,s.building,s.noeud
 FROM public.rue_sorties_batiments s
 LEFT JOIN public.rue_noeuds_serveur n ON n.country=s.country AND n.city=s.city AND n.noeud=s.noeud
 WHERE n.noeud IS NULL
 UNION ALL
 SELECT 'voisin_duplique',a.country,a.city,a.noeud,v.dest
 FROM public.rue_noeuds_serveur a CROSS JOIN LATERAL unnest(a.voisins) v(dest)
 GROUP BY a.country,a.city,a.noeud,v.dest HAVING count(*)>1
)
SELECT * FROM anomalies ORDER BY type,country,city,source,cible;
