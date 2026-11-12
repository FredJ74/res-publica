-- Etendre le compteur existant des questions de musée à Ilia Krioukov (musée municipal).
-- Le musée national conserve exactement ses clés de salles et sa limite 1 PA / 3 questions.
-- Le préfixe novomirsk: empêche une collision entre les deux musées.
-- Aucune fonction du trésor des Tsars, de la fouille ou de l'inventaire n'est modifiée.
CREATE OR REPLACE FUNCTION public.guide_musee_salle_interne(p_nom text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN d.current_building = 'musee-novomirsk'
              THEN 'novomirsk:' || d.current_room ELSE d.current_room END
    FROM public.personnages_donnees d
   WHERE d.name = p_nom AND d.country = 'soviet' AND d.current_city = 'capitale'
     AND (
       (d.current_building = 'musee-national-republia'
         AND d.current_room IN ('hall', 'salle_presidents', 'salle_politiques', 'salle_honneur_militaire_nationale',
         'salle_organisations', 'salle_artistes_sportifs', 'salle_civils_intellectuels',
         'salle_grandes_villes', 'expositions_temporaires'))
       OR
       (d.current_building = 'musee-novomirsk'
         AND d.current_room IN ('hall', 'salle_origines', 'salle_personnalites_discretes',
         'salle_bataille_fleuve', 'salle_grand_incendie'))
     );
$$;
REVOKE ALL ON FUNCTION public.guide_musee_salle_interne(text) FROM PUBLIC, anon, authenticated;
