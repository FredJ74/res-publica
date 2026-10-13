-- BANC DU SOCLE D'ADMINISTRATION ET DE L'INCARNATION (12 octobre 2026) -- 29 epreuves
--
-- CE BANC NE COMMITE RIEN. Il cree un administrateur de banc, joue la chaine judiciaire entiere
-- par incarnation de Saad puis d'Honore, nomme des PJ sur les deux postes pour verifier que
-- l'incarnation se ferme, et se termine par un RAISE EXCEPTION INCONDITIONNEL qui annule tout.
--
-- CE QU'IL A TROUVE QUE LES PREUVES NE POUVAIENT PAS TROUVER, et c'est pour cela qu'il existe :
--   1. `justice_relaxer` rendait `ok: true`, creait la ligne de jugement, consignait l'acte au nom
--      d'Honore -- et le dossier restait `saisie`. Le declencheur `plaintes_epingler_verdict`
--      restaurait le statut : il ne reconnait que `affaire_autorite_de`, qui lit la FICHE du
--      compte authentifie, et un administrateur n'a pas de fiche. Corrige en faisant passer cette
--      definition par `juge_moi()`. Quatrieme occurrence de « decide au serveur n'est pas applique
--      au serveur », troisieme sur ce declencheur.
--   2. `parquet_garde` appelait `acteur_present_sur_site` a QUATRE arguments pour une fonction qui
--      en exige CINQ : le controle de presence levait 42883 et TOUTES les actions du parquet
--      etaient cassees en production. T20 le mesure sur un vrai Procureur PJ.
--
-- Usage : coller ce fichier dans un execute_sql. Il doit finir sur
--   ERROR: banc administration : LES 29 EPREUVES SONT VERTES. -- rien ne doit rester
--
-- DEUX PIEGES DE DECOR, pour qui le rejoue :
--   . un poste doit etre INSCRIT dans `postes_attribues` AVANT d'etre pose sur une fiche, sinon
--     `trg_personnages_attester_poste` refuse l'ecriture -- c'est la garde qu'on veut laisser en
--     place, pas contourner ;
--   . le Procureur PJ de T20 doit etre PHYSIQUEMENT dans le tribunal de la capitale, sinon son
--     refus viendrait de la presence et non de l'arite qu'on veut mesurer ;
--   . T27 et T28 ecrivent dans `auth.users`. C'est volontaire et sans danger : la transaction est
--     annulee, et il n'y a aucune autre facon d'eprouver qu'un compte REEL, CONFIRME et NON INVITE
--     se fait refuser -- tous les comptes joueurs etant anonymes, ils se font refuser plus tot.

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
GRANT EXECUTE ON FUNCTION pg_temp.je_suis(text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION pg_temp.je_suis_le_serveur() TO PUBLIC;

DO $banc$
DECLARE
  ADMIN_U text := 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
  INCONNU text := '99999999-8888-7777-6666-555555555555';
  PIRATE_U text := '11111111-2222-3333-4444-555555555555';
  INVITE_U text := '22222222-3333-4444-5555-666666666666';
  MARS_U text := 'a5a55fc8-64fa-4406-b617-76439d1d4aac'; MARS text := 'Marsault';
  LEE_U  text := 'ea4a2a0c-a192-4e10-8cff-d5db9b1cceb6'; LEE  text := 'Lee Capene';
  BEN    text := 'Ben';
  v jsonb; n integer := 0; ko integer := 0; e text := '';
  v_n integer; v_s text; v_leve boolean;
BEGIN
  PERFORM pg_temp.je_suis_le_serveur();

  -- DECOR. Les deux postes sont vacants cote PJ : Saad et Honore sont donc titulaires.
  DELETE FROM public.postes_attribues WHERE poste_id IN ('procureur', 'juge');
  UPDATE public.personnages_donnees SET poste = NULL WHERE name IN (MARS, LEE);
  UPDATE public.personnages_donnees SET est_emprisonne = NULL WHERE name = BEN;
  DELETE FROM public.detentions WHERE nom = BEN;
  INSERT INTO public.administrateurs (user_id, libelle) VALUES (ADMIN_U::uuid, 'Banc');

  -- L'AUDIENCE EST OUVERTE DANS LE DECOR (verrou du 13 octobre 2026). Depuis ce verrou, aucune
  -- condamnation ni relaxe de procedure COMPLETE ne se rend avant que le proces ait eu lieu. Ce
  -- banc-ci n'eprouve pas la chaine de l'audience -- `banc-parcours-judiciaires` le fait, des
  -- deux cotes -- mais il ne peut plus l'ignorer : la cle `audience_ouverte_le` est donc posee au
  -- decor, exactement comme le statut l'est. C'est la PRESENCE de cette cle que
  -- `affaire_audience_ouverte` lit.
  INSERT INTO public.plaintes_en_cours (id, country, city, data) VALUES
    ('banc-adm-1', 'republic', 'capitale', jsonb_build_object('status', 'au_parquet',
      'cible', BEN, 'plaignant', MARS, 'motif', 'Vol', 'infraction_constatee', 'vol',
      'country', 'republic', 'city', 'capitale',
      'audience_ouverte_le', '2026-10-13T10:00:00Z')::text),
    ('banc-adm-2', 'republic', 'ville_b', jsonb_build_object('status', 'au_parquet',
      'cible', BEN, 'plaignant', MARS, 'motif', 'Vol', 'infraction_constatee', 'vol',
      'country', 'republic', 'city', 'ville_b',
      'audience_ouverte_le', '2026-10-13T10:00:00Z')::text),
    ('banc-adm-3', 'republic', 'capitale', jsonb_build_object('status', 'au_parquet',
      'cible', BEN, 'plaignant', MARS, 'motif', 'Vol', 'infraction_constatee', 'vol',
      'country', 'republic', 'city', 'capitale',
      'audience_ouverte_le', '2026-10-13T10:00:00Z')::text);

  -- ------------------------------------- T1 : UN JOUEUR ORDINAIRE N'EST PAS ADMINISTRATEUR
  n := n + 1;
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.admin_moi();
  IF coalesce((v ->> 'administrateur')::boolean, true) IS NOT FALSE THEN
    ko := ko + 1; e := e || E'\nT1 : un joueur ordinaire se voit administrateur'; END IF;

  -- ------------------------- T2 : LA DONNEE D'ADMINISTRATION LUI EST REFUSEE AU SERVEUR
  n := n + 1;
  v_leve := false;
  BEGIN PERFORM public.admin_tribunal_dossiers();
  EXCEPTION WHEN insufficient_privilege THEN v_leve := true;
           WHEN OTHERS THEN v_leve := true; END;
  IF NOT v_leve THEN
    ko := ko + 1; e := e || E'\nT2 : un joueur lit les dossiers de l''administration'; END IF;

  -- ------------------- T3 : L'ACTION LUI EST REFUSEE, MEME EN APPELANT DIRECTEMENT LA PORTE
  n := n + 1;
  v_leve := false;
  BEGIN PERFORM public.admin_incarner('procureur', 'enqueter', 'banc-adm-1', '{}'::jsonb);
  EXCEPTION WHEN OTHERS THEN v_leve := true; END;
  IF NOT v_leve THEN
    ko := ko + 1; e := e || E'\nT3 : un joueur incarne le Procureur en appelant la porte'; END IF;

  -- ----------------- T4 : CONNAITRE LE PANNEAU NE SUFFIT PAS. Un compte inconnu n'est rien.
  -- Et `est_administrateur()` n'est MEME PAS appelable par un client : elle n'a aucun droit
  -- client, ce qui est la bonne reponse -- le panneau passe par `admin_moi()`.
  n := n + 1;
  PERFORM pg_temp.je_suis(INCONNU);
  v_leve := false;
  BEGIN IF public.est_administrateur() THEN NULL; END IF;
  EXCEPTION WHEN OTHERS THEN v_leve := true; END;
  IF NOT v_leve THEN
    ko := ko + 1; e := e || E'\nT4 : la definition de l''autorite est appelable par un client'; END IF;
  v := public.admin_moi();
  IF coalesce((v ->> 'administrateur')::boolean, true) IS NOT FALSE THEN
    ko := ko + 1; e := e || E'\nT4 : un compte inconnu porte l''autorite administrateur'; END IF;

  -- ------------------------------------------------ T5 : LE COMPTE ADMINISTRATEUR, LUI, PASSE
  n := n + 1;
  PERFORM pg_temp.je_suis(ADMIN_U);
  v := public.admin_moi();
  IF coalesce((v ->> 'administrateur')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nT5 : le compte administrateur n''est pas reconnu'; END IF;

  -- ------------------- T6 : L'ADMINISTRATION NE DEPEND D'AUCUN PERSONNAGE, NI D'AUCUN POSTE
  n := n + 1;
  IF public.mon_personnage() IS NOT NULL THEN
    ko := ko + 1; e := e || E'\nT6 : le compte administrateur porte un personnage'; END IF;

  -- ------------------------------------- T7 : LE PANNEAU NOMME LES DEUX PNJ, ET ILS SONT LA
  n := n + 1;
  v := public.admin_tribunal_dossiers();
  IF (v -> 'parquet' ->> 'pnj') IS DISTINCT FROM 'Procureur Saad'
     OR coalesce((v -> 'parquet' ->> 'incarnable')::boolean, false) IS NOT TRUE
     OR (v -> 'juge' ->> 'pnj') IS DISTINCT FROM 'Honoré Cozetoujours (PNJ)'
     OR coalesce((v -> 'juge' ->> 'incarnable')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nT7 : le panneau ne nomme pas les deux titulaires -- '
      || coalesce(v -> 'parquet' ->> 'pnj', '-') || ' / ' || coalesce(v -> 'juge' ->> 'pnj', '-'); END IF;

  -- -------------------------------- T8 : L'INDICATEUR COMPTE LES DOSSIERS QUI ATTENDENT
  n := n + 1;
  IF coalesce((v ->> 'en_attente')::integer, -1) < 1 THEN
    ko := ko + 1; e := e || E'\nT8 : l''indicateur d''attente vaut ' || coalesce(v ->> 'en_attente', '-'); END IF;

  -- -------------------------------------------- T9 : SAAD INCARNE DILIGENTE UNE ENQUETE
  n := n + 1;
  v := public.admin_incarner('procureur', 'enqueter', 'banc-adm-1', '{}'::jsonb);
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT p.data::jsonb ->> 'status' INTO v_s FROM public.plaintes_en_cours p WHERE p.id = 'banc-adm-1';
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE OR v_s IS DISTINCT FROM 'enquete' THEN
    ko := ko + 1; e := e || E'\nT9 : l''enquete n''a pas pris -- ' || v::text || ' statut=' || coalesce(v_s, '-'); END IF;

  -- ----------------------- T10 : L'ACTE EST SIGNE SAAD, AU POSTE DE PROCUREUR. Rien d'autre.
  n := n + 1;
  SELECT a.acteur || '/' || coalesce(a.acteur_poste, '-') INTO v_s
    FROM public.dossiers_judiciaires_actes a WHERE a.affaire = 'banc-adm-1' ORDER BY a.rang DESC LIMIT 1;
  IF v_s IS DISTINCT FROM 'Procureur Saad/procureur' THEN
    ko := ko + 1; e := e || E'\nT10 : l''acte est signe ' || coalesce(v_s, '-'); END IF;

  -- ------------- T11 : AUCUNE PROVENANCE ADMINISTRATIVE DANS LA DONNEE VUE PAR LES JOUEURS
  n := n + 1;
  SELECT count(*) INTO v_n FROM public.plaintes_en_cours p
   WHERE p.id = 'banc-adm-1' AND (p.data ILIKE '%admin%' OR p.data ILIKE '%incarn%');
  IF v_n <> 0 THEN ko := ko + 1; e := e || E'\nT11 : le dossier public porte une trace administrative'; END IF;
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes a
   WHERE a.affaire = 'banc-adm-1'
     AND (a.acteur ILIKE '%admin%' OR coalesce(a.donnees::text, '') ILIKE '%admin%'
          OR coalesce(a.donnees::text, '') ILIKE '%incarn%');
  IF v_n <> 0 THEN ko := ko + 1; e := e || E'\nT11 : la chronologie publique porte une provenance'; END IF;

  -- ------------------------------------- T12 : L'AUDIT PRIVE, LUI, SAIT TOUT -- et lui seul
  n := n + 1;
  SELECT count(*) INTO v_n FROM public.admin_journal j
   WHERE j.affaire = 'banc-adm-1' AND j.action = 'enqueter'
     AND j.pnj = 'Procureur Saad' AND j.admin_user_id = ADMIN_U::uuid AND j.ok;
  IF v_n <> 1 THEN ko := ko + 1; e := e || E'\nT12 : l''audit prive n''a pas consigne l''acte (' || v_n || ')'; END IF;

  -- ---------------------------- T13 : LA CHAINE ENTIERE, PAR LES PORTES DU TITULAIRE
  n := n + 1;
  PERFORM pg_temp.je_suis(ADMIN_U);
  v := public.admin_incarner('procureur', 'poursuivre', 'banc-adm-1', '{"infraction":"vol"}'::jsonb);
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nT13 : poursuivre -- ' || v::text; END IF;
  v := public.admin_incarner('procureur', 'transmettre_juge', 'banc-adm-1', '{}'::jsonb);
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nT13 : saisir le juge -- ' || v::text; END IF;
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT p.data::jsonb ->> 'status' INTO v_s FROM public.plaintes_en_cours p WHERE p.id = 'banc-adm-1';
  IF v_s IS DISTINCT FROM 'saisie' THEN
    ko := ko + 1; e := e || E'\nT13 : statut apres saisine = ' || coalesce(v_s, '-'); END IF;

  -- ------------- T14 : HONORE INCARNE REND LA SENTENCE, ET LE STATUT TIENT REELLEMENT
  n := n + 1;
  PERFORM pg_temp.je_suis(ADMIN_U);
  v := public.admin_incarner('juge', 'rendre_sentence', 'banc-adm-1',
        '{"infraction":"vol","genre":"prison","jours":1,"amende":0}'::jsonb);
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT p.data::jsonb ->> 'status' INTO v_s FROM public.plaintes_en_cours p WHERE p.id = 'banc-adm-1';
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE OR v_s IS DISTINCT FROM 'jugee' THEN
    ko := ko + 1; e := e || E'\nT14 : la sentence n''a pas pris -- ' || v::text
                           || ' statut=' || coalesce(v_s, '-'); END IF;
  SELECT j.juge INTO v_s FROM public.jugements j WHERE j.id = 'jug-banc-adm-1';
  IF v_s IS DISTINCT FROM 'Honoré Cozetoujours (PNJ)' THEN
    ko := ko + 1; e := e || E'\nT14 : le jugement est signe ' || coalesce(v_s, '-'); END IF;

  -- ------------------------------------------- T15 : LA PEINE EST REELLEMENT EXECUTEE
  n := n + 1;
  SELECT count(*) INTO v_n FROM public.detentions d
   WHERE d.nom = BEN AND d.autorite = 'Honoré Cozetoujours (PNJ)';
  IF v_n <> 1 THEN ko := ko + 1; e := e || E'\nT15 : la detention n''est pas ouverte (' || v_n || ')'; END IF;

  -- ------------------------------------------ T16 : LE PERIMETRE DES POSTES EST FERME
  n := n + 1;
  PERFORM pg_temp.je_suis(ADMIN_U);
  v := public.admin_incarner('maire', 'enqueter', 'banc-adm-3', '{}'::jsonb);
  IF (v ->> 'raison') IS DISTINCT FROM 'poste_hors_perimetre' THEN
    ko := ko + 1; e := e || E'\nT16 : un maire est incarnable -- ' || v::text; END IF;
  v := public.admin_incarner('president', 'enqueter', 'banc-adm-3', '{}'::jsonb);
  IF (v ->> 'raison') IS DISTINCT FROM 'poste_hors_perimetre' THEN
    ko := ko + 1; e := e || E'\nT16 : le President est incarnable'; END IF;

  -- ------------------------------------------ T17 : IL N'Y A PAS DE SUPER-BOUTON
  n := n + 1;
  v := public.admin_incarner('procureur', 'forcer', 'banc-adm-3', '{}'::jsonb);
  IF (v ->> 'raison') IS DISTINCT FROM 'action_hors_perimetre' THEN
    ko := ko + 1; e := e || E'\nT17 : une action inconnue est acceptee -- ' || v::text; END IF;

  -- ------- T18 : AUCUN POUVOIR SUPPLEMENTAIRE. La garde de statut refuse l'administration.
  n := n + 1;
  v := public.admin_incarner('procureur', 'enqueter', 'banc-adm-1', '{}'::jsonb);
  IF (v ->> 'raison') IS DISTINCT FROM 'statut_incompatible' THEN
    ko := ko + 1; e := e || E'\nT18 : la garde de statut cede devant l''administration -- ' || v::text; END IF;
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT count(*) INTO v_n FROM public.admin_journal j
   WHERE j.affaire = 'banc-adm-1' AND j.action = 'enqueter' AND NOT j.ok;
  IF v_n <> 1 THEN ko := ko + 1; e := e || E'\nT18 : le refus n''est pas consigne a l''audit'; END IF;

  -- ------- T19 : SAAD SIEGE A LA CAPITALE, ET NULLE PART AILLEURS. La province lui echappe.
  n := n + 1;
  PERFORM pg_temp.je_suis(ADMIN_U);
  v := public.admin_incarner('procureur', 'enqueter', 'banc-adm-2', '{}'::jsonb);
  IF (v ->> 'raison') IS DISTINCT FROM 'presence_requise' THEN
    ko := ko + 1; e := e || E'\nT19 : Saad agit hors de son siege -- ' || v::text; END IF;

  -- ------- T20 : CONCURRENCE. UN PJ PREND LE PARQUET : L'INCARNATION SE FERME IMMEDIATEMENT.
  n := n + 1;
  PERFORM pg_temp.je_suis_le_serveur();
  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, source)
  VALUES ('banc_adm_procureur', 'republic', 'procureur', NULL, MARS, 'banc');
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id', 'procureur'),
         country = 'republic', current_city = 'capitale',
         current_building = 'tribunal', current_room = 'salle_audience'
   WHERE name = MARS;
  PERFORM pg_temp.je_suis(ADMIN_U);
  v := public.admin_incarner('procureur', 'enqueter', 'banc-adm-3', '{}'::jsonb);
  IF (v ->> 'raison') IS DISTINCT FROM 'poste_tenu_par_un_pj' THEN
    ko := ko + 1; e := e || E'\nT20 : l''incarnation survit a la nomination d''un PJ -- ' || v::text; END IF;
  v := public.admin_tribunal_dossiers();
  IF coalesce((v -> 'parquet' ->> 'incarnable')::boolean, true) IS NOT FALSE THEN
    ko := ko + 1; e := e || E'\nT20 : le panneau croit encore Saad titulaire'; END IF;

  -- ------- T21 : ET LE PROCUREUR PJ, LUI, AGIT. C'est la mesure du correctif d'arite.
  n := n + 1;
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.parquet_enqueter('banc-adm-3');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT p.data::jsonb ->> 'status' INTO v_s FROM public.plaintes_en_cours p WHERE p.id = 'banc-adm-3';
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE OR v_s IS DISTINCT FROM 'enquete' THEN
    ko := ko + 1; e := e || E'\nT21 : le Procureur PJ ne peut pas enqueter -- ' || v::text
                           || ' statut=' || coalesce(v_s, '-'); END IF;

  -- ------- T22 : UN PJ PREND LE TRIBUNAL : HONORE N'EST PLUS INCARNABLE NON PLUS.
  n := n + 1;
  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, source)
  VALUES ('banc_adm_juge', 'republic', 'juge', 'capitale', LEE, 'banc');
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id', 'juge', 'city', 'capitale'), country = 'republic'
   WHERE name = LEE;
  PERFORM pg_temp.je_suis(ADMIN_U);
  v := public.admin_incarner('juge', 'relaxer', 'banc-adm-3', '{"infraction":"vol"}'::jsonb);
  IF (v ->> 'raison') IS DISTINCT FROM 'poste_tenu_par_un_pj' THEN
    ko := ko + 1; e := e || E'\nT22 : Honore reste incarnable sous un juge PJ -- ' || v::text; END IF;
  v := public.admin_tribunal_dossiers();
  IF coalesce((v -> 'juge' ->> 'incarnable')::boolean, true) IS NOT FALSE THEN
    ko := ko + 1; e := e || E'\nT22 : le panneau croit encore Honore titulaire'; END IF;

  -- ------------------------------------- T23 : L'AUDIT PRIVE NE SE REECRIT PAS
  n := n + 1;
  PERFORM pg_temp.je_suis_le_serveur();
  v_leve := false;
  BEGIN UPDATE public.admin_journal SET pnj = 'Quelqu''un d''autre' WHERE rang > 0;
  EXCEPTION WHEN OTHERS THEN v_leve := true; END;
  IF NOT v_leve THEN ko := ko + 1; e := e || E'\nT23 : l''audit prive se reecrit'; END IF;

  -- ------------------------------------- T24 : L'AUDIT PRIVE NE S'EFFACE PAS
  n := n + 1;
  v_leve := false;
  BEGIN DELETE FROM public.admin_journal WHERE rang > 0;
  EXCEPTION WHEN OTHERS THEN v_leve := true; END;
  IF NOT v_leve THEN ko := ko + 1; e := e || E'\nT24 : l''audit prive s''efface'; END IF;

  -- --------- T25 A T29 : LA DECLARATION DU PREMIER COMPTE NE S'AUTO-PROMEUT JAMAIS
  --
  -- CES CINQ EPREUVES ONT ETE RECALIBREES LE 12 OCTOBRE 2026 AU SOIR, et elles mesurent desormais
  -- l'inverse de ce que mesurait l'ancienne T25. L'ancienne version eprouvait une fenetre : la
  -- declaration etait ouverte TANT QUE la table des administrateurs etait vide, et fermee des
  -- qu'une ligne y figurait. La securite dependait donc de la VITESSE de provisionnement -- entre
  -- le deploiement et la premiere declaration, n'importe quel compte confirme pouvait prendre la
  -- place. La condition « la table est vide » a ete RETIREE de `admin_se_declarer` : la seule
  -- porte est desormais une INVITATION NOMMEE, posee par migration, sur une adresse confirmee, et
  -- consommee par compare-and-swap. Il n'y a plus de fenetre a courir.
  n := n + 1;   -- T25 : UN COMPTE QUI N'EXISTE PAS N'EST PAS UN ADMINISTRATEUR EN DEVENIR.
  PERFORM pg_temp.je_suis(INCONNU);
  v := public.admin_se_declarer('Pirate');
  IF (v ->> 'raison') IS DISTINCT FROM 'compte_sans_identite_reelle' THEN
    ko := ko + 1; e := e || E'\nT25 : un compte inconnu se declare -- ' || v::text; END IF;

  n := n + 1;   -- T26 : UN COMPTE JOUEUR NE SE PROMEUT PAS, ET LE REFUS NE DOIT RIEN A LA
                --       PRESENCE D'UN ADMINISTRATEUR DEJA INSCRIT : la table est VIDEE d'abord.
                --       C'est tout le §A.2 -- la fenetre de revendication n'existe plus.
  PERFORM pg_temp.je_suis_le_serveur();
  DELETE FROM public.administrateurs;
  PERFORM pg_temp.je_suis(MARS_U);
  v := public.admin_se_declarer('Moi, le joueur');
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT FALSE
     OR (v ->> 'raison') IN ('administration_deja_constituee') THEN
    ko := ko + 1; e := e || E'\nT26 : un compte joueur se promeut, administration vide -- ' || v::text; END IF;

  n := n + 1;   -- T27 : UN COMPTE REEL ET CONFIRME, MAIS NON INVITE, EST REFUSE -- toujours
                --       l'administration vide. C'est le cas du passant qui a devine l'URL.
  PERFORM pg_temp.je_suis_le_serveur();
  INSERT INTO auth.users (id, email, email_confirmed_at, is_anonymous)
  VALUES (PIRATE_U::uuid, 'pirate-de-banc@example.invalid', now(), false);
  PERFORM pg_temp.je_suis(PIRATE_U);
  v := public.admin_se_declarer('Pirate confirme');
  IF (v ->> 'raison') IS DISTINCT FROM 'aucune_invitation' THEN
    ko := ko + 1; e := e || E'\nT27 : un compte confirme non invite se declare -- ' || v::text; END IF;

  n := n + 1;   -- T28 : L'INVITE, LUI, PASSE -- UNE FOIS. La seconde tentative trouve
                --       l'invitation consommee : deux onglets ne la prennent pas tous les deux.
  PERFORM pg_temp.je_suis_le_serveur();
  INSERT INTO auth.users (id, email, email_confirmed_at, is_anonymous)
  VALUES (INVITE_U::uuid, 'invite-de-banc@example.invalid', now(), false);
  INSERT INTO public.administrateurs_invitations (email, note)
  VALUES ('invite-de-banc@example.invalid', 'banc');
  PERFORM pg_temp.je_suis(INVITE_U);
  v := public.admin_se_declarer('Invite');
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN
    ko := ko + 1; e := e || E'\nT28 : l''invite ne peut pas se declarer -- ' || v::text; END IF;
  v := public.admin_se_declarer('Invite, deuxieme fois');
  IF (v ->> 'raison') NOT IN ('invitation_deja_consommee', 'administrateur_deja_inscrit') THEN
    ko := ko + 1; e := e || E'\nT28 : l''invitation se consomme deux fois -- ' || v::text; END IF;

  n := n + 1;   -- T29 : L'UNIQUE INVITATION DE PROVISIONNEMENT EST NOMMEE, POSEE PAR MIGRATION,
                --       ET LE REGISTRE EST FERME AUX CLIENTS. L'etape restante est bornee : une
                --       seule adresse, et personne ne peut s'en ajouter une.
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT count(*) INTO v_n FROM public.administrateurs_invitations
   WHERE consommee_le IS NULL AND email <> 'invite-de-banc@example.invalid';
  IF v_n <> 1 THEN
    ko := ko + 1; e := e || E'\nT29 : ' || v_n || ' invitation(s) de provisionnement en attente au lieu d''une'; END IF;
  v_leve := false;
  BEGIN
    PERFORM set_config('role', 'authenticated', true);
    PERFORM count(*) FROM public.administrateurs_invitations;
  EXCEPTION WHEN insufficient_privilege THEN v_leve := true; END;
  PERFORM pg_temp.je_suis_le_serveur();
  IF NOT v_leve THEN
    ko := ko + 1; e := e || E'\nT29 : un client lit le registre des invitations'; END IF;
  v_leve := false;
  BEGIN
    PERFORM pg_temp.je_suis(PIRATE_U);
    INSERT INTO public.administrateurs_invitations (email) VALUES ('pirate-de-banc@example.invalid');
  EXCEPTION WHEN insufficient_privilege THEN v_leve := true;
           WHEN OTHERS THEN v_leve := true; END;
  PERFORM pg_temp.je_suis_le_serveur();
  IF NOT v_leve THEN
    ko := ko + 1; e := e || E'\nT29 : un client s''invite lui-meme'; END IF;

  PERFORM pg_temp.je_suis_le_serveur();
  IF ko > 0 THEN RAISE EXCEPTION 'banc administration : % EPREUVE(S) ROUGE(S) sur % --%', ko, n, e; END IF;
  RAISE EXCEPTION 'banc administration : LES % EPREUVES SONT VERTES.', n;
END $banc$;
ROLLBACK;
