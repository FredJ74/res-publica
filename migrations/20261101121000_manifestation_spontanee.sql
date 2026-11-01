-- ============================================================================
-- MANIFESTATION SPONTANEE SUR LES PLACES DES VILLES (1er novembre 2026)
-- ============================================================================
-- Decision de Fred (game designer), 1er novembre 2026 :
--   * ordre commun a chaque place de ville : Place du Formulaire de la Liberte (Luthecia),
--     Place d'Armes (Port-Sainte-Marie), Place du Rail (Montrouge) ;
--   * il faut etre le chef d'un groupe d'au moins 10 PJ (le chef compris), presents sur la place ;
--   * pas de declaration prealable ; chaque PJ du groupe devient hors-la-loi (avis de recherche)
--     le temps de la manifestation, la police presente peut donc les interpeller ;
--   * une seule manifestation spontanee par jour et par ville, quel que soit le PJ ; une
--     manifestation officielle le meme jour ne la bloque pas (reponse de Fred : « pas de blocage ») ;
--   * le chef choisit « en faveur » ou « hostile » et une cible, comme pour les tracts ;
--   * effet immediat au clic : +1 POP (en faveur) ou -1 POP (hostile) a la cible PAR PARTICIPANT ;
--   * duree maximale 1 h ; fin des que le chef quitte le groupe (le groupe est dissous) ;
--   * a la fin, les participants ne sont plus hors-la-loi ; une trace de leur action demeure
--     (historique_crimes, non decouvrable la nuit : elle sert aux rumeurs et aux fuites).
--
-- DEPEND DE #219 (Codex, groupes PJ persistants : public.groupes_pj_adhesions). La migration
-- se refuse tant que cette table n'existe pas. NE PAS APPLIQUER AVANT #219 INSTALLE.
--
-- Fin a l'heure : il n'y a pas de cron infra-journalier. La cloture est faite par le serveur
-- (1) a chaque lecture manif_spontanee_lire (appelee par les ecrans presents sur une place ou
-- participants, chaque minute), (2) avant chaque nouvelle manifestation, (3) immediatement par
-- un declencheur quand le groupe du chef est dissous.
-- Idempotente.
-- ============================================================================

DO $garde$
BEGIN
  IF to_regclass('public.groupes_pj_adhesions') IS NULL THEN
    RAISE EXCEPTION 'manifestation_spontanee : attend #219 (table groupes_pj_adhesions absente)';
  END IF;
END $garde$;

-- Bareme penal d'une interpellation pendant la manifestation : 1 jour et 500 FR (Fred, 1/11/2026).
-- Non decouvrable : apres la manifestation, la trace ne vaut aucune arrestation de nuit.
INSERT INTO public.actes_illegaux (fn, type, detect_rate, peine_jours, amende, decouvrable)
VALUES ('manifestation_spontanee', 'delit_mineur', 25, 1, 500, false)
ON CONFLICT (fn) DO UPDATE SET type = EXCLUDED.type, peine_jours = EXCLUDED.peine_jours, amende = EXCLUDED.amende,
  decouvrable = EXCLUDED.decouvrable, maj_le = now();

-- Cout de l'ordre (miroir de data.js : 1 PA, 0 FR).
INSERT INTO public.ordres_couts (fn, pa, cost) VALUES ('organiser_manifestation_spontanee', 1, 0)
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS public.manifestations_spontanees (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pays         text NOT NULL,
  ville        text NOT NULL,
  batiment     text NOT NULL,
  jour         date NOT NULL,
  chef         text NOT NULL,
  sens         text NOT NULL CHECK (sens IN ('pour', 'contre')),
  cible        text NOT NULL,
  participants text[] NOT NULL,
  effet_pop    integer NOT NULL,
  debut        timestamptz NOT NULL DEFAULT now(),
  fin_max      timestamptz NOT NULL,
  fin_reelle   timestamptz,
  motif_fin    text,
  CONSTRAINT manif_spontanee_une_par_jour UNIQUE (pays, ville, jour)
);
CREATE INDEX IF NOT EXISTS manif_spontanee_actives_idx ON public.manifestations_spontanees (fin_reelle) WHERE fin_reelle IS NULL;
ALTER TABLE public.manifestations_spontanees ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.manifestations_spontanees FROM PUBLIC, anon, authenticated;

-- Les places : seul endroit ou l'ordre existe (miroir de data.js).
CREATE OR REPLACE FUNCTION public.manif_spontanee_place_interne(p_batiment text)
 RETURNS text LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp'
AS $$ SELECT CASE p_batiment
    WHEN 'place-formulaire-liberte' THEN 'Place du Formulaire de la Liberté (Luthécia)'
    WHEN 'place-armes-psm'          THEN 'Place d''Armes (Port-Sainte-Marie)'
    WHEN 'place-du-rail-montrouge'  THEN 'Place du Rail (Montrouge)' END $$;

