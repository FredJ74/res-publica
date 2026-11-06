-- =====================================================================================
-- FRET ET DOUANES DU PORT INDUSTRIEL AU SERVEUR (#433, Claude, 04/11/2026)
--
-- Jusqu'ici l'écran écrivait lui-même `caisses_fret` (réservation, chargeurs, réceptionnaires,
-- fermeture, expédition), tirait le contrôle du Chef des Douanes avec Math.random() et vidait
-- les lignes saisies par un PATCH direct ; la difficulté de dissimulation était posée par
-- l'écran dans un blob (`dissimulation-fret`), écriture refusée depuis la fermeture de
-- batiments_etat. Tout passe désormais par deux portes serveur :
--   * fret_caisse_commande(action, caisse, paramètres, reçu) : reserver, chargeur_ajouter,
--     chargeur_retirer, receptionnaire_ajouter, receptionnaire_retirer, fermer, expedier ;
--   * douane_caisse_controler(caisse, reçu) : contrôle ciblé du Chef des Douanes (formule du
--     25/08 inchangée : PER du Chef + 1 par douanier actif, +3 avec une unité cynophile si la
--     caisse contient des stupéfiants ; chance clamp(50 + 5 × (PER - DIS caisse), 10, 90)).
--
-- Règles de Fred (GAME-DESIGN-DOUANES.md) :
--   * 28/10 : le port inspecte une caisse sur trois (tirée à l'expédition, une seule fois) ;
--     tout objet prohibé (arme non déclarée, stupéfiant…) est saisi, convocation du déposant ;
--   * 04/11 : contenu non déclaré = amende au Trésor, double des frais de douane (10 %) sur la
--     valeur de référence de ce qui n'est pas déclaré : 2 × 10 % × valeur. Valeur de référence
--     (04/11) : prix de base des matières (ressources_economie), prix fixe des produits de
--     commerce ; un objet sans prix connu ne compte pas. L'amende est imposée à l'expéditeur par
--     le contrat commun des sanctions (prélèvement immédiat, reste recouvré chaque nuit).
--   La déclaration devient structurée : à la fermeture, l'expéditeur coche les lots déclarés.
--
-- Fermeture : REVOKE INSERT/UPDATE sur caisses_fret et contenu_caisses_fret pour les joueurs
-- (le dépôt/retrait passe déjà par fret_objet_agir, l'arrivée et la liquidation par le cron).
-- Le banc annulé `outils/bancs/banc-fret-caisses-serveur.sql` éprouve chaque action.
-- =====================================================================================

ALTER TABLE public.caisses_fret ADD COLUMN IF NOT EXISTS dissimulation numeric;
ALTER TABLE public.caisses_fret ADD COLUMN IF NOT EXISTS inspection jsonb;
ALTER TABLE public.caisses_fret ADD COLUMN IF NOT EXISTS controle_chef jsonb;
ALTER TABLE public.contenu_caisses_fret ADD COLUMN IF NOT EXISTS declaree boolean NOT NULL DEFAULT true;

-- Valeur de référence d'un lot (règle de Fred du 04/11).
CREATE OR REPLACE FUNCTION public.fret_valeur_reference_interne(p_objet jsonb, p_quantite integer)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT greatest(0, coalesce(p_quantite, 0)) * coalesce(
    (SELECT r.prix_base FROM public.ressources_economie r WHERE r.cle = p_objet->>'stackKey'),
    (SELECT rc.prix_fixe FROM public.recettes_commerce rc
      WHERE rc.prix_fixe IS NOT NULL AND rc.stack_key = p_objet->>'stackKey' ORDER BY rc.id LIMIT 1),
    0);
$$;

-- Le port de fret d'un pays (seul celui de la Républia existe).
CREATE OR REPLACE FUNCTION public.fret_port_interne(p_pays text)
RETURNS TABLE(ville text, batiment text) LANGUAGE sql IMMUTABLE AS $$
  SELECT v, b FROM (VALUES ('republic', 'ville_a', 'port-sainte-marie')) t(p, v, b) WHERE t.p = p_pays;
$$;

-- Inspection d'une caisse ouverte par la douane (inspection aléatoire ou contrôle du Chef).
-- Saisit les objets prohibés (mêmes critères que le contrôle des personnes), convoque leurs
-- déposants, impose l'amende de fausse déclaration à l'expéditeur. Appelée sous verrou.
CREATE OR REPLACE FUNCTION public.fret_inspecter_interne(p_caisse uuid, p_origine text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE c public.caisses_fret%ROWTYPE; l record; v_pays text; v_saisis jsonb := '[]'::jsonb;
  v_valeur numeric := 0; v_amende integer := 0; v_dep text; v_noms text; v_ref text;
  v_jour integer; v_heure integer; v_sanction jsonb;
BEGIN
  SELECT * INTO c FROM public.caisses_fret WHERE id = p_caisse FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_introuvable'); END IF;
  v_pays := coalesce(CASE WHEN c.statut = 'arrivee' THEN c.pays_destination ELSE c.pays_origine END, 'republic');
  FOR l IN SELECT * FROM public.contenu_caisses_fret WHERE caisse_id = p_caisse AND quantite > 0 ORDER BY date_depot, id FOR UPDATE LOOP
    IF (coalesce((l.objet->>'legal')::boolean, true) = false
        OR public.assemblee_loi_en_vigueur(v_pays, l.objet, now()) IS NOT NULL)
       AND NOT public.inventaire_objet_protege(NULL, l.objet) THEN
      v_saisis := v_saisis || jsonb_build_array(jsonb_build_object('ligne', l.id, 'deposant', l.deposant,
        'nom', coalesce(l.objet->>'name', l.objet->>'type', '?'), 'type', l.objet->>'type', 'quantite', l.quantite));
      INSERT INTO public.confiscations_douanieres(id, personne, objet_nom, objet_type, quantite, pays, ville, building_id, room_id, reference)
      VALUES ('conf-' || gen_random_uuid()::text, l.deposant, coalesce(l.objet->>'name', '?'), l.objet->>'type', l.quantite,
        v_pays, coalesce(CASE WHEN c.statut = 'arrivee' THEN c.ville_destination ELSE c.ville_origine END, 'ville_a'),
        coalesce(CASE WHEN c.statut = 'arrivee' THEN c.building_destination ELSE c.building_origine END, 'port-sainte-marie'),
        'douanes', 'fret-' || p_caisse::text);
      UPDATE public.contenu_caisses_fret SET quantite = 0 WHERE id = l.id;
    ELSIF NOT l.declaree THEN
      v_valeur := v_valeur + public.fret_valeur_reference_interne(l.objet, l.quantite);
    END IF;
  END LOOP;

  -- Convocation et courrier par déposant d'objets saisis (même contenu que le contrôle des personnes).
  SELECT coalesce(day, 1), extract(hour FROM now() AT TIME ZONE 'Europe/Paris')::integer
    INTO v_jour, v_heure FROM public.personnages_donnees WHERE name = c.leader;
  FOR v_dep, v_noms IN SELECT s->>'deposant', string_agg(s->>'nom', ', ') FROM jsonb_array_elements(v_saisis) s GROUP BY 1 LOOP
    UPDATE public.personnages_donnees SET convocations = coalesce(convocations, '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
      'id', 'conv-' || replace(gen_random_uuid()::text, '-', ''), 'motif', 'possession_illegale_douane',
      'jourEmission', coalesce(v_jour, 1), 'heureEmission', v_heure, 'jourLimite', coalesce(v_jour, 1) + 1, 'heureLimite', v_heure,
      'traitee', false, 'limiteTs', to_char((now() + interval '24 hours') AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))
     WHERE name = v_dep;
    PERFORM public.mail_systeme_poser_interne('Chef des Douanes', v_dep, 'Convocation officielle',
      'Un contrôle douanier a détecté et confisqué du contenu prohibé dans une caisse de fret que vous avez approvisionnée ('
      || v_noms || '). Présentez-vous au commissariat sous 24h pour vous justifier, faute de quoi vous serez arrêté(e).');
  END LOOP;

  v_amende := floor(2 * 0.10 * v_valeur)::integer;
  IF v_amende > 0 THEN
    v_ref := 'fret-' || p_caisse::text;
    v_sanction := public.sanction_financiere_imposer_interne(v_ref, 'fausse_declaration_fret', v_pays, c.leader, v_amende, 'tresor');
    IF coalesce((v_sanction->>'ok')::boolean, false) IS NOT TRUE THEN
      RAISE EXCEPTION 'amende_fret_non_enregistree: %', coalesce(v_sanction->>'raison', '?');
    END IF;
    PERFORM public.mail_systeme_poser_interne('Douanes du port', c.leader, 'Amende pour fausse déclaration',
      'Une inspection de votre caisse de fret a révélé des marchandises non déclarées. Amende : ' || v_amende
      || ' FR au Trésor (double des droits de douane sur leur valeur).');
  END IF;

  RETURN jsonb_build_object('ok', true, 'origine', p_origine, 'saisis', v_saisis,
    'valeur_non_declaree', v_valeur, 'amende', v_amende);
END; $$;

CREATE OR REPLACE FUNCTION public.fret_caisse_commande_interne(p_acteur text, p_action text, p_caisse uuid, p_params jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE moi public.personnages_donnees%ROWTYPE; c public.caisses_fret%ROWTYPE; v jsonb; v_id uuid;
  v_nom text; v_dest public.personnages_donnees%ROWTYPE; v_port record; v_total integer; v_insp jsonb := NULL;
  v_valeur numeric; v_lots uuid[];
BEGIN
  IF p_acteur IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'non_authentifie'); END IF;
  SELECT * INTO moi FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  p_params := coalesce(p_params, '{}'::jsonb);

  IF p_action = 'reserver' THEN
    SELECT * INTO v_port FROM public.fret_port_interne(moi.country);
    IF v_port IS NULL OR moi.current_city IS DISTINCT FROM v_port.ville OR moi.current_building IS DISTINCT FROM v_port.batiment THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_au_port'); END IF;
    v := public.payer_ordre(p_acteur, 'expedier_colis', 2, 200);
    IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v; END IF;
    INSERT INTO public.caisses_fret(leader, pays_origine, ville_origine, building_origine, statut,
      chargeurs_autorises, receptionnaires_autorises, dedouanee)
    VALUES (p_acteur, moi.country, v_port.ville, v_port.batiment, 'ouverte', '{}', '{}', false)
    RETURNING id INTO v_id;
    RETURN jsonb_build_object('ok', true, 'caisse', v_id, 'pa', v->'pa', 'liquide', v->'liquide', 'arg', v->'arg');
  END IF;

  SELECT * INTO c FROM public.caisses_fret WHERE id = p_caisse FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_introuvable'); END IF;
  v_nom := nullif(btrim(p_params->>'nom'), '');

  IF p_action IN ('chargeur_ajouter', 'chargeur_retirer') THEN
    IF c.leader IS DISTINCT FROM p_acteur THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_responsable'); END IF;
    IF c.statut IS DISTINCT FROM 'ouverte' THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_fermee'); END IF;
    IF v_nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'nom_requis'); END IF;
    IF p_action = 'chargeur_ajouter' THEN
      IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_nom) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
      UPDATE public.caisses_fret SET chargeurs_autorises = (SELECT array_agg(DISTINCT x ORDER BY x)
        FROM unnest(coalesce(chargeurs_autorises, '{}') || v_nom) x) WHERE id = c.id;
    ELSE
      UPDATE public.caisses_fret SET chargeurs_autorises = array_remove(coalesce(chargeurs_autorises, '{}'), v_nom) WHERE id = c.id;
    END IF;
    RETURN jsonb_build_object('ok', true, 'chargeurs', (SELECT chargeurs_autorises FROM public.caisses_fret WHERE id = c.id));
  END IF;

  IF p_action IN ('receptionnaire_ajouter', 'receptionnaire_retirer') THEN
    IF c.destinataire IS DISTINCT FROM p_acteur THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_destinataire'); END IF;
    IF v_nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'nom_requis'); END IF;
    IF p_action = 'receptionnaire_ajouter' THEN
      IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_nom) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
      UPDATE public.caisses_fret SET receptionnaires_autorises = (SELECT array_agg(DISTINCT x ORDER BY x)
        FROM unnest(coalesce(receptionnaires_autorises, '{}') || v_nom) x) WHERE id = c.id;
    ELSE
      UPDATE public.caisses_fret SET receptionnaires_autorises = array_remove(coalesce(receptionnaires_autorises, '{}'), v_nom) WHERE id = c.id;
    END IF;
    RETURN jsonb_build_object('ok', true, 'receptionnaires', (SELECT receptionnaires_autorises FROM public.caisses_fret WHERE id = c.id));
  END IF;

  IF p_action = 'fermer' THEN
    IF c.leader IS DISTINCT FROM p_acteur THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_responsable'); END IF;
    IF c.statut IS DISTINCT FROM 'ouverte' THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_fermee'); END IF;
    SELECT coalesce(sum(quantite), 0) INTO v_total FROM public.contenu_caisses_fret WHERE caisse_id = c.id AND quantite > 0;
    IF v_total <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_vide'); END IF;
    SELECT * INTO v_dest FROM public.personnages_donnees WHERE name = v_nom;
    IF NOT FOUND OR v_nom = p_acteur THEN RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_invalide'); END IF;
    SELECT * INTO v_port FROM public.fret_port_interne(v_dest.country);
    IF v_port IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'port_indisponible'); END IF;
    v_valeur := round(greatest(0, coalesce(nullif(p_params->>'valeur', '')::numeric, 0)));
    -- Lots NON déclarés : identifiants des lignes de cette caisse cochées comme non déclarées.
    SELECT coalesce(array_agg(x::uuid), '{}') INTO v_lots
      FROM jsonb_array_elements_text(CASE WHEN jsonb_typeof(p_params->'non_declares') = 'array' THEN p_params->'non_declares' ELSE '[]'::jsonb END) x;
    UPDATE public.contenu_caisses_fret SET declaree = NOT (id = ANY(v_lots)) WHERE caisse_id = c.id;
    UPDATE public.caisses_fret SET statut = 'fermee', destinataire = v_dest.name, pays_destination = v_dest.country,
      ville_destination = v_port.ville, building_destination = v_port.batiment,
      declaration_douaniere = left(coalesce(btrim(p_params->>'declaration'), ''), 300), valeur_declaree = v_valeur,
      date_fermeture = now(), dissimulation = 8 + coalesce(nullif(moi.resources->>'dis', '')::numeric, 0) / 10
     WHERE id = c.id;
    RETURN jsonb_build_object('ok', true, 'destinataire', v_dest.name);
  END IF;

  IF p_action = 'expedier' THEN
    IF c.leader IS DISTINCT FROM p_acteur THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_responsable'); END IF;
    IF c.statut IS DISTINCT FROM 'fermee' OR c.destinataire IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_non_fermee'); END IF;
    SELECT coalesce(sum(quantite), 0) INTO v_total FROM public.contenu_caisses_fret WHERE caisse_id = c.id AND quantite > 0;
    IF v_total <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_vide'); END IF;
    -- Une caisse sur trois est inspectée par les douaniers du port (Fred, 28/10).
    IF c.inspection IS NULL AND random() < 1.0 / 3 THEN
      v_insp := public.fret_inspecter_interne(c.id, 'inspection_port');
    END IF;
    UPDATE public.caisses_fret SET statut = 'en_transit', date_depart = now(), date_arrivee_prevue = now() + interval '1 day',
      inspection = coalesce(v_insp, jsonb_build_object('inspectee', false))
     WHERE id = c.id;
    PERFORM public.mail_systeme_poser_interne('Administration Portuaire', c.destinataire, 'Caisse de fret en route',
      'Une caisse de fret vous a été expédiée par ' || p_acteur || '. Elle sera à retirer au port sous 1 jour.');
    -- Le résultat de l'inspection n'est pas révélé à l'expéditeur ici : il l'apprend par courrier.
    RETURN jsonb_build_object('ok', true, 'statut', 'en_transit');
  END IF;

  RETURN jsonb_build_object('ok', false, 'raison', 'action_inconnue');
