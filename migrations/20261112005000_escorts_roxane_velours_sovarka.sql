-- Pavillon des Ambassadeurs et Résidence impériale de Novomirsk : service d'étage, « Appel à un(e) escort »,
-- rumeur et presse, espionnage (décisions de Fred, 12/11/2026, 0 h 41 – 1 h 23, GAME-DESIGN-NOVOMIRSK.md).
--  1. Service d'étage dans les suites louées du Pavillon et les appartements loués de la Résidence : carte du
--     restaurant du Grand Hôtel de Sovarka à son prix, + 20 PSK de service par commande, mêmes effets qu'au restaurant.
--  2. « Appel à un(e) escort » (locataire seul, dans sa pièce) : standard de l'agence internationale Roxane Velours.
--     Le serveur lit la demande libre (nombre et genres), choisit les escorts du catalogue, encaisse nombre × 800
--     et les embauche exactement comme l'agence de Républia (paie quotidienne, renvoi par le PJ). La validation
--     pose la trace « appel_escort ».
--  3. Rumeur : chaque écoute de cette trace coûte 3 POP au dignitaire ; à la 3e écoute, projet d'article au
--     ministre de l'Intérieur de Sovarka et à celui du pays du dignitaire (journalistes PNJ) ; validation ou
--     attente ; ministre PNJ : tirage à 50 %.
--  4. Espionnage : les secrets confiés aux escorts en Sovarka vont au ministre de la Sécurité du Peuple ; une fois
--     par nuit, 25 % de chances qu'un escort copie un dossier de l'ordinateur du locataire pour ce même ministre.
-- Idempotente.
BEGIN;

