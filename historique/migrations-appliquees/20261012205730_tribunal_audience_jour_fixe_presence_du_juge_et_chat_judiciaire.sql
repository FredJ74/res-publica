-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261012205730 (UTC), nom
-- `tribunal_audience_jour_fixe_presence_du_juge_et_chat_judiciaire`.
-- Le registre passe de 698 a 699 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 ae636a2a675d8a7ce35ea95977a2962c, 28651 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- L'AUDIENCE A UN JOUR, UN LIEU, ET UNE PAROLE QUI S'ECRIT
--
-- CE QUI MANQUAIT. L'audience savait s'ouvrir et distribuer la parole, mais elle n'avait ni DATE
-- ni LIEU : le juge pouvait l'ouvrir a l'instant, depuis n'importe ou, et la parole accordee
-- n'ouvrait aucun endroit ou parler.
--
--   1. LE JUGE FIXE LE JOUR.
--   2. AU MINIMUM TROIS JOURS. Plus tot exige le consentement EXPLICITE du prevenu, SUR CE
--      JOUR-LA : un consentement donne pour le jour J ne vaut pas pour J-1. Aucun consentement
--      implicite, et il appartient au prevenu seul -- ni son avocat ni le juge ne le donnent.
--   3. LE JOUR VENU, LE JUGE DOIT ETRE DANS SON TRIBUNAL, salle d'audience.
--   4. NI L'ABSENCE DU PREVENU NI CELLE DU PROCUREUR NE BLOQUENT. Elles sont CONSTATEES et
--      consignees comme des FAITS : aucun malus, aucune perte de popularite, aucun jugement moral.
--
-- LE CHAT JUDICIAIRE EST UN LIEU, PAS UN MOTEUR. Append-only et verbatim. LIRE : tout PJ
-- physiquement present dans la salle -- un spectateur lit. ECRIRE : le juge, le procureur, le
-- prevenu, l'avocat retenu -- et un temoin UNIQUEMENT si le juge lui a donne la parole, qu'il peut
-- retirer. Les droits sont RECALCULES AU SERVEUR a chaque message : le role affiche par le
-- navigateur n'entre nulle part dans la decision.
--
-- AUCUNE IA, AUCUN SCORE, AUCUN RESUME. Personne ne note une plaidoirie, ne mesure une
-- credibilite, ne resume des debats en verite.
--
-- PREUVES STRUCTURELLES -- 16.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- L'AUDIENCE A UN JOUR, UN LIEU, ET UNE PAROLE QUI S'ECRIT
-- 12 octobre 2026, nuit -- lot 6
--
-- CE QUI MANQUAIT. L'audience savait s'ouvrir et distribuer la parole, mais elle n'avait ni DATE
-- ni LIEU : le juge pouvait l'ouvrir a l'instant, depuis n'importe ou, et la parole accordee
-- n'ouvrait aucun endroit ou parler. Les quatre regles validees sont posees ici.
--
--   1. LE JUGE FIXE LE JOUR. `justice_audience_fixer`, sur une affaire dont il est saisi.
--   2. AU MINIMUM TROIS JOURS. Plus tot EXIGE le consentement EXPLICITE du prevenu, sur ce
--      jour-la precisement : `justice_audience_consentir(affaire, jour)`. Il n'existe aucun
--      consentement implicite, aucun consentement « general », et un consentement donne pour le
--      jour J ne vaut pas pour le jour J-1 -- si le juge change de date, il faut un consentement
--      neuf. Le prevenu peut le retirer tant que l'audience n'est pas ouverte.
--   3. LE JOUR VENU, LE JUGE DOIT ETRE DANS LE TRIBUNAL COMPETENT, salle d'audience, mesure par
--      `acteur_present_sur_site` -- la regle unique de localisation du depot.
--   4. NI L'ABSENCE DU PREVENU NI CELLE DU PROCUREUR NE BLOQUENT L'AUDIENCE. Elles sont
--      CONSTATEES et consignees comme des FAITS, et rien de plus : aucun malus, aucune perte de
--      popularite, aucun jugement moral du serveur. Qui etait la, et qui n'y etait pas.
--
-- LE CHAT JUDICIAIRE EST UN LIEU, PAS UN MOTEUR. `audience_messages` est append-only et verbatim.
-- LIRE : tout PJ physiquement present dans la salle d'audience competente -- un spectateur lit.
-- ECRIRE : le juge, le procureur, le prevenu, l'avocat retenu -- et un temoin UNIQUEMENT si le
-- juge lui a donne la parole, qu'il peut retirer. Les droits sont recalcules AU SERVEUR a chaque
-- message : le role affiche par le navigateur n'entre nulle part dans la decision.
--
-- AUCUNE IA, AUCUN SCORE, AUCUN RESUME. Le texte est consigne tel qu'il est ecrit. Personne ne
-- note une plaidoirie, ne mesure une credibilite, ne resume des debats en verite. Ce que les
-- joueurs se disent leur appartient.
--
-- PREUVES STRUCTURELLES -- 16.

