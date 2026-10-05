-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260929070539
-- Nom original      : pnj_social_relations
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-29 07:05:39 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 24c99ffcd558e528bf9b4eb5223b8c52
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- ===========================================================================
-- SOCLE DES PNJ SOCIAUX — UNE RELATION PAR COUPLE PNJ / JOUEUR
-- 29 septembre 2026
-- ===========================================================================
-- Aucun PNJ du jeu ne se souvenait d'un joueur. `contacts` est le repertoire du
-- JOUEUR -- c'est lui qui se souvient du PNJ, jamais l'inverse -- et l'historique
-- d'une conversation vit en memoire de page, perdu au premier rafraichissement.
--
-- CE QUE CETTE TABLE N'EST PAS. Ce n'est pas une jauge d'affection : rien ici ne
-- monte parce qu'un joueur clique souvent. `familiarite` et `confiance` sont deux
-- notions distinctes et le restent -- la premiere se gagne en se voyant et en se
-- parlant, la seconde n'a AUCUN chemin d'augmentation automatique. Elle existe
-- parce que la suite en aura besoin, et elle reste a zero tant qu'un evenement
-- significatif ne la fera pas bouger.
--
-- AUCUNE MEMOIRE PARTAGEE. Une ligne par couple : ce que Jean-Lou sait d'un joueur
-- est structurellement hors d'atteinte de Marine.
create table if not exists public.pnj_social_relations (
  pnj_id        text        not null,
  joueur        text        not null,
  rencontres    integer     not null default 0,
  conversations integer     not null default 0,
  premiere_le   timestamptz not null default now(),
  derniere_le   timestamptz not null default now(),
  familiarite   integer     not null default 0,
  confiance     integer     not null default 0,
  jalons        jsonb       not null default '{}'::jsonb,
  memoire       jsonb       not null default '{}'::jsonb,
  primary key (pnj_id, joueur)
);

alter table public.pnj_social_relations enable row level security;
revoke all on table public.pnj_social_relations from public, anon, authenticated;
grant select on table public.pnj_social_relations to service_role;

comment on table public.pnj_social_relations is
  'Relation d''un PNJ social a un joueur : rencontres, conversations, familiarite, confiance, jalons deja joues et souvenirs. Une ligne par couple, aucune memoire partagee. Fermee au client : tout passe par les trois RPC.';

-- ---------------------------------------------------------------------------
-- LES REGLES DE JALON — DES DONNEES, PAS DU CODE
-- ---------------------------------------------------------------------------
-- Le serveur ne sait pas qui est Marine ni qui est Jean-Lou. Il sait lire une
-- condition : « ce jalon se joue a partir de la Nieme rencontre, et seulement si
-- le joueur n'a pas encore parle plus de M fois ». Ajouter les sept autres PNJ
-- sociaux prevus sera une ligne de donnees, pas une ligne de code.
create table if not exists public.pnj_social_jalons_regles (
  pnj_id            text    not null,
  jalon             text    not null,
  min_rencontres    integer not null default 1,
  max_conversations integer,          -- NULL = sans condition sur les conversations
  rang              integer not null default 0,
  primary key (pnj_id, jalon)
);

alter table public.pnj_social_jalons_regles enable row level security;
revoke all on table public.pnj_social_jalons_regles from public, anon, authenticated;
grant select on table public.pnj_social_jalons_regles to service_role;

comment on table public.pnj_social_jalons_regles is
  'Quand un PNJ social joue une intervention automatique. Le serveur decide du QUAND, le client sait le QUOI : seul l''identifiant du jalon remonte, jamais son texte.';

-- MARINE accueille des la premiere visite : c'est son metier, elle sert les clients.
-- JEAN-LOU n'aborde personne. A la deuxieme visite seulement, et seulement si on ne
-- lui a encore jamais parle, il lance sa phrase. Si le joueur l'a aborde des la
-- premiere fois, `max_conversations = 0` l'en empeche : il le reconnait deja.
insert into public.pnj_social_jalons_regles (pnj_id, jalon, min_rencontres, max_conversations, rang) values
  ('marine_leroux',  'accueil_premiere_visite',   1, null, 1),
  ('jean_lou_demer', 'abordage_deuxieme_visite',  2, 0,    1)
on conflict (pnj_id, jalon) do nothing;

