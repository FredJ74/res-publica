-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261011011638 (UTC), nom `communication_officielle_autorite_de_salle`.
-- Le registre passe de 645 a 643 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 ed9436ad9f192c30433645ce44622ac7, 13460 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LA SALLE DE PRESSE DU GOUVERNEMENT N'AVAIT PAS LA BONNE AUTORITE, ET ELLE N'ETAIT PAS AU SERVEUR
--
-- Constate en jouant : la conference de presse du Palais du Gouvernement refusait de publier avec
-- « Seul le President peut publier depuis la tribune presidentielle ». Trois defauts superposes.
--
-- 1. LE VERROU ETAIT LE MAUVAIS. `publierMessagePresidentiel` appelait exigerPoste('president')
--    EN DUR, sans regarder de quelle salle venait l'ordre -- alors que data.js declare les trois
--    ordres du Gouvernement avec `requiresPost: true`, soit « un titulaire, lequel qu'il soit ».
--    La declaration etait juste ; le handler la contredisait. AUCUN ministre n'a jamais pu
--    s'exprimer depuis cette tribune.
--
-- 2. LE VERROU ETAIT CLIENT. exigerPoste est une fonction du navigateur : meme corrigee, une
--    console suffisait a publier au nom du Gouvernement sans tenir aucun poste.
--
-- 3. RIEN N'ETAIT ATOMIQUE. Les PA partaient par payer_ordre, puis le sujet et le message par
--    deux appels REST separes : on pouvait payer sa conference et n'avoir ni sujet ni message.
--
-- UN REGISTRE PLUTOT QU'UN `IF`. (batiment, piece) -> postes admis : l'Elysee reste au President,
-- le Gouvernement s'ouvre au Premier ministre et aux sept ministres. Ouvrir une tribune ailleurs
-- est une ligne de table.
--
-- ET AUCUN MONTANT N'A ETE TOUCHE. L'arbitrage veut que le budget du ministere de l'Information
-- finance ces prises de parole ; le code preleve aujourd'hui sur la poche du responsable. Les deux
-- ne disent pas la meme chose. On ne tranche pas un tarif dans une migration d'autorite :
-- l'ecart est consigne dans la note du registre, en attente d'arbitrage.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =================================================================================================
-- LA SALLE DE PRESSE A UNE AUTORITE, ET ELLE EST AU SERVEUR (11 octobre 2026)
-- =================================================================================================
-- CE QUI A ETE CONSTATE EN JOUANT. Dans la salle de presse du PALAIS DU GOUVERNEMENT, l'ordre
-- « Conference de presse » refusait de publier avec le message « Seul le President peut publier
-- depuis la tribune presidentielle ». Trois defauts se superposaient :
--
--   1. LE VERROU ETAIT LE MAUVAIS. `publierMessagePresidentiel` appelait
--      `exigerPoste('president')` en dur, sans regarder DE QUELLE SALLE l'ordre venait. Or les
--      deux salles de presse du jeu partagent les memes noms d'ordre -- conference_presse,
--      propagande_etat, dementi -- et data.js declare celles du Gouvernement avec
--      `requiresPost: true`, c'est-a-dire « un titulaire, lequel qu'il soit ». La declaration
--      etait donc deja juste ; c'est le handler qui la contredisait. Resultat : AUCUN ministre
--      n'a jamais pu s'exprimer depuis la tribune du Gouvernement.
--
--   2. LE VERROU ETAIT CLIENT. `exigerPoste` est une fonction du navigateur. Meme corrige, il
--      aurait suffi d'une console pour publier au nom du Gouvernement sans tenir aucun poste.
--      L'autorite d'une prise de parole officielle ne peut pas vivre dans le navigateur.
--
--   3. RIEN N'ETAIT ATOMIQUE. Les PA partaient par `payer_ordre`, puis le sujet et le message
--      etaient inseres par deux appels REST separes : un joueur pouvait payer sa conference et
--      n'avoir ni sujet, ni message.
--
-- CETTE MIGRATION POSE LA PORTE QUI MANQUAIT, et rien de plus :
--   . un REGISTRE des salles de parole officielle -- (batiment, piece) -> postes admis. L'Elysee
--     reste au President, le Gouvernement s'ouvre au Premier ministre et aux ministres. Ajouter
--     une salle, ou en changer les titulaires, est une ligne de table et non du code ;
--   . une PORTE UNIQUE qui verifie l'autorite en base, preleve le cout par le chemin atteste, et
--     ecrit le sujet ET le message dans la MEME transaction.
--
-- CE QU'ELLE NE FAIT PAS, ET C'EST DELIBERE. Elle ne change AUCUN montant. L'arbitrage veut que
-- la communication gouvernementale soit financee par le budget du ministere de l'Information ;
-- aujourd'hui le code prend les 500 FR de la propagande sur la POCHE du responsable, via
-- payer_ordre. Les deux ne disent pas la meme chose. On ne tranche pas un tarif dans une
-- migration d'autorite : l'ecart est consigne dans la note du registre, et le cout reste
-- exactement celui qui est declare au miroir.
-- =================================================================================================