-- ============================================================================================
-- 1. LA SALLE D'AUDIENCE COMPETENTE
-- ============================================================================================
-- MEME PATRON QUE `justice_greffe_competent`, et pour la meme raison : la piece ne porte pas le
-- meme identifiant dans le gabarit de la capitale et dans celui des tribunaux locaux.
CREATE OR REPLACE FUNCTION public.justice_salle_audience_competente(p_pays text, p_ville text)
RETURNS TABLE(batiment text, piece text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT s.b,
         CASE WHEN s.b = 'tribunal' THEN 'salle_audience'
              WHEN s.b = 'tribunal-local' THEN 'salle_audience_locale'
              ELSE NULL END
    FROM (SELECT public.parquet_site_competent(p_pays, p_ville) AS b) s
   WHERE s.b IS NOT NULL;
$$;

-- ============================================================================================
-- 2. LE CHAT JUDICIAIRE
-- ============================================================================================
CREATE TABLE IF NOT EXISTS public.audience_messages (
  rang    bigserial PRIMARY KEY,
  affaire text NOT NULL,
  pays    text NOT NULL,
  ville   text NOT NULL,
  auteur  text NOT NULL,
  qualite text NOT NULL,
  texte   text NOT NULL,
  dit_le  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT audience_messages_texte_non_vide CHECK (btrim(texte) <> ''),
  CONSTRAINT audience_messages_texte_borne CHECK (length(texte) <= 4000),
  CONSTRAINT audience_messages_qualite_check
    CHECK (qualite IN ('juge', 'procureur', 'prevenu', 'avocat', 'temoin'))
);
REVOKE ALL ON TABLE public.audience_messages FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.audience_messages_rang_seq FROM PUBLIC, anon, authenticated;
ALTER TABLE public.audience_messages ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS audience_messages_par_affaire
  ON public.audience_messages (affaire, rang);

-- CE QUI EST DIT A L'AUDIENCE NE SE REECRIT PAS. Troisieme verrou, celui qui bat service_role et
-- les fonctions SECURITY DEFINER : une absence de droit ne les arrete pas, une exception si.
CREATE OR REPLACE FUNCTION public.audience_messages_append_only()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  RAISE EXCEPTION 'audience_messages est en ajout seul : ni modification ni suppression';
END $$;
DROP TRIGGER IF EXISTS trg_audience_messages_append_only ON public.audience_messages;
CREATE TRIGGER trg_audience_messages_append_only
  BEFORE UPDATE OR DELETE ON public.audience_messages
  FOR EACH ROW EXECUTE FUNCTION public.audience_messages_append_only();

-- ============================================================================================
-- 3. LE JUGE FIXE LE JOUR
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.justice_delai_audience_jours()
RETURNS integer LANGUAGE sql IMMUTABLE AS $$ SELECT 3; $$;

CREATE OR REPLACE FUNCTION public.justice_audience_fixer(p_affaire_id text, p_jour integer)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_j record; v_brut text; v_a jsonb; v_ville text; v_pays text;
        v_jour integer; v_min integer; v_n integer; v_prev text;
BEGIN
  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;

  SELECT * INTO v_j FROM public.juge_de_la_ville(v_ville);
  IF v_j.nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_juge_de_cette_ville', 'ville', v_ville); END IF;
  IF coalesce(v_a ->> 'status', '') <> 'saisie' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_non_saisie', 'statut', v_a ->> 'status'); END IF;
  IF public.affaire_audience_ouverte(v_a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audience_deja_ouverte'); END IF;

  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  v_min  := v_jour + public.justice_delai_audience_jours();
  v_prev := v_a ->> 'cible';

  IF p_jour IS NULL OR p_jour < v_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jour_invalide',
                              'jour_courant', v_jour, 'minimum', v_min); END IF;

  -- PLUS TOT QUE J+3 N'EST POSSIBLE QUE SI LE PREVENU A CONSENTI A CE JOUR-LA. Le consentement
  -- porte sur UN jour precis : s'il a consenti au jour 12 et que le juge fixe le 11, il faut un
  -- consentement neuf. Rien n'est deduit du silence.
  IF p_jour < v_min
     AND coalesce((v_a ->> 'audience_consentie_jour')::integer, -1) IS DISTINCT FROM p_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'consentement_du_prevenu_requis',
      'minimum', v_min, 'demande', p_jour, 'prevenu', v_prev);
  END IF;

  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'audience_jour', p_jour,
           'audience_fixee_par', v_j.nom,
           'audience_fixee_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text
   WHERE id = p_affaire_id AND (data::jsonb ->> 'status') = 'saisie'
     AND NOT (data::jsonb ? 'audience_ouverte_le');
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'statut_a_change'); END IF;

  -- ET L'EFFET EST RELU EN BASE, jamais suppose.
  SELECT p.data::jsonb INTO v_a FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF (v_a ->> 'audience_jour')::integer IS DISTINCT FROM p_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'date_non_appliquee'); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'audience_fixee',
    v_j.nom, 'juge', NULL, NULL,
    jsonb_build_object('jour', p_jour, 'minimum', v_min,
                       'consentement_du_prevenu', p_jour < v_min));

  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'jour', p_jour,
                            'minimum', v_min, 'juge', v_j.nom);
