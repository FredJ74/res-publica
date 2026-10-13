-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 13 OCTOBRE 2026
--
-- Registre Supabase : version 20261013123725 (UTC), nom
-- `tribunal_le_ministre_de_la_justice_n_a_pas_le_dossier`.
-- Le registre passe de 707 a 708 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 ede590415e7db27eec313d5c1d0e48c0, 9205 caracteres, 1
-- instruction au registre. Empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE REGISTRE STOCKE LE MEME CORPS SUIVI D'UN SAUT DE LIGNE FINAL : md5
-- 5a64a1671997acc9f91210700a14dfab, 9206 caracteres. Les deux ont ete compares : le corps
-- archive ici est, au saut de ligne final pres, OCTET POUR OCTET celui que Supabase a
-- enregistre.
--
-- LE MINISTRE DE LA JUSTICE N'A PAS LE DOSSIER
--
-- La policy de lecture de `plaintes_en_cours` accordait encore la ligne ENTIERE a `min_just` et
-- `min_int` : le texte libre du plaignant, son identite, la trace du PV, la preuve retenue et le
-- jet de la procedure simplifiee, pour toutes les affaires du pays, en un seul GET.
--
-- AUCUN POUVOIR MINISTERIEL NE DEMANDAIT CELA : nommer et revoquer les juges, tenir deux budgets,
-- proposer la grace, ordonner une garde a vue d'exception. L'inventaire des ecrans le confirme --
-- aucun ne lit cette table. Le Ministre de l'Interieur part pour la meme raison : son volet
-- dossiers lit `contre_espionnage_dossiers`, par sa propre porte.
--
-- SECOND TROU DU MEME TYPE, FERME AUSSI : `justice_recherches` transportait `motif_allegue` --
-- la declaration du plaignant -- sur l'avis de recherche. Aucun appelant ne la lisait.
--
-- CE QUI RESTE : les parties sur leur propre affaire, et le juge ou le commissaire de la VILLE de
-- l'affaire. La grace et le registre du QHS restent ouverts au ministre (preuve P6).
--
-- PREUVES STRUCTURELLES -- 6.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LE MINISTRE DE LA JUSTICE N'A PAS LE DOSSIER.
--
-- LA FUITE, EXACTEMENT. La policy de lecture de `plaintes_en_cours` -- resserree le 13 octobre au
-- matin pour fermer la branche « toute affaire jugee est publique » -- accordait encore la ligne
-- ENTIERE a deux postes nommes : `min_just` et `min_int`. Or `data` n'est pas un resume : il
-- porte le TEXTE LIBRE du plaignant (`motif`), son IDENTITE (`auteur`), la trace du PV, la
-- qualification du parquet, la preuve reelle retenue et le jet de la procedure simplifiee. Un
-- seul GET PostgREST rendait tout cela, pour TOUTES les affaires du pays, a un ministre.
--
-- CE QUE L'ARBITRAGE DIT. Le Ministre de la Justice n'a PAS acces automatiquement au contenu
-- confidentiel des dossiers judiciaires. Il nomme et revoque les juges, il tient le budget de la
-- Justice et celui du QHS, il propose la grace, il ordonne une garde a vue d'exception sous
-- regime de restriction des libertes -- et AUCUN de ces pouvoirs ne demande de lire une piece de
-- dossier. L'inventaire a ete fait : aucun ecran du ministere ne lit `plaintes_en_cours`.
--
-- LE MINISTRE DE L'INTERIEUR PART AVEC, ET POUR LA MEME RAISON. Il n'est ni partie a l'affaire ni
-- l'autorite judiciaire de sa ville, et son seul ecran de dossiers -- le volet contre-espionnage
-- -- lit `contre_espionnage_dossiers`, une autre table, par sa propre porte. Le client le dit
-- lui-meme : « le volet plaintes reste commissaire ; un ministre n'y a aucune decision a
-- prendre ». Sa branche etait du meme type que celle du garde des Sceaux : un acces en bloc,
-- sans affaire, sans acte et sans trace.
--
-- CE QUI RESTE ACCORDE, ET C'EST TOUT : les PARTIES sur leur propre affaire
-- (`affaire_me_concerne`), et le juge ou le commissaire DE LA VILLE de l'affaire
-- (`affaire_autorite_de`). L'avocat retenu, le Procureur et le juge lisent par leurs portes
-- dediees, qui filtrent chacune ce qu'elles ont le droit de dire. Le registre public du greffe
-- (`justice_archives_greffe`) continue de nommer la personne visee, la categorie et l'etat de la
-- procedure -- jamais le contenu.
--
-- L'AVIS DE RECHERCHE NE TRANSPORTE PLUS LA DECLARATION DU PLAIGNANT. Second trou du meme type :
-- `justice_recherches` rendait le blob COMPLET d'une ligne `jugements`, et celui d'une
-- condamnation judiciaire porte `motif_allegue` -- le texte libre du plaignant, recopie depuis le
-- dossier. Un avis de recherche a besoin de la qualification retenue, de la ville, du pays et des
-- jours a purger ; il n'a aucun besoin de ce que le plaignant a ecrit. La cle est desormais
-- retiree de ce qui sort, et AUCUN appelant ne la lisait -- la preuve P5 le mesure dans le code
-- client. Rien d'autre du blob ne change : les motifs, la ville, le pays et l'instance restent.
--
-- AUCUNE DONNEE N'EST TOUCHEE : deux regles de lecture changent, et rien d'autre.

