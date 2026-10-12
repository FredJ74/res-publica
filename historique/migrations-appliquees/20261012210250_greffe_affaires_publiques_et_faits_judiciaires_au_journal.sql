-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261012210250 (UTC), nom
-- `greffe_affaires_publiques_et_faits_judiciaires_au_journal`.
-- Le registre passe de 699 a 700 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 da28780e4ab204bd9d1f4dcec985b98b, 16616 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- CE QUE LE GREFFE DIT A TOUT LE MONDE, ET CE QUE LE JOURNAL APPREND
--
-- L'AFFAIRE EN COURS EST PUBLIQUE, SON DOSSIER NE L'EST PAS. Un citoyen au greffe apprend QUI est
-- poursuivi, pour quelle CATEGORIE generale, ou en est la procedure, et qui a ete CITE comme
-- temoin. Il n'apprend ni le texte de la plainte, ni l'identite du plaignant, ni une preuve, ni un
-- PV, ni le contenu d'une deposition. Ce ne sont pas deux affichages : ce sont deux portes
-- serveur distinctes, et la porte publique NE LIT PAS ce qu'elle ne doit pas dire.
--
-- LES ARCHIVES NE SE REECRIVENT PAS. `justice_archives_greffe` expose la chronologie complete des
-- affaires closes -- la SUITE des actes, jamais leur contenu.
--
-- LES FAITS JUDICIAIRES ENTRENT AU JOURNAL PAR LE CANAL QUI EXISTE DEJA : une ligne dans
-- `chronique_nationale`. Et surtout AUCUN CROCHET DANS LES HUIT PORTES JUDICIAIRES : un
-- DECLENCHEUR sur les ACTES fait le travail. Une neuvieme porte publiera sans qu'on y pense -- et
-- un acte non declare au registre `justice_faits_publics` ne publiera rien : le silence est le
-- defaut.
--
-- LE LIBELLE DIT LE FAIT, ET RIEN QUE LE FAIT. « Le proces s'est ouvert en l'absence du
-- Procureur » est un constat ; « le Procureur a abandonne ses responsabilites » serait une
-- interpretation, et l'interpretation appartient aux joueurs et aux journalistes.
--
-- LE PIEGE DU COMMENTAIRE S'EST REFERME UNE SEPTIEME FOIS EN QUATRE JOURS, ICI MEME : une preuve
-- negative cherchait des cles interdites dans `prosrc`, qui CONTIENT les commentaires -- dont
-- celui qui enumere precisement ce qui est interdit. La reponse generale est desormais ecrite une
-- fois pour toutes : `sans_commentaires()` retire les lignes de commentaire AVANT toute mesure
-- d'absence.
--
-- PREUVES STRUCTURELLES -- 13.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CE QUE LE GREFFE DIT A TOUT LE MONDE, ET CE QUE LE JOURNAL APPREND
-- 12 octobre 2026, nuit -- lots 7 et 8
--
-- §N -- L'AFFAIRE EN COURS EST PUBLIQUE, SON DOSSIER NE L'EST PAS. Un citoyen qui se rend au
-- greffe apprend QUI est poursuivi, pour quelle CATEGORIE generale, ou en est la procedure, et
-- qui a ete CITE comme temoin. Il n'apprend ni le texte de la plainte, ni l'identite du
-- plaignant, ni une preuve, ni un PV, ni le contenu d'une deposition. La difference entre les
-- deux n'est pas une question d'affichage : ce sont deux portes serveur distinctes, et la porte
-- publique ne LIT PAS ce qu'elle ne doit pas dire.
--
-- §O -- LES ARCHIVES NE SE REECRIVENT PAS. `dossiers_judiciaires_actes` est deja append-only par
-- declencheur ; rien n'est detruit quand un etat change. `justice_archives_greffe` l'expose pour
-- les affaires CLOSES, avec la chronologie complete des actes -- l'histoire procedurale reelle,
-- pas son dernier etat.
--
-- §8 -- LES FAITS JUDICIAIRES ENTRENT DANS LE JOURNAL PAR LE CANAL QUI EXISTE DEJA. Aucune
-- seconde architecture : une ligne dans `chronique_nationale`, que `collecterChroniqueNationale`
-- lit depuis septembre. Et surtout AUCUN CROCHET DANS LES HUIT PORTES JUDICIAIRES : un
-- DECLENCHEUR sur `dossiers_judiciaires_actes` fait le travail, parce que chaque acte de la
-- procedure y est deja consigne. Une neuvieme porte qui consignera un acte declare public sera
-- publiee sans qu'on y pense -- et une porte qui consigne un acte NON declare ne publiera rien,
-- ce qui est le defaut sur : ici, le silence est le defaut.
--
-- CE QUE LE LIBELLE DIT, ET CE QU'IL NE DIRA JAMAIS. Le fait, et le fait seul. « Le Procureur
-- n'etait pas present a l'audience » est un constat ; « le Procureur a abandonne ses
-- responsabilites » serait une interpretation, et l'interpretation appartient aux joueurs et aux
-- journalistes.
--
-- LE PIEGE DU COMMENTAIRE S'EST REFERME UNE SEPTIEME FOIS EN QUATRE JOURS, ICI MEME. La preuve
-- P12 cherchait des cles interdites dans `prosrc` -- et `prosrc` CONTIENT LES COMMENTAIRES de la
-- fonction, dont celui qui enumere precisement ce qui est interdit. La reponse generale est
-- desormais ecrite une fois pour toutes : `sans_commentaires()` retire les lignes de commentaire
-- AVANT toute mesure d'absence. Les preuves negatives portent sur du CODE, jamais sur de la prose.
--
-- PREUVES STRUCTURELLES -- 13.