END $$;
GRANT EXECUTE ON FUNCTION public.justice_audience_fixer(text, integer) TO authenticated;

-- ============================================================================================
-- 4. LE PREVENU CONSENT -- EXPLICITEMENT, SUR UN JOUR, ET IL PEUT SE RETIRER
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.justice_audience_consentir(p_affaire_id text, p_jour integer)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_moi text; v_brut text; v_a jsonb; v_ville text; v_pays text; v_jour integer; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;

  -- LE CONSENTEMENT APPARTIENT AU PREVENU, ET A LUI SEUL. Ni son avocat, ni le juge, ni le
  -- parquet ne peuvent le donner a sa place.
  IF coalesce(v_a ->> 'cible', '') IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_affaire'); END IF;
  IF public.affaire_audience_ouverte(v_a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audience_ouverte'); END IF;

  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  IF p_jour IS NOT NULL AND p_jour < v_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jour_invalide', 'jour_courant', v_jour); END IF;

  UPDATE public.plaintes_en_cours
     SET data = CASE WHEN p_jour IS NULL
                THEN (v_a - 'audience_consentie_jour' - 'audience_consentie_le')::text
                ELSE (v_a || jsonb_build_object(
                        'audience_consentie_jour', p_jour,
                        'audience_consentie_le',
                        to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text END
   WHERE id = p_affaire_id AND NOT (data::jsonb ? 'audience_ouverte_le');
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'audience_ouverte'); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville,
    CASE WHEN p_jour IS NULL THEN 'audience_consentement_retire' ELSE 'audience_consentement' END,
    v_moi, 'accuse', NULL, NULL, jsonb_build_object('jour', p_jour));

  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id,
                            'consenti_jour', p_jour, 'retire', (p_jour IS NULL));
