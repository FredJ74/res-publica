-- Reprise des positions historiques sans croire le cache du navigateur.
UPDATE public.personnages_donnees p
SET current_street=coalesce((
 SELECT h.room_id FROM public.historique_deplacements h
 JOIN public.rue_noeuds_serveur n ON n.country=p.country AND n.city=p.current_city AND n.noeud=h.room_id
 WHERE h.name=p.name AND h.country=p.country AND h.city=p.current_city
 AND h.building_id='rue-centrale'
 ORDER BY h.created_at DESC LIMIT 1
),CASE p.current_city WHEN 'capitale' THEN 'luthecia-palais-presidentiel'
 WHEN 'ville_a' THEN 'psm-centre-multimodal' WHEN 'ville_b' THEN 'montrouge-vue-3' END)
WHERE p.country='republic' AND p.current_building IS NULL AND p.current_street IS NULL
AND p.current_city IN ('capitale','ville_a','ville_b');