-- ============================================================================================
-- 0. L'OUTIL DES PREUVES NEGATIVES
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.sans_commentaires(p_src text)
RETURNS text
LANGUAGE sql IMMUTABLE
AS $$
  -- Retire les commentaires de ligne SQL/plpgsql. Sert UNIQUEMENT aux preuves de migration et aux
  -- controles : une mesure d'absence qui lirait la prose mesurerait le commentaire qui explique
  -- l'interdiction, pas le code qui la respecte.
  SELECT regexp_replace(coalesce(p_src, ''), '--[^\n]*', '', 'g');
$$;

-- ============================================================================================
-- 1. LA CATEGORIE GENERALE D'UNE AFFAIRE -- ce que le public a le droit de savoir
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.affaire_categorie_publique(p_data jsonb)
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT coalesce(
    (SELECT i.categorie FROM public.infractions i
      WHERE i.id = coalesce(p_data ->> 'qualification_finale',
                            p_data ->> 'qualification_parquet',
                            p_data ->> 'infraction_constatee')),
    p_data ->> 'categorie_alleguee');
$$;

-- ============================================================================================
-- 2. LES AFFAIRES EN COURS, AU GREFFE, POUR TOUT LE MONDE
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.justice_affaires_publiques()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_moi text; v_pays text; v_ville text; v_g record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT d.country, coalesce(d.current_city, 'capitale') INTO v_pays, v_ville
    FROM public.personnages_donnees d WHERE d.name = v_moi;

  SELECT * INTO v_g FROM public.justice_greffe_competent(v_pays, v_ville);
  IF v_g.batiment IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'greffe_indetermine', 'ville', v_ville); END IF;
  IF NOT public.acteur_present_sur_site(v_moi, v_pays, v_ville, v_g.batiment, v_g.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_au_greffe_requise',
      'ville', v_ville, 'site', v_g.batiment, 'piece', v_g.piece); END IF;

  RETURN jsonb_build_object('ok', true, 'ville', v_ville, 'pays', v_pays,
    'affaires', (SELECT coalesce(jsonb_agg(jsonb_build_object(
        'affaire', p.id,
        'prevenu', (p.data::jsonb) ->> 'cible',
        'categorie', public.affaire_categorie_publique(p.data::jsonb),
        'statut', (p.data::jsonb) ->> 'status',
        'audience_jour', (p.data::jsonb) ->> 'audience_jour',
        'temoins', (SELECT coalesce(jsonb_agg(c.temoin ORDER BY c.rang), '[]'::jsonb)
                      FROM public.temoins_citations c WHERE c.affaire = p.id)
      ) ORDER BY p.id), '[]'::jsonb)
      FROM public.plaintes_en_cours p
     WHERE p.country = v_pays AND p.city = v_ville
       AND left(btrim(p.data), 1) = '{'
       AND (p.data::jsonb) ->> 'status' IN
           ('au_parquet', 'enquete', 'poursuites', 'saisie', 'abandon_demande')),
    'greffe', jsonb_build_object('batiment', v_g.batiment, 'piece', v_g.piece));
