-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 13 OCTOBRE 2026
--
-- Registre Supabase : version 20261013073927 (UTC), nom
-- `presse_un_joueur_ne_forge_pas_un_fait_judiciaire_au_journal`.
-- Le registre passe de 703 a 704 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 4f0fde5824a0132fae4294ff6413b467, 4150 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- UN JOUEUR POUVAIT ECRIRE « X A ETE CONDAMNE » DANS LE JOURNAL NATIONAL
--
-- `chronique_nationale` accorde l'INSERT a tout acteur identifie, sans aucune contrainte sur le
-- `type` ni sur le `libelle`. C'est voulu pour les quatorze faits que le navigateur depose
-- legitimement -- nominations, rachats d'entreprise, debuts et fins de greve, dissolutions
-- d'organisation. Mais rien n'empechait d'y poser un `justice_condamnation` nommant n'importe qui.
--
-- LES FAITS JUDICIAIRES N'ONT QU'UNE SOURCE, ET ELLE EST SERVEUR : le declencheur sur les actes du
-- dossier, qui lit le registre `justice_faits_publics` et publie la phrase declaree pour l'acte
-- reellement consigne. Il est SECURITY DEFINER : fermer la porte cliente ne ferme rien de ce qui
-- doit passer.
--
-- LA GARDE EST DECLARATIVE : est interdit au client tout `type` declare au registre des faits
-- judiciaires. Un treizieme fait ajoute demain sera protege sans qu'on y pense.
--
-- CETTE MIGRATION EST INCOMPLETE, ET LA SUIVANTE LA CORRIGE DANS LA MEME HEURE. La policy lit le
-- registre dans un sous-select, or une policy RLS s'execute avec les droits de l'APPELANT et ce
-- registre n'accorde aucun droit client : toute insertion cliente mourait en « permission denied ».
-- Le banc des parcours l'a trouve parce que son epreuve F6 mesure les DEUX cotes -- le faux refuse
-- ET le vrai accepte. L'archive garde la migration telle qu'elle a ete appliquee ; la correction est
-- au registre 705.
--
-- PREUVES STRUCTURELLES -- 6.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- UN JOUEUR POUVAIT ECRIRE « X A ETE CONDAMNE » DANS LE JOURNAL NATIONAL.
--
-- `chronique_nationale` accorde l'INSERT a tout acteur identifie -- `acteur_identifie()` -- sans
-- aucune contrainte sur le `type` ni sur le `libelle`. C'est voulu pour les quatorze faits que le
-- navigateur depose legitimement (nominations, rachats d'entreprise, debut et fin de greve,
-- dissolution d'organisation, subvention publique, fraude electorale dejouee...). Mais rien
-- n'empechait d'y poser un `justice_condamnation` nommant n'importe qui.
--
-- LES FAITS JUDICIAIRES N'ONT QU'UNE SOURCE, ET ELLE EST SERVEUR : le declencheur
-- `trg_dossiers_actes_chronique`, qui lit le registre `justice_faits_publics` et publie la phrase
-- declaree pour l'acte reellement consigne. Ce declencheur est SECURITY DEFINER, donc la RLS ne
-- s'applique pas a lui : fermer la porte cliente ne ferme rien de ce qui doit passer.
--
-- LA GARDE EST DECLARATIVE, PAS UNE LISTE A LA MAIN : est interdit au client tout `type` declare
-- dans `justice_faits_publics`. Un treizieme fait judiciaire ajoute au registre demain sera
-- protege sans qu'on y pense -- et c'est le meme principe que « le silence est le defaut ».
--
-- CE QUI RESTE OUVERT, ET QUI EST SIGNALE AU RAPPORT : les autres types restent libres. Un joueur
-- peut encore deposer une fausse nomination. Fermer cela demande la liste close des quatorze
-- types legitimes, donc un arbitrage sur ce que le navigateur a le droit de raconter -- et c'est
-- la dette « chronique_nationale n'est pas attestee », deja consignee. Cette migration ferme la
-- moitie judiciaire, celle que la tranche du tribunal rend atteignable.

DROP POLICY IF EXISTS chronique_nationale_ecriture_acteur ON public.chronique_nationale;

CREATE POLICY chronique_nationale_ecriture_acteur
  ON public.chronique_nationale FOR INSERT TO authenticated
  WITH CHECK (
    public.acteur_identifie()
    AND NOT EXISTS (SELECT 1 FROM public.justice_faits_publics f
                     WHERE f.chronique_type = chronique_nationale.type)
  );

DO $$
DECLARE v_c text; v_n integer;
BEGIN
  -- P1 -- la policy existe, et elle porte les deux conditions.
  SELECT with_check INTO v_c FROM pg_policies
   WHERE schemaname = 'public' AND tablename = 'chronique_nationale' AND cmd = 'INSERT';
  IF v_c IS NULL THEN RAISE EXCEPTION 'P1 ECHOUEE -- aucune policy d''insertion'; END IF;
  IF v_c NOT ILIKE '%acteur_identifie%' THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- l''identification a disparu : %', v_c; END IF;
  IF v_c NOT ILIKE '%justice_faits_publics%' THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la garde judiciaire est absente : %', v_c; END IF;

  -- P3 -- LE DECLENCHEUR SERVEUR EST TOUJOURS LA. Sans lui, fermer la porte cliente rendrait le
  -- journal judiciaire MUET au lieu de le rendre honnete.
  SELECT count(*) INTO v_n FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
   WHERE c.relname = 'dossiers_judiciaires_actes' AND t.tgname = 'trg_dossiers_actes_chronique'
     AND NOT t.tgisinternal;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P3 ECHOUEE -- le declencheur du journal a disparu'; END IF;

  -- P4 -- et la fonction qu'il appelle est bien SECURITY DEFINER : c'est ce qui lui permet de
  -- publier malgre la policy qu'on vient de poser.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    AND n.nspname = 'public'
   WHERE p.proname = 'dossiers_actes_publier_au_journal' AND p.prosecdef;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P4 ECHOUEE -- le publicateur n''est pas SECURITY DEFINER'; END IF;

  -- P5 -- LA LECTURE RESTE PUBLIQUE : un journal que personne ne lit n'est pas un journal.
  SELECT count(*) INTO v_n FROM pg_policies
   WHERE schemaname = 'public' AND tablename = 'chronique_nationale' AND cmd = 'SELECT';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P5 ECHOUEE -- la lecture publique a disparu'; END IF;

  -- P6 -- LES DOUZE TYPES JUDICIAIRES SONT BIEN CEUX QUE LA GARDE PROTEGE.
  SELECT count(*) INTO v_n FROM public.justice_faits_publics;
  IF v_n < 12 THEN RAISE EXCEPTION 'P6 ECHOUEE -- % type(s) judiciaire(s) au registre', v_n; END IF;

  RAISE NOTICE 'LES 6 PREUVES SONT VERTES.';
END $$;
