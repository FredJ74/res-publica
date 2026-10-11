-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261011005129 (UTC), nom `memoire_la_chronique_nationale_est_la_source`.
-- Le registre passe de 642 a 643 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 cc0f94ee7155bcb278fb6c00c20def26, 10302 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LA CHRONIQUE NATIONALE ETAIT LA BONNE TABLE DEPUIS LE DEBUT
--
-- La premiere migration branchait la memoire sur deux producteurs nommes et renvoyait tout le
-- reste en « non raccordable ». En cherchant a brancher l'election, `chronique_nationale` est
-- apparue : une table de faits nationaux PUBLICS, ecrite par exactement TROIS portes serveur --
-- le depouillement, la publication d'une fuite, la publication d'un scandale -- et par rien
-- d'autre.
--
-- ELLE REPOND TOUTE SEULE A LA QUESTION DIFFICILE. « Huguette pourrait-elle raisonnablement
-- etre au courant ? » : une fuite n'entre dans la chronique qu'une fois PUBLIEE. Ce qui y figure
-- est public par construction.
--
-- C'EST UN DECLENCHEUR, ET NON TROIS APPELS. Brancher chaque producteur aurait demande de
-- modifier `election_resultats_consigner`, qui porte le compare-and-swap du depouillement -- on
-- ne touche pas au depouillement pour une fonctionnalite de dialogue. Et le declencheur couvrira
-- le quatrieme producteur le jour ou il existera, sans qu'on y revienne.
--
-- LA PORTE A PAYS EXPLICITE S'EST REFERMEE AU NAVIGATEUR du meme coup : le canal de dialogue
-- ne doit pas recevoir un pays du client, sinon un joueur lit la memoire presidentielle de
-- l'empire voisin. Le pays est relu en base, comme le fait deja le contexte public.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =================================================================================================
-- LA CHRONIQUE NATIONALE DEVIENT LA SOURCE DE CONTEXTE (11 octobre 2026)
-- =================================================================================================
-- CE QUE LA PREMIERE MIGRATION AVAIT MANQUE. Elle branchait la memoire sur deux producteurs nommes
-- -- payer_ordre et guerre_declarer -- et renvoyait tout le reste dans la liste des sources non
-- raccordables. En cherchant a brancher l'election, `chronique_nationale` est apparue : une table
-- de FAITS NATIONAUX PUBLICS, ecrite par exactement TROIS portes serveur et par rien d'autre --
-- `election_resultats_consigner`, `fuite_publier`, `scandale_publier`.
--
-- C'est la source generale qui manquait, et elle est meilleure que trois raccordements separes :
--   . elle est PUBLIQUE PAR CONSTRUCTION. Une fuite ou un scandale n'y entre qu'une fois PUBLIE :
--     ce qui y figure est, par definition, ce que tout le monde peut savoir. La question « Huguette
--     pourrait-elle raisonnablement etre au courant ? » s'y repond toute seule ;
--   . elle est ATTESTEE : aucun navigateur n'y ecrit, les trois portes sont SECURITY DEFINER ;
--   . elle est EXTENSIBLE SANS NOUVEAU CODE. Un declencheur sur la table couvre les trois
--     producteurs d'un coup, et couvrira le quatrieme le jour ou il existera -- sans qu'on
--     retouche ni la memoire ni le producteur.
--
-- C'est donc un DECLENCHEUR, et non trois appels : brancher chaque producteur aurait demande de
-- modifier `election_resultats_consigner`, qui porte le compare-and-swap du depouillement. On ne
-- touche pas au depouillement pour une fonctionnalite de dialogue.
--
-- ET LE DECLENCHEUR N'INVENTE RIEN : il recopie le libelle que la chronique a deja ecrit. Il ne
-- resume pas, ne qualifie pas, n'interprete pas.
-- =================================================================================================