END $$;
GRANT EXECUTE ON FUNCTION public.justice_affaires_publiques() TO authenticated;

-- ============================================================================================
-- 3. LES ARCHIVES -- L'HISTOIRE, PAS LE DERNIER ETAT
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.justice_archives_greffe(p_affaire_id text DEFAULT NULL::text)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_moi text; v_pays text; v_ville text; v_g record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT d.country, coalesce(d.current_city, 'capitale') INTO v_pays, v_ville
    FROM public.personnages_donnees d WHERE d.name = v_moi;
  SELECT * INTO v_g FROM public.justice_greffe_competent(v_pays, v_ville);
  IF v_g.batiment IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'greffe_indetermine'); END IF;
  IF NOT public.acteur_present_sur_site(v_moi, v_pays, v_ville, v_g.batiment, v_g.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_au_greffe_requise',
      'site', v_g.batiment, 'piece', v_g.piece); END IF;

  RETURN jsonb_build_object('ok', true, 'ville', v_ville,
    'affaires', (SELECT coalesce(jsonb_agg(jsonb_build_object(
        'affaire', p.id,
        'prevenu', (p.data::jsonb) ->> 'cible',
        'categorie', public.affaire_categorie_publique(p.data::jsonb),
        'statut', (p.data::jsonb) ->> 'status',
        'verdict', (p.data::jsonb) ->> 'verdict',
        'peine', (SELECT j.peine FROM public.jugements j WHERE j.id = 'jug-' || p.id),
        'chronologie', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                          'rang', x.rang, 'type', x.type, 'libelle', t.libelle,
                          'poste', x.acteur_poste, 'fait_le', x.fait_le) ORDER BY x.rang), '[]'::jsonb)
                         FROM public.dossiers_judiciaires_actes x
                         JOIN public.dossiers_judiciaires_actes_types t ON t.type = x.type
                        WHERE x.affaire = p.id)
      ) ORDER BY p.id DESC), '[]'::jsonb)
      FROM public.plaintes_en_cours p
     WHERE p.country = v_pays AND p.city = v_ville
       AND left(btrim(p.data), 1) = '{'
       AND (p_affaire_id IS NULL OR p.id = p_affaire_id)
       AND (p.data::jsonb) ->> 'status' IN
           ('non_lieu', 'abandonnee', 'arret', 'relaxe', 'jugee', 'jugee_appel', 'delai_expire')));
END $$;
GRANT EXECUTE ON FUNCTION public.justice_archives_greffe(text) TO authenticated;

-- ============================================================================================
-- 4. QUELS ACTES SONT DES FAITS PUBLICS -- UN REGISTRE, PAS UN `CASE` DANS UN DECLENCHEUR
-- ============================================================================================
CREATE TABLE IF NOT EXISTS public.justice_faits_publics (
  type_acte       text PRIMARY KEY REFERENCES public.dossiers_judiciaires_actes_types(type),
  chronique_type  text NOT NULL,
  phrase          text NOT NULL,
  note            text
);
REVOKE ALL ON TABLE public.justice_faits_publics FROM PUBLIC, anon, authenticated;
ALTER TABLE public.justice_faits_publics ENABLE ROW LEVEL SECURITY;

