-- Ministères de Sovarka, lot 2 : décisions de Fred du 08/11/2026 (tour des bureaux du Palais du Gouvernement,
-- GAME-DESIGN-NOVOMIRSK.md, « Ministères de Sovarka : décisions du tour du 08/11 »).
--  1. Président du Conseil : trancher un projet de loi coûte 1 PA par projet (promulguer ou refuser).
--  2. Grâce : proposée par le ministre de la Justice, TRANSMISE (ou non) par le Président du Conseil (1 PA par
--     décision), puis accordée par le Président de la République (circuit inchangé, statut 'attente').
--  3. Manifestation de soutien : le chef de parti la DEMANDE ; le ministre de la Sécurité du Peuple l'accepte ou
--     la refuse (1 PA) ; une fois acceptée, il ne peut plus l'interdire, seulement la réprimer (3 PA).
--     Sans ministre PJ, la demande est acceptée d'office (règle des autorités PNJ).
--  4-5. Budget et dotations : exclus de cette reprise, car remplaces par des decisions ulterieures.
--  6. Salaire du Président de la République payé par la caisse de l'Économie collective.
--  7. Subvention plafonnée à 150 PSK ; propagande 150 PSK ; sondage 60 PSK ; Garde de la Patrie : Palais du
--     Gouvernement seul, 15 PSK par garde supplémentaire ; réquisition civile fermée (la conscription la remplace).

-- ---------------------------------------------------------------- Tables
CREATE TABLE IF NOT EXISTS public.sovarka_manif_demandes (
  id bigserial PRIMARY KEY, ts timestamptz NOT NULL DEFAULT now(), parti text NOT NULL, chef text NOT NULL,
  ville text NOT NULL, statut text NOT NULL DEFAULT 'demande'
    CHECK (statut IN ('demande', 'acceptee', 'refusee', 'faite', 'reprimee')),
  decide_par text, decide_ts timestamptz, jour_limite date, manif_id bigint, reprime_par text, reprime_ts timestamptz);
CREATE INDEX IF NOT EXISTS sovarka_manif_demandes_ville ON public.sovarka_manif_demandes (ville, statut);
ALTER TABLE public.sovarka_manif_demandes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_manif_demandes FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.sovarka_manif_demandes_id_seq FROM PUBLIC, anon, authenticated;

INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT x.fn, x.pa, x.cost FROM (VALUES ('sovarka_loi_trancher', 1, 0), ('sovarka_grace_transmettre', 1, 0),
  ('sovarka_graces', 0, 0), ('sovarka_manifs_gerer', 0, 0), ('sovarka_manif_decider', 1, 0),
  ('sovarka_manif_reprimer', 3, 0), ('sovarka_manif_demander', 0, 0), ('propagande_etat@soviet', 3, 150)) AS x(fn, pa, cost)
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts o WHERE o.fn = x.fn);

-- IMPORTANT (14/11/2026): la redistribution a ete remplacee depuis le 08/11.
-- La repartition actuelle de Sovarka (3/9/15/9/9/9/9/9/9/19) fait autorite.
-- Aucune modification de repartitions_budgetaires, de soldes ou de dotations.

-- ---------------------------------------------------------------- Garde de la Patrie : Palais du Gouvernement seul
INSERT INTO public.garde_republicaine_postes (pays, ville, libelle, room_id, building_id, vacant_depuis)
VALUES ('soviet', 'capitale', 'Hall d entree du Palais du Gouvernement', 'hall', 'palais-gouvernement', NULL)
ON CONFLICT (pays, building_id) DO NOTHING;

-- ---------------------------------------------------------------- Subvention : plafond par pays
CREATE OR REPLACE FUNCTION public.subvention_plafond_interne()
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN (SELECT country FROM public.personnages_donnees WHERE name = public.mon_personnage()) = 'soviet'
              THEN 150 ELSE 5000 END
