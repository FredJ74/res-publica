-- ===========================================================================
-- SOCLE DES PNJ SOCIAUX -- TRANSCRIPTION RETROSPECTIVE (29 septembre 2026)
-- Migration Supabase appliquee : 20260929070539 pnj_social_relations
-- ---------------------------------------------------------------------------
-- POURQUOI CE FICHIER EXISTE APRES COUP. Le socle social a ete livre le
-- 29 septembre 2026 (commit c91054d) : les deux tables, les trois RPC, la RLS et
-- les droits sont en production depuis. Mais AUCUN fichier du depot ne les
-- creait -- la table `pnj_social_jalons_regles` n'etait meme nommee nulle part
-- dans le code, alors que c'est ELLE qui decide qu'un PNJ est social.
--
-- Un socle dont le SQL n'existe qu'en base est un socle inverifiable : on ne
-- peut ni le relire, ni le rejouer sur un autre environnement, ni constater
-- qu'il n'a pas derive. L'audit du 1er octobre 2026 l'a releve, et le chantier
-- des escorts s'appuyant dessus, la dette est soldee ici.
--
-- CE FICHIER EST UNE TRANSCRIPTION FIDELE DE LA PRODUCTION, PAS UNE REECRITURE.
-- Les corps des trois fonctions sont repris a l'identique de pg_get_functiondef.
-- Il est idempotent et n'a PAS ete rejoue : sa fidelite a ete verifiee en
-- comparant l'empreinte du code de chaque fonction avec celle de la base.
-- Le rejouer ne changerait donc rien -- c'est precisement ce qu'on veut d'une
-- transcription.
--
-- CE QUE LE SOCLE FAIT, EN UNE PHRASE. Un PNJ social parle comme les 175 autres
-- -- meme RPC, meme prompt serveur -- mais le serveur sait combien de fois il a
-- vu ce joueur, et il le lui dit. Le reste en decoule.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. LA RELATION D'UN PNJ A UN JOUEUR
-- ---------------------------------------------------------------------------
-- Une ligne par couple (PNJ, joueur). AUCUNE memoire partagee entre joueurs :
-- c'est ce qui permet a plusieurs joueurs d'entretenir chacun leur relation avec
-- le meme personnage, sans exclusivite ni collision.
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

comment on table public.pnj_social_relations is
  'Relation d''un PNJ social a un joueur : rencontres, conversations, familiarite, confiance, jalons deja joues et souvenirs. Une ligne par couple, aucune memoire partagee. Fermee au client : tout passe par les trois RPC.';

-- ---------------------------------------------------------------------------
-- 2. CE QUI FAIT QU'UN PNJ EST SOCIAL
-- ---------------------------------------------------------------------------
-- C'EST LE POINT LE PLUS IMPORTANT DU SOCLE, et le moins visible : un PNJ est
-- social SI ET SEULEMENT SI il possede au moins une ligne ici. Les trois RPC
-- interrogent cette table avant toute ecriture et repondent `social: false` pour
-- tous les autres. Enroler un nouveau PNJ social est donc une operation de
-- DONNEES : aucune ligne de serveur a ecrire.
create table if not exists public.pnj_social_jalons_regles (
  pnj_id            text    not null,
  jalon             text    not null,
  min_rencontres    integer not null default 1,
  max_conversations integer,
  rang              integer not null default 0,
  primary key (pnj_id, jalon)
);

comment on table public.pnj_social_jalons_regles is
  'Quand un PNJ social joue une intervention automatique. Le serveur decide du QUAND, le client sait le QUOI : seul l''identifiant du jalon remonte, jamais son texte.';

-- Les deux PNJ sociaux de Port-Sainte-Marie, livres le 29 septembre 2026.
-- `max_conversations = 0` pour Jean-Lou : il n'aborde que quelqu'un a qui il n'a
-- jamais parle -- sans quoi il saluerait comme un inconnu un habitue du bar.
insert into public.pnj_social_jalons_regles (pnj_id, jalon, min_rencontres, max_conversations, rang)
values ('jean_lou_demer', 'abordage_deuxieme_visite', 2, 0, 0),
       ('marine_leroux',  'accueil_premiere_visite',  1, 0, 0)
on conflict (pnj_id, jalon) do nothing;

-- ---------------------------------------------------------------------------
-- 3. FERMETURE DES DEUX TABLES
-- ---------------------------------------------------------------------------
-- RLS active et AUCUNE policy : personne ne lit ni n'ecrit ces tables en direct.
-- Les trois RPC sont SECURITY DEFINER et resolvent l'identite par
-- mon_personnage() ; un client ne peut donc ni lire la relation d'autrui, ni
-- s'inventer une familiarite.
alter table public.pnj_social_relations     enable row level security;
alter table public.pnj_social_jalons_regles enable row level security;

revoke all on table public.pnj_social_relations     from public, anon, authenticated;
revoke all on table public.pnj_social_jalons_regles from public, anon, authenticated;
grant all on table public.pnj_social_relations     to service_role;
grant all on table public.pnj_social_jalons_regles to service_role;

-- ---------------------------------------------------------------------------
-- 4. ENTREE CHEZ UN PNJ SOCIAL
-- ---------------------------------------------------------------------------
create or replace function public.pnj_social_entrer(p_pnj_id text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
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
END; $function$;

comment on function public.pnj_social_entrer(text) is
  'Note l''arrivee d''un joueur chez un PNJ social et rend le jalon a jouer, deja marque. Sans effet pour un PNJ qui n''a aucune regle de jalon : aucune ligne n''est creee.';

-- ---------------------------------------------------------------------------
-- 5. UNE CONVERSATION REELLEMENT ENGAGEE
-- ---------------------------------------------------------------------------
create or replace function public.pnj_social_noter(p_pnj_id text, p_evenement text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
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
END; $function$;

comment on function public.pnj_social_noter(text, text) is
  'Enregistre une conversation reellement engagee avec un PNJ social. Fait monter la familiarite par paliers bornes ; ne touche JAMAIS la confiance, qui n''a aucun chemin d''augmentation automatique en V1.';

-- ---------------------------------------------------------------------------
-- 6. LA RELATION, LUE POUR LE PROMPT SERVEUR
-- ---------------------------------------------------------------------------
create or replace function public.pnj_social_contexte(p_pnj_id text)
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to 'public', 'pg_temp'
as $function$
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
END; $function$;

comment on function public.pnj_social_contexte(text) is
  'Relation du joueur connecte a un PNJ social, pour injection dans le prompt serveur. Lecture seule, sous le jeton du joueur : un client ne peut ni la fournir ni la falsifier.';

-- ---------------------------------------------------------------------------
-- 7. DROITS DES TROIS RPC
-- ---------------------------------------------------------------------------
revoke all on function public.pnj_social_entrer(text)         from public, anon;
revoke all on function public.pnj_social_noter(text, text)    from public, anon;
revoke all on function public.pnj_social_contexte(text)       from public, anon;
grant execute on function public.pnj_social_entrer(text)      to authenticated, service_role;
grant execute on function public.pnj_social_noter(text, text) to authenticated, service_role;
grant execute on function public.pnj_social_contexte(text)    to authenticated, service_role;