END $$;
GRANT EXECUTE ON FUNCTION public.justice_audience_consentir(text, integer) TO authenticated;

-- ============================================================================================
-- 5. OUVRIR L'AUDIENCE -- LE JOUR VENU, SUR PLACE, ET ON CONSTATE QUI EST LA
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.justice_audience_ouvrir(p_affaire_id text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_j record; v_brut text; v_a jsonb; v_ville text; v_pays text; v_n integer;
        v_jour integer; v_s record; v_prev text; v_proc text;
        v_prev_la boolean; v_proc_la boolean;
BEGIN
  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;

  SELECT * INTO v_j FROM public.juge_de_la_ville(v_ville);
  IF v_j.nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_juge_de_cette_ville', 'ville', v_ville); END IF;
  IF coalesce(v_a ->> 'status', '') <> 'saisie' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_non_saisie',
                              'statut', v_a ->> 'status'); END IF;
  IF public.affaire_delai_expire(v_a, v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_de_jugement_expire'); END IF;
  IF public.affaire_audience_ouverte(v_a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audience_deja_ouverte'); END IF;

  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);

  -- LE JOUR DOIT AVOIR ETE FIXE, ET IL DOIT ETRE ARRIVE.
  IF (v_a ->> 'audience_jour') IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jour_d_audience_non_fixe'); END IF;
  IF v_jour < (v_a ->> 'audience_jour')::integer THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jour_d_audience_non_venu',
      'jour_courant', v_jour, 'audience_jour', (v_a ->> 'audience_jour')::integer); END IF;

  -- LE JUGE TIENT SON AUDIENCE DANS SON TRIBUNAL. Pas depuis chez lui, pas depuis une autre ville.
  SELECT * INTO v_s FROM public.justice_salle_audience_competente(v_pays, v_ville);
  IF v_s.batiment IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'salle_indeterminee', 'ville', v_ville); END IF;
  IF NOT public.acteur_present_sur_site(v_j.nom, v_pays, v_ville, v_s.batiment, v_s.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_du_juge_requise',
      'ville', v_ville, 'site', v_s.batiment, 'piece', v_s.piece); END IF;

  -- QUI EST LA, ET QUI N'Y EST PAS. C'est un CONSTAT, pas un reproche : ni l'absence du prevenu
  -- ni celle du procureur ne bloquent quoi que ce soit, et aucune consequence mecanique n'en
  -- decoule. Le fait est consigne ; son interpretation appartient aux joueurs.
  v_prev := v_a ->> 'cible';
  SELECT t.nom_pnj INTO v_proc FROM public.titulaires_pnj t
   WHERE t.country = v_pays AND t.poste_id = 'procureur' AND t.city IS NULL;
  IF v_proc IS NULL THEN
    SELECT a2.titulaire INTO v_proc FROM public.postes_attribues a2
     WHERE a2.country = v_pays AND a2.poste_id = 'procureur';
  END IF;
  v_prev_la := v_prev IS NOT NULL
               AND public.acteur_present_sur_site(v_prev, v_pays, v_ville, v_s.batiment, v_s.piece);
  v_proc_la := v_proc IS NOT NULL
               AND public.acteur_present_sur_site(v_proc, v_pays, v_ville, v_s.batiment, v_s.piece);

  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object(
           'audience_ouverte_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'audience_ouverte_jour', v_jour,
           'audience_ouverte_par', v_j.nom,
           'audience_prevenu_present', v_prev_la,
           'audience_procureur_present', v_proc_la))::text
   WHERE id = p_affaire_id AND (data::jsonb ->> 'status') = 'saisie'
     AND NOT (data::jsonb ? 'audience_ouverte_le');
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'audience_deja_ouverte'); END IF;

  SELECT p.data::jsonb INTO v_a FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF NOT public.affaire_audience_ouverte(v_a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ouverture_non_appliquee'); END IF;

  PERFORM public.dossier_acte_consigner(p_affaire_id, v_pays, v_ville, 'audience_ouverte',
    v_j.nom, 'juge', NULL, NULL,
    jsonb_build_object('jour', v_jour, 'prevenu_present', v_prev_la,
                       'procureur_present', v_proc_la, 'procureur', v_proc));

  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id, 'juge', v_j.nom, 'jour', v_jour,
    'prevenu_present', v_prev_la, 'procureur_present', v_proc_la,
    'salle', jsonb_build_object('batiment', v_s.batiment, 'piece', v_s.piece));
