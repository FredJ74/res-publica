-- NON APPLIQUÉE — l'agent principal l'applique à la fusion (mission « Purge », 24/11/2026).
-- Point H.3 (Fred, 24/11/2026) : au musée de Krasnov, Arkadi Pamiatnikov répond aux questions libres, 1 PA pour
-- 3 questions, par salle et par jour, comme à Novomirsk (Ouliana au musée national, Ilia au musée municipal).
-- Même compteur serveur (guide_musee_dialogues, guide_musee_dialogue_lire / _ouvrir / question_consommer, tarif
-- questionner_guide_musee 1 PA déjà dans ordres_couts) : on ajoute seulement les six pièces du musée de Krasnov
-- (bâtiment du gabarit « musee-novomirsk » dans la ville ville_b), sous le préfixe « krasnov: » pour qu'aucun compte ne
-- se mélange avec le musée municipal de Novomirsk (préfixe « novomirsk: ») ni avec le musée national (sans préfixe).
-- /api/chat n'accepte une question d'Arkadi que si la salle lue commence par « krasnov: ». Rejouable ; rien du goulag.
BEGIN;
CREATE OR REPLACE FUNCTION public.guide_musee_salle_interne(p_nom text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN d.current_city = 'ville_b' THEN 'krasnov:' || d.current_room   /* ghe_h3_arkadi_v1 */
              WHEN d.current_building = 'musee-novomirsk' THEN 'novomirsk:' || d.current_room
              ELSE d.current_room END
    FROM public.personnages_donnees d
   WHERE d.name = p_nom AND d.country = 'soviet'
     AND (
       (d.current_city = 'capitale' AND d.current_building = 'musee-national-republia'
         AND d.current_room IN ('hall', 'salle_presidents', 'salle_politiques', 'salle_honneur_militaire_nationale',
         'salle_organisations', 'salle_artistes_sportifs', 'salle_civils_intellectuels',
         'salle_grandes_villes', 'expositions_temporaires'))
       OR
       (d.current_city = 'capitale' AND d.current_building = 'musee-novomirsk'
         AND d.current_room IN ('hall', 'salle_origines', 'salle_personnalites_discretes',
         'salle_bataille_fleuve', 'salle_grand_incendie'))
       OR
       (d.current_city = 'ville_b' AND d.current_building = 'musee-novomirsk'
         AND d.current_room IN ('hall', 'faune_sauvage', 'flore_sauvage', 'exploitation_bois', 'kolkhozes', 'ecoute_spatiale'))
     );
$$;
REVOKE ALL ON FUNCTION public.guide_musee_salle_interne(text) FROM PUBLIC, anon, authenticated;

DO $$ BEGIN
  IF position('ghe_h3_arkadi_v1' IN pg_get_functiondef('public.guide_musee_salle_interne(text)'::regprocedure)) = 0
     OR NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'questionner_guide_musee' AND pa = 1 AND cost = 0) THEN
    RAISE EXCEPTION 'ghe_h3_arkadi_questions_musee_krasnov : contrôle structurel en échec';
  END IF;
END $$;
COMMIT;
