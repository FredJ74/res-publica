-- ACCÈS RÉSERVÉ : PAVILLON DES AMBASSADEURS ET RÉSIDENCE IMPÉRIALE DE NOVOMIRSK
-- (décisions de Fred du 11-12/11/2026, GAME-DESIGN-NOVOMIRSK.md, « Pavillon des Ambassadeurs — accès réservé »).
--  1. Seul l'accueil est ouvert à tous. Pavillon : bar, réception et suites réservés aux dignitaires (présidents,
--     Président du Conseil, ministres, ambassadeurs, députés, de Sovarka ou d'ailleurs). Résidence : chaque appartement
--     réservé à son locataire et à UNE personne de son groupe.
--  2. « Forcer le passage » : 2 PA, 60 % + 4 % par point de VOL au-dessus de 13. Réussite : le PJ entre, recherché.
--     Échec : combat contre le garde (moteur de combat, bataille « garde_acces ») ; s'il gagne, il entre, recherché.
--     Libre circulation jusqu'à sa sortie du bâtiment. Sanction : 1 jour et 1 500 PSK.
--  3. Résidence : location privative de 3 nuits renouvelables, payée d'avance (1 000 / 1 800 PSK la nuit, recette
--     municipale), rendue le 3e jour à 12 h 00 (heure de Paris) ; bonus de jauges à chaque nuit passée dans
--     l'appartement ; mini-bar de 3 bouteilles par location, « Remplir le minibar » 350 PSK.
-- Le serveur décide tout. Aucune donnée de joueur modifiée. Idempotente.
BEGIN;

-- 1. Tables (fermées au client).
CREATE TABLE IF NOT EXISTS public.acces_intrusions (
  acteur text NOT NULL, batiment text NOT NULL, cree_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (acteur, batiment));
CREATE TABLE IF NOT EXISTS public.acces_tentatives (
  id bigserial PRIMARY KEY, acteur text NOT NULL, batiment text NOT NULL, piece text NOT NULL,
  pnj_id text, statut text NOT NULL DEFAULT 'combat' CHECK (statut IN ('combat', 'vaincu', 'perdu')),
  cree_le timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.residence_locations (
  id bigserial PRIMARY KEY, piece text NOT NULL, locataire text NOT NULL,
  debut timestamptz NOT NULL DEFAULT now(), fin timestamptz NOT NULL,
  minibar integer NOT NULL DEFAULT 3 CHECK (minibar BETWEEN 0 AND 3),
  nuit_bonus date, cree_le timestamptz NOT NULL DEFAULT now());
CREATE INDEX IF NOT EXISTS residence_locations_piece_fin ON public.residence_locations (piece, fin);
CREATE INDEX IF NOT EXISTS residence_locations_locataire_fin ON public.residence_locations (locataire, fin);
CREATE TABLE IF NOT EXISTS public.acces_actes (
  acteur text NOT NULL, requete uuid NOT NULL, resultat jsonb NOT NULL, cree_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (acteur, requete));
ALTER TABLE public.acces_intrusions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.acces_tentatives ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.residence_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.acces_actes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.acces_intrusions, public.acces_tentatives, public.residence_locations, public.acces_actes
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.acces_tentatives_id_seq, public.residence_locations_id_seq FROM PUBLIC, anon, authenticated;

-- 2. Tarifs et acte illégal.
INSERT INTO public.ordres_couts (fn, pa, cost) VALUES
  ('forcer_passage', 2, 0), ('residence_reserver', 0, 3000), ('residence_reserver', 0, 5400), ('residence_minibar', 0, 350)
ON CONFLICT DO NOTHING;
INSERT INTO public.actes_illegaux (fn, type, detect_rate, peine_jours, amende, decouvrable)
VALUES ('forcer_passage', 'delit_mineur', 100, 1, 1500, false)
ON CONFLICT (fn) DO UPDATE SET type = EXCLUDED.type, detect_rate = EXCLUDED.detect_rate,
  peine_jours = EXCLUDED.peine_jours, amende = EXCLUDED.amende, decouvrable = EXCLUDED.decouvrable, maj_le = now();
-- L'ancienne location de local des appartements est fermée (remplacée par la réservation à l'accueil).
UPDATE public.locaux_loyers_referentiel SET louable = false
 WHERE batiment = 'residence-imperiale-novomirsk'
   AND piece IN ('appartement_1', 'appartement_2', 'appartement_3', 'appartement_4', 'grand_appartement');

