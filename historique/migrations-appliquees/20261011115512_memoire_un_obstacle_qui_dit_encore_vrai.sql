-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261011115512 (UTC), nom `memoire_un_obstacle_qui_dit_encore_vrai`.
-- Le registre passe de 646 a 646 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 de29ecf5be193bdb662687d494223839, 3889 caracteres, 1 instruction
-- au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- UN OBSTACLE CONSIGNE DOIT CONTINUER DE DIRE VRAI
--
-- C'est la reextraction du baseline qui l'a fait voir. La migration precedente avait bien
-- reecrit l'obstacle de la source `election presidentielle`, mais une AUTRE ligne de
-- `presidence_memoire_sources_absentes` parlait encore du declencheur retire : « la chronique
-- de l election est desormais reprise par le declencheur, donc le FAIT est bien dans la memoire
-- ». La phrase etait devenue fausse le jour meme.
-- CE REGISTRE N'EST PAS DE LA DOCUMENTATION D'ACCOMPAGNEMENT : c'est celui que le banc de la
-- memoire LIT pour verifier qu'aucune source ecartee n'a ete rebranchee en cachette. Un
-- registre qui decrit un mecanisme disparu fait croire qu'il reste quelque chose a ne pas
-- refaire.
-- AUCUN MECANISME NE CHANGE. Une seule phrase est corrigee, et l'obstacle de fond est conserve
-- mot pour mot : au moment ou `election_resultats_consigner` s'execute, `postes_attribues` ne
-- porte pas encore le nouveau President. La dette reste consignee, elle n'est pas effacee avec
-- la phrase.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =================================================================================================
-- UN OBSTACLE CONSIGNE DOIT CONTINUER DE DIRE VRAI (11 octobre 2026)
-- =================================================================================================
-- CE QUE LA REEXTRACTION DU BASELINE A FAIT VOIR. La migration de la conference de presse a retire
-- le declencheur qui recopiait la chronique nationale dans la memoire presidentielle, et elle a
-- bien reecrit l'obstacle de la source `election presidentielle`. Mais une AUTRE ligne de
-- `presidence_memoire_sources_absentes` parlait du meme declencheur :
--
--   « ouverture du mandat par le depouillement » :
--   « La chronique de l election est desormais reprise par le declencheur, donc le FAIT est bien
--     dans la memoire. »
--
-- Cette phrase est devenue FAUSSE le jour meme : il n'y a plus de declencheur, et le fait n'est
-- plus dans la memoire du tout. Le laisser serait pire qu'une imprecision -- cette table n'est pas
-- de la documentation d'accompagnement, c'est le registre que le banc de la memoire LIT pour
-- verifier qu'aucune source ecartee n'a ete rebranchee en cachette. Un registre qui decrit un
-- mecanisme disparu fait croire qu'il reste quelque chose a ne pas refaire.
--
-- AUCUN MECANISME NE CHANGE ICI. Une seule phrase est corrigee, et l'obstacle de fond -- celui qui
-- restera a lever un jour -- est conserve mot pour mot : au moment ou `election_resultats_consigner`
-- s'execute, `postes_attribues` ne porte pas encore le nouveau President.
-- =================================================================================================

UPDATE public.presidence_memoire_sources_absentes
   SET obstacle = 'DEUX OBSTACLES, ET LE PREMIER EST NEUF. (1) La chronique nationale a ete ECARTEE des sources le 11 octobre 2026 -- elle est ecrite depuis le navigateur -- donc le depouillement n alimente plus la memoire du tout. (2) L obstacle de fond demeure : au moment ou election_resultats_consigner s execute, postes_attribues ne porte pas encore le nouveau President, donc une ligne se rattacherait au mandat SORTANT. L ouverture d un mandat ne pourra etre datee proprement que le jour ou l attribution du poste et le depouillement seront dans la meme transaction. Ce n est pas bloquant : la separation des mandats est portee par mandat_depuis, pas par cette ligne.'
 WHERE sujet = 'ouverture du mandat par le depouillement';

-- -------------------------------------------------------------------------------------------------
-- PREUVES STRUCTURELLES
-- -------------------------------------------------------------------------------------------------
DO $$
DECLARE v_n integer;
BEGIN
  -- P1 : plus aucun obstacle consigne ne pretend qu'un declencheur de chronique alimente la memoire.
  SELECT count(*) INTO v_n FROM public.presidence_memoire_sources_absentes
   WHERE obstacle LIKE '%reprise par le declencheur%';
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P1 : % obstacle(s) parlent encore du declencheur retire', v_n;
  END IF;

  -- P2 : et l'obstacle de FOND est toujours la, mot pour mot. Corriger une phrase ne doit pas
  -- effacer la dette qu'elle portait.
  SELECT count(*) INTO v_n FROM public.presidence_memoire_sources_absentes
   WHERE sujet = 'ouverture du mandat par le depouillement'
     AND obstacle LIKE '%postes_attribues ne porte pas encore le nouveau President%'
     AND obstacle LIKE '%mandat_depuis%';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'P2 : l obstacle de fond a ete perdu dans la correction';
  END IF;

  -- P3 : le registre garde ses douze lignes -- on corrige, on ne supprime pas.
  SELECT count(*) INTO v_n FROM public.presidence_memoire_sources_absentes;
  IF v_n <> 12 THEN
    RAISE EXCEPTION 'P3 : % sources ecartees au lieu de 12', v_n;
  END IF;

  RAISE NOTICE 'Un obstacle qui dit encore vrai : les 3 preuves passent.';
END $$;
