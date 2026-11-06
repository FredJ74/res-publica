-- APPLIQUEE le 04/11/2026 par Claude (registre serrures_portes_lire_20261104131000), apres banc annule
-- (migration + lecture par Jean Jaaj, qui a la cle, puis par Angie, qui ne l a pas) : vert.
-- 4 novembre 2026 -- SERRURES, etape 6 : ce que l'on voit d'une porte fermee a cle (issue #434).
--
-- Decision de Fred (04/11, 14 h 07) : l'infobulle d'un local ferme a cle l'indique ; seul un PJ qui
-- possede une cle peut cliquer pour y entrer ; une fois dedans, il decide de l'ouvrir au public ou
-- non (fermer/ouvrir avec sa cle, serrure_basculer).
--
-- serrures_portes_lire(batiment) : pour le batiment ou se trouve le joueur (pays et ville de sa
-- position serveur), les pieces dont la serrure est fermee, et s'il en detient une cle. Une
-- serrure dont le bail a pris fin est d'abord detruite. Lecture seule pour le reste.

CREATE OR REPLACE FUNCTION public.serrures_portes_lire(p_batiment text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text := public.mon_personnage(); d record; s public.serrures;
BEGIN
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city INTO d FROM public.personnages_donnees WHERE name = v_moi;
  FOR s IN SELECT * FROM public.serrures WHERE statut = 'posee' AND cible = 'lieu'
             AND pays = d.country AND ville = d.current_city AND batiment = p_batiment LOOP
    PERFORM public.serrures_fin_bail_interne(s.pays, s.ville, s.batiment, s.piece);
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'batiment', p_batiment,
    'pieces', coalesce((SELECT jsonb_object_agg(x.piece, jsonb_build_object('fermee', true,
                          'a_cle', public.serrure_cle_detenue_interne(v_moi, x.id)))
                          FROM public.serrures x
                         WHERE x.statut = 'posee' AND x.cible = 'lieu' AND x.fermee
                           AND x.pays = d.country AND x.ville = d.current_city AND x.batiment = p_batiment), '{}'::jsonb));
END $$;
REVOKE ALL ON FUNCTION public.serrures_portes_lire(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.serrures_portes_lire(text) TO authenticated;