END $$;

-- ============================================================================================
-- 6. QUI PEUT LIRE, QUI PEUT ECRIRE -- CALCULE AU SERVEUR, A CHAQUE FOIS
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.audience_role_de(p_affaire_id text, p_personne text)
RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_brut text; v_a jsonb; v_ville text; v_pays text; v_j record; v_p record;
BEGIN
  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN RETURN NULL; END IF;
  v_a := v_brut::jsonb;

  SELECT * INTO v_j FROM public.juge_de_la_ville(v_ville);
  IF v_j.nom = p_personne THEN RETURN 'juge'; END IF;
  SELECT * INTO v_p FROM public.parquet_moi();
  IF v_p.nom = p_personne AND v_p.pays IS NOT DISTINCT FROM v_pays THEN RETURN 'procureur'; END IF;
  IF coalesce(v_a ->> 'cible', '') = p_personne THEN RETURN 'prevenu'; END IF;
  IF public.defense_avocat_de(p_affaire_id) = p_personne THEN RETURN 'avocat'; END IF;
  IF EXISTS (SELECT 1 FROM public.temoins_citations c
              WHERE c.affaire = p_affaire_id AND c.temoin = p_personne) THEN RETURN 'temoin'; END IF;
  RETURN 'spectateur';
END $$;

-- ============================================================================================
-- 7. ECRIRE A L'AUDIENCE
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.justice_audience_ecrire(p_affaire_id text, p_texte text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_moi text; v_brut text; v_a jsonb; v_ville text; v_pays text;
        v_s record; v_role text; v_txt text; v_rang bigint;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_txt := coalesce(p_texte, '');
  IF btrim(v_txt) = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'message_vide'); END IF;
  IF length(v_txt) > 4000 THEN RETURN jsonb_build_object('ok', false, 'raison', 'message_trop_long'); END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;
  IF NOT public.affaire_audience_ouverte(v_a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audience_non_ouverte'); END IF;

  -- ON PARLE DANS LA SALLE, PAS DEPUIS CHEZ SOI.
  SELECT * INTO v_s FROM public.justice_salle_audience_competente(v_pays, v_ville);
  IF v_s.batiment IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'salle_indeterminee'); END IF;
  IF NOT public.acteur_present_sur_site(v_moi, v_pays, v_ville, v_s.batiment, v_s.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_en_salle_requise',
      'site', v_s.batiment, 'piece', v_s.piece); END IF;

  -- LE ROLE EST RECALCULE ICI, A PARTIR DE LA BASE. Le navigateur n'en dit rien et n'est pas cru.
  v_role := public.audience_role_de(p_affaire_id, v_moi);
  IF v_role = 'spectateur' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'spectateur_sans_parole'); END IF;
  -- UN TEMOIN N'A AUCUN DROIT AUTOMATIQUE D'ECRIRE : il lui faut la parole du juge, et le juge
  -- peut la retirer.
  IF v_role = 'temoin' AND NOT public.audience_peut_ecrire(p_affaire_id, v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parole_non_accordee'); END IF;

  INSERT INTO public.audience_messages (affaire, pays, ville, auteur, qualite, texte)
  VALUES (p_affaire_id, v_pays, v_ville, v_moi, v_role, v_txt)
  RETURNING rang INTO v_rang;

  RETURN jsonb_build_object('ok', true, 'rang', v_rang, 'affaire', p_affaire_id,
                            'qualite', v_role, 'auteur', v_moi);
END $$;
GRANT EXECUTE ON FUNCTION public.justice_audience_ecrire(text, text) TO authenticated;

-- ============================================================================================
-- 8. LIRE L'AUDIENCE -- TOUT CE QUI EST PRESENT DANS LA SALLE
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.justice_audience_lire(p_affaire_id text, p_apres bigint DEFAULT 0)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_moi text; v_brut text; v_a jsonb; v_ville text; v_pays text; v_s record; v_role text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;

  SELECT * INTO v_s FROM public.justice_salle_audience_competente(v_pays, v_ville);
  IF v_s.batiment IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'salle_indeterminee'); END IF;
  -- LIRE EXIGE D'ETRE LA. Une audience publique l'est pour qui s'y rend, pas pour le monde entier.
  IF NOT public.acteur_present_sur_site(v_moi, v_pays, v_ville, v_s.batiment, v_s.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_en_salle_requise',
      'site', v_s.batiment, 'piece', v_s.piece); END IF;

  v_role := public.audience_role_de(p_affaire_id, v_moi);
  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire_id,
    'ouverte', public.affaire_audience_ouverte(v_a),
    'mon_role', v_role,
    'je_peux_ecrire', public.affaire_audience_ouverte(v_a)
       AND v_role <> 'spectateur'
       AND (v_role <> 'temoin' OR public.audience_peut_ecrire(p_affaire_id, v_moi)),
    'paroles', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                  'personne', x.personne, 'accordee_le', x.accordee_le,
                  'retiree_le', x.retiree_le) ORDER BY x.accordee_le), '[]'::jsonb)
                 FROM public.audience_paroles x WHERE x.affaire = p_affaire_id),
    'messages', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                   'rang', m.rang, 'auteur', m.auteur, 'qualite', m.qualite,
                   'texte', m.texte, 'dit_le', m.dit_le) ORDER BY m.rang), '[]'::jsonb)
                  FROM (SELECT * FROM public.audience_messages
                         WHERE affaire = p_affaire_id AND rang > coalesce(p_apres, 0)
                         ORDER BY rang LIMIT 200) m));
