-- APPLIQUÉE en production le 24/11/2026 (contrôlée en lecture : 1 fontaine active à Luthécia, ancienne redirigée) — mission « Purge » du 24/11/2026, bloc F (images de fontaines), point F.1 (consigne de Fred) :
-- « La fontaine de Luthécia est DÉPLACÉE du parvis de l'Hôtel de Ville vers la place du Formulaire de la Liberté.
--   C'est un lieu où l'on entre, pas une vue de rue : « Puiser de l'eau » se fait sur la place. Mets à jour la consigne
--   de canicule, redirige l'ancien emplacement et ajoute un banc. »
-- • climat_points_eau reçoit deux colonnes : `batiment` (point d'eau situé DANS un lieu où l'on entre ; NULL = vue de rue)
--   et `remplace_par` (redirection d'un point d'eau retiré vers celui qui le remplace).
-- • Nouvelle fontaine luthecia-fontaine-place-formulaire-liberte, dans le lieu place-formulaire-liberte (entrée depuis la
--   vue luthecia-stade-multimodal, seule sortie déclarée dans rue_sorties_batiments) ; image fournie par Fred.
-- • L'ancienne fontaine du parvis (luthecia-fontaine-hotel-de-ville) est désactivée et redirigée (remplace_par).
-- • point_eau_etat accepte un point d'eau de lieu (marque point_eau_batiment_v1) ; climat_points_eau_lister renvoie
--   `batiment`. La consigne de canicule lit le nom du point d'eau actif de la ville : elle cite désormais la place.
-- Rejouable (IF NOT EXISTS, ON CONFLICT, marque). Aucune fonction commune ni objet du goulag touchés.
BEGIN;

ALTER TABLE public.climat_points_eau ADD COLUMN IF NOT EXISTS batiment text;
ALTER TABLE public.climat_points_eau ADD COLUMN IF NOT EXISTS remplace_par text;

INSERT INTO public.climat_points_eau (id, pays, ville, noeud, batiment, nom, image, actif) VALUES
  ('luthecia-fontaine-place-formulaire-liberte', 'republic', 'capitale', 'luthecia-stade-multimodal', 'place-formulaire-liberte',
   'la fontaine de la place du Formulaire de la Liberté, à Luthécia', 'images/fontaines/luthecia-fontaine-place-formulaire-liberte.webp', true)
ON CONFLICT (id) DO NOTHING;

UPDATE public.climat_points_eau SET actif = false, remplace_par = 'luthecia-fontaine-place-formulaire-liberte'
 WHERE id = 'luthecia-fontaine-hotel-de-ville' AND (actif OR remplace_par IS NULL);

-- Point d'eau de rue (batiment NULL) : dans la vue, hors de tout lieu. Point d'eau de lieu : dans ce lieu.
CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer(p_fn regprocedure, p_avant text, p_apres text, p_n integer, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  n := (length(d) - length(replace(d, p_avant, ''))) / length(p_avant);
  IF n <> p_n THEN RAISE EXCEPTION '% : % occurrence(s) au lieu de % (%)', p_fn, n, p_n, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : marque absente', p_fn; END IF;
END $$;
SELECT pg_temp.rp_remplacer('public.point_eau_etat()'::regprocedure,
  $a$AND p.noeud = d.current_street AND d.current_building IS NULL ORDER BY p.id LIMIT 1;$a$,
  $b$AND ((p.batiment IS NULL AND p.noeud = d.current_street AND d.current_building IS NULL)
          OR (p.batiment IS NOT NULL AND d.current_building = p.batiment)) /* point_eau_batiment_v1 */ ORDER BY p.id LIMIT 1;$b$,
  1, 'point_eau_batiment_v1');

CREATE OR REPLACE FUNCTION public.climat_points_eau_lister()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('ok', true, 'points', coalesce(jsonb_agg(jsonb_build_object('id', id, 'pays', pays, 'ville', ville,
           'noeud', noeud, 'batiment', batiment, 'nom', nom, 'image', image) ORDER BY id), '[]'::jsonb))
    FROM public.climat_points_eau WHERE actif;
$$;
REVOKE ALL ON FUNCTION public.climat_points_eau_lister() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.climat_points_eau_lister() TO authenticated;

DO $$ BEGIN
  -- Au plus une fontaine active par ville ; chaque vue existe ; un point d'eau de lieu s'ouvre depuis sa vue ;
  -- toute redirection mène à une fontaine active de la même ville.
  IF EXISTS (SELECT pays, ville FROM public.climat_points_eau WHERE actif GROUP BY pays, ville HAVING count(*) > 1)
     OR EXISTS (SELECT 1 FROM public.climat_points_eau p WHERE p.actif AND NOT EXISTS (
          SELECT 1 FROM public.rue_noeuds_serveur n WHERE n.country = p.pays AND n.city = p.ville AND n.noeud = p.noeud))
     OR EXISTS (SELECT 1 FROM public.climat_points_eau p WHERE p.actif AND p.batiment IS NOT NULL AND NOT EXISTS (
          SELECT 1 FROM public.rue_sorties_batiments s WHERE s.country = p.pays AND s.city = p.ville AND s.noeud = p.noeud AND s.building = p.batiment))
     OR EXISTS (SELECT 1 FROM public.climat_points_eau p WHERE p.remplace_par IS NOT NULL AND NOT EXISTS (
          SELECT 1 FROM public.climat_points_eau q WHERE q.id = p.remplace_par AND q.actif AND q.pays = p.pays AND q.ville = p.ville))
     OR NOT EXISTS (SELECT 1 FROM public.climat_points_eau WHERE id = 'luthecia-fontaine-place-formulaire-liberte' AND actif) THEN
    RAISE EXCEPTION 'fontaine_luthecia_place_formulaire : contrôle en échec';
  END IF;
END $$;
COMMIT;
