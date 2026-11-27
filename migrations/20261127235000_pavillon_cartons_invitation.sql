-- Mission du 27/11/2026 (soir, Claude), étape 5 — Réception à Novomirsk : cartons d'invitation (décision de Fred du 27/11).
--   • Réservation inchangée : Grande Salle du Pavillon des Ambassadeurs, 1 500 PSK payés par la caisse de l'institution
--     (pavillon_acte, décision du 11/11). La réservation gratuite de Luthécia (1 PA) est inchangée.
--   • Celui qui a réservé la Grande Salle pour aujourd'hui choisit ses invités dans la liste des joueurs : chacun reçoit un
--     carton d'invitation nominatif dans son inventaire, avec un message au courrier. Le carton n'est valable que le jour
--     de la réception.
--   • Le soir de la réception, l'invité « Donne » le carton à un PNJ de l'accueil du Pavillon (Touyana Dachieva, Alina
--     Belokourova ou Arkadi Belov) : le PNJ reprend le carton SANS contrôler l'identité ni la liste ; l'accès à la Grande
--     Salle est ouvert jusqu'à minuit (heure de Paris), pour cette seule pièce. Un carton peut donc être cédé.
--   • « Demander l'accès aux salons » garde sa fenêtre d'information (aucun changement).
-- Un carton reconnu = un objet d'inventaire de type « carton_invitation » dont la date est celle du jour. Le client ne peut
-- pas fabriquer d'objet (inventaire_ajouts_interdits) : seuls le serveur (envoi) et le faussaire (« Falsifier un
-- document », étape 6) en créent.
--
-- Contrôles en lecture après application :
--   SELECT position('pavillon_cartons_v1' in pg_get_functiondef('public.acces_reserve_raison_interne(text,text,text)'::regprocedure)) > 0; -- vrai
--   SELECT has_function_privilege('authenticated', 'public.pavillon_carton_remettre(integer,jsonb,text)', 'EXECUTE');           -- vrai
BEGIN;

CREATE TABLE IF NOT EXISTS public.pavillon_cartons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  jour date NOT NULL,
  emis_par text NOT NULL,
  invite text NOT NULL,
  cree_le timestamptz NOT NULL DEFAULT now(),
  remis_le timestamptz,
  remis_par text,
  UNIQUE (jour, invite)
);
CREATE TABLE IF NOT EXISTS public.pavillon_acces_cartons (
  nom text NOT NULL,
  jour date NOT NULL,
  carton text,
  cree_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (nom, jour)
);
ALTER TABLE public.pavillon_cartons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pavillon_acces_cartons ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.pavillon_cartons, public.pavillon_acces_cartons FROM PUBLIC, anon, authenticated;

-- L'objet « carton d'invitation » (le faussaire de l'étape 6 utilise la même forme, avec la date qu'il choisit).
CREATE OR REPLACE FUNCTION public.pavillon_carton_objet_interne(p_jour date, p_invite text, p_id text)
RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('name', 'Carton d''invitation — ' || to_char(p_jour, 'DD/MM/YYYY'), 'type', 'carton_invitation',
    'icon', 'ti-mail-opened', 'encombrement', 1,
    'desc', 'Réception à la Grande Salle du Pavillon des Ambassadeurs de Novomirsk, le ' || to_char(p_jour, 'DD/MM/YYYY')
      || coalesce(', au nom de ' || p_invite, '') || '. À remettre le jour même à l''accueil du Pavillon (ordre « Donner »).',
    'carton', jsonb_build_object('id', p_id, 'jour', to_char(p_jour, 'YYYY-MM-DD'), 'nominatif', p_invite))
$$;
REVOKE ALL ON FUNCTION public.pavillon_carton_objet_interne(date, text, text) FROM PUBLIC, anon, authenticated;

