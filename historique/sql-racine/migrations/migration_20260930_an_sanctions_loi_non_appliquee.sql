-- ===========================================================================
-- LE GOUVERNEMENT REPOND DE CE QU'IL N'APPLIQUE PAS (30 septembre 2026)
-- Migration Supabase appliquee : 20260930165140 an_sanctions_loi_non_appliquee
-- ---------------------------------------------------------------------------
-- Une loi adoptee mais laissee sans application coute de la popularite a
-- l'executif. Le chrono demarre a l'ADOPTION et APPARTIENT A LA LOI : aucun
-- changement de ministre, de Premier ministre, de President ni de gouvernement
-- ne le remet a zero. Le nouveau titulaire herite de la situation.
--     H+36  : -20 POP
--     H+60, H+84, H+108...  : -10 POP toutes les 24 heures
-- La sanction frappe les personnes qui occupent les postes AU MOMENT DU TICK,
-- jamais celles qui etaient en fonction lors du vote. Aucune anciennete n'est
-- recalculee.
--
-- POP : on reutilise la primitive canonique personnage_ajuster_pop_inf, la seule
-- qui applique un DELTA sous verrou et respecte les bornes [0,100]. Aucun second
-- systeme de popularite n'est cree, et aucun UPDATE direct de `resources` n'est
-- fait -- un tel UPDATE ecrirait une valeur absolue et ecraserait les effets
-- concurrents (le declencheur personnages_fusionner_pop ne fusionne pas un appel
-- serveur).
-- ===========================================================================

-- 1. LE REGISTRE DES PALIERS DEJA SANCTIONNES -- L'IDEMPOTENCE EST LA CLE PRIMAIRE
create table if not exists public.assemblee_sanctions_paliers (
  id              text primary key,     -- '<proposition_id>:<palier>' : LE verrou
  proposition_id  text        not null,
  country         text        not null,
  palier          integer     not null check (palier >= 1),
  echeance_ts     timestamptz not null, -- l'instant theorique du palier
  applique_ts     timestamptz not null default now(),
  pop_delta       integer     not null,
  titulaires      jsonb       not null default '[]'::jsonb
);

comment on table public.assemblee_sanctions_paliers is
  'Registre durable des paliers de sanction DEJA debites pour une loi non appliquee. La cle primaire <proposition_id>:<palier> est l''idempotence : un rejeu, deux crons concurrents ou un appel manuel ne peuvent pas debiter deux fois le meme palier. titulaires garde la trace nominative des personnages sanctionnes a cet instant.';

create index if not exists assemblee_sanctions_paliers_prop_idx
  on public.assemblee_sanctions_paliers (proposition_id, palier);

alter table public.assemblee_sanctions_paliers enable row level security;
revoke all on table public.assemblee_sanctions_paliers from public, anon, authenticated;
grant select on table public.assemblee_sanctions_paliers to service_role;

-- 2. LE CALENDRIER DES PALIERS -- ARITHMETIQUE PURE, ECRITE UNE FOIS
create or replace function public.assemblee_palier_atteint(
  p_adoptee_ts timestamptz, p_instant timestamptz)
returns integer
language sql
immutable
set search_path to 'public', 'pg_temp'
as $fn$
  SELECT CASE
    WHEN p_adoptee_ts IS NULL OR p_instant IS NULL THEN 0
    WHEN p_instant < p_adoptee_ts + interval '36 hours' THEN 0
    ELSE 1 + floor(
      extract(epoch FROM (p_instant - (p_adoptee_ts + interval '36 hours'))) / 86400
    )::integer
  END;
$fn$;

comment on function public.assemblee_palier_atteint(timestamptz, timestamptz) is
  'Numero du dernier palier de sanction atteint a cet instant : 0 avant H+36, 1 a H+36, 2 a H+60, 3 a H+84, puis un de plus toutes les 24 heures. Arithmetique pure, sans effet de bord.';

create or replace function public.assemblee_echeance_palier(
  p_adoptee_ts timestamptz, p_palier integer)
returns timestamptz
language sql
immutable
set search_path to 'public', 'pg_temp'
as $fn$
  SELECT p_adoptee_ts + interval '36 hours' + ((p_palier - 1) * interval '24 hours');
$fn$;

create or replace function public.assemblee_pop_du_palier(p_palier integer)
returns integer
language sql
immutable
set search_path to 'public', 'pg_temp'
as $fn$
  SELECT CASE WHEN p_palier <= 1 THEN -20 ELSE -10 END;
$fn$;

comment on function public.assemblee_pop_du_palier(integer) is
  'Perte de popularite d''un palier : -20 au premier (H+36), -10 a chacun des suivants. Bareme de l''arbitrage du 30 septembre 2026.';

