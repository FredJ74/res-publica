-- #219 : adaptateur d'identité du moteur de confiscation existant.
-- Aucun fichier de l'inventaire modifié. Le corps métier est inchangé.
-- Toute version différente (notamment #213) exige une nouvelle comparaison.
DO $prevol$
BEGIN
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='public.inventaire_confisquer(text)'::regprocedure)
 NOT IN ('8aa5bde1ef31df82acc948172478a9d7','671b602d2c1d3322d6feef9f01657ed5') THEN RAISE EXCEPTION 'confiscation_vivante_non_examinee';END IF;
 IF to_regprocedure('public.douane_confisquer_personnage_interne(text)') IS NOT NULL
 AND (SELECT md5(prosrc) FROM pg_proc WHERE oid=to_regprocedure('public.douane_confisquer_personnage_interne(text)'))<>'296ab5d5ecd5da05a9f34e15a0f4da7b'
 THEN RAISE EXCEPTION 'confiscation_interne_non_examinee';END IF;
END $prevol$;
CREATE OR REPLACE FUNCTION public.douane_confisquer_personnage_interne(p_acteur text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_inv jsonb; v_quete jsonb; v_pays text; v_trouve boolean;
  v_saisis jsonb; v_restant jsonb;
  v_ville text; v_bat text; v_room text; v_ref text;
BEGIN
  SELECT true, coalesce(inventory, '[]'::jsonb), quete_carriere, coalesce(country, 'republic'),
         current_city, current_building, current_room
    INTO v_trouve, v_inv, v_quete, v_pays, v_ville, v_bat, v_room
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT coalesce(v_trouve, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  WITH elements AS (
    SELECT e, (coalesce((e->>'legal')::boolean, true) = false
               OR public.assemblee_loi_en_vigueur(v_pays, e, now()) IS NOT NULL)
              AND NOT public.inventaire_objet_protege(v_quete, e) AS saisi
      FROM jsonb_array_elements(v_inv) e
  )
  SELECT coalesce(jsonb_agg(e) FILTER (WHERE saisi), '[]'::jsonb),
         coalesce(jsonb_agg(e) FILTER (WHERE NOT saisi), '[]'::jsonb)
    INTO v_saisis, v_restant FROM elements;

  IF jsonb_array_length(v_saisis) = 0 THEN
    RETURN jsonb_build_object('ok', true, 'saisis', '[]'::jsonb, 'inventory', v_inv, 'noms', '');
  END IF;

  UPDATE public.personnages_donnees SET inventory = v_restant WHERE name = p_acteur;

  -- EVENEMENT MONDE, une ligne par objet reellement confisque, dans la meme
  -- transaction que le retrait.
  v_ref := 'conf-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' ||
           substr(md5(p_acteur || random()::text), 1, 8);
  INSERT INTO public.confiscations_douanieres
    (id, personne, objet_nom, objet_type, quantite, pays, ville, building_id, room_id, reference)
  SELECT v_ref || '-' || o.ord, p_acteur,
         coalesce(o.e ->> 'name', o.e ->> 'nom', '?'),
         o.e ->> 'type',
         nullif(coalesce(o.e ->> 'qty', o.e ->> 'quantite'), '')::integer,
         v_pays, v_ville, v_bat, v_room, v_ref
    FROM jsonb_array_elements(v_saisis) WITH ORDINALITY AS o(e, ord);

  RETURN jsonb_build_object('ok', true, 'saisis', v_saisis, 'inventory', v_restant,
    'noms', (SELECT string_agg(e->>'name', ', ') FROM jsonb_array_elements(v_saisis) e));
END; $function$;
REVOKE ALL ON FUNCTION public.douane_confisquer_personnage_interne(text) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.inventaire_confisquer(p_acteur text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
BEGIN
 PERFORM public.exiger_acteur(p_acteur);
 RETURN public.douane_confisquer_personnage_interne(p_acteur);
END;
$g$;
