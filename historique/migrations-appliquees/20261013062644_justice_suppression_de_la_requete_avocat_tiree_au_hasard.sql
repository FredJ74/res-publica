-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 13 OCTOBRE 2026
--
-- Registre Supabase : version 20261013062644 (UTC), nom
-- `justice_suppression_de_la_requete_avocat_tiree_au_hasard`.
-- Le registre passe de 700 a 701 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 844a21b7839706d9448215c483825549, 4850 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LA REQUETE D'AVOCAT TIREE AU HASARD EST SUPPRIMEE, ET ELLE SEULE
--
-- C'ETAIT LA DERNIERE PORTE DU JEU OU UN DE DECIDAIT SI UNE PLAIDOIRIE ETAIT BONNE. Le navigateur
-- tirait un d100 contre `Math.min(85, 40 + DUP*1.5)` et le serveur enregistrait le verdict du de :
-- `detention_reduire_peine` reduisait la peine de moitie, ou pas, selon un jet. Human Gambit ne code
-- pas les reactions humaines -- un juge qui allege une peine est un joueur, pas une probabilite --
-- et c'est l'arbitrage qui demande cette suppression.
--
-- CE QUI PART AVEC ELLE : la colonne de travail `detentions.reduction_jours`, morte et NULLE sur
-- toutes les lignes ; le mode de cloture `anticipee_avocat`, que plus aucune porte ne produit ; et,
-- cote navigateur, l'ordre `requete_avocat` (declare dans les trois lieux de detention), son entree
-- ORDER_EFFECTS, ses deux routes, ses deux handlers, ses 800 FR d'honoraires inventes et le drapeau
-- `avocatUtilise`.
--
-- CE QUI NE PART PAS, ET LA MIGRATION LE PROUVE : les huit portes qui portent le mot « avocat » et
-- qui sont de vraies mecaniques judiciaires. Le barreau, la tarification, la defense retenue, le
-- dossier de l'avocat, la commission d'office de la procedure simplifiee. Supprimer une mecanique
-- parce qu'elle partage un mot avec une autre serait un degat, pas un nettoyage -- d'ou la preuve
-- P7, qui exige leur presence, et P8, qui exige celle des portes de detention.
--
-- LA NON-REGRESSION EST AU BANC, PAS DANS LA BASE. Le chapitre 8 de
-- outils/bancs/banc-detention-plateau.js est un VERROU : il rougit si l'ordre, la route, le handler
-- ou l'appel a la porte serveur renaissent par copier-coller, et il exige en meme temps que le
-- barreau et la defense restent branches. Trois contre-epreuves inverses le mesurent, dans
-- outils/bancs/contre-epreuves-chantier5.py : elles REINJECTENT la mecanique supprimee et verifient
-- que le banc la voit.
--
-- PREUVES STRUCTURELLES -- 8.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LA REQUETE D'AVOCAT TIREE AU HASARD DISPARAIT, LE RESTE DE LA DEFENSE NE BOUGE PAS.
--
-- `detention_reduire_peine` etait la derniere porte du jeu ou un DE decidait si une plaidoirie
-- etait bonne : le navigateur tirait `Math.min(85, 40 + DUP*1.5)` contre un d100 et le serveur
-- enregistrait le verdict du de. Human Gambit ne code pas les reactions humaines : un juge qui
-- allege une peine est un joueur, pas une probabilite. La porte part, sa colonne de travail part,
-- et rien d'autre ne part.
--
-- CE QUI RESTE, ET C'EST VOLONTAIRE : les huit portes qui portent le mot « avocat » et qui sont
-- de vraies mecaniques judiciaires -- le barreau (`avocat_est_qualifie`, `avocat_ma_tarification`,
-- `avocat_publier_tarification`, `avocat_retirer_tarification`, `justice_avocats_disponibles`),
-- la defense retenue (`defense_avocat_de`), le dossier de l'avocat (`avocat_dossier`) et la
-- commission d'office de la procedure simplifiee (`justice_avocat_commis`).
--
-- LA COLONNE PART PARCE QU'ELLE EST MORTE, PAS PARCE QU'ELLE GENE. `detentions.reduction_jours`
-- n'a jamais ete ecrite par personne d'autre que cette porte, elle est NULLE sur toutes les
-- lignes existantes, et aucune autre fonction, vue ou contrainte ne la nomme. Releve en base
-- avant suppression.

