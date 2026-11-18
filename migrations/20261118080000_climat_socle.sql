-- MALADIES, PÉREMPTION ET CLIMAT — LOT 3 : socle des événements climatiques (GAME-DESIGN-MALADIES-CLIMAT.md §§ 4 et 11).
-- Décisions de Fred (18/11/2026 au soir) :
-- • crue, canicule et orage en Républia : une fois par trimestre et par ville, première ville tirée au hasard, puis les deux
--   autres dans un ordre aléatoire (délais : canicule 2 à 4 jours, orage 1 à 2, crue 1 à 3) ;
-- • brouillard inchangé : deux journées par mois et par ville, tous pays ; orage en Sovarka : une fois par mois et par ville
--   (règle du § 7, à confirmer) ; blizzard : lot 4 ;
-- • alerte au moins 48 h avant, pour chaque ville : article de presse, journal d'événements, fenêtre du gouvernement (écran) ;
-- • crue : 2 ou 3 lieux de la zone inondable de la ville, tirés au hasard et nommés dans l'alerte ;
-- • tout est réglable par le MJ. Les effets propres à chaque événement viennent aux lots 4 et 5 ; ce lot bloque déjà les
--   chantiers de la ville pendant un blizzard, un orage, une crue ou une canicule.
BEGIN;

CREATE TABLE IF NOT EXISTS public.climat_parametres (
  type           text NOT NULL,
  pays           text NOT NULL,
  actif          boolean NOT NULL DEFAULT true,
  frequence      text NOT NULL CHECK (frequence IN ('trimestre_propage', 'mois', 'mandat')),
  par_periode    integer NOT NULL DEFAULT 1 CHECK (par_periode BETWEEN 0 AND 10),
  delai_min      integer NOT NULL DEFAULT 0 CHECK (delai_min >= 0),
  delai_max      integer NOT NULL DEFAULT 0 CHECK (delai_max >= 0),
  duree_heures   integer NOT NULL DEFAULT 24 CHECK (duree_heures BETWEEN 1 AND 240),
  preavis_heures integer NOT NULL DEFAULT 48 CHECK (preavis_heures BETWEEN 0 AND 240),
  bloque_chantiers boolean NOT NULL DEFAULT false,
  PRIMARY KEY (type, pays)
);
ALTER TABLE public.climat_parametres ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.climat_parametres FROM anon, authenticated;
INSERT INTO public.climat_parametres (type, pays, frequence, par_periode, delai_min, delai_max, bloque_chantiers) VALUES
  ('crue',       'republic', 'trimestre_propage', 1, 1, 3, true),
  ('canicule',   'republic', 'trimestre_propage', 1, 2, 4, true),
  ('orage',      'republic', 'trimestre_propage', 1, 1, 2, true),
  ('orage',      'soviet',   'mois',              1, 0, 0, true),
  ('brouillard', 'republic', 'mois',              2, 0, 0, false),
  ('brouillard', 'soviet',   'mois',              2, 0, 0, false)
ON CONFLICT (type, pays) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.climat_zones_inondables (
  pays text NOT NULL, ville text NOT NULL, batiment text NOT NULL, nom text NOT NULL,
  PRIMARY KEY (pays, ville, batiment)
);
ALTER TABLE public.climat_zones_inondables ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.climat_zones_inondables FROM anon, authenticated;
INSERT INTO public.climat_zones_inondables (pays, ville, batiment, nom) VALUES
  ('republic', 'capitale', 'entrepot-logistique-luthecia', 'l''entrepôt logistique'),
  ('republic', 'capitale', 'marche',                       'le marché'),
  ('republic', 'capitale', 'parc-botanique-national',      'le parc botanique'),
  ('republic', 'ville_a',  'port-sainte-marie',            'le port'),
  ('republic', 'ville_a',  'port-plaisance-psm',           'le port de plaisance'),
  ('republic', 'ville_a',  'bar-des-pecheurs',             'le bar des Pêcheurs'),
  ('republic', 'ville_a',  'chantier-naval',               'le chantier naval'),
  ('republic', 'ville_a',  'marche-psm',                   'le marché'),
  ('republic', 'ville_a',  'chasse-peche-psm',             'la boutique Chasse et Pêche'),
  ('republic', 'ville_b',  'entrepot-logistique-montrouge','l''entrepôt logistique'),
  ('republic', 'ville_b',  'zone-production',              'la zone de production')
