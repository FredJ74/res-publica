-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261011182306 (UTC), nom
-- `assemblee_presidence_suit_la_legislature`.
-- Le registre passe de 662 a 663 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 4b780a0772b07ce23569587ca615e267, 15885 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LA PRESIDENCE SUIT LA LEGISLATURE
--
-- L'invariant arbitre le 11 octobre au soir : un President de l'Assemblee doit etre l'un des NEUF
-- deputes de la legislature EN COURS, et il ne doit jamais exister de periode ou un ancien depute
-- preside la nouvelle Assemblee.
-- CE QUE L'AUDIT A TROUVE, et qui etait plus grave que le point signale a la quatrieme passe. Le
-- siege d'un depute joueur etait derive de `personnages.poste_depute` SEUL -- une valeur POSEE sur
-- la fiche, que le declencheur d'attestation ne verifie QU'A L'ECRITURE. Un mandat acheve y
-- survivait donc tant que la fiche n'etait pas reecrite, c'est-a-dire INDEFINIMENT pour un joueur
-- deconnecte. La remise a zero existait, mais cote NAVIGATEUR seulement (reconcilierPosteElu, au
-- chargement) : un ancien depute deconnecte restait assis, et s'il presidait, il presidait la
-- legislature suivante.
-- LA CORRECTION EST EN DEUX LIGNES, ET ELLE NE DEPEND D'AUCUN CALENDRIER.
--   1. assemblee_occupation_sieges appelle `poste_est_atteste`, la regle d'attestation UNIQUE du
--      projet, qui pour un depute lit `cycles_electoraux.data -> 'elus' ? nom`. Les neuf mandats
--      commencent et finissent donc A L'INSTANT ou le cycle de leur ville les liste ou cesse de les
--      lister -- et le cycle est reecrit en UNE ecriture par ville, donc le renouvellement est
--      SIMULTANE par construction.
--   2. assemblee_president ne rend le titulaire du registre que s'il est l'un des neuf
--      (assemblee_est_des_neuf, PJ comme PNJ). La presidence tombe dans la MEME lecture que le
--      mandat : il n'y a aucune fenetre, parce qu'il n'y a aucun instant a attendre.
-- AUCUN CRON NE PORTE L'INVARIANT. assemblee_presidence_fin_de_legislature, appelee par cron-minuit
-- avant la convocation du lundi, ne CREE pas la fin de la presidence : elle l'ENREGISTRE, en
-- retirant du registre des postes une ligne devenue fausse -- sans quoi la FICHE de l'ancien
-- President continuerait d'afficher son titre. Idempotente par nature.
-- ET LA JUSTIFICATION « LE DERNIER PNJ A CEDER SA PLACE », ecrite a la quatrieme passe, etait fausse
-- en game design : elle est retiree. Le rang d'un PNJ n'est pas une protection, c'est l'ordre
-- d'appariement des deputes joueurs elus -- et une preuve verifie qu'aucune des quatre fonctions de
-- l'invariant ne nomme un PNJ en dur.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- ASSEMBLEE NATIONALE -- CORRECTIF : LA PRESIDENCE SUIT LA LEGISLATURE
-- 11 octobre 2026
--
-- L'INVARIANT ARBITRE : un President de l'Assemblee doit etre l'un des NEUF deputes de la
-- legislature EN COURS. Il ne doit jamais exister de periode ou un ancien depute continue a
-- presider la nouvelle Assemblee.
--
-- CE QUE L'AUDIT A TROUVE, ET QUI EST PLUS GRAVE QUE PREVU. Le siege d'un depute joueur etait
-- derive de `personnages.poste_depute` SEUL. Or ce champ est une valeur POSEE sur la fiche, et le
-- declencheur d'attestation ne le verifie qu'A L'ECRITURE : un depute dont le mandat s'acheve
-- garde donc `poste_depute` en base tant que SA PROPRE FICHE n'est pas reecrite. La remise a zero
-- existait, mais cote NAVIGATEUR seulement (reconcilierPosteElu, plateau-politique.js, au
-- chargement). Un ancien depute deconnecte restait donc assis -- et, s'il presidait, il presidait
-- la legislature suivante. C'est exactement la periode que l'arbitrage interdit.
--
-- LA CORRECTION EST EN DEUX LIGNES, ET ELLE EST CALENDAIRE-INDEPENDANTE.
--
--   1. UN SIEGE PJ N'EXISTE QUE SI LE MANDAT EST ATTESTE. assemblee_occupation_sieges appelle
--      desormais public.poste_est_atteste -- la regle d'attestation UNIQUE du projet, celle que le
--      declencheur de la fiche utilise deja -- au lieu de faire confiance au champ pose. Pour un
--      depute, cette regle lit `cycles_electoraux.data -> 'elus' ? nom` : la VERITE du
--      depouillement, et rien d'autre.
--
--   2. LA PRESIDENCE EST DERIVEE, PAS STOCKEE. assemblee_president ne rend le titulaire du
--      registre que s'il est l'un des neuf. Le reste de la seance lit cette fonction et elle
--      seule : la presidence d'un ancien depute cesse donc A L'INSTANT MEME ou son mandat cesse.
--
-- POURQUOI C'EST MIEUX QU'UN CRON. Aucune tache planifiee ne peut garantir « jamais » : un cron
-- en retard, un redeploiement, une passe manquee, et l'ancien President presiderait quelques
-- heures. Ici il n'y a aucune fenetre, parce qu'il n'y a aucun instant a attendre : les neuf
-- changent, la presidence tombe dans la meme lecture. La regle tient sous le calendrier actuel
-- comme sous n'importe quel autre -- hebdomadaire ou non, dimanche ou lundi.
--
-- CE QUI N'EST PAS TOUCHE, DELIBEREMENT : le scrutin presidentiel (aucune candidature, PNJ
-- abstentionnistes, courte paille serveur, fenetre du lundi, cloture a 23 heures), les neuf
-- sieges, les autres PNJ, le moteur electoral, la duree des mandats.
--
-- ET IL N'Y A AUCUNE PROTECTION DU SIEGE DE LAROCHE, NI D'AUCUN PRESIDENT SORTANT. Le rang d'un
-- PNJ dans sa ville n'est pas une protection : c'est l'ordre d'appariement des deputes joueurs
-- elus, identique dans les trois villes depuis le 10 septembre, et il ne survit pas a un
-- renouvellement -- puisque la presidence ne survit pas au mandat. La justification « le dernier
-- PNJ a ceder sa place », ecrite a la quatrieme passe, etait fausse en game design : elle est
-- retiree des commentaires du depot, et aucune ligne de code ne l'a jamais implementee.

