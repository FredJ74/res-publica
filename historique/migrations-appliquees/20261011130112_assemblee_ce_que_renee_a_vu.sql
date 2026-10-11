-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261011130112 (UTC), nom `assemblee_ce_que_renee_a_vu`.
-- Le registre passe de 647 a 648 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 603bda35214d180842ffaf858b5188e4, 16506 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- UNE PORTE QUI DIT AUSSI CE QU'ELLE NE SAIT PAS
--
-- Renee Toitout est l'agente d'entretien de l'Assemblee nationale. Elle circule dans le
-- batiment pendant que les autres parlent, et personne ne fait attention a elle. Cette
-- migration lui donne de quoi raconter ce qu'elle a vu -- et RIEN de plus.
-- ELLE NE CREE AUCUNE SURVEILLANCE. Pas de table neuve, pas de journalisation neuve, pas de
-- mouchard : la porte est STABLE, en lecture seule, et une preuve structurelle verifie qu'elle
-- n'ecrit nulle part. Elle lit trois sources qui existaient deja -- le journal des passages,
-- les neuf sieges, les scrutins clos.
-- LA SOURCE EST ATTESTEE, et c'est ce qui change tout par rapport a la chronique nationale
-- debranchee le matin meme : `historique_deplacements` est sous RLS SANS policy, SANS aucun
-- droit accorde a anon ni a authenticated -- le navigateur ne peut ni l'ecrire ni la lire -- et
-- la porte qui l'alimente derive l'identite de `mon_personnage()`. Un joueur ne peut inscrire
-- que SON passage ; il ne peut pas fabriquer la presence d'un autre pour la faire raconter.
-- ELLE CONSTATE, ELLE N'ENQUETE PAS. La porte rend des faits : qui est passe, combien de fois,
-- dans quelles pieces, quand, et qui s'est trouve la EN MEME TEMPS. Aucune conclusion : ni
-- negociation de vote, ni corruption, ni complot, ni contenu de conversation. Aucune donnee du
-- jeu ne permettrait de l'etablir, et on n'en fabrique pas une.
-- ET ELLE DIT CE QU'ELLE NE SAIT PAS -- `rien_a_signaler` et `aucun_scrutin`. C'est le point le
-- plus important : sans ces deux drapeaux, un silence se raconterait comme une anecdote
-- inventee. AUCUN SCRUTIN N'A JAMAIS ETE CLOS en beta, donc l'assiduite des deputes n'est PAS
-- etablissable aujourd'hui ; la donnee existerait (`non_votants`, `endormis`) mais l'historique
-- est vide.
-- L'HOTESSE D'ACCUEIL entre au registre des referents : elle est la referente PEDAGOGIQUE de
-- l'Assemblee. Renee n'y entre PAS, deliberement : elle n'enseigne rien, et une memoire
-- pedagogique appliquee a des confidences compterait des sujets qui n'en sont pas.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =================================================================================================
-- CE QUE RENEE A VU, ET RIEN DE PLUS (11 octobre 2026)
-- =================================================================================================
-- RENEE TOITOUT est l'agente d'entretien de l'Assemblee nationale. Elle passe ses journees dans le
-- batiment, elle travaille pendant que les autres parlent, et personne ne fait attention a elle.
-- Quand un joueur prend la peine de lui parler, elle raconte ce qu'elle a vu.
--
-- CETTE PORTE NE FABRIQUE AUCUNE SURVEILLANCE NOUVELLE, et c'est sa regle principale. Elle ne cree
-- aucune table, aucune journalisation, aucun mouchard. Elle LIT trois sources qui existaient deja :
--
--   `historique_deplacements`  le journal des passages, deja ecrit par `deplacement_enregistrer`.
--                              CETTE TABLE EST ATTESTEE : RLS active, AUCUNE policy, AUCUN droit
--                              accorde a anon ni a authenticated -- le navigateur ne peut donc ni
--                              l'ecrire ni la lire -- et la porte qui l'alimente derive l'identite
--                              de `mon_personnage()`. Un joueur ne peut inscrire que SON passage.
--                              C'est exactement ce qui manquait a `chronique_nationale`, dont la
--                              memoire presidentielle a du etre debranchee le matin meme.
--   `assemblee_sieges`         les neuf sieges et leurs deputes PNJ, avec l'etat `endormi`.
--   `assemblee_scrutins`       le depouillement nominatif des scrutins CLOS : qui a vote quoi, qui
--                              n'a pas vote, qui dormait.
--
-- ELLE CONSTATE, ELLE N'ENQUETE PAS. La porte ne rend que des FAITS : qui est passe, combien de
-- fois, dans quelles pieces, quand, et qui s'est trouve la EN MEME TEMPS. Elle ne rend aucune
-- conclusion : pas de negociation de vote, pas de corruption, pas de complot, pas de contenu de
-- conversation. Il n'existe dans tout le jeu AUCUNE donnee qui permettrait de l'etablir, et on
-- n'en fabrique pas une.
--
-- CE QU'ELLE NE PEUT PAS SAVOIR AUJOURD'HUI, ET QUI EST RENDU EXPLICITEMENT :
--   . L'ASSIDUITE DES DEPUTES. La donnee existerait -- `assemblee_scrutins` archive `non_votants`
--     et `endormis` a chaque cloture -- mais AUCUN SCRUTIN N'A JAMAIS ETE CLOS. La porte rend donc
--     `aucun_scrutin: true`, et Renee dit qu'elle n'a pas encore vu voter. Elle ne deduit pas une
--     assiduite d'un historique vide.
--   . LA PRESENCE PHYSIQUE DES PNJ. `historique_deplacements` n'enregistre que les joueurs : les
--     deputes PNJ ne se deplacent pas, ils occupent un siege. Renee les voit a leur place, elle ne
--     peut pas raconter leurs allees et venues.
-- =================================================================================================

