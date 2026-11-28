-- Mission du 28/11/2026 (nuit, Claude), étape 3 B, C et D — Hôtels de Ciudad Roja et d'Al Madina, billet aux douaniers.
-- Règles de Fred (28/11/2026), résumées dans GAME-DESIGN-CIUDAD-ROJA.md et GAME-DESIGN-AL-MADINA.md.
--
-- Une seule commande serveur pour les gestes d'hôtel : hotel_teaser_agir(p_requete, p_action, p_cible, p_montant),
-- idempotente par reçu (hotel_teaser_actes). Le lieu, les PA, l'argent, les limites quotidiennes, les tirages et les
-- effets sont tous décidés ici ; le navigateur n'envoie que l'action, la cible et, pour le billet ou le backgammon, le montant.
--   Ciudad Roja (PS) : cr_nager, cr_tennis, cr_pourboire, cr_billet_douaniers (centre multimodal).
--   Al Madina (DR)   : am_the_menthe, am_patisseries, am_jus_fruits, am_the_special, am_narguile, am_cafe_arabe,
--                      am_bain_vapeur, am_secret_contre_secret, am_backgammon (défi) ; réponse : hotel_backgammon_repondre.
-- Autres pièces : escorts de la suite de Ciudad Roja (catalogue « narco », confidences vers les ministères), tirade unique de
-- Don Augusto Bigotes (ciudad_roja_augusto_tirade), journal des passages pour les PNJ référents (hotel_teaser_habitues),
-- protection contre la canicule (piscine, jus de fruits frais), verrou de navigation des pièces réservées de l'Hôtel Royal.
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  n := (length(d) - length(replace(d, p_avant, ''))) / length(p_avant);
  IF n <> 1 THEN RAISE EXCEPTION '% : % occurrence(s) au lieu de 1 (%)', p_fn, n, left(p_avant, 70); END IF;
  EXECUTE replace(d, p_avant, p_apres);
END $$;

-- 1. Tables.
CREATE TABLE IF NOT EXISTS public.hotel_teaser_actes (
  acteur text NOT NULL, requete uuid NOT NULL, resultat jsonb NOT NULL, cree_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (acteur, requete));
CREATE TABLE IF NOT EXISTS public.hotel_teaser_compteurs (
  acteur text NOT NULL, action text NOT NULL, cible text NOT NULL DEFAULT '', jour date NOT NULL, n integer NOT NULL DEFAULT 0,
  PRIMARY KEY (acteur, action, cible, jour));
CREATE TABLE IF NOT EXISTS public.hotel_teaser_visites (
  personnage text NOT NULL, pays text NOT NULL, piece text NOT NULL, jour date NOT NULL, n integer NOT NULL DEFAULT 0,
  PRIMARY KEY (personnage, pays, piece, jour));
CREATE TABLE IF NOT EXISTS public.hotel_backgammon_defis (
  id bigserial PRIMARY KEY, auteur text NOT NULL, cible text NOT NULL, mise integer NOT NULL CHECK (mise > 0),
  statut text NOT NULL DEFAULT 'attente' CHECK (statut IN ('attente', 'accepte', 'refuse', 'expire', 'annule')),
  gagnant text, cree_le timestamptz NOT NULL DEFAULT now(), resolu_le timestamptz);
CREATE INDEX IF NOT EXISTS hotel_backgammon_defis_cible ON public.hotel_backgammon_defis (cible, statut);
CREATE TABLE IF NOT EXISTS public.ciudad_roja_augusto_tirades (personnage text PRIMARY KEY, le timestamptz NOT NULL DEFAULT now());
ALTER TABLE public.hotel_teaser_actes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hotel_teaser_compteurs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hotel_teaser_visites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hotel_backgammon_defis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ciudad_roja_augusto_tirades ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.hotel_teaser_actes, public.hotel_teaser_compteurs, public.hotel_teaser_visites,
              public.hotel_backgammon_defis, public.ciudad_roja_augusto_tirades FROM anon, authenticated;

