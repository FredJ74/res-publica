-- =============================================================================================
-- BANC -- LE GREFFE, SES DOCUMENTS, LA SALLE DE REUNION, ET LE JUGE CONTRE LE PARQUET
-- 13 octobre 2026. 39 EPREUVES.
-- =============================================================================================
--
-- USAGE : coller ce fichier dans un execute_sql. Il doit finir sur
--   ERROR: banc greffe : LES 39 EPREUVES SONT VERTES.  -- rien ne doit rester
-- Il ouvre une transaction et la ROLLBACK : aucun banc ne commite jamais.
--
-- HUIT CHAPITRES, ET CHACUN MESURE LES DEUX COTES.
--
--   1. L'EXTRAIT DE SON PROPRE CASIER (D1, G1 a G4) -- le decor lui-meme est verifie, puis le
--      refus hors du greffe, la delivrance au greffe, l'argent qui entre dans la caisse du
--      TRIBUNAL, le document present AUX DEUX ENDROITS (registre et inventaire), et la fermeture
--      du registre de provenance au client.
--   2. LE CONTENU DU CASIER (G5 a G7) -- vierge, puis une condamnation, puis une relaxe
--      DEFINITIVE en appel qui l'en retire. Et le texte du plaignant qui n'y entre jamais.
--   3. L'EXTRAIT D'UN AUTRE DANS UNE ENQUETE (G8 a G12) -- trois autorites et aucune autre, une
--      affaire VIVANTE exigee, la caisse de l'INSTITUTION debitee (tribunal pour le parquet,
--      commissariat pour le commissaire), et une caisse vide qui refuse SANS rien consommer.
--   4. CORROMPRE LE GREFFIER (G13 a G19) -- le greffe COMPETENT exige pour un dossier, les couts
--      preleves A LA TENTATIVE, les 300 FR DETRUITS, LES DEUX ISSUES observees pour de vrai, le
--      faux casier indistinguable d'un vrai, et le VRAI casier intact.
--   5. LA SALLE DE REUNION (U1 a U4) -- la presence exigee, les frais de greffe au tribunal,
--      TROIS syndicats dans la meme salle, et un bail impossible meme par ecriture directe.
--   6. LE DUPLICATA (U5 a U8) -- President ou Secretaire, et personne d'autre : ni un tiers, ni
--      le Tresorier. Et pas de duplicata sans original.
--   7. LES MILITANTS (U9 a U11) -- les trois regles au serveur : adhesion, un par JOUR DE JEU,
--      plafond de deux. Et aucun refus ne coute un PA.
--   8. LE JUGE CONTRE LE PARQUET (J1 a J8) -- le juge ne prend pas la main avant le non-lieu, il
--      rouvre apres, les DEUX decisions coexistent, le journal l'apprend, et la chaine va
--      jusqu'au jugement SANS LA MOINDRE TRACE OBJECTIVE -- la culpabilite judiciaire ne depend
--      pas d'une preuve serveur.
--
-- TROIS PIEGES QUE CE BANC EVITE, ET QUI LUI ONT COUTE UN TOUR CHACUN.
--
--   * `recherche` NE SE REINITIALISE PAS DEPUIS UN BANC. La colonne est gardee en ecriture
--     (`rp.recherche_interne`) : un `UPDATE ... SET recherche = '[]'` passe en silence sans rien
--     changer. La mesure est donc un DELTA -- `pg_temp.recherches_corruption` compte avant et
--     apres --, jamais une valeur absolue apres remise a zero.
--   * UN JET ALEATOIRE SE MESURE EN REJOUANT. La corruption du greffier a 25 % de decouverte :
--     le banc rejoue jusqu'a observer LES DEUX issues (certain a 0,75^40 et 0,25^40 pres) et
--     verifie les invariants de chacune. Un banc qui n'en verrait qu'une serait vert a moitie.
--   * UN DECOR QUI MENT PROUVE N'IMPORTE QUOI. D1 verifie le greffier du registre AVANT tout le
--     reste, et J7 verifie l'ABSENCE de traces objectives avant d'affirmer qu'on juge sans elles.
-- =============================================================================================

