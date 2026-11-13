-- Direction du renseignement de Novomirsk : archives de sa salle d'écoutes.
-- Reutilise le registre et le vol de rapports existants de Krasnov/Starovka.
-- Aucune modification des probabilites, peines, courriers ou données des rapports.
CREATE OR REPLACE FUNCTION public.sovarka_ecoute_centre_interne(p_ville text,p_batiment text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
 SELECT CASE
   WHEN p_ville='capitale' AND p_batiment='siege-renseignement' THEN 'novomirsk'
   WHEN p_ville='ville_a' AND p_batiment='poste-vigilance-glaciale' THEN 'starovka'
   WHEN p_ville='ville_b' AND p_batiment='station-radar-krasnov' THEN 'krasnov'
 END;
$$;

-- Interdire l'utilisation du vol de Novomirsk depuis le hall ou l'interrogatoire.
-- Le code métier de l'acte illégal est conservé intégralement.
DO $migration$
DECLARE
  code text;
  ancien text := 'SELECT country, current_city, current_building, resources, stats INTO p FROM public.personnages_donnees WHERE name = a FOR UPDATE;';
  nouveau text := 'SELECT country, current_city, current_building, current_room, resources, stats INTO p FROM public.personnages_donnees WHERE name = a FOR UPDATE;';
  garde_avant text := 'IF c IS NULL THEN RETURN jsonb_build_object(''ok'', false, ''raison'', ''pas_sur_place''); END IF;';
  garde_apres text := garde_avant || E'\n  IF c = ''novomirsk'' AND p.current_room IS DISTINCT FROM ''salle_ecoutes'' THEN\n    RETURN jsonb_build_object(''ok'', false, ''raison'', ''pas_sur_place''); END IF;';
BEGIN
  SELECT pg_get_functiondef('public.sovarka_ecoute_archives_voler(text)'::regprocedure) INTO code;
  IF position(nouveau IN code)>0 AND position('p.current_room IS DISTINCT FROM ''salle_ecoutes''' IN code)>0 THEN RETURN; END IF;
  IF position(ancien IN code)=0 OR position(garde_avant IN code)=0 THEN
    RAISE EXCEPTION 'Definition de vol archives modifiee : revue manuelle necessaire';
  END IF;
  code:=replace(code,ancien,nouveau);
  code:=replace(code,garde_avant,garde_apres);
  EXECUTE code;
END $migration$;