-- Organisateur : sa réception du jour, les invités déjà choisis et la liste des joueurs.
CREATE OR REPLACE FUNCTION public.pavillon_cartons_etat()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE moi text := public.mon_personnage(); j date := (now() AT TIME ZONE 'Europe/Paris')::date; r public.pavillon_receptions%ROWTYPE;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO r FROM public.pavillon_receptions WHERE jour = j;
  IF NOT FOUND OR r.acteur IS DISTINCT FROM moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'reception_non_reservee'); END IF;
  RETURN jsonb_build_object('ok', true, 'jour', j,
    'invites', coalesce((SELECT jsonb_agg(c.invite ORDER BY c.invite) FROM public.pavillon_cartons c WHERE c.jour = j), '[]'::jsonb),
    'joueurs', coalesce((SELECT jsonb_agg(p.name ORDER BY p.name) FROM public.personnages p
                          WHERE p.user_id IS NOT NULL AND p.name <> moi), '[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION public.pavillon_cartons_etat() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pavillon_cartons_etat() TO authenticated;

CREATE OR REPLACE FUNCTION public.pavillon_cartons_envoyer(p_invites text[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE moi text := public.mon_personnage(); j date := (now() AT TIME ZONE 'Europe/Paris')::date; r public.pavillon_receptions%ROWTYPE;
  v_nom text; v_id uuid; v_nb integer := 0; v_ecartes jsonb := '[]'::jsonb; v_dep jsonb;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO r FROM public.pavillon_receptions WHERE jour = j FOR UPDATE;
  IF NOT FOUND OR r.acteur IS DISTINCT FROM moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'reception_non_reservee'); END IF;
  IF p_invites IS NULL OR cardinality(p_invites) = 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_invite'); END IF;
  IF cardinality(p_invites) > 40 THEN RETURN jsonb_build_object('ok', false, 'raison', 'trop_d_invites'); END IF;
  FOR v_nom IN SELECT DISTINCT btrim(x) FROM unnest(p_invites) x WHERE coalesce(btrim(x), '') <> '' LOOP
    IF v_nom = moi OR NOT EXISTS (SELECT 1 FROM public.personnages p WHERE p.name = v_nom AND p.user_id IS NOT NULL) THEN
      v_ecartes := v_ecartes || jsonb_build_object('nom', v_nom, 'raison', 'joueur_inconnu'); CONTINUE; END IF;
    INSERT INTO public.pavillon_cartons (jour, emis_par, invite) VALUES (j, moi, v_nom)
      ON CONFLICT (jour, invite) DO NOTHING RETURNING id INTO v_id;
    IF v_id IS NULL THEN v_ecartes := v_ecartes || jsonb_build_object('nom', v_nom, 'raison', 'deja_invite'); CONTINUE; END IF;
    v_dep := public.inventaire_deposer_interne(v_nom, public.pavillon_carton_objet_interne(j, v_nom, v_id::text), true);
    PERFORM public.mail_systeme_poser_interne('Pavillon des Ambassadeurs', v_nom, 'Carton d''invitation : réception du ' || to_char(j, 'DD/MM'),
      moi || ' vous invite ce soir à la réception de la Grande Salle du Pavillon des Ambassadeurs de Novomirsk. Votre carton '
      || 'nominatif est dans votre inventaire ; remettez-le aujourd''hui à l''accueil du Pavillon (ordre « Donner ») : la Grande '
      || 'Salle vous sera ouverte jusqu''à minuit.');
    v_nb := v_nb + 1; v_id := NULL;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'envoyes', v_nb, 'ecartes', v_ecartes);
END $$;
REVOKE ALL ON FUNCTION public.pavillon_cartons_envoyer(text[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pavillon_cartons_envoyer(text[]) TO authenticated;

-- L'invité (ou quiconque porte le carton) le donne à un PNJ de l'accueil : aucun contrôle d'identité ni de liste.
CREATE OR REPLACE FUNCTION public.pavillon_carton_remettre(p_index integer, p_signature jsonb, p_pnj text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE moi text := public.mon_personnage(); j date := (now() AT TIME ZONE 'Europe/Paris')::date; p record; v_pos integer; v_obj jsonb;
  v_inv jsonb; v_cid text;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room, inventory INTO p FROM public.personnages_donnees WHERE name = moi FOR UPDATE;
  IF p.country IS DISTINCT FROM 'soviet' OR p.current_city IS DISTINCT FROM 'capitale'
     OR p.current_building IS DISTINCT FROM 'pavillon-ambassadeurs-novomirsk' OR p.current_room IS DISTINCT FROM 'hall_pavillon' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_a_l_accueil'); END IF;
  IF regexp_replace(coalesce(p_pnj, ''), '\s*\(PNJ\)\s*$', '') NOT IN ('Touyana Dachieva', 'Alina Belokourova', 'Arkadi Belov') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pnj_accueil_requis'); END IF;
  v_inv := CASE WHEN jsonb_typeof(p.inventory) = 'array' THEN p.inventory ELSE '[]'::jsonb END;
  v_pos := public.inventaire_localiser(v_inv, p_index, p_signature);
  IF v_pos < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_introuvable'); END IF;
  v_obj := v_inv -> v_pos;
  IF v_obj ->> 'type' IS DISTINCT FROM 'carton_invitation' THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_carton'); END IF;
  IF (v_obj #>> '{carton,jour}') IS DISTINCT FROM to_char(j, 'YYYY-MM-DD') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'carton_pas_valable_aujourdhui', 'jour', v_obj #>> '{carton,jour}'); END IF;
  UPDATE public.personnages_donnees SET inventory = public.inventaire_retirer_position(v_inv, v_pos), updated_at = clock_timestamp()
   WHERE name = moi;
  v_cid := v_obj #>> '{carton,id}';
  INSERT INTO public.pavillon_acces_cartons (nom, jour, carton) VALUES (moi, j, v_cid) ON CONFLICT (nom, jour) DO NOTHING;
  IF v_cid ~ '^[0-9a-f-]{36}$' THEN
    UPDATE public.pavillon_cartons SET remis_le = now(), remis_par = moi WHERE id = v_cid::uuid AND remis_le IS NULL;
  END IF;
  RETURN jsonb_build_object('ok', true, 'jour', j, 'inventory', (SELECT inventory FROM public.personnages_donnees WHERE name = moi));
END $$;
REVOKE ALL ON FUNCTION public.pavillon_carton_remettre(integer, jsonb, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pavillon_carton_remettre(integer, jsonb, text) TO authenticated;

-- Accès réservé : un carton remis aujourd'hui ouvre la seule Grande Salle jusqu'à minuit (heure de Paris).
CREATE OR REPLACE FUNCTION public.acces_reserve_raison_interne(p_nom text, p_batiment text, p_piece text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_loc text; v_n integer;
BEGIN
  IF NOT public.acces_piece_reservee_interne(p_batiment, p_piece) THEN RETURN NULL; END IF;
  IF EXISTS (SELECT 1 FROM public.acces_intrusions WHERE acteur = p_nom AND batiment = p_batiment) THEN RETURN NULL; END IF;
  IF p_batiment = 'pavillon-ambassadeurs-novomirsk' THEN
    -- pavillon_cartons_v1 : carton d'invitation remis à l'accueil aujourd'hui (Fred, 27/11/2026).
    IF p_piece = 'salle_reception' AND EXISTS (SELECT 1 FROM public.pavillon_acces_cartons
         WHERE nom = p_nom AND jour = (now() AT TIME ZONE 'Europe/Paris')::date) THEN RETURN NULL; END IF;
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
END $function$;

COMMIT;