-- Cloture : leve les avis de recherche poses par la manifestation, elle seule.
CREATE OR REPLACE FUNCTION public.manif_spontanee_clore_une_interne(p_id uuid, p_motif text)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE m record;
BEGIN
  UPDATE public.manifestations_spontanees SET fin_reelle = now(), motif_fin = p_motif
   WHERE id = p_id AND fin_reelle IS NULL RETURNING * INTO m;
  IF NOT FOUND THEN RETURN; END IF;
  PERFORM set_config('rp.recherche_interne', 'on', true);
  UPDATE public.personnages_donnees
     SET recherche = coalesce((SELECT jsonb_agg(e) FROM jsonb_array_elements(recherche) e
                                WHERE e ->> 'manif' IS DISTINCT FROM p_id::text), '[]'::jsonb)
   WHERE name = ANY (m.participants) AND jsonb_typeof(recherche) = 'array';
  PERFORM set_config('rp.recherche_interne', '', true);
END; $function$;

CREATE OR REPLACE FUNCTION public.manif_spontanee_clore_echues_interne()
 RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; n integer := 0;
BEGIN
  FOR r IN SELECT id, chef, fin_max FROM public.manifestations_spontanees WHERE fin_reelle IS NULL FOR UPDATE SKIP LOCKED LOOP
    IF now() >= r.fin_max THEN
      PERFORM public.manif_spontanee_clore_une_interne(r.id, 'duree_ecoulee'); n := n + 1;
    ELSIF NOT EXISTS (SELECT 1 FROM public.groupes_pj_adhesions WHERE chef = r.chef) THEN
      PERFORM public.manif_spontanee_clore_une_interne(r.id, 'chef_parti'); n := n + 1;
    END IF;
  END LOOP;
  RETURN n;
END; $function$;

-- Le chef quitte son groupe (groupe dissous) : fin immediate.
CREATE OR REPLACE FUNCTION public.manif_spontanee_groupe_dissous()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.groupes_pj_adhesions WHERE chef = OLD.chef) THEN
    FOR r IN SELECT id FROM public.manifestations_spontanees WHERE chef = OLD.chef AND fin_reelle IS NULL LOOP
      PERFORM public.manif_spontanee_clore_une_interne(r.id, 'chef_parti');
    END LOOP;
  END IF;
  RETURN NULL;
END; $function$;
DROP TRIGGER IF EXISTS manif_spontanee_groupe_dissous ON public.groupes_pj_adhesions;
CREATE TRIGGER manif_spontanee_groupe_dissous AFTER DELETE ON public.groupes_pj_adhesions
  FOR EACH ROW EXECUTE FUNCTION public.manif_spontanee_groupe_dissous();

CREATE OR REPLACE FUNCTION public.manif_spontanee_resume_interne(m public.manifestations_spontanees)
 RETURNS jsonb LANGUAGE sql STABLE SET search_path TO 'public', 'pg_temp'
AS $$ SELECT jsonb_build_object('id', m.id, 'lieu', public.manif_spontanee_place_interne(m.batiment), 'chef', m.chef,
    'sens', m.sens, 'cible', m.cible, 'participants', to_jsonb(m.participants), 'effet_pop', m.effet_pop,
    'debut', m.debut, 'fin_max', m.fin_max, 'fin_reelle', m.fin_reelle, 'motif_fin', m.motif_fin,
    'active', m.fin_reelle IS NULL) $$;

