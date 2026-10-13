-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 13 OCTOBRE 2026
--
-- Registre Supabase : version 20261013131924 (UTC), nom
-- `universite_la_salle_de_reunion_domicilie_les_syndicats_etudiants`.
-- Le registre passe de 711 a 712 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 2caa5fd8bda877ef1e09f30d18a502e2, 32305 caracteres, 1
-- instruction au registre. Empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE REGISTRE STOCKE LE MEME CORPS SUIVI D'UN SAUT DE LIGNE FINAL : md5
-- 26a6e67947ecb8b6642460b2b058ec6c, 32306 caracteres. Le corps archive ici a ete RELU DEPUIS LE
-- REGISTRE par outils/baseline/extraire-corps-migration.py -- il n'a pas ete recopie a la main.
--
-- LA SALLE DE REUNION DE L'UNIVERSITE N'EST PLUS UN LOCAL A LOUER
--
-- ELLE DEVIENT le lieu de DOMICILIATION des syndicats etudiants -- plusieurs a la fois, sans
-- exclusivite. Le verrou est une CONTRAINTE CHECK sur `locations_actives`, pas le retrait d'un
-- bouton : la table accorde INSERT a `authenticated`, donc un bail aurait pu etre ecrit
-- directement. La contrainte vaut pour les quatre empires (le gabarit de piece est partage).
--
-- 150 FR DE FRAIS DE GREFFE ET 2 PA, dans la caisse du TRIBUNAL, aucun loyer, aucun bonus de
-- local, et un EXTRAIT DE DOMICILIATION delivre automatiquement dans l'inventaire du fondateur.
--
-- LE DUPLICATA (75 FR + 1 PA) est reserve au PRESIDENT ou au SECRETAIRE, et exige qu'un original
-- existe. L'ossature n'est pas un systeme : deux cles posees a la constitution, aucune
-- prerogative ailleurs (preuve P6). Le besoin d'une ossature GENERALE est signale au rapport.
--
-- LES TROIS REGLES DU MILITANT PASSENT AU SERVEUR : adhesion syndicale, un seul recrutement par
-- JOUR DE JEU, plafond de deux. La garde quotidienne etait restee cliente faute de source
-- serveur du jour de jeu ; `jour_de_jeu_pays` existe, la raison a disparu.
--
-- DEUX ETATS DE TEST SUPPRIMES, NOMMES UN PAR UN : le bail de Fred sur cette salle, et le
-- syndicat de test `orga_1791891241579`. L'autre bail de Fred est verifie intact (preuve P1c).
--
-- PREUVES STRUCTURELLES -- 9.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LA SALLE DE REUNION DE L'UNIVERSITE N'EST PLUS UN LOCAL A LOUER.
--
-- CE QU'ELLE ETAIT. Une piece `isLocationRoom` a 180 FR/jour, avec ses bonus de local
-- (+4 POP, +4 INF, +2 DIS), louable par UN SEUL locataire -- et c'est tout le probleme : une
-- salle de reunion universitaire louee a vie par un joueur n'est plus une salle de reunion. Fred
-- l'a louee le 13 octobre, y a domicilie un syndicat de test, et n'a trouve AUCUNE porte pour
-- resilier : « Gerer mon local » n'offre pas la resiliation.
--
-- CE QU'ELLE DEVIENT : le lieu de DOMICILIATION des syndicats etudiants -- PLUSIEURS a la fois,
-- sans privatisation ni exclusivite. N'importe quel PJ peut en fonder un ; il n'est pas necessaire
-- d'etre inscrit a l'universite. Deux familles d'ordres y vivent, et deux seulement : domicilier
-- ou gerer un syndicat etudiant, et recruter des militants.
--
-- LE VERROU EST STRUCTUREL, PAS COSMETIQUE. Retirer l'ordre « Louer cette salle » de data.js ne
-- ferme rien : `locations_actives` accorde INSERT a `authenticated`, donc un bail pourrait
-- toujours etre ecrit directement. Une CONTRAINTE CHECK sur la table refuse desormais toute
-- ligne dont la cle designe cette piece, dans les quatre empires -- la salle n'est plus louable
-- par AUCUNE voie, client comprise.
--
-- LES FRAIS DE GREFFE, ET PAS UN LOYER. Domicilier un syndicat etudiant coute 150 FR et 2 PA ;
-- les 150 FR sont des FRAIS DE GREFFE et entrent dans la caisse du TRIBUNAL. Aucun loyer, aucun
-- cout recurrent, aucun bonus de local. Et la constitution delivre AUTOMATIQUEMENT un extrait de
-- domiciliation dans l'inventaire du fondateur -- le document, pas une mention a l'ecran.
--
-- LES MILITANTS : LES REGLES DECLAREES DEVIENNENT DES REGLES. L'ordre `recruter_etud` annonce
-- depuis toujours « reserve aux membres d'un syndicat actif, 1/jour, plafond 2 par joueur ».
-- Le plafond de deux etait deja compte au serveur ; les DEUX AUTRES ne vivaient que dans le
-- navigateur. La garde quotidienne y etait restee pour une raison nommee dans le code -- « le jeu
-- n'a aucune source serveur du jour de jeu » -- qui n'est plus vraie depuis le chantier des deux
-- horloges : `jour_de_jeu_pays` existe. Les trois regles sont desormais au serveur, dans la meme
-- transaction que le paiement et que la creation du PNJ.
--
-- AUCUNE PREROGATIVE N'EST INVENTEE. Un syndicat etudiant est un syndicat : memes regles de
-- constitution et de direction, meme echelle de grades, aucun pouvoir propre. Rien sur les
-- manifestations, rien sur les elections, rien de plus que ce que le type `syndicale` donne deja.
--
-- L'OSSATURE PRESIDENT / SECRETAIRE / TRESORIER. Le modele des organisations n'en a AUCUNE : il
-- porte un `chef` et des `membres` avec des echelles de grades thematiques par empire. Pour le
-- droit au duplicata, qui est reserve au President ou au Secretaire, la FONDATION MINIMALE est
-- posee ici -- et rien de plus : les syndicats etudiants nes par cette porte portent une cle
-- `president` (le fondateur) et une cle `secretaire` (nulle au depart). Aucune prerogative
-- generale n'est attachee a ces deux roles, et les organisations creees par l'ancien chemin n'en
-- portent pas : elles n'ont pas d'extrait de domiciliation non plus, donc pas de duplicata a
-- demander. Le besoin d'une ossature GENERALE est signale au rapport, pas tranche ici.
--
-- CE QUI EST SUPPRIME, ET STRICTEMENT CELA : le bail de Fred sur cette salle, et le syndicat de
-- test qu'il y avait domicilie (`orga_1791891241579`). Les deux etats sont nommes un par un ;
-- aucune autre location, aucune autre organisation n'est touchee.