INSERT INTO public.justice_faits_publics (type_acte, chronique_type, phrase, note) VALUES
  ('non_lieu', 'justice_non_lieu',
   'Le parquet a prononce un non-lieu dans l''affaire visant %s',
   'Le non-lieu ne dit rien de la veracite de la plainte ni de l''innocence de la personne visee -- la phrase non plus.'),
  ('poursuites_engagees', 'justice_poursuites',
   'Le parquet a engage des poursuites contre %s', NULL),
  ('abandon_poursuites', 'justice_abandon_parquet',
   'Le parquet a abandonne les poursuites contre %s', NULL),
  ('juge_poursuite_maintenue', 'justice_poursuite_maintenue',
   'Le juge a decide de poursuivre %s malgre l''abandon du parquet', NULL),
  ('juge_arret_accepte', 'justice_arret',
   'Le juge a accepte l''arret de la procedure visant %s', NULL),
  ('requalification', 'justice_requalification',
   'Le juge a requalifie les faits reproches a %s', NULL),
  ('condamnation', 'justice_condamnation',
   '%s a ete condamne(e)', NULL),
  ('relaxe', 'justice_relaxe',
   '%s a ete relaxe(e)', NULL),
  ('appel_ouvert', 'justice_appel',
   'Appel a ete interjete dans l''affaire visant %s', NULL),
  ('jugement_appel', 'justice_jugement_appel',
   'La cour a rendu son jugement d''appel dans l''affaire visant %s', NULL),
  ('audience_fixee', 'justice_audience_fixee',
   'Le jour du proces de %s a ete fixe', NULL),
  ('audience_ouverte', 'justice_audience',
   'Le proces de %s s''est ouvert',
   'Le libelle est complete par la PRESENCE constatee du Procureur, et par rien d''autre. Un constat, jamais un reproche.')
ON CONFLICT (type_acte) DO UPDATE
  SET chronique_type = EXCLUDED.chronique_type, phrase = EXCLUDED.phrase, note = EXCLUDED.note;

-- ============================================================================================
-- 5. LE DECLENCHEUR QUI PUBLIE -- LE FAIT, ET RIEN QUE LE FAIT
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.dossiers_actes_publier_au_journal()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_f record; v_prevenu text; v_libelle text; v_data jsonb;
BEGIN
  SELECT * INTO v_f FROM public.justice_faits_publics WHERE type_acte = NEW.type;
  IF NOT FOUND THEN RETURN NEW; END IF;

  SELECT (p.data::jsonb) ->> 'cible' INTO v_prevenu
    FROM public.plaintes_en_cours p WHERE p.id = NEW.affaire;
  IF v_prevenu IS NULL THEN RETURN NEW; END IF;

  v_libelle := format(v_f.phrase, v_prevenu);

  IF NEW.type = 'audience_ouverte'
     AND coalesce((NEW.donnees ->> 'procureur_present')::boolean, true) IS FALSE THEN
    v_libelle := v_libelle || ', en l''absence du Procureur';
  END IF;

  v_data := jsonb_build_object(
    'affaire', NEW.affaire, 'acte', NEW.type,
    'categorie', (SELECT public.affaire_categorie_publique(p.data::jsonb)
                    FROM public.plaintes_en_cours p WHERE p.id = NEW.affaire));
  IF NEW.type = 'audience_ouverte' THEN
    v_data := v_data || jsonb_build_object(
      'procureur_present', coalesce((NEW.donnees ->> 'procureur_present')::boolean, true),
      'prevenu_present', coalesce((NEW.donnees ->> 'prevenu_present')::boolean, true));
  END IF;

  INSERT INTO public.chronique_nationale
    (id, country, type, city, personnages, libelle, data, source_ref, created_at)
  VALUES ('chronique-' || v_f.chronique_type || '-' || NEW.rang::text,
          NEW.pays, v_f.chronique_type, NEW.ville,
          jsonb_build_array(v_prevenu), v_libelle, v_data, NEW.affaire, now())
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_dossiers_actes_chronique ON public.dossiers_judiciaires_actes;
CREATE TRIGGER trg_dossiers_actes_chronique
  AFTER INSERT ON public.dossiers_judiciaires_actes
  FOR EACH ROW EXECUTE FUNCTION public.dossiers_actes_publier_au_journal();