$$;
REVOKE ALL ON FUNCTION public.subvention_plafond_interne() FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------- Correctifs en place (fragments uniques vérifiés)
DO $patch$
DECLARE r record; f record; v_def text; v_n int;
BEGIN
  CREATE TEMP TABLE patch_fragments (n serial, fn text, avant text, apres text) ON COMMIT DROP;
  INSERT INTO patch_fragments (fn, avant, apres) VALUES
    -- 1. Trancher un projet de loi : 1 PA par projet.
    ('public.sovarka_pouvoir_commande(uuid,text,jsonb)', $a$      ELSIF (p_params->>'accepter')::boolean THEN$a$,
     $b$      ELSE
        v_paie := public.payer_ordre_interne(a, 'sovarka_loi_trancher', 1, 0);
        IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN v := v_paie;
      ELSIF (p_params->>'accepter')::boolean THEN$b$),
    ('public.sovarka_pouvoir_commande(uuid,text,jsonb)', $a$'statut', 'adoptee');$a$,
     $b$'statut', 'adoptee', 'pa', v_paie->'pa', 'liquide', v_paie->'liquide', 'arg', v_paie->'arg');$b$),
    ('public.sovarka_pouvoir_commande(uuid,text,jsonb)', $a$'statut', 'rejetee');
      END IF;
$a$,
     $b$'statut', 'rejetee', 'pa', v_paie->'pa', 'liquide', v_paie->'liquide', 'arg', v_paie->'arg');
      END IF;
      END IF;