-- LA CINQUIEME SOURCE. `scandale de presse` quitte du meme coup la liste des non raccordables :
-- elle y figurait parce que `scandales_presse` est alimentee par des chemins clients et que
-- `evenements_globaux` est un flux d'ambiance -- mais la CHRONIQUE, elle, ne recoit que des
-- publications attestees. C'etait la bonne table depuis le debut.
INSERT INTO public.presidence_memoire_sources (source, genre, note) VALUES
  ('chronique_nationale', 'contexte',
   'Un fait national PUBLIC, recopie de public.chronique_nationale par un declencheur. Cette table n est ecrite que par trois portes serveur -- le depouillement d une election, la publication d une fuite, la publication d un scandale -- et jamais par un navigateur. Ce qui y figure est public par construction : une fuite n y entre qu une fois PUBLIEE. Le declencheur recopie le libelle deja ecrit, sans resumer ni qualifier.')
ON CONFLICT (source) DO UPDATE SET genre = EXCLUDED.genre, note = EXCLUDED.note;

DELETE FROM public.presidence_memoire_sources_absentes WHERE sujet = 'scandale de presse';

INSERT INTO public.presidence_memoire_sources_absentes (sujet, genre, obstacle) VALUES
  ('ouverture du mandat par le depouillement', 'contexte',
   'La chronique de l election est desormais reprise par le declencheur, donc le FAIT est bien dans la memoire. Ce qui manque est plus fin : au moment ou election_resultats_consigner s execute, postes_attribues ne porte pas encore le nouveau President, donc la ligne se rattache au mandat SORTANT. L ouverture d un mandat ne pourra etre datee proprement que le jour ou l attribution du poste et le depouillement seront dans la meme transaction. Ce n est pas bloquant : la separation des mandats est portee par mandat_depuis, pas par cette ligne.')
ON CONFLICT (sujet) DO UPDATE SET genre = EXCLUDED.genre, obstacle = EXCLUDED.obstacle;

-- -------------------------------------------------------------------------------------------------
-- LE DECLENCHEUR
-- -------------------------------------------------------------------------------------------------
-- IL NE DECIDE RIEN. Il passe le libelle a la porte d'ecriture, qui garde ses quatre refus : pas de
-- President joueur, pas de source declaree, pas de genre contredit, pas de reaction usurpee. Un
-- fait de chronique survenu hors de tout mandat n'est donc PAS enregistre -- et c'est voulu : la
-- memoire d'Huguette est celle des presidences, pas celle du pays.
CREATE OR REPLACE FUNCTION public.presidence_memoire_chronique()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF coalesce(btrim(coalesce(NEW.country, '')), '') = ''
     OR coalesce(btrim(coalesce(NEW.libelle, '')), '') = '' THEN
    RETURN NEW;                       -- une chronique sans pays ni libelle n'apprend rien
  END IF;

  PERFORM public.presidence_memoire_noter(
    NEW.country, 'contexte', 'chronique_nationale',
    -- LE LIBELLE DE LA CHRONIQUE, TEL QUEL. Tronque a 300 caracteres pour qu'un libelle demesure
    -- ne remplisse pas le prompt d'Huguette, jamais reecrit.
    left(NEW.libelle, 300),
    jsonb_build_object('chronique', NEW.id, 'type', NEW.type, 'ville', NEW.city),
    NULL);
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS presidence_memoire_chronique_trg ON public.chronique_nationale;
CREATE TRIGGER presidence_memoire_chronique_trg
  AFTER INSERT ON public.chronique_nationale
  FOR EACH ROW EXECUTE FUNCTION public.presidence_memoire_chronique();

