-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010084809 (UTC), nom `deux_contraintes_qui_rendent_l_anti_rejeu_structurel`.
-- Le registre passe de 600 a 601 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 996f15871f4bb7eb6ca1fe60d46cdbf7, 6723 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- CHANTIER 6, RELIQUAT : LES DEUX CONTRAINTES RECLAMEES PAR LE §5 DE L'AUDIT
--
-- Et l'inspection a trouve POURQUOI la premiere manquait : un SECOND ecrivain de
-- `compromis_historique` que l'audit ne nommait pas -- `nettoyerAchatsDirectsManques`, dont
-- l'identifiant portait un `Date.now()`. `resultat` entre dans la cle parce qu'un bien peut
-- legitimement produire deux actes distincts le meme jour ; un rejeu, lui, reproduit le meme.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CHANTIER 6, RELIQUAT -- LES DEUX CONTRAINTES RECLAMEES PAR LE §5 DE L'AUDIT (10 octobre 2026)
--
-- « Contraintes a ajouter, pour que la protection soit structurelle et non disciplinaire :
--   UNIQUE sur compromis_historique par bien et par jour, et UNIQUE sur l'identifiant de
--   chronique electorale, qui est deja stable mais que rien ne protege. »
--
-- =============================================================================================
-- 1. compromis_historique -- ET L'INSPECTION A TROUVE POURQUOI LA CONTRAINTE MANQUAIT
-- =============================================================================================
-- La migration 575 a donne a compromis_expire_resoudre un identifiant DATE
-- (`compromis-<bien>-<jour>`), et la cle primaire sur `id` suffit donc pour CE mecanisme.
--
-- Mais il existe un SECOND ECRIVAIN, et il porte exactement le defaut que la contrainte visait :
-- `nettoyerAchatsDirectsManques` (api/cron-minuit.js) insere
-- `id = 'achatdirect-' + row.id + '-' + Date.now()`. UN Date.now() DANS L'IDENTIFIANT : deux
-- passes la meme nuit ecrivent DEUX lignes d'historique pour le meme depot de garantie perdu.
-- Son INSERT est de plus avale, et l'ecriture du terrain qui suit l'est aussi -- le rendez-vous
-- manque pouvait donc etre consigne sans etre purge, puis reconsigne la nuit suivante.
--
-- POURQUOI `resultat` ENTRE DANS LA CLE, et ce n'est pas un relachement. « Par bien et par jour »
-- interdirait un evenement de jeu LEGITIME : un bien peut, le meme jour, voir un compromis
-- rembourse ET un depot d'achat direct perdu -- deux actes distincts, deux lignes justes. Un
-- rejeu, lui, reproduit le MEME resultat sur le MEME bien le MEME jour. La cle
-- (pays, bien, resultat, journee) refuse donc tout rejeu sans refuser aucun acte reel.
--
-- La journee est derivee de created_at en heure de Paris -- le fuseau du jeu, celui de la bascule
-- de minuit. `timezone(text, timestamptz)` est IMMUTABLE (verifie en base : provolatile = 'i'),
-- ce qui autorise l'index d'expression. Aucune colonne n'est ajoutee.
--
-- =============================================================================================
-- 2. chronique_nationale -- UNE PROCLAMATION PAR SCRUTIN, STRUCTURELLEMENT
-- =============================================================================================
-- L'identifiant `election-<cycle>-<dateResultats>` est stable, et la cle primaire le protege
-- contre un rejeu A L'IDENTIQUE. Ce que rien ne protegeait, c'est l'inverse : RIEN n'empechait
-- une SECONDE chronique du meme scrutin sous un identifiant DIFFERENT. La contrainte porte donc
-- sur la cle LOGIQUE de l'evenement -- (pays, ville, scrutin) -- et non sur sa cle technique.
--
-- `coalesce(city,'')` est indispensable : en PostgreSQL deux NULL ne se heurtent pas dans un
-- index unique, et un scrutin national a precisement `city = NULL`. Sans le coalesce, deux
-- proclamations nationales du meme cycle passeraient toutes les deux.
--
-- L'index est PARTIEL, sur type = 'election_resultat' : la chronique nationale historise aussi
-- des nominations, des fins de greve et des rachats d'entreprise, qui n'ont ni la meme cle
-- logique ni la meme regle d'unicite. Les contraindre serait inventer une regle.

