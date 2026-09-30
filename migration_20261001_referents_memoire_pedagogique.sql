-- ===========================================================================
-- LA MEMOIRE D'UN REFERENT EST PEDAGOGIQUE (1er octobre 2026)
-- ---------------------------------------------------------------------------
-- LA DISTINCTION QUE CE FICHIER REND STRUCTURELLE. Un PNJ social se souvient de
-- QUELQU'UN : il compte les rencontres, sa familiarite monte, il finit par
-- tutoyer. Un referent, lui, se souvient de CE QU'IL A EXPLIQUE, pour ne pas
-- reprendre au debut -- et de rien d'autre. Il ne se lie pas, ce n'est pas son
-- role.
--
-- On n'a donc PAS reutilise pnj_social_relations. Y loger les referents aurait
-- mele deux natures : leurs consultations auraient fait monter une familiarite
-- qui n'a aucun sens pour eux, et la difference se serait effacee en un lot. Une
-- table separee la maintient sans qu'on ait a y penser.
--
-- CE QUI EST MESURE, ET CE QUI NE L'EST PAS. V1 compte les consultations -- un
-- fait certain, connu du jeu. La colonne `sujets` existe pour le jour ou l'on
-- saura dire de QUOI on a parle, mais elle reste vide : deduire un sujet d'un
-- texte libre demanderait au modele de l'annoncer, ce qui changerait le contrat
-- de /api/chat pour les 180 PNJ. On ne devine pas, on attend un signal fiable.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. QUI EST REFERENT -- liste fermee
-- ---------------------------------------------------------------------------
-- Le serveur doit pouvoir refuser d'ouvrir une memoire pour un PNJ quelconque :
-- sans cette liste, un client pourrait faire naitre 180 lignes en demandant
-- gentiment. Elle ne porte QUE des identifiants -- la personnalite, elle, vit
-- dans api/_pnj-referents.js et n'a rien a faire en base.
--
-- LES DEUX LISTES DOIVENT RESTER ALIGNEES. Le banc
-- .scratch/banc_referents_personnalites.py le verifie automatiquement : ajouter
-- un referent au fichier sans l'ajouter ici le fait echouer.
create table if not exists public.pnj_referents (
  referent_id text primary key,
  domaine     text not null
);

comment on table public.pnj_referents is
  'Liste FERMEE des PNJ referents, cote serveur. Ne porte que des identifiants et un libelle de domaine : la personnalite vit dans api/_pnj-referents.js. Sert a refuser d''ouvrir une memoire pedagogique pour un PNJ qui n''en est pas un.';

insert into public.pnj_referents (referent_id, domaine) values
  ('marc_hantile',      'economie'),
  ('martial_bouterin',  'militaire — organisation, strategie, operations'),
  ('gaspard_ferriere',  'militaire — engagement, formation, troupe'),
  ('procureur_saad',    'justice — poursuites et parquet'),
  ('juge_fontaine',     'justice — proces et jugement'),
  ('president_laroche', 'institutions et Etat'),
  ('raoul_toufaud',     'police')
on conflict (referent_id) do nothing;

-- ---------------------------------------------------------------------------
-- 2. CE QU'IL A DEJA EXPLIQUE, ET A QUI
-- ---------------------------------------------------------------------------
create table if not exists public.pnj_referents_pedagogie (
  referent_id   text        not null,
  joueur        text        not null,
  consultations integer     not null default 0,
  premiere_le   timestamptz not null default now(),
  derniere_le   timestamptz not null default now(),
  -- Reservee. Vide tant qu'aucun signal fiable ne dit de quoi on a parle.
  sujets        jsonb       not null default '{}'::jsonb,
  primary key (referent_id, joueur)
);

comment on table public.pnj_referents_pedagogie is
  'Memoire PEDAGOGIQUE d''un referent envers un joueur : combien de fois il lui a deja explique des choses. AUCUNE familiarite, AUCUNE confiance, AUCUN jalon -- ces notions appartiennent aux PNJ sociaux, et les melanger effacerait la difference de nature entre les deux. Une ligne par couple ; fermee au client, tout passe par les deux RPC.';

alter table public.pnj_referents           enable row level security;
alter table public.pnj_referents_pedagogie enable row level security;
revoke all on table public.pnj_referents           from public, anon, authenticated;
revoke all on table public.pnj_referents_pedagogie from public, anon, authenticated;
grant all on table public.pnj_referents           to service_role;
grant all on table public.pnj_referents_pedagogie to service_role;

-- ---------------------------------------------------------------------------
-- 3. NOTER UNE CONSULTATION
-- ---------------------------------------------------------------------------
-- Appelee apres un echange reellement abouti, jamais a l'ouverture d'une fiche :
-- consulter quelqu'un, c'est lui avoir parle. Sans effet pour les 180 PNJ qui ne
-- sont pas referents -- aucune ligne n'est creee.
create or replace function public.referent_pedagogie_noter(p_referent_id text)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_moi text; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.pnj_referents r WHERE r.referent_id = p_referent_id) THEN
    RETURN jsonb_build_object('ok', true, 'referent', false); END IF;

  INSERT INTO public.pnj_referents_pedagogie (referent_id, joueur, consultations)
       VALUES (p_referent_id, v_moi, 1)
  ON CONFLICT (referent_id, joueur) DO UPDATE
     SET consultations = public.pnj_referents_pedagogie.consultations + 1,
         derniere_le   = now();

  SELECT consultations INTO v_n FROM public.pnj_referents_pedagogie
   WHERE referent_id = p_referent_id AND joueur = v_moi;
  RETURN jsonb_build_object('ok', true, 'referent', true, 'consultations', v_n);
END;
$fn$;

comment on function public.referent_pedagogie_noter(text) is
  'Note une consultation aboutie aupres d''un referent. Sans effet pour un PNJ qui n''est pas dans la liste fermee : aucune ligne n''est creee. Ne touche a aucune notion sociale.';

-- ---------------------------------------------------------------------------
-- 4. CE QUE LE PROMPT A LE DROIT DE SAVOIR
-- ---------------------------------------------------------------------------
-- Lue sous le jeton du joueur, comme la relation sociale : un client ne peut ni
-- la fournir, ni la falsifier, ni lire celle d'un autre.
create or replace function public.referent_pedagogie_contexte(p_referent_id text)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_moi text; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT consultations INTO v_n FROM public.pnj_referents_pedagogie
   WHERE referent_id = p_referent_id AND joueur = v_moi;
  IF v_n IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_consultation'); END IF;
  RETURN jsonb_build_object('ok', true, 'consultations', v_n);
END;
$fn$;

comment on function public.referent_pedagogie_contexte(text) is
  'Combien de fois ce referent a deja explique des choses au joueur connecte, pour adapter son enseignement. Lecture seule, sous le jeton du joueur.';

revoke all on function public.referent_pedagogie_noter(text)    from public, anon;
revoke all on function public.referent_pedagogie_contexte(text) from public, anon;
grant execute on function public.referent_pedagogie_noter(text)    to authenticated, service_role;
grant execute on function public.referent_pedagogie_contexte(text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. GARDE
-- ---------------------------------------------------------------------------
DO $garde$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.pnj_referents;
  IF n <> 7 THEN RAISE EXCEPTION 'liste des referents : % entrees, 7 attendues', n; END IF;
END $garde$;
