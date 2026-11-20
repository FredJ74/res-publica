-- LOT DE KRASNOV (1re partie), point 6 (Fred, 20/11/2026) : en Sovarka, le club des supporters ne boycotte plus ; il ne
-- manifeste qu'« en faveur » d'une cible choisie par son président — le président du club de football ou le maire de
-- la ville — avec exactement le mécanisme de la manifestation de soutien du Syndicat national
-- (syndicat_etat_manifester_interne) :
--   • ordre du président des supporters, au siège des supporters du stade de sa ville, 10 membres au moins, une
--     manifestation par jour et par ville ;
--   • chaque membre présent dans la ville défile et paie 2 PA (pas à 3 PA ou moins) ;
--   • taux = présents / domiciliés ; effet sur la popularité de la cible = syndicat_etat_effet_pop(taux), y compris la
--     perte de POP sous 50 % ; aucun effet si la cible n'est pas un joueur ou si le poste est vacant ;
--   • bandeau et article du journal.
-- Idempotente.
BEGIN;

CREATE TABLE IF NOT EXISTS public.supporters_manifestations_sovarka (
  ville text NOT NULL, jour integer NOT NULL, chef text NOT NULL, cible_type text NOT NULL, cible text,
  presents integer NOT NULL, domicilies integer NOT NULL, taux integer NOT NULL, effet_pop integer NOT NULL,
  participants jsonb NOT NULL DEFAULT '[]'::jsonb, cree_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (ville, jour));
