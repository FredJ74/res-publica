-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260930164804
-- Nom original      : an_portee_votee_et_mise_en_application
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-30 16:48:04 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : eea502eaae69123f1ac82969b48390b1
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
-- LA PORTEE EST VOTEE, L'APPLICATION EST PRONONCEE (30 septembre 2026)
-- Deux choses distinctes, deux fonctions distinctes :
--   - au DEPOT, l'auteur fixe la portee mecanique. Elle est verrouillee des cet
--     instant : assemblee_amender n'ajoute que du texte, jamais un parametre.
--   - a l'APPLICATION, le ministre ne transmet QUE l'identifiant de la loi. Le
--     serveur relit lui-meme la portee votee. Le niveau d'interdiction appartient
--     a l'Assemblee, jamais au Ministre de l'Interieur.

-- 1. LA PORTEE : UNE SEULE DIMENSION VOTEE, VALIDEE CONTRE UNE LISTE FERMEE
-- Les cas A et B de l'arbitrage ne different que par la transformation : la
-- production, l'achat, la vente, l'approvisionnement et l'import legaux sont
-- bloques dans les DEUX. Une seule variable suffit donc, et il serait trompeur
-- d'en stocker davantage : un champ que le moteur n'honore pas est un mensonge.
create or replace function public.assemblee_portee_valider(p_portee jsonb)
returns jsonb
language plpgsql
immutable
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_cle text; v_val jsonb;
BEGIN
  -- Absente ou vide : CAS A par defaut -- interdiction economique sans
  -- interdiction de transformation. Le moins-disant, jamais le plus-disant.
  IF p_portee IS NULL OR p_portee = 'null'::jsonb THEN
    RETURN jsonb_build_object('ok', true, 'portee',
             jsonb_build_object('transformation_stock_interdite', false));
  END IF;
  IF jsonb_typeof(p_portee) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'portee_invalide');
  END IF;

  -- LISTE FERMEE. Toute cle inconnue est un refus, jamais un silence : c'est ce
  -- qui empeche l'IA d'inventer un effet que le moteur n'applique pas.
  FOR v_cle IN SELECT jsonb_object_keys(p_portee) LOOP
    IF v_cle NOT IN ('transformation_stock_interdite') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'portee_cle_inconnue', 'cle', v_cle);
    END IF;
    v_val := p_portee -> v_cle;
    IF jsonb_typeof(v_val) <> 'boolean' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'portee_valeur_invalide', 'cle', v_cle);
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'portee', jsonb_build_object(
    'transformation_stock_interdite',
    coalesce((p_portee ->> 'transformation_stock_interdite')::boolean, false)));
END $fn$;

comment on function public.assemblee_portee_valider(jsonb) is
  'Valide la portee mecanique d''un projet de loi contre une liste FERMEE de dimensions reellement implementees. Aujourd''hui une seule : transformation_stock_interdite (cas B de l''arbitrage). Absente = cas A. Toute cle ou valeur inconnue est refusee : l''IA ne peut pas inventer un effet.';

revoke all on function public.assemblee_portee_valider(jsonb) from public, anon;
grant execute on function public.assemblee_portee_valider(jsonb) to authenticated, service_role;

