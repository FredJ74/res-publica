-- CLIMAT — décisions de Fred du 21/11/2026 sur les quatre questions (GAME-DESIGN-CLIMAT-20261121.md).
-- ⚠️ NON APPLIQUÉE : pause sur Supabase en production (Codex termine le goulag). Testée en local (PGlite,
--    outils/bancs/banc-climat-pglite-20261121.cjs). À appliquer seulement sur feu vert de Fred.
-- Règle d'application (Fred, 21/11 au soir) : aucun événement ne commence sans annonce 48 h avant. Les épisodes non annoncés
--    sont placés au plus tôt 48 h après maintenant ; les événements déjà annoncés qui commencent dans moins de 48 h gardent
--    date, heure et annonce (ils ont eu leur préavis) ; les alertes paraissent entre 49 et 48 h avant le début.
-- Q1 Heure de début tirée au hasard sur les 24 heures (une heure pleine, uniforme), durée inchangée (6 h ; blizzard 24 h) ;
--    l'alerte 48 h avant annonce l'heure exacte (heure du jeu). Appliqué aux événements déjà planifiés : chaque événement non
--    commencé reçoit une heure tirée au hasard ; s'il avait déjà été annoncé, il est annoncé de nouveau, avec l'heure.
-- Q2 Brouillard : 1 par mois et par ville. Calendrier recalculé : chaque événement garde sa date prévue (debut_prevu) ;
--    on place d'abord ce qui a commencé, puis ce qui est annoncé, puis crues, orages, canicules et blizzards à leur date,
--    puis les brouillards dans les créneaux libres ; toujours un seul épisode à la fois par pays et 48 h d'écart.
--    Les dates d'origine des événements déjà décalés le 21/11 (migration 20261121090000) sont restaurées depuis le
--    calendrier relevé le 21/11 à 13 h 49 UTC, avant ce décalage. Brouillards en trop : annulés (annule = true), jamais supprimés.
-- Q3 Catastrophe naturelle : une seule option, tous les sinistrés à 50 % des stocks perdus. Sinistré : lieu tiré, non
--    protégé, qui a réellement perdu des stocks. La fermeture n'est jamais indemnisée. Crue seulement.
-- Q4 Un sac de sable (60 FR, 1 PA) protège entièrement un lieu pour une crue ; toute trace de la règle du 19/11
--    (10 % par sac, 9 sacs) est retirée (fonctions, réglages, colonne « sacs » restée vide en production).
BEGIN;

-- ── Q1 : heure au hasard ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.climat_evenements ADD COLUMN IF NOT EXISTS debut_prevu timestamptz;
UPDATE public.climat_evenements SET debut_prevu = debut WHERE debut_prevu IS NULL;

CREATE OR REPLACE FUNCTION public.climat_heure_hasard_interne(p_jour date)
RETURNS timestamptz LANGUAGE sql VOLATILE AS $$
  SELECT public.climat_minuit_interne(p_jour) + make_interval(hours => floor(random() * 24)::integer);
$$;

CREATE OR REPLACE FUNCTION public.climat_creer_interne(p_type text, p_pays text, p_ville text, p_jour date, p_periode text, p_origine text)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE c public.climat_parametres; v_lieux jsonb := '[]'::jsonb; v_id bigint; v_debut timestamptz;
BEGIN
  SELECT * INTO c FROM public.climat_parametres WHERE type = p_type AND pays = p_pays;
  IF p_type = 'crue' THEN
    SELECT coalesce(jsonb_agg(jsonb_build_object('batiment', batiment, 'nom', nom)), '[]'::jsonb) INTO v_lieux
      FROM (SELECT batiment, nom FROM public.climat_zones_inondables
             WHERE pays = p_pays AND ville = p_ville AND NOT public.climat_lieu_est_gare_interne(batiment) /* climat_gare_jamais_v1 */
             ORDER BY random() LIMIT (2 + floor(random() * 2))::integer) z;
    IF jsonb_array_length(v_lieux) = 0 THEN RETURN NULL; END IF;
  END IF;
  v_debut := public.climat_heure_hasard_interne(p_jour) /* climat_heure_hasard_v1 */;
  INSERT INTO public.climat_evenements (type, pays, ville, debut, fin, periode, lieux, origine, debut_prevu)
  VALUES (p_type, p_pays, p_ville, v_debut, v_debut + make_interval(hours => coalesce(c.duree_heures, 24)), p_periode, v_lieux, p_origine, v_debut)
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;

