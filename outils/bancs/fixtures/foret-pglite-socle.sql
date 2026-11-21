-- Socle minimal pour éprouver la migration de la forêt de Krasnov dans PGlite (banc local, jamais la production).
SET check_function_bodies = off;
CREATE ROLE anon; CREATE ROLE authenticated;
CREATE SCHEMA IF NOT EXISTS auth;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('test.uid', true), '')::uuid $$;
CREATE TABLE public.personnages (name text PRIMARY KEY, user_id uuid);
CREATE OR REPLACE FUNCTION public.mon_personnage() RETURNS text LANGUAGE sql STABLE AS $$ SELECT name FROM public.personnages WHERE user_id = auth.uid() $$;
CREATE TABLE public.personnages_donnees (name text PRIMARY KEY, country text, current_city text, current_building text, current_room text, pa integer DEFAULT 10);
CREATE TABLE public.groupes_pj_adhesions (membre text PRIMARY KEY, chef text NOT NULL);
CREATE TABLE public.aliments_parametres (cle text PRIMARY KEY, valeur numeric);
CREATE OR REPLACE FUNCTION public.aliments_param_interne(p_cle text, p_defaut numeric) RETURNS numeric LANGUAGE sql STABLE AS $$
  SELECT coalesce((SELECT valeur FROM public.aliments_parametres WHERE cle = p_cle), p_defaut) $$;
CREATE TABLE public.ordres_couts (fn text, pa integer, cost numeric);
CREATE TABLE public.navigation_lieux_regles (pays text, ville text, batiment text, pieces jsonb);
INSERT INTO public.navigation_lieux_regles VALUES ('soviet', 'ville_b', 'zone-production', '["zone_recolte","foret_vue_1","foret_vue_2","foret_vue_3","foret_vue_4"]');
CREATE TABLE public.sovarka_foret_visites (bucheron text PRIMARY KEY, vue integer NOT NULL CHECK (vue BETWEEN 1 AND 4), coupes integer NOT NULL DEFAULT 0, bois integer NOT NULL DEFAULT 0, arrivee timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.sovarka_foret_rencontres (id bigserial PRIMARY KEY, bucheron text NOT NULL, vue integer NOT NULL, creature text NOT NULL, pnj_id text, statut text NOT NULL, cree_le timestamptz DEFAULT now(), clos_le timestamptz);
CREATE TABLE public.sovarka_foret_actes (acteur text NOT NULL, requete uuid NOT NULL, resultat jsonb NOT NULL, cree_le timestamptz DEFAULT now(), PRIMARY KEY (acteur, requete));
CREATE TABLE public.sovarka_foret_perdus (bucheron text PRIMARY KEY, depuis timestamptz NOT NULL DEFAULT now());
-- Comme la navigation réelle : le chef emmène les membres de son groupe présents avec lui.
CREATE OR REPLACE FUNCTION public.navigation_commander_personnage_interne(p_nom text, p_mode text, p_bat text, p_piece text)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE m jsonb;
BEGIN
  IF current_setting('rp.foret_passage', true) IS DISTINCT FROM 'on' THEN RETURN '{"ok":false,"raison":"passage_ferme"}'; END IF;
  UPDATE public.personnages_donnees SET current_building = p_bat, current_room = p_piece
   WHERE name = p_nom OR name IN (SELECT membre FROM public.groupes_pj_adhesions WHERE chef = p_nom);
  SELECT coalesce(jsonb_agg(membre), '[]') INTO m FROM public.groupes_pj_adhesions WHERE chef = p_nom;
  RETURN jsonb_build_object('ok', true, 'membres', m);
END $$;
CREATE OR REPLACE FUNCTION public.sovarka_foret_deplacer_interne(p_nom text, p_piece text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v jsonb;
BEGIN
  PERFORM set_config('rp.foret_passage', 'on', true);
  v := public.navigation_commander_personnage_interne(p_nom, 'piece', 'zone-production', p_piece);
  PERFORM set_config('rp.foret_passage', 'off', true);
  RETURN v;
END $function$;
-- Ancre de la coupe (le reste de la fonction réelle est hors sujet ici).
CREATE OR REPLACE FUNCTION public.sovarka_foret_couper(p_requete uuid) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE v_vue integer := public.sovarka_foret_vue_interne(public.mon_personnage());
BEGIN
  IF coalesce(v_vue, 0) = 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_en_foret_profonde'); END IF;
  RETURN jsonb_build_object('ok', true, 'vue', v_vue);
END $$;