-- 2. LE DEPOT, PORTEE COMPRISE
-- Corps repris de assemblee_deposer releve en production, plus la portee. Le nom
-- change parce que PostgREST ne tolere pas deux signatures homonymes : l'ancien
-- nom devient un relais (section 3), donc rien ne casse pendant le deploiement.
create or replace function public.assemblee_deposer_projet(
  p_requete text, p_nom text, p_titre text, p_type text, p_texte text,
  p_categorie text, p_loi_cible_id text, p_portee jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE
  c_pa      CONSTANT integer := 1;
  c_categories text[] := ARRAY(SELECT categorie FROM public.assemblee_categories_interdiction);
  v_rej     jsonb;
  v_perso   public.personnages%ROWTYPE;
  v_cible   public.assemblee_propositions%ROWTYPE;
  v_titre   text;
  v_texte   text;
  v_cat     text := NULL;
  v_cible_id text := NULL;
  v_portee  jsonb := NULL;
  v_vp      jsonb;
  v_debit   jsonb;
  v_id      text;
  v_row     public.assemblee_propositions%ROWTYPE;
BEGIN
  PERFORM public.exiger_acteur(p_nom);
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_nom, 'deposer');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  SELECT * INTO v_perso FROM public.personnages WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'));
  END IF;
  IF NOT (v_perso.current_building = 'assemblee' AND v_perso.current_room = 'hemicycle'
          AND EXISTS (SELECT 1 FROM public.assemblee_sieges s WHERE s.country = v_perso.country)) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_lieu'));
  END IF;
  IF NOT public.assemblee_peut_deposer(p_nom, v_perso.country) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'ineligible'));
  END IF;
  IF p_type IS NULL OR p_type NOT IN ('rp', 'mecanique', 'abrogation') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'type_invalide'));
  END IF;

  v_texte := btrim(COALESCE(p_texte, ''));
  IF v_texte = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'champs_requis'));
  END IF;
  IF length(v_texte) > 20000 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'texte_trop_long'));
  END IF;

  IF p_type = 'abrogation' THEN
    SELECT * INTO v_cible FROM public.assemblee_propositions
     WHERE id = p_loi_cible_id AND statut = 'adoptee' AND country = v_perso.country;
    IF NOT FOUND THEN
      RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'loi_cible_introuvable'));
    END IF;
    v_cible_id := v_cible.id;
    v_titre := left('Abrogation — ' || v_cible.titre, 200);
  ELSE
    v_titre := btrim(COALESCE(p_titre, ''));
    IF v_titre = '' THEN
      RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'champs_requis'));
    END IF;
    IF length(v_titre) > 120 THEN
      RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'titre_trop_long'));
    END IF;
    IF p_type = 'mecanique' THEN
      -- La liste des categories n'est plus figee dans le corps : elle est LUE dans
      -- assemblee_categories_interdiction, pour qu'ajouter une categorie n'oblige
      -- plus a reecrire cette fonction (les six matieres ajoutees ce jour l'ont
      -- montre).
      IF p_categorie IS NULL OR NOT (p_categorie = ANY (c_categories)) THEN
        RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'categorie_invalide'));
      END IF;
      v_cat := p_categorie;

      v_vp := public.assemblee_portee_valider(p_portee);
      IF NOT (v_vp ->> 'ok')::boolean THEN
        RETURN public.assemblee_requete_clore(p_requete, v_vp);
      END IF;
      v_portee := v_vp -> 'portee';
    END IF;
  END IF;

  -- LE PA N'EST DEBITE QU'ICI, au depot effectif. La conversation avec le juriste
  -- de l'Assemblee ne coute rien : elle ne passe jamais par cette fonction.
  v_debit := public.assemblee_debiter_joueur(p_nom, c_pa, 0);
  IF NOT (v_debit ->> 'ok')::boolean THEN
    RETURN public.assemblee_requete_clore(p_requete, v_debit);
  END IF;

  v_id := 'prop-' || (extract(epoch FROM clock_timestamp()) * 1000)::bigint
          || '-' || substr(md5(random()::text || clock_timestamp()::text), 1, 6);

  INSERT INTO public.assemblee_propositions
    (id, country, auteur, titre, type, categorie, loi_cible_id, texte_original,
     eligible_session_ts, data)
  VALUES
    (v_id, v_perso.country, p_nom, v_titre, p_type, v_cat, v_cible_id, v_texte,
     now() + interval '7 days',
     CASE WHEN v_portee IS NULL THEN '{}'::jsonb
          ELSE jsonb_build_object('portee', v_portee) END)
  RETURNING * INTO v_row;

  RETURN public.assemblee_requete_clore(p_requete,
    v_debit || jsonb_build_object('ok', true, 'proposition', to_jsonb(v_row)));
END;
$fn$;

comment on function public.assemblee_deposer_projet(text, text, text, text, text, text, text, jsonb) is
  'Depot d''un projet de loi, portee mecanique comprise (data.portee, validee contre une liste fermee). Porte canonique depuis le 30 septembre 2026 ; assemblee_deposer la relaie sans portee. Exige la presence dans l''hemicycle, l''eligibilite (depute, PM, ministres) et debite 1 PA -- uniquement au depot effectif.';

revoke all on function public.assemblee_deposer_projet(text, text, text, text, text, text, text, jsonb) from public, anon;
grant execute on function public.assemblee_deposer_projet(text, text, text, text, text, text, text, jsonb) to authenticated, service_role;

-- 3. L'ANCIENNE PORTE DEVIENT UN RELAIS -- une seule logique de depot
create or replace function public.assemblee_deposer(
  p_nom text, p_titre text, p_type text, p_texte text,
  p_categorie text, p_loi_cible_id text, p_requete text)
returns jsonb
language sql
security definer
set search_path to 'public', 'pg_temp'
as $relais$
  SELECT public.assemblee_deposer_projet(
    p_requete, p_nom, p_titre, p_type, p_texte, p_categorie, p_loi_cible_id, NULL);
$relais$;

comment on function public.assemblee_deposer(text, text, text, text, text, text, text) is
  'RELAIS (30 septembre 2026) vers assemblee_deposer_projet, sans portee -- donc cas A par defaut pour une loi mecanique. Signature inchangee : aucun appelant deploye ne casse. Ne contient plus aucune logique.';