$b$),
    -- 3. Manifestation de soutien : seulement sur demande acceptée et non réprimée.
    ('public.sovarka_pouvoir_commande(uuid,text,jsonb)', $a$v_pop numeric; v_pm text; v_deps text;$a$,
     $b$v_pop numeric; v_pm text; v_deps text; v_dem_id bigint;$b$),
    ('public.sovarka_pouvoir_commande(uuid,text,jsonb)', $a$        PERFORM pg_advisory_xact_lock(hashtextextended('sovarka:manif:' || p.current_city, 0));
        IF EXISTS (SELECT 1 FROM public.sovarka_manifs WHERE ville = p.current_city AND jour = v_jour) THEN$a$,
     $b$        PERFORM pg_advisory_xact_lock(hashtextextended('sovarka:manif:' || p.current_city, 0));
        SELECT id INTO v_dem_id FROM public.sovarka_manif_demandes
         WHERE parti = v_parti AND ville = p.current_city AND statut = 'acceptee' AND jour_limite >= v_jour
         ORDER BY id LIMIT 1 FOR UPDATE;
        IF v_dem_id IS NULL THEN
          v := jsonb_build_object('ok', false, 'raison', 'manif_non_autorisee');
        ELSIF EXISTS (SELECT 1 FROM public.sovarka_manifs WHERE ville = p.current_city AND jour = v_jour) THEN$b$),
    ('public.sovarka_pouvoir_commande(uuid,text,jsonb)', $a$              VALUES (p.current_city, v_jour, v_parti, v_beneficiaire, a, v_noms, v_n);$a$,
     $b$              VALUES (p.current_city, v_jour, v_parti, v_beneficiaire, a, v_noms, v_n);
              UPDATE public.sovarka_manif_demandes SET statut = 'faite',
                     manif_id = (SELECT id FROM public.sovarka_manifs WHERE ville = p.current_city AND jour = v_jour)
               WHERE id = v_dem_id;$b$),
    -- 7. Sondage de Sovarka : 60 PSK.
    ('public.sovarka_pouvoir_commande(uuid,text,jsonb)', $a$public.payer_ordre_interne(a, 'commanditer_sondage', 1, 200)$a$,
     $b$public.payer_ordre_interne(a, 'commanditer_sondage', 1, 60)$b$),
    -- 6. Salaire du Président de Sovarka : caisse de l'Économie collective.
    ('public.salaire_caisse_de(text,text,text)', $a$BEGIN
  SELECT * INTO r FROM public.salaires_caisses s WHERE s.poste_id = p_poste_id;$a$,
     $b$BEGIN
  -- Fred, 08/11/2026 : en Sovarka, le salaire et les dépenses du Président sont payés par l'Économie collective.
  IF p_poste_id = 'president' AND p_pays = 'soviet' THEN RETURN 'soviet_gouvernement-min_fin'; END IF;
  SELECT * INTO r FROM public.salaires_caisses s WHERE s.poste_id = p_poste_id;$b$),
    -- 7. Plafond des subventions par pays.
    ('public.subvention_citoyen_verser(text,integer)', $a$p_montant > 5000 THEN$a$, $b$p_montant > public.subvention_plafond_interne() THEN$b$),
    ('public.subvention_collective_verser(text,text,text,integer)', $a$p_montant > 5000 THEN$a$, $b$p_montant > public.subvention_plafond_interne() THEN$b$),
    ('public.subvention_entreprise_verser(text,integer,text)', $a$p_montant > 5000 THEN$a$, $b$p_montant > public.subvention_plafond_interne() THEN$b$),
    -- 7. Garde de la Patrie : 15 PSK par garde supplémentaire.
    ('public.garde_renfort_national(integer)', $a$  v_cout := v_sup * 50;$a$,
     $b$  v_cout := v_sup * CASE WHEN a.pays = 'soviet' THEN 15 ELSE 50 END;$b$),
    -- 7. Propagande de Sovarka : coût déclaré propre (150 PSK).
    ('public.communication_officielle_publier(text,text,text,integer,integer,text,text,jsonb,boolean)',
     $a$WHERE o.fn = p_fn AND o.pa = coalesce(p_pa,0) AND o.cost = coalesce(p_cost,0)) THEN$a$,
     $b$WHERE o.fn = p_fn || CASE WHEN a.pays = 'soviet' AND p_fn = 'propagande_etat' THEN '@soviet' ELSE '' END
                    AND o.pa = coalesce(p_pa,0) AND o.cost = coalesce(p_cost,0)) THEN$b$),
    -- 7. Réquisition civile fermée en Sovarka (la conscription la remplace).
    ('public.militaire_requisition_civile(text,text)', $a$  SELECT coalesce((b.data->>'mobilisationNationaleActive')::boolean, false) INTO v_mobilisee$a$,
     $b$  IF v_pays = 'soviet' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'conscription_en_sovarka');
  END IF;
  SELECT coalesce((b.data->>'mobilisationNationaleActive')::boolean, false) INTO v_mobilisee$b$)
;
  -- Tous les fragments d'une même fonction sont appliqués avant de la recréer (une étape isolée ne compile pas).
  FOR f IN SELECT fn, min(n) AS premier FROM patch_fragments GROUP BY fn ORDER BY min(n) LOOP
    v_def := pg_get_functiondef(f.fn::regprocedure);
    FOR r IN SELECT * FROM patch_fragments WHERE fn = f.fn ORDER BY n LOOP
      v_n := (length(v_def) - length(replace(v_def, r.avant, ''))) / length(r.avant);
      IF v_n <> 1 THEN RAISE EXCEPTION 'fragment non unique dans % (%) : %', r.fn, v_n, left(r.avant, 80); END IF;
      v_def := replace(v_def, r.avant, r.apres);
    END LOOP;
    EXECUTE v_def;
  END LOOP;
  DROP TABLE patch_fragments;
END $patch$;

-- ---------------------------------------------------------------- 2. Grâce : transmission par le Président du Conseil
CREATE OR REPLACE FUNCTION public.sovarka_grace_garder()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.data->>'pays' = 'soviet' AND NEW.statut = 'attente' THEN NEW.statut := 'attente_pm'; END IF;
  ELSIF OLD.statut = 'attente_pm' AND NEW.statut IS DISTINCT FROM OLD.statut
        AND current_setting('rp.sovarka_grace_pm', true) IS DISTINCT FROM 'on' THEN
    RAISE EXCEPTION 'grace_transmission_pm_requise' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.sovarka_grace_garder() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS sovarka_grace_garder ON public.demandes_grace;