DROP FUNCTION IF EXISTS public.detention_reduire_peine(boolean);
ALTER TABLE public.detentions DROP COLUMN IF EXISTS reduction_jours;

DO $$
DECLARE v_n integer; v_manque text;
BEGIN
  -- P1 -- la porte n'existe plus, sous AUCUNE signature.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    AND n.nspname = 'public' WHERE p.proname = 'detention_reduire_peine';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P1 ECHOUEE -- detention_reduire_peine survit (%)', v_n; END IF;

  -- P2 -- aucun droit residuel ne porte ce nom.
  SELECT count(*) INTO v_n FROM information_schema.routine_privileges
   WHERE routine_schema = 'public' AND routine_name = 'detention_reduire_peine';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P2 ECHOUEE -- des droits survivent (%)', v_n; END IF;

  -- P3 -- aucune fonction n'appelle plus la porte disparue.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    AND n.nspname = 'public' WHERE public.sans_commentaires(p.prosrc) LIKE '%detention_reduire_peine%';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P3 ECHOUEE -- % appelant(s) residuel(s)', v_n; END IF;

  -- P4 -- le mode de cloture « anticipee_avocat » n'est plus produit par aucune porte.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    AND n.nspname = 'public' WHERE public.sans_commentaires(p.prosrc) LIKE '%anticipee_avocat%';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P4 ECHOUEE -- % producteur(s) de anticipee_avocat', v_n; END IF;

  -- P5 -- la colonne de travail de la porte a disparu.
  SELECT count(*) INTO v_n FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'detentions' AND column_name = 'reduction_jours';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P5 ECHOUEE -- detentions.reduction_jours survit'; END IF;

  -- P6 -- aucune fonction ne nomme plus la colonne disparue.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    AND n.nspname = 'public' WHERE public.sans_commentaires(p.prosrc) LIKE '%reduction_jours%';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P6 ECHOUEE -- % lecteur(s) de reduction_jours', v_n; END IF;

  -- P7 -- LES HUIT VRAIES MECANIQUES DE L'AVOCAT SURVIVENT. Une suppression qui emporterait le
  -- barreau ou la defense retenue serait un degat, pas un nettoyage.
  SELECT string_agg(x.nom, ', ') INTO v_manque FROM (VALUES
      ('avocat_dossier'), ('avocat_est_qualifie'), ('avocat_ma_tarification'),
      ('avocat_publier_tarification'), ('avocat_retirer_tarification'),
      ('defense_avocat_de'), ('justice_avocat_commis'), ('justice_avocats_disponibles')
    ) AS x(nom)
   WHERE NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                      AND n.nspname = 'public' WHERE p.proname = x.nom);
  IF v_manque IS NOT NULL THEN
    RAISE EXCEPTION 'P7 ECHOUEE -- mecanique(s) legitime(s) emportee(s) : %', v_manque; END IF;

  -- P8 -- la detention elle-meme reste entiere : ses portes et sa table sont intactes.
  SELECT string_agg(x.nom, ', ') INTO v_manque FROM (VALUES
      ('detention_active'), ('detention_clore_interne'), ('detention_ouvrir_interne'),
      ('detention_clore_evasion')
    ) AS x(nom)
   WHERE NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                      AND n.nspname = 'public' WHERE p.proname = x.nom);
  IF v_manque IS NOT NULL THEN
    RAISE EXCEPTION 'P8 ECHOUEE -- porte(s) de detention emportee(s) : %', v_manque; END IF;

  RAISE NOTICE 'LES 8 PREUVES SONT VERTES.';
END $$;
