-- PRÉSENCE PERMANENTE ET SYNCHRONISATION IMMÉDIATE (décisions de Fred du 20/11/2026).
--  • Un personnage est présent là où le SERVEUR l'a placé, que son joueur soit connecté ou non. La liste des présents
--    (crim_presents) et la numérotation des masqués (crim_masques_piece_interne) découlent désormais de
--    personnages_donnees, plus du battement de 30 s du navigateur (table presences, qui s'arrêtait onglet masqué).
--    Règles de discrétion inchangées : visage découvert = nom ; masqué = « Individu masqué n°X » sans nom ni portrait ;
--    caché = absent. Le battement ne sert plus qu'à l'indicateur « connecté » (connecte), qui ne retire personne.
--  • presences garde la position CANONIQUE : un déclencheur la recopie depuis personnages_donnees à chaque déplacement
--    (et une écriture de l'écran ne peut plus y poser un autre lieu) ; les autres lecteurs (signalement à la police,
--    statuts judiciaires de la pièce) lisent donc le vrai lieu.
--  • Signaux temps réel, sans aucun nom : salles_signaux (une ligne par pièce ou rue, version incrémentée à chaque
--    entrée, sortie, masque, cachette) et personnages_signaux (une ligne par personnage, lisible par lui seul :
--    position, détention, QHS, hospitalisation, PA, santé). Publiés dans supabase_realtime ; l'écran s'y abonne
--    (plateau-temps-reel.js) et relit au serveur. Couvre TOUS les déplacements imposés, puisqu'ils écrivent tous
--    personnages_donnees : neutralisation, hospitalisation, arrestation, garde à vue, libération, évasion, QHS, goulag,
--    expulsion, MJ.
-- Idempotente.
BEGIN;

CREATE OR REPLACE FUNCTION public.salle_cle_interne(p_pays text, p_ville text, p_batiment text, p_piece text, p_rue text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT coalesce(p_pays, '') || '|' || coalesce(p_ville, '') || '|'
      || CASE WHEN coalesce(p_batiment, '') <> '' THEN p_batiment || '|' || coalesce(p_piece, '') ELSE 'rue|' || coalesce(p_rue, '') END;
$$;

CREATE TABLE IF NOT EXISTS public.salles_signaux (
  salle text PRIMARY KEY, version bigint NOT NULL DEFAULT 1, maj timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.personnages_signaux (
  personnage text PRIMARY KEY, version bigint NOT NULL DEFAULT 1, maj timestamptz NOT NULL DEFAULT now());
ALTER TABLE public.salles_signaux ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personnages_signaux ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.salles_signaux, public.personnages_signaux FROM anon, authenticated;
GRANT SELECT ON public.salles_signaux, public.personnages_signaux TO authenticated;
DROP POLICY IF EXISTS salles_signaux_lecture ON public.salles_signaux;
CREATE POLICY salles_signaux_lecture ON public.salles_signaux FOR SELECT TO authenticated USING (true);   -- aucun nom
DROP POLICY IF EXISTS personnages_signaux_soi ON public.personnages_signaux;
CREATE POLICY personnages_signaux_soi ON public.personnages_signaux FOR SELECT TO authenticated
  USING (personnage = public.mon_personnage());

CREATE OR REPLACE FUNCTION public.salle_signaler_interne(p_salle text)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  INSERT INTO public.salles_signaux (salle) VALUES (p_salle)
  ON CONFLICT (salle) DO UPDATE SET version = public.salles_signaux.version + 1, maj = now();
$$;
CREATE OR REPLACE FUNCTION public.personnage_signaler_interne(p_nom text)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  INSERT INTO public.personnages_signaux (personnage) VALUES (p_nom)
  ON CONFLICT (personnage) DO UPDATE SET version = public.personnages_signaux.version + 1, maj = now();
$$;
REVOKE ALL ON FUNCTION public.salle_signaler_interne(text), public.personnage_signaler_interne(text) FROM PUBLIC, anon, authenticated;

-- Déclencheur commun : signaux + position canonique dans presences.
CREATE OR REPLACE FUNCTION public.personnages_signaux_trg()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_pos boolean; v_etat boolean;
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public.salle_signaler_interne(public.salle_cle_interne(OLD.country, OLD.current_city, OLD.current_building, OLD.current_room, OLD.current_street));
    RETURN OLD;
  END IF;
  v_pos := TG_OP = 'INSERT' OR NEW.country IS DISTINCT FROM OLD.country OR NEW.current_city IS DISTINCT FROM OLD.current_city
        OR NEW.current_building IS DISTINCT FROM OLD.current_building OR NEW.current_room IS DISTINCT FROM OLD.current_room
        OR NEW.current_street IS DISTINCT FROM OLD.current_street;
  v_etat := v_pos OR NEW.est_emprisonne IS DISTINCT FROM OLD.est_emprisonne OR NEW.detention_qhs IS DISTINCT FROM OLD.detention_qhs
        OR NEW.hospitalisation IS DISTINCT FROM OLD.hospitalisation OR NEW.pa IS DISTINCT FROM OLD.pa OR NEW.hp IS DISTINCT FROM OLD.hp;
  IF v_pos THEN
    IF TG_OP = 'UPDATE' THEN
      PERFORM public.salle_signaler_interne(public.salle_cle_interne(OLD.country, OLD.current_city, OLD.current_building, OLD.current_room, OLD.current_street));
    END IF;
    PERFORM public.salle_signaler_interne(public.salle_cle_interne(NEW.country, NEW.current_city, NEW.current_building, NEW.current_room, NEW.current_street));
    INSERT INTO public.presences (name, country, city, building_id, room_id, updated_at)
    VALUES (NEW.name, NEW.country, NEW.current_city, coalesce(NEW.current_building, 'rue-centrale'),
            CASE WHEN NEW.current_building IS NULL THEN NEW.current_street ELSE NEW.current_room END, NULL)
    ON CONFLICT (name) DO UPDATE SET country = excluded.country, city = excluded.city,
      building_id = excluded.building_id, room_id = excluded.room_id;
  ELSIF TG_OP = 'UPDATE' AND NEW.inventory IS DISTINCT FROM OLD.inventory THEN
    -- Un masque revêtu ou retiré change ce que voient les présents.
    PERFORM public.salle_signaler_interne(public.salle_cle_interne(NEW.country, NEW.current_city, NEW.current_building, NEW.current_room, NEW.current_street));
  END IF;
  IF v_etat THEN PERFORM public.personnage_signaler_interne(NEW.name); END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.personnages_signaux_trg() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS zz_personnages_signaux ON public.personnages_donnees;
CREATE TRIGGER zz_personnages_signaux AFTER INSERT OR UPDATE OR DELETE ON public.personnages_donnees
  FOR EACH ROW EXECUTE FUNCTION public.personnages_signaux_trg();

-- Une cachette prise ou perdue change ce que voient les présents.
CREATE OR REPLACE FUNCTION public.caches_signaux_trg()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE d record;
BEGIN
  SELECT country, current_city, current_building, current_room, current_street INTO d
    FROM public.personnages_donnees WHERE name = coalesce(NEW.personnage, OLD.personnage);
  IF FOUND THEN
    PERFORM public.salle_signaler_interne(public.salle_cle_interne(d.country, d.current_city, d.current_building, d.current_room, d.current_street));
  END IF;
  RETURN coalesce(NEW, OLD);
END $$;
REVOKE ALL ON FUNCTION public.caches_signaux_trg() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS zz_caches_signaux ON public.caches_pj;
CREATE TRIGGER zz_caches_signaux AFTER INSERT OR UPDATE OR DELETE ON public.caches_pj
  FOR EACH ROW EXECUTE FUNCTION public.caches_signaux_trg();

-- L'écran ne pose jamais un autre lieu dans presences : il ne rafraîchit que son battement et son groupe.
CREATE OR REPLACE FUNCTION public.presences_position_canonique_trg()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE d record;
BEGIN
  SELECT country, current_city, current_building, current_room, current_street INTO d FROM public.personnages_donnees WHERE name = NEW.name;
  IF FOUND THEN
    NEW.country := d.country; NEW.city := d.current_city;
    NEW.building_id := coalesce(d.current_building, 'rue-centrale');
    NEW.room_id := CASE WHEN d.current_building IS NULL THEN d.current_street ELSE d.current_room END;
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.presences_position_canonique_trg() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS presences_position_canonique ON public.presences;
CREATE TRIGGER presences_position_canonique BEFORE INSERT OR UPDATE ON public.presences
  FOR EACH ROW EXECUTE FUNCTION public.presences_position_canonique_trg();

-- Rattrapage : chaque personnage a sa ligne, au vrai lieu (battement inchangé).
INSERT INTO public.presences (name, country, city, building_id, room_id, updated_at)
SELECT d.name, d.country, d.current_city, coalesce(d.current_building, 'rue-centrale'),
       CASE WHEN d.current_building IS NULL THEN d.current_street ELSE d.current_room END, NULL
  FROM public.personnages_donnees d
ON CONFLICT (name) DO UPDATE SET country = excluded.country, city = excluded.city,
  building_id = excluded.building_id, room_id = excluded.room_id;

-- Numérotation des masqués : par la position enregistrée, connecté ou non.
CREATE OR REPLACE FUNCTION public.crim_masques_piece_interne(p_pays text, p_ville text, p_bat text, p_piece text)
 RETURNS TABLE(nom text, numero integer) LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  -- presence_permanente_v1 : la position du serveur, plus le battement du navigateur.
  SELECT d.name, (row_number() OVER (ORDER BY md5(d.name || p_bat || p_piece)))::integer
    FROM public.personnages_donnees d
   WHERE d.country = p_pays AND d.current_city = p_ville AND d.current_building = p_bat AND d.current_room = p_piece
     AND public.crim_masque_interne(d.name) AND NOT public.crim_cache_interne(d.name);
$function$;

-- Les présents de MA pièce : la position du serveur ; le battement ne donne que « connecté ».
CREATE OR REPLACE FUNCTION public.crim_presents()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); d record; v jsonb;
BEGIN
  -- presence_permanente_v1 (Fred, 20/11/2026)
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room INTO d FROM public.personnages_donnees WHERE name = a;
  IF coalesce(d.current_building, '') = '' OR coalesce(d.current_room, '') = '' THEN RETURN jsonb_build_object('ok', true, 'presents', '[]'::jsonb); END IF;
  WITH m AS (
    SELECT * FROM public.crim_masques_piece_interne(d.country, d.current_city, d.current_building, d.current_room)
  ), pr AS (
    SELECT q.name, p.updated_at, p.groupe_pnj,
           coalesce(p.updated_at > now() - interval '5 minutes', false) AS connecte,
           (q.name <> a AND public.crim_cache_interne(q.name)) AS cache,
           CASE WHEN q.name <> a THEN m.numero END AS numero
      FROM public.personnages_donnees q
      LEFT JOIN public.presences p ON p.name = q.name
      LEFT JOIN m ON m.nom = q.name
     WHERE q.country = d.country AND q.current_city = d.current_city
       AND q.current_building = d.current_building AND q.current_room = d.current_room
  ), vis AS (
    SELECT pr.*, (numero IS NOT NULL) AS masque FROM pr WHERE NOT cache
  )
  SELECT coalesce(jsonb_agg(CASE WHEN masque THEN
           jsonb_build_object('name', 'Individu masqué n°' || numero, 'masque', true, 'numero', numero, 'updated_at', updated_at,
                              'connecte', connecte,
                              'jeton', (SELECT jeton FROM public.crim_jetons_masque j WHERE j.personnage = vis.name),
                              'groupe_pnj', (SELECT coalesce(jsonb_agg(g - 'photoUrl'), '[]'::jsonb)
                                               FROM jsonb_array_elements(CASE WHEN jsonb_typeof(groupe_pnj) = 'array' THEN groupe_pnj ELSE '[]'::jsonb END) g))
         ELSE jsonb_build_object('name', name, 'masque', false, 'updated_at', updated_at, 'connecte', connecte, 'groupe_pnj', groupe_pnj) END
         ORDER BY masque, numero, name), '[]'::jsonb)
    INTO v FROM vis;
  RETURN jsonb_build_object('ok', true, 'presents', v, 'mode', public.crim_mode_action_interne(a),
                            'salle', public.salle_cle_interne(d.country, d.current_city, d.current_building, d.current_room, NULL));
END
$function$;

-- Temps réel : les deux tables de signaux, et elles seules.
DO $p$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'salles_signaux') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.salles_signaux; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'personnages_signaux') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.personnages_signaux; END IF;
END $p$;

COMMIT;
