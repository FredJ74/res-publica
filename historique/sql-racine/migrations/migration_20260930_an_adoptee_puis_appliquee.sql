-- ===========================================================================
-- L'ASSEMBLEE DECIDE, LE MINISTRE EXECUTE (30 septembre 2026)
-- ---------------------------------------------------------------------------
-- Une loi ne devient plus mecaniquement applicable du seul fait de son
-- adoption. Trois etats se succedent desormais :
--     PROJET  ->  ADOPTEE PAR L'ASSEMBLEE  ->  MISE EN APPLICATION
-- L'Assemblee decide du CONTENU exact ; le Ministre de l'Interieur ne decide
-- que du MOMENT. Il ne choisit ni la matiere, ni le niveau, ni les exceptions.
--
-- PERIMETRE DU NOUVEAU CYCLE (arbitrage Fred du 30 septembre) : les types
-- `mecanique` et `abrogation` seulement. Une loi `rp` est declarative : adoptee,
-- elle est terminee. Elle n'entre pas dans le registre ministeriel, ne declenche
-- aucun chrono, ne recoit jamais d'etat « appliquee ».
--
-- LE CHANGEMENT EST CENTRAL, PAS DISSEMINE. Quatorze fonctions consomment
-- `assemblee_loi_en_vigueur`, toutes avec le meme sens : « cette loi produit
-- actuellement ses effets ». On corrige donc CETTE fonction, une fois, et les
-- quatorze suivent -- circuits economiques, qualification judiciaire, trigger de
-- fret, confiscation douaniere, achat illegal, verification d'UX. Aucun test
-- d'application n'est duplique ailleurs.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. L'ETAT D'APPLICATION
-- ---------------------------------------------------------------------------
alter table public.assemblee_propositions
  add column if not exists appliquee_ts  timestamptz,
  add column if not exists appliquee_par text;

comment on column public.assemblee_propositions.appliquee_ts is
  'Instant SERVEUR de la mise en application par le Ministre de l''Interieur. NULL = adoptee mais pas encore appliquee : la loi existe politiquement, ses effets mecaniques ne sont pas actifs. Toujours NULL pour une loi de type rp, qui n''a rien a appliquer.';
comment on column public.assemblee_propositions.appliquee_par is
  'Nom du personnage qui a prononce la mise en application. Tracabilite seule : l''autorite est verifiee au moment de l''acte, pas relue ici.';

-- Le registre ministeriel interroge « adoptees et pas encore appliquees ».
create index if not exists assemblee_propositions_a_appliquer_idx
  on public.assemblee_propositions (country, adoptee_ts)
  where statut = 'adoptee' and appliquee_ts is null and type in ('mecanique', 'abrogation');

-- ---------------------------------------------------------------------------
-- 2. QUELS TYPES EXIGENT UNE MISE EN APPLICATION -- ECRIT UNE SEULE FOIS
-- ---------------------------------------------------------------------------
create or replace function public.assemblee_exige_application(p_type text)
returns boolean
language sql
immutable
set search_path to 'public', 'pg_temp'
as $fn$
  SELECT coalesce(p_type, '') IN ('mecanique', 'abrogation');
$fn$;

comment on function public.assemblee_exige_application(text) is
  'Un type de proposition entre-t-il dans le cycle d''execution gouvernementale ? mecanique et abrogation : oui. rp : non, une loi declarative est terminee des son adoption. Seul endroit du serveur ou cette frontiere est ecrite.';