ALTER TABLE public.supporters_manifestations_sovarka ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.supporters_manifestations_sovarka FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.supporters_sovarka_manifester_interne(p_chef text, p_cible text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_ville text; v_orga_id text; d jsonb; v_noms text[]; v_participants text[]; v_jour integer; v_club record;
  v_dom integer; v_pres integer; v_taux integer; v_effet integer; v_cible text; v_pj boolean; v_nom_ville text;
  v_qui text; v_txt text; v_corps text;
BEGIN
  IF p_cible NOT IN ('president_club', 'maire') THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  SELECT current_city INTO v_ville FROM public.personnages_donnees
   WHERE name = p_chef AND country = 'soviet' AND current_building = 'stade' AND current_room = 'siege_supporters'
     AND current_city IN ('capitale', 'ville_a', 'ville_b');
  IF v_ville IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_au_siege_supporters'); END IF;
  SELECT o.id, o.data::jsonb INTO v_orga_id, d FROM public.organisations o
   WHERE o.data IS JSON OBJECT AND o.data::jsonb->>'type' = 'supporters' AND o.data::jsonb->>'country' = 'soviet'
     AND o.data::jsonb->>'city' = v_ville ORDER BY o.created_at LIMIT 1 FOR UPDATE;
  IF d IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'club_supporters_absent'); END IF;
  IF d->>'chef' IS DISTINCT FROM p_chef THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_president'); END IF;
  SELECT coalesce(array_agg(DISTINCT coalesce(m->>'nom', m #>> '{}')), '{}') INTO v_noms
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(d->'membres') = 'array' THEN d->'membres' ELSE '[]'::jsonb END) m;
  IF coalesce(array_length(v_noms, 1), 0) < 10 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'club_trop_petit', 'minimum', 10, 'membres', coalesce(array_length(v_noms, 1), 0));
  END IF;
  v_jour := coalesce(public.jour_de_jeu_pays('soviet'), 1);
  IF EXISTS (SELECT 1 FROM public.supporters_manifestations_sovarka WHERE ville = v_ville AND jour = v_jour) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_manifeste_aujourdhui');
  END IF;
  SELECT id, nom INTO v_club FROM public.clubs_football WHERE pays = 'soviet' AND ville = v_ville LIMIT 1;
  v_cible := CASE p_cible
    WHEN 'president_club' THEN (SELECT nullif(data->>'president', '') FROM public.presidents_clubs WHERE id = v_club.id)
    ELSE (SELECT nullif(data::jsonb->>'eluId', '') FROM public.cycles_electoraux WHERE id = 'soviet_maire_' || v_ville) END;
  WITH p AS (
    UPDATE public.personnages_donnees x SET pa = pa - 2, updated_at = now()
     WHERE x.name = ANY (v_noms) AND x.country = 'soviet' AND x.current_city = v_ville AND coalesce(x.pa, 0) > 3
    RETURNING x.name)
  SELECT coalesce(array_agg(name ORDER BY name), '{}') INTO v_participants FROM p;
  v_pres := coalesce(array_length(v_participants, 1), 0);
  SELECT count(*) INTO v_dom FROM public.personnages_donnees x
   WHERE x.name = ANY (v_noms) AND x.domicile->>'country' = 'soviet' AND x.domicile->>'city' = v_ville;
  v_taux := floor(v_pres * 100.0 / greatest(v_dom, 1))::integer;
  v_effet := public.syndicat_etat_effet_pop(v_taux);
  v_pj := v_cible IS NOT NULL AND EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_cible);
  IF v_pj AND v_effet <> 0 THEN PERFORM public.jauges_effet_appliquer_interne(v_cible, v_effet, 0, 0); END IF;
  v_nom_ville := CASE v_ville WHEN 'capitale' THEN 'Novomirsk' WHEN 'ville_a' THEN 'Starovka' ELSE 'Krasnov' END;
  v_qui := CASE p_cible WHEN 'maire' THEN 'du maire' ELSE 'du président du club' END
        || CASE WHEN v_cible IS NOT NULL THEN ' ' || replace(v_cible, ' (PNJ)', '') ELSE '' END;
  v_txt := 'Les supporters ' || coalesce('du club ' || v_club.nom, 'de ' || v_nom_ville) || ' défilent en faveur ' || v_qui || ' : ' || v_pres
        || ' supporter(s) dans le cortège pour ' || v_dom || ' domicilié(s), participation ' || v_taux || ' %. '
        || CASE WHEN v_cible IS NULL THEN 'Poste vacant : aucun effet.'
                WHEN NOT v_pj THEN 'Cible non joueuse : aucun effet.'
                WHEN v_effet > 0 THEN 'Popularité : +' || v_effet || '.'
                WHEN v_effet < 0 THEN 'Désaveu : popularité ' || v_effet || '.'
                ELSE 'Aucun effet sur la popularité.' END;
  INSERT INTO public.evenements_globaux (country, city, texte, jour) VALUES ('soviet', v_ville, '🚩 ' || v_txt, v_jour);
  v_corps := 'Sous la conduite de ' || replace(p_chef, ' (PNJ)', '') || ', président du club des supporters, ' || v_txt;
  INSERT INTO public.journal_articles_en_attente (id, country, rubrique, titre, texte, ville, statut, origine, priorite, dedup_key, expire_le, fait_json)
  VALUES ('manif-supporters-' || v_ville || '-' || v_jour, 'soviet', 'sport', 'Les supporters défilent à ' || v_nom_ville, v_corps, v_ville,
          'attente', 'supporters', 'normale', 'manif-supporters-' || v_ville || '-' || v_jour, now() + interval '2 days',
          jsonb_build_object('presents', v_pres, 'domicilies', v_dom, 'taux', v_taux, 'effet_pop', v_effet, 'cible', v_cible, 'cible_type', p_cible))
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.supporters_manifestations_sovarka (ville, jour, chef, cible_type, cible, presents, domicilies, taux, effet_pop, participants)
  VALUES (v_ville, v_jour, p_chef, p_cible, v_cible, v_pres, v_dom, v_taux, CASE WHEN v_pj THEN v_effet ELSE 0 END, to_jsonb(v_participants));
  RETURN jsonb_build_object('ok', true, 'ville', v_ville, 'jour', v_jour, 'cible_type', p_cible, 'cible', v_cible, 'cible_pj', v_pj,
    'presents', v_pres, 'domicilies', v_dom, 'taux', v_taux, 'effet_pop', CASE WHEN v_pj THEN v_effet ELSE 0 END,
    'membres', array_length(v_noms, 1), 'participe', p_chef = ANY (v_participants))
    || (SELECT jsonb_build_object('pa', pa) FROM public.personnages_donnees WHERE name = p_chef);
END $$;
REVOKE ALL ON FUNCTION public.supporters_sovarka_manifester_interne(text, text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.supporters_sovarka_manifester(p_requete uuid, p_cible text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('cible', p_cible); v jsonb; d text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'supporters_sovarka_manifester', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.supporters_sovarka_manifester_interne(a, p_cible);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'refus' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'supporters_sovarka_manifester', prm, v);
END $$;
REVOKE ALL ON FUNCTION public.supporters_sovarka_manifester(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.supporters_sovarka_manifester(uuid, text) TO authenticated;

COMMIT;