-- Annonce : « le 08/12 à 14 h 00 (heure du jeu) ».
CREATE OR REPLACE FUNCTION public.climat_quand_interne(p_debut timestamptz)
RETURNS text LANGUAGE sql STABLE AS $$
  SELECT 'le ' || to_char(p_debut AT TIME ZONE 'Europe/Paris', 'DD/MM') || ' à ' || to_char(p_debut AT TIME ZONE 'Europe/Paris', 'HH24" h "MI') || ' (heure du jeu)';
$$;

CREATE OR REPLACE FUNCTION public.climat_texte_alerte_interne(e public.climat_evenements)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.climat_nom_type_interne(e.type) || ' annoncé' || CASE WHEN e.type IN ('crue', 'canicule') THEN 'e' ELSE '' END
      || ' à ' || public.climat_nom_ville_interne(e.pays, e.ville) || ' ' || public.climat_quand_interne(e.debut) /* climat_heure_hasard_v1 */
      || CASE WHEN e.type = 'crue' THEN ' (zone inondable menacée : ' || (SELECT string_agg(l->>'nom', ', ') FROM jsonb_array_elements(e.lieux) l) || ')' ELSE '' END
      || '. ' || coalesce(public.climat_consigne_interne(e.type, e.pays, e.ville), '') /* climat_consignes_v1 */;
$$;

-- Clé de l'article : l'heure en fait partie (un événement annoncé de nouveau à une autre heure a son propre article).
CREATE OR REPLACE FUNCTION public.climat_alertes_publier_interne()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE e public.climat_evenements; v_n integer := 0; v_txt text; v_cle text;
BEGIN
  FOR e IN SELECT ev.* FROM public.climat_evenements ev JOIN public.climat_parametres c ON c.type = ev.type AND c.pays = ev.pays
            WHERE NOT ev.annule AND ev.alerte_le IS NULL AND ev.fin > now()
              AND ev.debut <= now() + make_interval(hours => c.preavis_heures + 1) /* climat_preavis_garanti_v1 */ FOR UPDATE OF ev LOOP
    v_txt := public.climat_texte_alerte_interne(e);
    v_cle := 'climat-' || e.id || '-' || to_char(e.debut AT TIME ZONE 'Europe/Paris', 'YYYYMMDDHH24MI') /* climat_report_v1 */;
    INSERT INTO public.evenements_globaux (country, city, texte, jour) VALUES (e.pays, e.ville, '⚠️ ' || v_txt, NULL);
    INSERT INTO public.journal_articles_en_attente (id, country, rubrique, titre, texte, statut, origine, priorite, dedup_key, created_at)
    VALUES (v_cle, e.pays, 'politique', 'Alerte météo : ' || public.climat_nom_ville_interne(e.pays, e.ville),
            v_txt || ' Les autorités appellent la population à la prudence.', 'attente', 'climat', 'importante', v_cle, now())
    ON CONFLICT (id) DO NOTHING;
    UPDATE public.climat_evenements SET alerte_le = now() WHERE id = e.id;
    v_n := v_n + 1;
  END LOOP;
  RETURN v_n;
END $$;

-- ── Q2 : brouillard 1 par mois et par ville ; calendrier recalculé ───────────────────────────────
UPDATE public.climat_parametres SET par_periode = 1 WHERE type = 'brouillard';

