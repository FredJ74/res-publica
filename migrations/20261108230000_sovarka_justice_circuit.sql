-- Justice de Sovarka : bureau des magistrats et circuit sans procureur (décisions de Fred du 08/11/2026,
-- GAME-DESIGN-NOVOMIRSK.md, « Justice de Sovarka »). La Républia ne change pas : chaque garde est bornée
-- à country = 'soviet', les patchs en place sont posés sous empreinte.
--  1. Titulaires PNJ des trois villes (juge et commissaire) ; ils restent référents quand un PJ prend le poste.
--  2. Circuit : la plainte reste au registre du commissariat (statut historique « au_parquet ») ; le
--     commissaire de la ville ou le ministre de la Justice prolétarienne SAISIT le juge (statut « saisie »,
--     celui qu'attendent déjà audience et jugement) ou ENTERRE l'affaire (statut « enterree ») : elle n'est
--     jamais close, n'expire pas (justice_delais_echus ne connaît pas ce statut), n'apparaît pas au registre
--     du tribunal et peut toujours être transmise. L'enterrement laisse une trace « plainte_egaree » pour
--     les rumeurs, sans auteur nommé.
--  3. Consignes du ministre au juge (sévère, légère, relaxe, libre) jusqu'à la veille de l'audience ;
--     aucun effet automatique.
--  4. « Offrir un café » : le juge, à une ou plusieurs personnes présentes dans le bureau des magistrats ;
--     +10 moral, 1 PSK par café sur la caisse du tribunal, un café par jour et par bénéficiaire.
--  5. Acte officiel au greffe : pour soi 1 PA + 8 PSK (caisse du Tribunal Populaire) ; juge, commissaire et
--     ministre de la Justice pour n'importe qui, 1 PA sans frais. Plus d'acte au bureau des magistrats.
--  6. Extrait d'enregistrement du parti (salle des partis) : chef du parti, 1 PA + 7 PSK (caisse de la mairie).
--  7. Registre public du greffe de Sovarka : seules les affaires dont le juge est saisi.

-- 1. Titulaires PNJ (noms validés par Fred)
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj) VALUES
  ('soviet_juge_capitale',        'soviet', 'juge',        'capitale', 'Camarade Juge Pravdine (PNJ)'),
  ('soviet_commissaire_capitale', 'soviet', 'commissaire', 'capitale', 'Vassili Ostrovski (PNJ)'),
  ('soviet_juge_ville_a',         'soviet', 'juge',        'ville_a',  'Dulma Tsyrenova (PNJ)'),
  ('soviet_commissaire_ville_a',  'soviet', 'commissaire', 'ville_a',  'Bato Dashiev (PNJ)'),
  ('soviet_juge_ville_b',         'soviet', 'juge',        'ville_b',  'Anatoli Gromov (PNJ)'),
  ('soviet_commissaire_ville_b',  'soviet', 'commissaire', 'ville_b',  'Oleg Morozov (PNJ)')
ON CONFLICT (id) DO NOTHING;

