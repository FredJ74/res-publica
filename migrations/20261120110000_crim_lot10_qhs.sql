-- CRIMINALITÉ — LOT 10 : ENVOI AU QHS (GAME-DESIGN-CRIMINALITE.md § 16 ; Fred, 19/11/2026, nuit).
-- • Le QHS est un RÉGIME, pas une peine : le détenu y purge le reste de sa peine (même détention, detention_qhs_poser_interne)
--   et sort libre à la fin (detention_clore_interne, retour à la ville de sa détention). La durée libre de 1 jour à 10 ans de
--   detention_transferer_qhs disparaît hors Sovarka (refus qhs_decision_ministre).
-- • Décision : le Ministre de la Justice (PJ) ; à défaut (poste vacant ou PNJ), le Premier ministre (PJ) ; sans eux, toute
--   demande est refusée automatiquement. Trois réponses : valider (envoi direct), soumettre au référendum, refuser.
--   Un juge propose l'envoi en prononçant la sanction « qhs » (première instance) : c'est une peine de prison au barème
--   (±50 %, section 14) assortie d'une proposition au Ministre (crim_qhs_demandes) ; plus aucun envoi direct par le juge.
-- • Envoi direct : −5 POP par membre du gouvernement (Premier ministre et ministres PJ), −10 au décideur, rumeur sur le
--   modèle de la torture (popPerdu = perte du décideur, récupérable par démenti). Référendum perdu puis passé outre : double.
-- • Référendum : gratuit ; électeurs = PJ domiciliés dans le pays (toute nationalité), une voix, 24 h, courrier à chacun ;
--   bloc PNJ de 10 voix (part de oui 50 ± Sécurité/2 ± Moral/4 ∓ POP du détenu/2, bornes 10-90) ; égalité = non ;
--   oui = envoi sans pénalité ; non = le détenu reste en cellule, sauf si le gouvernement passe outre.
-- • Plus aucun envoi automatique hors Sovarka : sentence QHS du juge (proposition), justice_prolonger_peine / _soi /
--   detention_ouvrir_soi (drapeau QHS ignoré hors Sovarka), subtilisation d'explosifs militaires (détention ordinaire au barème).
-- • Sovarka : le goulag est son QHS ; règles d'envoi existantes inchangées, ni pénalité ni référendum (RPC refusées).
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN
    RAISE EXCEPTION '% : ancrage introuvable ou multiple (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

-- ── Paramètres (Républia ; les autres empires reprennent Républia) ──────────────────────────────────────────────────
INSERT INTO public.crim_parametres (cle, valeur)
SELECT v.cle, v.valeur FROM (VALUES
  ('qhs_penalite_gouvernement', 5), ('qhs_penalite_ministre', 10), ('qhs_referendum_heures', 24),
  ('qhs_pnj_voix', 10), ('qhs_pnj_part_min', 10), ('qhs_pnj_part_max', 90),
  ('peine_jours_vol_materiel_militaire_republic', 2)) v(cle, valeur)
WHERE NOT EXISTS (SELECT 1 FROM public.crim_parametres p WHERE p.cle = v.cle);

-- ── Demandes d'envoi et référendums ─────────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.crim_qhs_demandes (
  id bigserial PRIMARY KEY,
  pays text NOT NULL,
  detenu text NOT NULL,
  detention_id text,
  origine text NOT NULL CHECK (origine IN ('juge', 'ministre')),
  juge text,
  jugement_id text,
  motif text,
  statut text NOT NULL DEFAULT 'en_attente'
    CHECK (statut IN ('en_attente', 'referendum', 'referendum_non', 'envoye', 'refuse', 'caduque')),
  decideur text,
  role_decideur text,
  decision text,
  referendum_cloture timestamptz,
  bulletins jsonb NOT NULL DEFAULT '{}'::jsonb,
  depouillement jsonb,
  penalite jsonb,
  cree_le timestamptz NOT NULL DEFAULT now(),
  maj_le timestamptz NOT NULL DEFAULT now());
CREATE UNIQUE INDEX IF NOT EXISTS crim_qhs_demandes_ouverte
  ON public.crim_qhs_demandes (detenu) WHERE statut IN ('en_attente', 'referendum', 'referendum_non');
ALTER TABLE public.crim_qhs_demandes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.crim_qhs_demandes FROM anon, authenticated;
COMMENT ON TABLE public.crim_qhs_demandes IS
  'Envoi au QHS (§ 16) : proposition du juge ou initiative du décideur, réponse (envoi direct, référendum, refus), bulletins du référendum (PJ domiciliés), dépouillement avec le bloc PNJ, pénalité. Criminalité lot 10, 20/11/2026.';