-- L'ordre. Tout est decide ici : groupe, presence, limite du jour, paiement, POP, avis, trace.
CREATE OR REPLACE FUNCTION public.manif_spontanee_organiser(p_sens text, p_cible text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; a record; v_lieu text; v_jour date; v_participants text[]; v_n integer;
  v_paie jsonb; v_delta integer; v_pop numeric; m public.manifestations_spontanees; p text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'non_authentifie'); END IF;
  IF p_sens NOT IN ('pour', 'contre') THEN RETURN jsonb_build_object('ok', false, 'raison', 'sens_invalide'); END IF;
  IF coalesce(btrim(p_cible), '') = '' OR NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_cible) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;

  SELECT country, current_city, current_building, current_room INTO a FROM public.personnages_donnees WHERE name = v_moi;
  v_lieu := public.manif_spontanee_place_interne(a.current_building);
  IF v_lieu IS NULL OR a.current_room IS DISTINCT FROM 'place' OR a.country IS NULL OR a.current_city IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_place'); END IF;
  IF EXISTS (SELECT 1 FROM public.groupes_pj_adhesions WHERE membre = v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_chef'); END IF;

  -- Une seule par ville et par jour (horloge commune, bascule a minuit, heure de Paris).
  PERFORM pg_advisory_xact_lock(hashtextextended('manif_spontanee:' || a.country || ':' || a.current_city, 0));
  PERFORM public.manif_spontanee_clore_echues_interne();
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date;
  IF EXISTS (SELECT 1 FROM public.manifestations_spontanees WHERE pays = a.country AND ville = a.current_city AND jour = v_jour) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_aujourdhui'); END IF;

  -- Participants : le chef et les PJ de son groupe presents avec lui sur la place.
  SELECT array_agg(d.name ORDER BY d.name) INTO v_participants
    FROM public.personnages_donnees d
   WHERE (d.name = v_moi OR d.name IN (SELECT membre FROM public.groupes_pj_adhesions WHERE chef = v_moi))
     AND d.country = a.country AND d.current_city = a.current_city
     AND d.current_building = a.current_building AND d.current_room = a.current_room;
  v_n := coalesce(array_length(v_participants, 1), 0);
  IF v_n < 10 THEN RETURN jsonb_build_object('ok', false, 'raison', 'groupe_insuffisant', 'presents', v_n, 'minimum', 10); END IF;

  v_paie := public.payer_ordre(v_moi, 'organiser_manifestation_spontanee', 1, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;

  v_delta := CASE WHEN p_sens = 'pour' THEN v_n ELSE -v_n END;
  UPDATE public.personnages_donnees
     SET resources = jsonb_set(CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END, '{pop}',
           to_jsonb(least(100, greatest(0, coalesce(CASE WHEN jsonb_typeof(resources -> 'pop') = 'number'
                                                         THEN (resources ->> 'pop')::numeric END, 50) + v_delta))))
   WHERE name = p_cible
  RETURNING (resources ->> 'pop')::numeric INTO v_pop;

  INSERT INTO public.manifestations_spontanees (pays, ville, batiment, jour, chef, sens, cible, participants, effet_pop, fin_max)
  VALUES (a.country, a.current_city, a.current_building, v_jour, v_moi, p_sens, p_cible, v_participants, v_delta, now() + interval '1 hour')
  RETURNING * INTO m;

  -- Hors-la-loi le temps de la manifestation : avis de recherche marque du numero de la manif.
  PERFORM set_config('rp.recherche_interne', 'on', true);
  UPDATE public.personnages_donnees
     SET recherche = (CASE WHEN jsonb_typeof(recherche) = 'array' THEN recherche ELSE '[]'::jsonb END)
       || jsonb_build_array(jsonb_build_object('acte', 'manifestation_spontanee', 'type', 'delit_mineur',
            'jour', coalesce(day, 1), 'country', country, 'manif', m.id::text))
   WHERE name = ANY (v_participants);
  PERFORM set_config('rp.recherche_interne', '', true);
  FOREACH p IN ARRAY v_participants LOOP
    PERFORM public.crime_tracer_interne(p, 'manifestation_spontanee',
      CASE WHEN p_sens = 'pour' THEN 'en faveur de ' ELSE 'hostile à ' END || p_cible);
  END LOOP;

  PERFORM public.annonce_publique_interne(a.country, '📢 Manifestation spontanée, ' || v_lieu || ' : ' || v_n
    || ' manifestants ' || CASE WHEN p_sens = 'pour' THEN 'en faveur de ' ELSE 'contre ' END || p_cible || '.');

  RETURN jsonb_build_object('ok', true, 'manif', public.manif_spontanee_resume_interne(m), 'pop_cible', v_pop)
    || (SELECT jsonb_build_object('pa', pa, 'pop', (resources ->> 'pop')::numeric, 'recherche', recherche)
          FROM public.personnages_donnees WHERE name = v_moi);
END; $function$;

-- Lecture (et cloture des manifestations echues) : la manifestation du jour dans ma ville,
-- ma participation et mon avis de recherche a jour.
CREATE OR REPLACE FUNCTION public.manif_spontanee_lire()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; a record; m public.manifestations_spontanees;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'non_authentifie'); END IF;
  PERFORM public.manif_spontanee_clore_echues_interne();
  SELECT country, current_city, recherche, (resources ->> 'pop')::numeric AS pop INTO a
    FROM public.personnages_donnees WHERE name = v_moi;
  SELECT * INTO m FROM public.manifestations_spontanees
   WHERE pays = a.country AND ville = a.current_city AND jour = (now() AT TIME ZONE 'Europe/Paris')::date;
  RETURN jsonb_build_object('ok', true, 'recherche', a.recherche, 'pop', a.pop,
    'manif', CASE WHEN m.id IS NULL THEN NULL ELSE public.manif_spontanee_resume_interne(m) END,
    'participe', m.id IS NOT NULL AND v_moi = ANY (m.participants) AND m.fin_reelle IS NULL);
END; $function$;

REVOKE ALL ON FUNCTION public.manif_spontanee_place_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.manif_spontanee_clore_une_interne(uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.manif_spontanee_clore_echues_interne() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.manif_spontanee_groupe_dissous() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.manif_spontanee_resume_interne(public.manifestations_spontanees) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.manif_spontanee_organiser(text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.manif_spontanee_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.manif_spontanee_organiser(text, text), public.manif_spontanee_lire() TO authenticated;