-- ---------------------------------------------------------------------------------------------
-- 1. LA LECTURE DU DOSSIER
-- ---------------------------------------------------------------------------------------------
DROP POLICY IF EXISTS "affaire lue par ses parties et par l autorite de sa ville"
  ON public.plaintes_en_cours;

CREATE POLICY "affaire lue par ses parties et par l autorite de sa ville"
  ON public.plaintes_en_cours FOR SELECT TO authenticated
  USING (
    public.affaire_autorite_de(city)
    OR public.affaire_me_concerne(data)
  );

-- ---------------------------------------------------------------------------------------------
-- 2. L'AVIS DE RECHERCHE
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.justice_recherches(p_nom text)
 RETURNS TABLE(id text, country text, ville_condamnation text, motif text, jours integer, data jsonb)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_autorise boolean := false;
BEGIN
  IF public.est_appel_serveur() THEN
    v_autorise := true;
  ELSE
    v_moi := public.mon_personnage();
    IF v_moi IS NOT NULL THEN
      -- Soi-meme : un joueur peut savoir qu'il est recherche.
      IF v_moi = p_nom THEN
        v_autorise := true;
      ELSE
        -- Autorite judiciaire, dans son propre pays.
        SELECT true INTO v_autorise
          FROM public.acteur_poste_courant() a
          JOIN public.personnages_donnees c ON c.name = p_nom
         WHERE a.poste_id IN ('commissaire','juge','min_just','min_int','president')
           AND a.pays = c.country
         LIMIT 1;
      END IF;
    END IF;
  END IF;

  IF NOT coalesce(v_autorise, false) THEN RETURN; END IF;

  -- `motif_allegue` EST RETIRE DE CE QUI SORT (13 octobre 2026). C'est le texte libre du
  -- plaignant, recopie sur la condamnation depuis le dossier : il n'a rien a faire sur un avis de
  -- recherche, que l'autorite lit pour savoir QUI chercher, pour QUELLE qualification, OU et
  -- pour COMBIEN de jours. Le retrait est inconditionnel -- meme pour la personne recherchee
  -- elle-meme, qui lit le texte du plaignant sur SON dossier par sa propre porte, pas ici.
  RETURN QUERY
    SELECT j.id, j.country, j.city, j.motif,
           coalesce((SELECT sum((m->>'jours')::int)
                       FROM jsonb_array_elements(coalesce(j.data->'motifs', '[]'::jsonb)) m), 0)::int,
           (j.data - 'motif_allegue')
      FROM public.jugements j
     WHERE j.accuse = p_nom AND j.executee = false
     ORDER BY j.created_at;
END;
$function$;

