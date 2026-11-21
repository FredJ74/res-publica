-- GROUPES, MASQUE DE CARNAVAL, CACHETTE COLLECTIVE (Fred, 21/11/2026, mission du soir, points 7 et 8).
-- • presents_ici() : les présents de MA vue, dans un bâtiment comme dans la rue (la rue lisait jusqu'ici la table
--   presences, dont la RLS retire les masqués : Tom Tom disparaissait de la liste d'Arnie en se masquant).
--   Être masqué n'est pas être caché : un masqué reste listé, nom « Personnage masqué », sans nom réel ni lien vers sa
--   fiche (jeton seulement). Chaque ligne porte la clé opaque de son groupe et le libellé du groupe : « Groupe <chef> »,
--   ou « Groupe d'un personnage masqué » pour qui n'en fait pas partie quand le chef est masqué.
-- • Cachette collective : quand le chef se cache, un seul jet sur sa dissimulation, malus de 5 points par membre en plus
--   du chef (plafond 98 % et 2 % d'échec critique inchangés, tenue de ninja du chef comme aujourd'hui) ; réussite = tout le
--   groupe caché (membres présents dans la même pièce) ; qui rejoint un groupe caché est caché sans jet ; le chef sort de
--   sa cachette ou est découvert = tout le groupe redevient visible.
-- • Mise à jour en direct : toute adhésion ou départ de groupe signale la salle (salles_signaux) ; la cachette et le masque
--   la signalaient déjà (caches_pj, inventaire).
-- Fonction commune modifiée par simple appel ajouté : se_cacher (une ligne : malus de groupe). Le reste passe par des
-- déclencheurs nouveaux. Aucun objet du goulag touché.
BEGIN;

INSERT INTO public.crim_parametres (cle, valeur) VALUES ('cacher_malus_par_membre', 5) ON CONFLICT (cle) DO NOTHING;

-- Chef d'un personnage : lui-même s'il mène un groupe, son chef s'il est membre, NULL sinon.
CREATE OR REPLACE FUNCTION public.groupe_chef_de_interne(p_nom text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce((SELECT a.chef FROM public.groupes_pj_adhesions a WHERE a.membre = p_nom LIMIT 1),
                  (SELECT p_nom WHERE EXISTS (SELECT 1 FROM public.groupes_pj_adhesions a WHERE a.chef = p_nom)));
$$;

-- Membres (hors chef) présents dans la même pièce que le chef.
CREATE OR REPLACE FUNCTION public.groupe_membres_avec_chef_interne(p_chef text)
RETURNS SETOF text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT m.name FROM public.groupes_pj_adhesions a
    JOIN public.personnages_donnees m ON m.name = a.membre
    JOIN public.personnages_donnees c ON c.name = a.chef
   WHERE a.chef = p_chef AND m.country IS NOT DISTINCT FROM c.country AND m.current_city IS NOT DISTINCT FROM c.current_city
     AND m.current_building IS NOT DISTINCT FROM c.current_building AND m.current_room IS NOT DISTINCT FROM c.current_room
     AND m.current_street IS NOT DISTINCT FROM c.current_street;
$$;

-- Taux du chef, moins 5 points par membre présent (plancher 0 ; le plafond de 98 % est déjà appliqué au taux reçu).
CREATE OR REPLACE FUNCTION public.groupe_cacher_taux_interne(p_nom text, p_taux integer)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN EXISTS (SELECT 1 FROM public.groupes_pj_adhesions WHERE chef = p_nom)
    THEN greatest(0, p_taux - public.crim_param_interne('cacher_malus_par_membre', 5)::integer
                      * (SELECT count(*)::integer FROM public.groupe_membres_avec_chef_interne(p_nom)))
    ELSE p_taux END;
$$;

-- Chances annoncées AVANT le jet (message pédagogique) : aucune écriture, aucun PA.
CREATE OR REPLACE FUNCTION public.se_cacher_chances()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); v_ninja boolean; v_base integer; v_n integer := 0; v_chef text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_chef := public.groupe_chef_de_interne(a);
  v_ninja := public.crim_objet_porte_interne(a, 'tenue_ninja');
  v_base := public.crim_cacher_taux_interne(public.crim_stat_interne(a, 'dis', 50), v_ninja);
  IF v_chef = a THEN SELECT count(*)::integer INTO v_n FROM public.groupe_membres_avec_chef_interne(a); END IF;
  RETURN jsonb_build_object('ok', true, 'chef', coalesce(v_chef = a, false), 'membre', coalesce(v_chef <> a, false),
    'membres', v_n, 'base', v_base, 'malus_par_membre', public.crim_param_interne('cacher_malus_par_membre', 5)::integer,
    'taux', public.groupe_cacher_taux_interne(a, v_base), 'ninja', v_ninja,
    'critique', public.crim_param_interne('cacher_critique_points', 2)::integer, 'cout_pa', 1);
END $$;

-- Cachette du chef → tout le groupe présent ; sortie ou découverte du chef → tout le groupe visible.
CREATE OR REPLACE FUNCTION public.groupe_cachette_suivre_trg()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF pg_trigger_depth() > 1 THEN RETURN coalesce(NEW, OLD); END IF;
  IF TG_OP = 'INSERT' AND EXISTS (SELECT 1 FROM public.groupes_pj_adhesions WHERE chef = NEW.personnage) THEN
    INSERT INTO public.caches_pj (personnage, pays, ville, batiment, piece, le)
    SELECT m, NEW.pays, NEW.ville, NEW.batiment, NEW.piece, now() FROM public.groupe_membres_avec_chef_interne(NEW.personnage) m
    ON CONFLICT (personnage) DO UPDATE SET pays = EXCLUDED.pays, ville = EXCLUDED.ville, batiment = EXCLUDED.batiment,
      piece = EXCLUDED.piece, le = now();
  ELSIF TG_OP = 'DELETE' AND EXISTS (SELECT 1 FROM public.groupes_pj_adhesions WHERE chef = OLD.personnage) THEN
    DELETE FROM public.caches_pj WHERE personnage IN (SELECT membre FROM public.groupes_pj_adhesions WHERE chef = OLD.personnage);
  END IF;
  RETURN coalesce(NEW, OLD);
END $$;
DROP TRIGGER IF EXISTS zz_groupe_cachette_suivre ON public.caches_pj;
CREATE TRIGGER zz_groupe_cachette_suivre AFTER INSERT OR DELETE ON public.caches_pj
  FOR EACH ROW EXECUTE FUNCTION public.groupe_cachette_suivre_trg();

-- Adhésion : caché sans jet si le chef est caché dans la même pièce ; départ : la cachette de groupe ne le suit plus.
-- Dans les deux cas, la salle est signalée : tous les présents voient le changement sans recharger.
CREATE OR REPLACE FUNCTION public.groupe_adhesion_signaux_trg()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE d record; k public.caches_pj;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT * INTO k FROM public.caches_pj WHERE personnage = NEW.chef;
    IF k.personnage IS NOT NULL AND NEW.membre IN (SELECT public.groupe_membres_avec_chef_interne(NEW.chef)) THEN
      INSERT INTO public.caches_pj (personnage, pays, ville, batiment, piece, le)
      VALUES (NEW.membre, k.pays, k.ville, k.batiment, k.piece, now())
      ON CONFLICT (personnage) DO UPDATE SET pays = EXCLUDED.pays, ville = EXCLUDED.ville, batiment = EXCLUDED.batiment,
        piece = EXCLUDED.piece, le = now();
    END IF;
  END IF;
  FOR d IN SELECT country, current_city, current_building, current_room, current_street FROM public.personnages_donnees
            WHERE name IN (coalesce(NEW.membre, OLD.membre), coalesce(NEW.chef, OLD.chef)) LOOP
    PERFORM public.salle_signaler_interne(public.salle_cle_interne(d.country, d.current_city, d.current_building, d.current_room, d.current_street));
  END LOOP;
  RETURN coalesce(NEW, OLD);
END $$;
DROP TRIGGER IF EXISTS zz_groupe_adhesion_signaux ON public.groupes_pj_adhesions;
CREATE TRIGGER zz_groupe_adhesion_signaux AFTER INSERT OR DELETE OR UPDATE ON public.groupes_pj_adhesions
  FOR EACH ROW EXECUTE FUNCTION public.groupe_adhesion_signaux_trg();

-- Présents de ma vue (bâtiment ou rue). Le masqué reste visible ; le caché n'est vu que de son propre groupe.
CREATE OR REPLACE FUNCTION public.presents_ici()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); d record; v_rue boolean; v_mon_chef text; v jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room, current_street INTO d FROM public.personnages_donnees WHERE name = a;
  v_rue := coalesce(d.current_building, '') = '';
  IF v_rue AND coalesce(d.current_street, '') = '' THEN RETURN jsonb_build_object('ok', true, 'presents', '[]'::jsonb); END IF;
  v_mon_chef := public.groupe_chef_de_interne(a);
  WITH q AS (
    SELECT x.name, p.updated_at, p.groupe_pnj,
           coalesce(p.updated_at > now() - interval '5 minutes', false) AS connecte,
           public.crim_masque_interne(x.name) AS masque,
           public.crim_cache_interne(x.name) AS cache,
           public.groupe_chef_de_interne(x.name) AS chef
      FROM public.personnages_donnees x
      LEFT JOIN public.presences p ON p.name = x.name
     WHERE x.name <> a AND x.country = d.country AND x.current_city = d.current_city
       AND CASE WHEN v_rue THEN coalesce(x.current_building, '') = '' AND x.current_street = d.current_street
                ELSE x.current_building = d.current_building AND x.current_room = d.current_room END
  ), vis AS (
    SELECT q.*, coalesce(q.chef = v_mon_chef, false) AS mon_groupe FROM q   -- jamais NULL : un masqué hors de mon groupe reste anonyme
     WHERE NOT q.cache OR coalesce(q.chef = v_mon_chef, false)
  )
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'name', CASE WHEN masque AND NOT mon_groupe THEN 'Personnage masqué' ELSE name END,
           'masque', masque,
           'jeton', CASE WHEN masque AND NOT mon_groupe THEN (SELECT j.jeton FROM public.crim_jetons_masque j WHERE j.personnage = vis.name) END,
           'connecte', connecte, 'updated_at', updated_at,
           'groupe_pnj', CASE WHEN masque AND NOT mon_groupe
                              THEN (SELECT coalesce(jsonb_agg(g - 'photoUrl'), '[]'::jsonb)
                                      FROM jsonb_array_elements(CASE WHEN jsonb_typeof(groupe_pnj) = 'array' THEN groupe_pnj ELSE '[]'::jsonb END) g)
                              ELSE groupe_pnj END,
           'groupe', CASE WHEN chef IS NOT NULL THEN md5('groupe:' || chef || ':' || coalesce(d.current_city, '')) END,
           'est_chef', chef IS NOT NULL AND chef = name,
           'mon_groupe', mon_groupe,
           'groupe_libelle', CASE WHEN chef IS NULL THEN NULL
                                  WHEN mon_groupe OR NOT public.crim_masque_interne(chef) THEN 'Groupe ' || chef
                                  ELSE 'Groupe d''un personnage masqué' END,
           'cache', cache)
         ORDER BY name), '[]'::jsonb) INTO v FROM vis;
  RETURN jsonb_build_object('ok', true, 'presents', v,
    'moi', jsonb_build_object('masque', public.crim_masque_interne(a), 'cache', public.crim_cache_interne(a),
      'chef', v_mon_chef, 'est_chef', coalesce(v_mon_chef = a, false),
      'groupe', CASE WHEN v_mon_chef IS NOT NULL THEN md5('groupe:' || v_mon_chef || ':' || coalesce(d.current_city, '')) END,
      'groupe_libelle', CASE WHEN v_mon_chef IS NOT NULL THEN 'Groupe ' || v_mon_chef END),
    'salle', public.salle_cle_interne(d.country, d.current_city, d.current_building, d.current_room, d.current_street));
END $$;

-- se_cacher : une ligne ajoutée, le malus de groupe sur le taux du chef.
CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN RAISE EXCEPTION '% : ancrage (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;
SELECT pg_temp.rp_raccorder('public.se_cacher()'::regprocedure,
  $a$v_taux := public.crim_cacher_taux_interne(public.crim_stat_interne(v_moi, 'dis', 50), v_ninja);$a$,
  $b$v_taux := public.crim_cacher_taux_interne(public.crim_stat_interne(v_moi, 'dis', 50), v_ninja);
  v_taux := public.groupe_cacher_taux_interne(v_moi, v_taux); -- groupe_cachette_v1$b$,
  'groupe_cachette_v1');

REVOKE ALL ON FUNCTION public.groupe_chef_de_interne(text), public.groupe_membres_avec_chef_interne(text),
  public.groupe_cacher_taux_interne(text, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.presents_ici(), public.se_cacher_chances() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.presents_ici(), public.se_cacher_chances() TO authenticated;

COMMIT;