-- ── Qui gouverne ────────────────────────────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.crim_qhs_pays_mandat_interne(p_nom text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce((SELECT a.country FROM public.postes_attribues a
                    WHERE a.titulaire = p.name AND a.poste_id = p.poste ->> 'id'
                    ORDER BY a.updated_at DESC NULLS LAST LIMIT 1), p.country)
    FROM public.personnages_donnees p WHERE p.name = p_nom $$;

-- Titulaire PJ d'un poste national (un PNJ n'a pas de fiche jouée : poste « vacant ou tenu par un PNJ » = NULL).
CREATE OR REPLACE FUNCTION public.crim_qhs_titulaire_interne(p_pays text, p_poste text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT p.name FROM public.personnages_donnees p
   WHERE p.user_id IS NOT NULL AND p.poste ->> 'id' = p_poste
     AND public.crim_qhs_pays_mandat_interne(p.name) = p_pays
   ORDER BY p.name LIMIT 1 $$;

-- Membres PJ du gouvernement : Premier ministre et ministres (le Président n'en fait pas partie).
CREATE OR REPLACE FUNCTION public.crim_qhs_gouvernement_interne(p_pays text)
RETURNS SETOF text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT p.name FROM public.personnages_donnees p
   WHERE p.user_id IS NOT NULL AND (p.poste ->> 'id' = 'pm' OR p.poste ->> 'id' LIKE 'min\_%')
     AND public.crim_qhs_pays_mandat_interne(p.name) = p_pays
   ORDER BY p.name $$;

-- Décideur : Ministre de la Justice PJ, sinon Premier ministre PJ (suppléance), sinon personne (refus automatique).
CREATE OR REPLACE FUNCTION public.crim_qhs_decideur_interne(p_pays text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v text;
BEGIN
  IF p_pays IS NULL OR p_pays = 'soviet' THEN RETURN NULL; END IF;
  v := public.crim_qhs_titulaire_interne(p_pays, 'min_just');
  IF v IS NOT NULL THEN RETURN jsonb_build_object('nom', v, 'role', 'min_just'); END IF;
  v := public.crim_qhs_titulaire_interne(p_pays, 'pm');
  IF v IS NOT NULL THEN RETURN jsonb_build_object('nom', v, 'role', 'pm'); END IF;
  RETURN NULL;
END $$;

-- ── Bloc PNJ ────────────────────────────────────────────────────────────────────────────────────────────────────────
-- Indices du pays : ligne nationale <pays>_national si elle existe, sinon moyenne des villes du pays ; 50 à défaut.
CREATE OR REPLACE FUNCTION public.crim_qhs_indices_pays_interne(p_pays text)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('securite', round(coalesce(n.sec, v.sec, 50), 2), 'moral', round(coalesce(n.mor, v.mor, 50), 2))
    FROM (SELECT avg(nullif(i.data ->> 'isn', '')::numeric) sec, avg(nullif(i.data ->> 'moral', '')::numeric) mor
            FROM public.indices_villes i WHERE i.id = p_pays || '_national') n,
         (SELECT avg(nullif(i.data ->> 'isn', '')::numeric) sec, avg(nullif(i.data ->> 'moral', '')::numeric) mor
            FROM public.indices_villes i JOIN public.villes w ON w.pays = p_pays AND i.id = w.pays || '_' || w.ville) v $$;

-- Part de oui : 50 ; +1 par 2 points de Sécurité sous 50 (−1 au-dessus) ; +1 par 4 points de Moral sous 50 (−1 au-dessus) ;
-- −1 par 2 points de POP du détenu au-dessus de 50 (+1 en dessous) ; bornes 10-90. Points entiers (troncature).
CREATE OR REPLACE FUNCTION public.crim_qhs_part_oui_interne(p_securite numeric, p_moral numeric, p_pop numeric)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT least(public.crim_param_interne('qhs_pnj_part_max', 90), greatest(public.crim_param_interne('qhs_pnj_part_min', 10),
    50 + trunc((50 - coalesce(p_securite, 50)) / 2) + trunc((50 - coalesce(p_moral, 50)) / 4)
       - trunc((coalesce(p_pop, 50) - 50) / 2)))::integer $$;

-- Voix PNJ pour le oui : part × 10 voix, arrondie au plus proche (0,5 vers le haut).
CREATE OR REPLACE FUNCTION public.crim_qhs_pnj_oui_interne(p_part integer)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT round(p_part * public.crim_param_interne('qhs_pnj_voix', 10) / 100.0)::integer $$;

-- ── Effets ──────────────────────────────────────────────────────────────────────────────────────────────────────────
-- Transfert : même détention, reste de la peine ; retour à la ville de la détention à la sortie.
CREATE OR REPLACE FUNCTION public.crim_qhs_transferer_interne(p_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE d record; v_det record;
BEGIN
  SELECT * INTO d FROM public.crim_qhs_demandes WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'demande_introuvable'); END IF;
  SELECT * INTO v_det FROM public.detention_active(d.detenu);
  IF v_det.id IS NULL OR v_det.country IS DISTINCT FROM d.pays OR v_det.qhs THEN
    UPDATE public.crim_qhs_demandes SET statut = 'caduque', decision = coalesce(decision, 'caduque'), maj_le = now() WHERE id = p_id;
    RETURN jsonb_build_object('ok', false, 'raison', CASE WHEN v_det.qhs THEN 'deja_qhs' ELSE 'detenu_libere' END);
  END IF;
  UPDATE public.personnages_donnees SET est_emprisonne = est_emprisonne || jsonb_build_object('retourVille', v_det.city)
   WHERE name = d.detenu AND jsonb_typeof(est_emprisonne) = 'object' AND nullif(est_emprisonne ->> 'retourVille', '') IS NULL;
  PERFORM public.detention_qhs_poser_interne(d.detenu, v_det.id, coalesce(nullif(d.motif, ''), 'Décision du gouvernement'));
  UPDATE public.crim_qhs_demandes SET statut = 'envoye', detention_id = v_det.id, maj_le = now() WHERE id = p_id;
  PERFORM public.mail_systeme_poser_interne('Ministère de la Justice', d.detenu, 'Transfert au QHS',
    'Vous êtes transféré(e) au quartier de haute sécurité. Vous y purgez le reste de votre peine, sans un jour de plus ; vous sortirez libre à son terme.');
  RETURN jsonb_build_object('ok', true, 'detention_id', v_det.id, 'jour_fin', v_det.jour_fin);
END $$;

-- Pénalité de l'envoi sans consultation (facteur 1) ou malgré le non (facteur 2), et rumeur sur le modèle de la torture.
CREATE OR REPLACE FUNCTION public.crim_qhs_penaliser_interne(p_pays text, p_decideur jsonb, p_facteur integer, p_detenu text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_g integer := public.crim_param_interne('qhs_penalite_gouvernement', 5)::integer * p_facteur;
  v_m integer := public.crim_param_interne('qhs_penalite_ministre', 10)::integer * p_facteur;
  v_chef text := p_decideur ->> 'nom'; v_nom text; v_perte integer; v_liste jsonb := '[]'::jsonb; v_rumeur text; v_vu boolean := false;
BEGIN
  FOR v_nom IN SELECT g FROM public.crim_qhs_gouvernement_interne(p_pays) g LOOP
    v_perte := CASE WHEN v_nom = v_chef THEN v_m ELSE v_g END;
    v_vu := v_vu OR v_nom = v_chef;
    PERFORM public.rumeur_pop_retirer_interne(v_nom, v_perte);
    v_liste := v_liste || jsonb_build_object('nom', v_nom, 'perte', v_perte);
  END LOOP;
  IF v_chef IS NOT NULL AND NOT v_vu THEN
    PERFORM public.rumeur_pop_retirer_interne(v_chef, v_m);
    v_liste := v_liste || jsonb_build_object('nom', v_chef, 'perte', v_m);
  END IF;
  v_rumeur := 'rumeur-' || replace(gen_random_uuid()::text, '-', '');
  INSERT INTO public.rumeurs_actives (id, resolu, data)
  VALUES (v_rumeur, false, jsonb_build_object('cible', v_chef,
    'contenu', CASE WHEN p_decideur ->> 'role' = 'pm' THEN 'Le Premier ministre' ELSE 'Le Ministre de la Justice' END
               || ' aurait fait envoyer ' || p_detenu || ' au QHS '
               || CASE WHEN p_facteur > 1 THEN 'malgré le non du référendum.' ELSE 'sans consulter personne.' END,
    'auteur', 'Anonyme', 'jour', public.jour_de_jeu_pays(p_pays), 'popPerdu', v_m));
  RETURN jsonb_build_object('facteur', p_facteur, 'perte_decideur', v_m, 'perte_membre', v_g, 'membres', v_liste, 'rumeur', v_rumeur);
END $$;

-- Demande (proposition du juge ou initiative du décideur). Une seule demande ouverte par détenu.
CREATE OR REPLACE FUNCTION public.crim_qhs_demande_creer_interne(p_pays text, p_detenu text, p_origine text, p_juge text,
  p_jugement text, p_motif text)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_id bigint; v_dec jsonb; v_det record;
BEGIN
  IF p_pays IS NULL OR p_pays = 'soviet' THEN RETURN NULL; END IF;
  SELECT id INTO v_id FROM public.crim_qhs_demandes
   WHERE detenu = p_detenu AND statut IN ('en_attente', 'referendum', 'referendum_non') FOR UPDATE;
  IF v_id IS NOT NULL THEN RETURN v_id; END IF;
  v_dec := public.crim_qhs_decideur_interne(p_pays);
  SELECT * INTO v_det FROM public.detention_active(p_detenu);
  INSERT INTO public.crim_qhs_demandes (pays, detenu, detention_id, origine, juge, jugement_id, motif)
  VALUES (p_pays, p_detenu, v_det.id, p_origine, p_juge, p_jugement, p_motif) RETURNING id INTO v_id;
  IF v_dec IS NULL THEN
    UPDATE public.crim_qhs_demandes SET statut = 'refuse', decision = 'refus_automatique', maj_le = now() WHERE id = v_id;
    IF p_juge IS NOT NULL THEN
      PERFORM public.mail_systeme_poser_interne('Ministère de la Justice', p_juge, 'Proposition d''envoi au QHS refusée',
        'Ni Ministre de la Justice ni Premier ministre en exercice : par prudence, la proposition d''envoyer ' || p_detenu
        || ' au QHS est refusée. Le détenu reste en cellule ordinaire.');
    END IF;
  ELSIF p_origine = 'juge' THEN
    PERFORM public.mail_systeme_poser_interne('Ministère de la Justice', v_dec ->> 'nom', 'Proposition d''envoi au QHS',
      'Le juge ' || coalesce(p_juge, '?') || ' propose d''envoyer ' || p_detenu || ' au quartier de haute sécurité'
      || coalesce(' (' || nullif(p_motif, '') || ')', '') || '. Trois réponses : valider l''envoi (ressenti comme un abus de pouvoir : '
      || 'popularité du gouvernement en baisse et rumeur), le soumettre au référendum, ou le refuser.<br><br>'
      || '[[act:qhs_decider|' || v_id || ']]');
  END IF;
  RETURN v_id;
END $$;

-- Ouverture du référendum : 24 h, courrier à chaque PJ domicilié dans le pays (toute nationalité).
CREATE OR REPLACE FUNCTION public.crim_qhs_referendum_ouvrir_interne(p_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE d record; v_cloture timestamptz; v_n integer := 0; v_e record;
BEGIN
  SELECT * INTO d FROM public.crim_qhs_demandes WHERE id = p_id FOR UPDATE;
  v_cloture := now() + make_interval(hours => public.crim_param_interne('qhs_referendum_heures', 24)::integer);
  UPDATE public.crim_qhs_demandes SET statut = 'referendum', decision = 'referendum', referendum_cloture = v_cloture,
         bulletins = '{}'::jsonb, maj_le = now() WHERE id = p_id;
  FOR v_e IN SELECT name FROM public.personnages_donnees
              WHERE user_id IS NOT NULL AND domicile ->> 'country' = d.pays ORDER BY name LOOP
    PERFORM public.mail_systeme_poser_interne('Ministère de la Justice', v_e.name, 'Référendum : envoi de ' || d.detenu || ' au QHS',
      'Le gouvernement vous consulte : faut-il envoyer ' || d.detenu || coalesce(' (' || nullif(d.motif, '') || ')', '')
      || ' au quartier de haute sécurité ? Le détenu y purgerait le reste de sa peine. Une voix par personne domiciliée dans le pays ; '
      || 'vote ouvert 24 heures. Les habitants non joueurs comptent pour 10 voix. En cas d''égalité, le non l''emporte.<br><br>'
      || '[[act:qhs_oui|' || p_id || ']][[act:qhs_non|' || p_id || ']]');
    v_n := v_n + 1;
  END LOOP;
  PERFORM public.annonce_publique_interne(d.pays, '🗳 Référendum : faut-il envoyer ' || d.detenu
    || ' au QHS ? Vote ouvert 24 heures pour les personnes domiciliées dans le pays.');
  RETURN jsonb_build_object('ok', true, 'electeurs', v_n, 'cloture', v_cloture);
END $$;

-- Dépouillement : voix des PJ + bloc PNJ ; égalité = non ; oui = envoi sans pénalité ; non = le décideur est prévenu.
CREATE OR REPLACE FUNCTION public.crim_qhs_referendum_clore_interne(p_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE d record; v_ind jsonb; v_pop numeric; v_part integer; v_pnj_oui integer; v_voix integer;
  v_pj_oui integer; v_pj_non integer; v_oui integer; v_non integer; v_res text; v_dep jsonb; v_tr jsonb; v_dec jsonb;
BEGIN
  SELECT * INTO d FROM public.crim_qhs_demandes WHERE id = p_id FOR UPDATE;
  IF NOT FOUND OR d.statut <> 'referendum' THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_referendum'); END IF;
  IF now() < d.referendum_cloture THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_echu'); END IF;
  SELECT count(*) FILTER (WHERE value = '"oui"'), count(*) FILTER (WHERE value = '"non"')
    INTO v_pj_oui, v_pj_non FROM jsonb_each(d.bulletins);
  v_ind := public.crim_qhs_indices_pays_interne(d.pays);
  SELECT CASE WHEN jsonb_typeof(resources -> 'pop') = 'number' THEN (resources ->> 'pop')::numeric END INTO v_pop
    FROM public.personnages_donnees WHERE name = d.detenu;
  v_part := public.crim_qhs_part_oui_interne((v_ind ->> 'securite')::numeric, (v_ind ->> 'moral')::numeric, coalesce(v_pop, 50));
  v_voix := public.crim_param_interne('qhs_pnj_voix', 10)::integer;
  v_pnj_oui := public.crim_qhs_pnj_oui_interne(v_part);
  v_oui := v_pj_oui + v_pnj_oui; v_non := v_pj_non + (v_voix - v_pnj_oui);
  v_res := CASE WHEN v_oui > v_non THEN 'oui' ELSE 'non' END;
  v_dep := jsonb_build_object('pj_oui', v_pj_oui, 'pj_non', v_pj_non, 'part_oui_pnj', v_part, 'pnj_oui', v_pnj_oui,
    'pnj_non', v_voix - v_pnj_oui, 'oui', v_oui, 'non', v_non, 'resultat', v_res, 'securite', v_ind -> 'securite',
    'moral', v_ind -> 'moral', 'pop_detenu', coalesce(v_pop, 50));
  UPDATE public.crim_qhs_demandes SET depouillement = v_dep, maj_le = now() WHERE id = p_id;
  INSERT INTO public.evenements_globaux (country, city, texte, jour)
  VALUES (d.pays, NULL, '🗳 Référendum sur l''envoi de ' || d.detenu || ' au QHS : ' || v_oui || ' OUI / ' || v_non || ' NON. '
    || CASE WHEN v_res = 'oui' THEN 'Le détenu est transféré au QHS.' ELSE 'Le détenu reste en cellule ordinaire.' END, NULL);
  IF v_res = 'oui' THEN
    UPDATE public.crim_qhs_demandes SET decision = 'referendum_oui' WHERE id = p_id;
    v_tr := public.crim_qhs_transferer_interne(p_id);
  ELSE
    UPDATE public.crim_qhs_demandes SET statut = 'referendum_non', decision = 'referendum_non' WHERE id = p_id;
    v_dec := public.crim_qhs_decideur_interne(d.pays);
    IF v_dec IS NOT NULL THEN
      PERFORM public.mail_systeme_poser_interne('Ministère de la Justice', v_dec ->> 'nom', 'Référendum : le non l''emporte',
        'Le référendum sur l''envoi de ' || d.detenu || ' au QHS est perdu (' || v_oui || ' oui, ' || v_non || ' non). '
        || 'Le détenu reste en cellule ordinaire. L''envoyer quand même doublerait la pénalité.<br><br>[[act:qhs_decider|' || p_id || ']]');
    END IF;
  END IF;
  RETURN jsonb_build_object('ok', true, 'id', p_id, 'transfert', v_tr) || v_dep;
END $$;

-- Passe (pg_cron, toutes les heures, et à chaque lecture) : dépouillements échus, demandes caduques, refus automatiques.
CREATE OR REPLACE FUNCTION public.crim_qhs_passe()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_id bigint; v_n integer := 0; v_c integer; v_r integer;
BEGIN
  FOR v_id IN SELECT id FROM public.crim_qhs_demandes WHERE statut = 'referendum' AND referendum_cloture <= now() ORDER BY id LOOP
    PERFORM public.crim_qhs_referendum_clore_interne(v_id); v_n := v_n + 1;
  END LOOP;
  UPDATE public.crim_qhs_demandes d SET statut = 'caduque', decision = 'caduque', maj_le = now()
   WHERE d.statut IN ('en_attente', 'referendum', 'referendum_non')
     AND NOT EXISTS (SELECT 1 FROM public.detention_active(d.detenu) a WHERE a.country = d.pays AND NOT a.qhs);
  GET DIAGNOSTICS v_c = ROW_COUNT;
  UPDATE public.crim_qhs_demandes d SET statut = 'refuse', decision = 'refus_automatique', maj_le = now()
   WHERE d.statut IN ('en_attente', 'referendum_non') AND public.crim_qhs_decideur_interne(d.pays) IS NULL;
  GET DIAGNOSTICS v_r = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'depouilles', v_n, 'caduques', v_c, 'refus_automatiques', v_r);
END $$;

-- ── RPC ─────────────────────────────────────────────────────────────────────────────────────────────────────────────
-- Lecture : pour le décideur, demandes ouvertes et détenus ordinaires du pays ; pour tout électeur, référendums ouverts.
CREATE OR REPLACE FUNCTION public.crim_qhs_lire()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; v_pays text; v_dom text; v_dec jsonb; v_ref jsonb; v_dem jsonb; v_det jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  PERFORM public.crim_qhs_passe();
  v_pays := public.crim_qhs_pays_mandat_interne(v_moi);
  SELECT domicile ->> 'country' INTO v_dom FROM public.personnages_donnees WHERE name = v_moi;
  SELECT coalesce(jsonb_agg(jsonb_build_object('id', q.id, 'detenu', q.detenu, 'motif', q.motif, 'cloture', q.referendum_cloture,
           'a_vote', q.bulletins ? v_moi) ORDER BY q.id), '[]'::jsonb)
    INTO v_ref FROM public.crim_qhs_demandes q WHERE q.statut = 'referendum' AND q.pays = v_dom;
  IF v_pays = 'soviet' THEN
    RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'decideur', false, 'sovarka', true, 'referendums', v_ref);
  END IF;
  v_dec := public.crim_qhs_decideur_interne(v_pays);
  IF v_dec ->> 'nom' IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'decideur', false, 'referendums', v_ref);
  END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object('id', q.id, 'detenu', q.detenu, 'origine', q.origine, 'juge', q.juge, 'motif', q.motif,
           'statut', q.statut, 'cloture', q.referendum_cloture, 'depouillement', q.depouillement) ORDER BY q.id), '[]'::jsonb)
    INTO v_dem FROM public.crim_qhs_demandes q
   WHERE q.pays = v_pays AND q.statut IN ('en_attente', 'referendum', 'referendum_non');
  SELECT coalesce(jsonb_agg(jsonb_build_object('nom', d.nom, 'raison', d.raison, 'ville', d.city, 'jour_fin', d.jour_fin,
           'demande', (SELECT q.id FROM public.crim_qhs_demandes q WHERE q.detenu = d.nom
                        AND q.statut IN ('en_attente', 'referendum', 'referendum_non'))) ORDER BY d.nom), '[]'::jsonb)
    INTO v_det FROM public.detentions d
   WHERE d.country = v_pays AND d.mode_fin IS NULL AND d.jour_fin_effective IS NULL AND NOT coalesce(d.qhs, false)
     AND (SELECT a.id FROM public.detention_active(d.nom) a) = d.id;
  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'decideur', true, 'role', v_dec ->> 'role',
    'penalite_gouvernement', public.crim_param_interne('qhs_penalite_gouvernement', 5)::integer,
    'penalite_ministre', public.crim_param_interne('qhs_penalite_ministre', 10)::integer,
    'demandes', v_dem, 'detenus', v_det, 'referendums', v_ref);