-- Dates d'origine (heure de Paris) des événements planifiés, relevées le 21/11/2026 à 13 h 49 UTC, avant le décalage
-- « un seul événement à la fois » : on les restaure, avec une heure tirée au hasard, pour tout événement non commencé.
CREATE TEMP TABLE climat_dates_origine (id bigint PRIMARY KEY, jour date) ON COMMIT DROP;
INSERT INTO climat_dates_origine (id, jour) VALUES
  (64, '2026-11-22'), (25, '2026-11-22'), (37, '2026-11-22'), (7, '2026-11-22'), (39, '2026-11-22'), (65, '2026-11-23'),
  (27, '2026-11-24'), (54, '2026-11-24'), (26, '2026-11-25'), (8, '2026-11-25'), (29, '2026-11-25'), (53, '2026-11-26'),
  (30, '2026-11-26'), (38, '2026-11-27'), (9, '2026-11-27'), (28, '2026-11-28'), (13, '2026-11-28'), (42, '2026-11-28'),
  (55, '2026-11-29'), (40, '2026-11-30'), (14, '2026-11-30'), (45, '2026-12-01'), (35, '2026-12-01'), (15, '2026-12-02'),
  (43, '2026-12-03'), (47, '2026-12-05'), (1, '2026-12-08'), (48, '2026-12-08'), (2, '2026-12-10'), (31, '2026-12-10'),
  (46, '2026-12-11'), (3, '2026-12-12'), (36, '2026-12-15'), (32, '2026-12-18'), (33, '2026-12-20'), (44, '2026-12-20'),
  (34, '2026-12-29'), (4, '2027-01-09'), (5, '2027-01-10'), (6, '2027-01-13'), (16, '2027-01-17'), (17, '2027-01-19'),
  (18, '2027-01-21'), (66, '2027-02-15'), (67, '2027-02-17'), (68, '2027-02-18'), (10, '2027-03-21'), (11, '2027-03-23'),
  (12, '2027-03-27');
-- Le relevé ne vaut que pour la base de production : ailleurs (banc), les identifiants absents sont simplement ignorés.

-- Événements déjà annoncés et non commencés : relevés avant tout changement (avis public si leur date change).
CREATE TEMP TABLE climat_annonces_avant ON COMMIT DROP AS
  SELECT id, debut FROM public.climat_evenements WHERE NOT annule AND now() < debut AND alerte_le IS NOT NULL;