-- ============================================================================================
-- 1. UN SIEGE PJ N'EXISTE QUE SI LE MANDAT EST ATTESTE
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.assemblee_occupation_sieges(p_country text)
RETURNS TABLE(siege_id text, city text, rang integer, pnj_id text, pnj_nom text, endormi boolean,
              pj_nom text, est_pnj boolean)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH deputes_pj AS (
    SELECT
      p.name AS pj_nom,
      p.poste_depute->>'city' AS city,
      -- COLLATE "C" : tri par point de code, PAS par collation locale. Le client doit reproduire
      -- ce classement a l'identique (assembleeCalculerOccupation, plateau-assemblee.js) pour
      -- afficher le bon PNJ en assistant parlementaire. Une collation locale (en_US.utf8) classe
      -- "Émile" avant "Fabien", un tri par point de code le classe apres : les deux moteurs
      -- attribueraient alors des rangs differents sur des noms accentues, tres frequents en
      -- francais. COLLATE "C" cote SQL et le tri par defaut de Array.prototype.sort() cote JS
      -- (ordre des unites de code UTF-16) coincident sur tout le plan multilingue de base.
      row_number() OVER (
        PARTITION BY p.poste_depute->>'city'
        ORDER BY p.name COLLATE "C"
      ) AS rang
    FROM public.personnages p
    WHERE p.country = p_country
      AND p.poste_depute IS NOT NULL
      AND p.poste_depute->>'id' = 'depute'
      AND p.poste_depute->>'city' IS NOT NULL
      -- LE MANDAT EST ATTESTE, OU LE SIEGE N'EXISTE PAS (correctif du 11 octobre 2026).
      -- `poste_depute` est une valeur POSEE sur la fiche : le declencheur d'attestation ne la
      -- verifie qu'a l'ECRITURE, donc un mandat acheve y survit tant que la fiche n'est pas
      -- reecrite -- indefiniment pour un joueur deconnecte. On relit donc la regle d'attestation
      -- UNIQUE du projet, qui pour un depute lit `cycles_electoraux.data -> 'elus' ? nom`.
      --
      -- CONSEQUENCE VOULUE, ET C'EST TOUT L'ARBITRAGE : les neuf mandats commencent et finissent
      -- A L'INSTANT ou le cycle de leur ville les liste ou cesse de les lister. Le cycle est
      -- reecrit en UNE ecriture par ville, donc le renouvellement est SIMULTANE par construction
      -- -- il n'y a aucun depute « en cours de sortie ».
      AND public.poste_est_atteste(p.name, p.poste_depute, p.country)
  )
  SELECT
    s.id, s.city, s.rang, s.pnj_id, s.pnj_nom, s.endormi,
    d.pj_nom,
    (d.pj_nom IS NULL) AS est_pnj
  FROM public.assemblee_sieges s
  LEFT JOIN deputes_pj d
    ON d.city = s.city AND d.rang = s.rang
  WHERE s.country = p_country
  ORDER BY s.city, s.rang;