ON CONFLICT (pays, ville, batiment) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.climat_evenements (
  id        bigserial PRIMARY KEY,
  type      text NOT NULL,
  pays      text NOT NULL,
  ville     text NOT NULL,
  debut     timestamptz NOT NULL,
  fin       timestamptz NOT NULL,
  periode   text NOT NULL,            -- '2026-T4' (trimestre) ou '2026-11' (mois) : unicité du calendrier
  lieux     jsonb NOT NULL DEFAULT '[]'::jsonb,
  alerte_le timestamptz,
  origine   text NOT NULL DEFAULT 'calendrier' CHECK (origine IN ('calendrier', 'mj')),
  annule    boolean NOT NULL DEFAULT false,
  cree_le   timestamptz NOT NULL DEFAULT now(),
  CHECK (fin > debut)
);
CREATE INDEX IF NOT EXISTS climat_evenements_ville_idx ON public.climat_evenements (pays, ville, debut);
ALTER TABLE public.climat_evenements ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.climat_evenements FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.climat_villes_interne(p_pays text)
RETURNS text[] LANGUAGE sql IMMUTABLE AS $$ SELECT ARRAY['capitale', 'ville_a', 'ville_b']; $$;

CREATE OR REPLACE FUNCTION public.climat_nom_ville_interne(p_pays text, p_ville text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_pays WHEN 'republic' THEN CASE p_ville WHEN 'capitale' THEN 'Luthécia' WHEN 'ville_a' THEN 'Port-Sainte-Marie' WHEN 'ville_b' THEN 'Montrouge' END
                     ELSE CASE p_ville WHEN 'capitale' THEN 'Novomirsk' WHEN 'ville_a' THEN 'Starovka' WHEN 'ville_b' THEN 'Krasnov' END END;
$$;

-- Début d'un événement : minuit (Paris) du jour donné.
CREATE OR REPLACE FUNCTION public.climat_minuit_interne(p_jour date)
RETURNS timestamptz LANGUAGE sql IMMUTABLE AS $$ SELECT (p_jour::timestamp) AT TIME ZONE 'Europe/Paris'; $$;

CREATE OR REPLACE FUNCTION public.climat_creer_interne(p_type text, p_pays text, p_ville text, p_jour date, p_periode text, p_origine text)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE c public.climat_parametres; v_lieux jsonb := '[]'::jsonb; v_id bigint;
BEGIN
  SELECT * INTO c FROM public.climat_parametres WHERE type = p_type AND pays = p_pays;
  IF p_type = 'crue' THEN
    SELECT coalesce(jsonb_agg(jsonb_build_object('batiment', batiment, 'nom', nom)), '[]'::jsonb) INTO v_lieux
      FROM (SELECT batiment, nom FROM public.climat_zones_inondables WHERE pays = p_pays AND ville = p_ville
             ORDER BY random() LIMIT (2 + floor(random() * 2))::integer) z;
    IF jsonb_array_length(v_lieux) = 0 THEN RETURN NULL; END IF;   -- ville sans zone inondable
  END IF;
  INSERT INTO public.climat_evenements (type, pays, ville, debut, fin, periode, lieux, origine)
  VALUES (p_type, p_pays, p_ville, public.climat_minuit_interne(p_jour),
          public.climat_minuit_interne(p_jour) + make_interval(hours => coalesce(c.duree_heures, 24)), p_periode, v_lieux, p_origine)
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;

-- Planifie le trimestre (ou le mois) en cours et le suivant, sans jamais revenir sur ce qui existe déjà.
CREATE OR REPLACE FUNCTION public.climat_planifier_interne()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE c public.climat_parametres; v_auj date := (now() AT TIME ZONE 'Europe/Paris')::date; v_min date; v_deb date; v_fin date;
        k integer; v_periode text; v_villes text[]; v_ville text; v_jour date; v_dernier date; v_n integer := 0; v_marge integer; j integer;
        v_jours date[];
BEGIN
  FOR c IN SELECT * FROM public.climat_parametres WHERE actif AND frequence IN ('trimestre_propage', 'mois') AND par_periode > 0 LOOP
    v_min := v_auj + ceil(c.preavis_heures / 24.0)::integer + 1;   -- jamais d'événement sans préavis complet
    FOR k IN 0 .. 1 LOOP
      IF c.frequence = 'trimestre_propage' THEN
        v_deb := (date_trunc('quarter', v_auj::timestamp) + make_interval(months => 3 * k))::date;
        v_fin := (v_deb + interval '3 months')::date - 1;
        v_periode := to_char(v_deb, 'YYYY') || '-T' || extract(quarter FROM v_deb)::text;
        IF EXISTS (SELECT 1 FROM public.climat_evenements WHERE type = c.type AND pays = c.pays AND periode = v_periode AND origine = 'calendrier') THEN CONTINUE; END IF;
        v_marge := 2 * c.delai_max;
        v_deb := greatest(v_deb, v_min);
        IF v_fin - v_marge < v_deb THEN CONTINUE; END IF;   -- plus la place ce trimestre-ci
        SELECT array_agg(x ORDER BY random()) INTO v_villes FROM unnest(public.climat_villes_interne(c.pays)) x;
        v_jour := v_deb + floor(random() * (v_fin - v_marge - v_deb + 1))::integer;
        FOREACH v_ville IN ARRAY v_villes LOOP
          IF public.climat_creer_interne(c.type, c.pays, v_ville, v_jour, v_periode, 'calendrier') IS NOT NULL THEN v_n := v_n + 1; END IF;
          v_jour := v_jour + c.delai_min + floor(random() * (c.delai_max - c.delai_min + 1))::integer;
        END LOOP;
      ELSE
        v_deb := (date_trunc('month', v_auj::timestamp) + make_interval(months => k))::date;
        v_fin := (v_deb + interval '1 month')::date - 1;
        v_periode := to_char(v_deb, 'YYYY-MM');
        FOREACH v_ville IN ARRAY public.climat_villes_interne(c.pays) LOOP
          IF EXISTS (SELECT 1 FROM public.climat_evenements WHERE type = c.type AND pays = c.pays AND ville = v_ville AND periode = v_periode AND origine = 'calendrier') THEN CONTINUE; END IF;
          IF v_fin < greatest(v_deb, v_min) THEN CONTINUE; END IF;
          SELECT array_agg(d ORDER BY d) INTO v_jours FROM (
            SELECT d::date FROM generate_series(greatest(v_deb, v_min), v_fin, interval '1 day') d ORDER BY random() LIMIT c.par_periode) s;
          FOREACH v_jour IN ARRAY coalesce(v_jours, '{}') LOOP
            IF public.climat_creer_interne(c.type, c.pays, v_ville, v_jour, v_periode, 'calendrier') IS NOT NULL THEN v_n := v_n + 1; END IF;
          END LOOP;
        END LOOP;
      END IF;
    END LOOP;
  END LOOP;
  RETURN v_n;
END $$;

CREATE OR REPLACE FUNCTION public.climat_texte_alerte_interne(e public.climat_evenements)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE e.type
    WHEN 'crue' THEN 'Crue annoncée à ' || public.climat_nom_ville_interne(e.pays, e.ville) || ' le ' || to_char(e.debut AT TIME ZONE 'Europe/Paris', 'DD/MM')
      || ' : ' || (SELECT string_agg(l->>'nom', ', ') FROM jsonb_array_elements(e.lieux) l) || ' seront sous les eaux pendant 24 heures.'
    WHEN 'canicule' THEN 'Canicule annoncée à ' || public.climat_nom_ville_interne(e.pays, e.ville) || ' le ' || to_char(e.debut AT TIME ZONE 'Europe/Paris', 'DD/MM') || ' : buvez, restez à l''ombre.'
    WHEN 'orage' THEN 'Violent orage annoncé à ' || public.climat_nom_ville_interne(e.pays, e.ville) || ' le ' || to_char(e.debut AT TIME ZONE 'Europe/Paris', 'DD/MM') || ' : coupures d''électricité et d''internet probables.'
    WHEN 'brouillard' THEN 'Brouillard épais attendu à ' || public.climat_nom_ville_interne(e.pays, e.ville) || ' le ' || to_char(e.debut AT TIME ZONE 'Europe/Paris', 'DD/MM') || '.'
    WHEN 'blizzard' THEN 'Blizzard annoncé à ' || public.climat_nom_ville_interne(e.pays, e.ville) || ' le ' || to_char(e.debut AT TIME ZONE 'Europe/Paris', 'DD/MM') || ' : munissez-vous de graisse.'
    ELSE 'Événement climatique annoncé à ' || public.climat_nom_ville_interne(e.pays, e.ville) || '.' END;
$$;

-- Publie les alertes dont le préavis est atteint : journal d'événements et article de presse (une fois chacun).
CREATE OR REPLACE FUNCTION public.climat_alertes_publier_interne()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE e public.climat_evenements; v_n integer := 0; v_txt text;
BEGIN
  FOR e IN SELECT ev.* FROM public.climat_evenements ev JOIN public.climat_parametres c ON c.type = ev.type AND c.pays = ev.pays
            WHERE NOT ev.annule AND ev.alerte_le IS NULL AND ev.fin > now()
              AND ev.debut <= now() + make_interval(hours => c.preavis_heures) FOR UPDATE OF ev LOOP
    v_txt := public.climat_texte_alerte_interne(e);
    INSERT INTO public.evenements_globaux (country, city, texte, jour) VALUES (e.pays, e.ville, '⚠️ ' || v_txt, NULL);
    INSERT INTO public.journal_articles_en_attente (id, country, rubrique, titre, texte, statut, origine, priorite, dedup_key, created_at)
    VALUES ('climat-' || e.id, e.pays, 'politique', 'Alerte météo : ' || public.climat_nom_ville_interne(e.pays, e.ville),
            v_txt || ' Les autorités appellent la population à la prudence.', 'attente', 'climat', 'importante', 'climat-' || e.id, now())
    ON CONFLICT (id) DO NOTHING;
    UPDATE public.climat_evenements SET alerte_le = now() WHERE id = e.id;
    v_n := v_n + 1;
  END LOOP;
  RETURN v_n;
END $$;

CREATE OR REPLACE FUNCTION public.climat_passe()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  RETURN jsonb_build_object('ok', true, 'planifies', public.climat_planifier_interne(), 'alertes', public.climat_alertes_publier_interne());
END $$;

-- Événement en cours dans une ville (pour les effets et les refus).
CREATE OR REPLACE FUNCTION public.climat_en_cours_interne(p_pays text, p_ville text, p_type text DEFAULT NULL)
RETURNS public.climat_evenements LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT * FROM public.climat_evenements WHERE pays = p_pays AND ville = p_ville AND NOT annule AND now() >= debut AND now() < fin
     AND (p_type IS NULL OR type = p_type) ORDER BY debut LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.climat_chantiers_bloques_interne(p_pays text, p_ville text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.climat_evenements e JOIN public.climat_parametres c ON c.type = e.type AND c.pays = e.pays
                  WHERE e.pays = p_pays AND e.ville = p_ville AND NOT e.annule AND e.alerte_le IS NOT NULL   -- jamais sans alerte publiée
                    AND now() >= e.debut AND now() < e.fin AND c.bloque_chantiers);
$$;

-- Lecture du joueur : alertes publiées et événements en cours de son pays.
CREATE OR REPLACE FUNCTION public.climat_etat()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); p public.personnages_donnees;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = a;
  RETURN jsonb_build_object('ok', true, 'maintenant', now(), 'evenements', (
    SELECT coalesce(jsonb_agg(jsonb_build_object('id', id, 'type', type, 'ville', ville, 'debut', debut, 'fin', fin,
             'lieux', (SELECT coalesce(jsonb_agg(l->>'batiment'), '[]'::jsonb) FROM jsonb_array_elements(lieux) l),
             'en_cours', now() >= debut AND now() < fin) ORDER BY debut), '[]'::jsonb)
      FROM public.climat_evenements WHERE pays = p.country AND NOT annule AND alerte_le IS NOT NULL AND fin > now()));