END $$;

-- Réponse du décideur. p_demande : demande existante ; sinon p_detenu (initiative du décideur : valider ou référendum).
-- Réponses : valider, referendum, refuser (demande en attente) ; passer_outre, respecter (référendum perdu).
CREATE OR REPLACE FUNCTION public.crim_qhs_decider(p_demande bigint, p_detenu text, p_reponse text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; v_pays text; v_dec jsonb; v_id bigint := p_demande; d record; v_det record; v_r jsonb; v_pen jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_reponse IS NULL OR p_reponse NOT IN ('valider', 'referendum', 'refuser', 'passer_outre', 'respecter') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reponse_inconnue'); END IF;
  v_pays := public.crim_qhs_pays_mandat_interne(v_moi);
  IF v_pays = 'soviet' THEN RETURN jsonb_build_object('ok', false, 'raison', 'sovarka_goulag'); END IF;
  v_dec := public.crim_qhs_decideur_interne(v_pays);
  IF v_dec ->> 'nom' IS DISTINCT FROM v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_decideur'); END IF;
  IF (SELECT country FROM public.personnages_donnees WHERE name = v_moi) IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mandat_autre_pays'); END IF;
  PERFORM public.crim_qhs_passe();
  IF v_id IS NULL THEN
    IF p_reponse NOT IN ('valider', 'referendum') THEN RETURN jsonb_build_object('ok', false, 'raison', 'reponse_invalide'); END IF;
    SELECT * INTO v_det FROM public.detention_active(p_detenu);
    IF v_det.id IS NULL OR v_det.country IS DISTINCT FROM v_pays THEN RETURN jsonb_build_object('ok', false, 'raison', 'detenu_introuvable'); END IF;
    IF v_det.qhs THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_qhs'); END IF;
    v_id := public.crim_qhs_demande_creer_interne(v_pays, p_detenu, 'ministre', NULL, NULL,
      CASE WHEN v_dec ->> 'role' = 'pm' THEN 'Décision du Premier ministre' ELSE 'Décision du Ministre de la Justice' END);
  END IF;
  SELECT * INTO d FROM public.crim_qhs_demandes WHERE id = v_id AND pays = v_pays FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'demande_introuvable'); END IF;
  IF d.statut = 'en_attente' AND p_reponse IN ('valider', 'referendum', 'refuser') THEN
    UPDATE public.crim_qhs_demandes SET decideur = v_moi, role_decideur = v_dec ->> 'role', maj_le = now() WHERE id = v_id;
    IF p_reponse = 'valider' THEN
      v_r := public.crim_qhs_transferer_interne(v_id);
      IF NOT coalesce((v_r ->> 'ok')::boolean, false) THEN RETURN v_r; END IF;
      v_pen := public.crim_qhs_penaliser_interne(v_pays, v_dec, 1, d.detenu);
      UPDATE public.crim_qhs_demandes SET decision = 'envoi_direct', penalite = v_pen WHERE id = v_id;
    ELSIF p_reponse = 'referendum' THEN
      v_r := public.crim_qhs_referendum_ouvrir_interne(v_id);
    ELSE
      UPDATE public.crim_qhs_demandes SET statut = 'refuse', decision = 'refus' WHERE id = v_id;
      IF d.juge IS NOT NULL THEN
        PERFORM public.mail_systeme_poser_interne('Ministère de la Justice', d.juge, 'Proposition d''envoi au QHS refusée',
          'Votre proposition d''envoyer ' || d.detenu || ' au QHS est refusée. Le détenu reste en cellule ordinaire.');
      END IF;
    END IF;
  ELSIF d.statut = 'referendum_non' AND p_reponse IN ('passer_outre', 'respecter') THEN
    UPDATE public.crim_qhs_demandes SET decideur = v_moi, role_decideur = v_dec ->> 'role', maj_le = now() WHERE id = v_id;
    IF p_reponse = 'passer_outre' THEN
      v_r := public.crim_qhs_transferer_interne(v_id);
      IF NOT coalesce((v_r ->> 'ok')::boolean, false) THEN RETURN v_r; END IF;
      v_pen := public.crim_qhs_penaliser_interne(v_pays, v_dec, 2, d.detenu);
      UPDATE public.crim_qhs_demandes SET decision = 'passer_outre', penalite = v_pen WHERE id = v_id;
    ELSE
      UPDATE public.crim_qhs_demandes SET statut = 'refuse', decision = 'respecter' WHERE id = v_id;
    END IF;
  ELSIF d.statut = 'referendum' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'referendum_en_cours');
  ELSIF d.statut IN ('en_attente', 'referendum_non') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reponse_invalide');
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'demande_close');
  END IF;
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'reponse', p_reponse, 'detenu', d.detenu, 'resultat', v_r, 'penalite', v_pen,
    'pop', (SELECT CASE WHEN jsonb_typeof(resources -> 'pop') = 'number' THEN (resources ->> 'pop')::numeric END
              FROM public.personnages_donnees WHERE name = v_moi));
