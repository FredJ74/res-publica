-- Réponses de Fred aux 12 questions du 28/11/2026 (mission du 28/11 après-midi, étape 1).
-- GAME-DESIGN-AL-MADINA.md et GAME-DESIGN-CIUDAD-ROJA.md, « Décisions du 28/11 (après-midi) ».
--   2. Échec de « Forcer le passage » à l'Hôtel Royal : plus de prison ; assignation à résidence dans la suite
--      (pièce « chambres »), attribuée d'office et sans frais ; fin au premier « Dormir ».
--   3. Détenu du Renseignement en salle d'interrogatoire : 48 h au plus, puis retour d'office dans son lieu de
--      détention d'origine ; courrier au détenu et au ministre.
--   4. Transfert : la peine restante ne se décompte plus qu'au « Dormir » (et un ancien détenu du goulag
--      transféré n'est plus bloqué : detention_clore_purgee le refusait à jamais).
--   5. Escorts de la suite de Ciudad Roja : nuitée réservée et pas encore de « Dormir » depuis la réservation.
--   7. Police des mœurs : liquide d'abord, puis comptes bancaires, puis ce qui existe.
--   8. Tito Maletas : un vrai secret sur un joueur réel (réseau Roxane Velours ; clients du standard d'abord).
--   Correctif : service d'étage de l'Hôtel Royal au tarif national (300 DR), refusé jusqu'ici.
--   9. Vrais secrets des hôtels : + parti ou organisation publique, biens, casier et peine en cours, conjoint et
--      employés, crimes non élucidés (en rumeur) ; jamais une organisation secrète.
-- Contrôle :
--   SELECT position('hotel_royal_assignation_v1' in pg_get_functiondef('public.acces_forcer_passage(uuid,text)'::regprocedure)) > 0;
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer(p_fn regprocedure, p_avant text, p_apres text, p_marque text, p_n integer DEFAULT 1)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  n := (length(d) - length(replace(d, p_avant, ''))) / length(p_avant);
  IF n <> p_n THEN RAISE EXCEPTION '% : % occurrence(s) au lieu de % (%)', p_fn, n, p_n, left(p_avant, 70); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : marque absente (%)', p_fn, p_marque; END IF;
END $$;

-- ===================================================================== Tables
CREATE TABLE IF NOT EXISTS public.hotel_royal_assignations (
  acteur text PRIMARY KEY,
  debut timestamptz NOT NULL DEFAULT now(),
  fin timestamptz
);
ALTER TABLE public.hotel_royal_assignations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.hotel_royal_assignations FROM PUBLIC, anon, authenticated;

-- Heure exacte du dernier « Dormir » (pa_repos_le n'est qu'une date).
CREATE TABLE IF NOT EXISTS public.personnages_dormir_horodates (
  nom text PRIMARY KEY,
  le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.personnages_dormir_horodates ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.personnages_dormir_horodates FROM PUBLIC, anon, authenticated;

-- ===================================================================== 2. Assignation à résidence
CREATE OR REPLACE FUNCTION public.hotel_royal_assignation_active(p_nom text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.hotel_royal_assignations WHERE acteur = p_nom AND fin IS NULL);
$$;

CREATE OR REPLACE FUNCTION public.hotel_royal_assigner_interne(p_nom text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_id uuid;
BEGIN
  UPDATE public.personnages_donnees
     SET country = 'khalija', current_city = 'capitale', current_building = 'hotel-republica', current_room = 'chambres',
         current_street = NULL, updated_at = clock_timestamp()
   WHERE name = p_nom RETURNING id INTO v_id;
  -- Suite attribuée d'office et sans frais, même sans réservation : une nuitée gratuite si aucune n'attend.
  IF NOT EXISTS (SELECT 1 FROM public.hotel_nuitees n WHERE n.personnage_id = v_id AND n.consommee_le IS NULL
                   AND n.country = 'khalija' AND n.city = 'capitale' AND n.building_id = 'hotel-republica') THEN
    PERFORM public.hotel_nuitee_ajouter_interne(p_nom, 'hotel-republica');
    UPDATE public.hotel_nuitees SET reference = 'assignation_hotel_royal'
     WHERE personnage_id = v_id AND consommee_le IS NULL AND building_id = 'hotel-republica' AND country = 'khalija' AND reference IS NULL;
  END IF;
  INSERT INTO public.hotel_royal_assignations (acteur) VALUES (p_nom)
    ON CONFLICT (acteur) DO UPDATE SET debut = now(), fin = NULL;
  -- Texte vide : le navigateur l'écrit au journal dans la langue du joueur (plateau-hotels-teaser.js).
  PERFORM public.personnage_evenement_ajouter_interne(p_nom, 'assignation_hotel_royal', '', jsonb_build_object('ton', 'mauvais'));
  PERFORM public.mail_systeme_poser_interne('Hôtel Royal d''Al-Khalija', p_nom, 'Assignation à résidence',
    'Surpris dans un salon réservé, vous êtes assigné à résidence dans votre suite de l''Hôtel Royal, offerte par la maison. '
    || 'Vous ne pouvez pas en sortir ; vous pouvez y dormir, commander au service d''étage, écrire et aller sur le forum. '
    || 'L''assignation prend fin à votre premier « Dormir ».', NULL);
  RETURN jsonb_build_object('assignation', true, 'batiment', 'hotel-republica', 'piece', 'chambres');
END $$;

SELECT pg_temp.rp_remplacer('public.acces_forcer_passage(uuid,text)'::regprocedure,
$q$    v_det := public.detention_ouvrir_interne(a, 'Intrusion dans un salon réservé de l''Hôtel Royal', 1, 'capitale', 'khalija',
      jsonb_build_array(jsonb_build_object('type', 'Intrusion dans un salon réservé de l''Hôtel Royal', 'jours', 1,
        'source', 'acces_reserve', 'city', 'capitale')), 'garde_hotel_royal', 'intrusion_hotel_royal');
    r := jsonb_build_object('ok', true, 'reussi', false, 'prison', true, 'jours', 1, 'taux', v_taux, 'jet', v_jet,
      'batiment', p.current_building, 'piece', p_piece, 'detention', v_det);$q$,
$q$    -- hotel_royal_assignation_v1 (Fred, 28/11/2026) : plus de prison ; assignation à résidence dans la suite.
    v_det := public.hotel_royal_assigner_interne(a);
    r := jsonb_build_object('ok', true, 'reussi', false, 'assignation', true, 'taux', v_taux, 'jet', v_jet,
      'batiment', p.current_building, 'piece', p_piece, 'residence', v_det);$q$,
'hotel_royal_assignation_v1');

-- Service d'étage : le prix suit le tarif national (300 DR à Al-Khalija, migration 20261128040000) ; sans ce raccord,
-- payer_ordre_interne refusait la commande à l'Hôtel Royal (« cout_non_declare »), assignés compris.
SELECT pg_temp.rp_remplacer('public.hotel_service_etage_commander()'::regprocedure,
$q$  IF v_prix IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'service_indisponible'); END IF;$q$,
$q$  IF v_prix IS NOT NULL THEN /* service_etage_tarif_pays_v1 */
    v_prix := coalesce((SELECT o.cost FROM public.ordres_couts_pays o WHERE o.fn = 'service_etage' AND o.pays = p.country LIMIT 1), v_prix);
  END IF;
  IF v_prix IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'service_indisponible'); END IF;$q$,
'service_etage_tarif_pays_v1');

-- Il ne peut pas sortir de la suite : toute navigation (pièces, rue, transports, véhicules) est refusée.
SELECT pg_temp.rp_remplacer('public.navigation_disponibilite_interne(text)'::regprocedure,
$q$ RETURN jsonb_build_object('ok',true);$q$,
$q$ IF public.hotel_royal_assignation_active(p_nom) THEN /* hotel_royal_assignation_v1 */
  RETURN jsonb_build_object('ok',false,'raison','assignation_residence'); END IF;
 RETURN jsonb_build_object('ok',true);$q$,
'hotel_royal_assignation_v1');

-- ===================================================================== 4. Peine au sommeil après transfert ; « Dormir »
CREATE OR REPLACE FUNCTION public.pa_repos_suites_interne(p_acteur text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  INSERT INTO public.personnages_dormir_horodates (nom, le) VALUES (p_acteur, now())
    ON CONFLICT (nom) DO UPDATE SET le = now();
  -- transfert_peine_au_sommeil_v1 : un jour de peine par « Dormir ».
  UPDATE public.personnages_donnees
     SET est_emprisonne = jsonb_set(est_emprisonne, '{nuitsRestantes}',
           to_jsonb(greatest(0, coalesce((est_emprisonne ->> 'nuitsRestantes')::integer, 0) - 1)))
   WHERE name = p_acteur AND jsonb_typeof(est_emprisonne) = 'object'
     AND coalesce((est_emprisonne ->> 'peineAuSommeil')::boolean, false);
  -- hotel_royal_assignation_v1 : l'assignation prend fin au premier « Dormir ».
  IF EXISTS (SELECT 1 FROM public.hotel_royal_assignations WHERE acteur = p_acteur AND fin IS NULL) THEN
    UPDATE public.hotel_royal_assignations SET fin = now() WHERE acteur = p_acteur AND fin IS NULL;
    PERFORM public.personnage_evenement_ajouter_interne(p_acteur, 'assignation_hotel_royal_fin', '', jsonb_build_object('ton', 'bon'));
  END IF;
END $$;

SELECT pg_temp.rp_remplacer('public.pa_repos_nocturne(text)'::regprocedure,
$q$pa_repos_le = v_jour
   WHERE name = p_acteur;

  v_sante_nuit$q$,
$q$pa_repos_le = v_jour
   WHERE name = p_acteur;
  PERFORM public.pa_repos_suites_interne(p_acteur); /* pa_repos_suites_v1 */

  v_sante_nuit$q$,
'pa_repos_suites_v1');

CREATE OR REPLACE FUNCTION public.transfert_detenu_regimes_lever_interne(p_detenu text, p_detention text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE g record; v_jour integer; v_peine jsonb; v_reste integer; v_fin date;
BEGIN
  -- transfert_peine_au_sommeil_v1 (Fred, 28/11/2026) : après le transfert, la peine restante ne se décompte qu'au
  -- « Dormir » (est_emprisonne.nuitsRestantes, décrémenté par pa_repos_suites_interne) ; plus d'échéance au calendrier.
  SELECT coalesce(day, 1), est_emprisonne INTO v_jour, v_peine FROM public.personnages_donnees WHERE name = p_detenu FOR UPDATE;
  SELECT * INTO g FROM public.sovarka_goulag_registre WHERE detention_id = p_detention AND liberation_le IS NULL FOR UPDATE;
  IF jsonb_typeof(v_peine) = 'object' AND coalesce((v_peine ->> 'peineAuSommeil')::boolean, false) THEN
    v_reste := greatest(0, coalesce((v_peine ->> 'nuitsRestantes')::integer, 0));
  ELSIF g.detention_id IS NOT NULL THEN
    v_reste := greatest(0, coalesce(g.jours_restants, 0));
  ELSIF coalesce(v_peine ->> 'debutTs', '') ~ '^[0-9]+(\.[0-9]+)?$' AND coalesce(v_peine ->> 'jours', '') ~ '^[0-9]+(\.[0-9]+)?$' THEN
    v_fin := (to_timestamp((v_peine ->> 'debutTs')::numeric / 1000) AT TIME ZONE 'Europe/Paris')::date
             + ceil((v_peine ->> 'jours')::numeric)::integer;
    v_reste := greatest(0, v_fin - (now() AT TIME ZONE 'Europe/Paris')::date);
  ELSE
    v_reste := greatest(0, coalesce((SELECT jour_fin FROM public.detentions WHERE id = p_detention), v_jour) - v_jour);
  END IF;
  -- QHS
  UPDATE public.detentions SET qhs = false WHERE id = p_detention AND qhs;
  UPDATE public.prisonniers_qhs SET statut = 'transfere' WHERE data ->> 'nom' = p_detenu AND coalesce(statut, '') <> 'transfere';
  UPDATE public.personnages_donnees SET detention_qhs = jsonb_build_object('enQHS', false)
   WHERE name = p_detenu AND jsonb_typeof(detention_qhs) = 'object' AND coalesce((detention_qhs ->> 'enQHS')::boolean, false);
  -- Goulag : le registre est clos (le décompte passe au « Dormir » de la prison ordinaire).
  IF g.detention_id IS NOT NULL THEN
    UPDATE public.sovarka_goulag_registre SET liberation_le = now() WHERE detention_id = p_detention;
  END IF;
  UPDATE public.detentions SET jour_fin = v_jour + v_reste WHERE id = p_detention;
  -- Salle d'interrogatoire levée ; peine au sommeil posée.
  UPDATE public.personnages_donnees
     SET est_emprisonne = (est_emprisonne - 'interrogatoire')
           || jsonb_build_object('peineAuSommeil', true, 'nuitsRestantes', v_reste, 'jourFin', v_jour + v_reste)
   WHERE name = p_detenu AND jsonb_typeof(est_emprisonne) = 'object';
END $$;
REVOKE ALL ON FUNCTION public.transfert_detenu_regimes_lever_interne(text, text) FROM PUBLIC, anon, authenticated;

SELECT pg_temp.rp_remplacer('public.detention_clore_purgee()'::regprocedure,
$q$  SELECT * INTO v_det FROM public.detention_active(v_moi);
$q$,
$q$  SELECT * INTO v_det FROM public.detention_active(v_moi);
  -- transfert_peine_au_sommeil_v1 (Fred, 28/11/2026) : détenu transféré, la peine se purge au « Dormir » seulement.
  IF coalesce((v_peine->>'peineAuSommeil')::boolean, false) THEN
    IF coalesce((v_peine->>'nuitsRestantes')::integer, 0) > 0 THEN
      RETURN jsonb_build_object('ok',false,'raison','peine_non_purgee','nuits_restantes',(v_peine->>'nuitsRestantes')::integer);
    END IF;
    RETURN public.detention_clore_interne(v_moi,'purgee') || jsonb_build_object('ok',true,'au_sommeil',true);
  END IF;
$q$,
'transfert_peine_au_sommeil_v1');

-- ===================================================================== 3. Salle d'interrogatoire : 48 h au plus
CREATE OR REPLACE FUNCTION public.renseignement_interrogatoire_placer_interne(p_nom text)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  -- interrogatoire_48h_v1 (Fred, 28/11/2026) : heure d'entrée et lieu de détention d'origine, pour le retour d'office.
  UPDATE public.personnages_donnees
     SET est_emprisonne = est_emprisonne || jsonb_build_object('interrogatoire', jsonb_build_object(
           'batiment', 'siege-renseignement', 'piece', 'salle_interrogatoire_renseignement',
           'depuis', coalesce(est_emprisonne #> '{interrogatoire,depuis}', to_jsonb((extract(epoch FROM now()) * 1000)::bigint)),
           'origine', coalesce(est_emprisonne #> '{interrogatoire,origine}',
             CASE WHEN current_building IS NOT NULL AND current_building <> 'siege-renseignement' THEN
               jsonb_build_object('country', country, 'city', current_city, 'building', current_building, 'room', current_room) END))),
         current_building = 'siege-renseignement', current_room = 'salle_interrogatoire_renseignement',
         current_street = NULL, updated_at = clock_timestamp()
   WHERE name = p_nom AND jsonb_typeof(est_emprisonne) = 'object';
$$;
REVOKE ALL ON FUNCTION public.renseignement_interrogatoire_placer_interne(text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.renseignement_interrogatoire_echeances_interne()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE d record; v_or jsonb; v_pays text; v_ville text; v_b text; v_r text; v_min text; n integer := 0;
        v_seuil bigint := (extract(epoch FROM now() - interval '48 hours') * 1000)::bigint;
BEGIN
  -- Détenus déjà en salle sans heure d'entrée : les 48 h partent d'aujourd'hui.
  UPDATE public.personnages_donnees
     SET est_emprisonne = jsonb_set(est_emprisonne, '{interrogatoire}',
           CASE WHEN jsonb_typeof(est_emprisonne -> 'interrogatoire') = 'object' THEN est_emprisonne -> 'interrogatoire' ELSE '{}'::jsonb END
           || jsonb_build_object('depuis', (extract(epoch FROM now()) * 1000)::bigint))
   WHERE jsonb_typeof(est_emprisonne) = 'object' AND est_emprisonne ? 'interrogatoire'
     AND (jsonb_typeof(est_emprisonne -> 'interrogatoire') <> 'object'
          OR coalesce(est_emprisonne #>> '{interrogatoire,depuis}', '') !~ '^[0-9]+$');
  FOR d IN SELECT name, country, current_city, est_emprisonne FROM public.personnages_donnees
            WHERE jsonb_typeof(est_emprisonne) = 'object' AND jsonb_typeof(est_emprisonne -> 'interrogatoire') = 'object'
              AND (est_emprisonne #>> '{interrogatoire,depuis}')::bigint <= v_seuil
            FOR UPDATE LOOP
    v_or := d.est_emprisonne #> '{interrogatoire,origine}';
    IF jsonb_typeof(v_or) = 'object' AND coalesce(v_or ->> 'building', '') NOT IN ('', 'siege-renseignement') THEN
      v_pays := coalesce(v_or ->> 'country', d.country); v_ville := coalesce(v_or ->> 'city', d.current_city);
      v_b := v_or ->> 'building'; v_r := v_or ->> 'room';
    ELSE
      v_pays := d.country; v_ville := d.current_city;
      v_b := CASE WHEN d.current_city = 'capitale' THEN 'commissariat' ELSE 'commissariat-local' END;
      v_r := CASE WHEN d.current_city = 'capitale' THEN 'prison' ELSE 'geoles' END;
    END IF;
    UPDATE public.personnages_donnees
       SET est_emprisonne = est_emprisonne - 'interrogatoire', country = v_pays, current_city = v_ville,
           current_building = v_b, current_room = v_r, current_street = NULL, updated_at = clock_timestamp()
     WHERE name = d.name;
    PERFORM public.mail_systeme_poser_interne('Direction du Renseignement', d.name, 'Fin de l''interrogatoire',
      'Après 48 heures en salle d''interrogatoire, vous êtes reconduit d''office dans votre lieu de détention.', NULL);
    FOR v_min IN SELECT p.name FROM public.personnages_donnees p
                  WHERE p.user_id IS NOT NULL AND p.poste ->> 'id' IN ('min_def', 'min_int')
                    AND (public.poste_detenu(p.name, 'min_def', d.country)
                         OR (d.country = 'soviet' AND public.poste_detenu(p.name, 'min_int', 'soviet'))) LOOP
      PERFORM public.mail_systeme_poser_interne('Direction du Renseignement', v_min, 'Fin de l''interrogatoire : ' || d.name,
        'Le délai de 48 heures est écoulé : ' || d.name || ' a été reconduit d''office dans son lieu de détention.', NULL);
    END LOOP;
    n := n + 1;
  END LOOP;
  RETURN n;
END $$;
REVOKE ALL ON FUNCTION public.renseignement_interrogatoire_echeances_interne() FROM PUBLIC, anon, authenticated;

SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'renseignement_interrogatoire_passe';
SELECT cron.schedule('renseignement_interrogatoire_passe', '47 * * * *', 'SELECT public.renseignement_interrogatoire_echeances_interne()');

-- ===================================================================== 5. Escorts : pas encore de « Dormir » depuis la réservation
CREATE OR REPLACE FUNCTION public.nuitee_sans_dormir_interne(p_nom text, p_cree timestamptz)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN EXISTS (SELECT 1 FROM public.personnages_dormir_horodates h WHERE h.nom = p_nom)
              THEN (SELECT h.le < p_cree FROM public.personnages_dormir_horodates h WHERE h.nom = p_nom)
              -- Avant le premier horodatage : la date du dernier repos.
              ELSE coalesce((SELECT d.pa_repos_le IS NULL OR d.pa_repos_le <= (p_cree AT TIME ZONE 'Europe/Paris')::date
                               FROM public.personnages_donnees d WHERE d.name = p_nom), false) END;
$$;

SELECT pg_temp.rp_remplacer('public.escort_lieu_appel_interne(text)'::regprocedure,
$q$AND n.cree_le > now() - interval '36 hours'))$q$,
$q$AND n.consommee_le IS NULL AND public.nuitee_sans_dormir_interne(pd.name, n.cree_le) /* ciudad_roja_escorts_dormir_v1 */))$q$,
'ciudad_roja_escorts_dormir_v1');

-- ===================================================================== 7. Amende : liquide, puis comptes, puis ce qui existe
CREATE OR REPLACE FUNCTION public.amende_prelever_interne(p_nom text, p_montant numeric)
RETURNS numeric LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_liq numeric; v_reste numeric := greatest(0, coalesce(p_montant, 0)); v_pris numeric := 0; v_x numeric; c record;
BEGIN
  SELECT coalesce(liquide, 0) INTO v_liq FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND THEN RETURN 0; END IF;
  v_x := least(greatest(v_liq, 0), v_reste);
  IF v_x > 0 THEN
    UPDATE public.personnages_donnees SET liquide = liquide - v_x, updated_at = now() WHERE name = p_nom;
    v_reste := v_reste - v_x; v_pris := v_x;
  END IF;
  FOR c IN SELECT id, solde FROM public.comptes_bancaires WHERE personnage = p_nom AND solde > 0
            ORDER BY (banque = 'nationale') DESC, banque, id FOR UPDATE LOOP
    EXIT WHEN v_reste <= 0;
    v_x := least(c.solde, v_reste);
    UPDATE public.comptes_bancaires SET solde = solde - v_x, updated_at = now() WHERE id = c.id;
    v_reste := v_reste - v_x; v_pris := v_pris + v_x;
  END LOOP;
  RETURN v_pris;
END $$;
REVOKE ALL ON FUNCTION public.amende_prelever_interne(text, numeric) FROM PUBLIC, anon, authenticated;

-- ===================================================================== 9. Vrais secrets des hôtels
CREATE OR REPLACE FUNCTION public.hotel_secret_vrai_interne(p_nom text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  -- hotel_secret_vrai_v1 (Fred, 28/11/2026). Jamais l'appartenance à une organisation secrète.
  WITH d AS (SELECT * FROM public.personnages_donnees WHERE name = p_nom),
  c AS (
    SELECT p_nom || ' occupe le poste de ' || coalesce(nullif(d.poste->>'label', ''), replace(d.poste->>'id', '_', ' ')) || '.' AS t
      FROM d WHERE coalesce(d.poste->>'id', '') <> ''
    UNION ALL
    SELECT p_nom || ' se promène avec plus de ' || (floor(coalesce(d.liquide, 0) / 100) * 100)::bigint || ' '
           || CASE d.country WHEN 'soviet' THEN 'PSK' WHEN 'khalija' THEN 'DR' WHEN 'narco' THEN 'PS' ELSE 'FR' END || ' en poche.'
      FROM d WHERE coalesce(d.liquide, 0) >= 100
    UNION ALL
    SELECT p_nom || ' vit à ' || public.sovarka_ville_nom_interne(d.domicile->>'country', d.domicile->>'city') || '.'
      FROM d WHERE d.domicile ? 'country'
    UNION ALL
    SELECT p_nom || ' a fait récemment quelque chose de louche (« ' || replace(a.type_action, '_', ' ') || ' »'
           || CASE WHEN coalesce(a.cible, '') <> '' THEN ', visant ' || a.cible ELSE '' END || ') à '
           || public.sovarka_ville_nom_interne(a.country, a.city) || '.'
      FROM (SELECT * FROM public.actions_tracables WHERE auteur = p_nom ORDER BY created_at DESC LIMIT 3) a
    UNION ALL
    -- Parti ou organisation publique.
    SELECT p_nom || ' est membre de « ' || coalesce(o.data::jsonb->>'nom', o.id) || ' » ('
           || CASE o.data::jsonb->>'type' WHEN 'politique' THEN 'parti politique' WHEN 'syndicale' THEN 'syndicat'
                WHEN 'economique' THEN 'organisation économique' ELSE 'organisation' END || ').'
      FROM public.organisations o
     WHERE NOT public.organisation_secrete_donnees_interne(o.data::jsonb)
       AND EXISTS (SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(o.data::jsonb->'membres') = 'array'
                     THEN o.data::jsonb->'membres' ELSE '[]'::jsonb END) m WHERE m->>'nom' = p_nom)
    UNION ALL
    -- Biens : locaux (commerces, bureaux) et terrains. Un local d'organisation secrète n'est jamais cité.
    SELECT p_nom || ' tient un local (' || coalesce(nullif(l.data->>'localLabel', ''), l.data->>'roomId', 'local') || ') à '
           || coalesce(nullif(l.data->>'batimentLabel', ''), l.data->>'buildingId', '?') || ', '
           || public.sovarka_ville_nom_interne(coalesce(l.data->>'country', l.country), l.data->>'city') || '.'
      FROM public.locations_actives l
     WHERE l.data->>'locataire' = p_nom
       AND (coalesce(l.data->>'orgaId', '') = '' OR NOT public.organisation_secrete_interne(l.data->>'orgaId'))
    UNION ALL
    SELECT p_nom || ' possède un terrain à ' || public.sovarka_ville_nom_interne(t.country, r.ville) || '.'
      FROM public.terrains_etat t LEFT JOIN public.terrains_referentiel r ON r.pays = t.country AND r.batiment = t.building_id
     WHERE p_nom IN (t.proprietaire, t.coproprietaire)
    UNION ALL
    -- Casier judiciaire et peine en cours.
    SELECT p_nom || ' a déjà fait de la prison (' || x.n || ' détention' || CASE WHEN x.n > 1 THEN 's' ELSE '' END
           || ', la dernière pour « ' || coalesce(x.raison, 'motif inconnu') || ' »).'
      FROM (SELECT count(*) AS n, (array_agg(raison ORDER BY created_at DESC))[1] AS raison FROM public.detentions WHERE nom = p_nom) x
     WHERE x.n > 0
    UNION ALL
    SELECT p_nom || ' purge en ce moment une peine de prison.' FROM public.detention_active(p_nom) da WHERE da.id IS NOT NULL
    UNION ALL
    -- Relations : conjoint et employés.
    SELECT p_nom || ' est marié(e) à ' || CASE WHEN m.conjoint1 = p_nom THEN m.conjoint2 ELSE m.conjoint1 END || '.'
      FROM public.mariages m WHERE m.dissous_at IS NULL AND p_nom IN (m.conjoint1, m.conjoint2)
    UNION ALL
    SELECT p_nom || ' emploie ' || e.n || ' personne' || CASE WHEN e.n > 1 THEN 's' ELSE '' END || '.'
      FROM (SELECT greatest((SELECT CASE WHEN jsonb_typeof(d.employes) = 'array' THEN jsonb_array_length(d.employes) ELSE 0 END FROM d),
                            (SELECT count(*) FROM public.pnj_membres WHERE proprietaire_pj = p_nom)::integer) AS n) e
     WHERE e.n > 0
    UNION ALL
    -- Crimes passés non élucidés : rumeur seulement, aucune affaire ouverte.
    SELECT 'On murmure que ' || p_nom || ' serait derrière une affaire jamais élucidée (« ' || replace(a.type_action, '_', ' ')
           || ' ») à ' || public.sovarka_ville_nom_interne(a.country, a.city) || '.'
      FROM (SELECT * FROM public.actions_tracables WHERE auteur = p_nom AND NOT coalesce(decouvert, false)
             ORDER BY created_at DESC OFFSET 3 LIMIT 5) a
  )
  SELECT coalesce((SELECT t FROM c ORDER BY random() LIMIT 1), p_nom || ' n''a rien d''intéressant à cacher, paraît-il.');
$$;
REVOKE ALL ON FUNCTION public.hotel_secret_vrai_interne(text) FROM PUBLIC, anon, authenticated;

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
  PERFORM public.mail_systeme_poser_interne(CASE p_categorie WHEN 'secret_hammam' THEN 'Hôtel Royal d''Al-Khalija'
      WHEN 'secret_tito' THEN 'Tito Maletas (Hotel Ciudad Roja)' ELSE 'Salon des gentlemen' END,
    p_titulaire, 'Un secret de ' || p_sujet, p_sujet || ' : ' || p_secret, NULL);
END $$;
REVOKE ALL ON FUNCTION public.hotel_teaser_apprendre_interne(text, text, text, text, text, text) FROM PUBLIC, anon, authenticated;

-- ===================================================================== 8. Tito Maletas : un vrai secret du réseau Roxane Velours
CREATE OR REPLACE FUNCTION public.tito_secret_reseau_interne(p_acteur text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_cible text; v_source text := 'reservation'; v_secret text;
BEGIN
  -- Clients réels du standard Roxane Velours d'abord ; sinon un joueur réel au hasard. Jamais un PNJ ni un compte de test.
  SELECT d.name INTO v_cible FROM public.personnages_donnees d
   WHERE d.user_id IS NOT NULL AND d.name <> p_acteur AND NOT public.est_compte_test(d.name)
     AND d.name IN (SELECT appelant FROM public.escort_appels UNION SELECT client FROM public.escort_relations)
   ORDER BY random() LIMIT 1;
  IF v_cible IS NULL THEN
    v_source := 'reseau';
    SELECT d.name INTO v_cible FROM public.personnages_donnees d
     WHERE d.user_id IS NOT NULL AND d.name <> p_acteur AND NOT public.est_compte_test(d.name)
     ORDER BY random() LIMIT 1;
  END IF;
  IF v_cible IS NULL THEN RETURN jsonb_build_object('cible', NULL); END IF;
  v_secret := public.hotel_secret_vrai_interne(v_cible);
  PERFORM public.hotel_teaser_apprendre_interne(p_acteur, v_cible, 'confidence', 'secret_tito', v_secret, 'tito');
  RETURN jsonb_build_object('cible', v_cible, 'secret', v_secret, 'source', v_source);
END $$;
REVOKE ALL ON FUNCTION public.tito_secret_reseau_interne(text) FROM PUBLIC, anon, authenticated;

SELECT pg_temp.rp_remplacer('public.hotel_teaser_agir(uuid,text,text,integer)'::regprocedure,
$q$v_cible text := ''; v_rumeurs text[] := ARRAY[
          'Le Caudillo ne dort jamais deux nuits de suite dans le même palais.',
          'Les douaniers de Ciudad Roja touchent plus en billets qu''en salaire.',
          'Un avion sans immatriculation se pose chaque jeudi sur la piste nord.',
          'Le casino de la ville appartient à un neveu de Don Augusto Bigotes.',
          'Les gangs armés du port paient la sécurité de l''hôtel pour ne pas y entrer.',
          'Le ministre de l''Intérieur lit chaque matin les confidences recueillies dans les suites.',
          'Une réserve d''or attendrait sous la Banque nationale le retour d''un ancien président.',
          'Les élections d''El Estado se gagnent au poker, la veille du scrutin.'];$q$,
$q$v_cible text := ''; v_tito jsonb; /* tito_vrai_secret_decl_v1 */$q$,
'tito_vrai_secret_decl_v1');

SELECT pg_temp.rp_remplacer('public.hotel_teaser_agir(uuid,text,text,integer)'::regprocedure,
$q$      v_n := 1 + floor(random() * array_length(v_rumeurs, 1))::integer;
      r := r || jsonb_build_object('rumeur', v_n, 'rumeur_texte', v_rumeurs[v_n]);$q$,
$q$      v_tito := public.tito_secret_reseau_interne(a); /* tito_vrai_secret_v1 */
      r := r || jsonb_build_object('tito', v_tito);$q$,
'tito_vrai_secret_v1');

SELECT pg_temp.rp_remplacer('public.hotel_teaser_agir(uuid,text,text,integer)'::regprocedure,
$q$      v_n := least(1000, greatest(0, coalesce((SELECT liquide FROM public.personnages_donnees WHERE name = a), 0)::integer));
      IF v_n > 0 THEN UPDATE public.personnages_donnees SET liquide = liquide - v_n, updated_at = now() WHERE name = a; END IF;$q$,
$q$      v_n := floor(public.amende_prelever_interne(a, 1000))::integer; /* moeurs_amende_comptes_v1 */$q$,
'moeurs_amende_comptes_v1');

SELECT pg_temp.rp_remplacer('public.hotel_teaser_agir(uuid,text,text,integer)'::regprocedure,
'public.sovarka_maison_secret_pj_interne(', 'public.hotel_secret_vrai_interne(', 'hotel_secret_vrai_interne(', 4);

COMMIT;