-- 2. Tables propres
CREATE TABLE IF NOT EXISTS public.sovarka_consignes_ministre (
  affaire  text PRIMARY KEY,
  consigne text NOT NULL CHECK (consigne IN ('severe', 'legere', 'relaxe', 'libre')),
  ministre text NOT NULL,
  jour     integer NOT NULL,
  maj      timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.sovarka_consignes_ministre ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_consignes_ministre FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS public.sovarka_cafes_magistrat (
  jour         date NOT NULL,
  beneficiaire text NOT NULL,
  magistrat    text NOT NULL,
  requete      text NOT NULL,
  offert_le    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (jour, beneficiaire)
);
ALTER TABLE public.sovarka_cafes_magistrat ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_cafes_magistrat FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS public.sovarka_cafes_requetes (
  requete   text PRIMARY KEY,
  magistrat text NOT NULL,
  resultat  jsonb NOT NULL,
  cree_le   timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.sovarka_cafes_requetes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_cafes_requetes FROM PUBLIC, anon, authenticated;

-- 3. Qui agit dans la justice de Sovarka
CREATE OR REPLACE FUNCTION public.sovarka_justice_roles_interne(p_nom text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_ministre boolean; v_comm text; v_juge text;
BEGIN
  -- Les deux lectures de poste passent par l'utilisateur connecté (auth.uid) : p_nom est toujours
  -- mon_personnage(), et on revérifie qu'il s'agit bien de lui.
  v_ministre := public.sovarka_est_titulaire_interne(p_nom, 'min_just');
  SELECT coalesce(a.poste_city, 'capitale') INTO v_comm FROM public.acteur_poste_courant() a
   WHERE a.nom = p_nom AND a.poste_id = 'commissaire' AND a.pays = 'soviet';
  SELECT j.ville INTO v_juge FROM public.juge_moi() j WHERE j.nom = p_nom AND j.pays = 'soviet';
  RETURN jsonb_build_object('ministre', coalesce(v_ministre, false), 'commissaire_ville', v_comm, 'juge_ville', v_juge);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_justice_roles_interne(text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.sovarka_justice_acte_autorite_interne(p_nom text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.personnages_donnees d
                  WHERE d.name = p_nom AND d.country = 'soviet' AND (d.poste ->> 'id') IN ('juge', 'commissaire'))
      OR public.sovarka_est_titulaire_interne(p_nom, 'min_just');
$$;
REVOKE ALL ON FUNCTION public.sovarka_justice_acte_autorite_interne(text) FROM PUBLIC, anon, authenticated;

-- 4. Registre : le commissaire voit les plaintes de sa ville, le ministre toutes, le juge ses affaires saisies
CREATE OR REPLACE FUNCTION public.sovarka_justice_registre()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; v_r jsonb; v_min boolean; v_comm text; v_juge text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_r := public.sovarka_justice_roles_interne(v_moi);
  v_min := (v_r ->> 'ministre')::boolean;
  v_comm := v_r ->> 'commissaire_ville';
  v_juge := v_r ->> 'juge_ville';
  IF NOT v_min AND v_comm IS NULL AND v_juge IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_justice_sovarka');
  END IF;
  RETURN jsonb_build_object('ok', true, 'moi', v_moi, 'ministre', v_min,
    'commissaire_ville', v_comm, 'juge_ville', v_juge,
    'jour', coalesce(public.jour_de_jeu_pays('soviet'), 1),
    'affaires', (SELECT coalesce(jsonb_agg(jsonb_build_object(
        'id', p.id, 'ville', p.city,
        'cible', p.data::jsonb ->> 'cible', 'plaignant', p.data::jsonb ->> 'auteur',
        'motif', p.data::jsonb ->> 'motif', 'categorie', p.data::jsonb ->> 'categorie_alleguee',
        'jour', (p.data::jsonb ->> 'jour')::integer, 'statut', p.data::jsonb ->> 'status',
        'audience_jour', (p.data::jsonb ->> 'audience_jour')::integer,
        'audience_ouverte', public.affaire_audience_ouverte(p.data::jsonb),
        'juge', public.justice_juge_titulaire('soviet', p.city),
        'peut_decider', (v_min OR v_comm IS NOT DISTINCT FROM p.city)
                        AND (p.data::jsonb ->> 'status') IN ('au_parquet', 'enterree'),
        'consigne', CASE WHEN v_min OR v_juge IS NOT DISTINCT FROM p.city THEN c.consigne END)
        ORDER BY p.created_at), '[]'::jsonb)
      FROM public.plaintes_en_cours p
      LEFT JOIN public.sovarka_consignes_ministre c ON c.affaire = p.id
     WHERE p.country = 'soviet' AND p.data IS NOT NULL AND left(btrim(p.data), 1) = '{'
       AND (   (v_min AND (p.data::jsonb ->> 'status') IN ('au_parquet', 'enterree', 'saisie'))
            OR (v_comm IS NOT DISTINCT FROM p.city AND (p.data::jsonb ->> 'status') IN ('au_parquet', 'enterree', 'saisie'))
            OR (v_juge IS NOT DISTINCT FROM p.city AND (p.data::jsonb ->> 'status') = 'saisie'))));
END $$;
REVOKE ALL ON FUNCTION public.sovarka_justice_registre() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_justice_registre() TO authenticated;

-- 5. Saisir le juge ou enterrer l'affaire
CREATE OR REPLACE FUNCTION public.sovarka_justice_decider(p_affaire text, p_decision text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; v_r jsonb; v_min boolean; v_comm text; v_brut text; v_a jsonb; v_ville text; v_pays text;
        v_statut text; v_juge text; v_jour integer; v_qualite text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_decision NOT IN ('saisir', 'enterrer') THEN RETURN jsonb_build_object('ok', false, 'raison', 'decision_invalide'); END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  IF v_pays IS DISTINCT FROM 'soviet' THEN RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction'); END IF;
  v_a := v_brut::jsonb;
  v_statut := v_a ->> 'status';

  v_r := public.sovarka_justice_roles_interne(v_moi);
  v_min := (v_r ->> 'ministre')::boolean;
  v_comm := v_r ->> 'commissaire_ville';
  IF v_min THEN v_qualite := 'min_just';
  ELSIF v_comm IS NOT DISTINCT FROM v_ville AND v_comm IS NOT NULL THEN v_qualite := 'commissaire';
  ELSE RETURN jsonb_build_object('ok', false, 'raison', 'reserve_commissaire_ou_ministre'); END IF;

  IF p_decision = 'enterrer' AND v_statut IS DISTINCT FROM 'au_parquet' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'statut_incompatible', 'statut', v_statut); END IF;
  IF p_decision = 'saisir' AND v_statut NOT IN ('au_parquet', 'enterree') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'statut_incompatible', 'statut', v_statut); END IF;

  v_jour := coalesce(public.jour_de_jeu_pays('soviet'), 1);
  IF p_decision = 'saisir' THEN
    v_juge := public.justice_juge_titulaire('soviet', v_ville);
    IF v_juge IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_juge', 'ville', v_ville); END IF;
    UPDATE public.plaintes_en_cours
       SET data = ((v_a - 'enterree_le' - 'enterree_jour') || jsonb_build_object(
             'status', 'saisie', 'saisine_par', v_moi, 'saisine_qualite', v_qualite,
             'saisine_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text
     WHERE id = p_affaire;
    PERFORM public.dossier_acte_consigner(p_affaire, 'soviet', v_ville, 'juge_saisi', v_moi, v_qualite, NULL, NULL,
      jsonb_build_object('circuit', 'sovarka'));
    IF EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_juge) THEN
      PERFORM public.mail_systeme_envoyer('Système', v_juge, 'Tribunal Populaire : vous êtes saisi',
        'Une affaire contre ' || coalesce(v_a ->> 'cible', 'X') || ' vous est transmise. Elle vous attend au bureau des magistrats.');
    END IF;
    RETURN jsonb_build_object('ok', true, 'affaire', p_affaire, 'statut', 'saisie', 'juge', v_juge);
  END IF;

  -- Enterrer : l'affaire se « perd » au commissariat, sans rien dire de qui l'a perdue.
  UPDATE public.plaintes_en_cours
     SET data = (v_a || jsonb_build_object('status', 'enterree', 'enterree_jour', v_jour,
           'enterree_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text
   WHERE id = p_affaire;
  INSERT INTO public.actions_tracables (id, auteur, cible, type_action, country, city, jour, jour_expiration, decouvert)
  VALUES ('trace-plainte-egaree-' || p_affaire, 'Le commissariat', v_a ->> 'cible', 'plainte_egaree',
          'soviet', v_ville, v_jour, v_jour + 7, true)
  ON CONFLICT (id) DO NOTHING;
  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire, 'statut', 'enterree');
END $$;
REVOKE ALL ON FUNCTION public.sovarka_justice_decider(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_justice_decider(text, text) TO authenticated;

-- 6. Consignes du ministre au juge
CREATE OR REPLACE FUNCTION public.sovarka_consigne_envoyer(p_affaire text, p_consigne text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; v_brut text; v_a jsonb; v_ville text; v_pays text; v_jour integer; v_juge text; v_lib text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT public.sovarka_est_titulaire_interne(v_moi, 'min_just') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_ministre_justice'); END IF;
  IF p_consigne NOT IN ('severe', 'legere', 'relaxe', 'libre') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'consigne_invalide'); END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  IF v_pays IS DISTINCT FROM 'soviet' THEN RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction'); END IF;
  v_a := v_brut::jsonb;
  IF (v_a ->> 'status') NOT IN ('au_parquet', 'enterree', 'saisie') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'statut_incompatible', 'statut', v_a ->> 'status'); END IF;
  v_jour := coalesce(public.jour_de_jeu_pays('soviet'), 1);
  -- Jusqu'à la veille du procès : le jour de l'audience, ou une fois l'audience ouverte, c'est trop tard.
  IF public.affaire_audience_ouverte(v_a)
     OR ((v_a ->> 'audience_jour') IS NOT NULL AND v_jour >= (v_a ->> 'audience_jour')::integer) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'proces_trop_proche',
                              'audience_jour', (v_a ->> 'audience_jour')::integer); END IF;

  INSERT INTO public.sovarka_consignes_ministre (affaire, consigne, ministre, jour, maj)
  VALUES (p_affaire, p_consigne, v_moi, v_jour, now())
  ON CONFLICT (affaire) DO UPDATE SET consigne = EXCLUDED.consigne, ministre = EXCLUDED.ministre,
                                      jour = EXCLUDED.jour, maj = now();

  v_juge := public.justice_juge_titulaire('soviet', v_ville);
  v_lib := CASE p_consigne WHEN 'severe' THEN 'condamner sévèrement' WHEN 'legere' THEN 'condamner légèrement'
                           WHEN 'relaxe' THEN 'relaxer' ELSE 'libre à vous' END;
  IF (v_a ->> 'status') = 'saisie' AND EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_juge) THEN
    PERFORM public.mail_systeme_envoyer('Système', v_juge, 'Ordres du ministre de la Justice prolétarienne',
      'Affaire contre ' || coalesce(v_a ->> 'cible', 'X') || ' : « ' || v_lib || ' ». Vous restez libre de votre jugement.');
  END IF;
  RETURN jsonb_build_object('ok', true, 'affaire', p_affaire, 'consigne', p_consigne);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_consigne_envoyer(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_consigne_envoyer(text, text) TO authenticated;

-- 7. Offrir un café (le juge, dans le bureau des magistrats)
CREATE OR REPLACE FUNCTION public.sovarka_offrir_cafe(p_requete text, p_beneficiaires text[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date; v_j record; v_f record;
        v_benef text[]; v_n integer; v_presents integer; v_deja text[]; v_caisse text; v_flag text; v_rep jsonb;
        v_res jsonb; v_b text; v_prec record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(p_requete), '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_absente'); END IF;
  SELECT * INTO v_prec FROM public.sovarka_cafes_requetes WHERE requete = p_requete;
  IF FOUND THEN
    IF v_prec.magistrat = v_moi THEN RETURN v_prec.resultat || '{"rejeu":true}'; END IF;
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide');
  END IF;

  SELECT * INTO v_j FROM public.juge_moi() WHERE pays = 'soviet';
  IF v_j.nom IS NULL OR v_j.nom IS DISTINCT FROM v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_juge'); END IF;
  SELECT country, current_city, current_building, current_room INTO v_f
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_f.country IS DISTINCT FROM 'soviet' OR v_f.current_city IS DISTINCT FROM v_j.ville
     OR v_f.current_building IS DISTINCT FROM public.parquet_site_competent('soviet', v_j.ville)
     OR v_f.current_room IS DISTINCT FROM 'bureau_magistrats' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_au_bureau_des_magistrats'); END IF;

  SELECT coalesce(array_agg(DISTINCT n ORDER BY n), '{}') INTO v_benef
    FROM (SELECT nullif(btrim(x), '') AS n FROM unnest(coalesce(p_beneficiaires, '{}'::text[])) x) t WHERE n IS NOT NULL;
  v_n := coalesce(array_length(v_benef, 1), 0);
  IF v_n = 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_beneficiaire'); END IF;
  IF v_moi = ANY (v_benef) THEN RETURN jsonb_build_object('ok', false, 'raison', 'beneficiaire_invalide'); END IF;
  SELECT count(*) INTO v_presents FROM (
    SELECT 1 FROM public.personnages_donnees
     WHERE name = ANY (v_benef) AND country = 'soviet' AND current_city = v_f.current_city
       AND current_building = v_f.current_building AND current_room = 'bureau_magistrats'
     FOR UPDATE) t;
  IF v_presents <> v_n THEN RETURN jsonb_build_object('ok', false, 'raison', 'beneficiaire_absent'); END IF;

  PERFORM pg_advisory_xact_lock(hashtext('sovarka_cafe|' || v_jour::text));
  SELECT coalesce(array_agg(beneficiaire ORDER BY beneficiaire), '{}') INTO v_deja
    FROM public.sovarka_cafes_magistrat WHERE jour = v_jour AND beneficiaire = ANY (v_benef);
  IF coalesce(array_length(v_deja, 1), 0) > 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_servi_aujourdhui', 'beneficiaires', to_jsonb(v_deja)); END IF;

  v_caisse := 'soviet_tribunal_' || v_j.ville;
  v_flag := current_setting('rp.caisse_interne', true);
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_rep := public.caisse_institution_mouvement(v_caisse, -v_n, true);
  PERFORM set_config('rp.caisse_interne', coalesce(v_flag, ''), true);
  IF (v_rep ->> 'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'cout', v_n); END IF;

  FOREACH v_b IN ARRAY v_benef LOOP
    PERFORM public.jauges_effet_appliquer_interne(v_b, 0, 0, 10);
    INSERT INTO public.sovarka_cafes_magistrat (jour, beneficiaire, magistrat, requete) VALUES (v_jour, v_b, v_moi, p_requete);
    PERFORM public.mail_systeme_envoyer('Système', v_b, 'Un café au Tribunal Populaire',
      v_moi || ', juge, vous a offert un café dans le bureau des magistrats (+10 Moral).');
  END LOOP;
  v_res := jsonb_build_object('ok', true, 'beneficiaires', to_jsonb(v_benef), 'cout', v_n, 'caisse', v_caisse);
  INSERT INTO public.sovarka_cafes_requetes (requete, magistrat, resultat) VALUES (p_requete, v_moi, v_res);
  RETURN v_res;
END $$;
REVOKE ALL ON FUNCTION public.sovarka_offrir_cafe(text, text[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_offrir_cafe(text, text[]) TO authenticated;

-- 8. Extrait d'enregistrement du parti (salle des partis)
CREATE OR REPLACE FUNCTION public.sovarka_parti_extrait()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; v_f record; v_parti text; v_o jsonb; v_caisse text; v_paye jsonb; v_jour integer;
        v_contenu jsonb; v_doc jsonb; v_membres jsonb; v_villes jsonb := '{"capitale":"Novomirsk","ville_a":"Starovka","ville_b":"Krasnov"}';
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room, coalesce(inventory, '[]'::jsonb) AS inv INTO v_f
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_f.country IS DISTINCT FROM 'soviet' OR v_f.current_room IS DISTINCT FROM 'salle_partis'
     OR v_f.current_building NOT IN ('mairie', 'mairie-capitale') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'salle_des_partis_requise'); END IF;
  v_parti := public.sovarka_parti_de(v_moi);
  IF v_parti IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_chef'); END IF;
  SELECT data::jsonb INTO v_o FROM public.organisations WHERE id = v_parti;
  IF v_o ->> 'chef' IS DISTINCT FROM v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_chef'); END IF;
  IF public.inventaire_place_restante(v_f.inv) < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;

  v_caisse := CASE WHEN v_f.current_city = 'capitale' THEN 'soviet_mairie-capitale' ELSE 'soviet_mairie_' || v_f.current_city END;
  IF NOT EXISTS (SELECT 1 FROM public.caisses_batiments WHERE id = v_caisse) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_de_la_mairie_introuvable'); END IF;

  v_paye := public.payer_ordre(v_moi, 'sovarka_extrait_parti', 1, 7);
  IF coalesce((v_paye ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paye; END IF;
  PERFORM public.caisse_institution_mouvement(v_caisse, 7, true);

  v_jour := coalesce(public.jour_de_jeu_pays('soviet'), 1);
  SELECT coalesce(jsonb_agg(m ->> 'nom' ORDER BY m ->> 'nom'), '[]'::jsonb) INTO v_membres
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(v_o -> 'membres') = 'array' THEN v_o -> 'membres' ELSE '[]'::jsonb END) m
   WHERE nullif(m ->> 'nom', '') IS NOT NULL;
  v_contenu := jsonb_build_object('organisation', v_parti, 'nom', v_o ->> 'nom', 'type', 'politique',
    'pays', 'soviet', 'chef', v_o ->> 'chef', 'siege', v_o ->> 'city',
    'siege_libelle', coalesce(v_villes ->> (v_o ->> 'city'), v_o ->> 'city'),
    'membres', v_membres, 'enregistrement', true, 'frais', 7);
  v_doc := public.document_officiel_emettre(
    'domiciliation_extrait', 'domiciliation_extrait', true,
    'soviet', v_f.current_city, NULL, v_parti, NULL, v_moi, v_moi, v_jour,
    'Extrait d''enregistrement du parti — ' || coalesce(v_o ->> 'nom', v_parti),
    'Délivré par la salle des partis au jour ' || v_jour || '. Chef : ' || coalesce(v_o ->> 'chef', '?')
      || ' ; siège : ' || coalesce(v_villes ->> (v_o ->> 'city'), v_o ->> 'city', '?')
      || ' ; membres : ' || coalesce((SELECT string_agg(x, ', ') FROM jsonb_array_elements_text(v_membres) x), 'aucun')
      || '. Document FIGÉ à sa date.',
    'ti-flag', v_contenu, jsonb_build_object('motif', 'enregistrement_parti'));
  IF coalesce((v_doc ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'sovarka_parti_extrait : emission refusee (%)', v_doc ->> 'raison'; END IF;
  RETURN jsonb_build_object('ok', true, 'document', v_doc ->> 'document', 'parti', v_o ->> 'nom', 'jour', v_jour,
    'pa', (v_paye ->> 'pa')::integer, 'liquide', (v_paye ->> 'liquide')::numeric, 'arg', (v_paye ->> 'arg')::numeric);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_parti_extrait() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_parti_extrait() TO authenticated;

-- 9. Coûts déclarés
INSERT INTO public.ordres_couts (fn, pa, cost) VALUES
  ('sovarka_acte_officiel', 1, 8), ('sovarka_acte_officiel_autorite', 1, 0), ('sovarka_extrait_parti', 1, 7)
ON CONFLICT DO NOTHING;

-- 10. Patchs en place sous empreinte
DO $patch$
DECLARE r record; v_def text; i integer;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('public.etat_civil_document_recevoir(uuid,text,text,text,integer,integer)', 'b21eac63c48ff9c7f53e35df6adb098f',
     'justice_sovarka_acte_greffe_v1',
     ARRAY[E'  ELSIF a.current_building IN(''tribunal'',''tribunal-local'') AND a.current_room=''bureau_magistrats''\n',
           E' v:=public.inventaire_deposer_interne(a.name,o);\n'],
     ARRAY[E'  ELSIF a.country=''soviet'' AND a.current_building IN(''tribunal'',''tribunal-local'') AND a.current_room=''greffe'' THEN -- justice_sovarka_acte_greffe_v1 (Fred, 08/11/2026)\n'
           || E'   IF p_cost IS NOT DISTINCT FROM 0 THEN\n'
           || E'    IF NOT public.sovarka_justice_acte_autorite_interne(a.name) THEN RETURN jsonb_build_object(''ok'',false,''raison'',''reserve_autorites_sovarka'');END IF;\n'
           || E'    ordre:=''sovarka_acte_officiel_autorite'';cout:=0;\n'
           || E'   ELSIF p_nom=a.name THEN ordre:=''sovarka_acte_officiel'';cout:=8;\n'
           || E'   ELSE RETURN jsonb_build_object(''ok'',false,''raison'',''acte_pour_soi_seulement'');END IF;\n'
           || E'  ELSIF a.country IS DISTINCT FROM ''soviet'' AND a.current_building IN(''tribunal'',''tribunal-local'') AND a.current_room=''bureau_magistrats''\n',
           E' IF ordre=''sovarka_acte_officiel'' THEN PERFORM public.caisse_institution_mouvement(''soviet_tribunal_''||a.current_city,8,true);END IF; -- 8 PSK au Tribunal Populaire\n'
           || E' v:=public.inventaire_deposer_interne(a.name,o);\n']),
    ('public.rumeur_ecoute_jauges_interne(text)', '2ed52ab1f8aea1fc11fe7cf8e1bea27a', 'justice_sovarka_rumeur_v1',
     ARRAY['''fausse_rumeur'',''presence_suspecte''])THEN'],
     ARRAY['''fausse_rumeur'',''presence_suspecte'',''plainte_egaree''/* justice_sovarka_rumeur_v1 */])THEN']),
    ('public.justice_affaires_publiques()', 'de321a60a0216f16b05e8d1dadbc3b0e', 'justice_sovarka_registre_v1',
     ARRAY[E'           (''au_parquet'', ''enquete'', ''poursuites'', ''saisie'', ''abandon_demande'')),\n'],
     ARRAY[E'           (''au_parquet'', ''enquete'', ''poursuites'', ''saisie'', ''abandon_demande'')\n'
           || E'       -- justice_sovarka_registre_v1 : en Sovarka, le registre du tribunal ne connaît que les affaires dont le juge est saisi.\n'
           || E'       AND (v_pays IS DISTINCT FROM ''soviet'' OR (p.data::jsonb) ->> ''status'' = ''saisie'')),\n'])
  ) AS t(fn, empreinte, marque, ancres, remplaces) LOOP
    v_def := pg_get_functiondef(r.fn::regprocedure);
    CONTINUE WHEN strpos(v_def, r.marque) > 0;
    IF md5(v_def) <> r.empreinte THEN RAISE EXCEPTION 'empreinte_inattendue: %', r.fn; END IF;
    FOR i IN 1 .. array_length(r.ancres, 1) LOOP
      IF (length(v_def) - length(replace(v_def, r.ancres[i], ''))) / length(r.ancres[i]) <> 1 THEN
        RAISE EXCEPTION 'ancre_non_unique: % (%)', r.fn, i; END IF;
      v_def := replace(v_def, r.ancres[i], r.remplaces[i]);
    END LOOP;
    EXECUTE v_def;
  END LOOP;
END $patch$;

-- 11. Contrôles structurels
DO $v$ BEGIN
  IF strpos(pg_get_functiondef('public.etat_civil_document_recevoir(uuid,text,text,text,integer,integer)'::regprocedure), 'justice_sovarka_acte_greffe_v1') = 0
     OR strpos(pg_get_functiondef('public.rumeur_ecoute_jauges_interne(text)'::regprocedure), 'justice_sovarka_rumeur_v1') = 0
     OR strpos(pg_get_functiondef('public.justice_affaires_publiques()'::regprocedure), 'justice_sovarka_registre_v1') = 0 THEN
    RAISE EXCEPTION 'patch_incomplet'; END IF;
  IF (SELECT count(*) FROM public.titulaires_pnj WHERE country = 'soviet' AND poste_id IN ('juge', 'commissaire')) < 6 THEN
    RAISE EXCEPTION 'titulaires_incomplets'; END IF;
  IF (SELECT count(*) FROM public.ordres_couts WHERE (fn, pa, cost) IN
        (('sovarka_acte_officiel', 1, 8), ('sovarka_acte_officiel_autorite', 1, 0), ('sovarka_extrait_parti', 1, 7))) <> 3 THEN
    RAISE EXCEPTION 'couts_absents'; END IF;
  IF has_function_privilege('anon', 'public.sovarka_justice_decider(text,text)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.sovarka_justice_roles_interne(text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'droits_incorrects'; END IF;
END $v$;