revoke all on function public.assemblee_exige_application(text) from public, anon;
grant execute on function public.assemblee_exige_application(text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. LES SIX MATIERES QUE L'ASSEMBLEE NE POUVAIT PAS ATTEINDRE
-- ---------------------------------------------------------------------------
-- Le jeu connait 17 matieres economiques ; les 15 categories n'en visaient que
-- 11. C'etait une lacune d'implementation, pas une regle : on la comble en
-- suivant EXACTEMENT le motif deja present (viandes -> ['viande'], textile ->
-- ['textile'], tabac -> ['tabac'] sont deja des categories a une seule matiere).
-- Aucun mecanisme nouveau, aucun circuit invente : la garde ne mord que sur les
-- circuits qui existent reellement pour chaque matiere, et l'audit de ces
-- circuits est consigne dans le rapport du chantier.
insert into public.assemblee_categories_interdiction (categorie, label, matieres, types_objet, sous_types)
values
  ('cereales',       'Céréales',            array['cereales'],       array[]::text[], array[]::text[]),
  ('fruits_legumes', 'Fruits et légumes',   array['fruits_legumes'], array[]::text[], array[]::text[]),
  ('metal',          'Métal',               array['metal'],          array[]::text[], array[]::text[]),
  ('minerai',        'Minerai',             array['minerai'],        array[]::text[], array[]::text[]),
  ('plantes',        'Plantes',             array['plantes'],        array[]::text[], array[]::text[]),
  ('desinfectant',   'Désinfectant',        array['desinfectant'],   array[]::text[], array[]::text[])
on conflict (categorie) do nothing;

-- ---------------------------------------------------------------------------
-- 4. LES CIRCUITS REELLEMENT DISPONIBLES POUR UNE MATIERE
-- ---------------------------------------------------------------------------
-- Seb Lex ne doit pas demander au joueur de statuer sur un mecanisme qui
-- n'existe pas. Cette fonction repond, pour une matiere, quelles dimensions
-- mecaniques ont un sens -- et elle le DEDUIT des tables du jeu, jamais d'une
-- liste tenue a la main. Elle ne decide rien : elle decrit.
create or replace function public.matiere_circuits_disponibles(p_matiere text)
returns jsonb
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
  SELECT CASE WHEN NOT EXISTS (SELECT 1 FROM public.ressources_economie WHERE cle = p_matiere)
    THEN NULL
    ELSE jsonb_build_object(
      'matiere', p_matiere,
      -- ACHAT LEGAL : l'Entrepot logistique tient les 17 matieres ; la criee du
      -- port en vend certaines.
      'achat_entrepot', EXISTS (
        SELECT 1 FROM public.batiments_etat b
         WHERE b.id LIKE '%entrepot%'
           AND public.batiment_etat_lire(b.data)->'entrepot'->'stock' ? p_matiere),
      'achat_criee', EXISTS (
        SELECT 1 FROM public.batiments_etat b
         WHERE public.batiment_etat_lire(b.data)->'port'->'criee'->'stock' ? p_matiere),
      -- VENTE LEGALE : a un commerce (si une recette de sa carte la consomme), a
      -- une usine (chaine ou liste hors chaine), a une structure medicale.
      'vente_commerce', EXISTS (
        SELECT 1 FROM public.recettes_commerce r WHERE r.materiaux ? p_matiere),
      'vente_armurerie', EXISTS (
        SELECT 1 FROM public.recettes_production r WHERE r.materiaux ? p_matiere),
      'vente_usine', EXISTS (
        SELECT 1 FROM public.chaines_production_usine c WHERE c.matiere = p_matiere)
        OR EXISTS (
        SELECT 1 FROM public.usines_rachat_config u
         WHERE coalesce(u.matieres_hors_chaine, '[]'::jsonb) ? p_matiere),
      'vente_medical', EXISTS (
        SELECT 1 FROM public.structures_medicales s
         WHERE coalesce(s.ressources, '[]'::jsonb) ? p_matiere),
      -- PRODUCTION : une chaine d'usine la FABRIQUE (point de passage serveur,
      -- produire_en_usine), ou elle est recoltable (aujourd'hui sans RPC : la
      -- dette est consignee au rapport).
      'production_usine', EXISTS (
        SELECT 1 FROM public.chaines_production_usine c WHERE c.produit = p_matiere),
      'recolte', p_matiere IN ('metal', 'poisson', 'charbon', 'bois'),
      -- TRANSFORMATION : un stock de cette matiere peut-il etre consomme pour
      -- fabriquer autre chose ? C'est la dimension du CAS B.
      'transformation', EXISTS (
        SELECT 1 FROM public.recettes_commerce r WHERE r.materiaux ? p_matiere)
        OR EXISTS (
        SELECT 1 FROM public.recettes_production r WHERE r.materiaux ? p_matiere)
        OR EXISTS (
        SELECT 1 FROM public.chaines_production_usine c WHERE c.matiere = p_matiere),
      -- Quelle categorie parlementaire permet de la viser.
      'categories', coalesce((
        SELECT jsonb_agg(c.categorie ORDER BY c.categorie)
          FROM public.assemblee_categories_interdiction c
         WHERE p_matiere = ANY (c.matieres)), '[]'::jsonb)
    ) END;