-- ============================================================================================
-- PREUVES STRUCTURELLES -- 13
-- ============================================================================================
DO $preuves$
DECLARE v_n integer; v_txt text;
BEGIN
  SELECT public.sans_commentaires(prosrc) INTO v_txt FROM pg_proc
   WHERE pronamespace = 'public'::regnamespace AND proname = 'justice_affaires_publiques';
  IF v_txt !~ 'presence_au_greffe_requise' THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- les affaires en cours se consultent a distance'; END IF;
  IF v_txt ~ 'dossiers_auditions|''motif''|''auteur''|''plaignant''|actions_tracables|dossiers_judiciaires_actes' THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la porte publique expose le dossier'; END IF;
  IF v_txt !~ 'affaire_categorie_publique' OR v_txt !~ 'temoins_citations' THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- la porte publique ne dit ni la categorie ni les temoins'; END IF;

  SELECT public.sans_commentaires(prosrc) INTO v_txt FROM pg_proc
   WHERE pronamespace = 'public'::regnamespace AND proname = 'affaire_categorie_publique';
  IF v_txt !~ 'infractions' THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- la categorie publique ne vient pas du code penal'; END IF;

  SELECT public.sans_commentaires(prosrc) INTO v_txt FROM pg_proc
   WHERE pronamespace = 'public'::regnamespace AND proname = 'justice_archives_greffe';
  IF v_txt ~ 'dossiers_auditions|actions_tracables|x\.donnees' THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- les archives publiques exposent le contenu des actes'; END IF;
  IF v_txt !~ 'dossiers_judiciaires_actes' THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- les archives ne portent pas la chronologie'; END IF;

  SELECT count(*) INTO v_n FROM public.justice_faits_publics;
  IF v_n <> 12 THEN RAISE EXCEPTION 'P7 ECHOUEE -- % fait(s) judiciaire(s) public(s), 12 attendus', v_n; END IF;

  SELECT count(*) INTO v_n FROM public.justice_faits_publics f
   WHERE NOT EXISTS (SELECT 1 FROM public.dossiers_judiciaires_actes_types t WHERE t.type = f.type_acte);
  IF v_n <> 0 THEN RAISE EXCEPTION 'P8 ECHOUEE -- un fait public nomme un acte inconnu'; END IF;

  SELECT count(*) INTO v_n FROM public.justice_faits_publics
   WHERE type_acte IN ('pv_audition', 'temoin_deposition', 'plainte_deposee',
                       'defense_constituee', 'defense_rompue', 'temoin_cite');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P9 ECHOUEE -- un acte du dossier est publie au Journal'; END IF;

  SELECT count(*) INTO v_n FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
   WHERE c.relname = 'dossiers_judiciaires_actes' AND NOT t.tgisinternal
     AND t.tgname = 'trg_dossiers_actes_chronique';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P10 ECHOUEE -- aucun declencheur ne publie les faits judiciaires'; END IF;

  SELECT public.sans_commentaires(prosrc) INTO v_txt FROM pg_proc
   WHERE pronamespace = 'public'::regnamespace AND proname = 'dossiers_actes_publier_au_journal';
  IF v_txt !~ 'justice_faits_publics' THEN
    RAISE EXCEPTION 'P11 ECHOUEE -- le declencheur devine au lieu de lire le registre'; END IF;
  IF v_txt ~ '''motif''|''auteur''|''plaignant''|declaration|dossiers_auditions' THEN
    RAISE EXCEPTION 'P12 ECHOUEE -- le Journal apprend le contenu du dossier'; END IF;
  IF v_txt ~ 'deepseek|openai|ia_|analyse_|evaluer_|noter_' THEN
    RAISE EXCEPTION 'P13 ECHOUEE -- une IA redige le fait judiciaire'; END IF;

  RAISE NOTICE 'LES 13 PREUVES SONT VERTES.';
END $preuves$;