END $$;

-- Vote : PJ domicilié dans le pays du référendum, une voix, tant que le vote est ouvert.
CREATE OR REPLACE FUNCTION public.crim_qhs_voter(p_demande bigint, p_choix text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; d record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_choix IS NULL OR p_choix NOT IN ('oui', 'non') THEN RETURN jsonb_build_object('ok', false, 'raison', 'choix_invalide'); END IF;
  SELECT * INTO d FROM public.crim_qhs_demandes WHERE id = p_demande FOR UPDATE;
  IF NOT FOUND OR d.statut <> 'referendum' OR now() >= d.referendum_cloture THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'vote_ferme'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_moi AND user_id IS NOT NULL
                  AND domicile ->> 'country' = d.pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'non_domicilie'); END IF;
  IF d.bulletins ? v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_vote'); END IF;
  UPDATE public.crim_qhs_demandes SET bulletins = bulletins || jsonb_build_object(v_moi, p_choix), maj_le = now() WHERE id = p_demande;
  RETURN jsonb_build_object('ok', true, 'choix', p_choix, 'detenu', d.detenu);
END $$;

-- ── Raccords : plus aucun envoi automatique hors Sovarka ────────────────────────────────────────────────────────────
-- Juge : la sanction « qhs » hors Sovarka est une peine de prison au barème (±50 %) assortie d'une proposition au Ministre.
SELECT pg_temp.rp_raccorder('public.crim_peine_bornes_juge_interne(jsonb,jsonb,text)'::regprocedure,
  $a$OR p_calc ->> 'genre' IS DISTINCT FROM 'prison' THEN$a$,
  $b$OR (p_calc ->> 'genre' IS DISTINCT FROM 'prison' AND NOT (p_calc ->> 'genre' = 'qhs' AND p_pays IS DISTINCT FROM 'soviet')) /* crim_qhs_regime_v1 */ THEN$b$,
  'crim_qhs_regime_v1');