-- 1. Tables (serveur seul).
CREATE TABLE IF NOT EXISTS public.escort_appels (
  id bigserial PRIMARY KEY, requete uuid NOT NULL UNIQUE, appelant text NOT NULL, batiment text NOT NULL, piece text NOT NULL,
  escorts jsonb NOT NULL DEFAULT '[]'::jsonb, montant integer NOT NULL DEFAULT 0, trace_id text, reponse jsonb,
  cree_le timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.escort_scandales (
  trace_id text PRIMARY KEY, appel_id bigint, dignitaire text NOT NULL, pays_dignitaire text, poste_id text, poste_libelle text,
  lieu text NOT NULL, ecoutes integer NOT NULL DEFAULT 0, journalistes_prevenus boolean NOT NULL DEFAULT false,
  cree_le timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.interieur_dossiers (
  id bigserial PRIMARY KEY, pays text NOT NULL,
  type text NOT NULL CHECK (type IN ('projet_article', 'secret_escort', 'dossier_pirate')),
  cible text, titre text NOT NULL, contenu text NOT NULL, donnees jsonb NOT NULL DEFAULT '{}'::jsonb,
  statut text NOT NULL DEFAULT 'nouveau' CHECK (statut IN ('nouveau', 'lu', 'en_attente', 'publie')),
  decide_par text, decide_le timestamptz, cree_le timestamptz NOT NULL DEFAULT now());
CREATE INDEX IF NOT EXISTS interieur_dossiers_pays_cree ON public.interieur_dossiers (pays, cree_le DESC);
CREATE TABLE IF NOT EXISTS public.escort_piratages_nuits (nom text NOT NULL, jour date NOT NULL, PRIMARY KEY (nom, jour));
CREATE TABLE IF NOT EXISTS public.service_etage_commandes (
  requete uuid PRIMARY KEY, acteur text NOT NULL, produit text NOT NULL, reponse jsonb NOT NULL, cree_le timestamptz NOT NULL DEFAULT now());
ALTER TABLE public.escort_appels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.escort_scandales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.interieur_dossiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.escort_piratages_nuits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_etage_commandes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.escort_appels, public.escort_scandales, public.interieur_dossiers, public.escort_piratages_nuits,
  public.service_etage_commandes FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.escort_appels_id_seq, public.interieur_dossiers_id_seq FROM PUBLIC, anon, authenticated;

-- 2. Lieu loué : le locataire dans sa suite du Pavillon ou dans son appartement de la Résidence.
CREATE OR REPLACE FUNCTION public.escort_lieu_locataire_interne(p_nom text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE d record; j date := (now() AT TIME ZONE 'Europe/Paris')::date;
BEGIN
  SELECT country, current_city, current_building, current_room INTO d FROM public.personnages_donnees WHERE name = p_nom;
  IF NOT FOUND OR d.country IS DISTINCT FROM 'soviet' OR d.current_city IS DISTINCT FROM 'capitale' THEN RETURN NULL; END IF;
  IF d.current_building = 'pavillon-ambassadeurs-novomirsk'
     AND d.current_room IN ('suite_privee', 'suite_presidentielle', 'suite_parti')
     AND EXISTS (SELECT 1 FROM public.pavillon_baux pb WHERE pb.piece = d.current_room AND pb.locataire = p_nom
                   AND pb.statut = 'actif' AND pb.debut <= j AND pb.fin_excl > j) THEN
    RETURN jsonb_build_object('batiment', d.current_building, 'piece', d.current_room, 'lieu', 'pavillon');
  END IF;
  IF d.current_building = 'residence-imperiale-novomirsk'
     AND EXISTS (SELECT 1 FROM public.residence_locations l WHERE l.locataire = p_nom AND l.piece = d.current_room AND l.fin > now()) THEN
    RETURN jsonb_build_object('batiment', d.current_building, 'piece', d.current_room, 'lieu', 'residence');
  END IF;
  RETURN NULL;
END $$;
REVOKE ALL ON FUNCTION public.escort_lieu_locataire_interne(text) FROM PUBLIC, anon, authenticated;

-- Poste du dignitaire : pays du poste (registre), intitulé propre à Sovarka le cas échéant.
CREATE OR REPLACE FUNCTION public.escort_dignitaire_interne(p_nom text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_pays text; v_poste text; v_nom_poste text;
BEGIN
  SELECT a.country, a.poste_id INTO v_pays, v_poste FROM public.postes_attribues a
    JOIN public.personnages_donnees d ON d.name = a.titulaire AND d.poste->>'id' = a.poste_id
   WHERE a.titulaire = p_nom ORDER BY a.updated_at DESC NULLS LAST LIMIT 1;
  SELECT CASE WHEN jsonb_typeof(poste) = 'object' THEN poste->>'name' END, coalesce(v_poste, CASE WHEN jsonb_typeof(poste) = 'object' THEN poste->>'id' END)
    INTO v_nom_poste, v_poste FROM public.personnages_donnees WHERE name = p_nom;
  RETURN jsonb_build_object('pays', v_pays, 'poste_id', v_poste, 'libelle',
    CASE WHEN v_pays = 'soviet' THEN coalesce(CASE v_poste
           WHEN 'president' THEN 'Président de la République de Sovarka' WHEN 'pm' THEN 'Président du Conseil du Peuple'
           WHEN 'min_int' THEN 'Ministre de la Sécurité du Peuple' WHEN 'min_fin' THEN 'Ministre de l''Économie collective'
           WHEN 'min_just' THEN 'Ministre de la Justice prolétarienne' WHEN 'min_def' THEN 'Ministre de la Défense de la Patrie'
           WHEN 'min_info' THEN 'Ministre de la Vérité officielle' WHEN 'min_ae' THEN 'Ministre de l''Amitié entre les Peuples'
           WHEN 'depute' THEN 'Député du Soviet Suprême' END, v_nom_poste)
         ELSE v_nom_poste END);
END $$;
REVOKE ALL ON FUNCTION public.escort_dignitaire_interne(text) FROM PUBLIC, anon, authenticated;

-- Ministre de l'Intérieur PJ d'un pays (NULL si le poste est tenu par un PNJ).
CREATE OR REPLACE FUNCTION public.interieur_ministre_pj_interne(p_pays text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT a.titulaire FROM public.postes_attribues a
    JOIN public.personnages_donnees d ON d.name = a.titulaire AND d.poste->>'id' = a.poste_id
   WHERE a.country = p_pays AND a.poste_id = 'min_int' ORDER BY a.updated_at DESC NULLS LAST LIMIT 1 $$;
REVOKE ALL ON FUNCTION public.interieur_ministre_pj_interne(text) FROM PUBLIC, anon, authenticated;

-- 3. Lecture de la demande libre faite à Rebecca : nombre et genres seulement (neuf langues, chiffres compris).
CREATE OR REPLACE FUNCTION public.escort_demande_analyser(p_texte text)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path TO 'public', 'pg_temp' AS $$
DECLARE
  t text := ' ' || lower(coalesce(left(p_texte, 400), '')) || ' ';
  c_num constant text := '(\d+|\mune?\M|\muno\M|\muna\M|\meine?[nr]?\M|\muma?\M|\ma\M|\man\M|\mone\M|\mdeux\M|\mtwo\M|\mdos\M|\mzwei\M|\mdois\M|\mduas\M'
    || '|\mtrois\M|\mthree\M|\mtres\M|\mtrês\M|\mdrei\M|\mquatre\M|\mfour\M|\mcuatro\M|\mquatro\M|\mvier\M|\mcinq\M|\mfive\M|\mcinco\M|\mfünf\M'
    || '|один|одна|одну|два|две|двух|три|трёх|трех|четыре|пять|한|하나|두|둘|세|셋|네|넷|다섯|一|二|兩|两|三|四|五'
    || '|واحدة|واحد|اثنتين|اثنين|ثلاث|أربع|خمس)';
  c_f constant text := '(femmes?|filles?|\mdames?|demoiselles?|escortes|hôtesses?|wom[ae]n|girls?|lad(y|ies)|mujer(es)?|chicas?|señoritas?'
    || '|frau(en)?|mädchen|mulher(es)?|garotas?|moças?|женщин\w*|девушк\w*|дам\w*|여자|여성|아가씨|女|小姐|امرأة|نساء|فتاة|فتيات)';
  c_h constant text := '(hommes?|garçons?|garcons?|messieurs|monsieur|gigolos?|\mm[ae]n\M|guys?|boys?|gentlem[ae]n|hombres?|chicos?|caballeros?'
    || '|männer|\mmann\M|herren|homem|homens|rapaz(es)?|мужчин\w*|парн\w*|парня|джентльмен\w*|남자|남성|男|先生|رجل|رجال|شاب)';
  m text[]; f integer := 0; h integer := 0; n integer; v_imprecis boolean := false;
BEGIN
  FOR m IN SELECT regexp_matches(t, c_num || '?\s*[個个位名]?\s*' || c_f, 'g') LOOP
    f := f + public.escort_nombre_interne(m[1]);
  END LOOP;
  FOR m IN SELECT regexp_matches(t, c_num || '?\s*[個个位名]?\s*' || c_h, 'g') LOOP
    h := h + public.escort_nombre_interne(m[1]);
  END LOOP;
  -- « deux jolies femmes » : un mot entre le nombre et le genre (le genre seul a déjà compté pour 1).
  FOR m IN SELECT regexp_matches(t, c_num || '\s+[a-zà-ÿа-яё]{2,15}\s+' || c_f, 'g') LOOP f := f + public.escort_nombre_interne(m[1]) - 1; END LOOP;
  FOR m IN SELECT regexp_matches(t, c_num || '\s+[a-zà-ÿа-яё]{2,15}\s+' || c_h, 'g') LOOP h := h + public.escort_nombre_interne(m[1]) - 1; END LOOP;
  -- Coréen : le nombre suit le nom (« 여자 두 명 »).
  FOR m IN SELECT regexp_matches(t, '(여자|여성|아가씨)\s*(\d+|한|두|세|네|다섯)\s*명', 'g') LOOP f := f + public.escort_nombre_interne(m[2]) - 1; END LOOP;
  FOR m IN SELECT regexp_matches(t, '(남자|남성)\s*(\d+|한|두|세|네|다섯)\s*명', 'g') LOOP h := h + public.escort_nombre_interne(m[2]) - 1; END LOOP;
  -- « une escort » / « un escort » : l'article dit le genre (français, espagnol, allemand, portugais).
  f := f + (SELECT count(*) FROM regexp_matches(t, '\m(une|una|eine|uma)\s+escort(e)?\M', 'g'));
  h := h + (SELECT count(*) FROM regexp_matches(t, '\m(un|uno|ein|einen|um)\s+escort\M', 'g'));
  IF f = 0 AND h = 0 THEN
    IF t ~ '(les deux|\mboth\M|ambos|ambas|beide|\mоба\M|\mобе\M|둘 다|兩個|两个|兩位|两位|كلاهما|os dois|as duas|los dos|las dos)' THEN
      f := 1; h := 1;
    ELSIF t ~ '(escort|эскорт|에스코트|伴遊|伴游|مرافق)' THEN v_imprecis := true;
    END IF;
  END IF;
  RETURN jsonb_build_object('femmes', least(f, 10), 'hommes', least(h, 10), 'genre_imprecis', v_imprecis);
END $$;

CREATE OR REPLACE FUNCTION public.escort_nombre_interne(p text)
RETURNS integer LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE
    WHEN p IS NULL OR p = '' THEN 1
    WHEN p ~ '^\d+$' THEN least(10, greatest(0, p::integer))
    WHEN p IN ('deux','two','dos','zwei','dois','duas','два','две','двух','두','둘','二','兩','两','اثنين','اثنتين') THEN 2
    WHEN p IN ('trois','three','tres','três','drei','три','трёх','трех','세','셋','三','ثلاث') THEN 3
    WHEN p IN ('quatre','four','cuatro','quatro','vier','четыре','네','넷','四','أربع') THEN 4
    WHEN p IN ('cinq','five','cinco','fünf','пять','다섯','五','خمس') THEN 5
    ELSE 1 END $$;

-- Escorts disponibles pour cet appelant : catalogue de l'agence internationale, hors celles déjà à son service.
CREATE OR REPLACE FUNCTION public.escort_disponibles_interne(p_nom text, p_genre text)
RETURNS SETOF public.escorts_catalogue LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT c.* FROM public.escorts_catalogue c
   WHERE c.actif AND c.pays = 'republic' AND c.genre = p_genre
     AND NOT EXISTS (SELECT 1 FROM public.pnj_membres m WHERE m.id = public.employe_pnj_id(p_nom, 'escort', c.escort_id) AND m.statut = 'actif') $$;
REVOKE ALL ON FUNCTION public.escort_disponibles_interne(text, text) FROM PUBLIC, anon, authenticated;

-- 4. Le standard : devis (aucune écriture) puis validation.
CREATE OR REPLACE FUNCTION public.escort_standard_devis(p_texte text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE moi text := public.mon_personnage(); v jsonb; f integer; h integer; v_prix integer; v_place integer;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF public.escort_lieu_locataire_interne(moi) IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_locataire'); END IF;
  v := public.escort_demande_analyser(p_texte);
  IF (v->>'genre_imprecis')::boolean THEN RETURN jsonb_build_object('ok', false, 'raison', 'genre_imprecis'); END IF;
  f := least((v->>'femmes')::integer, (SELECT count(*) FROM public.escort_disponibles_interne(moi, 'F'))::integer);
  h := least((v->>'hommes')::integer, (SELECT count(*) FROM public.escort_disponibles_interne(moi, 'H'))::integer);
  IF (v->>'femmes')::integer + (v->>'hommes')::integer = 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'demande_incomprise'); END IF;
  v_place := 10 - (SELECT count(*) FROM public.pnj_membres m WHERE m.famille = 'employe' AND m.proprietaire_pj = moi AND m.statut = 'actif')::integer;
  IF f + h > v_place THEN h := greatest(0, least(h, v_place - f)); f := greatest(0, least(f, v_place)); END IF;
  IF f + h = 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'agence_complete'); END IF;
  SELECT cout_initial INTO v_prix FROM public.pnj_metiers_profils WHERE metier = 'escort';
  RETURN jsonb_build_object('ok', true, 'femmes', f, 'hommes', h, 'nombre', f + h, 'prix', v_prix, 'montant', (f + h) * v_prix);
END $$;
REVOKE ALL ON FUNCTION public.escort_standard_devis(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.escort_standard_devis(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.escort_standard_valider(p_requete uuid, p_femmes integer, p_hommes integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE moi text := public.mon_personnage(); v_lieu jsonb; v_prof public.pnj_metiers_profils%ROWTYPE; v_ancien jsonb;
  v_place integer; v_total integer; v_pay jsonb; c record; v_id text; v_liste jsonb := '[]'::jsonb; v_dig jsonb;
  v_trace text; v_appel bigint; v_rep jsonb; v_pays text; f integer := greatest(0, coalesce(p_femmes, 0)); h integer := greatest(0, coalesce(p_hommes, 0));
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_requise'); END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('escort_standard:' || moi, 0));
  SELECT reponse INTO v_ancien FROM public.escort_appels WHERE requete = p_requete AND appelant = moi;
  IF v_ancien IS NOT NULL THEN RETURN v_ancien || jsonb_build_object('rejeu', true); END IF;
  v_lieu := public.escort_lieu_locataire_interne(moi);
  IF v_lieu IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_locataire'); END IF;
  SELECT * INTO v_prof FROM public.pnj_metiers_profils WHERE metier = 'escort';
  IF v_prof.metier IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'profil_metier_absent'); END IF;
  f := least(f, (SELECT count(*) FROM public.escort_disponibles_interne(moi, 'F'))::integer);
  h := least(h, (SELECT count(*) FROM public.escort_disponibles_interne(moi, 'H'))::integer);
  v_place := 10 - (SELECT count(*) FROM public.pnj_membres m WHERE m.famille = 'employe' AND m.proprietaire_pj = moi AND m.statut = 'actif')::integer;
  IF f + h > v_place THEN h := greatest(0, least(h, v_place - f)); f := greatest(0, least(f, v_place)); END IF;
  IF f + h = 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'agence_complete'); END IF;
  v_total := (f + h) * v_prof.cout_initial;
  v_pay := public.debiter_fonds_ordinaires(moi, v_total);
  IF coalesce((v_pay->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'montant', v_total); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = moi;
  -- Même embauche que escort_recruter (agence de Républia) : employé, groupe, paie quotidienne.
  FOR c IN (SELECT * FROM (SELECT * FROM public.escort_disponibles_interne(moi, 'F') ORDER BY random() LIMIT f) x
            UNION ALL SELECT * FROM (SELECT * FROM public.escort_disponibles_interne(moi, 'H') ORDER BY random() LIMIT h) y) LOOP
    v_id := public.employe_pnj_id(moi, 'escort', c.escort_id);
    INSERT INTO public.pnj_membres (id, famille, classe, nom, pays, proprietaire_pj, leader_pj, pa, statut,
                                    car_int, car_cha, car_vol, car_per, car_dup, car_ent)
    VALUES (v_id, 'employe', 'beta', c.nom, v_pays, moi, moi, 12, 'actif',
            v_prof.car_int, v_prof.car_cha, v_prof.car_vol, v_prof.car_per, v_prof.car_dup, v_prof.car_ent)
    ON CONFLICT (id) DO UPDATE SET statut = 'actif', nom = EXCLUDED.nom, proprietaire_pj = EXCLUDED.proprietaire_pj,
      leader_pj = EXCLUDED.leader_pj, leader_pnj_id = NULL, ville = NULL, building_id = NULL, room_id = NULL, rue_noeud_id = NULL,
      car_int = EXCLUDED.car_int, car_cha = EXCLUDED.car_cha, car_vol = EXCLUDED.car_vol,
      car_per = EXCLUDED.car_per, car_dup = EXCLUDED.car_dup, car_ent = EXCLUDED.car_ent, maj_le = now();
    INSERT INTO public.pnj_employes_metier (pnj_id, job, role_libelle, cout_jour, genre, escort_id, depuis_jour)
    VALUES (v_id, 'escort', 'Escort — Agence Roxane Velours', v_prof.cout_jour, c.genre, c.escort_id, NULL)
    ON CONFLICT (pnj_id) DO UPDATE SET job = EXCLUDED.job, role_libelle = EXCLUDED.role_libelle,
      cout_jour = EXCLUDED.cout_jour, genre = EXCLUDED.genre, escort_id = EXCLUDED.escort_id;
    v_liste := v_liste || jsonb_build_array(jsonb_build_object('pnj_id', v_id, 'escort_id', c.escort_id, 'nom', c.nom,
      'genre', c.genre, 'portrait', c.portrait, 'vignette', c.vignette, 'cadrage', c.cadrage, 'cout_jour', v_prof.cout_jour));
  END LOOP;
  -- La validation pose la trace (Fred, 12/11/2026) : rumeur et scandale.
  v_dig := public.escort_dignitaire_interne(moi);
  v_trace := 'action-' || replace(gen_random_uuid()::text, '-', '');
  INSERT INTO public.actions_tracables (id, auteur, cible, type_action, country, city, jour, jour_expiration)
  SELECT v_trace, name, (v_lieu->>'lieu') || '|' || coalesce(v_dig->>'libelle', ''), 'appel_escort', country, current_city,
         coalesce(day, 1), coalesce(day, 1) + 7
    FROM public.personnages_donnees WHERE name = moi;
  INSERT INTO public.escort_appels (requete, appelant, batiment, piece, escorts, montant, trace_id)
  VALUES (p_requete, moi, v_lieu->>'batiment', v_lieu->>'piece', v_liste, v_total, v_trace) RETURNING id INTO v_appel;
  INSERT INTO public.escort_scandales (trace_id, appel_id, dignitaire, pays_dignitaire, poste_id, poste_libelle, lieu)
  VALUES (v_trace, v_appel, moi, v_dig->>'pays', v_dig->>'poste_id', v_dig->>'libelle', v_lieu->>'lieu');
  v_rep := jsonb_build_object('ok', true, 'escorts', v_liste, 'nombre', f + h, 'montant', v_total, 'agence', 'Agence Roxane Velours',
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = moi), 'arg', (SELECT arg FROM public.personnages_donnees WHERE name = moi));
  UPDATE public.escort_appels SET reponse = v_rep WHERE id = v_appel;
  RETURN v_rep;
END $$;
REVOKE ALL ON FUNCTION public.escort_standard_valider(uuid, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.escort_standard_valider(uuid, integer, integer) TO authenticated;

-- 5. Dossiers du ministre de l'Intérieur : projets d'article, secrets, dossiers piratés.
CREATE OR REPLACE FUNCTION public.interieur_publier_interne(p_id bigint, p_par text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE d public.interieur_dossiers;
BEGIN
  SELECT * INTO d FROM public.interieur_dossiers WHERE id = p_id AND type = 'projet_article' FOR UPDATE;
  IF NOT FOUND OR d.statut = 'publie' THEN RETURN; END IF;
  INSERT INTO public.journal_articles_en_attente (id, country, rubrique, titre, texte, statut, origine, priorite, dedup_key, created_at)
  VALUES ('scandale-escort-' || p_id, d.pays, 'politique', d.titre, d.contenu, 'attente', 'scandale_escort', 'importante',
          'scandale-escort-' || p_id, now())
  ON CONFLICT (id) DO NOTHING;
  UPDATE public.interieur_dossiers SET statut = 'publie', decide_par = p_par, decide_le = now() WHERE id = p_id;
END $$;
REVOKE ALL ON FUNCTION public.interieur_publier_interne(bigint, text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.interieur_dossier_deposer_interne(p_pays text, p_type text, p_cible text, p_titre text,
  p_contenu text, p_donnees jsonb, p_expediteur text, p_sujet text, p_corps text)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_id bigint; v_ministre text := public.interieur_ministre_pj_interne(p_pays);
BEGIN
  INSERT INTO public.interieur_dossiers (pays, type, cible, titre, contenu, donnees)
  VALUES (p_pays, p_type, p_cible, left(p_titre, 200), p_contenu, coalesce(p_donnees, '{}'::jsonb)) RETURNING id INTO v_id;
  IF v_ministre IS NOT NULL THEN
    PERFORM public.mail_systeme_poser_interne(p_expediteur, v_ministre, p_sujet, p_corps, NULL);
  ELSIF p_type = 'projet_article' THEN
    -- Ministre PNJ : publication une fois sur deux (Fred, 12/11/2026), sinon le projet attend dans le bureau.
    IF random() < 0.5 THEN PERFORM public.interieur_publier_interne(v_id, 'PNJ');
    ELSE UPDATE public.interieur_dossiers SET statut = 'en_attente', decide_par = 'PNJ', decide_le = now() WHERE id = v_id;
    END IF;
  END IF;
  RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION public.interieur_dossier_deposer_interne(text, text, text, text, text, jsonb, text, text, text) FROM PUBLIC, anon, authenticated;

-- 6. Rumeur : une écoute = −3 POP ; à la 3e, projets d'article (journalistes PNJ → ministres de l'Intérieur).
CREATE OR REPLACE FUNCTION public.escort_scandale_presse_interne(p_trace text, p_pays text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE s public.escort_scandales; v_titre text; v_texte text; v_qui text; v_exp text; v_salut text;
BEGIN
  SELECT * INTO s FROM public.escort_scandales WHERE trace_id = p_trace;
  IF NOT FOUND THEN RETURN; END IF;
  v_qui := s.dignitaire || CASE WHEN coalesce(s.poste_libelle, '') <> '' THEN ', ' || s.poste_libelle ELSE '' END;
  v_titre := 'Soirée velours pour ' || coalesce(nullif(s.poste_libelle, ''), s.dignitaire);
  v_texte := 'Selon nos informations, ' || v_qui || ', a fait appel aux services de l''agence internationale Roxane Velours dans son appartement '
    || CASE s.lieu WHEN 'residence' THEN 'de la Résidence impériale' ELSE 'du Pavillon des Ambassadeurs' END
    || ', aux frais de qui, la question reste posée. La rédaction a tenté de joindre l''intéressé, sans succès.';
  v_exp := CASE p_pays WHEN 'soviet' THEN 'La Voix de Sovarka — Zoïa Glazounova' WHEN 'republic' THEN 'La Tribune de Républia' ELSE 'Rédaction' END;
  v_salut := CASE p_pays WHEN 'soviet' THEN 'Camarade ministre' ELSE 'Monsieur le ministre' END;
  PERFORM public.interieur_dossier_deposer_interne(p_pays, 'projet_article', s.dignitaire, v_titre, v_texte,
    jsonb_build_object('trace', p_trace, 'journal', v_exp),
    v_exp, 'Projet d''article — ' || v_titre,
    v_salut || ', avant publication, la rédaction soumet à votre validation le projet d''article suivant :' || E'\n\n« ' || v_titre || E' »\n'
    || v_texte || E'\n\nVous pouvez en valider la publication ou le mettre en attente depuis votre bureau (« Dossiers confidentiels »).');
END $$;
REVOKE ALL ON FUNCTION public.escort_scandale_presse_interne(text, text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.escort_scandale_ecoute_interne(p_trace text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE s public.escort_scandales;
BEGIN
  UPDATE public.escort_scandales SET ecoutes = ecoutes + 1 WHERE trace_id = p_trace RETURNING * INTO s;
  IF NOT FOUND THEN RETURN; END IF;
  PERFORM public.rumeur_pop_retirer_interne(s.dignitaire, 3);
  IF s.ecoutes >= 3 AND NOT s.journalistes_prevenus THEN
    UPDATE public.escort_scandales SET journalistes_prevenus = true WHERE trace_id = p_trace;
    PERFORM public.escort_scandale_presse_interne(p_trace, 'soviet');
    IF s.pays_dignitaire IS NOT NULL AND s.pays_dignitaire <> 'soviet' THEN
      PERFORM public.escort_scandale_presse_interne(p_trace, s.pays_dignitaire);
    END IF;
  END IF;
END $$;
REVOKE ALL ON FUNCTION public.escort_scandale_ecoute_interne(text) FROM PUBLIC, anon, authenticated;

-- Raccord à l'écoute des rumeurs (tables, barman, « Écouter les rumeurs ») : patch en place sous empreinte.
DO $mig$
DECLARE d text; a1 text; a2 text; a3 text;
BEGIN
  d := pg_get_functiondef('public.rumeur_ecoute_jauges_interne(text)'::regprocedure);
  IF position('escort_scandale_v1' IN d) = 0 THEN
    a1 := 'SELECT t.type_action,t.auteur,t.cible INTO trace FROM public.actions_tracables t';
    a2 := '''plainte_egaree''/* justice_sovarka_rumeur_v1 */';
    a3 := 'fait:=jsonb_build_object(''type_action'',trace.type_action,''auteur'',trace.auteur,''cible'',trace.cible);gain:=1;';
    IF (length(d) - length(replace(d, a1, ''))) / length(a1) <> 1 OR (length(d) - length(replace(d, a2, ''))) / length(a2) <> 1
       OR (length(d) - length(replace(d, a3, ''))) / length(a3) <> 1 THEN
      RAISE EXCEPTION 'rumeur_ecoute_jauges_interne : ancrage introuvable'; END IF;
    d := replace(d, a1, 'SELECT t.id,t.type_action,t.auteur,t.cible INTO trace FROM public.actions_tracables t');
    d := replace(d, a2, a2 || ',''appel_escort''/* escort_scandale_v1 */');
    d := replace(d, a3, a3 || E'\n   IF trace.type_action=''appel_escort''AND coalesce(a.pa,0)>=coalesce(cout_pa,0)THEN PERFORM public.escort_scandale_ecoute_interne(trace.id);END IF;');
    EXECUTE d;
  END IF;
END $mig$;

-- 7. Secrets confiés aux escorts en Sovarka : transmis au ministre de la Sécurité du Peuple (Fred, 12/11/2026).
CREATE OR REPLACE FUNCTION public.escort_secret_transmettre_trg()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF NEW.mode_acquisition IN ('confidence', 'transmission')
     AND EXISTS (SELECT 1 FROM public.escorts_catalogue c WHERE c.nom = NEW.titulaire)
     AND EXISTS (SELECT 1 FROM public.personnages_donnees p WHERE p.name = NEW.source AND p.country = 'soviet') THEN
    BEGIN
      PERFORM public.interieur_dossier_deposer_interne('soviet', 'secret_escort', NEW.source,
        'Confidence de ' || NEW.source || ' à ' || NEW.titulaire, NEW.contenu,
        jsonb_build_object('escort', NEW.titulaire, 'mode', NEW.mode_acquisition),
        'Ministère de la Sécurité du Peuple', 'Confidence recueillie — ' || NEW.source,
        NEW.titulaire || ', de l''agence Roxane Velours, rapporte ceci :' || E'\n\n' || NEW.contenu
        || E'\n\nLe dossier est conservé dans votre bureau (« Dossiers confidentiels »).');
    EXCEPTION WHEN others THEN NULL; -- un rapport perdu ne doit jamais empêcher la confidence elle-même
    END;
  END IF;
  RETURN NULL;
END $$;
REVOKE ALL ON FUNCTION public.escort_secret_transmettre_trg() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS escort_secret_transmettre ON public.renseignements_connus;
CREATE TRIGGER escort_secret_transmettre AFTER INSERT ON public.renseignements_connus
  FOR EACH ROW EXECUTE FUNCTION public.escort_secret_transmettre_trg();

-- 8. Piratage nocturne : une fois par nuit dans l'appartement loué, escort sous contrat, 25 %, copie discrète.
CREATE OR REPLACE FUNCTION public.escort_piratage_nuit_interne(p_nom text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_lieu jsonb; v_escort text; v_n integer; d public.dossiers_informatiques; v_objets text[];
  v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date; p record;
BEGIN
  v_lieu := public.escort_lieu_locataire_interne(p_nom);
  IF v_lieu IS NULL THEN RETURN; END IF;
  SELECT m.nom INTO v_escort FROM public.pnj_membres m JOIN public.pnj_employes_metier em ON em.pnj_id = m.id
   WHERE m.famille = 'employe' AND m.proprietaire_pj = p_nom AND m.statut = 'actif' AND em.job = 'escort'
   ORDER BY random() LIMIT 1;
  IF v_escort IS NULL THEN RETURN; END IF;
  INSERT INTO public.escort_piratages_nuits (nom, jour) VALUES (p_nom, v_jour) ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n = 0 THEN RETURN; END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = p_nom;
  -- Ordinateurs « venus avec lui » : dans l'inventaire, ou installés dans la pièce louée.
  SELECT array_agg(x) INTO v_objets FROM (
    SELECT o->>'id' x FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p.inventory) = 'array' THEN p.inventory ELSE '[]'::jsonb END) o
     WHERE coalesce(o->>'generique_id', o->>'type') = 'ordinateur-complet' AND coalesce(o->>'id', '') <> ''
    UNION SELECT e.objet->>'id' FROM public.equipements_installes e
     WHERE e.proprietaire = p_nom AND e.generique_id = 'ordinateur-complet' AND e.pays = p.country AND e.ville = p.current_city
       AND e.batiment = p.current_building AND e.piece = p.current_room) q;
  IF v_objets IS NULL OR random() >= 0.25 THEN RETURN; END IF;
  SELECT * INTO d FROM public.dossiers_informatiques WHERE objet_id = ANY (v_objets) ORDER BY random() LIMIT 1;
  IF NOT FOUND THEN RETURN; END IF;
  PERFORM public.interieur_dossier_deposer_interne('soviet', 'dossier_pirate', p_nom,
    'Dossier copié chez ' || p_nom || ' : ' || coalesce(d.titre, 'sans titre'), coalesce(d.contenu, ''),
    jsonb_build_object('escort', v_escort, 'type', d.type, 'donnees', d.donnees),
    'Ministère de la Sécurité du Peuple', 'Dossier informatique copié — ' || p_nom,
    'Pendant la nuit, ' || v_escort || ' a copié un dossier de l''ordinateur de ' || p_nom || ' : « ' || coalesce(d.titre, 'sans titre')
    || E' ».\n\nLa copie est conservée dans votre bureau (« Dossiers confidentiels »).');
  -- La trace d'un acte illégal ordinaire, au nom de l'escort ; la victime n'est pas prévenue.
  INSERT INTO public.actions_tracables (id, auteur, cible, type_action, country, city, jour, jour_expiration)
  VALUES ('action-' || replace(gen_random_uuid()::text, '-', ''), v_escort, p_nom, 'pirater', p.country, p.current_city,
          coalesce(p.day, 1), coalesce(p.day, 1) + 7);
END $$;
REVOKE ALL ON FUNCTION public.escort_piratage_nuit_interne(text) FROM PUBLIC, anon, authenticated;

DO $mig$
DECLARE d text; a text := E'    PERFORM public.residence_bonus_nuit_interne(p_acteur);\n';
BEGIN
  d := pg_get_functiondef('public.pa_repos_nocturne(text)'::regprocedure);
  IF position('escort_piratage_nuit_interne' IN d) = 0 THEN
    IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'pa_repos_nocturne : ancrage introuvable'; END IF;
    EXECUTE replace(d, a, a || E'    -- escort_piratage_v1 : un escort sous contrat peut copier un dossier pendant la nuit.\n'
      || E'    PERFORM public.escort_piratage_nuit_interne(p_acteur);\n');
  END IF;
END $mig$;

-- 9. Le bureau du ministre de l'Intérieur : lire les dossiers, décider des projets d'article.
CREATE OR REPLACE FUNCTION public.interieur_dossiers_lire()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE moi text := public.mon_personnage(); v_pays text; v jsonb;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT a.country INTO v_pays FROM public.postes_attribues a
    JOIN public.personnages_donnees d ON d.name = a.titulaire AND d.poste->>'id' = a.poste_id
   WHERE a.titulaire = moi AND a.poste_id = 'min_int' LIMIT 1;
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'poste_requis'); END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'type', x.type, 'cible', x.cible, 'titre', x.titre, 'contenu', x.contenu,
           'statut', x.statut, 'decide_par', x.decide_par, 'cree_le', to_char(x.cree_le AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD HH24:MI'))
         ORDER BY x.cree_le DESC), '[]'::jsonb)
    INTO v FROM (SELECT * FROM public.interieur_dossiers WHERE pays = v_pays ORDER BY cree_le DESC LIMIT 60) x;
  UPDATE public.interieur_dossiers SET statut = 'lu' WHERE pays = v_pays AND statut = 'nouveau' AND type <> 'projet_article';
  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'dossiers', v);
END $$;
REVOKE ALL ON FUNCTION public.interieur_dossiers_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.interieur_dossiers_lire() TO authenticated;

CREATE OR REPLACE FUNCTION public.interieur_projet_decider(p_id bigint, p_action text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE moi text := public.mon_personnage(); v_pays text; d public.interieur_dossiers;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_action NOT IN ('publier', 'attente') THEN RETURN jsonb_build_object('ok', false, 'raison', 'action_inconnue'); END IF;
  SELECT a.country INTO v_pays FROM public.postes_attribues a
    JOIN public.personnages_donnees pd ON pd.name = a.titulaire AND pd.poste->>'id' = a.poste_id
   WHERE a.titulaire = moi AND a.poste_id = 'min_int' LIMIT 1;
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'poste_requis'); END IF;
  SELECT * INTO d FROM public.interieur_dossiers WHERE id = p_id AND pays = v_pays AND type = 'projet_article' FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'projet_introuvable'); END IF;
  IF d.statut = 'publie' THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_publie'); END IF;
  IF p_action = 'publier' THEN PERFORM public.interieur_publier_interne(p_id, moi);
  ELSE UPDATE public.interieur_dossiers SET statut = 'en_attente', decide_par = moi, decide_le = now() WHERE id = p_id;
  END IF;
  RETURN jsonb_build_object('ok', true, 'id', p_id, 'statut', CASE p_action WHEN 'publier' THEN 'publie' ELSE 'en_attente' END);
END $$;
REVOKE ALL ON FUNCTION public.interieur_projet_decider(bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.interieur_projet_decider(bigint, text) TO authenticated;

-- 10. Service d'étage : carte du Grand Hôtel, + 20 PSK par commande (à la caisse de l'hôtel), effets du restaurant.
CREATE OR REPLACE FUNCTION public.service_etage_carte()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE moi text := public.mon_personnage(); v_data jsonb;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF public.escort_lieu_locataire_interne(moi) IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_locataire'); END IF;
  SELECT data INTO v_data FROM public.entreprises WHERE id = 'brasserie-soviet-capitale-hotel-republica';
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'carte_indisponible'); END IF;
  RETURN jsonb_build_object('ok', true, 'service', 20, 'carte', coalesce((
    SELECT jsonb_agg(jsonb_build_object('produit', x.p, 'label', r.label, 'prix', (v_data#>>ARRAY['parametres','prixVente',x.p])::numeric,
             'stock', coalesce((v_data#>>ARRAY['stockProduits',x.p])::numeric, 0), 'effets', coalesce(r.effets, '{}'::jsonb)) ORDER BY x.o)
      FROM jsonb_array_elements_text(coalesce(v_data->'carte', '[]'::jsonb)) WITH ORDINALITY x(p, o)
      JOIN public.recettes_commerce r ON r.id = x.p), '[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION public.service_etage_carte() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.service_etage_carte() TO authenticated;

CREATE OR REPLACE FUNCTION public.service_etage_commander(p_requete uuid, p_produit text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE moi text := public.mon_personnage(); v_ancien jsonb; v_vente jsonb; v_frais jsonb; v_eff jsonb; v_rep jsonb;
  c_ent constant text := 'brasserie-soviet-capitale-hotel-republica'; c_service constant integer := 20;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_requise'); END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('service_etage:' || moi, 0));
  SELECT reponse INTO v_ancien FROM public.service_etage_commandes WHERE requete = p_requete AND acteur = moi;
  IF v_ancien IS NOT NULL THEN RETURN v_ancien || jsonb_build_object('rejeu', true); END IF;
  IF public.escort_lieu_locataire_interne(moi) IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_locataire'); END IF;
  IF (SELECT coalesce(liquide, 0) FROM public.personnages_donnees WHERE name = moi)
     + coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage = moi AND banque = 'nationale'), 0)
     < coalesce((SELECT (data#>>ARRAY['parametres','prixVente',p_produit])::numeric FROM public.entreprises WHERE id = c_ent), 0) + c_service THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'); END IF;
  -- La vente elle-même : même porte que le comptoir du restaurant (prix, stock, taxe, caisse).
  v_vente := public.commerce_vendre_produit_interne(moi, c_ent, jsonb_build_array(jsonb_build_object('produit', p_produit, 'qte', 1)),
               'comptoir', NULL, 0, 0, NULL, NULL);
  IF coalesce((v_vente->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_vente; END IF;
  v_frais := public.debiter_fonds_ordinaires(moi, c_service);
  IF coalesce((v_frais->>'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'service_etage : frais de service refusés après la vente'; END IF;
  UPDATE public.entreprises SET data = jsonb_set(data, '{caisse}', to_jsonb(greatest(0, coalesce((data->>'caisse')::numeric, 0)) + c_service), true),
         updated_at = now() WHERE id = c_ent;
  -- Mêmes effets qu'au restaurant : santé, moral, PA différés au prochain Dormir.
  SELECT coalesce(effets, '{}'::jsonb) INTO v_eff FROM public.recettes_commerce WHERE id = p_produit;
  UPDATE public.personnages_donnees
     SET hp = least(100, coalesce(hp, 0) + greatest(0, coalesce((v_eff->>'hp')::integer, 0))),
         moral = least(100, coalesce(moral, 0) + greatest(0, coalesce((v_eff->>'moral')::integer, 0)))
   WHERE name = moi;
  IF coalesce((v_eff->>'paDiffere')::integer, 0) > 0 THEN PERFORM public.pa_bonus_differe_crediter(moi, p_produit); END IF;
  SELECT jsonb_build_object('ok', true, 'produit', p_produit, 'prix', v_vente->'total', 'service', c_service,
           'effets', v_eff, 'hp', hp, 'moral', moral, 'pa', pa, 'liquide', liquide, 'arg', arg)
    INTO v_rep FROM public.personnages_donnees WHERE name = moi;
  INSERT INTO public.service_etage_commandes (requete, acteur, produit, reponse) VALUES (p_requete, moi, p_produit, v_rep);
  RETURN v_rep;
END $$;
REVOKE ALL ON FUNCTION public.service_etage_commander(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.service_etage_commander(uuid, text) TO authenticated;

-- 11. Contrôles structurels.
DO $$
DECLARE v jsonb;
BEGIN
  v := public.escort_demande_analyser('Bonsoir, deux femmes et un homme, s''il vous plaît');
  IF (v->>'femmes')::int <> 2 OR (v->>'hommes')::int <> 1 THEN RAISE EXCEPTION 'escort_demande_analyser : % ', v; END IF;
  v := public.escort_demande_analyser('une escort');
  IF (v->>'femmes')::int <> 1 OR (v->>'hommes')::int <> 0 THEN RAISE EXCEPTION 'escort_demande_analyser (une escort) : %', v; END IF;
  v := public.escort_demande_analyser('les deux');
  IF (v->>'femmes')::int <> 1 OR (v->>'hommes')::int <> 1 THEN RAISE EXCEPTION 'escort_demande_analyser (les deux) : %', v; END IF;
  IF position('escort_scandale_v1' IN pg_get_functiondef('public.rumeur_ecoute_jauges_interne(text)'::regprocedure)) = 0
     OR position('escort_piratage_nuit_interne' IN pg_get_functiondef('public.pa_repos_nocturne(text)'::regprocedure)) = 0
     OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'escort_secret_transmettre')
     OR has_table_privilege('authenticated', 'public.interieur_dossiers', 'SELECT')
     OR has_function_privilege('authenticated', 'public.escort_scandale_ecoute_interne(text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'escorts_roxane_velours : contrôle structurel en échec';
  END IF;
END $$;

COMMIT;