CREATE OR REPLACE FUNCTION public.assemblee_regards(p_jours integer DEFAULT 7)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_jour integer;
  v_fen integer := least(greatest(coalesce(p_jours, 7), 1), 30);
  v_depuis integer; v_scrutins jsonb; v_passages jsonb; v_ensemble jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  -- LE PAYS N'EST PAS RECU DU NAVIGATEUR, il est relu en base : une Renee de Republia ne raconte
  -- pas ce qui s'est passe dans l'Assemblee d'un autre empire. Meme regle que
  -- `presidence_memoire_mon_pays`, posee le matin meme pour exactement ce motif.
  SELECT coalesce(country, 'republic'), coalesce(day, 1) INTO v_pays, v_jour
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pays_inconnu');
  END IF;
  v_depuis := greatest(v_jour - v_fen, 0);

  -- LES SCRUTINS CLOS. Nominatifs, tels que la cloture du mercredi les a archives.
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'titre', s.titre, 'resultat', s.resultat, 'session', s.session_num,
           'pour', s.pour, 'contre', s.contre, 'abstention', s.abstention,
           'non_votants', s.non_votants, 'endormis', s.endormis,
           'clos_le', s.cloture_ts) ORDER BY s.cloture_ts DESC), '[]'::jsonb)
    INTO v_scrutins
    FROM (SELECT * FROM public.assemblee_scrutins WHERE country = v_pays
           ORDER BY cloture_ts DESC LIMIT 5) s;

  -- LES PASSAGES. Un joueur, le nombre de fois qu'il est entre, les pieces ou Renee l'a croise, et
  -- la derniere fois. `poste_actuel` est son poste AUJOURD'HUI -- pas necessairement celui qu'il
  -- avait ce jour-la : le journal des passages ne garde pas la fonction du moment.
  --
  -- `raison_institutionnelle` N'EST PAS UN JUGEMENT : c'est la reponse a une question factuelle --
  -- cette personne a-t-elle une raison officielle de venir ici ? La liste est celle que
  -- `assemblee_peut_deposer` applique reellement (depute, Premier ministre, ministres), plus
  -- l'appartenance a un groupe de presse, qui est le titre du correspondant parlementaire. Le
  -- President n'y figure pas, et ce n'est pas un oubli : il n'est pas eligible au depot.
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'qui', q.name, 'passages', q.n, 'pieces', q.pieces,
           'dernier_jour', q.dernier_jour, 'derniere_heure', q.derniere_heure,
           'poste_actuel', q.poste_actuel,
           'raison_institutionnelle', q.raison) ORDER BY q.n DESC, q.name), '[]'::jsonb)
    INTO v_passages
    FROM (
      SELECT h.name, count(*)::int AS n,
             (SELECT jsonb_agg(DISTINCT h2.room_id) FROM public.historique_deplacements h2
               WHERE h2.country = v_pays AND h2.building_id = 'assemblee'
                 AND h2.jour >= v_depuis AND h2.name = h.name) AS pieces,
             max(h.jour) AS dernier_jour,
             (SELECT h3.heure FROM public.historique_deplacements h3
               WHERE h3.country = v_pays AND h3.building_id = 'assemblee' AND h3.name = h.name
               ORDER BY h3.created_at DESC LIMIT 1) AS derniere_heure,
             (SELECT coalesce(pd.poste->>'id', pd.poste_depute->>'id')
                FROM public.personnages_donnees pd WHERE pd.name = h.name) AS poste_actuel,
             (SELECT coalesce((pd.poste_depute->>'id') = 'depute', false)
                  OR coalesce((pd.poste->>'id') IN ('pm','min_int','min_fin','min_just',
                                                    'min_def','min_info','min_ae'), false)
                  OR EXISTS (SELECT 1 FROM public.presse_membres m
                               JOIN public.groupes_presse g ON g.id = m.groupe_id
                              WHERE m.personnage = h.name AND g.pays = v_pays)
                FROM public.personnages_donnees pd WHERE pd.name = h.name) AS raison
        FROM public.historique_deplacements h
       WHERE h.country = v_pays AND h.building_id = 'assemblee' AND h.jour >= v_depuis
       GROUP BY h.name) q;

  -- CEUX QUI S'Y SONT TROUVES EN MEME TEMPS. Meme jour, meme heure, meme batiment : c'est tout ce
  -- que le journal permet de dire, et c'est deja une observation. Le couple est ordonne pour qu'une
  -- rencontre ne soit pas comptee deux fois.
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'qui_a', c.a, 'qui_b', c.b, 'fois', c.fois,
           'dernier_jour', c.dernier_jour) ORDER BY c.fois DESC, c.a, c.b), '[]'::jsonb)
    INTO v_ensemble
    FROM (
      SELECT x.name AS a, y.name AS b, count(DISTINCT (x.jour || ':' || x.heure))::int AS fois,
             max(x.jour) AS dernier_jour
        FROM public.historique_deplacements x
        JOIN public.historique_deplacements y
          ON y.country = x.country AND y.building_id = x.building_id
         AND y.jour = x.jour AND y.heure = x.heure AND y.name > x.name
       WHERE x.country = v_pays AND x.building_id = 'assemblee' AND x.jour >= v_depuis
       GROUP BY x.name, y.name) c;

  RETURN jsonb_build_object(
    'ok', true, 'pays', v_pays, 'jour', v_jour, 'fenetre_jours', v_fen,
    -- LES NEUF SIEGES, tels qu'ils sont occupes. Un depute endormi se voit : c'est une observation
    -- legitime pour qui passe la serpilliere entre les rangees.
    'deputes', (SELECT coalesce(jsonb_agg(jsonb_build_object(
          'ville', s.city, 'rang', s.rang, 'nom', s.pnj_nom, 'endormi', s.endormi)
          ORDER BY s.city, s.rang), '[]'::jsonb)
        FROM public.assemblee_sieges s WHERE s.country = v_pays),
    'scrutins', v_scrutins,
    -- AUCUN SCRUTIN CLOS : l'assiduite des deputes n'est donc PAS etablissable, et la porte le dit
    -- au lieu de laisser deviner. C'est ce drapeau qui empeche d'inventer une habitude.
    'aucun_scrutin', (jsonb_array_length(v_scrutins) = 0),
    'passages', v_passages,
    'ensemble', v_ensemble,
    -- RIEN A SIGNALER EST UNE REPONSE VALIDE, et meme la plus frequente. Sans ce drapeau, un
    -- silence se raconterait comme une anecdote inventee.
    'rien_a_signaler', (jsonb_array_length(v_passages) = 0 AND jsonb_array_length(v_ensemble) = 0
                        AND jsonb_array_length(v_scrutins) = 0));