-- ---------------------------------------------------------------------------
-- ENTRER DANS LE LIEU D'UN PNJ SOCIAL
-- ---------------------------------------------------------------------------
-- Note la visite et rend, dans le meme mouvement, le jalon a jouer. Le jalon est
-- MARQUE AVANT que le client ne l'affiche : c'est le patron de la quete d'accueil,
-- et c'est ce qui garantit qu'un rafraichissement de page ne le rejoue jamais.
create or replace function public.pnj_social_entrer(p_pnj_id text)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_moi text; r record; v_jalon text; v_genre text; v_nom text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(p_pnj_id), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pnj_absent'); END IF;
  -- Un PNJ sans regle de jalon n'est pas un PNJ social : on ne cree aucune ligne
  -- pour les 175 autres, qui n'ont aucune memoire a tenir.
  IF NOT EXISTS (SELECT 1 FROM public.pnj_social_jalons_regles g WHERE g.pnj_id = p_pnj_id) THEN
    RETURN jsonb_build_object('ok', true, 'social', false); END IF;

  INSERT INTO public.pnj_social_relations (pnj_id, joueur, rencontres)
       VALUES (p_pnj_id, v_moi, 1)
  ON CONFLICT (pnj_id, joueur) DO UPDATE
     SET rencontres = public.pnj_social_relations.rencontres + 1,
         derniere_le = now();

  SELECT * INTO r FROM public.pnj_social_relations
   WHERE pnj_id = p_pnj_id AND joueur = v_moi;

  -- Le premier jalon eligible, non deja joue. Ordre stable par `rang`.
  SELECT g.jalon INTO v_jalon
    FROM public.pnj_social_jalons_regles g
   WHERE g.pnj_id = p_pnj_id
     AND r.rencontres >= g.min_rencontres
     AND (g.max_conversations IS NULL OR r.conversations <= g.max_conversations)
     AND coalesce((r.jalons ->> g.jalon)::boolean, false) = false
   ORDER BY g.rang, g.jalon
   LIMIT 1;

  IF v_jalon IS NOT NULL THEN
    -- MARQUE AVANT D'ETRE JOUE. Un F5 entre les deux ne le rejouera pas.
    UPDATE public.pnj_social_relations
       SET jalons = jsonb_set(jalons, ARRAY[v_jalon], 'true'::jsonb, true)
     WHERE pnj_id = p_pnj_id AND joueur = v_moi;
  END IF;

  -- La memoire de V1 ne contient que des faits CERTAINS, connus du jeu : le nom du
  -- joueur et son genre s'il est renseigne. Aucun contenu de conversation, aucun
  -- resume, aucune extraction.
  SELECT d.name, nullif(btrim(coalesce(d.stats->>'genre', '')), '')
    INTO v_nom, v_genre
    FROM public.personnages_donnees d WHERE d.name = v_moi;
  UPDATE public.pnj_social_relations
     SET memoire = memoire || jsonb_strip_nulls(jsonb_build_object('nom', v_nom, 'genre', v_genre))
   WHERE pnj_id = p_pnj_id AND joueur = v_moi;

  RETURN jsonb_build_object('ok', true, 'social', true,
    'rencontres', r.rencontres, 'conversations', r.conversations,
    'familiarite', r.familiarite, 'jalon', v_jalon);
END; $fn$;

comment on function public.pnj_social_entrer(text) is
  'Note l''arrivee d''un joueur chez un PNJ social et rend le jalon a jouer, deja marque. Sans effet pour un PNJ qui n''a aucune regle de jalon : aucune ligne n''est creee.';

revoke all on function public.pnj_social_entrer(text) from public, anon, authenticated;
grant execute on function public.pnj_social_entrer(text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- NOTER UN EVENEMENT RELATIONNEL
-- ---------------------------------------------------------------------------
-- Un seul evenement en V1 : une conversation reellement engagee. Elle fait monter
-- la FAMILIARITE, par paliers bornes -- jamais la confiance, qui n'a aucun chemin
-- automatique et qu'aucune quantite de clics ne peut gagner.
create or replace function public.pnj_social_noter(p_pnj_id text, p_evenement text)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_moi text; v_fam integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_evenement IS DISTINCT FROM 'conversation' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'evenement_inconnu'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.pnj_social_jalons_regles g WHERE g.pnj_id = p_pnj_id) THEN
    RETURN jsonb_build_object('ok', true, 'social', false); END IF;

  INSERT INTO public.pnj_social_relations (pnj_id, joueur, rencontres, conversations, familiarite)
       VALUES (p_pnj_id, v_moi, 1, 1, 1)
  ON CONFLICT (pnj_id, joueur) DO UPDATE
     SET conversations = public.pnj_social_relations.conversations + 1,
         -- FAMILIARITE BORNEE A 5. Elle regle un registre de langage, pas un score :
         -- au-dela, se parler davantage ne change plus rien.
         familiarite   = LEAST(5, public.pnj_social_relations.familiarite + 1),
         derniere_le   = now();

  SELECT familiarite INTO v_fam FROM public.pnj_social_relations
   WHERE pnj_id = p_pnj_id AND joueur = v_moi;
  RETURN jsonb_build_object('ok', true, 'social', true, 'familiarite', v_fam);
END; $fn$;

comment on function public.pnj_social_noter(text, text) is
  'Enregistre une conversation reellement engagee avec un PNJ social. Fait monter la familiarite par paliers bornes ; ne touche JAMAIS la confiance, qui n''a aucun chemin d''augmentation automatique en V1.';

revoke all on function public.pnj_social_noter(text, text) from public, anon, authenticated;
grant execute on function public.pnj_social_noter(text, text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- LE CONTEXTE LU PAR LE PROMPT
-- ---------------------------------------------------------------------------
-- Appelee par api/chat.js SOUS LE JETON DU JOUEUR, jamais sous une cle de service :
-- elle ne rend que la relation du personnage connecte. C'est ce qui empeche un
-- navigateur de s'inventer une familiarite avec Jean-Lou.
create or replace function public.pnj_social_contexte(p_pnj_id text)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_moi text; r record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO r FROM public.pnj_social_relations
   WHERE pnj_id = p_pnj_id AND joueur = v_moi;
  IF NOT FOUND THEN
    -- Pas de relation : soit ce PNJ n'en tient pas, soit ils ne se sont jamais vus.
    -- Dans les deux cas le prompt reste celui d'avant.
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_relation'); END IF;

  RETURN jsonb_build_object('ok', true,
    'rencontres', r.rencontres, 'conversations', r.conversations,
    'familiarite', r.familiarite, 'confiance', r.confiance,
    'memoire', r.memoire);
END; $fn$;

comment on function public.pnj_social_contexte(text) is
  'Relation du joueur connecte a un PNJ social, pour injection dans le prompt serveur. Lecture seule, sous le jeton du joueur : un client ne peut ni la fournir ni la falsifier.';

revoke all on function public.pnj_social_contexte(text) from public, anon, authenticated;
grant execute on function public.pnj_social_contexte(text) to authenticated, service_role;