-- =============================================================================================
-- PREUVES STRUCTURELLES
-- =============================================================================================
DO $$
DECLARE v_n integer; v_q text; v_src text;
BEGIN
  -- P1. LA POLICY NE NOMME PLUS AUCUN MINISTRE.
  SELECT count(*) INTO v_n FROM pg_policies
   WHERE schemaname = 'public' AND tablename = 'plaintes_en_cours';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'P1 ECHOUEE : % policy(s) sur plaintes_en_cours, 1 attendue', v_n;
  END IF;
  SELECT qual INTO v_q FROM pg_policies
   WHERE schemaname = 'public' AND tablename = 'plaintes_en_cours';
  IF v_q LIKE '%min_just%' OR v_q LIKE '%min_int%' OR v_q LIKE '%mon_poste_est_dans%' THEN
    RAISE EXCEPTION 'P1b ECHOUEE : la policy nomme encore un poste ministeriel -- %', v_q;
  END IF;

  -- P2. LES DEUX BRANCHES LEGITIMES SURVIVENT, et elles sont les seules.
  IF v_q NOT LIKE '%affaire_autorite_de(city)%' OR v_q NOT LIKE '%affaire_me_concerne(data)%' THEN
    RAISE EXCEPTION 'P2 ECHOUEE : une branche legitime a disparu -- %', v_q;
  END IF;

  -- P3. LA TABLE N EST TOUJOURS LUE QUE PAR UNE POLICY DE SELECT, et aucune ecriture cliente n a
  -- ete ouverte au passage.
  SELECT count(*) INTO v_n FROM pg_policies
   WHERE schemaname = 'public' AND tablename = 'plaintes_en_cours' AND cmd <> 'SELECT';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P3 ECHOUEE : % policy(s) d ecriture sur le dossier', v_n; END IF;
  SELECT count(*) INTO v_n FROM information_schema.role_table_grants
   WHERE table_schema = 'public' AND table_name = 'plaintes_en_cours'
     AND grantee IN ('anon', 'authenticated')
     AND privilege_type IN ('INSERT', 'UPDATE', 'DELETE');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P3b ECHOUEE : % droit(s) d ecriture client sur le dossier', v_n; END IF;

  -- P4. L AVIS DE RECHERCHE RETIRE LA DECLARATION DU PLAIGNANT, et conserve le reste.
  SELECT public.sans_commentaires(p.prosrc) INTO v_src FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'justice_recherches';
  IF v_src !~ 'j.data - ''motif_allegue''' THEN
    RAISE EXCEPTION 'P4 ECHOUEE : justice_recherches rend encore le blob complet';
  END IF;
  IF v_src !~ 'j.executee = false' OR v_src !~ 'acteur_poste_courant' THEN
    RAISE EXCEPTION 'P4b ECHOUEE : justice_recherches a perdu sa garde ou son filtre';
  END IF;
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'justice_recherches';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P4c ECHOUEE : % signatures de justice_recherches', v_n; END IF;

  -- P5. AUCUNE AFFAIRE N EST TOUCHEE, et aucune condamnation n est relue : les deux objets
  -- changes sont des REGLES DE LECTURE. Le nombre d affaires et de jugements est inchange.
  SELECT count(*) INTO v_n FROM public.plaintes_en_cours;
  RAISE NOTICE 'P5 : % affaire(s) au greffe, aucune modifiee.', v_n;
  SELECT count(*) INTO v_n FROM public.jugements;
  RAISE NOTICE 'P5 : % jugement(s) au registre, aucun modifie.', v_n;

  -- P6. LES DEUX AUTRES PORTES DU MINISTRE RESTENT OUVERTES : la grace et le registre du QHS.
  -- Fermer un acces au DOSSIER ne doit pas lui retirer ses pouvoirs declares.
  SELECT count(*) INTO v_n FROM pg_policies
   WHERE schemaname = 'public' AND tablename IN ('demandes_grace', 'prisonniers_qhs')
     AND (coalesce(qual,'') LIKE '%min_just%' OR coalesce(with_check,'') LIKE '%min_just%');
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'P6 ECHOUEE : % policy(s) ministerielle(s) survivante(s), 2 attendues', v_n;
  END IF;

  RAISE NOTICE 'LES 6 PREUVES STRUCTURELLES SONT VERTES.';
END $$;