revoke all on function public.assemblee_palier_atteint(timestamptz, timestamptz) from public, anon;
revoke all on function public.assemblee_echeance_palier(timestamptz, integer) from public, anon;
revoke all on function public.assemblee_pop_du_palier(integer) from public, anon;
grant execute on function public.assemblee_palier_atteint(timestamptz, timestamptz) to authenticated, service_role;
grant execute on function public.assemblee_echeance_palier(timestamptz, integer) to authenticated, service_role;
grant execute on function public.assemblee_pop_du_palier(integer) to authenticated, service_role;

-- 3. QUI COMPOSE LE GOUVERNEMENT A CET INSTANT
-- Lu au moment du tick, jamais memorise : c'est exactement la regle de
-- l'arbitrage. Le President, le Premier ministre et TOUS les ministres, y compris
-- un ministere cree en cours de partie (convention d'identifiant « min_ »).
create or replace function public.assemblee_gouvernement_actuel(p_country text)
returns table(nom text, poste_id text)
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
  SELECT pd.name, pd.poste ->> 'id'
    FROM public.personnages_donnees pd
   WHERE pd.country = p_country
     AND pd.poste IS NOT NULL
     AND (pd.poste ->> 'id' IN ('president', 'pm') OR pd.poste ->> 'id' LIKE 'min\_%')
   ORDER BY pd.poste ->> 'id', pd.name;
$fn$;

comment on function public.assemblee_gouvernement_actuel(text) is
  'Les titulaires du President, du Premier ministre et de tous les ministeres A CET INSTANT. La convention d''identifiant « min_ » couvre aussi un ministere cree en cours de partie. Sert aux sanctions : elles frappent ceux qui occupent les postes au moment du tick, jamais ceux qui etaient la au vote.';

revoke all on function public.assemblee_gouvernement_actuel(text) from public, anon;
grant execute on function public.assemblee_gouvernement_actuel(text) to authenticated, service_role;

-- 4. LA PASSE DE SANCTION -- IDEMPOTENTE PALIER PAR PALIER
create or replace function public.assemblee_sanctionner_lois_non_appliquees(
  p_country text default 'republic')
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE
  v_loi     record;
  v_palier  integer;
  v_n       integer;
  v_id      text;
  v_delta   integer;
  v_membre  record;
  v_noms    jsonb;
  v_res     jsonb := '[]'::jsonb;
  v_faits   integer := 0;
BEGIN
  -- Reservee au serveur : un joueur ne declenche pas une sanction gouvernementale.
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur');
  END IF;

  FOR v_loi IN
    SELECT p.id, p.titre, p.type, p.adoptee_ts
      FROM public.assemblee_propositions p
     WHERE p.country = p_country
       AND p.statut = 'adoptee'
       AND p.appliquee_ts IS NULL
       AND public.assemblee_exige_application(p.type)
       AND p.adoptee_ts IS NOT NULL
       AND now() >= public.assemblee_echeance_application(p.adoptee_ts)
     ORDER BY p.adoptee_ts
  LOOP
    v_palier := public.assemblee_palier_atteint(v_loi.adoptee_ts, now());

    -- RATTRAPAGE. Si la passe n'a pas tourne pendant deux jours, les paliers
    -- manques sont debites l'un apres l'autre -- jamais fusionnes, jamais perdus.
    FOR v_n IN 1 .. v_palier LOOP
      v_id := v_loi.id || ':' || v_n;

      -- L'INSERTION EST LA GARDE. Un rejeu, deux crons concurrents ou un appel
      -- manuel retombent ici : le second n'insere rien et ne debite rien. Un
      -- concurrent attend la fin de la premiere transaction sur cette ligne.
      INSERT INTO public.assemblee_sanctions_paliers
        (id, proposition_id, country, palier, echeance_ts, pop_delta, titulaires)
      VALUES (v_id, v_loi.id, p_country, v_n,
              public.assemblee_echeance_palier(v_loi.adoptee_ts, v_n),
              public.assemblee_pop_du_palier(v_n), '[]'::jsonb)
      ON CONFLICT (id) DO NOTHING;
      IF NOT FOUND THEN
        CONTINUE;   -- palier deja sanctionne : on ne redebite rien
      END IF;

      v_delta := public.assemblee_pop_du_palier(v_n);
      v_noms  := '[]'::jsonb;

      -- LES TITULAIRES DU MOMENT. Relus a chaque palier : un gouvernement nomme
      -- une heure avant le tick prend la sanction, c'est la regle.
      FOR v_membre IN SELECT * FROM public.assemblee_gouvernement_actuel(p_country) LOOP
        -- Primitive canonique : delta, sous verrou, bornes [0,100] respectees.
        PERFORM public.personnage_ajuster_pop_inf(
          NULL, v_membre.nom, v_delta, NULL, 'loi_non_appliquee');
        v_noms := v_noms || jsonb_build_array(
          jsonb_build_object('nom', v_membre.nom, 'poste', v_membre.poste_id));
      END LOOP;

      UPDATE public.assemblee_sanctions_paliers SET titulaires = v_noms WHERE id = v_id;
      v_faits := v_faits + 1;
      v_res := v_res || jsonb_build_array(jsonb_build_object(
        'loi', v_loi.id, 'titre', v_loi.titre, 'palier', v_n,
        'pop', v_delta, 'sanctionnes', jsonb_array_length(v_noms)));
    END LOOP;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'paliers_appliques', v_faits, 'detail', v_res);
