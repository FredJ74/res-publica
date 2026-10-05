-- =====================================================================
-- ASSEMBLEE NATIONALE — SECURISATION DES DROITS D'EXECUTION (correctif, 10 septembre 2026)
-- =====================================================================
-- A appliquer APRES migration_assemblee_nationale.sql (appliquee le 10/09/2026, version
-- 20260910212412). Rejouable : CREATE OR REPLACE, DROP ... IF EXISTS, REVOKE/GRANT idempotents.
--
-- CAUSE DU TROU DE SECURITE
-- migration_assemblee_nationale.sql cree 22 fonctions, dont 15 en SECURITY DEFINER (elles
-- s'executent avec les droits du proprietaire, postgres, et contournent donc la RLS), SANS aucun
-- REVOKE. Or Supabase accorde par defaut EXECUTE a anon et authenticated sur toute fonction creee
-- dans public (privileges par defaut du schema -- REVOKE ... FROM PUBLIC ne suffit PAS, voir le
-- meme piege documente dans migration_fonds_commerce.sql). La cle anon etant publique (committee
-- dans supabase.js), n'importe qui pouvait :
--   - cloturer un scrutin avant l'heure (assemblee_cloturer ne verifiait pas cloture_ts) ;
--   - reveiller tous les deputes (assemblee_reveil_minuit) ;
--   - ouvrir une session avec une cloture de son choix (p_cloture_ts fourni par l'appelant) ;
--   - endormir un depute sans PA, sans jet, sans arme (assemblee_endormir) ;
--   - retourner un depute en passant p_reussi=true (assemblee_marchander), et crediter la caisse
--     de son choix (p_caisse_key) ;
--   - fixer lui-meme le montant de son indemnite (assemblee_verser_indemnite, p_montant).
-- Et cron-assemblee.js appelait les RPC systeme avec cette meme cle anon : les proteger exigeait
-- donc aussi de changer l'identite du cron.
--
-- CE QUE FAIT CE FICHIER
--   1. OPERATIONS SYSTEME : EXECUTE retire a PUBLIC/anon/authenticated, accorde au seul
--      service_role (cle serveur Vercel, jamais exposee au navigateur -- meme mecanisme que
--      prelever_loyer_bail). Controles temporels ajoutes EN BASE, opposables au cron lui-meme :
--        - la cloture exige now() >= cloture_ts ;
--        - l'echeance d'une session est CALCULEE par la base (mercredi 22:00 Europe/Paris), plus
--          jamais recue en parametre ;
--        - l'ouverture n'est possible que dans la fenetre qui suit la cloture hebdomadaire ;
--        - le reveil de minuit ne reveille que les deputes endormis AVANT le dernier minuit Paris.
--   2. LECTURES PUBLIQUES : inchangees (occupation des sieges, eligibilite au depot, cle de
--      convocation -- cette derniere DOIT rester executable par anon : le trigger de preservation,
--      qui n'est pas SECURITY DEFINER, l'appelle sous l'identite de l'ecrivain).
--   3. ACTIONS JOUEUR : MISES EN QUARANTAINE (EXECUTE retire a anon/authenticated) en attendant
--      l'arbitrage d'architecture. Le jeu n'a aucune authentification : l'identite d'un PJ n'est
--      pas etablissable cote serveur, et PA/argent/inventaire/statistiques sont ecrits librement
--      par le client (policy allow_all sur personnages). Sans effet sur la production (acee977
--      n'appelle aucune de ces RPC) ; le code local 04c8220 est fail-closed et affiche
--      « Assemblee indisponible ».
--   4. search_path fige sur toutes les fonctions SECURITY DEFINER (hygiene standard).
-- =====================================================================


-- =====================================================================
-- 1. TEMPS PARLEMENTAIRE CALCULE PAR LA BASE
-- =====================================================================
-- Premiere echeance mercredi 22:00 Europe/Paris situee a plus de 24 h de l'instant de reference.
-- La marge de 24 h interdit une session ouverte quelques secondes avant 22:00 et close aussitot :
-- ouverte le mercredi soir (fenetre ci-dessous), une session dure toujours environ sept jours.
-- Calcul en heure locale Paris puis reconversion : correct de part et d'autre d'un changement
-- d'heure.
CREATE OR REPLACE FUNCTION public.assemblee_prochaine_cloture(p_depuis timestamptz)
RETURNS timestamptz
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $$
  WITH l AS (
    SELECT ((p_depuis + interval '1 day') AT TIME ZONE 'Europe/Paris') AS t
  ), c AS (
    SELECT t,
           date_trunc('day', t)
             + (((3 - extract(isodow FROM t)::int) + 7) % 7) * interval '1 day'
             + interval '22 hours' AS cand
      FROM l
  )
  SELECT (CASE WHEN cand > t THEN cand ELSE cand + interval '7 days' END) AT TIME ZONE 'Europe/Paris'
    FROM c;
$$;

-- Fenetre d'ouverture des sessions : du mercredi 22:00 au jeudi 23:59 Europe/Paris. Couvre le
-- declenchement du cron (21:00 UTC, soit 22:00 Paris l'hiver et 23:00 Paris l'ete) et laisse une
-- journee pour un rejeu manuel en cas d'incident. Hors fenetre, aucune session ne s'ouvre, meme
-- sur appel du service_role.
CREATE OR REPLACE FUNCTION public.assemblee_fenetre_ouverture(p_instant timestamptz)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT (extract(isodow FROM l) = 3 AND extract(hour FROM l) >= 22)
      OR  extract(isodow FROM l) = 4
    FROM (SELECT p_instant AT TIME ZONE 'Europe/Paris' AS l) x;
$$;


-- =====================================================================
-- 2. OUVERTURE DE SESSION : PLUS AUCUN HORAIRE FOURNI PAR L'APPELANT
-- =====================================================================
-- Anciennes signatures supprimees : elles recevaient p_cloture_ts de l'appelant. Aucune surcharge
-- n'est conservee, pour qu'aucun chemin ne puisse encore imposer son echeance.
DROP FUNCTION IF EXISTS public.assemblee_ouvrir_sessions_eligibles(timestamptz, text);
DROP FUNCTION IF EXISTS public.assemblee_ouvrir_session(text, timestamptz);

CREATE OR REPLACE FUNCTION public.assemblee_ouvrir_session(p_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row public.assemblee_propositions%ROWTYPE;
  v_num integer;
BEGIN
  -- Controle temporel en base, opposable a tout appelant, cron compris.
  IF NOT public.assemblee_fenetre_ouverture(now()) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_fenetre_ouverture');
  END IF;

  SELECT * INTO v_row FROM public.assemblee_propositions WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'introuvable');
  END IF;
  IF v_row.statut NOT IN ('debat', 'renvoyee') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'statut_incompatible');
  END IF;
  IF now() < v_row.eligible_session_ts THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'semaine_de_debat_non_ecoulee');
  END IF;

  v_num := v_row.session_num + 1;

  UPDATE public.assemblee_propositions
  SET statut = 'session',
      session_num = v_num,
      session_ouverte_ts = now(),
      cloture_ts = public.assemblee_prochaine_cloture(now())
  WHERE id = p_id
  RETURNING * INTO v_row;

  -- §27 : repartir de zero cote PJ. Les votes de la session precedente restent archives dans
  -- assemblee_scrutins ; ce sont les lignes de vote VIVES qui sont supprimees.
  DELETE FROM public.assemblee_votes
  WHERE proposition_id = p_id AND session_num < v_num;

  -- Intention 50/50 pour chaque siege actuellement tenu par son PNJ. Tirage SERVEUR.
  INSERT INTO public.assemblee_intentions (id, proposition_id, session_num, siege_id, intention)
  SELECT
    p_id || ':' || v_num || ':' || o.siege_id,
    p_id, v_num, o.siege_id,
    CASE WHEN random() < 0.5 THEN 'POUR' ELSE 'CONTRE' END
  FROM public.assemblee_occupation_sieges(v_row.country) o
  WHERE o.est_pnj
  ON CONFLICT (id) DO NOTHING;

  RETURN jsonb_build_object('ok', true, 'proposition', to_jsonb(v_row), 'session_num', v_num);
END;
$$;

CREATE OR REPLACE FUNCTION public.assemblee_ouvrir_sessions_eligibles(p_country text DEFAULT 'republic')
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_res  jsonb := '[]'::jsonb;
  v_prop record;
BEGIN
  IF NOT public.assemblee_fenetre_ouverture(now()) THEN
    RETURN jsonb_build_array(jsonb_build_object('ok', false, 'raison', 'hors_fenetre_ouverture'));
  END IF;

  FOR v_prop IN
    SELECT id FROM public.assemblee_propositions
    WHERE country = p_country
      AND statut IN ('debat', 'renvoyee')
      AND now() >= eligible_session_ts
    ORDER BY depose_ts
  LOOP
    v_res := v_res || jsonb_build_array(
      public.assemblee_ouvrir_session(v_prop.id) || jsonb_build_object('id', v_prop.id)
    );
  END LOOP;
  RETURN v_res;
END;
$$;


-- =====================================================================
-- 3. CLOTURE : L'ECHEANCE EST VERIFIEE PAR LA FONCTION ELLE-MEME
-- =====================================================================
-- Seul changement par rapport a la version d'origine : le bloc « Garde temporelle ». Avant, seule
-- assemblee_cloturer_echues filtrait sur cloture_ts ; assemblee_cloturer, appelee directement,
-- depouillait a n'importe quel moment.
CREATE OR REPLACE FUNCTION public.assemblee_cloturer(p_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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

  -- Garde temporelle (correctif) : jamais de depouillement avant l'echeance, quel que soit
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

    -- §32/§33 : une abrogation adoptee eteint sa cible IMMEDIATEMENT, meme transaction.
    IF v_row.type = 'abrogation' THEN
      UPDATE public.assemblee_propositions
      SET statut = 'abrogee', abrogee_ts = now()
      WHERE id = v_row.loi_cible_id AND statut = 'adoptee';
    END IF;

  ELSIF v_resultat = 'REJETEE' THEN
    UPDATE public.assemblee_propositions SET statut = 'rejetee' WHERE id = p_id;
  ELSE
    -- §27 : renvoi. Le projet reste vivant ; ses votes PJ seront effaces et les intentions
    -- rerollees a l'ouverture de la session suivante (assemblee_ouvrir_session). eligible_
    -- session_ts n'est pas repousse : la semaine de debat a deja ete purgee une fois.
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
    'loi_cible_id', v_row.loi_cible_id
  );
END;
$$;


-- =====================================================================
-- 4. REVEIL DE MINUIT : SEULS LES DEPUTES ENDORMIS AVANT LE DERNIER MINUIT PARIS
-- =====================================================================
-- §24 : un depute assomme se reveille « a minuit ». Celui qu'on a endormi a 00:30 n'a pas encore
-- passe minuit : il dort jusqu'a la nuit suivante. La regle est donc portee par l'instant du
-- dernier minuit Europe/Paris, et non par l'heure d'appel : un appel en pleine journee ne reveille
-- personne qui ait ete endormi le jour meme, et le decalage ete/hiver du cron (0 23 * * * UTC)
-- reste sans consequence.
CREATE OR REPLACE FUNCTION public.assemblee_reveil_minuit(p_country text DEFAULT 'republic')
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_n      integer;
  v_minuit timestamptz;
BEGIN
  v_minuit := date_trunc('day', now() AT TIME ZONE 'Europe/Paris') AT TIME ZONE 'Europe/Paris';

  UPDATE public.assemblee_sieges
  SET endormi = false, endormi_ts = NULL, endormi_par = NULL, updated_at = now()
  WHERE country = p_country
    AND endormi = true
    AND (endormi_ts IS NULL OR endormi_ts < v_minuit);
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$$;


-- =====================================================================
-- 5. DROITS D'EXECUTION
-- =====================================================================
-- Rappel du piege : REVOKE ... FROM PUBLIC ne retire PAS les droits accordes a anon et
-- authenticated par les privileges par defaut de Supabase. Chaque REVOKE nomme donc les trois.

-- 5.1 OPERATIONS SYSTEME / CRON / PRIMITIVES INTERNES — service_role uniquement
REVOKE ALL ON FUNCTION public.assemblee_ouvrir_session(text)                      FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_ouvrir_sessions_eligibles(text)           FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_cloturer(text)                            FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_cloturer_echues(text)                     FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_reveil_minuit(text)                       FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_marquer_convocations_echues(text)         FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_crediter_caisse(text, integer)            FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_debiter_caisse_plafonne(text, integer)    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_prochaine_cloture(timestamptz)            FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_fenetre_ouverture(timestamptz)            FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.assemblee_ouvrir_session(text)                   TO service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_ouvrir_sessions_eligibles(text)        TO service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_cloturer(text)                         TO service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_cloturer_echues(text)                  TO service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_reveil_minuit(text)                    TO service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_marquer_convocations_echues(text)      TO service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_crediter_caisse(text, integer)         TO service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_debiter_caisse_plafonne(text, integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_prochaine_cloture(timestamptz)         TO service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_fenetre_ouverture(timestamptz)         TO service_role;

-- 5.2 FONCTIONS DE TRIGGER — jamais appelables en RPC. Le droit EXECUTE n'est verifie qu'a la
-- creation du trigger, pas a son declenchement : les ecritures de anon sur personnages et
-- assemblee_propositions continuent de les declencher (verifie apres application).
REVOKE ALL ON FUNCTION public.assemblee_proposition_immuable()                    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.personnages_preserver_judiciaire()                  FROM PUBLIC, anon, authenticated;

-- 5.3 LECTURES REELLEMENT PUBLIQUES — inchangees, explicites
GRANT EXECUTE ON FUNCTION public.assemblee_occupation_sieges(text)                TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_peut_deposer(text, text)               TO anon, authenticated, service_role;
-- Appelee par personnages_preserver_judiciaire, qui s'execute sous l'identite de l'ecrivain :
-- la retirer a anon ferait echouer TOUTE sauvegarde de personnage. Fonction pure, sans effet.
GRANT EXECUTE ON FUNCTION public.assemblee_cle_convocation(jsonb)                 TO anon, authenticated, service_role;

-- 5.4 ACTIONS JOUEUR — QUARANTAINE en attente de l'arbitrage d'architecture (voir en-tete).
REVOKE ALL ON FUNCTION public.assemblee_deposer(text, text, text, text, text, text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_amender(text, text, text)                 FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_retirer(text, text)                       FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_voter(text, text, text)                   FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_marchander(text, text, text, boolean, integer, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_endormir(text, text)                      FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_reveiller(text)                           FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_verser_indemnite(text, text, integer)     FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_tracer_vente_interdite(text, text, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.assemblee_deposer(text, text, text, text, text, text, text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_amender(text, text, text)              TO service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_retirer(text, text)                    TO service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_voter(text, text, text)                TO service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_marchander(text, text, text, boolean, integer, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_endormir(text, text)                   TO service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_reveiller(text)                        TO service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_verser_indemnite(text, text, integer)  TO service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_tracer_vente_interdite(text, text, text, text) TO service_role;


-- =====================================================================
-- 6. search_path FIGE SUR LES FONCTIONS SECURITY DEFINER RESTANTES
-- =====================================================================
-- Les corps n'utilisent que des noms qualifies public.* : aucun changement de comportement.
ALTER FUNCTION public.assemblee_deposer(text, text, text, text, text, text, text, text) SET search_path = public, pg_temp;
ALTER FUNCTION public.assemblee_amender(text, text, text)                         SET search_path = public, pg_temp;
ALTER FUNCTION public.assemblee_retirer(text, text)                               SET search_path = public, pg_temp;
ALTER FUNCTION public.assemblee_voter(text, text, text)                           SET search_path = public, pg_temp;
ALTER FUNCTION public.assemblee_marchander(text, text, text, boolean, integer, text) SET search_path = public, pg_temp;
ALTER FUNCTION public.assemblee_endormir(text, text)                              SET search_path = public, pg_temp;
ALTER FUNCTION public.assemblee_reveiller(text)                                   SET search_path = public, pg_temp;
ALTER FUNCTION public.assemblee_cloturer_echues(text)                             SET search_path = public, pg_temp;
ALTER FUNCTION public.assemblee_verser_indemnite(text, text, integer)             SET search_path = public, pg_temp;
ALTER FUNCTION public.assemblee_tracer_vente_interdite(text, text, text, text)    SET search_path = public, pg_temp;
ALTER FUNCTION public.assemblee_marquer_convocations_echues(text)                 SET search_path = public, pg_temp;
ALTER FUNCTION public.assemblee_crediter_caisse(text, integer)                    SET search_path = public, pg_temp;
ALTER FUNCTION public.assemblee_debiter_caisse_plafonne(text, integer)            SET search_path = public, pg_temp;

-- =====================================================================
-- FIN
-- =====================================================================