END; $$;

CREATE OR REPLACE FUNCTION public.fret_caisse_commande(p_action text, p_caisse uuid, p_params jsonb, p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb; v jsonb; d text;
BEGIN
  prm := jsonb_build_object('action', p_action, 'caisse', p_caisse, 'params', coalesce(p_params, '{}'::jsonb));
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'fret_caisse_commande', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.fret_caisse_commande_interne(a, p_action, p_caisse, p_params);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'refus' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'fret_caisse_commande', prm, v);
END; $$;

-- Contrôle ciblé du Chef des Douanes (formule du 25/08, désormais tirée au serveur).
CREATE OR REPLACE FUNCTION public.douane_caisse_controler_interne(p_acteur text, p_caisse uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE c public.caisses_fret%ROWTYPE; chef public.personnages_donnees%ROWTYPE; v jsonb; v_port record;
  v_nb integer; v_cyno boolean; v_stup boolean; v_per numeric; v_chance numeric; v_jet integer; v_insp jsonb;
BEGIN
  SELECT * INTO chef FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  SELECT * INTO c FROM public.caisses_fret WHERE id = p_caisse FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_introuvable'); END IF;
  SELECT * INTO v_port FROM public.fret_port_interne(chef.country);
  IF v_port IS NULL OR NOT ((c.building_origine = v_port.batiment AND c.statut = 'fermee')
     OR (c.building_destination = v_port.batiment AND c.statut = 'arrivee')) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_non_controlable'); END IF;
  IF c.controle_chef IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_controlee'); END IF;
  v := public.payer_ordre(p_acteur, 'controler_caisse_douane', 1, 0);
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v; END IF;
  SELECT count(*), coalesce(bool_or(fp.type_unite = 'cynophile'), false) INTO v_nb, v_cyno
    FROM public.pnj_membres m LEFT JOIN public.pnj_force_publique_metier fp ON fp.pnj_id = m.id
   WHERE m.famille = 'douanier' AND m.statut = 'actif' AND m.pays = chef.country;
  SELECT EXISTS (SELECT 1 FROM public.contenu_caisses_fret WHERE caisse_id = c.id AND quantite > 0
    AND objet->>'type' = 'poison' AND coalesce((objet->>'legal')::boolean, true) = false) INTO v_stup;
  v_per := coalesce(nullif(chef.stats->>'PER', '')::numeric, 8) + v_nb + CASE WHEN v_cyno AND v_stup THEN 3 ELSE 0 END;
  v_chance := greatest(10, least(90, 50 + 5 * (v_per - coalesce(c.dissimulation, 13))));
  v_jet := floor(random() * 100)::integer + 1;
  IF v_jet > v_chance THEN
    UPDATE public.caisses_fret SET controle_chef = jsonb_build_object('resultat', 'negatif', 'le', now(), 'par', p_acteur) WHERE id = c.id;
    RETURN jsonb_build_object('ok', true, 'decouverte', false, 'pa', v->'pa');
  END IF;
  v_insp := public.fret_inspecter_interne(c.id, 'controle_chef');
  UPDATE public.caisses_fret SET controle_chef = jsonb_build_object('resultat', 'positif', 'le', now(), 'par', p_acteur) WHERE id = c.id;
  RETURN jsonb_build_object('ok', true, 'decouverte', true, 'saisis', jsonb_array_length(v_insp->'saisis'),
    'amende', v_insp->'amende', 'pa', v->'pa');
END; $$;

CREATE OR REPLACE FUNCTION public.douane_caisse_controler(p_caisse uuid, p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text; prm jsonb := jsonb_build_object('caisse', p_caisse); v jsonb; d text;
BEGIN
  a := public.exiger_poste('chef_douanes');
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'douane_caisse_controler', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.douane_caisse_controler_interne(a, p_caisse);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'refus' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'douane_caisse_controler', prm, v);
END; $$;

REVOKE ALL ON FUNCTION public.fret_valeur_reference_interne(jsonb, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fret_port_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fret_inspecter_interne(uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fret_caisse_commande_interne(text, text, uuid, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.douane_caisse_controler_interne(text, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fret_caisse_commande(text, uuid, jsonb, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.douane_caisse_controler(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fret_caisse_commande(text, uuid, jsonb, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.douane_caisse_controler(uuid, uuid) TO authenticated;

-- Fermeture des écritures directes de l'écran (une policy et son droit tombent ensemble).
REVOKE INSERT, UPDATE, DELETE ON public.caisses_fret FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.contenu_caisses_fret FROM anon, authenticated;
DROP POLICY IF EXISTS caisses_fret_ecriture_acteur ON public.caisses_fret;
DROP POLICY IF EXISTS caisses_fret_maj_acteur ON public.caisses_fret;
DROP POLICY IF EXISTS contenu_caisses_fret_ecriture_acteur ON public.contenu_caisses_fret;
DROP POLICY IF EXISTS contenu_caisses_fret_maj_acteur ON public.contenu_caisses_fret;