SELECT pg_temp.rp_raccorder('public.crim_peine_bornes_juge_interne(jsonb,jsonb,text)'::regprocedure,
  $a$    'etat_urgence', v_urg);$a$,
  $b$    'etat_urgence', v_urg) || CASE WHEN p_calc ->> 'genre' = 'qhs' THEN jsonb_build_object('impose', false, 'amende_min', 0,
    'amende_max', 0, 'amende_defaut', 0, 'proposition_qhs', true) ELSE '{}'::jsonb END; /* crim_qhs_regime_v2 */$b$,
  'crim_qhs_regime_v2');
SELECT pg_temp.rp_raccorder('public.justice_rendre_sentence(text,text,text,integer,integer)'::regprocedure,
  $a$    WHEN 'qhs'         THEN 'Envoi au QHS (' || v_jours || ' jours)'$a$,
  $b$    WHEN 'qhs'         THEN CASE WHEN v_pays = 'soviet' THEN 'Envoi au QHS (' || v_jours || ' jours)'
                                ELSE 'Prison ' || v_jours || ' jour' || CASE WHEN v_jours > 1 THEN 's' ELSE '' END
                                     || ', envoi au QHS proposé au Ministre de la Justice' END /* crim_qhs_libelle_v1 */$b$,
  'crim_qhs_libelle_v1');