CREATE TRIGGER sovarka_grace_garder BEFORE INSERT OR UPDATE ON public.demandes_grace
  FOR EACH ROW EXECUTE FUNCTION public.sovarka_grace_garder();

-- ---------------------------------------------------------------- Lecture des dossiers des ministères (grâces, manifestations)
CREATE OR REPLACE FUNCTION public.sovarka_ministeres_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); v_jour date := public.sovarka_jour_paris(); v_parti text;
  v_pm boolean; v_min_int boolean; v_out jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_pm := public.sovarka_est_titulaire_interne(a, 'pm');
  v_min_int := public.sovarka_est_titulaire_interne(a, 'min_int');
  v_parti := public.sovarka_parti_de(a);
  v_out := jsonb_build_object('ok', true, 'pm', v_pm, 'min_int', v_min_int, 'jour', v_jour,
    'chef_parti', EXISTS (SELECT 1 FROM public.organisations o WHERE o.id = v_parti AND o.data::jsonb->>'chef' = a));
  IF v_pm THEN
    v_out := v_out || jsonb_build_object('graces', coalesce((SELECT jsonb_agg(jsonb_build_object('id', g.id,
      'condamne', g.data->>'nomCondamne', 'raison', g.data->>'raison', 'propose_par', g.data->>'proposePar',
      'jour_fin', g.data->'jourFin') ORDER BY g.created_at)
      FROM public.demandes_grace g WHERE g.statut = 'attente_pm' AND g.data->>'pays' = 'soviet'), '[]'::jsonb));
  END IF;
  IF v_min_int THEN
    v_out := v_out || jsonb_build_object('manifs', coalesce((SELECT jsonb_agg(jsonb_build_object('id', m.id,
      'parti', coalesce((SELECT o.data::jsonb->>'nom' FROM public.organisations o WHERE o.id = m.parti), m.parti),
      'chef', m.chef, 'ville', m.ville, 'statut', m.statut, 'jour_limite', m.jour_limite) ORDER BY m.id)
      FROM public.sovarka_manif_demandes m
     WHERE m.statut = 'demande' OR (m.statut = 'acceptee' AND m.jour_limite >= v_jour)
        OR (m.statut = 'faite' AND (SELECT s.jour FROM public.sovarka_manifs s WHERE s.id = m.manif_id) = v_jour)), '[]'::jsonb));
  END IF;
  IF v_parti IS NOT NULL THEN
    v_out := v_out || jsonb_build_object('mes_demandes', coalesce((SELECT jsonb_agg(jsonb_build_object('id', m.id,
      'ville', m.ville, 'statut', m.statut, 'jour_limite', m.jour_limite) ORDER BY m.id DESC)
      FROM (SELECT * FROM public.sovarka_manif_demandes WHERE parti = v_parti ORDER BY id DESC LIMIT 5) m), '[]'::jsonb));
  END IF;
  RETURN v_out;
END $$;
REVOKE ALL ON FUNCTION public.sovarka_ministeres_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_ministeres_lire() TO authenticated;