-- 2. Tarifs (les montants d'Al Madina sont déjà doublés par rapport à Républia).
INSERT INTO public.ordres_couts (fn, pa, cost) VALUES
 ('cr_nager', 1, 0), ('cr_tennis', 2, 0), ('cr_pourboire', 0, 200), ('cr_billet_douaniers', 0, 0),
 ('am_the_menthe', 1, 60), ('am_patisseries', 1, 150), ('am_jus_fruits', 1, 50), ('am_the_special', 1, 150),
 ('am_narguile', 1, 250), ('am_cafe_arabe', 2, 80), ('am_bain_vapeur', 1, 300), ('am_secret_contre_secret', 1, 0),
 ('am_backgammon', 0, 0)
ON CONFLICT DO NOTHING; -- clé primaire (fn, pa, cost)

-- 3. Petites fonctions internes.
CREATE OR REPLACE FUNCTION public.hotel_teaser_stat_interne(p_stats jsonb, p_cle text, p_defaut integer DEFAULT 10)
RETURNS integer LANGUAGE sql IMMUTABLE AS $$
  SELECT coalesce(CASE WHEN jsonb_typeof(p_stats -> p_cle) = 'number' THEN (p_stats ->> p_cle)::numeric::integer END, p_defaut) $$;

CREATE OR REPLACE FUNCTION public.hotel_teaser_compter_interne(p_acteur text, p_action text, p_cible text, p_max integer)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE j date := (now() AT TIME ZONE 'Europe/Paris')::date; n integer;
BEGIN
  INSERT INTO public.hotel_teaser_compteurs (acteur, action, cible, jour, n) VALUES (p_acteur, p_action, coalesce(p_cible, ''), j, 0)
    ON CONFLICT DO NOTHING;
  SELECT c.n INTO n FROM public.hotel_teaser_compteurs c
   WHERE c.acteur = p_acteur AND c.action = p_action AND c.cible = coalesce(p_cible, '') AND c.jour = j FOR UPDATE;
  IF p_max IS NOT NULL AND n >= p_max THEN RETURN false; END IF;
  UPDATE public.hotel_teaser_compteurs c SET n = c.n + 1
   WHERE c.acteur = p_acteur AND c.action = p_action AND c.cible = coalesce(p_cible, '') AND c.jour = j;
  RETURN true;
END $$;

CREATE OR REPLACE FUNCTION public.hotel_teaser_effet_poser_interne(p_nom text, p_cle text, p_deltas jsonb, p_libelle text, p_heures integer, p_cumul_refuse boolean)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_now bigint := (extract(epoch FROM clock_timestamp()) * 1000)::bigint; v_eff jsonb;
BEGIN
  SELECT coalesce(effets_actifs, '[]'::jsonb) INTO v_eff FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  IF p_cumul_refuse AND EXISTS (SELECT 1 FROM jsonb_array_elements(v_eff) e
                                 WHERE e ->> 'cle' = p_cle AND coalesce((e ->> 'expireA')::bigint, 0) > v_now) THEN RETURN false; END IF;
  UPDATE public.personnages_donnees SET effets_actifs =
    (SELECT coalesce(jsonb_agg(e), '[]'::jsonb) FROM jsonb_array_elements(v_eff) e
      WHERE coalesce((e ->> 'expireA')::bigint, 0) > v_now AND e ->> 'cle' IS DISTINCT FROM p_cle)
    || jsonb_build_array(jsonb_build_object('cle', p_cle, 'cible', 'pj', 'deltas', coalesce(p_deltas, '{}'::jsonb), 'libelle', p_libelle,
                                            'poseA', v_now, 'expireA', v_now + p_heures::bigint * 3600000)),
    updated_at = now()
   WHERE name = p_nom;
  RETURN true;
END $$;

CREATE OR REPLACE FUNCTION public.hotel_protection_chaleur_interne(p_nom text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.personnages_donnees p, jsonb_array_elements(coalesce(p.effets_actifs, '[]'::jsonb)) e
                  WHERE p.name = p_nom AND e ->> 'cle' = 'protection_chaleur'
                    AND coalesce((e ->> 'expireA')::bigint, 0) > (extract(epoch FROM now()) * 1000)::bigint) $$;

-- Un vrai secret du personnage, pris au tirage existant des maisons de Sovarka (poste, argent liquide, domicile, actions récentes).
CREATE OR REPLACE FUNCTION public.hotel_teaser_apprendre_interne(p_titulaire text, p_sujet text, p_mode text, p_categorie text, p_secret text, p_lieu text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE d record;
BEGIN
  SELECT country, current_city, current_building, current_room INTO d FROM public.personnages_donnees WHERE name = p_titulaire;
  INSERT INTO public.renseignements_connus (id, titulaire, contenu, cible, categorie, source, mode_acquisition, fait_objectif_ref,
    jour_acquisition, jour_derniere_reactivation, jour_expiration, jour_observe, pays, ville, building_id, room_id)
  VALUES ('ht_' || (extract(epoch FROM clock_timestamp()) * 1000)::bigint || '_' || substr(md5(random()::text), 1, 8),
          p_titulaire, p_sujet || ' : ' || p_secret, p_sujet, p_categorie, p_sujet, p_mode, p_lieu || ':' || p_sujet,
          0, 0, 2147483647, (now() AT TIME ZONE 'Europe/Paris')::date, d.country, d.current_city, d.current_building, d.current_room);
  PERFORM public.mail_systeme_poser_interne(CASE p_categorie WHEN 'secret_hammam' THEN 'Hôtel Royal d''Al-Khalija' ELSE 'Salon des gentlemen' END,
    p_titulaire, 'Un secret de ' || p_sujet, p_sujet || ' : ' || p_secret, NULL);
END $$;

-- 4. Commande principale.
CREATE OR REPLACE FUNCTION public.hotel_teaser_agir(p_requete uuid, p_action text, p_cible text DEFAULT NULL, p_montant integer DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE a text := public.mon_personnage(); p record; c record; x record; v jsonb; r jsonb; v_taux integer; v_jet integer;
        v_isn numeric; v_secret text; v_secret2 text; v_n integer; v_mail text; v_temoins integer := 0; v_crit boolean;
        v_cr boolean; v_am boolean; v_lieu boolean; v_rumeurs text[] := ARRAY[
          'Le Caudillo ne dort jamais deux nuits de suite dans le même palais.',
          'Les douaniers de Ciudad Roja touchent plus en billets qu''en salaire.',
          'Un avion sans immatriculation se pose chaque jeudi sur la piste nord.',
          'Le casino de la ville appartient à un neveu de Don Augusto Bigotes.',
          'Les gangs armés du port paient la sécurité de l''hôtel pour ne pas y entrer.',
          'Le ministre de l''Intérieur lit chaque matin les confidences recueillies dans les suites.',
          'Une réserve d''or attendrait sous la Banque nationale le retour d''un ancien président.',
          'Les élections d''El Estado se gagnent au poker, la veille du scrutin.'];
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_absente'); END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('hotel_teaser:' || a, 0));
  SELECT * INTO x FROM public.hotel_teaser_actes WHERE acteur = a AND requete = p_requete;
  IF FOUND THEN RETURN x.resultat || jsonb_build_object('rejeu', true); END IF;
  SELECT name, country, current_city, current_building, current_room, stats, liquide INTO p
    FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF EXISTS (SELECT 1 FROM public.detention_active(a)) THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_indisponible'); END IF;
  v_cr := p.country = 'narco' AND p.current_city = 'capitale';
  v_am := p.country = 'khalija' AND p.current_city = 'capitale' AND p.current_building = 'hotel-republica';

  -- Lieu de chaque geste.
  v_lieu := CASE
       WHEN p_action IN ('cr_nager', 'cr_tennis') THEN v_cr AND p.current_building = 'hotel-republica' AND p.current_room = 'piscine'
       WHEN p_action = 'cr_pourboire' THEN v_cr AND p.current_building = 'hotel-republica' AND p.current_room IN ('accueil', 'restaurant', 'piscine', 'bar')
       WHEN p_action = 'cr_billet_douaniers' THEN v_cr AND p.current_building = 'centre-multinodal-luthecia' AND p.current_room = 'hall_douanes'
       WHEN p_action IN ('am_the_menthe', 'am_patisseries', 'am_jus_fruits', 'am_the_special') THEN v_am AND p.current_room = 'bar'
       WHEN p_action IN ('am_narguile', 'am_cafe_arabe', 'am_backgammon') THEN v_am AND p.current_room = 'salon_gentlemen'
       WHEN p_action = 'am_bain_vapeur' THEN v_am AND p.current_room IN ('hammam_hommes', 'hammam_femmes')
       WHEN p_action = 'am_secret_contre_secret' THEN v_am AND p.current_room IN ('salon_gentlemen', 'hammam_hommes', 'hammam_femmes')
       ELSE false END;
  IF NOT coalesce(v_lieu, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', CASE WHEN p_action LIKE 'cr\_%' OR p_action LIKE 'am\_%' THEN 'pas_sur_place' ELSE 'action_inconnue' END);
  END IF;
  -- Le serveur ne laisse dans une pièce réservée que ceux qui y ont droit (genre ou passage forcé) ; on revérifie quand même.
  IF v_am AND public.acces_reserve_raison_interne(a, p.current_building, p.current_room) IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;

  -- Cible joueur présente dans la même pièce (secret contre secret, backgammon).
  IF p_action IN ('am_secret_contre_secret', 'am_backgammon') THEN
    SELECT name, stats INTO c FROM public.personnages_donnees
     WHERE name = p_cible AND name <> a AND user_id IS NOT NULL AND country = p.country AND current_city = p.current_city
       AND current_building = p.current_building AND current_room = p.current_room;
    IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_absente'); END IF;
  END IF;

  -- Limites quotidiennes (vérifiées avant paiement, comptées après).
  IF p_action = 'cr_nager' AND coalesce((SELECT n FROM public.hotel_teaser_compteurs WHERE acteur = a AND action = p_action AND cible = ''
        AND jour = (now() AT TIME ZONE 'Europe/Paris')::date), 0) >= 2
     OR p_action IN ('cr_tennis', 'am_bain_vapeur') AND coalesce((SELECT n FROM public.hotel_teaser_compteurs WHERE acteur = a AND action = p_action AND cible = ''
        AND jour = (now() AT TIME ZONE 'Europe/Paris')::date), 0) >= 1
     OR p_action = 'am_narguile' AND coalesce((SELECT n FROM public.hotel_teaser_compteurs WHERE acteur = a AND action = p_action AND cible = ''
        AND jour = (now() AT TIME ZONE 'Europe/Paris')::date), 0) >= 3
     OR p_action = 'am_secret_contre_secret' AND coalesce((SELECT n FROM public.hotel_teaser_compteurs WHERE acteur = a AND action = p_action AND cible = c.name
        AND jour = (now() AT TIME ZONE 'Europe/Paris')::date), 0) >= 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'limite_quotidienne');
  END IF;
  IF p_action = 'am_cafe_arabe' AND EXISTS (SELECT 1 FROM public.personnages_donnees pp, jsonb_array_elements(coalesce(pp.effets_actifs, '[]'::jsonb)) e
       WHERE pp.name = a AND e ->> 'cle' = 'cafe_arabe' AND coalesce((e ->> 'expireA')::bigint, 0) > (extract(epoch FROM now()) * 1000)::bigint) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'effet_deja_actif'); END IF;
  IF p_action IN ('cr_billet_douaniers', 'am_backgammon') AND (p_montant IS NULL OR p_montant < 1 OR p_montant > 1000000) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;
  IF p_action = 'cr_pourboire' AND coalesce(btrim(p_cible), '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_absente'); END IF;

  -- Backgammon : le défi ne coûte rien ; les mises sont prélevées quand la cible accepte.
  IF p_action = 'am_backgammon' THEN
    IF EXISTS (SELECT 1 FROM public.hotel_backgammon_defis WHERE auteur = a AND cible = c.name AND statut = 'attente' AND cree_le > now() - interval '1 hour') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'defi_deja_lance'); END IF;
    IF coalesce(p.liquide, 0) < p_montant THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'); END IF;
    INSERT INTO public.hotel_backgammon_defis (auteur, cible, mise) VALUES (a, c.name, p_montant) RETURNING id INTO v_n;
    PERFORM public.mail_systeme_poser_interne('Salon des gentlemen', c.name, 'Défi au backgammon',
      a || ' vous défie au backgammon pour ' || p_montant || ' DR. Répondez depuis le salon des gentlemen (ordre « Backgammon »).', NULL);
    r := jsonb_build_object('ok', true, 'action', p_action, 'defi', v_n, 'cible', c.name, 'mise', p_montant);
    INSERT INTO public.hotel_teaser_actes (acteur, requete, resultat) VALUES (a, p_requete, r);
    RETURN r;
  END IF;

  -- Paiement (PA et prix fixes du tarif ; billet : montant choisi, prélevé à part).
  SELECT o.pa, o.cost INTO v_n, v_taux FROM public.ordres_couts o WHERE o.fn = p_action ORDER BY o.cost DESC, o.pa DESC LIMIT 1;
  v := public.payer_ordre(a, p_action, v_n, v_taux);
  IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v; END IF;
  IF p_action = 'cr_billet_douaniers' THEN
    IF NOT public.helvetia_debiter_fonds_ordinaires(a, p_montant) THEN RAISE EXCEPTION 'fonds_insuffisants'; END IF;
  END IF;
  PERFORM public.hotel_teaser_compter_interne(a, p_action, CASE WHEN p_action = 'am_secret_contre_secret' THEN c.name ELSE '' END, NULL);
  r := jsonb_build_object('ok', true, 'action', p_action);

  CASE p_action
  WHEN 'cr_nager' THEN
    PERFORM public.sante_gagner_interne(a, 5, 'piscine_ciudad_roja', '{}'::jsonb);
    PERFORM public.hotel_teaser_effet_poser_interne(a, 'protection_chaleur', '{}'::jsonb, 'Protégé de la canicule', 12, false);
  WHEN 'cr_tennis' THEN
    PERFORM public.sante_perdre_interne(a, 8, 'tennis_ciudad_roja', '{}'::jsonb);
    PERFORM public.personnage_ajuster_pop_inf(a, 5, 7);
  WHEN 'cr_pourboire' THEN
    PERFORM public.personnage_ajuster_pop_inf(a, 1, NULL);
    IF lower(p_cible) LIKE 'tito maletas%' THEN
      v_n := 1 + floor(random() * array_length(v_rumeurs, 1))::integer;
      r := r || jsonb_build_object('rumeur', v_n, 'rumeur_texte', v_rumeurs[v_n]);
    END IF;
  WHEN 'cr_billet_douaniers' THEN
    SELECT coalesce(nullif(data ->> 'isn', '')::numeric, 30) INTO v_isn FROM public.indices_villes WHERE id = 'narco_capitale';
    v_isn := coalesce(v_isn, 30);
    v_taux := least(95, 50 + floor(p_montant / 10.0)::integer
                       + 2 * greatest(0, public.hotel_teaser_stat_interne(p.stats, 'CHA') - 8)
                       + 2 * greatest(0, public.hotel_teaser_stat_interne(p.stats, 'ENT') - 8)
                       + floor(greatest(0, 50 - v_isn) / 3.0)::integer);
    v_jet := floor(random() * 100)::integer + 1;
    IF v_jet <= v_taux THEN
      INSERT INTO public.navigation_passages_douaniers (personnage, pays, ville, batiment, mode, corruption, controle_le)
      VALUES (a, p.country, p.current_city, p.current_building, 'avion', true, now())
      ON CONFLICT (personnage) DO UPDATE SET pays = EXCLUDED.pays, ville = EXCLUDED.ville, batiment = EXCLUDED.batiment,
        mode = 'avion', corruption = true, controle_le = now();
      r := r || jsonb_build_object('reussi', true, 'taux', v_taux, 'jet', v_jet, 'montant', p_montant);
    ELSE
      v := public.douane_confisquer_personnage_interne(a);
      r := r || jsonb_build_object('reussi', false, 'taux', v_taux, 'jet', v_jet, 'montant', p_montant,
                                   'saisis', coalesce(v -> 'saisis', '[]'::jsonb), 'inventory', v -> 'inventory');
    END IF;
  WHEN 'am_the_menthe' THEN PERFORM public.sante_gagner_interne(a, 2, 'the_menthe', '{}'::jsonb);
  WHEN 'am_patisseries' THEN PERFORM public.sante_repas_appliquer_interne(a, 'snack', 'patisseries_orientales', '{}'::jsonb);
  WHEN 'am_jus_fruits' THEN
    PERFORM public.sante_gagner_interne(a, 1, 'jus_fruits', '{}'::jsonb);
    PERFORM public.hotel_teaser_effet_poser_interne(a, 'protection_chaleur', '{}'::jsonb, 'Protégé de la canicule', 12, false);
  WHEN 'am_the_special' THEN
    PERFORM public.maladie_verre_interne(a); -- verre compté, santé du verre et risque de gueule de bois, comme au bar
    IF random() < 0.10 THEN
      -- Police des mœurs : amende de 1 000 DR, sans prison ; prélevée sur ce qui reste si les fonds manquent.
      v_n := least(1000, greatest(0, coalesce((SELECT liquide FROM public.personnages_donnees WHERE name = a), 0)::integer));
      IF v_n > 0 THEN UPDATE public.personnages_donnees SET liquide = liquide - v_n, updated_at = now() WHERE name = a; END IF;
      IF v_n > 0 THEN PERFORM public.assemblee_crediter_caisse('khalija_assemblee', v_n); END IF;
      r := r || jsonb_build_object('police_moeurs', true, 'amende', v_n);
    END IF;
  WHEN 'am_narguile' THEN
    PERFORM public.sante_perdre_interne(a, 2, 'narguile', '{}'::jsonb);
    PERFORM public.personnage_ajuster_pop_inf(a, NULL, 4);
    SELECT n INTO v_n FROM public.hotel_teaser_compteurs WHERE acteur = a AND action = 'am_narguile' AND cible = ''
       AND jour = (now() AT TIME ZONE 'Europe/Paris')::date;
    IF v_n >= 2 THEN
      v_secret := public.sovarka_maison_secret_pj_interne(a);
      IF v_secret IS NOT NULL THEN
        FOR c IN SELECT name FROM public.personnages_donnees WHERE name <> a AND user_id IS NOT NULL AND country = p.country
                  AND current_city = p.current_city AND current_building = p.current_building AND current_room = p.current_room LOOP
          PERFORM public.hotel_teaser_apprendre_interne(c.name, a, 'observation', 'secret_narguile', v_secret, 'narguile');
          v_temoins := v_temoins + 1;
        END LOOP;
        INSERT INTO public.rumeurs_actives (id, data) VALUES ('narguile_' || (extract(epoch FROM clock_timestamp()) * 1000)::bigint || '_' || substr(md5(a), 1, 6),
          jsonb_build_object('cible', a, 'contenu', a || ', la langue déliée par le narguilé : ' || v_secret, 'auteur', 'Salon des gentlemen',
                             'jour', to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD'), 'popPerdu', 0));
        r := r || jsonb_build_object('secret_lache', true, 'secret', v_secret, 'temoins', v_temoins);
      END IF;
    END IF;
  WHEN 'am_cafe_arabe' THEN
    PERFORM public.hotel_teaser_effet_poser_interne(a, 'cafe_arabe', '{"VOL":2}'::jsonb, 'Café arabe (+2 VOL)', 6, true);
  WHEN 'am_bain_vapeur' THEN
    PERFORM public.sante_gagner_interne(a, 6, 'bain_vapeur', '{}'::jsonb);
    UPDATE public.personnages_maladies SET guerie_le = now(), motif_fin = 'bain_vapeur' WHERE nom = a AND cle = 'gueule_de_bois' AND guerie_le IS NULL;
  WHEN 'am_secret_contre_secret' THEN
    v_taux := least(90, greatest(10, 50 + 3 * (public.hotel_teaser_stat_interne(p.stats, 'CHA') - 8)
                                     - 3 * (public.hotel_teaser_stat_interne(c.stats, 'VOL') - 8)));
    v_jet := floor(random() * 100)::integer + 1;
    IF v_jet <= v_taux THEN
      v_secret := public.sovarka_maison_secret_pj_interne(c.name);
      v_secret2 := public.sovarka_maison_secret_pj_interne(a);
      IF v_secret IS NOT NULL THEN PERFORM public.hotel_teaser_apprendre_interne(a, c.name, 'confidence', 'secret_hammam', v_secret, 'secret_contre_secret'); END IF;
      IF v_secret2 IS NOT NULL THEN PERFORM public.hotel_teaser_apprendre_interne(c.name, a, 'confidence', 'secret_hammam', v_secret2, 'secret_contre_secret'); END IF;
      r := r || jsonb_build_object('reussi', true, 'taux', v_taux, 'jet', v_jet, 'cible', c.name, 'secret', v_secret);
    ELSE
      v_crit := random() < 0.10;
      IF v_crit THEN
        v_secret2 := public.sovarka_maison_secret_pj_interne(a);
        IF v_secret2 IS NOT NULL THEN PERFORM public.hotel_teaser_apprendre_interne(c.name, a, 'confidence', 'secret_hammam', v_secret2, 'secret_contre_secret'); END IF;
      END IF;
      r := r || jsonb_build_object('reussi', false, 'critique', v_crit, 'taux', v_taux, 'jet', v_jet, 'cible', c.name);
    END IF;
  END CASE;

  r := r || jsonb_build_object('pa', (SELECT pa FROM public.personnages_donnees WHERE name = a),
                               'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = a));
  INSERT INTO public.hotel_teaser_actes (acteur, requete, resultat) VALUES (a, p_requete, r - 'inventory');
  RETURN r;
END $function$;

-- 5. Backgammon : lecture et réponse.
CREATE OR REPLACE FUNCTION public.hotel_backgammon_lister()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  RETURN jsonb_build_object('ok', true,
    'recus', (SELECT coalesce(jsonb_agg(jsonb_build_object('id', id, 'auteur', auteur, 'mise', mise) ORDER BY id), '[]'::jsonb)
                FROM public.hotel_backgammon_defis WHERE cible = a AND statut = 'attente' AND cree_le > now() - interval '1 hour'),
    'envoyes', (SELECT coalesce(jsonb_agg(jsonb_build_object('id', id, 'cible', cible, 'mise', mise) ORDER BY id), '[]'::jsonb)
                FROM public.hotel_backgammon_defis WHERE auteur = a AND statut = 'attente' AND cree_le > now() - interval '1 hour'));
END $$;

CREATE OR REPLACE FUNCTION public.hotel_backgammon_repondre(p_requete uuid, p_defi bigint, p_accepter boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); d record; x record; pa_ record; pc record; v_taux integer; v_jet integer; v_g text; v_p text; r jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_absente'); END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('hotel_teaser:' || a, 0));
  SELECT * INTO x FROM public.hotel_teaser_actes WHERE acteur = a AND requete = p_requete;
  IF FOUND THEN RETURN x.resultat || jsonb_build_object('rejeu', true); END IF;
  SELECT * INTO d FROM public.hotel_backgammon_defis WHERE id = p_defi AND cible = a FOR UPDATE;
  IF NOT FOUND OR d.statut <> 'attente' THEN RETURN jsonb_build_object('ok', false, 'raison', 'defi_introuvable'); END IF;
  IF d.cree_le <= now() - interval '1 hour' THEN
    UPDATE public.hotel_backgammon_defis SET statut = 'expire', resolu_le = now() WHERE id = d.id;
    RETURN jsonb_build_object('ok', false, 'raison', 'defi_expire'); END IF;
  IF NOT p_accepter THEN
    UPDATE public.hotel_backgammon_defis SET statut = 'refuse', resolu_le = now() WHERE id = d.id;
    PERFORM public.mail_systeme_poser_interne('Salon des gentlemen', d.auteur, 'Défi refusé', a || ' a décliné votre défi au backgammon.', NULL);
    r := jsonb_build_object('ok', true, 'accepte', false, 'defi', d.id);
    INSERT INTO public.hotel_teaser_actes (acteur, requete, resultat) VALUES (a, p_requete, r);
    RETURN r;
  END IF;
  SELECT name, stats, country, current_city, current_building, current_room INTO pc FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  SELECT name, stats, country, current_city, current_building, current_room INTO pa_ FROM public.personnages_donnees WHERE name = d.auteur FOR UPDATE;
  IF pc.country IS DISTINCT FROM 'khalija' OR pc.current_building IS DISTINCT FROM 'hotel-republica' OR pc.current_room IS DISTINCT FROM 'salon_gentlemen'
     OR (pa_.country, pa_.current_city, pa_.current_building, pa_.current_room) IS DISTINCT FROM (pc.country, pc.current_city, pc.current_building, pc.current_room) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_absente'); END IF;
  -- Les deux mises sont prélevées ensemble : si l'un ne peut pas payer, la partie n'a pas lieu et rien n'est prélevé.
  IF NOT public.helvetia_debiter_fonds_ordinaires(a, d.mise) THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'); END IF;
  IF NOT public.helvetia_debiter_fonds_ordinaires(d.auteur, d.mise) THEN
    RAISE EXCEPTION 'fonds_insuffisants_adversaire' USING HINT = 'aucun prélèvement conservé'; END IF;
  v_taux := least(100, greatest(0, 50 + 2 * (public.hotel_teaser_stat_interne(pa_.stats, 'INT') - public.hotel_teaser_stat_interne(pc.stats, 'INT'))));
  v_jet := floor(random() * 100)::integer + 1;
  IF v_jet <= v_taux THEN v_g := d.auteur; v_p := a; ELSE v_g := a; v_p := d.auteur; END IF;
  UPDATE public.personnages_donnees SET liquide = coalesce(liquide, 0) + 2 * d.mise, updated_at = now() WHERE name = v_g;
  PERFORM public.personnage_ajuster_pop_inf(v_g, 2, NULL);
  UPDATE public.hotel_backgammon_defis SET statut = 'accepte', gagnant = v_g, resolu_le = now() WHERE id = d.id;
  PERFORM public.mail_systeme_poser_interne('Salon des gentlemen', d.auteur, 'Partie de backgammon',
    'Partie contre ' || a || ' pour ' || d.mise || ' DR : ' || CASE WHEN v_g = d.auteur THEN 'vous gagnez la mise.' ELSE 'vous perdez la mise.' END, NULL);
  r := jsonb_build_object('ok', true, 'accepte', true, 'defi', d.id, 'gagnant', v_g, 'perdant', v_p, 'mise', d.mise,
                          'gagne', v_g = a, 'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = a));
  INSERT INTO public.hotel_teaser_actes (acteur, requete, resultat) VALUES (a, p_requete, r);
  RETURN r;
END $$;

-- 6. Tirade unique de Don Augusto Bigotes (une fois par joueur, la première fois qu'il s'adresse à Svetlana ou à Valentina).
CREATE OR REPLACE FUNCTION public.ciudad_roja_augusto_tirade()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); n integer;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = a AND country = 'narco' AND current_city = 'capitale'
                  AND current_building = 'hotel-republica' AND current_room = 'piscine') THEN
    RETURN jsonb_build_object('ok', true, 'tirade', false); END IF;
  INSERT INTO public.ciudad_roja_augusto_tirades (personnage) VALUES (a) ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'tirade', n = 1);
END $$;

-- 7. Journal des passages et mémoire des PNJ référents.
CREATE OR REPLACE FUNCTION public.hotel_teaser_visite_trg()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  INSERT INTO public.hotel_teaser_visites (personnage, pays, piece, jour, n)
  VALUES (NEW.name, NEW.country, NEW.current_room, (now() AT TIME ZONE 'Europe/Paris')::date, 1)
  ON CONFLICT (personnage, pays, piece, jour) DO UPDATE SET n = public.hotel_teaser_visites.n + 1;
  RETURN NULL;
EXCEPTION WHEN others THEN RETURN NULL; -- un journal perdu ne doit jamais bloquer un déplacement
END $$;
DROP TRIGGER IF EXISTS hotel_teaser_visite ON public.personnages_donnees;
CREATE TRIGGER hotel_teaser_visite AFTER UPDATE OF current_room ON public.personnages_donnees
  FOR EACH ROW WHEN (NEW.current_building = 'hotel-republica' AND NEW.current_city = 'capitale' AND NEW.country IN ('narco', 'khalija')
                     AND NEW.user_id IS NOT NULL AND NEW.current_room IS NOT NULL AND NEW.current_room IS DISTINCT FROM OLD.current_room)
  EXECUTE FUNCTION public.hotel_teaser_visite_trg();

CREATE OR REPLACE FUNCTION public.hotel_teaser_habitues(p_pnj text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); v_pays text; v_pieces text[];
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT m.pays, m.pieces INTO v_pays, v_pieces FROM (VALUES
    ('matias_bandeja', 'narco', ARRAY['restaurant']), ('rosario_esmeralda', 'narco', NULL::text[]),
    ('karim_sahn', 'khalija', ARRAY['restaurant']), ('faris_dukhan', 'khalija', ARRAY['salon_gentlemen']),
    ('amira_miftah', 'khalija', NULL::text[])) m(pnj, pays, pieces) WHERE m.pnj = p_pnj;
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pnj_non_referent'); END IF;
  RETURN jsonb_build_object('ok', true, 'pnj', p_pnj, 'habitues',
    (SELECT coalesce(jsonb_agg(jsonb_build_object('nom', personnage, 'passages', s, 'dernier', d) ORDER BY s DESC), '[]'::jsonb)
       FROM (SELECT personnage, sum(n) s, max(jour) d FROM public.hotel_teaser_visites
              WHERE pays = v_pays AND (v_pieces IS NULL OR piece = ANY (v_pieces)) AND jour >= (now() AT TIME ZONE 'Europe/Paris')::date - 30
              GROUP BY personnage ORDER BY sum(n) DESC LIMIT 12) t));
END $$;

-- 8. Escorts de Ciudad Roja : la suite (pièce « chambres ») d'un client de l'hôtel ; catalogue international + trois escorts de l'hôtel.
INSERT INTO public.escorts_catalogue (escort_id, pays, nom, genre, portrait, vignette, rang, actif) VALUES
 ('escort_svetlana_zolotova', 'narco', 'Svetlana Zolotova', 'F', '', '', 20, true),
 ('escort_valentina_fuego', 'narco', 'Valentina Fuego', 'F', '', '', 21, true),
 ('escort_rafael_toro', 'narco', 'Rafael Toro', 'H', '', '', 22, true)
ON CONFLICT (escort_id) DO UPDATE SET nom = EXCLUDED.nom, genre = EXCLUDED.genre, actif = true;

SELECT pg_temp.rp_remplacer('public.escort_lieu_appel_interne(text)'::regprocedure,
  '  IF v IS NOT NULL THEN RETURN v; END IF;',
  '  IF v IS NOT NULL THEN RETURN v; END IF;
  -- ciudad_roja_escorts_v1 (Fred, 28/11/2026) : la suite de l''Hotel Ciudad Roja, pour un client de l''hôtel (nuitée de moins de 36 h).
  IF EXISTS (SELECT 1 FROM public.personnages_donnees pd
              WHERE pd.name = p_nom AND pd.country = ''narco'' AND pd.current_city = ''capitale''
                AND pd.current_building = ''hotel-republica'' AND pd.current_room = ''chambres''
                AND EXISTS (SELECT 1 FROM public.hotel_nuitees n WHERE n.personnage_id = pd.id AND n.country = ''narco''
                             AND n.city = ''capitale'' AND n.building_id = ''hotel-republica'' AND n.cree_le > now() - interval ''36 hours'')) THEN
    RETURN jsonb_build_object(''batiment'', ''hotel-republica'', ''piece'', ''chambres'', ''lieu'', ''ciudad_roja'');
  END IF;',
  'ciudad_roja_escorts_v1');

CREATE OR REPLACE FUNCTION public.escort_disponibles_interne(p_nom text, p_genre text)
 RETURNS SETOF escorts_catalogue
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT c.* FROM public.escorts_catalogue c
   WHERE c.actif AND c.genre = p_genre
     AND c.pays = ANY (CASE
       WHEN public.escort_lieu_appel_interne(p_nom)->>'lieu' = 'clinique' THEN ARRAY['clinique']
       -- ciudad_roja_escorts_v1 : les 7 escorts internationales et les 3 de l'hôtel.
       WHEN public.escort_lieu_appel_interne(p_nom)->>'lieu' = 'ciudad_roja' THEN ARRAY['republic', 'narco']
       WHEN (SELECT country FROM public.personnages_donnees WHERE name = p_nom) = 'soviet' THEN ARRAY['republic', 'soviet']
       ELSE ARRAY['republic'] END)
     AND NOT EXISTS (SELECT 1 FROM public.pnj_membres m WHERE m.id = public.employe_pnj_id(p_nom, 'escort', c.escort_id) AND m.statut = 'actif') $function$;

-- Confidences : Svetlana travaille pour la Sécurité du Peuple de Sovarka, Valentina et Rafael pour l'Intérieur d'El Estado
-- (dossier conservé même si le poste est vacant). Les 7 escorts du catalogue ne renseignent personne à Ciudad Roja
-- (la règle existante ne transmet que les confidences recueillies en Sovarka).
CREATE OR REPLACE FUNCTION public.escort_secret_transmettre_trg()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_pays text; v_exp text;
BEGIN
  IF NEW.mode_acquisition NOT IN ('confidence', 'transmission')
     OR NOT EXISTS (SELECT 1 FROM public.escorts_catalogue c WHERE c.nom = NEW.titulaire) THEN RETURN NULL; END IF;
  v_pays := CASE WHEN NEW.titulaire = 'Svetlana Zolotova' THEN 'soviet'
                 WHEN NEW.titulaire IN ('Valentina Fuego', 'Rafael Toro') THEN 'narco'
                 WHEN EXISTS (SELECT 1 FROM public.personnages_donnees p WHERE p.name = NEW.source AND p.country = 'soviet') THEN 'soviet'
                 ELSE NULL END;
  IF v_pays IS NULL THEN RETURN NULL; END IF;
  v_exp := CASE v_pays WHEN 'narco' THEN 'Ministère de l''Intérieur d''El Estado' ELSE 'Ministère de la Sécurité du Peuple' END;
  BEGIN
    PERFORM public.interieur_dossier_deposer_interne(v_pays, 'secret_escort', NEW.source,
      'Confidence de ' || NEW.source || ' à ' || NEW.titulaire, NEW.contenu,
      jsonb_build_object('escort', NEW.titulaire, 'mode', NEW.mode_acquisition),
      v_exp, 'Confidence recueillie — ' || NEW.source,
      NEW.titulaire || CASE WHEN v_pays = 'narco' OR NEW.titulaire = 'Svetlana Zolotova' THEN ', de l''Hotel Ciudad Roja,' ELSE ', de l''agence Roxane Velours,' END
      || ' rapporte ceci :' || E'\n\n' || NEW.contenu
      || E'\n\nLe dossier est conservé dans votre bureau (« Dossiers confidentiels »).');
  EXCEPTION WHEN others THEN NULL; -- un rapport perdu ne doit jamais empêcher la confidence elle-même
  END;
  RETURN NULL;
END $function$;

-- 9. Canicule : la piscine et le jus de fruits frais protègent comme une bouteille d'eau, sans la consommer et sans risque.
SELECT pg_temp.rp_remplacer('public.climat_canicule_appliquer_interne(climat_evenements)'::regprocedure,
  'IF v_eau THEN UPDATE public.personnages_donnees SET inventory',
  'IF public.hotel_protection_chaleur_interne(p.name) THEN v_pa := p.pa; /* hotel_protection_chaleur_v1 */ ELSIF v_eau THEN UPDATE public.personnages_donnees SET inventory',
  'hotel_protection_chaleur_v1');
SELECT pg_temp.rp_remplacer('public.climat_canicule_appliquer_interne(climat_evenements)'::regprocedure,
  'PERFORM public.maladie_tirer_interne(p.name, ''coup_de_chaleur'', v_pct, ''canicule'');',
  'IF NOT public.hotel_protection_chaleur_interne(p.name) THEN PERFORM public.maladie_tirer_interne(p.name, ''coup_de_chaleur'', v_pct, ''canicule''); END IF; /* hotel_protection_chaleur_v2 */',
  'hotel_protection_chaleur_v2');

-- 10. Verrou de navigation : les pièces réservées de l'Hôtel Royal se gardent comme celles du Pavillon.
SELECT pg_temp.rp_remplacer('public.navigation_interieure_personnage_interne(text,text,text,boolean)'::regprocedure,
  ' IF p.country=''soviet'' AND p.current_city=''capitale'' AND p_batiment IN (''pavillon-ambassadeurs-novomirsk'',''residence-imperiale-novomirsk'') THEN',
  ' IF p.country=''soviet'' AND p.current_city=''capitale'' AND p_batiment IN (''pavillon-ambassadeurs-novomirsk'',''residence-imperiale-novomirsk'')
    OR p.country=''khalija'' AND p.current_city=''capitale'' AND p_batiment=''hotel-republica'' /* hotel_royal_navigation_v1 */ THEN',
  'hotel_royal_navigation_v1');

REVOKE ALL ON FUNCTION public.hotel_teaser_agir(uuid, text, text, integer), public.hotel_backgammon_lister(),
  public.hotel_backgammon_repondre(uuid, bigint, boolean), public.ciudad_roja_augusto_tirade(), public.hotel_teaser_habitues(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.hotel_teaser_agir(uuid, text, text, integer), public.hotel_backgammon_lister(),
  public.hotel_backgammon_repondre(uuid, bigint, boolean), public.ciudad_roja_augusto_tirade(), public.hotel_teaser_habitues(text) TO authenticated;
REVOKE ALL ON FUNCTION public.hotel_teaser_stat_interne(jsonb, text, integer), public.hotel_teaser_compter_interne(text, text, text, integer),
  public.hotel_teaser_effet_poser_interne(text, text, jsonb, text, integer, boolean), public.hotel_protection_chaleur_interne(text),
  public.hotel_teaser_apprendre_interne(text, text, text, text, text, text), public.hotel_teaser_visite_trg() FROM PUBLIC, anon, authenticated;

COMMIT;