SELECT pg_temp.rp_raccorder('public.justice_rendre_sentence(text,text,text,integer,integer)'::regprocedure,
  $a$    RETURN jsonb_build_object('ok', false, 'raison', 'jugement_deja_rendu');
  END IF;$a$,
  $b$    RETURN jsonb_build_object('ok', false, 'raison', 'jugement_deja_rendu');
  END IF;
  IF p_genre = 'qhs' AND v_pays IS DISTINCT FROM 'soviet' THEN /* crim_qhs_proposition_v1 */
    PERFORM public.crim_qhs_demande_creer_interne(v_pays, v_a ->> 'cible', 'juge', v_j.nom, v_jug, v_libelle);
  END IF;$b$,
  'crim_qhs_proposition_v1');
SELECT pg_temp.rp_raccorder('public.justice_appel_juger(text,text,text,text,integer,integer)'::regprocedure,
  $a$      WHEN 'qhs'         THEN 'Envoi au QHS (' || v_jours || ' jours)'$a$,
  $b$      WHEN 'qhs'         THEN CASE WHEN v_pays = 'soviet' THEN 'Envoi au QHS (' || v_jours || ' jours)'
                                  ELSE 'Prison ' || v_jours || ' jour' || CASE WHEN v_jours > 1 THEN 's' ELSE '' END END /* crim_qhs_libelle_appel_v1 */$b$,
  'crim_qhs_libelle_appel_v1');