CREATE UNIQUE INDEX IF NOT EXISTS compromis_historique_un_resultat_par_bien_et_par_jour
  ON public.compromis_historique
     (country, building_id, resultat, ((timezone('Europe/Paris', created_at))::date));

COMMENT ON INDEX public.compromis_historique_un_resultat_par_bien_et_par_jour IS
  'Anti-rejeu STRUCTUREL (§5 de l''audit du chantier 6). Un meme resultat ne peut etre consigne '
  'qu''une fois par bien et par journee de jeu. `resultat` est dans la cle parce qu''un bien peut '
  'legitimement produire deux actes distincts le meme jour (compromis rembourse ET depot d''achat '
  'direct perdu) ; un rejeu, lui, reproduit le meme resultat.';

CREATE UNIQUE INDEX IF NOT EXISTS chronique_nationale_une_proclamation_par_scrutin
  ON public.chronique_nationale (country, coalesce(city, ''), source_ref)
  WHERE type = 'election_resultat';

COMMENT ON INDEX public.chronique_nationale_une_proclamation_par_scrutin IS
  'Anti-rejeu STRUCTUREL (§5 de l''audit du chantier 6). La cle est LOGIQUE -- pays, ville, '
  'scrutin -- et non technique : la cle primaire protegeait deja un rejeu a l''identique, mais '
  'rien n''empechait une seconde proclamation du meme scrutin sous un autre identifiant. '
  'coalesce(city,'''') est indispensable : un scrutin national a city = NULL, et deux NULL ne se '
  'heurtent pas dans un index unique. Partiel, parce que les autres types de chronique '
  '(nominations, greves, rachats) n''ont pas cette regle d''unicite.';

DO $$
DECLARE v_def text;
BEGIN
  -- P1 : les deux index existent, sont UNIQUE, et portent bien les expressions voulues.
  SELECT pg_get_indexdef(i.indexrelid) INTO v_def
    FROM pg_index i JOIN pg_class c ON c.oid = i.indexrelid
   WHERE c.relname = 'compromis_historique_un_resultat_par_bien_et_par_jour';
  IF v_def IS NULL THEN RAISE EXCEPTION 'P1a : index compromis absent'; END IF;
  IF v_def NOT LIKE 'CREATE UNIQUE INDEX%' THEN RAISE EXCEPTION 'P1b : pas UNIQUE'; END IF;
  IF v_def NOT LIKE '%Europe/Paris%' THEN
    RAISE EXCEPTION 'P1c : la journee n''est pas derivee en heure de Paris'; END IF;
  IF v_def NOT LIKE '%resultat%' THEN RAISE EXCEPTION 'P1d : resultat absent de la cle'; END IF;

  SELECT pg_get_indexdef(i.indexrelid) INTO v_def
    FROM pg_index i JOIN pg_class c ON c.oid = i.indexrelid
   WHERE c.relname = 'chronique_nationale_une_proclamation_par_scrutin';
  IF v_def IS NULL THEN RAISE EXCEPTION 'P2a : index chronique absent'; END IF;
  IF v_def NOT LIKE 'CREATE UNIQUE INDEX%' THEN RAISE EXCEPTION 'P2b : pas UNIQUE'; END IF;
  IF v_def NOT LIKE '%COALESCE(city%' AND v_def NOT LIKE '%coalesce(city%' THEN
    RAISE EXCEPTION 'P2c : sans coalesce, deux scrutins nationaux passeraient -- %', v_def; END IF;
  IF v_def NOT LIKE '%WHERE (type =%' THEN
    RAISE EXCEPTION 'P2d : l''index n''est pas partiel, il contraint tous les types'; END IF;

  -- P3 : les deux tables sont vides, donc aucune ligne existante n'a pu etre refusee. Si elles
  -- ne l'etaient pas, la creation de l'index aurait leve -- c'est le comportement voulu.
  IF (SELECT count(*) FROM public.compromis_historique) <> 0
     OR (SELECT count(*) FROM public.chronique_nationale) <> 0 THEN
    RAISE EXCEPTION 'P3 : les tables ne sont pas vides (% et %) -- relire avant de conclure',
      (SELECT count(*) FROM public.compromis_historique),
      (SELECT count(*) FROM public.chronique_nationale); END IF;

  RAISE NOTICE 'deux contraintes posees : 3 preuves structurelles conformes.';
END $$;