BEGIN;
CREATE OR REPLACE FUNCTION pg_temp.je_suis(p_uuid text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', p_uuid, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
END $f$;
CREATE OR REPLACE FUNCTION pg_temp.je_suis_le_serveur() RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM set_config('role', 'postgres', true);
  PERFORM set_config('request.jwt.claims', '', true);
END $f$;
CREATE OR REPLACE FUNCTION pg_temp.au_greffe(p_qui text, p_ville text) RETURNS void
LANGUAGE plpgsql AS $f$
BEGIN
  UPDATE public.personnages_donnees SET current_city = p_ville,
         current_building = CASE WHEN p_ville = 'capitale' THEN 'tribunal' ELSE 'tribunal-local' END,
         current_room = 'greffe', pa = 40
   WHERE name = p_qui;
END $f$;
CREATE OR REPLACE FUNCTION pg_temp.en_salle(p_qui text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  UPDATE public.personnages_donnees SET current_city = 'capitale',
         current_building = 'universite', current_room = 'salle_reunion', pa = 40
   WHERE name = p_qui;
END $f$;
CREATE OR REPLACE FUNCTION pg_temp.siege(p_qui text, p_poste text, p_ville text) RETURNS void
LANGUAGE plpgsql AS $f$
BEGIN
  DELETE FROM public.postes_attribues WHERE poste_id = p_poste;
  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, source)
  VALUES ('banc-greffe-' || p_poste, 'republic', p_poste, p_ville, p_qui, 'banc');
  UPDATE public.personnages_donnees
     SET poste = CASE WHEN p_ville IS NULL THEN jsonb_build_object('id', p_poste)
                      ELSE jsonb_build_object('id', p_poste, 'city', p_ville) END
   WHERE name = p_qui;
END $f$;
-- LE DELTA, PAS LA VALEUR ABSOLUE. `recherche` est gardee en ecriture : un banc ne peut pas la
-- remettre a zero, il doit compter avant et apres.
CREATE OR REPLACE FUNCTION pg_temp.recherches_corruption(p_qui text) RETURNS integer
LANGUAGE sql AS $f$
  SELECT count(*)::int FROM public.personnages_donnees d,
         jsonb_array_elements(CASE WHEN jsonb_typeof(d.recherche) = 'array'
                                   THEN d.recherche ELSE '[]'::jsonb END) r
   WHERE d.name = p_qui AND r ->> 'acte' = 'corruption_fonctionnaire';
$f$;
GRANT EXECUTE ON FUNCTION pg_temp.je_suis(text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION pg_temp.je_suis_le_serveur() TO PUBLIC;
GRANT EXECUTE ON FUNCTION pg_temp.au_greffe(text, text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION pg_temp.en_salle(text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION pg_temp.siege(text, text, text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION pg_temp.recherches_corruption(text) TO PUBLIC;

DO $banc$
DECLARE
  JUGE_U text := '0821bcdf-0c69-4ba3-adcd-f60d9b82b7bf'; JUGE text := 'Phileas Frogg';
  PROC_U text := 'ea4a2a0c-a192-4e10-8cff-d5db9b1cceb6'; PROC text := 'Lee Capene';
  COMM_U text := '3d91b1fa-a22d-41ae-82cf-fef98194b10a'; COMM text := 'May';
  PLAI_U text := 'a5a55fc8-64fa-4406-b617-76439d1d4aac'; PLAI text := 'Marsault';
  PREV_U text := 'bafc96b1-1628-4ae2-93d2-78d89f8ac5b5'; PREV text := 'Ben';
  v jsonb; n integer := 0; ko integer := 0; e text := ''; v_n integer; v_s text;
  a text; o1 text; o2 text; o3 text;
  v_arg numeric; v_pa integer; v_trib numeric; v_comm numeric;
  v_essais integer; v_succes integer := 0; v_dec integer := 0; v_doc text; v_avant integer;
BEGIN
  PERFORM pg_temp.je_suis_le_serveur();
  DELETE FROM public.plaintes_en_cours
   WHERE data LIKE '%' || PREV || '%' OR data LIKE '%' || PLAI || '%';
  DELETE FROM public.postes_attribues WHERE poste_id IN ('juge','procureur','commissaire');
  DELETE FROM public.carrieres_acquises WHERE personnage IN (JUGE, PROC, COMM, PLAI, PREV);
  DELETE FROM public.jugements WHERE accuse IN (PLAI, PREV);
  DELETE FROM public.pnj_militants_metier WHERE pnj_id IN
    (SELECT id FROM public.pnj_membres WHERE proprietaire_pj IN (PLAI, PREV));
  DELETE FROM public.pnj_membres WHERE proprietaire_pj IN (PLAI, PREV);
  DELETE FROM public.militants_recrutes WHERE recruteur IN (PLAI, PREV);
  DELETE FROM public.organisations WHERE id LIKE 'orga_syndet_%' OR id LIKE 'orga_banc_%';
  UPDATE public.personnages_donnees SET poste = NULL, est_emprisonne = NULL,
         hp = 100, pa = 40, arg = 900000, liquide = 900000,
         country = 'republic', inventory = '[]'::jsonb
   WHERE name IN (JUGE, PROC, COMM, PLAI, PREV);
  DELETE FROM public.detentions WHERE nom IN (JUGE, PROC, COMM, PLAI, PREV);
  UPDATE public.personnages_donnees SET career = 'magistrat' WHERE name IN (JUGE, PROC, COMM);
  PERFORM pg_temp.siege(PROC, 'procureur', NULL);

  n := n + 1;   -- D1 : LE DECOR LUI-MEME EST VERIFIE.
  IF public.greffe_signataire('republic', 'capitale') IS DISTINCT FROM 'Greffier Petit' THEN
    ko := ko + 1; e := e || E'\nD1 : le greffier de Luthecia n''est pas celui du registre'; END IF;
  IF public.greffe_signataire('republic', 'ville_a') NOT LIKE 'Greffe du tribunal de %' THEN
    ko := ko + 1; e := e || E'\nD1 : le greffe sans greffier nomme ne signe pas par l''institution'; END IF;

  n := n + 1;   -- G1 : HORS DU GREFFE, RIEN -- et aucun cout n'est preleve.
  UPDATE public.personnages_donnees SET current_city='capitale',
         current_building='hotel-republica', current_room='bar' WHERE name = PLAI;
  SELECT arg, pa INTO v_arg, v_pa FROM public.personnages_donnees WHERE name = PLAI;
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.casier_mon_extrait();
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'presence_au_greffe_requise' THEN
    ko := ko + 1; e := e || E'\nG1 : extrait delivre depuis un bar -- ' || v::text; END IF;
  IF (SELECT arg FROM public.personnages_donnees WHERE name = PLAI) <> v_arg
     OR (SELECT pa FROM public.personnages_donnees WHERE name = PLAI) <> v_pa THEN
    ko := ko + 1; e := e || E'\nG1 : un refus a preleve quelque chose'; END IF;

  n := n + 1;   -- G2 : AU GREFFE, L'EXTRAIT EST DELIVRE, ET LES 100 FR VONT AU TRIBUNAL.
  PERFORM pg_temp.au_greffe(PLAI, 'capitale');
  SELECT arg, pa INTO v_arg, v_pa FROM public.personnages_donnees WHERE name = PLAI;
  SELECT (data->>'solde')::numeric INTO v_trib FROM public.caisses_batiments
   WHERE id = 'republic_tribunal_capitale';
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.casier_mon_extrait();
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nG2 : extrait refuse au greffe -- ' || v::text;
  ELSE
    IF (SELECT arg FROM public.personnages_donnees WHERE name = PLAI) <> v_arg - 100 THEN
      ko := ko + 1; e := e || E'\nG2 : les 100 FR ne sont pas preleves'; END IF;
    IF (SELECT pa FROM public.personnages_donnees WHERE name = PLAI) <> v_pa - 1 THEN
      ko := ko + 1; e := e || E'\nG2 : le PA n''est pas preleve'; END IF;
    IF (SELECT (data->>'solde')::numeric FROM public.caisses_batiments
         WHERE id = 'republic_tribunal_capitale') <> v_trib + 100 THEN
      ko := ko + 1; e := e || E'\nG2 : la caisse du tribunal n''a pas encaisse'; END IF;
  END IF;

  n := n + 1;   -- G3 : LE DOCUMENT EXISTE AUX DEUX ENDROITS, ET L'OBJET NE PORTE PAS
                --      L'AUTHENTICITE -- la provenance vit ailleurs.
  SELECT count(*) INTO v_n FROM public.documents_officiels
   WHERE porteur = PLAI AND genre = 'casier_extrait' AND authentique AND sujet = PLAI;
  IF v_n <> 1 THEN ko := ko + 1; e := e || E'\nG3 : ' || v_n || ' ligne(s) au registre'; END IF;
  SELECT count(*) INTO v_n FROM public.personnages_donnees d, jsonb_array_elements(d.inventory) o
   WHERE d.name = PLAI AND o ->> 'type' = 'document_officiel'
     AND o ->> 'genre' = 'casier_extrait' AND NOT (o ? 'authentique')
     AND o ->> 'emis_par' = 'Greffier Petit' AND (o ->> 'stackable') = 'false';
  IF v_n <> 1 THEN ko := ko + 1; e := e || E'\nG3 : l''objet d''inventaire n''est pas conforme'; END IF;

  n := n + 1;   -- G4 : LE REGISTRE DES DOCUMENTS EST FERME AU CLIENT, et l'emission aussi.
  PERFORM pg_temp.je_suis(PLAI_U);
  BEGIN
    SELECT count(*) INTO v_n FROM public.documents_officiels;
    ko := ko + 1; e := e || E'\nG4 : un joueur lit le registre des documents';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    PERFORM public.document_officiel_emettre('casier_faux', 'casier_extrait', false, 'republic',
      'capitale', PLAI, NULL, NULL, PLAI, PLAI, 1, 'Faux', 'Faux', NULL, '{}'::jsonb);
    ko := ko + 1; e := e || E'\nG4 : un joueur emet un document lui-meme';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM pg_temp.je_suis_le_serveur();

  n := n + 1;   -- G5 : UN CASIER SANS CONDAMNATION EST VIERGE, et il le dit.
  v := public.casier_judiciaire_contenu(PREV, 'republic');
  IF (v ->> 'vierge')::boolean IS NOT TRUE OR jsonb_array_length(v -> 'condamnations') <> 0 THEN
    ko := ko + 1; e := e || E'\nG5 : casier non vierge -- ' || v::text; END IF;

  n := n + 1;   -- G6 : UNE CONDAMNATION Y ENTRE, LE TEXTE DU PLAIGNANT N'Y ENTRE PAS.
  INSERT INTO public.jugements (id, country, city, accuse, motif, peine, juge, jour, executee, data)
  VALUES ('jug-banc-g6', 'republic', 'capitale', PREV, 'Vol', 'Prison 1 jour', JUGE, 7, true,
          jsonb_build_object('verdict','condamnation','instance','premiere','infraction','vol',
                             'infraction_libelle','Vol','motif_allegue','TEXTE DU PLAIGNANT'));
  v := public.casier_judiciaire_contenu(PREV, 'republic');
  IF (v ->> 'vierge')::boolean IS NOT FALSE OR jsonb_array_length(v -> 'condamnations') <> 1 THEN
    ko := ko + 1; e := e || E'\nG6 : la condamnation n''entre pas au casier -- ' || v::text; END IF;
  IF v::text LIKE '%TEXTE DU PLAIGNANT%' THEN
    ko := ko + 1; e := e || E'\nG6 : le casier recopie le texte du plaignant'; END IF;

  n := n + 1;   -- G7 : UNE RELAXE DEFINITIVE EN APPEL L'EN RETIRE.
  INSERT INTO public.jugements (id, country, city, accuse, motif, peine, juge, jour, executee, data)
  VALUES ('jug-app-banc-g6', 'republic', 'capitale', PREV, 'Vol', NULL, JUGE, 8, true,
          jsonb_build_object('verdict','relaxe','instance','appel','definitif',true,'infraction','vol'));
  v := public.casier_judiciaire_contenu(PREV, 'republic');
  IF (v ->> 'vierge')::boolean IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nG7 : la relaxe d''appel ne vide pas le casier -- ' || v::text; END IF;
  DELETE FROM public.jugements WHERE id IN ('jug-banc-g6', 'jug-app-banc-g6');

  n := n + 1;   -- G8 : UN JOUEUR ORDINAIRE N'OBTIENT PAS LE CASIER D'UN AUTRE.
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.casier_extrait_enquete(PREV);
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'autorite_refusee' THEN
    ko := ko + 1; e := e || E'\nG8 : un plaignant obtient le casier d''autrui -- ' || v::text; END IF;

  n := n + 1;   -- G9 : LE PROCUREUR NON PLUS, HORS DE TOUTE ENQUETE.
  PERFORM pg_temp.au_greffe(PROC, 'capitale');
  PERFORM pg_temp.je_suis(PROC_U);
  v := public.casier_extrait_enquete(PREV);
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'aucune_enquete_sur_cette_personne' THEN
    ko := ko + 1; e := e || E'\nG9 : casier obtenu hors enquete -- ' || v::text; END IF;

  n := n + 1;   -- G10 : UNE AFFAIRE VIVANTE OUVRE LA PORTE, ET C'EST L'INSTITUTION QUI PAIE.
  UPDATE public.personnages_donnees SET current_city='capitale',
         current_building='commissariat', current_room='accueil_police' WHERE name = PLAI;
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.plainte_deposer(PREV, 'Emplois fictifs a la mairie', 'delit');
  PERFORM pg_temp.je_suis_le_serveur();
  a := v ->> 'id';
  IF a IS NULL THEN RAISE EXCEPTION 'DECOR ROMPU -- le depot est refuse : %', v::text; END IF;
  SELECT (data->>'solde')::numeric INTO v_trib FROM public.caisses_batiments
   WHERE id = 'republic_tribunal_capitale';
  SELECT arg, pa INTO v_arg, v_pa FROM public.personnages_donnees WHERE name = PROC;
  PERFORM pg_temp.au_greffe(PROC, 'capitale');
  PERFORM pg_temp.je_suis(PROC_U);
  v := public.casier_extrait_enquete(PREV);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nG10 : casier refuse dans une enquete -- ' || v::text;
  ELSE
    IF (SELECT arg FROM public.personnages_donnees WHERE name = PROC) <> v_arg THEN
      ko := ko + 1; e := e || E'\nG10 : le magistrat a paye de sa poche'; END IF;
    IF (SELECT pa FROM public.personnages_donnees WHERE name = PROC) <> v_pa - 1 THEN
      ko := ko + 1; e := e || E'\nG10 : le PA du magistrat n''est pas preleve'; END IF;
    IF (v ->> 'caisse_debitee') IS DISTINCT FROM 'republic_tribunal_capitale' THEN
      ko := ko + 1; e := e || E'\nG10 : caisse debitee = ' || coalesce(v ->> 'caisse_debitee','(nul)'); END IF;
  END IF;

  n := n + 1;   -- G11 : LE COMMISSAIRE PAIE SUR LA CAISSE DU COMMISSARIAT.
  PERFORM pg_temp.siege(COMM, 'commissaire', 'capitale');
  SELECT (data->>'solde')::numeric INTO v_comm FROM public.caisses_batiments
   WHERE id = 'republic_commissariat_capitale';
  SELECT (data->>'solde')::numeric INTO v_trib FROM public.caisses_batiments
   WHERE id = 'republic_tribunal_capitale';
  PERFORM pg_temp.au_greffe(COMM, 'capitale');
  PERFORM pg_temp.je_suis(COMM_U);
  v := public.casier_extrait_enquete(PREV);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE
     OR (v ->> 'caisse_debitee') IS DISTINCT FROM 'republic_commissariat_capitale' THEN
    ko := ko + 1; e := e || E'\nG11 : le commissaire ne paie pas sur sa caisse -- ' || v::text; END IF;
  IF (SELECT (data->>'solde')::numeric FROM public.caisses_batiments
       WHERE id = 'republic_commissariat_capitale') <> v_comm - 100 THEN
    ko := ko + 1; e := e || E'\nG11 : le commissariat n''a pas ete debite'; END IF;
  IF (SELECT (data->>'solde')::numeric FROM public.caisses_batiments
       WHERE id = 'republic_tribunal_capitale') <> v_trib + 100 THEN
    ko := ko + 1; e := e || E'\nG11 : le tribunal n''a pas encaisse les 100 FR'; END IF;

  n := n + 1;   -- G12 : CAISSE VIDE, REFUS PROPRE, ET RIEN DE CONSOMME.
  UPDATE public.caisses_batiments
     SET data = coalesce(data, '{}'::jsonb) || jsonb_build_object('solde', 10)
   WHERE id = 'republic_commissariat_capitale';
  SELECT pa INTO v_pa FROM public.personnages_donnees WHERE name = COMM;
  PERFORM pg_temp.je_suis(COMM_U);
  v := public.casier_extrait_enquete(PREV);
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'caisse_institution_insuffisante' THEN
    ko := ko + 1; e := e || E'\nG12 : une caisse vide delivre quand meme -- ' || v::text; END IF;
  IF (SELECT pa FROM public.personnages_donnees WHERE name = COMM) <> v_pa THEN
    ko := ko + 1; e := e || E'\nG12 : le refus de caisse a coute un PA'; END IF;

  n := n + 1;   -- G13 : AU GREFFE DE LA MAUVAISE VILLE, LA COPIE EST REFUSEE.
  PERFORM pg_temp.au_greffe(PREV, 'ville_b');
  SELECT arg, pa INTO v_arg, v_pa FROM public.personnages_donnees WHERE name = PREV;
  PERFORM pg_temp.je_suis(PREV_U);
  v := public.greffe_corrompre_dossier(a);
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'presence_au_greffe_requise' THEN
    ko := ko + 1; e := e || E'\nG13 : un dossier de Luthecia se copie a Montrouge -- ' || v::text; END IF;
  IF (SELECT arg FROM public.personnages_donnees WHERE name = PREV) <> v_arg THEN
    ko := ko + 1; e := e || E'\nG13 : un refus de presence a preleve les 300 FR'; END IF;

  n := n + 1;   -- G14 : LES DEUX COUTS SONT PRELEVES A LA TENTATIVE, ET LES 300 FR SONT DETRUITS.
  PERFORM pg_temp.au_greffe(PREV, 'capitale');
  SELECT arg, pa INTO v_arg, v_pa FROM public.personnages_donnees WHERE name = PREV;
  SELECT (data->>'solde')::numeric INTO v_trib FROM public.caisses_batiments
   WHERE id = 'republic_tribunal_capitale';
  PERFORM pg_temp.je_suis(PREV_U);
  v := public.greffe_corrompre_dossier(a);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nG14 : la tentative est refusee -- ' || v::text; END IF;
  IF (SELECT arg FROM public.personnages_donnees WHERE name = PREV) <> v_arg - 300
     OR (SELECT pa FROM public.personnages_donnees WHERE name = PREV) <> v_pa - 3 THEN
    ko := ko + 1; e := e || E'\nG14 : les couts ne sont pas preleves a la tentative'; END IF;
  IF (SELECT (data->>'solde')::numeric FROM public.caisses_batiments
       WHERE id = 'republic_tribunal_capitale') <> v_trib THEN
    ko := ko + 1; e := e || E'\nG14 : une caisse a encaisse le prix de la corruption'; END IF;

  n := n + 1;   -- G15 : LES DEUX ISSUES EXISTENT, ET CHACUNE A SA CONSEQUENCE EXACTE.
  v_essais := 0;
  WHILE v_essais < 40 AND (v_succes = 0 OR v_dec = 0) LOOP
    v_essais := v_essais + 1;
    PERFORM pg_temp.au_greffe(PREV, 'capitale');
    UPDATE public.personnages_donnees SET pa = 40, arg = 900000, liquide = 900000,
           inventory = '[]'::jsonb WHERE name = PREV;
    v_avant := pg_temp.recherches_corruption(PREV);
    PERFORM pg_temp.je_suis(PREV_U);
    v := public.greffe_corrompre_dossier(a);
    PERFORM pg_temp.je_suis_le_serveur();
    IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
      ko := ko + 1; e := e || E'\nG15 : tentative refusee -- ' || v::text; EXIT; END IF;
    IF (v ->> 'decouvert')::boolean THEN
      v_dec := v_dec + 1;
      IF (v ->> 'document') IS NOT NULL THEN
        ko := ko + 1; e := e || E'\nG15 : un document est delivre malgre la decouverte'; END IF;
      IF pg_temp.recherches_corruption(PREV) <> v_avant + 1 THEN
        ko := ko + 1; e := e || E'\nG15 : la decouverte n''a pas denonce le corrupteur'; END IF;
    ELSE
      v_succes := v_succes + 1;
      v_doc := v ->> 'document';
      IF v_doc IS NULL THEN
        ko := ko + 1; e := e || E'\nG15 : aucun document alors que la corruption a reussi'; END IF;
      SELECT count(*) INTO v_n FROM public.documents_officiels
       WHERE id = v_doc AND genre = 'dossier_copie' AND authentique AND affaire = a;
      IF v_n <> 1 THEN ko := ko + 1; e := e || E'\nG15 : la copie n''est pas au registre'; END IF;
      IF pg_temp.recherches_corruption(PREV) <> v_avant THEN
        ko := ko + 1; e := e || E'\nG15 : une reussite a denonce le corrupteur'; END IF;
    END IF;
  END LOOP;
  IF v_succes = 0 OR v_dec = 0 THEN
    ko := ko + 1; e := e || E'\nG15 : une seule issue observee en ' || v_essais
                         || ' tentatives (reussites ' || v_succes || ', decouvertes ' || v_dec || ')'; END IF;

  n := n + 1;   -- G16 : LA COPIE EST LE DOSSIER COMPLET.
  UPDATE public.personnages_donnees SET pa = 40, arg = 900000, liquide = 900000,
         inventory = '[]'::jsonb WHERE name = PREV;
  v := public.dossier_judiciaire_copie(a);
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE
     OR (v ->> 'prevenu') IS DISTINCT FROM PREV
     OR (v ->> 'motif') IS DISTINCT FROM 'Emplois fictifs a la mairie'
     OR NOT (v ? 'actes') OR NOT (v ? 'temoins') OR NOT (v ? 'preuves') THEN
    ko := ko + 1; e := e || E'\nG16 : la copie n''est pas le dossier complet -- ' || v::text; END IF;

  n := n + 1;   -- G17 : LE FAUX SE PRESENTE COMME UN VRAI, ET LE REGISTRE SAIT QU'IL EST FAUX.
  v_essais := 0; v_succes := 0;
  WHILE v_essais < 40 AND v_succes = 0 LOOP
    v_essais := v_essais + 1;
    PERFORM pg_temp.au_greffe(PREV, 'ville_a');
    UPDATE public.personnages_donnees SET pa = 40, arg = 900000, liquide = 900000 WHERE name = PREV;
    PERFORM pg_temp.je_suis(PREV_U);
    v := public.greffe_corrompre_faux_casier(PLAI);
    PERFORM pg_temp.je_suis_le_serveur();
    IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
      ko := ko + 1; e := e || E'\nG17 : tentative refusee -- ' || v::text; EXIT; END IF;
    IF NOT (v ->> 'decouvert')::boolean THEN v_succes := v_succes + 1; v_doc := v ->> 'document'; END IF;
  END LOOP;
  IF v_succes = 0 THEN
    ko := ko + 1; e := e || E'\nG17 : aucune reussite en ' || v_essais || ' tentatives';
  ELSE
    SELECT count(*) INTO v_n FROM public.documents_officiels
     WHERE id = v_doc AND genre = 'casier_faux' AND genre_apparent = 'casier_extrait'
       AND authentique = false AND sujet = PLAI;
    IF v_n <> 1 THEN ko := ko + 1; e := e || E'\nG17 : le faux n''est pas au registre comme faux'; END IF;
    SELECT count(*) INTO v_n FROM public.personnages_donnees d, jsonb_array_elements(d.inventory) o
     WHERE d.name = PREV AND o ->> 'document' = v_doc
       AND o ->> 'genre' = 'casier_extrait'
       AND o ->> 'name' = 'Extrait de casier judiciaire — ' || PLAI
       AND NOT (o ? 'authentique') AND (o -> 'contenu' ->> 'vierge') = 'true';
    IF v_n <> 1 THEN ko := ko + 1; e := e || E'\nG17 : l''objet du faux se distingue d''un vrai'; END IF;
  END IF;

  n := n + 1;   -- G18 : ET LE VRAI CASIER N'A PAS BOUGE D'UN IOTA.
  INSERT INTO public.jugements (id, country, city, accuse, motif, peine, juge, jour, executee, data)
  VALUES ('jug-banc-g18', 'republic', 'capitale', PLAI, 'Vol', 'Prison 1 jour', JUGE, 7, true,
          jsonb_build_object('verdict','condamnation','infraction','vol','infraction_libelle','Vol'));
  v := public.casier_judiciaire_contenu(PLAI, 'republic');
  IF (v ->> 'vierge')::boolean IS NOT FALSE THEN
    ko := ko + 1; e := e || E'\nG18 : le faux a vide le vrai casier -- ' || v::text; END IF;
  DELETE FROM public.jugements WHERE id = 'jug-banc-g18';

  n := n + 1;   -- G19 : UN FAUX AU NOM D'UN INCONNU N'EST PAS UN DOCUMENT.
  PERFORM pg_temp.au_greffe(PREV, 'capitale');
  UPDATE public.personnages_donnees SET pa = 40 WHERE name = PREV;
  PERFORM pg_temp.je_suis(PREV_U);
  v := public.greffe_corrompre_faux_casier('Personne Qui N Existe Pas');
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'personne_introuvable' THEN
    ko := ko + 1; e := e || E'\nG19 : un faux au nom d''un inconnu est accepte -- ' || v::text; END IF;

  n := n + 1;   -- U1 : HORS DE LA SALLE, AUCUNE DOMICILIATION.
  UPDATE public.personnages_donnees SET current_city='capitale',
         current_building='hotel-republica', current_room='bar' WHERE name = PLAI;
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.syndicat_etudiant_domicilier('Syndicat de la Sorbonne');
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'presence_en_salle_de_reunion_requise' THEN
    ko := ko + 1; e := e || E'\nU1 : domiciliation depuis un bar -- ' || v::text; END IF;

  n := n + 1;   -- U2 : DANS LA SALLE, TOUT PASSE, ET LES 150 FR SONT DES FRAIS DE GREFFE.
  PERFORM pg_temp.en_salle(PLAI);
  UPDATE public.personnages_donnees SET inventory = '[]'::jsonb WHERE name = PLAI;
  SELECT arg, pa INTO v_arg, v_pa FROM public.personnages_donnees WHERE name = PLAI;
  SELECT (data->>'solde')::numeric INTO v_trib FROM public.caisses_batiments
   WHERE id = 'republic_tribunal_capitale';
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.syndicat_etudiant_domicilier('Syndicat de la Sorbonne', 'Pour une universite libre');
  PERFORM pg_temp.je_suis_le_serveur();
  o1 := v ->> 'organisation';
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE OR o1 IS NULL THEN
    ko := ko + 1; e := e || E'\nU2 : domiciliation refusee -- ' || v::text;
  ELSE
    IF (SELECT arg FROM public.personnages_donnees WHERE name = PLAI) <> v_arg - 150
       OR (SELECT pa FROM public.personnages_donnees WHERE name = PLAI) <> v_pa - 2 THEN
      ko := ko + 1; e := e || E'\nU2 : les couts ne sont pas preleves'; END IF;
    IF (SELECT (data->>'solde')::numeric FROM public.caisses_batiments
         WHERE id = 'republic_tribunal_capitale') <> v_trib + 150 THEN
      ko := ko + 1; e := e || E'\nU2 : le tribunal n''a pas encaisse les frais de greffe'; END IF;
    SELECT count(*) INTO v_n FROM public.organisations
     WHERE id = o1 AND (data::jsonb ->> 'localId') = 'universite:salle_reunion'
       AND (data::jsonb ->> 'president') = PLAI
       AND (data::jsonb ->> 'syndicat_etudiant') = 'true'
       AND (data::jsonb ->> 'type') = 'syndicale';
    IF v_n <> 1 THEN ko := ko + 1; e := e || E'\nU2 : le syndicat n''est pas correctement ecrit'; END IF;
    SELECT count(*) INTO v_n FROM public.personnages_donnees d, jsonb_array_elements(d.inventory) o
     WHERE d.name = PLAI AND o ->> 'genre' = 'domiciliation_extrait'
       AND (o -> 'contenu' ->> 'organisation') = o1;
    IF v_n <> 1 THEN ko := ko + 1; e := e || E'\nU2 : l''extrait n''est pas dans l''inventaire'; END IF;
  END IF;

  n := n + 1;   -- U3 : AUCUNE EXCLUSIVITE -- TROIS SYNDICATS DANS LA MEME SALLE.
  PERFORM pg_temp.en_salle(PREV);
  UPDATE public.personnages_donnees SET pa = 40 WHERE name = PREV;
  PERFORM pg_temp.je_suis(PREV_U);
  v := public.syndicat_etudiant_domicilier('Union des Etudiants Veneres');
  PERFORM pg_temp.je_suis_le_serveur();
  o2 := v ->> 'organisation';
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nU3 : un second syndicat est refuse -- ' || v::text; END IF;
  PERFORM pg_temp.en_salle(PLAI);
  UPDATE public.personnages_donnees SET pa = 40 WHERE name = PLAI;
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.syndicat_etudiant_domicilier('Collectif des Amphis');
  PERFORM pg_temp.je_suis_le_serveur();
  o3 := v ->> 'organisation';
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nU3 : un troisieme syndicat est refuse -- ' || v::text; END IF;
  SELECT count(*) INTO v_n FROM public.organisations
   WHERE (data::jsonb ->> 'localId') = 'universite:salle_reunion';
  IF v_n <> 3 THEN
    ko := ko + 1; e := e || E'\nU3 : ' || v_n || ' syndicat(s) domicilie(s) au lieu de 3'; END IF;

  n := n + 1;   -- U4 : LA SALLE N'EST PLUS LOUABLE, MEME PAR UNE ECRITURE DIRECTE, ET DANS LES
                --      QUATRE EMPIRES -- le gabarit de piece est partage.
  BEGIN
    INSERT INTO public.locations_actives (id, country, data)
    VALUES ('republic:universite:salle_reunion:capitale', 'republic', '{"locataire":"Ben"}'::jsonb);
    ko := ko + 1; e := e || E'\nU4 : un bail a pu etre ecrit sur la salle de reunion';
  EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN
    INSERT INTO public.locations_actives (id, country, data)
    VALUES ('soviet:universite:salle_reunion:capitale', 'soviet', '{"locataire":"X"}'::jsonb);
    ko := ko + 1; e := e || E'\nU4 : la contrainte ne vaut que pour un empire';
  EXCEPTION WHEN check_violation THEN NULL; END;

  n := n + 1;   -- U5 : LE DUPLICATA N'EST PAS POUR UN TIERS.
  PERFORM pg_temp.je_suis(PREV_U);
  v := public.organisation_extrait_duplicata(o1);
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'reserve_au_president_ou_au_secretaire' THEN
    ko := ko + 1; e := e || E'\nU5 : un tiers obtient un duplicata -- ' || v::text; END IF;

  n := n + 1;   -- U6 : LE PRESIDENT L'OBTIENT, ET LES 75 FR VONT AU TRIBUNAL.
  SELECT arg, pa INTO v_arg, v_pa FROM public.personnages_donnees WHERE name = PLAI;
  SELECT (data->>'solde')::numeric INTO v_trib FROM public.caisses_batiments
   WHERE id = 'republic_tribunal_capitale';
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.organisation_extrait_duplicata(o1);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE OR (v ->> 'qualite') <> 'president'
     OR (v ->> 'original') IS NULL THEN
    ko := ko + 1; e := e || E'\nU6 : le duplicata du president est refuse -- ' || v::text; END IF;
  IF (SELECT arg FROM public.personnages_donnees WHERE name = PLAI) <> v_arg - 75
     OR (SELECT pa FROM public.personnages_donnees WHERE name = PLAI) <> v_pa - 1 THEN
    ko := ko + 1; e := e || E'\nU6 : les couts du duplicata ne sont pas preleves'; END IF;
  IF (SELECT (data->>'solde')::numeric FROM public.caisses_batiments
       WHERE id = 'republic_tribunal_capitale') <> v_trib + 75 THEN
    ko := ko + 1; e := e || E'\nU6 : le tribunal n''a pas encaisse les 75 FR'; END IF;

  n := n + 1;   -- U7 : LE SECRETAIRE AUSSI ; LE TRESORIER, JAMAIS.
  UPDATE public.organisations
     SET data = ((data::jsonb) || jsonb_build_object('secretaire', PREV))::text WHERE id = o1;
  UPDATE public.personnages_donnees SET pa = 40 WHERE name = PREV;
  PERFORM pg_temp.je_suis(PREV_U);
  v := public.organisation_extrait_duplicata(o1);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE OR (v ->> 'qualite') <> 'secretaire' THEN
    ko := ko + 1; e := e || E'\nU7 : le secretaire n''obtient pas de duplicata -- ' || v::text; END IF;
  UPDATE public.organisations
     SET data = ((data::jsonb) - 'secretaire' || jsonb_build_object('tresorier', PREV))::text
   WHERE id = o1;
  UPDATE public.personnages_donnees SET pa = 40 WHERE name = PREV;
  PERFORM pg_temp.je_suis(PREV_U);
  v := public.organisation_extrait_duplicata(o1);
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'reserve_au_president_ou_au_secretaire' THEN
    ko := ko + 1; e := e || E'\nU7 : le tresorier obtient un duplicata -- ' || v::text; END IF;

  n := n + 1;   -- U8 : PAS D'ORIGINAL, PAS DE DUPLICATA.
  INSERT INTO public.organisations (id, country_origine, data)
  VALUES ('orga_banc_sans_extrait', 'republic',
          jsonb_build_object('id','orga_banc_sans_extrait','type','syndicale','nom','Sans extrait',
                             'president', PLAI, 'country','republic',
                             'membres', jsonb_build_array(
                               jsonb_build_object('nom', PLAI, 'grade','Confederal','gradeIdx',3)))::text);
  UPDATE public.personnages_donnees SET pa = 40 WHERE name = PLAI;
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.organisation_extrait_duplicata('orga_banc_sans_extrait');
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'aucun_extrait_original' THEN
    ko := ko + 1; e := e || E'\nU8 : un duplicata sans original est delivre -- ' || v::text; END IF;

  n := n + 1;   -- U9 : PAS DE MILITANT SANS ADHESION, et le refus ne coute rien.
  DELETE FROM public.organisations WHERE id IN (o1, o2, o3, 'orga_banc_sans_extrait');
  UPDATE public.personnages_donnees SET pa = 40 WHERE name = PLAI;
  SELECT pa INTO v_pa FROM public.personnages_donnees WHERE name = PLAI;
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.militant_recruter('Sacha Fervent (PNJ)', NULL, 'capitale', 'universite', 'amphi', 'recruter_etud');
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'adhesion_syndicale_requise' THEN
    ko := ko + 1; e := e || E'\nU9 : un militant recrute sans syndicat -- ' || v::text; END IF;
  IF (SELECT pa FROM public.personnages_donnees WHERE name = PLAI) <> v_pa THEN
    ko := ko + 1; e := e || E'\nU9 : le refus d''adhesion a coute un PA'; END IF;

  n := n + 1;   -- U10 : LE PREMIER PASSE, LE SECOND DU MEME JOUR EST REFUSE.
  PERFORM pg_temp.en_salle(PLAI);
  UPDATE public.personnages_donnees SET pa = 40 WHERE name = PLAI;
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.syndicat_etudiant_domicilier('Syndicat de la Sorbonne');
  o1 := v ->> 'organisation';
  v := public.militant_recruter('Sacha Fervent (PNJ)', o1, 'capitale', 'universite', 'amphi', 'recruter_etud');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nU10 : le premier militant est refuse -- ' || v::text; END IF;
  UPDATE public.personnages_donnees SET pa = 40 WHERE name = PLAI;
  SELECT pa INTO v_pa FROM public.personnages_donnees WHERE name = PLAI;
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.militant_recruter('Lila Combattante (PNJ)', o1, 'capitale', 'universite', 'amphi', 'recruter_etud');
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'recrutement_du_jour_deja_fait' THEN
    ko := ko + 1; e := e || E'\nU10 : deux militants le meme jour -- ' || v::text; END IF;
  IF (SELECT pa FROM public.personnages_donnees WHERE name = PLAI) <> v_pa THEN
    ko := ko + 1; e := e || E'\nU10 : le refus quotidien a coute un PA'; END IF;

  n := n + 1;   -- U11 : LE LENDEMAIN LE SECOND PASSE, ET LE TROISIEME BUTE SUR LE PLAFOND.
  UPDATE public.rp_epoques SET jour_un = jour_un - 1 WHERE pays = 'republic';
  UPDATE public.personnages_donnees SET pa = 40 WHERE name = PLAI;
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.militant_recruter('Lila Combattante (PNJ)', o1, 'capitale', 'universite', 'amphi', 'recruter_etud');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nU11 : le second militant du lendemain est refuse -- ' || v::text; END IF;
  UPDATE public.rp_epoques SET jour_un = jour_un - 1 WHERE pays = 'republic';
  UPDATE public.personnages_donnees SET pa = 40 WHERE name = PLAI;
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.militant_recruter('Noe Insurge (PNJ)', o1, 'capitale', 'universite', 'amphi', 'recruter_etud');
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'plafond_militants' THEN
    ko := ko + 1; e := e || E'\nU11 : un troisieme militant passe -- ' || v::text; END IF;

  n := n + 1;   -- J1 : LE JUGE NE PREND PAS LA MAIN TANT QUE LE PARQUET N'A PAS TRANCHE.
  PERFORM pg_temp.je_suis_le_serveur();
  DELETE FROM public.plaintes_en_cours
   WHERE data LIKE '%' || PREV || '%' OR data LIKE '%' || PLAI || '%';
  UPDATE public.personnages_donnees SET current_city='capitale',
         current_building='commissariat', current_room='accueil_police', pa = 40 WHERE name = PLAI;
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.plainte_deposer(PREV, 'Detournement de fonds publics', 'delit');
  PERFORM pg_temp.je_suis_le_serveur();
  a := v ->> 'id';
  IF a IS NULL THEN RAISE EXCEPTION 'DECOR ROMPU -- le depot du parcours judiciaire est refuse : %', v::text; END IF;
  PERFORM pg_temp.siege(JUGE, 'juge', 'capitale');
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.juge_ouvrir_enquete_malgre_non_lieu(a, 'Les faits meritent une enquete');
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'statut_incompatible' THEN
    ko := ko + 1; e := e || E'\nJ1 : le juge prend la main au parquet -- ' || v::text; END IF;

  n := n + 1;   -- J2 : LE PARQUET PRONONCE LE NON-LIEU.
  UPDATE public.personnages_donnees SET current_city='capitale',
         current_building='tribunal', current_room='greffe' WHERE name = PROC;
  PERFORM pg_temp.je_suis(PROC_U);
  v := public.parquet_non_lieu(a, 'Aucun element');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nJ2 : non-lieu refuse -- ' || v::text; END IF;

  n := n + 1;   -- J3 : NI UN JOUEUR ORDINAIRE, NI UN JUGE D'UNE AUTRE VILLE NE ROUVRENT.
  PERFORM pg_temp.je_suis(PLAI_U);
  v := public.juge_ouvrir_enquete_malgre_non_lieu(a, 'Je veux que ca continue');
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'pas_juge_de_cette_ville' THEN
    ko := ko + 1; e := e || E'\nJ3 : un plaignant rouvre l''enquete -- ' || v::text; END IF;
  PERFORM pg_temp.siege(JUGE, 'juge', 'ville_b');
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.juge_ouvrir_enquete_malgre_non_lieu(a, 'Depuis Montrouge');
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'pas_juge_de_cette_ville' THEN
    ko := ko + 1; e := e || E'\nJ3 : le juge de Montrouge rouvre a Luthecia -- ' || v::text; END IF;

  n := n + 1;   -- J4 : LE JUGE DE LA VILLE ROUVRE, ET LE DOSSIER REPASSE EN ENQUETE.
  PERFORM pg_temp.siege(JUGE, 'juge', 'capitale');
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.juge_ouvrir_enquete_malgre_non_lieu(a, 'Les faits meritent une enquete');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT (p.data::jsonb) ->> 'status' INTO v_s FROM public.plaintes_en_cours p WHERE p.id = a;
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE OR v_s IS DISTINCT FROM 'enquete' THEN
    ko := ko + 1; e := e || E'\nJ4 : la reouverture a echoue -- ' || coalesce(v_s,'(nul)') || ' ' || v::text; END IF;

  n := n + 1;   -- J5 : LES DEUX DECISIONS COEXISTENT -- chronologie ET dossier.
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes
   WHERE affaire = a AND type IN ('non_lieu', 'juge_enquete_ouverte');
  IF v_n <> 2 THEN ko := ko + 1; e := e || E'\nJ5 : ' || v_n || ' acte(s) au lieu de 2'; END IF;
  SELECT (p.data::jsonb) ->> 'non_lieu_par' INTO v_s FROM public.plaintes_en_cours p WHERE p.id = a;
  IF v_s IS DISTINCT FROM PROC THEN
    ko := ko + 1; e := e || E'\nJ5 : le non-lieu du parquet a ete efface'; END IF;
  SELECT (p.data::jsonb) ->> 'juge_enquete_ouverte_par' INTO v_s FROM public.plaintes_en_cours p WHERE p.id = a;
  IF v_s IS DISTINCT FROM JUGE THEN
    ko := ko + 1; e := e || E'\nJ5 : la decision du juge n''est pas sur le dossier'; END IF;

  n := n + 1;   -- J6 : ET LE JOURNAL L'APPREND, par le declencheur.
  SELECT count(*) INTO v_n FROM public.chronique_nationale
   WHERE type = 'justice_enquete_ouverte_par_le_juge' AND libelle LIKE '%' || PREV || '%';
  IF v_n < 1 THEN ko := ko + 1; e := e || E'\nJ6 : la reouverture n''entre pas au journal'; END IF;

  n := n + 1;   -- J7 : LA CHAINE VA JUSQU'AU JUGEMENT SANS LA MOINDRE TRACE OBJECTIVE.
  SELECT count(*) INTO v_n FROM public.actions_tracables WHERE auteur = PREV;
  IF v_n <> 0 THEN
    ko := ko + 1; e := e || E'\nJ7 : le decor porte ' || v_n || ' trace(s) objective(s)'; END IF;
  PERFORM pg_temp.je_suis(PROC_U);
  v := public.parquet_poursuivre(a, 'detournement_fonds_publics');
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    v := public.parquet_poursuivre(a, 'corruption_fonctionnaire');
  END IF;
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nJ7 : les poursuites apres reouverture sont refusees -- ' || v::text; END IF;
  v := public.parquet_transmettre_juge(a);
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT (p.data::jsonb) ->> 'status' INTO v_s FROM public.plaintes_en_cours p WHERE p.id = a;
  IF v_s IS DISTINCT FROM 'saisie' THEN
    ko := ko + 1; e := e || E'\nJ7 : la saisine apres reouverture a echoue -- ' || coalesce(v_s,'(nul)'); END IF;
  v_n := coalesce(public.jour_de_jeu_pays('republic'), 1);
  PERFORM pg_temp.je_suis(PREV_U);
  PERFORM public.justice_audience_consentir(a, v_n);
  PERFORM pg_temp.je_suis_le_serveur();
  PERFORM pg_temp.siege(JUGE, 'juge', 'capitale');
  UPDATE public.personnages_donnees SET current_city='capitale',
         current_building='tribunal', current_room='salle_audience' WHERE name = JUGE;
  PERFORM pg_temp.je_suis(JUGE_U);
  PERFORM public.justice_audience_fixer(a, v_n);
  v := public.justice_audience_ouvrir(a);
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nJ7 : l''audience ne s''ouvre pas -- ' || v::text; END IF;
  v := public.justice_relaxer(a);
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT (p.data::jsonb) ->> 'status' INTO v_s FROM public.plaintes_en_cours p WHERE p.id = a;
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE OR v_s IS DISTINCT FROM 'relaxe' THEN
    ko := ko + 1; e := e || E'\nJ7 : le jugement apres reouverture a echoue -- '
                         || coalesce(v_s,'(nul)') || ' ' || v::text; END IF;

  n := n + 1;   -- J8 : ET LE POUVOIR NE RESSUSCITE PAS UNE AFFAIRE JUGEE.
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.juge_ouvrir_enquete_malgre_non_lieu(a, 'Je recommence');
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v ->> 'raison') IS DISTINCT FROM 'statut_incompatible' THEN
    ko := ko + 1; e := e || E'\nJ8 : une affaire jugee est rouverte -- ' || v::text; END IF;

  IF ko > 0 THEN RAISE EXCEPTION 'banc greffe : % EPREUVE(S) ROUGE(S) sur % --%', ko, n, e; END IF;
  RAISE EXCEPTION 'banc greffe : LES % EPREUVES SONT VERTES.', n;
END $banc$;
ROLLBACK;