SELECT pg_temp.rp_raccorder('public.justice_prolonger_peine(text,jsonb,boolean)'::regprocedure,
  $a$v_r := public.detention_prolonger_interne(p_cible, p_motifs, p_forcer_qhs);$a$,
  $b$v_r := public.detention_prolonger_interne(p_cible, p_motifs,
    p_forcer_qhs AND coalesce((SELECT a.country FROM public.detention_active(p_cible) a), '') = 'soviet' /* crim_qhs_juge_v1 */);$b$,
  'crim_qhs_juge_v1');
SELECT pg_temp.rp_raccorder('public.detention_prolonger_soi(jsonb,boolean)'::regprocedure,
  $a$RETURN public.detention_prolonger_interne(v_moi, p_motifs, p_forcer_qhs);$a$,
  $b$RETURN public.detention_prolonger_interne(v_moi, p_motifs,
    p_forcer_qhs AND coalesce((SELECT a.country FROM public.detention_active(v_moi) a), '') = 'soviet' /* crim_qhs_soi_v1 */);$b$,
  'crim_qhs_soi_v1');
SELECT pg_temp.rp_raccorder('public.detention_ouvrir_soi(text,integer,text,jsonb,boolean,jsonb)'::regprocedure,
  $a$  IF p_qhs THEN$a$,
  $b$  IF p_qhs AND v_pays = 'soviet' /* crim_qhs_soi_v2 */ THEN$b$,
  'crim_qhs_soi_v2');