-- Événements non commencés : date prévue (d'origine si connue), heure tirée au hasard, durée conservée ; le début suit
-- la date prévue (l'espacement ci-dessous le décale si besoin).
UPDATE public.climat_evenements e
   SET debut_prevu = n.prevu, debut = n.prevu, fin = n.prevu + (e.fin - e.debut)
  FROM (SELECT ev.id, public.climat_heure_hasard_interne(coalesce(d.jour, (ev.debut AT TIME ZONE 'Europe/Paris')::date)) AS prevu
          FROM public.climat_evenements ev LEFT JOIN climat_dates_origine d ON d.id = ev.id
         WHERE NOT ev.annule AND now() < ev.debut
           -- Déjà annoncé et imminent (moins de 48 h) : il a eu son préavis, il garde sa date, son heure et son annonce.
           AND NOT (ev.alerte_le IS NOT NULL AND ev.debut <= now() + interval '48 hours')) n
 WHERE n.id = e.id;

-- Brouillards en trop (au plus un par ville et par mois, déjà passés compris) : on garde le premier, on annule les autres.
UPDATE public.climat_evenements e SET annule = true
 WHERE e.type = 'brouillard' AND NOT e.annule AND now() < e.debut AND e.origine = 'calendrier'
   AND EXISTS (SELECT 1 FROM public.climat_evenements x
                WHERE x.type = 'brouillard' AND NOT x.annule AND x.origine = 'calendrier' AND x.pays = e.pays AND x.ville = e.ville
                  AND x.periode = e.periode AND x.id <> e.id
                  AND (now() >= x.debut OR coalesce(x.debut_prevu, x.debut) < coalesce(e.debut_prevu, e.debut)
                       OR (coalesce(x.debut_prevu, x.debut) = coalesce(e.debut_prevu, e.debut) AND x.id < e.id)));

-- Placement : un épisode (événement propagé de ville en ville, ou isolé) occupe [début, fin + préavis[ ; deux épisodes d'un
-- même pays ne se recouvrent jamais. Ordre : commencés (immobiles), annoncés (à leur date actuelle), puis crues, orages,
-- canicules, blizzards à leur date prévue, puis brouillards. Un épisode ne recule jamais avant sa date prévue.
CREATE OR REPLACE FUNCTION public.climat_espacer_interne(p_pays text)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE r record; v_places tstzrange[] := '{}'; v_debut timestamptz; v_long interval; v_conflit tstzrange; v_delta interval; v_n integer := 0;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('climat_espacer:' || p_pays));
  FOR r IN
    WITH ev AS (
      SELECT e.id, e.type, e.debut, e.fin, coalesce(e.debut_prevu, e.debut) AS prevu, e.alerte_le, coalesce(c.preavis_heures, 48) AS preavis,
             CASE WHEN c.frequence = 'trimestre_propage' AND e.origine = 'calendrier' THEN e.type || ':' || e.periode ELSE 'ev:' || e.id END AS episode
        FROM public.climat_evenements e LEFT JOIN public.climat_parametres c ON c.type = e.type AND c.pays = e.pays
       WHERE e.pays = p_pays AND NOT e.annule)
    SELECT episode, min(debut) AS d0, max(fin) AS f1, min(prevu) AS p0, max(prevu + (fin - debut)) AS pf1, max(preavis) AS preavis,
           min(id) AS id0, bool_or(now() >= debut) AS commence, bool_or(alerte_le IS NOT NULL) AS annonce,
           bool_and(type = 'brouillard') AS brouillard, count(*) AS n
      FROM ev GROUP BY episode HAVING max(fin) > now() - interval '7 days'
     ORDER BY bool_or(now() >= debut) DESC, bool_or(alerte_le IS NOT NULL) DESC, bool_and(type = 'brouillard'),
              CASE WHEN bool_or(alerte_le IS NOT NULL) THEN min(debut) ELSE min(prevu) END, count(*) DESC, min(id)
  LOOP
    IF r.commence THEN
      v_places := v_places || tstzrange(r.d0, r.f1 + make_interval(hours => r.preavis));
      CONTINUE;
    END IF;
    -- Point de départ : la date actuelle d'un épisode annoncé, sinon sa date prévue.
    IF r.annonce THEN v_debut := r.d0; v_long := (r.f1 - r.d0) + make_interval(hours => r.preavis);
    ELSE v_debut := r.p0; v_long := (r.pf1 - r.p0) + make_interval(hours => r.preavis);
      -- Jamais sans préavis : un épisode non annoncé commence au plus tôt 48 h après maintenant, à l'heure pleine.
      IF v_debut < now() + make_interval(hours => r.preavis) THEN
        v_debut := date_trunc('hour', now() + make_interval(hours => r.preavis)) + interval '1 hour';
      END IF;
    END IF;
    LOOP
      SELECT x INTO v_conflit FROM unnest(v_places) x WHERE x && tstzrange(v_debut, v_debut + v_long) ORDER BY upper(x) DESC LIMIT 1;
      EXIT WHEN v_conflit IS NULL;
      -- Heure pleine suivante : un événement commence toujours à l'heure juste.
      v_debut := date_trunc('hour', upper(v_conflit)) + CASE WHEN upper(v_conflit) > date_trunc('hour', upper(v_conflit)) THEN interval '1 hour' ELSE interval '0' END;
    END LOOP;
    v_places := v_places || tstzrange(v_debut, v_debut + v_long);
    -- Décalage par rapport à la date prévue (épisode non annoncé) ou actuelle (annoncé), appliqué à tout l'épisode.
    v_delta := v_debut - CASE WHEN r.annonce THEN r.d0 ELSE r.p0 END;
    IF v_debut IS DISTINCT FROM r.d0 THEN
      INSERT INTO public.evenements_globaux (country, city, texte, jour)
      SELECT e.pays, e.ville, '⚠️ Prévisions corrigées : l''alerte « ' || lower(public.climat_nom_type_interne(e.type)) || ' » à '
             || public.climat_nom_ville_interne(e.pays, e.ville) || ', ' || public.climat_quand_interne(e.debut) || ', est reportée '
             || public.climat_quand_interne(CASE WHEN r.annonce THEN e.debut ELSE coalesce(e.debut_prevu, e.debut) END + v_delta)
             || ' : un seul événement climatique à la fois dans le pays. Une nouvelle alerte suivra.', NULL
        FROM public.climat_evenements e
       WHERE e.alerte_le IS NOT NULL AND NOT e.annule AND e.pays = p_pays
         AND (CASE WHEN r.episode LIKE 'ev:%' THEN e.id = r.id0
                   ELSE e.type || ':' || e.periode = r.episode AND e.origine = 'calendrier' END);
      UPDATE public.climat_evenements e
         SET debut = CASE WHEN r.annonce THEN e.debut ELSE coalesce(e.debut_prevu, e.debut) END + v_delta,
             fin = CASE WHEN r.annonce THEN e.debut ELSE coalesce(e.debut_prevu, e.debut) END + v_delta + (e.fin - e.debut),
             alerte_le = NULL
       WHERE NOT e.annule AND e.pays = p_pays
         AND (CASE WHEN r.episode LIKE 'ev:%' THEN e.id = r.id0
                   ELSE e.type || ':' || e.periode = r.episode AND e.origine = 'calendrier' END);
      v_n := v_n + 1;
    END IF;
  END LOOP;
  RETURN v_n;
END $$;

-- Événements non commencés déjà annoncés sans heure : on les annonce de nouveau (avec l'heure) dès leur nouvelle date.
UPDATE public.climat_evenements SET alerte_le = NULL WHERE NOT annule AND now() < debut AND alerte_le IS NOT NULL
   AND debut > now() + interval '48 hours';
-- Recalcul immédiat du calendrier des deux pays à partir des dates prévues.
SELECT public.climat_espacer_interne('republic'), public.climat_espacer_interne('soviet');
-- Avis public pour chaque événement déjà annoncé dont le jour change (l'heure exacte suivra dans la nouvelle alerte).
INSERT INTO public.evenements_globaux (country, city, texte, jour)
SELECT e.pays, e.ville, '⚠️ Prévisions corrigées : ' || lower(public.climat_nom_type_interne(e.type)) || ' à ' || public.climat_nom_ville_interne(e.pays, e.ville)
       || CASE WHEN e.annule THEN ' : annulé (un seul brouillard par mois et par ville).'
               ELSE ', annoncé pour le ' || to_char(a.debut AT TIME ZONE 'Europe/Paris', 'DD/MM') || ', aura lieu ' || public.climat_quand_interne(e.debut)
                    || '. Une nouvelle alerte suivra.' END, NULL
  FROM climat_annonces_avant a JOIN public.climat_evenements e ON e.id = a.id
 WHERE e.annule OR (e.debut AT TIME ZONE 'Europe/Paris')::date <> (a.debut AT TIME ZONE 'Europe/Paris')::date;

-- ── Q3 : catastrophe naturelle, une seule option ─────────────────────────────────────────────────
-- Sinistré : ligne de pertes d'un lieu tiré, non protégé, qui a réellement perdu des stocks (valeur > 0).
CREATE OR REPLACE FUNCTION public.catastrophe_couts_interne(p_evenement bigint)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('part', public.aliments_param_interne('catastrophe_part_pct', 50),
    'cout', coalesce(round(sum(valeur) * public.aliments_param_interne('catastrophe_part_pct', 50) / 100, 2), 0),
    'sinistres', count(*), 'pertes', coalesce(round(sum(valeur), 2), 0))
  FROM public.climat_crue_pertes WHERE evenement = p_evenement AND NOT protege AND valeur > 0 /* catastrophe_option_unique_v1 */;
$$;

CREATE OR REPLACE FUNCTION public.catastrophe_etat(p_evenement bigint)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); e public.climat_evenements; c public.climat_catastrophes; v_poste text; v_pays text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO e FROM public.climat_evenements WHERE id = p_evenement AND type = 'crue';
  IF e.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'crue_inconnue'); END IF;
  SELECT poste->>'id', country INTO v_poste, v_pays FROM public.personnages_donnees WHERE name = a;
  IF v_pays IS DISTINCT FROM e.pays OR v_poste NOT IN ('min_int', 'pm') THEN RETURN jsonb_build_object('ok', false, 'raison', 'poste_requis'); END IF;
  SELECT * INTO c FROM public.climat_catastrophes WHERE evenement = e.id;
  RETURN jsonb_build_object('ok', true, 'evenement', e.id, 'ville', e.ville, 'poste', v_poste,
    'limite', e.fin + make_interval(hours => public.aliments_param_interne('catastrophe_delai_h', 72)::integer),
    'propose', c.propose_le IS NOT NULL, 'declare', c.declare_le IS NOT NULL, 'cout_verse', c.cout,
    'reserve', (SELECT coalesce((data->>'solde')::numeric, 0) FROM public.caisses_batiments WHERE id = e.pays || '_gouvernement-pm')) /* catastrophe_caisse_pm_v1 */
    || public.catastrophe_couts_interne(e.id);
END $$;

CREATE OR REPLACE FUNCTION public.catastrophe_proposer(p_evenement bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); e public.climat_evenements; v_pm text; v_c jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO e FROM public.climat_evenements WHERE id = p_evenement AND type = 'crue' AND effets_le IS NOT NULL;
  IF e.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'crue_inconnue'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = a AND country = e.pays AND poste->>'id' = 'min_int') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_requis'); END IF;
  IF now() > e.fin + make_interval(hours => public.aliments_param_interne('catastrophe_delai_h', 72)::integer) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_depasse'); END IF;
  INSERT INTO public.climat_catastrophes (evenement, pays, propose_par, propose_le) VALUES (e.id, e.pays, a, now()) ON CONFLICT (evenement) DO NOTHING;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_propose'); END IF;
  v_c := public.catastrophe_couts_interne(e.id);
  SELECT name INTO v_pm FROM public.personnages_donnees WHERE country = e.pays AND poste->>'id' = 'pm' LIMIT 1;
  IF v_pm IS NOT NULL THEN
    PERFORM public.mail_systeme_poser_interne('Ministère de l''Intérieur', v_pm, 'Proposition : état de catastrophe naturelle',
      'Le ministre de l''Intérieur vous propose de déclarer l''état de catastrophe naturelle après la crue de ' || public.climat_nom_ville_interne(e.pays, e.ville)
      || ' : ' || (v_c->>'sinistres') || ' sinistré(s) (lieux non protégés qui ont perdu des stocks), indemnisés à ' || (v_c->>'part')
      || ' % de leurs pertes, soit ' || (v_c->>'cout') || '. Vous restez libre de ne pas la déclarer. [[act:catastrophe_examiner|' || e.id || ']]', NULL);
  END IF;
  RETURN jsonb_build_object('ok', true, 'premier_ministre', v_pm IS NOT NULL) || v_c;
END $$;

-- p_etendre est conservé pour les écrans déjà chargés, mais n'a plus d'effet : tous les sinistrés sont indemnisés.
CREATE OR REPLACE FUNCTION public.catastrophe_declarer(p_evenement bigint, p_etendre boolean DEFAULT true)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); e public.climat_evenements; c public.climat_catastrophes; v_part numeric; v_total numeric := 0;
        r record; v_ind numeric; v_rep jsonb; v_flag text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO e FROM public.climat_evenements WHERE id = p_evenement AND type = 'crue';
  IF e.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'crue_inconnue'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = a AND country = e.pays AND poste->>'id' = 'pm') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_requis'); END IF;
  SELECT * INTO c FROM public.climat_catastrophes WHERE evenement = e.id FOR UPDATE;
  IF c.propose_le IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_proposition'); END IF;
  IF c.declare_le IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_declare'); END IF;
  IF now() > e.fin + make_interval(hours => public.aliments_param_interne('catastrophe_delai_h', 72)::integer) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_depasse'); END IF;
  v_part := public.aliments_param_interne('catastrophe_part_pct', 50);
  SELECT coalesce(round(sum(valeur) * v_part / 100, 2), 0) INTO v_total FROM public.climat_crue_pertes
   WHERE evenement = e.id AND NOT protege AND valeur > 0 /* catastrophe_option_unique_v1 */;
  IF v_total > 0 THEN
    v_flag := current_setting('rp.caisse_interne', true);
    PERFORM set_config('rp.caisse_interne', 'on', true);
    v_rep := public.caisse_institution_mouvement(e.pays || '_gouvernement-pm', -v_total, false);
    PERFORM set_config('rp.caisse_interne', coalesce(v_flag, ''), true);
    IF (v_rep->>'ok')::boolean IS NOT TRUE THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'budget_insuffisant', 'cout', v_total,
        'reserve', (SELECT coalesce((data->>'solde')::numeric, 0) FROM public.caisses_batiments WHERE id = e.pays || '_gouvernement-pm')); END IF;
  END IF;
  FOR r IN SELECT * FROM public.climat_crue_pertes WHERE evenement = e.id AND NOT protege AND valeur > 0 FOR UPDATE LOOP
    v_ind := round(r.valeur * v_part / 100, 2);
    IF r.cible LIKE 'entrepot:%' THEN
      v_flag := current_setting('rp.caisse_interne', true);
      PERFORM set_config('rp.caisse_interne', 'on', true);
      v_rep := public.caisse_institution_mouvement(public.entrepot_caisse_id(substr(r.cible, 10)), v_ind, true);
      PERFORM set_config('rp.caisse_interne', coalesce(v_flag, ''), true);
      IF (v_rep->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'catastrophe : caisse entrepot refusee %', v_rep; END IF;
    ELSE
      UPDATE public.entreprises SET data = jsonb_set(data, '{caisse}', to_jsonb(coalesce((data->>'caisse')::numeric, 0) + v_ind)), updated_at = now() WHERE id = r.cible;
    END IF;
    UPDATE public.climat_crue_pertes SET indemnite = v_ind WHERE evenement = r.evenement AND cible = r.cible;
  END LOOP;
  UPDATE public.climat_catastrophes SET declare_par = a, declare_le = now(), option = 'tous', cout = v_total WHERE evenement = e.id;
  INSERT INTO public.evenements_globaux (country, city, texte, jour)
  VALUES (e.pays, e.ville, '🏛️ État de catastrophe naturelle déclaré à ' || public.climat_nom_ville_interne(e.pays, e.ville)
    || ' : les sinistrés de la crue sont indemnisés à ' || v_part || ' % des stocks perdus.', NULL);
  RETURN jsonb_build_object('ok', true, 'cout', v_total);
END $$;

-- ── Q4 : un sac protège entièrement ; plus aucune trace de la règle du 19/11 ─────────────────────
CREATE OR REPLACE FUNCTION public.climat_crue_appliquer_interne(e public.climat_evenements)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE l jsonb; v_bat text; v_prot boolean; v_pct numeric; v_id text; v_etat jsonb; r jsonb; ent record; v_d jsonb; v_val numeric; v_det jsonb;
        k text; v_n integer := 0; v_min text;
BEGIN
  FOR l IN SELECT * FROM jsonb_array_elements(e.lieux) LOOP
    v_bat := l->>'batiment';
    -- Le sac posé avant la crue est consommé par elle : le lieu reste ouvert et ne perd rien.
    UPDATE public.climat_protections SET evenement = e.id WHERE pays = e.pays AND ville = e.ville AND batiment = v_bat AND evenement IS NULL;
    v_prot := FOUND;
    v_pct := CASE WHEN v_prot THEN 0 ELSE public.aliments_param_interne('crue_perte_pct', 20) END /* climat_sacs_protegent_v1 */;
    v_id := e.pays || '_' || e.ville || '_' || v_bat;
    SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
    IF v_etat IS NOT NULL AND jsonb_typeof(v_etat->'entrepot'->'stock') = 'object' THEN
      r := public.climat_stock_amputer_interne(v_etat->'entrepot'->'stock', v_pct, e.pays);
      UPDATE public.batiments_etat SET data = to_jsonb((v_etat || jsonb_build_object('entrepot', (v_etat->'entrepot') || jsonb_build_object('stock', r->'stock')))::text), updated_at = now() WHERE id = v_id;
      INSERT INTO public.climat_crue_pertes (evenement, cible, pays, ville, batiment, proprietaire, protege, valeur, detail)
      VALUES (e.id, 'entrepot:' || v_id, e.pays, e.ville, v_bat, NULL, v_prot, (r->>'valeur')::numeric, r->'perdu') ON CONFLICT DO NOTHING;
      v_n := v_n + 1;
    END IF;
    FOR ent IN SELECT id, data FROM public.entreprises WHERE (data->>'country' = e.pays AND data->>'city' = e.ville AND data->>'buildingId' = v_bat)
                   OR (data->'implantation'->>'country' = e.pays AND data->'implantation'->>'city' = e.ville AND data->'implantation'->>'buildingId' = v_bat) FOR UPDATE LOOP
      v_d := ent.data; v_val := 0; v_det := '{}'::jsonb;
      FOREACH k IN ARRAY ARRAY['stockMatieres', 'stockProduits', 'stockReferences'] LOOP
        IF jsonb_typeof(v_d->k) = 'object' THEN
          r := public.climat_stock_amputer_interne(v_d->k, v_pct, e.pays);
          v_d := jsonb_set(v_d, ARRAY[k], r->'stock'); v_val := v_val + (r->>'valeur')::numeric; v_det := v_det || jsonb_build_object(k, r->'perdu');
        END IF;
      END LOOP;
      UPDATE public.entreprises SET data = v_d, updated_at = now() WHERE id = ent.id;
      INSERT INTO public.climat_crue_pertes (evenement, cible, pays, ville, batiment, proprietaire, protege, valeur, detail)
      VALUES (e.id, ent.id, e.pays, e.ville, v_bat, nullif(replace(coalesce(ent.data->>'proprietaire', ''), 'pj:', ''), ''), v_prot, v_val, v_det) ON CONFLICT DO NOTHING;
      v_n := v_n + 1;
    END LOOP;
  END LOOP;
  SELECT name INTO v_min FROM public.personnages_donnees WHERE country = e.pays AND poste->>'id' = 'min_int' LIMIT 1;
  IF v_min IS NOT NULL THEN
    PERFORM public.mail_systeme_poser_interne('Ministère de l''Intérieur', v_min, 'Crue à ' || public.climat_nom_ville_interne(e.pays, e.ville),
      'Une crue frappe ' || public.climat_nom_ville_interne(e.pays, e.ville) || '. Vous pouvez proposer au Premier ministre de déclarer l''état de catastrophe naturelle (72 h après la crue au plus tard). '
      || '[[act:catastrophe_proposer|' || e.id || ']]', NULL);
  END IF;
  RETURN v_n;
END $$;

-- Poser : 1 PA, consomme un sac, protège le lieu pour la prochaine crue (déjà protégé : refus, rien n'est consommé).
CREATE OR REPLACE FUNCTION public.sacs_sable_poser(p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := '{}'::jsonb; v jsonb; d public.personnages_donnees; v_droit boolean;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'sacs_sable_poser', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT * INTO d FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF NOT EXISTS (SELECT 1 FROM public.climat_zones_inondables WHERE pays = d.country AND ville = d.current_city AND batiment = d.current_building) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_zone_inondable'); END IF;
  v_droit := EXISTS (SELECT 1 FROM public.entreprises e
                      WHERE replace(coalesce(e.data->>'proprietaire', ''), 'pj:', '') = a
                        AND ((e.data->>'country' = d.country AND e.data->>'city' = d.current_city AND e.data->>'buildingId' = d.current_building)
                          OR (e.data->'implantation'->>'country' = d.country AND e.data->'implantation'->>'city' = d.current_city
                              AND e.data->'implantation'->>'buildingId' = d.current_building)))
          OR (d.current_building LIKE 'entrepot-logistique-%' AND d.poste->>'id' = 'directeur_entrepot');
  IF NOT v_droit THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire_ni_exploitant'); END IF;
  PERFORM pg_advisory_xact_lock(hashtext('climat_sacs:' || d.country || ':' || d.current_city || ':' || d.current_building));
  IF EXISTS (SELECT 1 FROM public.climat_protections WHERE pays = d.country AND ville = d.current_city AND batiment = d.current_building AND evenement IS NULL) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_protege'); END IF;
  IF public.inventaire_quantite(coalesce(d.inventory, '[]'::jsonb), 'sac_de_sable') < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_sacs'); END IF;
  v := public.payer_ordre(a, 'poser_sacs_sable', 1, 0);
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v; END IF;
  UPDATE public.personnages_donnees SET inventory = public.inventaire_retirer(inventory, 'sac_de_sable', 1), updated_at = now() WHERE name = a;
  INSERT INTO public.climat_protections (pays, ville, batiment, pose_par) VALUES (d.country, d.current_city, d.current_building, a);
  v := jsonb_build_object('ok', true, 'batiment', d.current_building, 'pa', v->'pa', 'protege', true) /* climat_un_sac_v1 */
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = a);
  RETURN public.achat_requete_clore_interne(a, p_requete, 'sacs_sable_poser', prm, v);
END $$;

DROP FUNCTION IF EXISTS public.climat_sacs_reste_pct_interne(numeric);
DROP FUNCTION IF EXISTS public.climat_sacs_poses_interne(text, text, text);
DELETE FROM public.aliments_parametres WHERE cle IN ('sac_protection_pct', 'sacs_plafond', 'sacs_protection_pct');
-- La colonne « sacs » (règle du 19/11) était vide en production (aucune protection posée au 21/11) : on la retire.
ALTER TABLE public.climat_protections DROP COLUMN IF EXISTS sacs;

REVOKE ALL ON FUNCTION public.climat_heure_hasard_interne(date), public.climat_quand_interne(timestamptz) FROM PUBLIC, anon, authenticated;

COMMIT;