END $$;
GRANT EXECUTE ON FUNCTION public.justice_audience_lire(text, bigint) TO authenticated;

-- ============================================================================================
-- 9. LES ACTES NEUFS AU REGISTRE
-- ============================================================================================
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES
  ('audience_fixee', 'Jour d''audience fixe', 'juge',
   'Le juge fixe le jour du proces. Au minimum trois jours apres, sauf consentement explicite du prevenu sur ce jour-la.'),
  ('audience_consentement', 'Consentement du prevenu a une audience anticipee', 'accuse',
   'Le prevenu accepte EXPLICITEMENT d''etre juge avant le delai de trois jours, sur un jour precis. Aucun consentement n''est jamais deduit d''un silence.'),
  ('audience_consentement_retire', 'Consentement a une audience anticipee retire', 'accuse',
   'Le prevenu retire son consentement. Possible tant que l''audience n''est pas ouverte.'),
  ('audience_ouverte', 'Audience ouverte', 'juge',
   'Le jour fixe est venu et le juge est dans sa salle d''audience. L''acte CONSTATE qui etait present -- le prevenu, le procureur -- et rien de plus : aucune absence n''emporte de consequence mecanique.')
ON CONFLICT (type) DO UPDATE SET libelle = EXCLUDED.libelle, note = EXCLUDED.note;