SELECT pg_temp.rp_raccorder('public.detention_transferer_qhs(text,integer,text,jsonb)'::regprocedure,
  $a$  IF p_jours IS NULL OR p_jours <= 0 OR p_jours > 3650 THEN$a$,
  $b$  IF (SELECT country FROM public.personnages_donnees WHERE name = v_moi) IS DISTINCT FROM 'soviet' THEN /* crim_qhs_transfert_v1 */
    RETURN jsonb_build_object('ok',false,'raison','qhs_decision_ministre'); END IF;
  IF p_jours IS NULL OR p_jours <= 0 OR p_jours > 3650 THEN$b$,
  'crim_qhs_transfert_v1');
SELECT pg_temp.rp_raccorder('public.militaire_subtiliser_tenter(text)'::regprocedure,
  $a$'Vol de matériel militaire', 3, true, 'caserne')$a$,
  $b$'Vol de matériel militaire',
             CASE WHEN v_pj.country = 'soviet' THEN 3 ELSE public.crim_peine_jours_interne('vol_materiel_militaire', v_pj.country) END,
             v_pj.country = 'soviet' /* crim_qhs_militaire_v1 */, 'caserne')$b$,
  'crim_qhs_militaire_v1');

-- ── Droits et passe horaire ─────────────────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY['crim_qhs_pays_mandat_interne(text)', 'crim_qhs_titulaire_interne(text,text)',
    'crim_qhs_gouvernement_interne(text)', 'crim_qhs_decideur_interne(text)', 'crim_qhs_indices_pays_interne(text)',
    'crim_qhs_part_oui_interne(numeric,numeric,numeric)', 'crim_qhs_pnj_oui_interne(integer)', 'crim_qhs_transferer_interne(bigint)',
    'crim_qhs_penaliser_interne(text,jsonb,integer,text)', 'crim_qhs_demande_creer_interne(text,text,text,text,text,text)',
    'crim_qhs_referendum_ouvrir_interne(bigint)', 'crim_qhs_referendum_clore_interne(bigint)', 'crim_qhs_passe()'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon, authenticated', f);
  END LOOP;
  FOREACH f IN ARRAY ARRAY['crim_qhs_lire()', 'crim_qhs_decider(bigint,text,text)', 'crim_qhs_voter(bigint,text)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO authenticated', f);
  END LOOP;
  PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'crim_qhs_passe';
  PERFORM cron.schedule('crim_qhs_passe', '27 * * * *', 'SELECT public.crim_qhs_passe()');
END $$;

COMMIT;
