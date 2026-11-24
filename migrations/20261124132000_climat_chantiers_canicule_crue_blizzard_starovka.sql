-- NON APPLIQUÉE — mission « Purge » du 24/11/2026, bloc D (climat), point D.2 (consigne de Fred) :
-- « Seules la CANICULE et la CRUE arrêtent les chantiers. L'orage et le blizzard ne les arrêtent pas : corrige aussi la
--   consigne d'alerte de l'orage. Le blizzard n'existe qu'à Starovka : vérifie le tirage. »
-- Constat (base lue le 24/11) : climat_parametres.bloque_chantiers valait vrai pour l'orage (deux pays) et le blizzard ; la
-- consigne de l'orage disait « les chantiers sont à l'arrêt » ; le blizzard (fréquence « mandat ») était tiré dans les trois
-- villes de Sovarka (prochains : Starovka 25/11, Novomirsk 28/11, Krasnov 01/12).
-- • bloque_chantiers = faux pour l'orage et le blizzard (réglage MJ inchangé dans sa forme).
-- • Consigne de l'orage : « … ni de piratage, mais les chantiers continuent. » (la marque est ce texte).
-- • Nouvelle table climat_villes_exclues (type, pays, ville) : une ville exclue n'est jamais tirée pour ce type
--   (climat_creer_interne, marque climat_ville_exclue_v1 ; refus « ville_exclue » côté MJ). Lignes : blizzard à Novomirsk
--   (soviet/capitale) et à Krasnov (soviet/ville_b) — le blizzard ne reste qu'à Starovka (soviet/ville_a).
-- • Blizzards déjà planifiés hors de Starovka et pas encore commencés : annulés (correction publiée si l'alerte était sortie).
-- Rejouable (ON CONFLICT, marques, gardes). Aucune fonction commune, aucun objet du goulag.
BEGIN;
UPDATE public.climat_parametres SET bloque_chantiers = false WHERE type IN ('orage', 'blizzard') AND bloque_chantiers;

CREATE TABLE IF NOT EXISTS public.climat_villes_exclues (
  type text NOT NULL, pays text NOT NULL, ville text NOT NULL, raison text,
  PRIMARY KEY (type, pays, ville));
ALTER TABLE public.climat_villes_exclues ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.climat_villes_exclues FROM PUBLIC, anon, authenticated;
INSERT INTO public.climat_villes_exclues (type, pays, ville, raison) VALUES
  ('blizzard', 'soviet', 'capitale', 'Fred, 24/11/2026 (D.2) : le blizzard n''existe qu''à Starovka'),
  ('blizzard', 'soviet', 'ville_b', 'Fred, 24/11/2026 (D.2) : le blizzard n''existe qu''à Starovka')
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION public.climat_ville_exclue_interne(p_type text, p_pays text, p_ville text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.climat_villes_exclues WHERE type = p_type AND pays = p_pays AND ville = p_ville);
$$;
REVOKE ALL ON FUNCTION public.climat_ville_exclue_interne(text, text, text) FROM PUBLIC, anon, authenticated;

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

SELECT pg_temp.rp_remplacer('public.climat_consigne_interne(text,text,text)'::regprocedure,
  $a$'et les chantiers sont à l''arrêt. Débranchez$a$,
  $b$'mais les chantiers continuent. Débranchez$b$,
  1, 'mais les chantiers continuent.');   -- la marque est le texte lui-même (le raccord est dans une chaîne)

SELECT pg_temp.rp_remplacer('public.climat_creer_interne(text,text,text,date,text,text)'::regprocedure,
  $a$  SELECT * INTO c FROM public.climat_parametres WHERE type = p_type AND pays = p_pays;$a$,
  $b$  IF public.climat_ville_exclue_interne(p_type, p_pays, p_ville) THEN RETURN NULL; END IF; /* climat_ville_exclue_v1 */
  SELECT * INTO c FROM public.climat_parametres WHERE type = p_type AND pays = p_pays;$b$,
  1, 'climat_ville_exclue_v1');

DO $$ BEGIN
  IF to_regprocedure('public.admin_climat_creer(text,text,text,date)') IS NOT NULL THEN
    PERFORM pg_temp.rp_remplacer('public.admin_climat_creer(text,text,text,date)'::regprocedure,
      $a$IF v_id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'ville_sans_zone_inondable'); END IF;$a$,
      $b$IF v_id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', CASE WHEN public.climat_ville_exclue_interne(p_type, p_pays, p_ville)
        THEN 'ville_exclue' ELSE 'ville_sans_zone_inondable' END); END IF; /* climat_ville_exclue_v1 */$b$,
      1, 'climat_ville_exclue_v1');
  END IF;
END $$;

-- Événements déjà planifiés dans une ville désormais exclue, pas encore commencés : annulés.
WITH a AS (
  UPDATE public.climat_evenements e SET annule = true
   WHERE NOT e.annule AND e.debut > now() AND public.climat_ville_exclue_interne(e.type, e.pays, e.ville)
  RETURNING e.pays, e.ville, e.type, e.debut, e.alerte_le)
INSERT INTO public.evenements_globaux (country, city, texte, jour)
SELECT a.pays, a.ville, '⚠️ Prévisions corrigées : l''alerte « ' || lower(public.climat_nom_type_interne(a.type)) || ' » à '
       || public.climat_nom_ville_interne(a.pays, a.ville) || ', ' || public.climat_quand_interne(a.debut) || ', est levée.', NULL
  FROM a WHERE a.alerte_le IS NOT NULL;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.climat_parametres WHERE type IN ('orage', 'blizzard') AND bloque_chantiers)
     OR EXISTS (SELECT 1 FROM public.climat_evenements WHERE NOT annule AND debut > now() AND type = 'blizzard' AND ville <> 'ville_a') THEN
    RAISE EXCEPTION 'climat_chantiers_canicule_crue_blizzard_starovka : contrôle en échec';
  END IF;
END $$;
COMMIT;