revoke all on function public.assemblee_deposer(text, text, text, text, text, text, text) from public, anon;
grant execute on function public.assemblee_deposer(text, text, text, text, text, text, text) to authenticated, service_role;

-- 4. LE CHRONO APPARTIENT A LA LOI
create or replace function public.assemblee_echeance_application(p_adoptee_ts timestamptz)
returns timestamptz
language sql
immutable
set search_path to 'public', 'pg_temp'
as $fn$
  SELECT p_adoptee_ts + interval '36 hours';
$fn$;

comment on function public.assemblee_echeance_application(timestamptz) is
  'Instant limite de mise en application : adoption + 36 heures reelles. Le chrono demarre a l''ADOPTION et appartient a la loi -- aucun changement de ministre, de gouvernement ou de president ne le remet a zero.';

revoke all on function public.assemblee_echeance_application(timestamptz) from public, anon;
grant execute on function public.assemblee_echeance_application(timestamptz) to authenticated, service_role;

-- 5. LA MISE EN APPLICATION -- LA SEULE DECISION DU MINISTRE
create or replace function public.assemblee_mettre_en_application(
  p_requete text, p_acteur text, p_loi_id text)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE
  v_rej    jsonb;
  v_perso  public.personnages%ROWTYPE;
  v_row    public.assemblee_propositions%ROWTYPE;
  v_cible  public.assemblee_propositions%ROWTYPE;
  v_poste  text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_acteur, 'appliquer');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  -- 1. IDENTITE ET POSTE. Le poste est lu en base, jamais recu du navigateur ; il
  --    est atteste par le trigger des postes.
  SELECT * INTO v_perso FROM public.personnages WHERE name = p_acteur;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'));
  END IF;
  SELECT pd.poste ->> 'id' INTO v_poste FROM public.personnages_donnees pd WHERE pd.name = p_acteur;
  IF v_poste IS DISTINCT FROM 'min_int' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', false, 'raison', 'reserve_au_ministre_de_l_interieur',
      'poste_reel', coalesce(v_poste, '(aucun)')));
  END IF;

  SELECT * INTO v_row FROM public.assemblee_propositions WHERE id = p_loi_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'introuvable'));
  END IF;
  IF v_row.country IS DISTINCT FROM v_perso.country THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'autre_pays'));
  END IF;

  -- 2. LA LOI EST-ELLE ADOPTEE ?
  IF v_row.statut <> 'adoptee' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', false, 'raison', 'non_adoptee', 'statut', v_row.statut));
  END IF;
  -- 3. Une loi declarative n'a rien a appliquer.
  IF NOT public.assemblee_exige_application(v_row.type) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', false, 'raison', 'type_sans_application', 'type', v_row.type));
  END IF;
  -- 4. Deux fois, jamais.
  IF v_row.appliquee_ts IS NOT NULL THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', false, 'raison', 'deja_appliquee', 'appliquee_ts', v_row.appliquee_ts));
  END IF;

  -- 5. APPLICATION. Le ministre n'a transmis qu'un identifiant : la portee votee
  --    reste celle de data.portee, relue par les gardes. Rien ne vient du client.
  UPDATE public.assemblee_propositions
     SET appliquee_ts = now(), appliquee_par = p_acteur
   WHERE id = p_loi_id
  RETURNING * INTO v_row;

  -- 6. UNE ABROGATION ETEINT SA CIBLE -- au moment de son application, pas de son
  --    adoption. Meme transaction : la cible cesse ses effets a l'instant ou
  --    l'abrogation prend les siens.
  IF v_row.type = 'abrogation' AND v_row.loi_cible_id IS NOT NULL THEN
    UPDATE public.assemblee_propositions
       SET statut = 'abrogee', abrogee_ts = now()
     WHERE id = v_row.loi_cible_id AND statut = 'adoptee' AND country = v_row.country
    RETURNING * INTO v_cible;
  END IF;

  RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
    'ok', true,
    'loi', jsonb_build_object('id', v_row.id, 'titre', v_row.titre, 'type', v_row.type,
                              'categorie', v_row.categorie,
                              'portee', coalesce(v_row.data -> 'portee', '{}'::jsonb),
                              'adoptee_ts', v_row.adoptee_ts, 'appliquee_ts', v_row.appliquee_ts),
    'cible_eteinte', CASE WHEN v_cible.id IS NULL THEN NULL
                          ELSE jsonb_build_object('id', v_cible.id, 'titre', v_cible.titre) END));
END;
$fn$;