-- ---------------------------------------------------------------------------------------------
-- 1. LES DEUX ETATS DE TEST, NOMMES UN PAR UN
-- ---------------------------------------------------------------------------------------------
DELETE FROM public.locations_actives WHERE id = 'republic:universite:salle_reunion:capitale';
DELETE FROM public.organisations     WHERE id = 'orga_1791891241579';

-- ---------------------------------------------------------------------------------------------
-- 2. LA SALLE N'EST PLUS LOUABLE, ET C'EST UNE CONTRAINTE
-- ---------------------------------------------------------------------------------------------
ALTER TABLE public.locations_actives
  DROP CONSTRAINT IF EXISTS locations_actives_salle_reunion_non_louable;
ALTER TABLE public.locations_actives
  ADD CONSTRAINT locations_actives_salle_reunion_non_louable
  CHECK (id NOT LIKE '%:universite:salle_reunion:%');

-- ---------------------------------------------------------------------------------------------
-- 3. DOMICILIER UN SYNDICAT ETUDIANT -- 150 FR DE FRAIS DE GREFFE ET 2 PA
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.syndicat_etudiant_domicilier(p_nom text, p_desc text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  -- L'ECHELLE DES GRADES SYNDICAUX, RECOPIEE DE `ORGANISATIONS_DEF.syndicale.grades` (data.js).
  -- Le serveur ne peut pas importer data.js -- aucun module, aucun export -- et un syndicat
  -- etudiant doit avoir la MEME echelle que les autres syndicats. La copie est donc assumee et
  -- signalee au rapport comme une ressaisie a tenir en phase.
  c_grades constant jsonb := jsonb_build_object(
    'republic', jsonb_build_array('Adherent', 'Secretaire General Adjoint', 'Secretaire General', 'Confederal'),
    'narco',    jsonb_build_array('Afilado', 'Delegado', 'Secretario', 'Comandante Sindical'),
    'soviet',   jsonb_build_array('Camarade de base', 'Delegue', 'Secretaire de cellule', 'Premier Secretaire'),
    'khalija',  jsonb_build_array('Affilie', 'Delegue du Souk', 'Secretaire de la Guilde', 'Grand Intendant'));
  v_moi text; v_pays text; v_ville text; v_inv jsonb; v_nom text; v_desc text;
  v_jour integer; v_paye jsonb; v_doc jsonb; v_caisse text; v_id text;
  v_grades jsonb; v_grade text; v_blob jsonb; v_contenu jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  v_nom  := nullif(btrim(coalesce(p_nom, '')), '');
  v_desc := nullif(btrim(coalesce(p_desc, '')), '');
  IF v_nom IS NULL OR length(v_nom) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nom_requis');
  END IF;
  IF length(v_nom) > 80 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nom_trop_long', 'maximum', 80);
  END IF;

  SELECT country, current_city, coalesce(inventory, '[]'::jsonb)
    INTO v_pays, v_ville, v_inv
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  -- LA PRESENCE DANS LA SALLE DE REUNION, ET LA REGLE DE LOCALISATION UNIQUE DU JEU.
  IF NOT public.acteur_present_sur_site(v_moi, v_pays, v_ville, 'universite', 'salle_reunion') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_en_salle_de_reunion_requise',
                              'site', 'universite', 'piece', 'salle_reunion');
  END IF;
  IF public.inventaire_place_restante(v_inv) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein');
  END IF;

  -- AUCUNE EXCLUSIVITE : on ne verifie PAS qu'une organisation occupe deja ce local. C'est tout
  -- le changement de nature de la piece -- plusieurs syndicats y sont domicilies a la fois.
  v_caisse := v_pays || '_tribunal_' || coalesce(v_ville, 'capitale');
  IF NOT EXISTS (SELECT 1 FROM public.caisses_batiments WHERE id = v_caisse) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_du_tribunal_introuvable',
                              'caisse', v_caisse);
  END IF;

  v_paye := public.payer_ordre(v_moi, 'syndicat_etudiant_creer', 2, 150);
  IF coalesce((v_paye ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paye; END IF;

  -- LES 150 FR SONT DES FRAIS DE GREFFE : ils entrent dans la caisse du tribunal.
  PERFORM public.caisse_institution_mouvement(v_caisse, 150, true);

  v_jour   := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  v_grades := coalesce(c_grades -> v_pays, c_grades -> 'republic');
  v_grade  := v_grades ->> (jsonb_array_length(v_grades) - 1);
  v_id     := 'orga_syndet_' || replace(gen_random_uuid()::text, '-', '');

  v_blob := jsonb_build_object(
    'id', v_id, 'type', 'syndicale', 'nom', v_nom, 'desc', coalesce(v_desc, ''),
    'fondateur', v_moi, 'chef', v_moi,
    -- LA FONDATION MINIMALE DE L'OSSATURE, et rien de plus : deux cles, aucune prerogative.
    'president', v_moi, 'secretaire', NULL, 'tresorier', NULL,
    'country', v_pays, 'country_origine', v_pays,
    'creeLe', v_jour,
    'membres', jsonb_build_array(jsonb_build_object(
      'nom', v_moi, 'grade', v_grade, 'gradeIdx', jsonb_array_length(v_grades) - 1,
      'rejointLe', v_jour)),
    'demandesAdhesion', '[]'::jsonb,
    'bonusLocaux', jsonb_build_object('pop', 0, 'inf', 0, 'dis', 0),
    'caisse', 0, 'influence', 50,
    'localId', 'universite:salle_reunion',
    'visible', true,
    -- CE QUI DISTINGUE UN SYNDICAT ETUDIANT D'UN AUTRE SYNDICAT : sa domiciliation, et ce
    -- drapeau. Aucune prerogative n'y est attachee.
    'syndicat_etudiant', true,
    'domicilie_le_jour', v_jour,
    'frais_de_greffe', 150);

  INSERT INTO public.organisations (id, country_origine, data)
  VALUES (v_id, v_pays, v_blob::text);

  v_contenu := jsonb_build_object(
    'organisation', v_id, 'nom', v_nom, 'type', 'syndicale', 'syndicat_etudiant', true,
    'pays', v_pays, 'ville', v_ville,
    'domicile', 'universite:salle_reunion',
    'domicile_libelle', 'Salle de reunion de l''Universite',
    'president', v_moi, 'fondateur', v_moi,
    'constituee_le_jour', v_jour, 'frais_de_greffe', 150);

  v_doc := public.document_officiel_emettre(
    'domiciliation_extrait', 'domiciliation_extrait', true,
    v_pays, v_ville, NULL, v_id, NULL, v_moi, v_moi, v_jour,
    'Extrait de domiciliation — ' || v_nom,
    'Delivre par le greffe au jour ' || v_jour || ' a la constitution. Document FIGE : il dit la '
      || 'domiciliation telle qu''elle etait a cette date.',
    'ti-building-community', v_contenu,
    jsonb_build_object('motif', 'constitution'));
  IF coalesce((v_doc ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'syndicat_etudiant_domicilier : emission refusee (%)', v_doc ->> 'raison';
  END IF;

  RETURN jsonb_build_object('ok', true, 'organisation', v_id, 'nom', v_nom,
    'document', v_doc ->> 'document', 'jour', v_jour, 'ville', v_ville,
    'grade', v_grade, 'frais_de_greffe', 150);
END;
$function$;
REVOKE ALL ON FUNCTION public.syndicat_etudiant_domicilier(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.syndicat_etudiant_domicilier(text, text) TO authenticated, service_role;

-- ---------------------------------------------------------------------------------------------
-- 4. LE DUPLICATA DE L'EXTRAIT DE DOMICILIATION -- 75 FR ET 1 PA
-- ---------------------------------------------------------------------------------------------
-- DEUX CONDITIONS, ET ELLES SONT LIEES. On ne delivre un DUPLICATA que d'un original qui existe :
-- il faut donc qu'un extrait de domiciliation ait deja ete emis pour cette organisation, c'est-a-
-- dire que des frais de greffe se soient appliques a sa constitution. Et le demandeur doit etre
-- le PRESIDENT ou le SECRETAIRE -- pas le Tresorier, pas un membre ordinaire, pas le chef si
-- l'organisation ne nomme personne a ces deux roles.
CREATE OR REPLACE FUNCTION public.organisation_extrait_duplicata(p_organisation_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_ville text; v_inv jsonb; v_brut text; v_o jsonb;
        v_jour integer; v_paye jsonb; v_doc jsonb; v_caisse text; v_original text;
        v_contenu jsonb; v_role text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT country, current_city, coalesce(inventory, '[]'::jsonb)
    INTO v_pays, v_ville, v_inv
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  SELECT o.data INTO v_brut FROM public.organisations o WHERE o.id = p_organisation_id;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'organisation_introuvable');
  END IF;
  v_o := v_brut::jsonb;

  -- LE PRESIDENT OU LE SECRETAIRE, NOMMEMENT. Une organisation qui ne nomme ni l'un ni l'autre
  -- n'ouvre ce droit a personne -- c'est le choix assume de ne pas BRICOLER un repli sur le chef.
  v_role := CASE
    WHEN coalesce(v_o ->> 'president', '')  = v_moi THEN 'president'
    WHEN coalesce(v_o ->> 'secretaire', '') = v_moi THEN 'secretaire'
    ELSE NULL END;
  IF v_role IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_president_ou_au_secretaire');
  END IF;

  -- L'ORIGINAL DOIT EXISTER : pas d'extrait, pas de duplicata.
  SELECT d.id INTO v_original FROM public.documents_officiels d
   WHERE d.organisation = p_organisation_id AND d.genre = 'domiciliation_extrait'
     AND (d.donnees ->> 'motif') = 'constitution'
   ORDER BY d.emis_le LIMIT 1;
  IF v_original IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_extrait_original',
                              'organisation', p_organisation_id);
  END IF;

  IF public.inventaire_place_restante(v_inv) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein');
  END IF;

  v_caisse := v_pays || '_tribunal_' || coalesce(v_ville, 'capitale');
  IF NOT EXISTS (SELECT 1 FROM public.caisses_batiments WHERE id = v_caisse) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_du_tribunal_introuvable',
                              'caisse', v_caisse);
  END IF;

  v_paye := public.payer_ordre(v_moi, 'orga_extrait_duplicata', 1, 75);
  IF coalesce((v_paye ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paye; END IF;

  PERFORM public.caisse_institution_mouvement(v_caisse, 75, true);

  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);

  -- UN DUPLICATA DIT L'ETAT COURANT, A SA PROPRE DATE. Il n'est pas la photographie de
  -- l'original : c'est un extrait de plus, et il est fige a SA date comme l'original l'etait a
  -- la sienne. Sa provenance dit de quel original il est le duplicata.
  v_contenu := jsonb_build_object(
    'organisation', p_organisation_id, 'nom', v_o ->> 'nom', 'type', v_o ->> 'type',
    'syndicat_etudiant', coalesce((v_o ->> 'syndicat_etudiant')::boolean, false),
    'pays', coalesce(v_o ->> 'country', v_pays), 'ville', v_ville,
    'domicile', v_o ->> 'localId',
    'domicile_libelle', 'Salle de reunion de l''Universite',
    'president', v_o ->> 'president', 'fondateur', v_o ->> 'fondateur',
    'constituee_le_jour', v_o ->> 'creeLe', 'frais_de_greffe', 150,
    'duplicata', true, 'duplicata_de', v_original, 'duplicata_le_jour', v_jour);

  v_doc := public.document_officiel_emettre(
    'domiciliation_extrait', 'domiciliation_extrait', true,
    v_pays, v_ville, NULL, p_organisation_id, NULL, v_moi, v_moi, v_jour,
    'Extrait de domiciliation (duplicata) — ' || coalesce(v_o ->> 'nom', p_organisation_id),
    'Duplicata delivre par le greffe au jour ' || v_jour || '. Document FIGE : il dit la '
      || 'domiciliation telle qu''elle est a cette date.',
    'ti-building-community', v_contenu,
    jsonb_build_object('motif', 'duplicata', 'original', v_original, 'qualite', v_role));
  IF coalesce((v_doc ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'organisation_extrait_duplicata : emission refusee (%)', v_doc ->> 'raison';
  END IF;

  RETURN jsonb_build_object('ok', true, 'organisation', p_organisation_id,
    'document', v_doc ->> 'document', 'original', v_original, 'qualite', v_role,
    'jour', v_jour, 'frais_de_greffe', 75);
END;
$function$;
REVOKE ALL ON FUNCTION public.organisation_extrait_duplicata(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.organisation_extrait_duplicata(text) TO authenticated, service_role;

-- ---------------------------------------------------------------------------------------------
-- 5. LES TROIS REGLES DU RECRUTEMENT DE MILITANTS PASSENT AU SERVEUR
-- ---------------------------------------------------------------------------------------------
-- CE QUI CHANGE : deux gardes de plus, et elles etaient DEJA LA REGLE -- l'ordre les annonce
-- depuis toujours dans sa description. Elles ne vivaient que dans le navigateur.
--   * ADHESION : il faut etre membre d'un syndicat. C'est la garde que `doRecruterMilitants`
--     faisait sur `state.organisations`, mot pour mot : type `syndicale`, et son nom dans
--     `membres`. Aucune regle n'est resserree -- un membre de n'importe quel syndicat recrute,
--     comme avant, et pas seulement un syndicat etudiant.
--   * UN SEUL PAR JOUR DE JEU. Le code disait : « la garde reste cliente, le jeu n'a aucune
--     source serveur du jour de jeu ». `jour_de_jeu_pays` existe depuis le chantier des deux
--     horloges : la raison a disparu, la garde descend.
-- Le plafond de deux, lui, etait DEJA au serveur et n'est pas touche.
CREATE OR REPLACE FUNCTION public.militant_recruter(p_nom text, p_organisation_id text DEFAULT NULL::text, p_ville text DEFAULT NULL::text, p_batiment text DEFAULT NULL::text, p_piece text DEFAULT NULL::text, p_fn text DEFAULT NULL::text, p_pa integer DEFAULT NULL::integer, p_cost integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_plafond constant integer := 2;
  v_moi text; v_prof record; v_id text; v_nom text; v_pay jsonb; v_pays text;
  v_deja integer; v_pa integer; v_cost integer; v_jour integer; v_syndicat boolean;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_nom := btrim(COALESCE(p_nom, ''));
  IF v_nom = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'nom_absent'); END IF;

  SELECT * INTO v_prof FROM public.pnj_metiers_profils WHERE metier = 'militant';
  IF v_prof IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'profil_metier_absent'); END IF;

  SELECT COALESCE(country, 'republic') INTO v_pays
    FROM public.personnages_donnees WHERE name = v_moi;

  -- L'ADHESION, AU SERVEUR. Meme predicat que celui du navigateur : un syndicat de mon pays dont
  -- je suis membre.
  SELECT EXISTS (
    SELECT 1 FROM public.organisations o
     WHERE left(btrim(coalesce(o.data, '')), 1) = '{'
       AND (o.data::jsonb ->> 'type') = 'syndicale'
       AND coalesce(o.data::jsonb ->> 'country', o.country_origine) = v_pays
       AND EXISTS (SELECT 1 FROM jsonb_array_elements(
                     CASE WHEN jsonb_typeof(o.data::jsonb -> 'membres') = 'array'
                          THEN o.data::jsonb -> 'membres' ELSE '[]'::jsonb END) m
                    WHERE m ->> 'nom' = v_moi))
    INTO v_syndicat;
  IF NOT coalesce(v_syndicat, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'adhesion_syndicale_requise'); END IF;

  -- UN SEUL RECRUTEMENT PAR JOUR DE JEU, ET PAR JOUEUR. La trace est le registre historique,
  -- qui porte desormais le JOUR DE JEU -- l'ancienne cle `jour` y ecrivait un horodatage en
  -- millisecondes, qui ne permettait aucune comparaison de journee.
  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  IF EXISTS (SELECT 1 FROM public.militants_recrutes r
              WHERE r.recruteur = v_moi AND r.country = v_pays
                AND (r.data ->> 'jour_de_jeu')::integer = v_jour) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'recrutement_du_jour_deja_fait',
      'jour', v_jour); END IF;

  -- PLAFOND COMPTE AU SERVEUR, sur le socle qui fait autorite.
  SELECT count(*) INTO v_deja FROM public.pnj_membres m
   WHERE m.famille = 'militant' AND m.proprietaire_pj = v_moi AND m.statut = 'actif';
  IF v_deja >= c_plafond THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plafond_militants',
      'plafond', c_plafond, 'deja', v_deja); END IF;

  v_id := 'militant-' || substr(md5(lower(btrim(v_moi)) || '|' || lower(v_nom)), 1, 12);
  IF EXISTS (SELECT 1 FROM public.pnj_membres WHERE id = v_id AND statut = 'actif') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_recrute', 'pnj_id', v_id); END IF;

  v_pa   := COALESCE(p_pa,   v_prof.pa_initial,   0);
  v_cost := COALESCE(p_cost, v_prof.cout_initial, 0);
  IF p_fn IS NOT NULL AND (v_pa > 0 OR v_cost > 0) THEN
    v_pay := public.payer_ordre(v_moi, p_fn, v_pa, v_cost);
  ELSE
    v_pay := jsonb_build_object('ok', true, 'montant', 0);
  END IF;
  IF COALESCE((v_pay->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'paiement_refuse', 'paiement', v_pay); END IF;

  -- IL NE SUIT PERSONNE : un militant reste sur son lieu de militance, donc position PROPRE et
  -- aucun leader. C'est l'autre etat autorise par pnj_position_deux_etats.
  INSERT INTO public.pnj_membres (id, famille, classe, nom, pays, proprietaire_pj,
      ville, building_id, room_id, pa, statut, car_int, car_cha, car_vol, car_per, car_dup, car_ent)
  VALUES (v_id, 'militant', 'beta', v_nom, v_pays, v_moi,
      p_ville, p_batiment, p_piece, 12, 'actif',
      v_prof.car_int, v_prof.car_cha, v_prof.car_vol,
      v_prof.car_per, v_prof.car_dup, v_prof.car_ent)
  ON CONFLICT (id) DO UPDATE SET
      statut = 'actif', proprietaire_pj = EXCLUDED.proprietaire_pj,
      ville = EXCLUDED.ville, building_id = EXCLUDED.building_id, room_id = EXCLUDED.room_id,
      car_int = EXCLUDED.car_int, car_cha = EXCLUDED.car_cha, car_vol = EXCLUDED.car_vol,
      car_per = EXCLUDED.car_per, car_dup = EXCLUDED.car_dup, car_ent = EXCLUDED.car_ent,
      maj_le = now();

  INSERT INTO public.pnj_militants_metier (pnj_id, organisation_id, grade, rejoint_le)
  VALUES (v_id, p_organisation_id, 'Militant (PNJ)', now())
  ON CONFLICT (pnj_id) DO UPDATE SET
      organisation_id = EXCLUDED.organisation_id, grade = EXCLUDED.grade;

  -- Le registre historique est CONSERVE : sbGetMesMilitants le lit encore, et on ne retire pas une
  -- structure dont un lecteur vivant depend. Il porte desormais le JOUR DE JEU, qui est la trace
  -- sur laquelle la garde quotidienne s'appuie.
  INSERT INTO public.militants_recrutes (id, country, recruteur, data)
  VALUES (v_id, v_pays, v_moi, jsonb_build_object('nom', v_nom, 'pnj_id', v_id,
            'jour', (extract(epoch from now()) * 1000)::bigint,
            'jour_de_jeu', v_jour))
  ON CONFLICT (id) DO NOTHING;

  RETURN jsonb_build_object('ok', true, 'pnj_id', v_id, 'nom', v_nom, 'metier', 'militant',
    'caracteristiques', public.pnj_metier_profil('militant'),
    'paiement', v_pay, 'militants', v_deja + 1, 'plafond', c_plafond, 'jour', v_jour);
END; $function$;

-- ---------------------------------------------------------------------------------------------
-- 6. LES DEUX ORDRES AU MIROIR DES COUTS
-- ---------------------------------------------------------------------------------------------
INSERT INTO public.ordres_couts (fn, pa, cost) VALUES
  ('syndicat_etudiant_creer', 2, 150),
  ('orga_extrait_duplicata', 1, 75)
ON CONFLICT (fn, pa, cost) DO NOTHING;

-- =============================================================================================
-- PREUVES STRUCTURELLES
-- =============================================================================================
DO $$
DECLARE v_n integer; v_src text;
BEGIN
  -- P1. LES DEUX ETATS DE TEST SONT PARTIS, ET EUX SEULS.
  SELECT count(*) INTO v_n FROM public.locations_actives
   WHERE id = 'republic:universite:salle_reunion:capitale';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P1 ECHOUEE : le bail de la salle de reunion subsiste'; END IF;
  SELECT count(*) INTO v_n FROM public.organisations WHERE id = 'orga_1791891241579';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P1b ECHOUEE : le syndicat de test subsiste'; END IF;
  -- L'AUTRE BAIL DE FRED EST INTACT : la boutique du centre commercial.
  SELECT count(*) INTO v_n FROM public.locations_actives
   WHERE id = 'republic:centre-commercial:boutique_milieu:capitale';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'P1c ECHOUEE : une autre location a ete touchee (% trouvee)', v_n;
  END IF;

  -- P2. LA SALLE N'EST PLUS LOUABLE PAR AUCUNE VOIE, et c'est une contrainte.
  SELECT count(*) INTO v_n FROM pg_constraint
   WHERE conname = 'locations_actives_salle_reunion_non_louable';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P2 ECHOUEE : la contrainte de non-location n est pas posee'; END IF;
  -- Et elle vaut pour les QUATRE empires : la piece est un gabarit partage.
  SELECT pg_get_constraintdef(oid) INTO v_src FROM pg_constraint
   WHERE conname = 'locations_actives_salle_reunion_non_louable';
  IF v_src NOT LIKE '%universite:salle\_reunion%' THEN
    RAISE EXCEPTION 'P2b ECHOUEE : la contrainte ne vise pas la piece -- %', v_src;
  END IF;
  IF v_src LIKE '%republic%' THEN
    RAISE EXCEPTION 'P2c ECHOUEE : la contrainte ne vaut que pour un empire -- %', v_src;
  END IF;

  -- P3. LA DOMICILIATION N'EST PAS EXCLUSIVE : la porte ne LIT jamais la table des organisations
  -- pour savoir si le local est occupe. C'est l'inverse exact du chemin client, qui refuse sur
  -- `localId`.
  SELECT public.sans_commentaires(p.prosrc) INTO v_src FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'syndicat_etudiant_domicilier';
  IF v_src ~ 'SELECT 1 FROM public.organisations' OR v_src ~ 'local_deja_occupe' THEN
    RAISE EXCEPTION 'P3 ECHOUEE : la domiciliation verifie une exclusivite';
  END IF;
  -- ELLE EXIGE LA PRESENCE, PAIE LE GREFFE, ET DELIVRE L'EXTRAIT.
  IF v_src !~ 'acteur_present_sur_site' OR v_src !~ 'presence_en_salle_de_reunion_requise'
     OR v_src !~ 'payer_ordre\(v_moi, ''syndicat_etudiant_creer'', 2, 150\)'
     OR v_src !~ 'caisse_institution_mouvement\(v_caisse, 150, true\)'
     OR v_src !~ 'document_officiel_emettre' THEN
    RAISE EXCEPTION 'P3b ECHOUEE : la domiciliation ne tient pas ses cinq engagements';
  END IF;
  -- AUCUN LOYER, AUCUN BONUS DE LOCAL : les mots n'y sont pas.
  IF v_src ~ '(loyer|bonusPOP|bonusINF|bonusDIS|isLocationRoom)' THEN
    RAISE EXCEPTION 'P3c ECHOUEE : la domiciliation porte un loyer ou un bonus de local';
  END IF;

  -- P4. LE DUPLICATA EST RESERVE AU PRESIDENT OU AU SECRETAIRE, et exige un original.
  SELECT public.sans_commentaires(p.prosrc) INTO v_src FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'organisation_extrait_duplicata';
  IF v_src !~ 'reserve_au_president_ou_au_secretaire' OR v_src !~ 'aucun_extrait_original'
     OR v_src !~ 'payer_ordre\(v_moi, ''orga_extrait_duplicata'', 1, 75\)'
     OR v_src !~ 'caisse_institution_mouvement\(v_caisse, 75, true\)' THEN
    RAISE EXCEPTION 'P4 ECHOUEE : le duplicata ne tient pas ses quatre regles';
  END IF;
  -- ET NI LE TRESORIER NI LE CHEF N'Y ONT DROIT : aucun repli n'est code.
  IF v_src ~ '''tresorier''' OR v_src ~ '->>\s*''chef''' THEN
    RAISE EXCEPTION 'P4b ECHOUEE : le duplicata ouvre le droit au tresorier ou au chef';
  END IF;

  -- P5. LES TROIS REGLES DU MILITANT SONT AU SERVEUR.
  SELECT public.sans_commentaires(p.prosrc) INTO v_src FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'militant_recruter';
  IF v_src !~ 'adhesion_syndicale_requise' THEN
    RAISE EXCEPTION 'P5 ECHOUEE : l adhesion syndicale n est pas verifiee au serveur';
  END IF;
  IF v_src !~ 'recrutement_du_jour_deja_fait' OR v_src !~ 'jour_de_jeu_pays' THEN
    RAISE EXCEPTION 'P5b ECHOUEE : la garde quotidienne n est pas au serveur';
  END IF;
  IF v_src !~ 'c_plafond constant integer := 2' THEN
    RAISE EXCEPTION 'P5c ECHOUEE : le plafond de deux a change';
  END IF;
  -- ET LES TROIS GARDES PRECEDENT LE PAIEMENT : un refus ne coute jamais un PA.
  IF position('adhesion_syndicale_requise' in v_src) > position('payer_ordre' in v_src)
     OR position('recrutement_du_jour_deja_fait' in v_src) > position('payer_ordre' in v_src)
     OR position('plafond_militants' in v_src) > position('payer_ordre' in v_src) THEN
    RAISE EXCEPTION 'P5d ECHOUEE : une garde du militant arrive apres le paiement';
  END IF;

  -- P6. L'OSSATURE EST UNE FONDATION, PAS UN SYSTEME : deux cles posees a la constitution, et
  -- aucune prerogative ailleurs. La mesure croise les deux mots -- `public.organisations` et
  -- `'president'` -- parce que « president » seul designe aussi le chef de l'Etat.
  --
  -- UNE FONCTION EST ECARTEE NOMMEMENT, ET LA RAISON EST VERIFIEE : `agent_conseillere_observer`
  -- parle du President de la REPUBLIQUE et lit les organisations pour tout autre chose. La
  -- preuve P6b le montre -- elle ne lit AUCUN `->> 'president'`, donc aucun president
  -- d'organisation.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname NOT IN ('syndicat_etudiant_domicilier', 'organisation_extrait_duplicata',
                           'agent_conseillere_observer')
     AND public.sans_commentaires(p.prosrc) LIKE '%public.organisations%'
     AND public.sans_commentaires(p.prosrc) LIKE '%''president''%';
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P6 ECHOUEE : % fonction(s) lisent deja une prerogative de president', v_n;
  END IF;
  SELECT public.sans_commentaires(p.prosrc) INTO v_src FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'agent_conseillere_observer';
  IF v_src ~ '->>\s*''president''' THEN
    RAISE EXCEPTION 'P6b ECHOUEE : la fonction ecartee lit bien un president d organisation';
  END IF;

  -- P7. LES DEUX ORDRES SONT AU MIROIR, aux montants de l'arbitrage.
  SELECT count(*) INTO v_n FROM public.ordres_couts
   WHERE (fn, pa, cost) IN (('syndicat_etudiant_creer', 2, 150), ('orga_extrait_duplicata', 1, 75));
  IF v_n <> 2 THEN RAISE EXCEPTION 'P7 ECHOUEE : % ligne(s) sur 2 au miroir', v_n; END IF;

  -- P8. LES DEUX PORTES NEUVES SONT CLIENTES, DEFINER, A SEARCH_PATH FIGE.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('syndicat_etudiant_domicilier', 'organisation_extrait_duplicata')
     AND p.prosecdef AND array_to_string(p.proconfig, ',') LIKE '%search_path=public, pg_temp%';
  IF v_n <> 2 THEN RAISE EXCEPTION 'P8 ECHOUEE : % porte(s) conforme(s) sur 2', v_n; END IF;
  SELECT count(*) INTO v_n FROM information_schema.role_routine_grants
   WHERE specific_schema = 'public' AND grantee = 'authenticated' AND privilege_type = 'EXECUTE'
     AND routine_name IN ('syndicat_etudiant_domicilier', 'organisation_extrait_duplicata');
  IF v_n <> 2 THEN RAISE EXCEPTION 'P8b ECHOUEE : % porte(s) appelable(s) sur 2', v_n; END IF;

  -- P9. LA FORMATION UNIVERSITAIRE EST STRUCTURELLEMENT IMPOSSIBLE, et ce n'est pas un bouton
  -- grise : le CATALOGUE DES CURSUS EST VIDE, donc `universite_inscrire` ne peut que refuser
  -- `cursus_inconnu`. C'est la mesure que l'arbitrage demande -- « desactivation reelle ».
  SELECT count(*) INTO v_n FROM public.universite_cursus;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P9 ECHOUEE : % cursus au catalogue -- la formation serait lancable', v_n;
  END IF;
  SELECT count(*) INTO v_n FROM public.universite_inscriptions;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P9b ECHOUEE : % inscription(s) en cours', v_n; END IF;
  SELECT public.sans_commentaires(p.prosrc) INTO v_src FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'universite_inscrire';
  IF v_src !~ 'cursus_inconnu' THEN
    RAISE EXCEPTION 'P9c ECHOUEE : l inscription n exige pas un cursus du catalogue';
  END IF;

  RAISE NOTICE 'LES 9 PREUVES STRUCTURELLES SONT VERTES.';
END $$;