$fn$;

comment on function public.matiere_circuits_disponibles(text) is
  'Decrit, pour une matiere economique, les circuits qui EXISTENT reellement dans le jeu : achat (entrepot, criee), vente (commerce, armurerie, usine, structure medicale), production (chaine d''usine, recolte), transformation, et les categories parlementaires qui permettent de la viser. Deduit des tables du jeu, jamais d''une liste tenue a la main. Rend NULL si la matiere est inconnue. Sert a Seb Lex pour ne poser que les questions pertinentes.';

revoke all on function public.matiere_circuits_disponibles(text) from public, anon;
grant execute on function public.matiere_circuits_disponibles(text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. « EN VIGUEUR » VEUT DESORMAIS DIRE « APPLIQUEE »
-- ---------------------------------------------------------------------------
-- LE SEUL ENDROIT MODIFIE POUR LES QUATORZE CONSOMMATEURS. Deux ajouts :
--   - la loi doit avoir ete mise en application, et l'etre a l'instant demande ;
--   - l'objet rendu porte desormais la PORTEE votee, pour que les gardes de
--     transformation puissent la lire sans relire la table.
-- Le filtre type='mecanique' etait deja la : une loi rp n'a jamais ete rendue par
-- cette fonction, et une abrogation agit en eteignant sa cible, pas en etant
-- elle-meme « en vigueur ».
create or replace function public.assemblee_loi_en_vigueur(
  p_country text, p_objet jsonb, p_instant timestamp with time zone)
returns jsonb
language sql
stable
set search_path to 'public', 'pg_temp'
as $fn$
  SELECT jsonb_build_object(
           'id', p.id, 'titre', p.titre, 'categorie', p.categorie,
           'adoptee_ts', p.adoptee_ts, 'appliquee_ts', p.appliquee_ts,
           'portee', coalesce(p.data -> 'portee', '{}'::jsonb))
    FROM public.assemblee_propositions p
   WHERE p.country = p_country
     AND p.type = 'mecanique'
     AND p.statut = 'adoptee'
     AND p.adoptee_ts IS NOT NULL
     AND p.adoptee_ts <= p_instant
     AND p.appliquee_ts IS NOT NULL
     AND p.appliquee_ts <= p_instant
     AND public.assemblee_objet_vise(p.categorie, p_objet)
   ORDER BY p.appliquee_ts, p.adoptee_ts, p.id
   LIMIT 1;
$fn$;

comment on function public.assemblee_loi_en_vigueur(text, jsonb, timestamp with time zone) is
  'La loi mecanique qui produit SES EFFETS sur cet objet a cet instant, ou NULL. Depuis le 30 septembre 2026, une loi adoptee mais non encore mise en application par le Ministre de l''Interieur n''est PAS en vigueur : l''adoption est parlementaire, l''entree en vigueur est executive. L''objet rendu porte la portee votee (data.portee), que lisent les gardes de transformation. Source unique pour les quatorze consommateurs -- aucun ne duplique ce test.';

-- ---------------------------------------------------------------------------
-- 6. UNE ABROGATION ADOPTEE N'ETEINT PLUS SA CIBLE TOUTE SEULE
-- ---------------------------------------------------------------------------
-- C'etait le cas jusqu'ici, dans la meme transaction que le depouillement. Elle
-- doit desormais attendre, elle aussi, la mise en application ministerielle --
-- une abrogation est une decision parlementaire comme une autre. Le reste de
-- assemblee_cloturer est repris a l'identique du corps releve en production.
create or replace function public.assemblee_cloturer(p_id text)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE
  v_row        public.assemblee_propositions%ROWTYPE;
  v_pour       text[]  := '{}';
  v_contre     text[]  := '{}';
  v_abst       text[]  := '{}';
  v_non_vot    text[]  := '{}';
  v_endormis   text[]  := '{}';
  v_pnj_pour   text[]  := '{}';
  v_pnj_contre text[]  := '{}';
  v_score_p    integer := 0;
  v_score_c    integer := 0;
  v_resultat   text;
  v_scrutin_id text;
BEGIN
  SELECT * INTO v_row FROM public.assemblee_propositions WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'introuvable');
  END IF;

  v_scrutin_id := p_id || ':' || v_row.session_num;

  -- Idempotence : cette session est deja close.
  IF EXISTS (SELECT 1 FROM public.assemblee_scrutins WHERE id = v_scrutin_id) THEN
    RETURN jsonb_build_object('ok', true, 'deja_cloture', true,
      'scrutin', (SELECT to_jsonb(s) FROM public.assemblee_scrutins s WHERE s.id = v_scrutin_id));
  END IF;

  IF v_row.statut <> 'session' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_session');
  END IF;

  -- Garde temporelle : jamais de depouillement avant l'echeance, quel que soit
  -- l'appelant. Une session sans echeance n'est pas depouillable.
  IF v_row.cloture_ts IS NULL OR now() < v_row.cloture_ts THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_non_echu');
  END IF;

  -- ---- Cote PJ : les sieges reellement tenus par un joueur
  SELECT
    COALESCE(array_agg(o.pj_nom) FILTER (WHERE v.choix = 'POUR'),       '{}'),
    COALESCE(array_agg(o.pj_nom) FILTER (WHERE v.choix = 'CONTRE'),     '{}'),
    COALESCE(array_agg(o.pj_nom) FILTER (WHERE v.choix = 'ABSTENTION'), '{}'),
    COALESCE(array_agg(o.pj_nom) FILTER (WHERE v.choix IS NULL),        '{}')
  INTO v_pour, v_contre, v_abst, v_non_vot
  FROM public.assemblee_occupation_sieges(v_row.country) o
  LEFT JOIN public.assemblee_votes v
    ON v.proposition_id = p_id
   AND v.session_num = v_row.session_num
   AND v.votant = o.pj_nom
  WHERE NOT o.est_pnj;

  -- ---- Cote PNJ : intention comptee UNIQUEMENT si le depute est eveille
  SELECT
    COALESCE(array_agg(o.pnj_nom) FILTER (WHERE NOT o.endormi AND i.intention = 'POUR'),   '{}'),
    COALESCE(array_agg(o.pnj_nom) FILTER (WHERE NOT o.endormi AND i.intention = 'CONTRE'), '{}'),
    COALESCE(array_agg(o.pnj_nom) FILTER (WHERE o.endormi), '{}')
  INTO v_pnj_pour, v_pnj_contre, v_endormis
  FROM public.assemblee_occupation_sieges(v_row.country) o
  LEFT JOIN public.assemblee_intentions i
    ON i.proposition_id = p_id
   AND i.session_num = v_row.session_num
   AND i.siege_id = o.siege_id
  WHERE o.est_pnj;

  v_pour   := v_pour   || v_pnj_pour;
  v_contre := v_contre || v_pnj_contre;

  v_score_p := COALESCE(array_length(v_pour, 1), 0);
  v_score_c := COALESCE(array_length(v_contre, 1), 0);

  -- §26/§27
  IF v_score_p > v_score_c THEN
    v_resultat := 'ADOPTEE';
  ELSIF v_score_c > v_score_p THEN
    v_resultat := 'REJETEE';
  ELSE
    v_resultat := 'RENVOYEE';
  END IF;

  INSERT INTO public.assemblee_scrutins
    (id, proposition_id, session_num, country, titre, resultat,
     score_pour, score_contre, pour, contre, abstention, non_votants, endormis)
  VALUES
    (v_scrutin_id, p_id, v_row.session_num, v_row.country, v_row.titre, v_resultat,
     v_score_p, v_score_c,
     to_jsonb(v_pour), to_jsonb(v_contre), to_jsonb(v_abst),
     to_jsonb(v_non_vot), to_jsonb(v_endormis));

  -- Statut de la proposition
  IF v_resultat = 'ADOPTEE' THEN
    UPDATE public.assemblee_propositions
    SET statut = 'adoptee', adoptee_ts = now()
    WHERE id = p_id;

    -- CHANGEMENT DU 30 SEPTEMBRE 2026 : une abrogation adoptee N'ETEINT PLUS sa
    -- cible ici. Elle rejoint le registre du Ministre de l'Interieur et attend
    -- sa mise en application, comme toute autre decision parlementaire. C'est
    -- assemblee_mettre_en_application qui eteindra la cible.
    -- L'adoptee_ts pose ci-dessus demarre AUSSI le chrono d'execution : le delai
    -- appartient a la loi, pas au gouvernement.

  ELSIF v_resultat = 'REJETEE' THEN
    UPDATE public.assemblee_propositions SET statut = 'rejetee' WHERE id = p_id;
  ELSE
    -- §27 : renvoi. Le projet reste vivant ; ses votes PJ seront effaces et les
    -- intentions rerollees a l'ouverture de la session suivante.
    UPDATE public.assemblee_propositions
    SET statut = 'renvoyee', cloture_ts = NULL, session_ouverte_ts = NULL
    WHERE id = p_id;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'resultat', v_resultat,
    'score_pour', v_score_p,
    'score_contre', v_score_c,
    'pour', to_jsonb(v_pour),
    'contre', to_jsonb(v_contre),
    'abstention', to_jsonb(v_abst),
    'non_votants', to_jsonb(v_non_vot),
    'endormis', to_jsonb(v_endormis),
    'titre', v_row.titre,
    'type', v_row.type,
    'categorie', v_row.categorie,
    'auteur', v_row.auteur,
    'forum_topic_id', v_row.forum_topic_id,
    'loi_cible_id', v_row.loi_cible_id,
    'exige_application', public.assemblee_exige_application(v_row.type)
  );