-- -------------------------------------------------------------------------------------------------
-- 1. LE REGISTRE DES SALLES DE PAROLE OFFICIELLE
-- -------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.communications_salles (
  building_id text NOT NULL,
  room_id     text NOT NULL,
  postes      text[] NOT NULL,
  forum_id    text NOT NULL,
  libelle     text NOT NULL,
  note        text,
  PRIMARY KEY (building_id, room_id),
  CONSTRAINT communications_postes_non_vides CHECK (array_length(postes, 1) >= 1)
);

COMMENT ON TABLE public.communications_salles IS
  'Qui peut prendre la parole officiellement, et depuis quelle piece. Registre d autorite du meme genre que caisses_autorites : c est lui qui distingue la tribune presidentielle de celle du Gouvernement, alors que les deux portent les memes noms d ordre (arbitrage du 11 octobre 2026).';

INSERT INTO public.communications_salles (building_id, room_id, postes, forum_id, libelle, note) VALUES
  ('palais-presidentiel', 'salle_presse_elysee', ARRAY['president'],
   'presidence', 'la tribune presidentielle',
   'Le President, et lui seul. Il a sa propre maison et sa propre tribune : il n est PAS le titulaire privilegie de la salle du Gouvernement.'),
  ('palais-gouvernement', 'salle_presse',
   ARRAY['pm','min_int','min_fin','min_just','min_def','min_info','min_ae'],
   'presidence', 'la tribune du Gouvernement',
   'Le Premier ministre et les SEPT ministres du Gouvernement. Le President n y figure pas, et ce n est pas un oubli. ECART DE COUT CONSIGNE ET NON TRANCHE : l arbitrage veut que le budget du ministere de l Information finance ces prises de parole, alors que payer_ordre preleve aujourd hui sur la bourse personnelle du responsable. Aucun montant n a ete modifie ici.')
ON CONFLICT (building_id, room_id) DO UPDATE
   SET postes = EXCLUDED.postes, forum_id = EXCLUDED.forum_id,
       libelle = EXCLUDED.libelle, note = EXCLUDED.note;

ALTER TABLE public.communications_salles ENABLE ROW LEVEL SECURITY;