END $$;

-- ── Chantiers bloqués pendant les intempéries ───────────────────────────────────────────────────
DO $$
DECLARE f regprocedure := 'public.chantier_travailler(text,text,text,integer)'::regprocedure; d text;
  avant text := E'  PERFORM public.exiger_acteur(p_acteur);\n  IF COALESCE(p_heures, 0) <= 0 THEN';
  apres text := E'  PERFORM public.exiger_acteur(p_acteur);\n  IF public.climat_chantiers_bloques_interne(p_pays, (SELECT current_city FROM public.personnages_donnees WHERE name = p_acteur)) THEN -- climat_chantiers_v1\n    RETURN jsonb_build_object(''ok'', false, ''raison'', ''chantier_intemperies'');\n  END IF;\n  IF COALESCE(p_heures, 0) <= 0 THEN';
BEGIN
  d := pg_get_functiondef(f);
  IF position('climat_chantiers_v1' IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'chantier_travailler : ancrage'; END IF;
  EXECUTE replace(d, avant, apres);
END $$;

-- ── Outils du MJ ─────────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_climat_lire()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  PERFORM public.admin_exiger();
  RETURN jsonb_build_object('ok', true,
    'parametres', (SELECT coalesce(jsonb_agg(to_jsonb(c) ORDER BY c.pays, c.type), '[]'::jsonb) FROM public.climat_parametres c),
    'evenements', (SELECT coalesce(jsonb_agg(to_jsonb(e) ORDER BY e.debut), '[]'::jsonb) FROM public.climat_evenements e
                    WHERE e.fin > now() - interval '7 days'),
    'zones', (SELECT coalesce(jsonb_agg(to_jsonb(z) ORDER BY z.ville, z.batiment), '[]'::jsonb) FROM public.climat_zones_inondables z));
END $$;

CREATE OR REPLACE FUNCTION public.admin_climat_parametre_modifier(p_type text, p_pays text, p_parametres jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE c public.climat_parametres; k text;
BEGIN
  PERFORM public.admin_exiger();
  SELECT * INTO c FROM public.climat_parametres WHERE type = p_type AND pays = p_pays FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'parametre_inconnu'); END IF;
  FOR k IN SELECT jsonb_object_keys(coalesce(p_parametres, '{}'::jsonb)) LOOP
    IF k NOT IN ('actif', 'par_periode', 'delai_min', 'delai_max', 'duree_heures', 'preavis_heures', 'bloque_chantiers') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'champ_inconnu', 'champ', k); END IF;
  END LOOP;
  UPDATE public.climat_parametres SET
    actif = coalesce((p_parametres->>'actif')::boolean, actif),
    par_periode = coalesce((p_parametres->>'par_periode')::integer, par_periode),
    delai_min = coalesce((p_parametres->>'delai_min')::integer, delai_min),
    delai_max = greatest(coalesce((p_parametres->>'delai_min')::integer, delai_min), coalesce((p_parametres->>'delai_max')::integer, delai_max)),
    duree_heures = coalesce((p_parametres->>'duree_heures')::integer, duree_heures),
    preavis_heures = coalesce((p_parametres->>'preavis_heures')::integer, preavis_heures),
    bloque_chantiers = coalesce((p_parametres->>'bloque_chantiers')::boolean, bloque_chantiers)
  WHERE type = p_type AND pays = p_pays;
  INSERT INTO public.admin_journal (admin_user_id, admin_libelle, action, parametres, ok)
  VALUES (auth.uid(), 'MJ', 'climat_parametre_modifier', jsonb_build_object('type', p_type, 'pays', p_pays) || coalesce(p_parametres, '{}'::jsonb), true);
  RETURN jsonb_build_object('ok', true);