-- ---------------------------------------------------------------- Actes : grâces et manifestations
CREATE OR REPLACE FUNCTION public.sovarka_ministeres_commande(p_requete uuid, p_action text, p_params jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE
  a text := public.mon_personnage(); act text := 'sovarka:ministeres'; par jsonb; v jsonb; dt text; p record;
  v_paie jsonb; v_parti text; d jsonb; g public.demandes_grace; m public.sovarka_manif_demandes;
  v_jour date := public.sovarka_jour_paris(); v_min text; v_president text; v_effet integer; v_benef text;
  v_ville_nom text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  p_params := coalesce(p_params, '{}'::jsonb);
  par := jsonb_build_object('action', p_action, 'params', p_params);
  v := public.achat_requete_ouvrir_interne(a, p_requete, act, par);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    SELECT name, country, current_city, current_building, current_room INTO p
      FROM public.personnages_donnees WHERE name = a FOR UPDATE;
    v_parti := public.sovarka_parti_de(a);

    IF p.country IS DISTINCT FROM 'soviet' THEN
      v := jsonb_build_object('ok', false, 'raison', 'reserve_a_sovarka');

    -- ---------------------------------------------------------- Grâce : le Président du Conseil transmet ou non
    ELSIF p_action = 'grace_transmettre' THEN
      SELECT * INTO g FROM public.demandes_grace WHERE id = p_params->>'grace' FOR UPDATE;
      IF NOT public.sovarka_est_titulaire_interne(a, 'pm') THEN v := jsonb_build_object('ok', false, 'raison', 'reserve_president_du_conseil');
      ELSIF NOT (p.current_city = 'capitale' AND p.current_building = 'palais-gouvernement' AND p.current_room = 'bureaux') THEN
        v := jsonb_build_object('ok', false, 'raison', 'bureau_du_president_du_conseil_requis');
      ELSIF g.id IS NULL OR g.statut <> 'attente_pm' OR g.data->>'pays' IS DISTINCT FROM 'soviet' THEN
        v := jsonb_build_object('ok', false, 'raison', 'grace_introuvable');
      ELSIF jsonb_typeof(p_params->'transmettre') IS DISTINCT FROM 'boolean' THEN v := jsonb_build_object('ok', false, 'raison', 'champs_requis');
      ELSE
        v_paie := public.payer_ordre_interne(a, 'sovarka_grace_transmettre', 1, 0);
        IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN v := v_paie;
        ELSE
          PERFORM set_config('rp.sovarka_grace_pm', 'on', true);
          IF (p_params->>'transmettre')::boolean THEN
            UPDATE public.demandes_grace SET statut = 'attente',
                   data = data || jsonb_build_object('transmisePar', a, 'transmiseLe', now()) WHERE id = g.id;
            v_president := public.sovarka_titulaire_interne('president');
            IF v_president IS NOT NULL THEN
              PERFORM public.mail_systeme_poser_interne('Conseil du Peuple', v_president, 'Recommandation de grâce',
                'Le Président du Conseil du Peuple vous transmet la recommandation de grâce de ' || coalesce(g.data->>'nomCondamne', '?')
                || ', proposée par le ministre de la Justice prolétarienne. Rendez-vous au palais pour en décider.', NULL);
            END IF;
          ELSE
            UPDATE public.demandes_grace SET statut = 'refusee_pm',
                   data = data || jsonb_build_object('refuseePar', a, 'refuseeLe', now()) WHERE id = g.id;
            IF g.data->>'proposePar' IS NOT NULL THEN
              PERFORM public.mail_systeme_poser_interne('Conseil du Peuple', g.data->>'proposePar', 'Grâce non transmise',
                'Le Président du Conseil du Peuple a refusé de transmettre au Président la grâce de ' || coalesce(g.data->>'nomCondamne', '?') || '.', NULL);
            END IF;
          END IF;
          PERFORM set_config('rp.sovarka_grace_pm', '', true);
          v := jsonb_build_object('ok', true, 'action', p_action, 'grace', g.id, 'transmise', (p_params->>'transmettre')::boolean,
                 'condamne', g.data->>'nomCondamne', 'pa', v_paie->'pa', 'liquide', v_paie->'liquide', 'arg', v_paie->'arg');
        END IF;
      END IF;

    -- ---------------------------------------------------------- Manifestation : demande du chef de parti
    ELSIF p_action = 'manif_demander' THEN
      SELECT data::jsonb INTO d FROM public.organisations WHERE id = v_parti;
      IF d IS NULL OR d->>'chef' IS DISTINCT FROM a THEN v := jsonb_build_object('ok', false, 'raison', 'reserve_chef_de_parti');
      ELSIF public.sovarka_parti_au_pouvoir() IS NULL THEN v := jsonb_build_object('ok', false, 'raison', 'aucun_parti_au_pouvoir');
      ELSIF NOT (p.current_room = 'salle_partis' AND ((p.current_city = 'capitale' AND p.current_building = 'mairie-capitale')
                 OR (p.current_city IN ('ville_a', 'ville_b') AND p.current_building = 'mairie'))) THEN
        v := jsonb_build_object('ok', false, 'raison', 'salle_des_partis_requise');
      ELSIF EXISTS (SELECT 1 FROM public.sovarka_manif_demandes WHERE parti = v_parti AND ville = p.current_city
                     AND (statut = 'demande' OR (statut = 'acceptee' AND jour_limite >= v_jour))) THEN
        v := jsonb_build_object('ok', false, 'raison', 'demande_deja_en_cours');
      ELSE
        v_min := public.sovarka_titulaire_interne('min_int');
        v_ville_nom := CASE p.current_city WHEN 'capitale' THEN 'Novomirsk' WHEN 'ville_a' THEN 'Starovka' WHEN 'ville_b' THEN 'Krasnov' ELSE p.current_city END;
        IF v_min IS NULL THEN
          -- Autorité PNJ : acceptation d'office (règle de Républia).
          INSERT INTO public.sovarka_manif_demandes (parti, chef, ville, statut, decide_par, decide_ts, jour_limite)
          VALUES (v_parti, a, p.current_city, 'acceptee', 'PNJ', now(), v_jour + 1) RETURNING * INTO m;
        ELSE
          INSERT INTO public.sovarka_manif_demandes (parti, chef, ville) VALUES (v_parti, a, p.current_city) RETURNING * INTO m;
          PERFORM public.mail_systeme_poser_interne('Secrétariat de la Sécurité du Peuple', v_min, 'Demande de manifestation de soutien',
            'Le parti « ' || coalesce(d->>'nom', '?') || ' » demande à manifester son soutien au gouvernement à ' || v_ville_nom
            || '. Acceptez ou refusez la demande depuis votre bureau (« Gérer les manifestations »).', NULL);
        END IF;
        v := jsonb_build_object('ok', true, 'action', p_action, 'demande', m.id, 'statut', m.statut, 'jour_limite', m.jour_limite);
      END IF;

    -- ---------------------------------------------------------- Manifestation : le ministre accepte ou refuse
    ELSIF p_action = 'manif_decider' THEN
      SELECT * INTO m FROM public.sovarka_manif_demandes WHERE id = (p_params->>'demande')::bigint FOR UPDATE;
      IF NOT public.sovarka_est_titulaire_interne(a, 'min_int') THEN v := jsonb_build_object('ok', false, 'raison', 'poste_requis');
      ELSIF NOT (p.current_city = 'capitale' AND p.current_building = 'palais-gouvernement' AND p.current_room = 'bureau_min_int') THEN
        v := jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
      ELSIF m.id IS NULL OR m.statut <> 'demande' THEN v := jsonb_build_object('ok', false, 'raison', 'demande_introuvable');
      ELSIF jsonb_typeof(p_params->'accepter') IS DISTINCT FROM 'boolean' THEN v := jsonb_build_object('ok', false, 'raison', 'champs_requis');
      ELSE
        v_paie := public.payer_ordre_interne(a, 'sovarka_manif_decider', 1, 0);
        IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN v := v_paie;
        ELSE
          UPDATE public.sovarka_manif_demandes
             SET statut = CASE WHEN (p_params->>'accepter')::boolean THEN 'acceptee' ELSE 'refusee' END,
                 decide_par = a, decide_ts = now(),
                 jour_limite = CASE WHEN (p_params->>'accepter')::boolean THEN v_jour + 1 ELSE NULL END
           WHERE id = m.id;
          PERFORM public.mail_systeme_poser_interne('Ministère de la Sécurité du Peuple', m.chef,
            CASE WHEN (p_params->>'accepter')::boolean THEN 'Manifestation de soutien autorisée' ELSE 'Manifestation de soutien refusée' END,
            CASE WHEN (p_params->>'accepter')::boolean
                 THEN 'Votre manifestation de soutien est autorisée jusqu''à demain soir. Organisez-la depuis la salle des partis de la mairie.'
                 ELSE 'Le ministre de la Sécurité du Peuple a refusé votre manifestation de soutien.' END, NULL);
          v := jsonb_build_object('ok', true, 'action', p_action, 'demande', m.id, 'acceptee', (p_params->>'accepter')::boolean,
                 'pa', v_paie->'pa', 'liquide', v_paie->'liquide', 'arg', v_paie->'arg');
        END IF;
      END IF;

    -- ---------------------------------------------------------- Manifestation : répression (autorisée ou déjà faite)
    ELSIF p_action = 'manif_reprimer' THEN
      SELECT * INTO m FROM public.sovarka_manif_demandes WHERE id = (p_params->>'demande')::bigint FOR UPDATE;
      IF NOT public.sovarka_est_titulaire_interne(a, 'min_int') THEN v := jsonb_build_object('ok', false, 'raison', 'poste_requis');
      ELSIF NOT (p.current_city = 'capitale' AND p.current_building = 'palais-gouvernement' AND p.current_room = 'bureau_min_int') THEN
        v := jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
      ELSIF m.id IS NULL OR NOT ((m.statut = 'acceptee' AND m.jour_limite >= v_jour)
             OR (m.statut = 'faite' AND (SELECT s.jour FROM public.sovarka_manifs s WHERE s.id = m.manif_id) = v_jour)) THEN
        v := jsonb_build_object('ok', false, 'raison', 'rien_a_reprimer');
      ELSE
        v_paie := public.payer_ordre_interne(a, 'sovarka_manif_reprimer', 3, 0);
        IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN v := v_paie;
        ELSE
          v_effet := 0;
          IF m.statut = 'faite' THEN
            SELECT s.effet, s.beneficiaire INTO v_effet, v_benef FROM public.sovarka_manifs s WHERE s.id = m.manif_id;
            IF v_benef IS NOT NULL AND coalesce(v_effet, 0) > 0 THEN PERFORM public.sovarka_parti_pop_interne(v_benef, -v_effet); END IF;
          END IF;
          UPDATE public.sovarka_manif_demandes SET statut = 'reprimee', reprime_par = a, reprime_ts = now() WHERE id = m.id;
          PERFORM public.annonce_publique_interne('soviet', '🚨 Les forces de la Sécurité du Peuple dispersent la manifestation de soutien du parti « '
            || coalesce((SELECT o.data::jsonb->>'nom' FROM public.organisations o WHERE o.id = m.parti), '?') || ' ».');
          PERFORM public.mail_systeme_poser_interne('Ministère de la Sécurité du Peuple', m.chef, 'Manifestation réprimée',
            'Votre manifestation de soutien a été dispersée sur ordre du ministre de la Sécurité du Peuple'
            || CASE WHEN coalesce(v_effet, 0) > 0 THEN ' ; ses effets sont annulés.' ELSE '.' END, NULL);
          v := jsonb_build_object('ok', true, 'action', p_action, 'demande', m.id, 'pop_annulee', coalesce(v_effet, 0),
                 'pa', v_paie->'pa', 'liquide', v_paie->'liquide', 'arg', v_paie->'arg');
        END IF;
      END IF;

    ELSE
      v := jsonb_build_object('ok', false, 'raison', 'action_inconnue');
    END IF;

    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN
      RAISE EXCEPTION 'acte_refuse' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS dt = PG_EXCEPTION_DETAIL; RETURN dt::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, act, par, v);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_ministeres_commande(uuid, text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_ministeres_commande(uuid, text, jsonb) TO authenticated;