$$;

-- ============================================================================================
-- 2. « EST-IL L'UN DES NEUF ? » -- UN SEUL LECTEUR
-- ============================================================================================
-- A ne pas confondre avec assemblee_est_depute, qui ne reconnait que les deputes JOUEURS
-- (o.pj_nom). Ici, PJ comme PNJ : un depute PNJ peut etre elu President, et il l'est alors
-- legitimement. C'est cette fonction, et elle seule, qui dit l'appartenance aux neuf.
CREATE OR REPLACE FUNCTION public.assemblee_est_des_neuf(p_pays text, p_nom text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (SELECT 1 FROM public.assemblee_occupation_sieges(p_pays) o
                  WHERE coalesce(o.pj_nom, o.pnj_nom) = p_nom);
$$;

COMMENT ON FUNCTION public.assemblee_est_des_neuf(text, text) IS
  'Ce nom tient-il l''un des neuf sieges de la legislature EN COURS -- joueur ou PNJ ? '
  'Point de verite unique de l''appartenance aux neuf (correctif du 11 octobre 2026).';

-- ============================================================================================
-- 3. LA PRESIDENCE EST DERIVEE DE LA LEGISLATURE
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.assemblee_president(p_pays text)
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  -- L'INVARIANT, ECRIT LA OU TOUT LE MONDE LE LIT : un President de l'Assemblee est l'un des
  -- neuf deputes de la legislature en cours. Le registre des postes nomme un titulaire ; cette
  -- fonction ne le rend que s'il siege encore. Un ancien depute ne preside donc RIEN, et il n'y
  -- a aucune periode a couvrir : la presidence tombe dans la meme lecture que le mandat.
  SELECT a.titulaire FROM public.postes_attribues a
   WHERE a.country = p_pays AND a.poste_id = 'president_assemblee' AND a.city IS NULL
     AND public.assemblee_est_des_neuf(p_pays, a.titulaire)
   LIMIT 1;
$$;

COMMENT ON FUNCTION public.assemblee_president(text) IS
  'Le President de l''Assemblee EN FONCTION : le titulaire du registre, et seulement s''il est '
  'l''un des neuf deputes de la legislature en cours (correctif du 11 octobre 2026). Une '
  'presidence ne survit jamais au mandat qui la porte.';

-- ============================================================================================
-- 4. LE FAIT EST CONSIGNE : LE REGISTRE EST NETTOYE
-- ============================================================================================
-- La fonction ci-dessus suffit a ce que l'ancien President ne preside plus. Elle ne suffit pas a
-- ce que sa FICHE arrete de l'annoncer : `poste_est_atteste` valide un poste nomme contre
-- `postes_attribues`, donc la ligne perimee continuerait d'attester son titre. On la retire, et
-- c'est le seul effet de cette porte -- elle ne cree pas la fin de la presidence, elle
-- l'enregistre.
--
-- IDEMPOTENTE PAR NATURE : elle ne retire que ce qui ne devrait plus etre la. Deux passages de
-- suite, le second ne trouve rien.
CREATE OR REPLACE FUNCTION public.assemblee_presidence_fin_de_legislature(p_pays text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE r record; v_sortis jsonb := '[]'::jsonb;
BEGIN
  IF p_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pays_absent');
  END IF;

  FOR r IN
    SELECT a.id, a.titulaire, a.depuis FROM public.postes_attribues a
     WHERE a.country = p_pays AND a.poste_id = 'president_assemblee' AND a.city IS NULL
       AND NOT public.assemblee_est_des_neuf(p_pays, a.titulaire)
     FOR UPDATE
  LOOP
    DELETE FROM public.postes_attribues WHERE id = r.id;
    v_sortis := v_sortis || jsonb_build_object('ancien_president', r.titulaire, 'depuis', r.depuis);
  END LOOP;

  RETURN jsonb_build_object('ok', true,
    'sortis', jsonb_array_length(v_sortis), 'detail', v_sortis,
    'president', public.assemblee_president(p_pays));
END;
$$;

REVOKE ALL ON FUNCTION public.assemblee_presidence_fin_de_legislature(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assemblee_presidence_fin_de_legislature(text) FROM anon;
REVOKE ALL ON FUNCTION public.assemblee_presidence_fin_de_legislature(text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.assemblee_presidence_fin_de_legislature(text) TO service_role;

REVOKE ALL ON FUNCTION public.assemblee_est_des_neuf(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assemblee_est_des_neuf(text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.assemblee_est_des_neuf(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assemblee_est_des_neuf(text, text) TO service_role;

-- ============================================================================================
-- PREUVES STRUCTURELLES
-- ============================================================================================
DO $$
DECLARE v_txt text; v_n integer;
BEGIN
  -- 1. UN SIEGE PJ PASSE PAR LA REGLE D'ATTESTATION UNIQUE, et non par le champ pose.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_occupation_sieges';
  IF v_txt NOT LIKE '%poste_est_atteste%' THEN
    RAISE EXCEPTION 'PREUVE 1 : le siege d''un depute PJ ne verifie pas l''attestation du mandat';
  END IF;

  -- 2. ET CETTE REGLE LIT BIEN LE DEPOUILLEMENT pour un depute : si elle cessait de le faire,
  --    le renouvellement cesserait d'etre simultane sans que rien ne rougisse ici.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'poste_est_atteste';
  IF v_txt NOT LIKE '%''elus''%' OR v_txt NOT LIKE '%cycles_electoraux%' THEN
    RAISE EXCEPTION 'PREUVE 2 : l''attestation d''un depute ne lit plus les elus du cycle';
  END IF;

  -- 3. LA PRESIDENCE EST DERIVEE DES NEUF. C'est l'invariant, et il est dans la fonction que
  --    toute la seance lit.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_president';
  IF v_txt NOT LIKE '%assemblee_est_des_neuf%' THEN
    RAISE EXCEPTION 'PREUVE 3 : la presidence ne verifie pas l''appartenance aux neuf';
  END IF;

  -- 4. « L'UN DES NEUF » COMPTE LES PNJ AUSSI. Sans le coalesce, un President PNJ -- Laroche
  --    aujourd'hui -- serait depose par son propre invariant.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_est_des_neuf';
  IF v_txt NOT LIKE '%coalesce(o.pj_nom, o.pnj_nom)%' THEN
    RAISE EXCEPTION 'PREUVE 4 : l''appartenance aux neuf ignore les deputes PNJ';
  END IF;
  IF v_txt NOT LIKE '%assemblee_occupation_sieges%' THEN
    RAISE EXCEPTION 'PREUVE 4 bis : l''appartenance aux neuf ne derive pas des sieges';
  END IF;

  -- 5. AUCUN NOM CODE EN DUR dans les fonctions de l'invariant : aucune protection
  --    particuliere pour Laroche ni pour quiconque.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('assemblee_president', 'assemblee_est_des_neuf',
                       'assemblee_occupation_sieges', 'assemblee_presidence_fin_de_legislature')
     AND (p.prosrc ILIKE '%laroche%' OR p.prosrc ILIKE '%delorme%' OR p.prosrc ILIKE '%vauclerc%');
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'PREUVE 5 : % fonction(s) de l''invariant nomment un PNJ en dur', v_n;
  END IF;

  -- 6. AUCUN DIXIEME PARLEMENTAIRE : les eligibles derivent toujours des neuf sieges.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_presidence_eligibles';
  IF v_txt NOT LIKE '%assemblee_occupation_sieges%' THEN
    RAISE EXCEPTION 'PREUVE 6 : les eligibles ne derivent plus des neuf sieges';
  END IF;
  SELECT count(*) INTO v_n FROM public.assemblee_presidence_eligibles('republic');
  IF v_n <> 9 THEN RAISE EXCEPTION 'PREUVE 6 bis : % eligibles au lieu de 9', v_n; END IF;

  -- 7. LE SCRUTIN N'A PAS BOUGE. Le vote refuse toujours un nom hors des neuf figes, et la
  --    presence dans l'hemicycle reste exigee : le correctif ne rouvre pas ces regles.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_presidence_voter';
  IF v_txt NOT LIKE '%pas_eligible%' OR v_txt NOT LIKE '%hors_hemicycle%' THEN
    RAISE EXCEPTION 'PREUVE 7 : le scrutin presidentiel a ete touche';
  END IF;

  -- 8. LA PORTE QUI NETTOIE LE REGISTRE N'EST PAS A LA MAIN DES JOUEURS.
  SELECT string_agg(g.grantee, ', ') INTO v_txt
    FROM information_schema.role_routine_grants g
   WHERE g.specific_schema = 'public'
     AND g.routine_name = 'assemblee_presidence_fin_de_legislature'
     AND g.grantee IN ('anon', 'authenticated', 'PUBLIC');
  IF v_txt IS NOT NULL THEN
    RAISE EXCEPTION 'PREUVE 8 : la fin de legislature est accordee a %', v_txt;
  END IF;

  -- 9. ELLE NE RETIRE QUE LA PRESIDENCE, et seulement celle d'un non-depute. Elle ne touche ni
  --    les sieges, ni les mandats, ni un autre poste nomme.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_presidence_fin_de_legislature';
  IF v_txt NOT LIKE '%president_assemblee%'
     OR v_txt NOT LIKE '%NOT public.assemblee_est_des_neuf%' THEN
    RAISE EXCEPTION 'PREUVE 9 : la fin de legislature ne cible pas la seule presidence perimee';
  END IF;
  IF v_txt LIKE '%assemblee_sieges%' OR v_txt LIKE '%poste_depute%'
     OR v_txt LIKE '%cycles_electoraux%' THEN
    RAISE EXCEPTION 'PREUVE 9 bis : la fin de legislature touche les sieges ou les mandats';
  END IF;

  RAISE NOTICE 'LES 9 PREUVES DU CORRECTIF SONT VERTES.';
END $$;
