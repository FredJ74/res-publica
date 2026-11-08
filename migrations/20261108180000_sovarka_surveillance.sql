-- Sovarka : « Placer sous surveillance » au bureau du ministre de la Sécurité du Peuple
-- (décisions de Fred, 08/11/2026 ; GAME-DESIGN-NOVOMIRSK.md, « Surveillance »).
--  * 4 jours, 2 PA au ministre, 150 PSK sur la caisse du ministère (soviet_gouvernement-min_int).
--  * Rapport garanti chaque nuit : tous les déplacements de la cible et les PJ croisés dans chaque lieu ;
--    hors de Sovarka, « hors du territoire ».
--  * Risque de découverte chaque nuit : 10 % + 1,5 x (PER - 10) + 0,5 x (INT - 10) - (ISN de la ville - 30) / 5,
--    borné 2-40 % ; la cible reçoit un courrier anonyme, la surveillance continue.
--  * Toute cible (ministre, Président compris) ; 3 surveillances simultanées, une seule par cible.
-- Le moteur réutilise le registre des déplacements de la filature (historique_deplacements).

CREATE TABLE IF NOT EXISTS public.sovarka_surveillances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), ts timestamptz NOT NULL DEFAULT now(),
  ministre text NOT NULL, cible text NOT NULL, rapports_restants integer NOT NULL DEFAULT 4,
  decouverte boolean NOT NULL DEFAULT false,
  statut text NOT NULL DEFAULT 'active' CHECK (statut IN ('active','terminee')));
CREATE UNIQUE INDEX IF NOT EXISTS sovarka_surveillances_une_par_cible
  ON public.sovarka_surveillances (cible) WHERE statut = 'active';
CREATE TABLE IF NOT EXISTS public.sovarka_surveillance_rapports (
  id bigserial PRIMARY KEY, surveillance uuid NOT NULL REFERENCES public.sovarka_surveillances(id) ON DELETE CASCADE,
  jour date NOT NULL, depuis timestamptz NOT NULL, jusqua timestamptz NOT NULL,
  deplacements jsonb NOT NULL, chance numeric, decouverte boolean NOT NULL DEFAULT false,
  ts timestamptz NOT NULL DEFAULT now(), UNIQUE (surveillance, jour));
ALTER TABLE public.sovarka_surveillances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sovarka_surveillance_rapports ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_surveillances, public.sovarka_surveillance_rapports FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.sovarka_surveillance_rapports_id_seq FROM PUBLIC, anon, authenticated;

INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT 'sovarka_surveiller', 2, 0 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'sovarka_surveiller');
INSERT INTO public.actes_nocturnes_mecanismes (mecanisme, sujet_singleton, note)
SELECT 'sovarka_surveillance_rapport', false, 'Rapport nocturne d''une surveillance de Sovarka ; un rejeu renverrait le rapport, retirerait un jour et retirerait le risque de découverte.'
 WHERE NOT EXISTS (SELECT 1 FROM public.actes_nocturnes_mecanismes WHERE mecanisme = 'sovarka_surveillance_rapport');

-- Moteur : déplacements de la cible entre deux instants, avec les PJ croisés dans chaque lieu.
CREATE OR REPLACE FUNCTION public.sovarka_surveillance_releve_interne(p_cible text, p_depuis timestamptz, p_jusqua timestamptz)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  WITH sejours AS (
    SELECT h.country, h.city, h.building_id, h.room_id, h.created_at AS debut,
           lead(h.created_at) OVER (ORDER BY h.created_at, h.id) AS fin
      FROM public.historique_deplacements h
     WHERE h.name = p_cible AND h.created_at < p_jusqua
       AND h.created_at >= coalesce((SELECT max(x.created_at) FROM public.historique_deplacements x
                                      WHERE x.name = p_cible AND x.created_at <= p_depuis), p_depuis)
  ), bornes AS (
    SELECT country, city, building_id, room_id, greatest(debut, p_depuis) AS debut, least(coalesce(fin, p_jusqua), p_jusqua) AS fin
      FROM sejours WHERE coalesce(fin, p_jusqua) > p_depuis
  ), autres AS (
    SELECT h.name, h.country, h.city, h.building_id, h.room_id, h.created_at AS debut,
           coalesce(lead(h.created_at) OVER (PARTITION BY h.name ORDER BY h.created_at, h.id), p_jusqua) AS fin
      FROM public.historique_deplacements h
     WHERE h.name <> p_cible AND h.country = 'soviet'
       AND h.created_at < p_jusqua AND h.created_at > p_depuis - interval '2 days'
  )
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'debut', b.debut, 'fin', b.fin,
           'hors_territoire', b.country IS DISTINCT FROM 'soviet',
           'ville', CASE WHEN b.country = 'soviet' THEN b.city END,
           'batiment', CASE WHEN b.country = 'soviet' THEN b.building_id END,
           'piece', CASE WHEN b.country = 'soviet' THEN b.room_id END,
           'croises', CASE WHEN b.country = 'soviet' THEN (
             SELECT coalesce(jsonb_agg(DISTINCT a.name), '[]'::jsonb) FROM autres a
              WHERE a.city = b.city AND a.building_id IS NOT DISTINCT FROM b.building_id
                AND a.room_id IS NOT DISTINCT FROM b.room_id AND a.debut < b.fin AND a.fin > b.debut)
             ELSE '[]'::jsonb END) ORDER BY b.debut), '[]'::jsonb)
    FROM bornes b WHERE b.fin > b.debut $$;

-- Chance de découverte d'une nuit, en pour cent (Fred : perception, intelligence, sécurité de la ville).
CREATE OR REPLACE FUNCTION public.sovarka_surveillance_chance_interne(p_cible text)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN d.country IS DISTINCT FROM 'soviet' THEN 0 ELSE
    least(40, greatest(2, 10 + 1.5 * (coalesce((d.stats->>'PER')::numeric, 10) - 10)
                          + 0.5 * (coalesce((d.stats->>'INT')::numeric, 10) - 10)
                          - (coalesce((SELECT nullif(i.data->>'isn', '')::numeric FROM public.indices_villes i
                                        WHERE i.id = d.country || '_' || d.current_city), 30) - 30) / 5)) END
    FROM public.personnages_donnees d WHERE d.name = p_cible $$;

-- Libellé d'un lieu pour le courrier (le bureau du ministre affiche les noms du jeu).
CREATE OR REPLACE FUNCTION public.sovarka_surveillance_lieu_interne(p jsonb)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN (p->>'hors_territoire')::boolean THEN 'hors du territoire' ELSE
    CASE p->>'ville' WHEN 'capitale' THEN 'Novomirsk' WHEN 'ville_a' THEN 'Starovka' WHEN 'ville_b' THEN 'Krasnov' ELSE coalesce(p->>'ville', '?') END
    || ', ' || CASE WHEN coalesce(p->>'batiment', '') LIKE 'rue%' OR coalesce(p->>'batiment', '') = '' THEN 'dans la rue'
                    ELSE initcap(replace(replace(p->>'batiment', '-', ' '), '_', ' '))
                         || coalesce(' (' || replace(replace(p->>'piece', '-', ' '), '_', ' ') || ')', '') END END $$;

REVOKE ALL ON FUNCTION public.sovarka_surveillance_releve_interne(text, timestamptz, timestamptz),
  public.sovarka_surveillance_chance_interne(text), public.sovarka_surveillance_lieu_interne(jsonb)
  FROM PUBLIC, anon, authenticated;