END $$;

-- Créer un événement à une date (l'alerte suit le préavis normal ; une date trop proche est annoncée tout de suite).
CREATE OR REPLACE FUNCTION public.admin_climat_creer(p_type text, p_pays text, p_ville text, p_jour date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_id bigint;
BEGIN
  PERFORM public.admin_exiger();
  IF NOT EXISTS (SELECT 1 FROM public.climat_parametres WHERE type = p_type AND pays = p_pays) OR NOT (p_ville = ANY (public.climat_villes_interne(p_pays)))
     OR p_jour IS NULL OR p_jour < (now() AT TIME ZONE 'Europe/Paris')::date THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  v_id := public.climat_creer_interne(p_type, p_pays, p_ville, p_jour, 'mj-' || to_char(now(), 'YYYYMMDDHH24MISS'), 'mj');
  IF v_id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'ville_sans_zone_inondable'); END IF;
  PERFORM public.climat_alertes_publier_interne();
  INSERT INTO public.admin_journal (admin_user_id, admin_libelle, action, parametres, resultat, ok)
  VALUES (auth.uid(), 'MJ', 'climat_creer', jsonb_build_object('type', p_type, 'pays', p_pays, 'ville', p_ville, 'jour', p_jour), jsonb_build_object('id', v_id), true);
  RETURN jsonb_build_object('ok', true, 'id', v_id);
END $$;

CREATE OR REPLACE FUNCTION public.admin_climat_annuler(p_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  PERFORM public.admin_exiger();
  UPDATE public.climat_evenements SET annule = true WHERE id = p_id AND NOT annule;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'evenement_inconnu'); END IF;
  INSERT INTO public.admin_journal (admin_user_id, admin_libelle, action, parametres, ok)
  VALUES (auth.uid(), 'MJ', 'climat_annuler', jsonb_build_object('id', p_id), true);
  RETURN jsonb_build_object('ok', true);
END $$;

REVOKE ALL ON FUNCTION public.climat_villes_interne(text), public.climat_nom_ville_interne(text, text), public.climat_minuit_interne(date),
  public.climat_creer_interne(text, text, text, date, text, text), public.climat_planifier_interne(), public.climat_texte_alerte_interne(public.climat_evenements),
  public.climat_alertes_publier_interne(), public.climat_passe(), public.climat_en_cours_interne(text, text, text),
  public.climat_chantiers_bloques_interne(text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.climat_etat(), public.admin_climat_lire(), public.admin_climat_parametre_modifier(text, text, jsonb),
  public.admin_climat_creer(text, text, text, date), public.admin_climat_annuler(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.climat_etat(), public.admin_climat_lire(), public.admin_climat_parametre_modifier(text, text, jsonb),
  public.admin_climat_creer(text, text, text, date), public.admin_climat_annuler(bigint) TO authenticated;

DO $$ BEGIN
  PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'climat_passe';
  PERFORM cron.schedule('climat_passe', '17 * * * *', 'SELECT public.climat_passe()');
END $$;

-- Première planification tout de suite (trimestre et mois en cours, puis suivants).
SELECT public.climat_passe();
-- En production, la passe horaire a été mise en pause le 18/11 (cron.alter_job active := false) jusqu'à la fusion de la PR
-- qui livre l'écran ; on la réactive alors : SELECT cron.alter_job(jobid, active := true) FROM cron.job WHERE jobname = 'climat_passe';

DO $$ BEGIN
  IF position('climat_chantiers_v1' IN pg_get_functiondef('public.chantier_travailler(text,text,text,integer)'::regprocedure)) = 0
     OR (SELECT count(DISTINCT ville) FROM public.climat_evenements WHERE type = 'crue' AND pays = 'republic' AND origine = 'calendrier') NOT IN (0, 3)
     OR EXISTS (SELECT 1 FROM public.climat_evenements WHERE origine = 'calendrier' AND alerte_le IS NULL AND debut < now() + interval '48 hours')
  THEN RAISE EXCEPTION 'climat lot 3 : controle structurel en echec'; END IF;
END $$;

COMMIT;
