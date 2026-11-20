-- Navigation : provenance de rue cohérente après un déplacement imposé ; peines codées en dur ramenées au barème commun
-- (bug signalé par Fred le 20/11/2026 : Tom Tom, libéré des geôles du commissariat de Krasnov, current_street_from resté
-- à krasnov-rue-ecole-foret).
--
-- POURQUOI UNE MISE À JOUR DIRECTE DE current_street_from « NE PREND PAS ». Le déclencheur BEFORE UPDATE
-- navigation_provenance_garder (fonction navigation_provenance_garder_interne) commence par
-- NEW.current_street_from := OLD.current_street_from, pour TOUT le monde (écran, fonctions serveur, SQL d'administration) :
-- la provenance n'est jamais adoptée telle qu'écrite, elle se DÉDUIT des déplacements (un pas de rue à rue la pose sur la
-- rue quittée ; un changement de pays ou de ville la vide). Ce n'est pas une colonne recalculée.
-- Correction volontaire : SET LOCAL rp.provenance_imposee = 'on' dans la même transaction, puis l'UPDATE.
--
-- CE QUI CHANGE (déduction toujours au serveur, pour TOUTE fin de détention et tout déplacement imposé, puisque tous
-- passent par ce déclencheur) :
--  • entrer dans un bâtiment SANS venir de la rue de sa porte (cellule, hôpital, téléportation) vide la provenance ;
--  • passer d'un bâtiment à un autre sans passer par la rue la vide aussi ;
--  • arriver dans une rue depuis un bâtiment ou une position imposée : si la provenance ne mène pas à cette rue (pas
--    une voisine), elle est remplacée par la première arrivée déclarée de cette rue (directions.parArrivee), sinon vidée.
--
-- PEINES : sovarka_ecoute_archives_voler (1 jour en dur) et militaire_subtiliser_tenter (3 jours en dur en Sovarka)
-- passent par crim_peine_jours_interne (barème commun, facteur ×2 de Sovarka) : archives 1 → 2 jours en Sovarka ;
-- matériel militaire en Sovarka 3 → 4 jours (2 × 2). Idempotente (marques navigation_provenance_v2, *_bareme_v1).
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN
    RAISE EXCEPTION '% : ancrage introuvable ou multiple (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

CREATE OR REPLACE FUNCTION public.navigation_provenance_garder_interne()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
 -- navigation_provenance_v2 (20/11/2026). Ce trigger vient après navigation_positions_garder : une sauvegarde refusée
 -- n'est pas un déplacement. Aucune provenance transmise par l'écran n'est adoptée.
 -- Correction volontaire (fonction serveur, administration) : SET LOCAL rp.provenance_imposee = 'on'.
 IF coalesce(current_setting('rp.provenance_imposee', true), '') = 'on' THEN RETURN NEW; END IF;
 NEW.current_street_from := OLD.current_street_from;
 IF NEW.country IS DISTINCT FROM OLD.country OR NEW.current_city IS DISTINCT FROM OLD.current_city THEN
  NEW.current_street_from := NULL;
 ELSIF NEW.current_building IS NULL AND OLD.current_building IS NULL
  AND NEW.current_street IS DISTINCT FROM OLD.current_street THEN
  NEW.current_street_from := OLD.current_street;
 ELSIF NEW.current_building IS NOT NULL AND NEW.current_building IS DISTINCT FROM OLD.current_building
  AND (OLD.current_building IS NOT NULL
       OR NOT EXISTS (SELECT 1 FROM public.rue_sorties_batiments s
                       WHERE s.country = NEW.country AND s.city = NEW.current_city
                         AND s.building = NEW.current_building AND s.noeud = OLD.current_street)) THEN
  -- Entrée qui ne vient pas de la rue de la porte (cellule, hôpital, téléportation) : plus d'orientation valable.
  NEW.current_street_from := NULL;
 END IF;
 -- Arrivée dans une rue depuis un bâtiment ou une position imposée : la provenance doit mener à cette rue.
 IF NEW.current_building IS NULL AND NEW.current_street IS NOT NULL
    AND (OLD.current_building IS NOT NULL OR OLD.current_street IS NULL
         OR NEW.country IS DISTINCT FROM OLD.country OR NEW.current_city IS DISTINCT FROM OLD.current_city)
    AND (NEW.current_street_from IS NULL OR NOT EXISTS (
          SELECT 1 FROM public.rue_noeuds_serveur r
           WHERE r.country = NEW.country AND r.city = NEW.current_city AND r.noeud = NEW.current_street
             AND NEW.current_street_from = ANY (r.voisins))) THEN
  NEW.current_street_from := (
    SELECT k FROM public.rue_noeuds_serveur r, jsonb_object_keys(coalesce(r.directions -> 'parArrivee', '{}'::jsonb)) k
     WHERE r.country = NEW.country AND r.city = NEW.current_city AND r.noeud = NEW.current_street
     ORDER BY k LIMIT 1);
 END IF;
 RETURN NEW;
END
$function$;

SELECT pg_temp.rp_raccorder('public.sovarka_ecoute_archives_voler(text)'::regprocedure,
  $a$'Surpris en train de fouiller les archives d''écoute, après une bagarre avec l''opérateur', 1)); /* vol_archives_un_jour */$a$,
  $b$'Surpris en train de fouiller les archives d''écoute, après une bagarre avec l''opérateur',
        public.crim_peine_jours_interne('voler_archives_ecoute', p.country))); /* vol_archives_bareme_v1 : barème commun, ×2 en Sovarka */$b$,
  'vol_archives_bareme_v1');
SELECT pg_temp.rp_raccorder('public.militaire_subtiliser_tenter(text)'::regprocedure,
  $a$CASE WHEN v_pj.country = 'soviet' THEN 3 ELSE public.crim_peine_jours_interne('vol_materiel_militaire', v_pj.country) END$a$,
  $b$public.crim_peine_jours_interne('vol_materiel_militaire', v_pj.country) /* crim_bareme_militaire_v1 : barème commun, ×2 en Sovarka */$b$,
  'crim_bareme_militaire_v1');

COMMIT;