-- -------------------------------------------------------------------------------------------------
-- LA PORTE DE LECTURE DU DIALOGUE : SANS PAYS TRANSMIS
-- -------------------------------------------------------------------------------------------------
-- POURQUOI UNE SECONDE PORTE. `presidence_memoire_contexte(p_pays, p_limite)` reste la porte
-- serveur, utile pour lire la memoire d'un pays donne. Mais le canal de dialogue ne doit pas
-- recevoir un pays du navigateur : un joueur pourrait alors lire la memoire presidentielle d'un
-- empire voisin. Le pays est donc RELU en base, exactement comme le fait `pnj_contexte_public`.
CREATE OR REPLACE FUNCTION public.presidence_memoire_mon_pays()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pays_inconnu');
  END IF;
  RETURN public.presidence_memoire_contexte(v_pays, 12);
END;
$function$;

REVOKE ALL ON FUNCTION public.presidence_memoire_mon_pays() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.presidence_memoire_mon_pays() TO authenticated;
GRANT EXECUTE ON FUNCTION public.presidence_memoire_mon_pays() TO service_role;

-- LA PORTE A PAYS EXPLICITE SE REFERME AU NAVIGATEUR. Elle reste au serveur, et la nouvelle porte
-- -- qui relit le pays -- devient le seul chemin client. C'est la meme correction que celle de la
-- synchronisation de la Garde : une porte unique, deja gardee, plutot qu'un parametre de confiance.
REVOKE EXECUTE ON FUNCTION public.presidence_memoire_contexte(text, integer) FROM authenticated;

-- -------------------------------------------------------------------------------------------------
-- PREUVES STRUCTURELLES
-- -------------------------------------------------------------------------------------------------
DO $$
DECLARE v_n integer;
BEGIN
  -- P1 : cinq sources declarees, dont la chronique.
  SELECT count(*) INTO v_n FROM public.presidence_memoire_sources;
  IF v_n <> 5 THEN RAISE EXCEPTION 'P1a : % sources au lieu de 5', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.presidence_memoire_sources
   WHERE source = 'chronique_nationale' AND genre = 'contexte';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P1b : la chronique n est pas declaree en contexte'; END IF;

  -- P2 : le declencheur est pose sur la chronique, en APRES-INSERTION.
  SELECT count(*) INTO v_n FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
   WHERE t.tgname = 'presidence_memoire_chronique_trg' AND c.relname = 'chronique_nationale'
     AND NOT t.tgisinternal;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P2 : le declencheur de chronique manque'; END IF;

  -- P3 : LES TROIS PRODUCTEURS DE LA CHRONIQUE SONT TOUJOURS LES MEMES. Si un quatrieme
  -- apparaissait, il serait couvert par le declencheur -- mais si l'un des trois disparaissait,
  -- la source perdrait son sens, et cette preuve le dirait.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.prosrc LIKE '%chronique_nationale%'
     AND p.proname IN ('election_resultats_consigner', 'fuite_publier', 'scandale_publier');
  IF v_n <> 3 THEN RAISE EXCEPTION 'P3 : % des trois portes de la chronique au lieu de 3', v_n; END IF;

  -- P4 : la porte du dialogue ne prend AUCUN pays, et la porte a pays explicite est refermee au
  -- navigateur. Les deux moities comptent : sans la revocation, le parametre resterait exploitable.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'presidence_memoire_mon_pays'
     AND p.pronargs = 0 AND p.prosecdef
     AND has_function_privilege('authenticated', p.oid, 'EXECUTE')
     AND NOT has_function_privilege('anon', p.oid, 'EXECUTE');
  IF v_n <> 1 THEN RAISE EXCEPTION 'P4a : la porte de dialogue de la memoire est mal posee'; END IF;
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'presidence_memoire_contexte'
     AND has_function_privilege('authenticated', p.oid, 'EXECUTE');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P4b : la porte a pays explicite reste ouverte au navigateur'; END IF;

  -- P5 : la memoire est toujours vide. Poser un declencheur ne fabrique aucun passe.
  SELECT count(*) INTO v_n FROM public.presidence_memoire;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P5 : la memoire a gagne % lignes', v_n; END IF;

  RAISE NOTICE 'Chronique nationale : les 5 preuves structurelles passent.';
END $$;
