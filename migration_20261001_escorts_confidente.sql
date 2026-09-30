-- ===========================================================================
-- UNE SEULE CONFIDENTE (1er octobre 2026)
-- ---------------------------------------------------------------------------
-- LA REGLE DE GAME DESIGN. Un joueur peut engager plusieurs escorts, mais une
-- seule d'entre elles devient sa confidente -- le PNJ social avec qui une
-- relation se construit. Le choix est EXPLICITE : c'est une ressource rare, et
-- une designation implicite surprendrait au mauvais moment.
--
-- CE QUE LE SOCLE SOCIAL DONNE DEJA GRATUITEMENT. La relation vit dans
-- pnj_social_relations, dont la cle est (pnj_id, joueur). En y logeant
-- l'escort_id du catalogue -- et non l'identifiant d'emploi, qui appartient a un
-- seul proprietaire -- trois exigences sont satisfaites sans une ligne de plus :
--   * plusieurs joueurs entretiennent chacun leur relation avec la meme personne ;
--   * la relation ignore le recrutement, la presence et le groupe ;
--   * elle SURVIT AU RENVOI, puisque rien ne la rattache a un contrat.
--
-- CE QU'IL FALLAIT AJOUTER. Une seule chose : la contrainte « une par joueur ».
-- Une table dediee, dont `joueur` est la cle primaire, la rend structurelle
-- plutot qu'applicative -- et repond en un acces a la question « qui est ma
-- confidente ? ». On ne la loge pas dans pnj_social_relations : cette table sert
-- tous les PNJ sociaux du jeu, et une regle propre aux escorts n'a pas a la
-- polluer.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. LE LIEN, UN PAR JOUEUR
-- ---------------------------------------------------------------------------
create table if not exists public.pnj_social_escort_choisi (
  joueur    text        primary key,
  escort_id text        not null,
  choisi_le timestamptz not null default now()
);

comment on table public.pnj_social_escort_choisi is
  'La confidente d''un joueur, une seule. `joueur` en cle primaire : la regle « une escort sociale par PJ » est structurelle, pas applicative. Changer de confidente remplace la ligne ; l''ancienne relation, elle, n''est jamais effacee.';

alter table public.pnj_social_escort_choisi enable row level security;
revoke all on table public.pnj_social_escort_choisi from public, anon, authenticated;
grant all on table public.pnj_social_escort_choisi to service_role;

-- ---------------------------------------------------------------------------
-- 2. UNE CONVERSATION COMPTE AUSSI POUR QUI N'A PAS DE JALON
-- ---------------------------------------------------------------------------
-- Le socle definissait « PNJ social » par la presence d'une regle de jalon. Les
-- escorts n'en ont pas : leur lien nait d'une designation, pas d'une rencontre
-- scriptee. Sans cet ajout, leurs conversations ne seraient jamais comptees et
-- leur familiarite resterait a zero -- le PNJ se souviendrait d'avoir ete choisi,
-- mais jamais d'avoir parle.
--
-- On elargit donc la definition : est social un PNJ qui a une regle de jalon, OU
-- avec qui ce joueur a DEJA une relation. Les 175 PNJ ordinaires restent hors du
-- compte, puisqu'ils n'ont ni l'une ni l'autre.
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
  IF NOT EXISTS (SELECT 1 FROM public.pnj_social_jalons_regles g WHERE g.pnj_id = p_pnj_id)
     AND NOT EXISTS (SELECT 1 FROM public.pnj_social_relations r
                      WHERE r.pnj_id = p_pnj_id AND r.joueur = v_moi) THEN
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
  'Enregistre une conversation reellement engagee avec un PNJ social. Est social un PNJ qui a une regle de jalon OU avec qui ce joueur a deja une relation -- c''est le second cas qui couvre les escorts, dont le lien nait d''une designation. Fait monter la familiarite par paliers bornes ; ne touche JAMAIS la confiance.';

-- ---------------------------------------------------------------------------
-- 3. DESIGNER SA CONFIDENTE
-- ---------------------------------------------------------------------------
create or replace function public.escort_sociale_choisir(p_escort_id text)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE
  v_moi text; v_pays text; v_avant text; v_avant_nom text;
  v_esc public.escorts_catalogue%ROWTYPE;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT coalesce(country, 'republic') INTO v_pays
    FROM public.personnages_donnees WHERE name = v_moi;

  SELECT * INTO v_esc FROM public.escorts_catalogue
   WHERE escort_id = p_escort_id AND pays = v_pays AND actif;
  IF v_esc.escort_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'escort_inconnue'); END IF;

  SELECT c.escort_id INTO v_avant
    FROM public.pnj_social_escort_choisi c WHERE c.joueur = v_moi;
  IF v_avant IS NOT DISTINCT FROM p_escort_id THEN
    RETURN jsonb_build_object('ok', true, 'inchange', true,
                              'escort_id', p_escort_id, 'nom', v_esc.nom); END IF;
  SELECT nom INTO v_avant_nom FROM public.escorts_catalogue WHERE escort_id = v_avant;

  -- LE CHOIX REMPLACE, IL N'EFFACE PAS. L'ancienne relation reste en base avec
  -- ses rencontres et sa familiarite : quelqu'un a qui l'on a parle ne redevient
  -- pas un inconnu parce qu'on s'est attache a une autre.
  INSERT INTO public.pnj_social_escort_choisi (joueur, escort_id, choisi_le)
       VALUES (v_moi, p_escort_id, now())
  ON CONFLICT (joueur) DO UPDATE
     SET escort_id = EXCLUDED.escort_id, choisi_le = now();

  -- La relation doit exister pour pouvoir croitre. Elle nait ici, vide : aucune
  -- rencontre n'est inventee, seulement la possibilite d'en compter.
  INSERT INTO public.pnj_social_relations (pnj_id, joueur)
       VALUES (p_escort_id, v_moi)
  ON CONFLICT (pnj_id, joueur) DO NOTHING;

  RETURN jsonb_build_object('ok', true, 'escort_id', p_escort_id, 'nom', v_esc.nom,
                            'precedente', v_avant, 'precedente_nom', v_avant_nom);
END;
$fn$;

comment on function public.escort_sociale_choisir(text) is
  'Designe la confidente du joueur, une seule a la fois, dans l''empire ou il se trouve. Remplace la precedente sans effacer sa relation. Cree la relation vide si elle n''existe pas encore, pour qu''elle puisse croitre.';

create or replace function public.escort_sociale_actuelle()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_moi text; v_id text; v_nom text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT c.escort_id INTO v_id FROM public.pnj_social_escort_choisi c WHERE c.joueur = v_moi;
  IF v_id IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'escort_id', NULL); END IF;
  SELECT nom INTO v_nom FROM public.escorts_catalogue WHERE escort_id = v_id;
  RETURN jsonb_build_object('ok', true, 'escort_id', v_id, 'nom', v_nom);
END;
$fn$;

comment on function public.escort_sociale_actuelle() is
  'Qui est la confidente du joueur connecte. Rend escort_id NULL s''il n''en a pas encore choisi -- etat normal, pas une erreur.';

revoke all on function public.escort_sociale_choisir(text) from public, anon;
revoke all on function public.escort_sociale_actuelle()   from public, anon;
grant execute on function public.escort_sociale_choisir(text) to authenticated, service_role;
grant execute on function public.escort_sociale_actuelle()    to authenticated, service_role;