END $fn$;

comment on function public.assemblee_sanctionner_lois_non_appliquees(text) is
  'Passe de sanction des lois adoptees et non mises en application. -20 POP au palier H+36, -10 a chaque palier suivant (toutes les 24 h). Strictement idempotente : la cle primaire <loi>:<palier> de assemblee_sanctions_paliers interdit tout second debit, quel que soit le rejeu, la concurrence ou l''appel manuel. Rattrape les paliers manques un par un. Frappe les titulaires du President, du Premier ministre et de tous les ministeres A L''INSTANT DU TICK. Utilise la primitive canonique personnage_ajuster_pop_inf (delta, verrou, bornes). Reservee au serveur.';

revoke all on function public.assemblee_sanctionner_lois_non_appliquees(text) from public, anon, authenticated;
grant execute on function public.assemblee_sanctionner_lois_non_appliquees(text) to service_role;

-- 5. GARDES
DO $garde$
DECLARE n integer;
BEGIN
  -- a) Le bareme de l'arbitrage, verifie par l'arithmetique.
  IF public.assemblee_pop_du_palier(1) <> -20 THEN RAISE EXCEPTION 'palier 1 ne vaut pas -20'; END IF;
  IF public.assemblee_pop_du_palier(2) <> -10 THEN RAISE EXCEPTION 'palier 2 ne vaut pas -10'; END IF;
  IF public.assemblee_pop_du_palier(9) <> -10 THEN RAISE EXCEPTION 'palier 9 ne vaut pas -10'; END IF;

  -- b) Le calendrier : rien avant H+36, puis un palier toutes les 24 h.
  IF public.assemblee_palier_atteint(now(), now() + interval '35 hours') <> 0 THEN
    RAISE EXCEPTION 'un palier tombe avant H+36'; END IF;
  IF public.assemblee_palier_atteint(now(), now() + interval '36 hours') <> 1 THEN
    RAISE EXCEPTION 'H+36 ne donne pas le palier 1'; END IF;
  IF public.assemblee_palier_atteint(now(), now() + interval '59 hours') <> 1 THEN
    RAISE EXCEPTION 'H+59 ne doit pas encore donner le palier 2'; END IF;
  IF public.assemblee_palier_atteint(now(), now() + interval '60 hours') <> 2 THEN
    RAISE EXCEPTION 'H+60 ne donne pas le palier 2'; END IF;
  IF public.assemblee_palier_atteint(now(), now() + interval '84 hours') <> 3 THEN
    RAISE EXCEPTION 'H+84 ne donne pas le palier 3'; END IF;
  IF public.assemblee_palier_atteint(now(), now() + interval '108 hours') <> 4 THEN
    RAISE EXCEPTION 'H+108 ne donne pas le palier 4'; END IF;

  -- c) Le registre est ferme au joueur : il porte des debits.
  SELECT count(*) INTO n FROM information_schema.role_table_grants
   WHERE table_schema='public' AND table_name='assemblee_sanctions_paliers'
     AND grantee IN ('anon','authenticated');
  IF n <> 0 THEN RAISE EXCEPTION 'le registre des sanctions est accessible au client'; END IF;

  -- d) La passe est reservee au serveur.
  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname='public' AND p.proname='assemblee_sanctionner_lois_non_appliquees'
     AND has_function_privilege('authenticated', p.oid, 'execute') = false
     AND has_function_privilege('anon', p.oid, 'execute') = false
     AND has_function_privilege('service_role', p.oid, 'execute') = true;
  IF n <> 1 THEN RAISE EXCEPTION 'droits inattendus sur la passe de sanction'; END IF;

  -- e) On reutilise bien la primitive canonique de POP, et on n'ecrit pas
  --    `resources` en direct.
  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname='public' AND p.proname='assemblee_sanctionner_lois_non_appliquees'
     AND pg_get_functiondef(p.oid) LIKE '%personnage_ajuster_pop_inf%'
     AND pg_get_functiondef(p.oid) NOT LIKE '%UPDATE public.personnages_donnees%';
  IF n <> 1 THEN RAISE EXCEPTION 'la passe n''utilise pas la primitive canonique de POP'; END IF;

  SELECT count(*) INTO n FROM public.assemblee_propositions WHERE id LIKE 'zzbanc-%';
  IF n <> 0 THEN RAISE EXCEPTION '% loi(s) de test en base', n; END IF;
END $garde$;