-- -------------------------------------------------------------------------------------------------
-- 2. LA PORTE UNIQUE
-- -------------------------------------------------------------------------------------------------
-- TOUT DANS LA MEME TRANSACTION : autorite, prelevement, sujet, message. Un refus n'ecrit rien et
-- ne preleve rien ; un succes laisse les quatre.
--
-- LE COUT PASSE PAR payer_ordre, et c'est voulu : c'est elle qui valide le triplet (fn, pa, cost)
-- contre le miroir de data.js. Un navigateur ne peut donc pas annoncer une conference gratuite.
CREATE OR REPLACE FUNCTION public.communication_officielle_publier(
  p_building_id text, p_room_id text, p_fn text, p_pa integer, p_cost integer,
  p_titre text, p_contenu text, p_blocs jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; a record; sa record; v_paiement jsonb;
  v_topic text; v_post text; v_titre text; v_contenu text; v_temps text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  v_titre   := nullif(btrim(coalesce(p_titre, '')), '');
  v_contenu := nullif(btrim(coalesce(p_contenu, '')), '');
  IF v_titre IS NULL OR v_contenu IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'titre_ou_contenu_vide');
  END IF;

  SELECT * INTO sa FROM public.communications_salles
   WHERE building_id = p_building_id AND room_id = p_room_id;
  IF NOT FOUND THEN
    -- AUCUNE SALLE DECLAREE : on ne publie pas « au nom de l'Etat » depuis un lieu quelconque.
    RETURN jsonb_build_object('ok', false, 'raison', 'salle_sans_tribune');
  END IF;

  -- L'AUTORITE EST RELUE EN BASE, par la porte attestee, et jamais sur la fiche transmise.
  SELECT * INTO a FROM public.acteur_poste_courant() LIMIT 1;
  IF NOT FOUND OR a.poste_id IS NULL OR NOT (a.poste_id = ANY (sa.postes)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_admis_dans_cette_tribune',
                              'tribune', sa.libelle, 'postes_admis', sa.postes);
  END IF;

  -- LE COUT, PAR LE CHEMIN ATTESTE. payer_ordre refuse un triplet que le miroir ne declare pas.
  v_paiement := public.payer_ordre(v_moi, p_fn, coalesce(p_pa, 0), coalesce(p_cost, 0));
  IF coalesce((v_paiement->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paiement->>'raison', 'paiement_refuse'),
                              'paiement', v_paiement);
  END IF;

  v_temps := to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI');
  v_topic := 'topic-' || (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_post  := 'post-'  || (extract(epoch from clock_timestamp()) * 1000)::bigint;

  INSERT INTO public.forum_topics
    (id, forum_id, title, author, country, time, views, replies,
     last_post_author, last_post_time, author_is_org, author_secret)
  VALUES (v_topic, sa.forum_id, v_titre, v_moi, a.pays, v_temps, 1, 0, v_moi, v_temps, false, false);

  INSERT INTO public.forum_posts
    (id, topic_id, author, content, time, author_is_org, author_secret, content_blocks, content_layout)
  VALUES (v_post, v_topic, v_moi, v_contenu, v_temps, false, false,
          CASE WHEN jsonb_typeof(p_blocs) = 'array' THEN p_blocs ELSE '[]'::jsonb END, NULL);

  RETURN jsonb_build_object('ok', true, 'topic', v_topic, 'post', v_post,
                            'auteur', v_moi, 'poste', a.poste_id, 'tribune', sa.libelle,
                            'temps', v_temps, 'paiement', v_paiement);
END;
$function$;

REVOKE ALL ON FUNCTION public.communication_officielle_publier(text, text, text, integer, integer, text, text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.communication_officielle_publier(text, text, text, integer, integer, text, text, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.communication_officielle_publier(text, text, text, integer, integer, text, text, jsonb) TO service_role;

-- UNE PORTE DE LECTURE, pour que l'interface sache quoi afficher AVANT que le joueur ne redige --
-- l'infobulle fausse faisait partie du defaut constate. Elle ne rend que ce qui est public : le
-- libelle de la tribune et la liste des postes admis.
CREATE OR REPLACE FUNCTION public.communication_tribune(p_building_id text, p_room_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE sa record; a record;
BEGIN
  SELECT * INTO sa FROM public.communications_salles
   WHERE building_id = p_building_id AND room_id = p_room_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'tribune', false);
  END IF;
  SELECT * INTO a FROM public.acteur_poste_courant() LIMIT 1;
  RETURN jsonb_build_object('ok', true, 'tribune', true, 'libelle', sa.libelle,
                            'postes_admis', sa.postes,
                            'je_peux', coalesce(a.poste_id = ANY (sa.postes), false));
END;
$function$;

REVOKE ALL ON FUNCTION public.communication_tribune(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.communication_tribune(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.communication_tribune(text, text) TO service_role;

-- -------------------------------------------------------------------------------------------------
-- PREUVES STRUCTURELLES
-- -------------------------------------------------------------------------------------------------
DO $$
DECLARE v_n integer; v_postes text[];
BEGIN
  -- P1 : les deux tribunes sont declarees, et elles ne se confondent pas.
  SELECT count(*) INTO v_n FROM public.communications_salles;
  IF v_n <> 2 THEN RAISE EXCEPTION 'P1a : % tribunes declarees au lieu de 2', v_n; END IF;
  SELECT postes INTO v_postes FROM public.communications_salles
   WHERE building_id = 'palais-presidentiel';
  IF v_postes <> ARRAY['president'] THEN
    RAISE EXCEPTION 'P1b : la tribune de l Elysee n est pas reservee au President';
  END IF;

  -- P2 : LE PRESIDENT N'EST PAS ADMIS A LA TRIBUNE DU GOUVERNEMENT, et c'est le coeur de
  -- l'arbitrage : il a la sienne.
  SELECT postes INTO v_postes FROM public.communications_salles
   WHERE building_id = 'palais-gouvernement';
  IF 'president' = ANY (v_postes) THEN
    RAISE EXCEPTION 'P2a : le President est admis a la tribune du Gouvernement';
  END IF;
  IF NOT ('pm' = ANY (v_postes)) OR NOT ('min_info' = ANY (v_postes))
     OR array_length(v_postes, 1) <> 7 THEN
    RAISE EXCEPTION 'P2b : la tribune du Gouvernement n admet pas le PM et les sept ministres (%)',
      array_length(v_postes, 1);
  END IF;

  -- P3 : CHAQUE POSTE DECLARE EXISTE REELLEMENT comme poste du jeu. Un poste invente ici serait
  -- une autorite qui ne peut jamais etre satisfaite -- une tribune morte.
  SELECT count(*) INTO v_n FROM (
    SELECT unnest(postes) AS poste FROM public.communications_salles) q
   WHERE q.poste NOT IN (SELECT poste_id FROM public.postes_electifs_regles)
     AND q.poste NOT IN (SELECT DISTINCT poste_id FROM public.salaires_caisses);
  IF v_n <> 0 THEN RAISE EXCEPTION 'P3 : % poste(s) de tribune inconnu(s) du jeu', v_n; END IF;

  -- P4 : la porte d'ecriture verifie l'autorite ET passe par payer_ordre. Les deux ensemble :
  -- une autorite sans paiement laisserait une conference gratuite.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'communication_officielle_publier'
     AND p.prosecdef
     AND array_to_string(coalesce(p.proconfig,'{}'), ',') LIKE '%search_path%'
     AND p.prosrc LIKE '%acteur_poste_courant%'
     AND p.prosrc LIKE '%payer_ordre%'
     AND p.prosrc LIKE '%forum_topics%' AND p.prosrc LIKE '%forum_posts%'
     AND NOT has_function_privilege('anon', p.oid, 'EXECUTE');
  IF v_n <> 1 THEN RAISE EXCEPTION 'P4 : la porte de publication est mal posee'; END IF;

  -- P5 : le registre est ferme au client -- RLS active, aucune policy.
  SELECT count(*) INTO v_n FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relname = 'communications_salles' AND c.relrowsecurity;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P5a : le registre des tribunes n est pas sous RLS'; END IF;
  SELECT count(*) INTO v_n FROM pg_policies
   WHERE schemaname = 'public' AND tablename = 'communications_salles';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P5b : % policy sur le registre des tribunes', v_n; END IF;

  RAISE NOTICE 'Tribunes officielles : les 5 preuves structurelles passent.';
END $$;