comment on function public.assemblee_mettre_en_application(text, text, text) is
  'Mise en application d''une loi adoptee par le Ministre de l''Interieur EN FONCTION. Le client ne transmet QUE l''identifiant : le serveur verifie l''identite, le poste (lu en base), l''adoption, la non-application prealable, puis relit lui-meme la portee votee. Une abrogation eteint sa cible dans la meme transaction. Idempotente par cle de requete. Aucun parametre economique ne vient du navigateur.';

revoke all on function public.assemblee_mettre_en_application(text, text, text) from public, anon;
grant execute on function public.assemblee_mettre_en_application(text, text, text) to authenticated, service_role;

-- 6. LE REGISTRE D'EXECUTION -- CE QUE VOIT LE MINISTRE
create or replace function public.assemblee_registre_execution(p_country text default 'republic')
returns jsonb
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
  SELECT coalesce(jsonb_agg(s.ligne ORDER BY s.ordre, s.adoptee_ts DESC), '[]'::jsonb)
    FROM (
      SELECT
        CASE WHEN p.appliquee_ts IS NULL THEN 0 ELSE 1 END AS ordre,
        p.adoptee_ts AS adoptee_ts,
        jsonb_build_object(
          'id', p.id,
          'titre', p.titre,
          'type', p.type,
          'categorie', p.categorie,
          'auteur', p.auteur,
          'portee', coalesce(p.data -> 'portee', '{}'::jsonb),
          'adoptee_ts', p.adoptee_ts,
          'appliquee_ts', p.appliquee_ts,
          'appliquee_par', p.appliquee_par,
          'echeance_ts', public.assemblee_echeance_application(p.adoptee_ts),
          'etat', CASE WHEN p.appliquee_ts IS NOT NULL THEN 'appliquee'
                       WHEN now() >= public.assemblee_echeance_application(p.adoptee_ts) THEN 'en_retard'
                       ELSE 'en_attente' END,
          'loi_cible', CASE WHEN p.loi_cible_id IS NULL THEN NULL ELSE (
            SELECT jsonb_build_object('id', c.id, 'titre', c.titre, 'statut', c.statut)
              FROM public.assemblee_propositions c WHERE c.id = p.loi_cible_id) END,
          -- L'instant SERVEUR accompagne chaque ligne : le navigateur ne doit
          -- jamais decider du temps restant avec sa propre horloge.
          'maintenant', now()
        ) AS ligne
        FROM public.assemblee_propositions p
       WHERE p.country = p_country
         AND p.statut = 'adoptee'
         AND public.assemblee_exige_application(p.type)
    ) s;
$fn$;

comment on function public.assemblee_registre_execution(text) is
  'Registre du Ministre de l''Interieur : les lois adoptees qui exigent une mise en application (mecanique, abrogation), en attente d''abord puis appliquees. Porte l''etat, l''echeance (adoption + 36 h), la portee votee, la loi cible d''une abrogation, et l''instant SERVEUR. Les lois rp n''y figurent jamais : elles sont terminees des leur adoption.';

revoke all on function public.assemblee_registre_execution(text) from public, anon;
grant execute on function public.assemblee_registre_execution(text) to authenticated, service_role;

-- 7. GARDES
DO $garde$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname='public' AND p.proname = 'assemblee_deposer';
  IF n <> 1 THEN RAISE EXCEPTION 'assemblee_deposer : % signatures, 1 attendue', n; END IF;
  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname='public' AND p.proname = 'assemblee_deposer_projet';
  IF n <> 1 THEN RAISE EXCEPTION 'assemblee_deposer_projet : % signatures', n; END IF;

  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname='public' AND p.proname='assemblee_deposer'
     AND pg_get_functiondef(p.oid) LIKE '%assemblee_deposer_projet%';
  IF n <> 1 THEN RAISE EXCEPTION 'assemblee_deposer ne relaie pas'; END IF;

  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname='public' AND p.proname='assemblee_mettre_en_application'
     AND has_function_privilege('anon', p.oid, 'execute') = false
     AND has_function_privilege('authenticated', p.oid, 'execute') = true;
  IF n <> 1 THEN RAISE EXCEPTION 'droits inattendus sur assemblee_mettre_en_application'; END IF;

  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname='public' AND p.proname='assemblee_deposer_projet'
     AND pg_get_functiondef(p.oid) LIKE '%FROM public.assemblee_categories_interdiction%';
  IF n <> 1 THEN RAISE EXCEPTION 'assemblee_deposer_projet fige encore la liste des categories'; END IF;

  SELECT count(*) INTO n FROM public.assemblee_propositions WHERE id LIKE 'zzbanc-%';
  IF n <> 0 THEN RAISE EXCEPTION '% loi(s) de test en base', n; END IF;
END $garde$;