-- 3. Référentiel des pièces réservées.
CREATE OR REPLACE FUNCTION public.acces_piece_reservee_interne(p_batiment text, p_piece text)
RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
  SELECT (p_batiment = 'pavillon-ambassadeurs-novomirsk'
           AND p_piece IN ('bar', 'salle_reception', 'suite_privee', 'suite_presidentielle', 'suite_parti'))
      OR (p_batiment = 'residence-imperiale-novomirsk'
           AND p_piece IN ('appartement_1', 'appartement_2', 'appartement_3', 'appartement_4', 'grand_appartement'));
$$;
CREATE OR REPLACE FUNCTION public.residence_prix_nuit_interne(p_piece text)
RETURNS integer LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN p_piece = 'grand_appartement' THEN 1800
              WHEN p_piece IN ('appartement_1', 'appartement_2', 'appartement_3', 'appartement_4') THEN 1000 END;
$$;

-- 4. Dignitaire (de Sovarka ou d'ailleurs) : président, Président du Conseil, ministre, ambassadeur, député.
CREATE OR REPLACE FUNCTION public.acces_dignitaire_interne(p_nom text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.postes_attribues a WHERE a.titulaire = p_nom
                    AND (a.poste_id IN ('president', 'pm') OR a.poste_id LIKE 'min\_%'))
      OR EXISTS (SELECT 1 FROM public.cycles_electoraux c WHERE c.id LIKE '%\_president' AND c.data::jsonb->>'eluId' = p_nom)
      OR EXISTS (SELECT 1 FROM public.ambassades_ouvertes a WHERE a.data->>'ambassadeur' = p_nom)
      OR EXISTS (SELECT 1 FROM public.personnages_donnees d WHERE d.name = p_nom
                    AND (d.poste_depute IS NOT NULL AND jsonb_typeof(d.poste_depute) = 'object'
                         OR d.poste->>'id' IN ('president', 'pm') OR coalesce(d.poste->>'id', '') LIKE 'min\_%'));
$$;
REVOKE ALL ON FUNCTION public.acces_dignitaire_interne(text) FROM PUBLIC, anon, authenticated;

-- Locataire actif d'un appartement de la Résidence (NULL si libre).
CREATE OR REPLACE FUNCTION public.residence_locataire_interne(p_piece text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT locataire FROM public.residence_locations WHERE piece = p_piece AND fin > now() ORDER BY fin DESC LIMIT 1;
$$;
REVOKE ALL ON FUNCTION public.residence_locataire_interne(text) FROM PUBLIC, anon, authenticated;

-- 5. Raison du refus d'entrer (NULL : accès permis).
CREATE OR REPLACE FUNCTION public.acces_reserve_raison_interne(p_nom text, p_batiment text, p_piece text)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_loc text; v_n integer;
BEGIN
  IF NOT public.acces_piece_reservee_interne(p_batiment, p_piece) THEN RETURN NULL; END IF;
  IF EXISTS (SELECT 1 FROM public.acces_intrusions WHERE acteur = p_nom AND batiment = p_batiment) THEN RETURN NULL; END IF;
  IF p_batiment = 'pavillon-ambassadeurs-novomirsk' THEN
    RETURN CASE WHEN public.acces_dignitaire_interne(p_nom) THEN NULL ELSE 'acces_dignitaires' END;
  END IF;
  v_loc := public.residence_locataire_interne(p_piece);
  IF v_loc IS NULL THEN RETURN 'location_requise'; END IF;
  IF v_loc = p_nom THEN RETURN NULL; END IF;
  -- Une seule personne accompagne le locataire : membre de son groupe, groupe d'un seul membre.
  IF EXISTS (SELECT 1 FROM public.groupes_pj_adhesions WHERE membre = p_nom AND chef = v_loc) THEN
    SELECT count(*) INTO v_n FROM public.groupes_pj_adhesions WHERE chef = v_loc;
    RETURN CASE WHEN v_n <= 1 THEN NULL ELSE 'un_seul_invite' END;
  END IF;
  RETURN 'location_requise';
END $$;
REVOKE ALL ON FUNCTION public.acces_reserve_raison_interne(text, text, text) FROM PUBLIC, anon, authenticated;

-- 6. Navigation intérieure : porte serveur (patch en place, ancre vérifiée).
DO $mig$
DECLARE d text; avant text; apres text;
BEGIN
  d := pg_get_functiondef('public.navigation_interieure_personnage_interne(text,text,text,boolean)'::regprocedure);
  IF position('acces_reserve_v1' IN d) = 0 THEN
    avant := E' -- ssm_acces_sur_rendezvous_v1';
    apres := E' -- acces_reserve_v1 (Fred, 12/11/2026) : Pavillon des Ambassadeurs et Résidence impériale de Novomirsk.\n'
      || E' IF p.country=''soviet'' AND p.current_city=''capitale'' AND p_batiment IN (''pavillon-ambassadeurs-novomirsk'',''residence-imperiale-novomirsk'') THEN\n'
      || E'  IF p.current_building IS DISTINCT FROM p_batiment AND NOT p_verifier THEN DELETE FROM public.acces_intrusions WHERE acteur=p_nom AND batiment=p_batiment; END IF;\n'
      || E'  IF p.current_building IS DISTINCT FROM p_batiment OR p.current_room IS DISTINCT FROM p_piece THEN\n'
      || E'   r:=CASE WHEN public.acces_reserve_raison_interne(p_nom,p_batiment,p_piece) IS NULL THEN NULL\n'
      || E'      ELSE jsonb_build_object(''ok'',false,''raison'',public.acces_reserve_raison_interne(p_nom,p_batiment,p_piece),''batiment'',p_batiment,''piece'',p_piece,''membre'',p_nom) END;\n'
      || E'   IF r IS NOT NULL THEN RETURN r; END IF;\n'
      || E'  END IF;\n'
      || E' END IF;\n'
      || avant;
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'navigation : ancrage introuvable'; END IF;
    EXECUTE replace(d, avant, apres);
  END IF;
END $mig$;

-- 7. Garde à affronter.
CREATE OR REPLACE FUNCTION public.acces_garde_interne(p_batiment text)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_batiment
    WHEN 'pavillon-ambassadeurs-novomirsk' THEN '{"nom":"Arkadi Belov","piece":"hall_pavillon"}'::jsonb
    WHEN 'residence-imperiale-novomirsk' THEN '{"nom":"Lev Zamkov","piece":"hall_residence"}'::jsonb END;
$$;

-- 8. Forcer le passage.
CREATE OR REPLACE FUNCTION public.acces_forcer_passage(p_requete uuid, p_piece text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); p record; x record; v_paie jsonb; v_vol integer; v_taux integer; v_jet integer;
        g jsonb; v_id bigint; v_pnj text; r jsonb; v_raison text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_absente'); END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('acces_reserve:' || a, 0));
  SELECT * INTO x FROM public.acces_actes WHERE acteur = a AND requete = p_requete;
  IF FOUND THEN RETURN x.resultat || jsonb_build_object('rejeu', true); END IF;
  SELECT country, current_city, current_building, current_room, stats, hp INTO p FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF p.country IS DISTINCT FROM 'soviet' OR p.current_city IS DISTINCT FROM 'capitale'
     OR p.current_building NOT IN ('pavillon-ambassadeurs-novomirsk', 'residence-imperiale-novomirsk')
     OR NOT public.acces_piece_reservee_interne(p.current_building, p_piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF coalesce(p.hp, 0) <= 0 OR EXISTS (SELECT 1 FROM public.detention_active(a)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_indisponible'); END IF;
  v_raison := public.acces_reserve_raison_interne(a, p.current_building, p_piece);
  IF v_raison IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acces_deja_autorise'); END IF;
  v_paie := public.payer_ordre(a, 'forcer_passage', 2, 0);
  IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_vol := coalesce(CASE WHEN jsonb_typeof(p.stats->'VOL') = 'number' THEN (p.stats->>'VOL')::integer END, 10);
  v_taux := least(100, greatest(0, 60 + 4 * (v_vol - 13)));
  v_jet := floor(random() * 100)::integer + 1;
  IF v_jet <= v_taux THEN
    INSERT INTO public.acces_intrusions (acteur, batiment) VALUES (a, p.current_building)
      ON CONFLICT (acteur, batiment) DO UPDATE SET cree_le = now();
    PERFORM public.crime_rechercher_interne(a, 'forcer_passage', 'delit_mineur');
    PERFORM public.crime_tracer_interne(a, 'forcer_passage', p.current_building);
    r := jsonb_build_object('ok', true, 'reussi', true, 'taux', v_taux, 'jet', v_jet, 'batiment', p.current_building, 'piece', p_piece);
  ELSE
    g := public.acces_garde_interne(p.current_building);
    INSERT INTO public.acces_tentatives (acteur, batiment, piece) VALUES (a, p.current_building, p_piece) RETURNING id INTO v_id;
    v_pnj := 'garde_acces:' || v_id;
    INSERT INTO public.pnj_membres (id, famille, nom, pays, ville, building_id, room_id, classe, pa, proprietaire_institution, proprietaire_perimetre,
                                    car_int, car_cha, car_vol, car_per, car_dup, car_ent)
    VALUES (v_pnj, 'employe', g->>'nom', 'soviet', 'capitale', p.current_building, p.current_room, 'beta', public.pnj_pa_max(),
            'garde_acces', 'soviet:capitale:' || p.current_building, 10, 8, 12, 12, 8, 8)
    ON CONFLICT (id) DO NOTHING;
    UPDATE public.acces_tentatives SET pnj_id = v_pnj WHERE id = v_id;
    r := jsonb_build_object('ok', true, 'reussi', false, 'combat', true, 'taux', v_taux, 'jet', v_jet,
      'pnj', v_pnj, 'garde', g->>'nom', 'batiment', p.current_building, 'piece', p_piece);
  END IF;
  r := r || public.crime_etat_acteur_interne(a);
  INSERT INTO public.acces_actes (acteur, requete, resultat) VALUES (a, p_requete, r - 'inventory' - 'inventaire');
  RETURN r;
END $$;
REVOKE ALL ON FUNCTION public.acces_forcer_passage(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.acces_forcer_passage(uuid, text) TO authenticated;

-- 9. Issue du combat contre le garde (appelée par le moteur de combat).
CREATE OR REPLACE FUNCTION public.acces_issue_combat_interne(p_pnj text, p_leader text, p_issue text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE t record;
BEGIN
  SELECT * INTO t FROM public.acces_tentatives WHERE pnj_id = p_pnj FOR UPDATE;
  UPDATE public.pnj_membres SET statut = 'disparu', maj_le = now() WHERE id = p_pnj AND statut = 'actif';
  IF NOT FOUND OR t.statut <> 'combat' THEN RETURN jsonb_build_object('ok', true, 'issue', p_issue, 'deja', true); END IF;
  IF p_issue IN ('tues', 'neutralises') THEN
    INSERT INTO public.acces_intrusions (acteur, batiment) VALUES (t.acteur, t.batiment)
      ON CONFLICT (acteur, batiment) DO UPDATE SET cree_le = now();
    PERFORM public.crime_rechercher_interne(t.acteur, 'forcer_passage', 'delit_mineur');
    PERFORM public.crime_tracer_interne(t.acteur, 'forcer_passage', t.batiment);
    UPDATE public.acces_tentatives SET statut = 'vaincu' WHERE id = t.id;
  ELSE
    UPDATE public.acces_tentatives SET statut = 'perdu' WHERE id = t.id;
  END IF;
  RETURN jsonb_build_object('ok', true, 'issue', p_issue, 'batiment', t.batiment, 'piece', t.piece);
END $$;
REVOKE ALL ON FUNCTION public.acces_issue_combat_interne(text, text, text) FROM PUBLIC, anon, authenticated;

-- 10. Raccords au moteur de combat (ancres posées par la forêt de Krasnov, vérifiées).
DO $raccord$
DECLARE d text; avant text; apres text;
BEGIN
  d := pg_get_functiondef('public.combat_ouvrir_interne(text,text,uuid)'::regprocedure);
  IF position('acces_reserve_garde_v1' IN d) = 0 THEN
    avant := E'WHEN pnj LIKE ''faune:%'' THEN ''faune'' /* sovarka_foret_faune_v1 */';
    apres := avant || E' WHEN pnj LIKE ''garde_acces:%'' THEN ''garde_acces'' /* acces_reserve_garde_v1 */';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'combat_ouvrir_interne : ancrage introuvable'; END IF;
    EXECUTE replace(d, avant, apres);
  END IF;
  d := pg_get_functiondef('public.combat_finaliser_interne(bigint)'::regprocedure);
  IF position('acces_reserve_garde_v1' IN d) = 0 THEN
    avant := E'NOT IN (''civil'',''squatteurs'',''faune'')';
    apres := E'NOT IN (''civil'',''squatteurs'',''faune'',''garde_acces'')';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'combat_finaliser_interne : ancrage 1 introuvable'; END IF;
    d := replace(d, avant, apres);
    avant := E' IF b.contexte->>''type''=''faune'' THEN';
    apres := E' -- acces_reserve_garde_v1 : garde du Pavillon ou de la Résidence, la voie est libre s''il est vaincu.\n'
          || E' IF b.contexte->>''type''=''garde_acces'' THEN\n'
          || E'  v:=public.acces_issue_combat_interne(b.contexte->>''cible'',b.contexte->>''acteur'',issue);\n'
          || E' ELSIF b.contexte->>''type''=''faune'' THEN';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'combat_finaliser_interne : ancrage 2 introuvable'; END IF;
    EXECUTE replace(d, avant, apres);
  END IF;
END $raccord$;

-- 11. Résidence : état lu à l'accueil ou dans un appartement.
CREATE OR REPLACE FUNCTION public.residence_etat()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); p record; m record;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room INTO p FROM public.personnages_donnees WHERE name = a;
  IF p.country IS DISTINCT FROM 'soviet' OR p.current_city IS DISTINCT FROM 'capitale'
     OR p.current_building IS DISTINCT FROM 'residence-imperiale-novomirsk' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  SELECT * INTO m FROM public.residence_locations WHERE locataire = a AND fin > now() ORDER BY fin DESC LIMIT 1;
  RETURN jsonb_build_object('ok', true, 'piece_courante', p.current_room,
    'appartements', (SELECT jsonb_agg(jsonb_build_object('piece', x.piece, 'prix_nuit', public.residence_prix_nuit_interne(x.piece),
        'libre', public.residence_locataire_interne(x.piece) IS NULL) ORDER BY x.o)
      FROM (VALUES ('appartement_1', 1), ('appartement_2', 2), ('appartement_3', 3), ('appartement_4', 4), ('grand_appartement', 5)) x(piece, o)),
    'ma_location', CASE WHEN m.id IS NULL THEN NULL ELSE jsonb_build_object('piece', m.piece,
        'fin', to_char(m.fin AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI'), 'minibar', m.minibar,
        'prix_nuit', public.residence_prix_nuit_interne(m.piece)) END);
END $$;
REVOKE ALL ON FUNCTION public.residence_etat() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.residence_etat() TO authenticated;

-- 12. Résidence : réserver, renouveler, mini-bar.
CREATE OR REPLACE FUNCTION public.residence_acte(p_requete uuid, p_action text, p_piece text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); p record; x record; m record; v_paie jsonb; v_prix integer; v_total integer;
        r jsonb; v_dep jsonb; v_fin timestamptz;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_absente'); END IF;
  IF p_action NOT IN ('reserver', 'renouveler', 'minibar_prendre', 'minibar_remplir') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'action_inconnue'); END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('residence_imperiale', 0));
  SELECT * INTO x FROM public.acces_actes WHERE acteur = a AND requete = p_requete;
  IF FOUND THEN RETURN x.resultat || jsonb_build_object('rejeu', true); END IF;
  SELECT country, current_city, current_building, current_room, hp INTO p FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF p.country IS DISTINCT FROM 'soviet' OR p.current_city IS DISTINCT FROM 'capitale'
     OR p.current_building IS DISTINCT FROM 'residence-imperiale-novomirsk' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  SELECT * INTO m FROM public.residence_locations WHERE locataire = a AND fin > now() ORDER BY fin DESC LIMIT 1 FOR UPDATE;

  IF p_action = 'reserver' THEN
    IF p.current_room IS DISTINCT FROM 'hall_residence' THEN RETURN jsonb_build_object('ok', false, 'raison', 'reservation_a_l_accueil'); END IF;
    v_prix := public.residence_prix_nuit_interne(p_piece);
    IF v_prix IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'appartement_inconnu'); END IF;
    IF m.id IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_locataire'); END IF;
    IF public.residence_locataire_interne(p_piece) IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'appartement_occupe'); END IF;
    v_total := 3 * v_prix;
    v_paie := public.payer_ordre(a, 'residence_reserver', 0, v_total);
    IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
    PERFORM public.recette_municipale('soviet', 'capitale', v_total, 'loyer');
    v_fin := (((now() AT TIME ZONE 'Europe/Paris')::date + 3) + time '12:00') AT TIME ZONE 'Europe/Paris';
    INSERT INTO public.residence_locations (piece, locataire, fin) VALUES (p_piece, a, v_fin);
    r := jsonb_build_object('ok', true, 'action', p_action, 'piece', p_piece, 'montant', v_total,
      'fin', to_char(v_fin AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI'), 'minibar', 3);

  ELSIF p_action = 'renouveler' THEN
    IF m.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucune_location'); END IF;
    v_total := 3 * public.residence_prix_nuit_interne(m.piece);
    v_paie := public.payer_ordre(a, 'residence_reserver', 0, v_total);
    IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
    PERFORM public.recette_municipale('soviet', 'capitale', v_total, 'loyer');
    UPDATE public.residence_locations SET fin = fin + interval '3 days', minibar = 3 WHERE id = m.id RETURNING fin INTO v_fin;
    r := jsonb_build_object('ok', true, 'action', p_action, 'piece', m.piece, 'montant', v_total,
      'fin', to_char(v_fin AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI'), 'minibar', 3);

  ELSE
    IF m.id IS NULL OR p.current_room IS DISTINCT FROM m.piece THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'dans_son_appartement'); END IF;
    IF p_action = 'minibar_prendre' THEN
      IF m.minibar <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'minibar_vide'); END IF;
      v_dep := public.inventaire_deposer_interne(a, jsonb_build_object('name', 'Vodka', 'icon', 'ti-bottle', 'stackable', true,
        'stackKey', 'vodka', 'qty', 1, 'legal', true, 'desc', 'Bouteille du mini-bar de la Résidence impériale.'));
      IF coalesce((v_dep->>'ok')::boolean, false) IS NOT TRUE THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
      UPDATE public.residence_locations SET minibar = minibar - 1 WHERE id = m.id;
      r := jsonb_build_object('ok', true, 'action', p_action, 'minibar', m.minibar - 1);
    ELSE
      IF m.minibar >= 3 THEN RETURN jsonb_build_object('ok', false, 'raison', 'minibar_plein'); END IF;
      v_paie := public.payer_ordre(a, 'residence_minibar', 0, 350);
      IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
      PERFORM public.recette_municipale('soviet', 'capitale', 350, 'loyer');
      UPDATE public.residence_locations SET minibar = 3 WHERE id = m.id;
      r := jsonb_build_object('ok', true, 'action', p_action, 'minibar', 3, 'montant', 350);
    END IF;
  END IF;
  r := r || (SELECT jsonb_build_object('pa', pa, 'liquide', liquide, 'arg', arg, 'inventory', inventory, 'revision', inventory_revision)
               FROM public.personnages_donnees WHERE name = a);
  INSERT INTO public.acces_actes (acteur, requete, resultat) VALUES (a, p_requete, r - 'inventory');
  RETURN r;
END $$;
REVOKE ALL ON FUNCTION public.residence_acte(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.residence_acte(uuid, text, text) TO authenticated;

-- 13. Bonus de jauges à chaque nuit passée dans l'appartement loué (une fois par jour).
CREATE OR REPLACE FUNCTION public.residence_bonus_nuit_interne(p_nom text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE m record; v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date; g boolean;
BEGIN
  SELECT l.* INTO m FROM public.residence_locations l JOIN public.personnages_donnees d ON d.name = l.locataire
   WHERE l.locataire = p_nom AND l.fin > now() AND d.current_building = 'residence-imperiale-novomirsk' AND d.current_room = l.piece
     AND l.nuit_bonus IS DISTINCT FROM v_jour
   ORDER BY l.fin DESC LIMIT 1 FOR UPDATE OF l;
  IF NOT FOUND THEN RETURN; END IF;
  g := m.piece = 'grand_appartement';
  PERFORM public.jauges_effet_appliquer_interne(p_nom, CASE WHEN g THEN 15 ELSE 4 END, CASE WHEN g THEN 15 ELSE 4 END, 0);
  UPDATE public.personnages_donnees
     SET resources = jsonb_set(CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END, '{dis}',
           to_jsonb(least(100, coalesce(CASE WHEN jsonb_typeof(resources->'dis') = 'number' THEN (resources->>'dis')::numeric END, 50)
                               + CASE WHEN g THEN 5 ELSE 4 END)))
   WHERE name = p_nom;
  UPDATE public.residence_locations SET nuit_bonus = v_jour WHERE id = m.id;
END $$;
REVOKE ALL ON FUNCTION public.residence_bonus_nuit_interne(text) FROM PUBLIC, anon, authenticated;

DO $mig$
DECLARE d text; avant text;
BEGIN
  d := pg_get_functiondef('public.pa_repos_nocturne(text)'::regprocedure);
  IF position('residence_bonus_nuit_interne' IN d) = 0 THEN
    avant := E'    THEN v_gain := v_gain + 3; END IF;\n';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'pa_repos_nocturne : ancrage introuvable'; END IF;
    EXECUTE replace(d, avant, avant
      || E'    -- residence_imperiale_v1 : nuit passée dans son appartement loué de la Résidence impériale.\n'
      || E'    PERFORM public.residence_bonus_nuit_interne(p_acteur);\n');
  END IF;
END $mig$;

-- 14. Contrôles structurels.
DO $$
BEGIN
  IF position('acces_reserve_v1' IN pg_get_functiondef('public.navigation_interieure_personnage_interne(text,text,text,boolean)'::regprocedure)) = 0
     OR position('acces_reserve_garde_v1' IN pg_get_functiondef('public.combat_ouvrir_interne(text,text,uuid)'::regprocedure)) = 0
     OR position('acces_reserve_garde_v1' IN pg_get_functiondef('public.combat_finaliser_interne(bigint)'::regprocedure)) = 0
     OR position('residence_bonus_nuit_interne' IN pg_get_functiondef('public.pa_repos_nocturne(text)'::regprocedure)) = 0
     OR has_table_privilege('authenticated', 'public.residence_locations', 'SELECT')
     OR NOT EXISTS (SELECT 1 FROM public.actes_illegaux WHERE fn = 'forcer_passage' AND peine_jours = 1 AND amende = 1500) THEN
    RAISE EXCEPTION 'acces_reserve : contrôle structurel en échec';
  END IF;
END $$;

COMMIT;