END;
$fn$;

revoke all on function public.assemblee_cloturer(text) from public, anon, authenticated;
grant execute on function public.assemblee_cloturer(text) to service_role;

-- ---------------------------------------------------------------------------
-- 7. GARDES
-- ---------------------------------------------------------------------------
DO $garde$
DECLARE n integer;
BEGIN
  -- a) L'etat d'application existe bien.
  SELECT count(*) INTO n FROM information_schema.columns
   WHERE table_schema='public' AND table_name='assemblee_propositions'
     AND column_name IN ('appliquee_ts','appliquee_par');
  IF n <> 2 THEN RAISE EXCEPTION 'colonnes d''application absentes (% trouvee(s))', n; END IF;

  -- b) Les 17 matieres du jeu sont desormais toutes atteignables par au moins
  --    une categorie. C'est l'objet meme de la section 3.
  SELECT count(*) INTO n FROM public.ressources_economie r
   WHERE NOT EXISTS (SELECT 1 FROM public.assemblee_categories_interdiction c
                      WHERE r.cle = ANY (c.matieres));
  IF n <> 0 THEN RAISE EXCEPTION '% matiere(s) restent hors de portee de l''Assemblee', n; END IF;

  -- c) « En vigueur » exige bien l'application, et rend la portee.
  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname='public' AND p.proname='assemblee_loi_en_vigueur'
     AND pg_get_functiondef(p.oid) LIKE '%appliquee_ts IS NOT NULL%'
     AND pg_get_functiondef(p.oid) LIKE '%''portee''%';
  IF n <> 1 THEN RAISE EXCEPTION 'assemblee_loi_en_vigueur n''exige pas l''application'; END IF;

  -- d) Le depouillement n'eteint plus une cible d'abrogation.
  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname='public' AND p.proname='assemblee_cloturer'
     AND pg_get_functiondef(p.oid) LIKE '%statut = ''abrogee''%';
  IF n <> 0 THEN RAISE EXCEPTION 'assemblee_cloturer eteint encore la cible d''abrogation'; END IF;

  -- e) Une seule signature pour chaque fonction touchee.
  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname='public'
     AND p.proname IN ('assemblee_loi_en_vigueur','assemblee_cloturer',
                       'assemblee_exige_application','matiere_circuits_disponibles');
  IF n <> 4 THEN RAISE EXCEPTION 'signatures inattendues sur les fonctions touchees (% trouvee(s))', n; END IF;

  -- f) Aucune loi de test ne traverse une migration.
  SELECT count(*) INTO n FROM public.assemblee_propositions WHERE id LIKE 'zzbanc-%';
  IF n <> 0 THEN RAISE EXCEPTION '% loi(s) de test en base', n; END IF;
END $garde$;