-- ============================================================================================
-- PREUVES STRUCTURELLES -- 16
-- ============================================================================================
DO $preuves$
DECLARE v_n integer; v_txt text;
BEGIN
  SELECT count(*) INTO v_n FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relname = 'audience_messages' AND c.relrowsecurity;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P1 ECHOUEE -- le chat judiciaire n''est pas sous RLS'; END IF;

  SELECT count(*) INTO v_n FROM pg_class c
   WHERE c.relname IN ('audience_messages', 'audience_messages_rang_seq')
     AND EXISTS (SELECT 1 FROM aclexplode(c.relacl) ae JOIN pg_roles r ON r.oid = ae.grantee
                  WHERE r.rolname IN ('anon', 'authenticated'));
  IF v_n <> 0 THEN RAISE EXCEPTION 'P2 ECHOUEE -- le chat ou sa sequence sont ouverts aux clients'; END IF;

  SELECT count(*) INTO v_n FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
   WHERE c.relname = 'audience_messages' AND NOT t.tgisinternal
     AND t.tgname = 'trg_audience_messages_append_only';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P3 ECHOUEE -- les debats peuvent etre reecrits'; END IF;

  IF public.justice_delai_audience_jours() <> 3 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- le delai minimal d''audience ne vaut pas 3 jours'; END IF;

  SELECT prosrc INTO v_txt FROM pg_proc
   WHERE pronamespace = 'public'::regnamespace AND proname = 'justice_audience_fixer';
  IF v_txt !~ 'justice_delai_audience_jours' THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- le minimum de trois jours est recopie au lieu d''etre lu'; END IF;
  IF position('''consentement_du_prevenu_requis''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- une date anticipee ne demande pas le consentement du prevenu'; END IF;
  IF v_txt !~ 'audience_consentie_jour' THEN
    RAISE EXCEPTION 'P7 ECHOUEE -- le consentement n''est pas verifie sur le JOUR demande'; END IF;

  SELECT prosrc INTO v_txt FROM pg_proc
   WHERE pronamespace = 'public'::regnamespace AND proname = 'justice_audience_consentir';
  IF position('''pas_mon_affaire''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P8 ECHOUEE -- quelqu''un d''autre peut consentir a la place du prevenu'; END IF;

  SELECT prosrc INTO v_txt FROM pg_proc
   WHERE pronamespace = 'public'::regnamespace AND proname = 'justice_audience_ouvrir';
  IF position('''jour_d_audience_non_venu''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P9 ECHOUEE -- l''audience s''ouvre avant le jour fixe'; END IF;
  IF position('''presence_du_juge_requise''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P10 ECHOUEE -- le juge ouvre son audience a distance'; END IF;
  IF v_txt !~ 'audience_prevenu_present' OR v_txt !~ 'audience_procureur_present' THEN
    RAISE EXCEPTION 'P11 ECHOUEE -- les presences ne sont pas constatees'; END IF;
  -- L'ABSENCE EST UN FAIT, PAS UNE SANCTION. La mesure porte sur des IDENTIFIANTS DE CODE --
  -- jamais sur des mots de prose, qui se trouvent aussi dans les commentaires ci-dessus.
  IF v_txt ~ 'personnage_ajuster_pop|payer_ordre|debiter_|indices_|detention_ouvrir|recherche_inscrire' THEN
    RAISE EXCEPTION 'P12 ECHOUEE -- une absence a l''audience emporte une consequence mecanique'; END IF;

  SELECT prosrc INTO v_txt FROM pg_proc
   WHERE pronamespace = 'public'::regnamespace AND proname = 'justice_audience_ecrire';
  IF v_txt !~ 'audience_role_de' OR v_txt !~ 'acteur_present_sur_site' THEN
    RAISE EXCEPTION 'P13 ECHOUEE -- le droit d''ecrire ne se calcule pas au serveur'; END IF;
  IF position('''parole_non_accordee''' IN v_txt) = 0
     OR position('''spectateur_sans_parole''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P14 ECHOUEE -- un temoin ou un spectateur ecrit sans la parole'; END IF;
  IF v_txt ~ 'deepseek|openai|ia_|analyse_|evaluer_|noter_|resumer_' THEN
    RAISE EXCEPTION 'P15 ECHOUEE -- une IA touche aux debats'; END IF;

  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes_types
   WHERE type IN ('audience_fixee','audience_consentement','audience_consentement_retire','audience_ouverte');
  IF v_n <> 4 THEN RAISE EXCEPTION 'P16 ECHOUEE -- les actes de l''audience ne sont pas tous declares'; END IF;

  RAISE NOTICE 'LES 16 PREUVES SONT VERTES.';
END $preuves$;