END;
$function$;

REVOKE ALL ON FUNCTION public.assemblee_regards(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.assemblee_regards(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assemblee_regards(integer) TO service_role;

COMMENT ON FUNCTION public.assemblee_regards(integer) IS
  'Ce que l agente d entretien de l Assemblee a pu VOIR : les passages des joueurs dans le batiment, ceux qui s y sont trouves en meme temps, les neuf sieges et leur etat, et le depouillement nominatif des scrutins clos. Lecture seule, sur des tables qui existaient deja -- aucune surveillance nouvelle. Ne rend AUCUNE conclusion : ni negociation, ni corruption, ni complot, ni contenu de conversation. Deux drapeaux disent ce qui n est pas etablissable : aucun_scrutin et rien_a_signaler (arbitrage du 11 octobre 2026).';

-- -------------------------------------------------------------------------------------------------
-- L'HOTESSE D'ACCUEIL ENTRE DANS LE REGISTRE DES REFERENTS
-- -------------------------------------------------------------------------------------------------
-- Elle est la REFERENTE PEDAGOGIQUE de l'Assemblee : son metier est de rendre l'institution
-- comprehensible. Elle rejoint donc la liste fermee qui autorise la memoire pedagogique, comme
-- Martial Bouterin, Tom Hawak et les cinq secretaires ministeriels.
--
-- RENEE N'Y ENTRE PAS, ET C'EST DELIBERE. Elle n'enseigne rien : elle raconte ce qu'elle a vu. La
-- memoire pedagogique compte les sujets DEJA EXPLIQUES a un joueur ; appliquee a Renee, elle
-- compterait des confidences, ce qui n'a pas de sens. Son interet vient des faits attestes, pas
-- d'une progression.
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES
  ('hotesse_accueil', 'Assemblee nationale — procedure parlementaire, calendrier, ce qu on peut y faire', 'republic')
ON CONFLICT (referent_id) DO UPDATE SET domaine = EXCLUDED.domaine, pays = EXCLUDED.pays;

-- -------------------------------------------------------------------------------------------------
-- PREUVES STRUCTURELLES
-- -------------------------------------------------------------------------------------------------
DO $$
DECLARE v_n integer;
BEGIN
  -- P1 : LA PORTE EST EN LECTURE SEULE. Une fonction STABLE ne peut pas ecrire : c'est PostgreSQL
  -- qui le garantit, pas une relecture humaine.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_regards' AND p.provolatile = 's';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P1 : assemblee_regards n est pas STABLE'; END IF;

  -- P2 : AUCUNE TABLE NEUVE, AUCUNE JOURNALISATION NEUVE. La porte ne lit que des tables qui
  -- existaient avant elle. Si quelqu'un y ajoute un INSERT, cette preuve tombe.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_regards'
     AND (p.prosrc ~* '(^|[^a-z_])insert into' OR p.prosrc ~* '(^|[^a-z_])update '
       OR p.prosrc ~* '(^|[^a-z_])delete from');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P2 : assemblee_regards ecrit quelque part'; END IF;

  -- P3 : LE JOURNAL DES PASSAGES EST ATTESTE. RLS active, aucune policy, et aucun droit pour les
  -- roles clients : le navigateur ne peut ni l'ecrire ni le lire. C'est ce qui distingue cette
  -- source de `chronique_nationale`, debranchee de la memoire presidentielle le matin meme.
  SELECT count(*) INTO v_n FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relname = 'historique_deplacements' AND c.relrowsecurity;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P3a : historique_deplacements n est pas sous RLS'; END IF;
  SELECT count(*) INTO v_n FROM pg_policies
   WHERE schemaname = 'public' AND tablename = 'historique_deplacements';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P3b : % policy sur le journal des passages', v_n; END IF;
  SELECT count(*) INTO v_n FROM information_schema.role_table_grants
   WHERE table_schema = 'public' AND table_name = 'historique_deplacements'
     AND grantee IN ('anon', 'authenticated');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P3c : % droit(s) client sur le journal des passages', v_n; END IF;

  -- P4 : ET CELUI QUI L'ALIMENTE DERIVE L'IDENTITE DU SERVEUR. Un joueur ne peut inscrire que son
  -- propre passage ; il ne peut pas fabriquer la presence d'un autre pour la faire raconter.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'deplacement_enregistrer'
     AND p.prosrc LIKE '%mon_personnage()%';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P4 : deplacement_enregistrer ne derive pas l identite du serveur'; END IF;

  -- P5 : AUCUN CHAMP DE CONCLUSION. Ni negociation, ni corruption, ni complot, ni soupcon : la
  -- porte rend des constats. Les mots sont cherches HORS des lignes de commentaire, qui ont le
  -- droit de les nommer pour dire qu'ils sont interdits -- lecon du 11 octobre sur prosrc.
  SELECT count(*) INTO v_n FROM (
    SELECT string_agg(l, E'\n') AS corps FROM (
      SELECT l FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace,
           regexp_split_to_table(p.prosrc, E'\n') AS l
       WHERE n.nspname = 'public' AND p.proname = 'assemblee_regards'
         AND l !~ '^[[:space:]]*--') z) q
   WHERE q.corps ~* '(negoci|corrupt|complot|soupcon|suspect|intention_de|achat_de_vote)';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P5 : un champ de conclusion est apparu dans assemblee_regards'; END IF;

  -- P6 : LES DEUX DRAPEAUX D'ABSENCE EXISTENT. Sans eux, un silence se raconterait comme une
  -- anecdote inventee -- c'est le point le plus important de l'arbitrage.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_regards'
     AND p.prosrc LIKE '%aucun_scrutin%' AND p.prosrc LIKE '%rien_a_signaler%';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P6 : les drapeaux d absence manquent'; END IF;

  -- P7 : LE PAYS N'EST PAS UN PARAMETRE. La porte le relit en base : une Renee de Republia ne
  -- raconte pas l'Assemblee d'un autre empire.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_regards'
     AND p.pronargs = 1
     AND pg_get_function_identity_arguments(p.oid) = 'p_jours integer';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P7 : assemblee_regards accepte autre chose qu une fenetre'; END IF;

  -- P8 : L'HOTESSE EST DECLAREE REFERENTE, ET RENEE NE L'EST PAS.
  SELECT count(*) INTO v_n FROM public.pnj_referents WHERE referent_id = 'hotesse_accueil';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P8a : l hotesse n est pas declaree referente'; END IF;
  SELECT count(*) INTO v_n FROM public.pnj_referents WHERE referent_id = 'renee_toitout';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P8b : Renee a ete declaree referente pedagogique'; END IF;

  -- P9 : les neuf sieges sont toujours la, et c'est ce que Renee voit en passant.
  SELECT count(*) INTO v_n FROM public.assemblee_sieges WHERE country = 'republic';
  IF v_n <> 9 THEN RAISE EXCEPTION 'P9 : % sieges au lieu de 9', v_n; END IF;

  RAISE NOTICE 'Ce que Renee a vu : les 9 preuves structurelles passent.';
END $$;
