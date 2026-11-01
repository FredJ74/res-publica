-- Fonctions et procedures stockees
-- ============================================================================
-- BASELINE Human Gambit -- domaine personnage et presence -- phase 20 : fonctions
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- ambassade_acces_bureau(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ambassade_acces_bureau(p_empire text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_expire timestamptz;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF public.ambassade_identite(p_empire) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ambassade_inconnue');
  END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF EXISTS (SELECT 1 FROM public.ambassades_ouvertes a
              WHERE a.pays_hote = v_pays AND a.empire = p_empire
                AND a.data ->> 'ambassadeur' = v_moi) THEN
    RETURN jsonb_build_object('ok', true, 'motif', 'ambassadeur');
  END IF;
  PERFORM public.ambassades_asiles_echoir(v_moi);
  IF public.ambassade_refuge_de(v_moi) = p_empire THEN
    RETURN jsonb_build_object('ok', true, 'motif', 'refugie');
  END IF;
  PERFORM public.ambassades_audiences_echoir(v_moi);
  SELECT expire_le INTO v_expire FROM public.ambassades_audiences
   WHERE demandeur = v_moi AND empire = p_empire AND statut = 'accordee' AND expire_le > now();
  IF v_expire IS NOT NULL THEN
    RETURN jsonb_build_object('ok', true, 'motif', 'audience', 'expire_le', v_expire);
  END IF;
  RETURN jsonb_build_object('ok', false, 'raison', 'sur_audience');
END; $function$;

-- ambassade_acces_bureaux() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ambassade_acces_bureaux()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_res jsonb := '{}'::jsonb; e text; v_expire timestamptz; v_refuge text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  PERFORM public.ambassades_audiences_echoir(v_moi);
  PERFORM public.ambassades_asiles_echoir(v_moi);
  v_refuge := public.ambassade_refuge_de(v_moi);
  FOREACH e IN ARRAY ARRAY['khalija','soviet','narco'] LOOP
    IF EXISTS (SELECT 1 FROM public.ambassades_ouvertes a
                WHERE a.pays_hote = v_pays AND a.empire = e AND a.data ->> 'ambassadeur' = v_moi) THEN
      v_res := v_res || jsonb_build_object(e, jsonb_build_object('acces', true, 'motif', 'immunite'));
      CONTINUE;
    END IF;
    IF v_refuge = e THEN
      v_res := v_res || jsonb_build_object(e, jsonb_build_object('acces', true, 'motif', 'refugie'));
      CONTINUE;
    END IF;
    SELECT expire_le INTO v_expire FROM public.ambassades_audiences
     WHERE demandeur = v_moi AND empire = e AND statut = 'accordee' AND expire_le > now();
    IF v_expire IS NOT NULL THEN
      v_res := v_res || jsonb_build_object(e, jsonb_build_object('acces', true, 'motif', 'audience', 'expire_le', v_expire));
    ELSE
      v_res := v_res || jsonb_build_object(e, jsonb_build_object('acces', false));
    END IF;
  END LOOP;
  -- Ambassadeurs joueurs en poste dans le pays (25/10/2026) : leurs PNJ deviennent secretaires.
  RETURN jsonb_build_object('ok', true, 'bureaux', v_res, 'ambassadeurs', coalesce((
    SELECT jsonb_object_agg(a.empire, a.data ->> 'ambassadeur') FROM public.ambassades_ouvertes a
     WHERE a.pays_hote = v_pays AND nullif(btrim(coalesce(a.data ->> 'ambassadeur', '')), '') IS NOT NULL), '{}'::jsonb));
END; $function$;

-- ambassade_accorder_audience(uuid) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ambassade_accorder_audience(p_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; r public.ambassades_audiences%rowtype; v_ident jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT * INTO r FROM public.ambassades_audiences WHERE id = p_id FOR UPDATE;
  IF NOT FOUND OR r.ambassadeur_pj IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'demande_introuvable');
  END IF;
  IF r.statut <> 'demandee' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_traitee');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ambassades_ouvertes a
                  WHERE a.pays_hote = r.pays_hote AND a.empire = r.empire
                    AND a.data ->> 'ambassadeur' = v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plus_ambassadeur');
  END IF;
  UPDATE public.ambassades_audiences
     SET statut = 'accordee', accordee_le = now(), expire_le = now() + interval '48 hours'
   WHERE id = r.id;
  v_ident := public.ambassade_identite(r.empire);
  PERFORM public.mail_systeme_poser_interne(
    v_ident ->> 'ambassade', r.demandeur, 'Audience accordée',
    '<strong>' || v_moi || '</strong> accepte de vous recevoir.<br><br>'
    || 'Présentez-vous à son bureau, au Quartier des Ambassades, dans les <strong>48 heures</strong>.');
  RETURN jsonb_build_object('ok', true, 'demandeur', r.demandeur);
END; $function$;

-- ambassade_ambassadeur_interne(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ambassade_ambassadeur_interne(p_empire text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_hote text; v_bat text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT a.pays_hote INTO v_hote FROM public.ambassades_ouvertes a
   WHERE a.empire = p_empire AND a.data ->> 'ambassadeur' = v_moi LIMIT 1;
  IF v_hote IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_ambassadeur'); END IF;
  SELECT current_building INTO v_bat FROM public.personnages_donnees WHERE name = v_moi;
  IF v_bat IS DISTINCT FROM 'quartier-ambassades' THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  RETURN jsonb_build_object('ok', true, 'moi', v_moi, 'hote', v_hote);
END; $function$;

-- ambassade_demander_asile(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ambassade_demander_asile(p_empire text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_batiment text; v_id uuid; v_paie jsonb; v_ident jsonb; v_statut text; v_pj text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_ident := public.ambassade_identite(p_empire);
  IF v_ident IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'ambassade_inconnue'); END IF;
  SELECT country, current_building INTO v_pays, v_batiment FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL OR v_pays = p_empire THEN RETURN jsonb_build_object('ok', false, 'raison', 'ambassade_inconnue'); END IF;
  IF v_batiment IS DISTINCT FROM 'quartier-ambassades' THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  PERFORM public.ambassades_asiles_echoir(v_moi);
  SELECT statut INTO v_statut FROM public.ambassades_asiles WHERE demandeur = v_moi AND statut IN ('demandee','accorde');
  IF v_statut = 'demandee' THEN RETURN jsonb_build_object('ok', false, 'raison', 'asile_en_cours');
  ELSIF v_statut = 'accorde' THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_refugie'); END IF;
  SELECT nullif(btrim(coalesce(a.data ->> 'ambassadeur', '')), '') INTO v_pj
    FROM public.ambassades_ouvertes a WHERE a.pays_hote = v_pays AND a.empire = p_empire;
  BEGIN
    INSERT INTO public.ambassades_asiles (demandeur, pays_hote, empire, decision_prevue_le, ambassadeur_pj)
    VALUES (v_moi, v_pays, p_empire,
            CASE WHEN v_pj IS NULL THEN now() + random() * interval '3 days' ELSE 'infinity'::timestamptz END, v_pj)
    RETURNING id INTO v_id;
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'asile_en_cours');
  END;
  v_paie := public.payer_ordre(v_moi, 'demander_asile_politique', 2, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN
    DELETE FROM public.ambassades_asiles WHERE id = v_id;
    RETURN v_paie;
  END IF;
  PERFORM public.mail_systeme_poser_interne('Quartier des Ambassades', v_moi, 'Demande d''asile transmise',
    'Votre demande d''asile politique auprès de l''<strong>' || (v_ident ->> 'ambassade')
    || '</strong> a bien été transmise.<br><br>Votre dossier sera examiné, et la réponse vous parviendra dans les plus brefs délais.<br><br>'
    || 'Le secrétariat du Quartier des Ambassades');
  IF v_pj IS NOT NULL THEN
    PERFORM public.mail_systeme_poser_interne('Quartier des Ambassades', v_pj, 'Demande d''asile politique',
      '<strong>' || v_moi || '</strong> sollicite l''asile politique auprès de votre ambassade. À vous de l''accorder ou de le refuser.<br><br>'
      || '[[act:asile_accorder|' || v_id::text || ']][[act:asile_refuser|' || v_id::text || ']]');
    RETURN jsonb_build_object('ok', true, 'statut', 'demandee', 'ambassade', v_ident ->> 'ambassade', 'pa', v_paie -> 'pa');
  END IF;
  PERFORM public.ambassades_asiles_echoir(v_moi);
  SELECT statut INTO v_statut FROM public.ambassades_asiles WHERE id = v_id;
  RETURN jsonb_build_object('ok', true, 'statut', v_statut, 'ambassade', v_ident ->> 'ambassade', 'pa', v_paie -> 'pa');
END; $function$;

-- ambassade_demander_audience(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ambassade_demander_audience(p_empire text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_batiment text; v_pj text; v_id uuid;
  v_paie jsonb; v_ident jsonb; v_statut text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  v_ident := public.ambassade_identite(p_empire);
  IF v_ident IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ambassade_inconnue');
  END IF;
  SELECT country, current_building INTO v_pays, v_batiment
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL OR v_pays = p_empire THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ambassade_inconnue');
  END IF;
  IF v_batiment IS DISTINCT FROM 'quartier-ambassades' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  PERFORM public.ambassades_audiences_echoir(v_moi);

  SELECT statut INTO v_statut FROM public.ambassades_audiences
   WHERE demandeur = v_moi AND empire = p_empire AND statut IN ('demandee','accordee');
  IF v_statut = 'demandee' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'demande_en_cours');
  ELSIF v_statut = 'accordee' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audience_deja_accordee');
  END IF;

  -- L'ambassadeur joueur en poste ici, s'il y en a un (inexistant tant que les autres empires
  -- ne sont pas codes : la branche est prete, et c'est tout).
  SELECT nullif(btrim(coalesce(a.data ->> 'ambassadeur','')), '') INTO v_pj
    FROM public.ambassades_ouvertes a
   WHERE a.pays_hote = v_pays AND a.empire = p_empire;

  -- ENREGISTRER AVANT DE PAYER : l'index unique arbitre une course entre deux onglets sans
  -- prelever le perdant. Si le paiement est refuse, la ligne est retiree.
  BEGIN
    INSERT INTO public.ambassades_audiences (demandeur, pays_hote, empire, ambassadeur_pj, accord_prevu_le)
    VALUES (v_moi, v_pays, p_empire, v_pj,
            CASE WHEN v_pj IS NULL THEN now() + random() * interval '3 days' END)
    RETURNING id INTO v_id;
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'demande_en_cours');
  END;

  v_paie := public.payer_ordre(v_moi, 'demander_audience_ambassadeur', 1, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN
    DELETE FROM public.ambassades_audiences WHERE id = v_id;
    RETURN v_paie;
  END IF;

  PERFORM public.mail_systeme_poser_interne(
    'Quartier des Ambassades', v_moi, 'Demande d''audience transmise',
    'Votre demande d''audience auprès de l''<strong>' || (v_ident ->> 'ambassade') || '</strong> a bien été transmise.<br><br>'
    || 'Vous recevrez une réponse dans les plus brefs délais.<br><br>'
    || 'Le secrétariat du Quartier des Ambassades');

  IF v_pj IS NOT NULL THEN
    PERFORM public.mail_systeme_poser_interne(
      'Quartier des Ambassades', v_pj, 'Demande d''audience',
      '<strong>' || v_moi || '</strong> sollicite une audience auprès de votre ambassade.<br><br>'
      || 'Si vous l''accordez, votre bureau lui sera ouvert pendant 48 heures.'
      || '[[act:audience_accorder|' || v_id::text || ']]');
  END IF;

  -- Un delai tire a zero ou presque : l'audience est accordee sur-le-champ.
  PERFORM public.ambassades_audiences_echoir(v_moi);
  SELECT statut INTO v_statut FROM public.ambassades_audiences WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'statut', v_statut,
                            'ambassadeur', v_ident ->> 'ambassadeur',
                            'ambassadeur_joueur', v_pj IS NOT NULL,
                            'pa', v_paie -> 'pa');
END; $function$;

-- ambassade_demettre(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ambassade_demettre(p_pays_hote text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE m jsonb; v_paie jsonb; v_id text; v_data jsonb; v_ancien text;
BEGIN
  m := public.ambassade_ministre_interne();
  IF NOT (m ->> 'ok')::boolean THEN RETURN m; END IF;
  v_id := p_pays_hote || '-' || (m ->> 'pays');
  SELECT data INTO v_data FROM public.ambassades_ouvertes WHERE id = v_id FOR UPDATE;
  v_ancien := v_data ->> 'ambassadeur';
  IF v_ancien IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_ambassadeur'); END IF;
  v_paie := public.payer_ordre(m ->> 'moi', 'gerer_ambassades', 2, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  UPDATE public.ambassades_ouvertes
     SET data = (data - 'expulsionEcheance') || jsonb_build_object('ambassadeur', NULL)
   WHERE id = v_id;
  PERFORM public.mail_systeme_poser_interne('Ministère des Affaires Étrangères', v_ancien, 'Fin de mission',
    'Le Ministre des Affaires Étrangères a mis fin à votre mission d''ambassadeur. Vous perdez ce poste avec effet immédiat.');
  RETURN jsonb_build_object('ok', true, 'ancien', v_ancien, 'pa', v_paie -> 'pa');
END; $function$;

-- ambassade_dossier_menace(text,text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ambassade_dossier_menace(p_nom text, p_pays text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.justice_recherches(p_nom) r
                  WHERE r.country IS NULL OR r.country = p_pays)
      OR EXISTS (SELECT 1 FROM public.plaintes_en_cours p
                  WHERE p.country = p_pays
                    AND left(btrim(coalesce(p.data, '')), 1) = '{'
                    AND (p.data::jsonb ->> 'cible') = p_nom
                    AND (p.data::jsonb ->> 'status') IN ('au_parquet','enquete','poursuites',
                                                         'saisie','abandon_demande','appel'));
$function$;

-- ambassade_expulser(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ambassade_expulser(p_empire text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE m jsonb; v_paie jsonb; v_id text; v_data jsonb; v_amb text; v_echeance bigint;
BEGIN
  m := public.ambassade_ministre_interne();
  IF NOT (m ->> 'ok')::boolean THEN RETURN m; END IF;
  v_id := (m ->> 'pays') || '-' || p_empire;
  SELECT data INTO v_data FROM public.ambassades_ouvertes WHERE id = v_id FOR UPDATE;
  v_amb := v_data ->> 'ambassadeur';
  IF v_amb IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_ambassadeur'); END IF;
  IF v_data ? 'expulsionEcheance' THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_expulse'); END IF;
  v_paie := public.payer_ordre(m ->> 'moi', 'gerer_ambassades', 2, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_echeance := ((extract(epoch from now()) + 24 * 3600) * 1000)::bigint;
  UPDATE public.ambassades_ouvertes SET data = data || jsonb_build_object('expulsionEcheance', v_echeance)
   WHERE id = v_id;
  PERFORM public.mail_systeme_poser_interne('Ministère des Affaires Étrangères', v_amb, 'Expulsion diplomatique',
    'Vous êtes déclaré(e) persona non grata par le Ministre des Affaires Étrangères du pays qui vous accueille. '
    || 'Vous conservez votre poste pendant 24 heures ; à l''échéance, votre mission prend fin.');
  RETURN jsonb_build_object('ok', true, 'ambassadeur', v_amb, 'echeance', v_echeance, 'pa', v_paie -> 'pa');
END; $function$;

-- ambassade_identite(text) -> jsonb | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ambassade_identite(p_empire text)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE p_empire
    WHEN 'soviet'  THEN jsonb_build_object('ambassadeur','Valery Antonov',      'ambassade','Ambassade de Sovarka')
    WHEN 'narco'   THEN jsonb_build_object('ambassadeur','Guillermo Vasquez',   'ambassade','Ambassade d''El Estado')
    WHEN 'khalija' THEN jsonb_build_object('ambassadeur','Mohamed Al-Mansoori', 'ambassade','Ambassade d''Al-Khalija')
  END;
$function$;

-- ambassade_mecenat(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ambassade_mecenat(p_empire text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE m jsonb; v_moi text; v_paie jsonb; v_indice integer; v_pop jsonb;
BEGIN
  m := public.ambassade_ambassadeur_interne(p_empire);
  IF NOT (m ->> 'ok')::boolean THEN RETURN m; END IF;
  v_moi := m ->> 'moi';
  v_paie := public.payer_ordre(v_moi, 'financer_oeuvre_culturelle', 1, 600);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_indice := public.indice_diplomatique_varier_interne(p_empire, 3, 'mecenat_culturel', v_moi);
  v_pop := public.personnage_ajuster_pop_inf(v_moi, v_moi, 8, NULL);
  PERFORM public.annonce_publique_interne(m ->> 'hote', 'SOFT POWER : ' || public.empire_nom_interne(p_empire) || ' finance une œuvre culturelle.');
  RETURN jsonb_build_object('ok', true, 'indice', v_indice, 'pop', v_pop -> 'pop', 'paie', v_paie);
END; $function$;

-- ambassade_mes_audiences() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ambassade_mes_audiences()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_liste jsonb; v_asile jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  PERFORM public.ambassades_audiences_echoir(v_moi);
  PERFORM public.ambassades_asiles_echoir(v_moi);
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'empire', a.empire, 'statut', a.statut,
           'ambassadeur', public.ambassade_identite(a.empire) ->> 'ambassadeur',
           'demandee_le', a.demandee_le, 'accordee_le', a.accordee_le, 'expire_le', a.expire_le)
         ORDER BY a.demandee_le), '[]'::jsonb)
    INTO v_liste
    FROM public.ambassades_audiences a
   WHERE a.demandeur = v_moi AND a.statut IN ('demandee','accordee');
  SELECT jsonb_build_object('empire', s.empire, 'statut', s.statut, 'demandee_le', s.demandee_le, 'decide_le', s.decide_le)
    INTO v_asile
    FROM public.ambassades_asiles s
   WHERE s.demandeur = v_moi AND s.statut IN ('demandee','accorde') LIMIT 1;
  RETURN jsonb_build_object('ok', true, 'audiences', v_liste, 'asile', v_asile,
    'en_attente', (SELECT count(*) FROM jsonb_array_elements(v_liste) e WHERE e ->> 'statut' = 'demandee')
                  + CASE WHEN v_asile ->> 'statut' = 'demandee' THEN 1 ELSE 0 END);
END; $function$;

-- ambassade_ministre_interne() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ambassade_ministre_interne()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF NOT public.mon_poste_est_dans('min_ae', v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_ministre_ae'); END IF;
  RETURN jsonb_build_object('ok', true, 'moi', v_moi, 'pays', v_pays);
END; $function$;

-- ambassade_mon_statut() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ambassade_mon_statut()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; a record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT pays_hote, empire INTO a FROM public.ambassades_ouvertes WHERE data ->> 'ambassadeur' = v_moi LIMIT 1;
  RETURN jsonb_build_object('ok', true, 'ambassadeur', a.empire IS NOT NULL, 'pays_hote', a.pays_hote, 'empire', a.empire);
END; $function$;

-- ambassade_nommer(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ambassade_nommer(p_pays_hote text, p_personne text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE m jsonb; v_pays text; v_paie jsonb; v_id text; v_data jsonb; v_p text := btrim(coalesce(p_personne, ''));
BEGIN
  m := public.ambassade_ministre_interne();
  IF NOT (m ->> 'ok')::boolean THEN RETURN m; END IF;
  v_pays := m ->> 'pays';
  v_id := p_pays_hote || '-' || v_pays;
  SELECT data INTO v_data FROM public.ambassades_ouvertes WHERE id = v_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'ambassade_fermee'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_p AND country = v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personne_introuvable'); END IF;
  IF v_data ->> 'ambassadeur' = v_p THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_en_poste'); END IF;
  v_paie := public.payer_ordre(m ->> 'moi', 'gerer_ambassades', 2, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  UPDATE public.ambassades_ouvertes
     SET data = (data - 'expulsionEcheance') || jsonb_build_object('ambassadeur', v_p, 'nommeLe', now())
   WHERE id = v_id;
  PERFORM public.mail_systeme_poser_interne('Ministère des Affaires Étrangères', v_p, 'Nomination comme ambassadeur',
    'Vous êtes nommé(e) ambassadeur(rice) de votre pays par le Ministre des Affaires Étrangères, <strong>' || (m ->> 'moi') || '</strong>.');
  RETURN jsonb_build_object('ok', true, 'ambassadeur', v_p, 'ancien', v_data ->> 'ambassadeur', 'pa', v_paie -> 'pa');
END; $function$;

-- ambassade_ouvrir(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ambassade_ouvrir(p_pays_hote text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE m jsonb; v_pays text; v_paie jsonb; v_id text; v_indice integer;
BEGIN
  m := public.ambassade_ministre_interne();
  IF NOT (m ->> 'ok')::boolean THEN RETURN m; END IF;
  v_pays := m ->> 'pays';
  IF p_pays_hote NOT IN ('republic', 'khalija', 'soviet', 'narco') OR p_pays_hote = v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pays_invalide'); END IF;
  v_id := p_pays_hote || '-' || v_pays;
  IF EXISTS (SELECT 1 FROM public.ambassades_ouvertes WHERE id = v_id) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_ouverte'); END IF;
  v_paie := public.payer_ordre(m ->> 'moi', 'gerer_ambassades', 2, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  INSERT INTO public.ambassades_ouvertes (id, pays_hote, empire, data)
  VALUES (v_id, p_pays_hote, v_pays, jsonb_build_object('empire', v_pays,
          'jour', (SELECT coalesce(day, 1) FROM public.personnages_donnees WHERE name = m ->> 'moi'),
          'ouverteLe', now()));
  v_indice := public.indice_diplomatique_varier_interne(v_pays, 8, 'ouverture_ambassade', m ->> 'moi');
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'pa', v_paie -> 'pa', 'indice', v_indice);
END; $function$;

-- ambassade_reception_organiser(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ambassade_reception_organiser(p_empire text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE m jsonb; v_moi text; v_hote text; v_id text; v_resa jsonb; v_paie jsonb;
  v_invites integer; v_did integer; v_dpop integer; v_indice integer; v_pop jsonb;
BEGIN
  m := public.ambassade_ambassadeur_interne(p_empire);
  IF NOT (m ->> 'ok')::boolean THEN RETURN m; END IF;
  v_moi := m ->> 'moi'; v_hote := m ->> 'hote';
  v_id := v_hote || '-' || public.jour_de_jeu_pays(v_hote);
  SELECT data INTO v_resa FROM public.reservations_salle_reception WHERE id = v_id FOR UPDATE;
  IF v_resa IS NULL OR v_resa ->> 'empire' IS DISTINCT FROM p_empire THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'salle_non_reservee'); END IF;
  IF v_resa ? 'receptionDonnee' THEN RETURN jsonb_build_object('ok', false, 'raison', 'reception_deja_donnee'); END IF;
  v_paie := public.payer_ordre(v_moi, 'organiser_reception_diplomatique', 2, 1200);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  SELECT count(*) INTO v_invites FROM public.personnages_donnees
   WHERE country = v_hote AND current_building = 'quartier-ambassades'
     AND current_room = 'salle_reception' AND name <> v_moi;
  IF v_invites = 0 THEN v_did := -3; v_dpop := -3;
  ELSE v_did := least(10, v_invites); v_dpop := least(5, v_invites); END IF;
  v_indice := public.indice_diplomatique_varier_interne(p_empire, v_did, 'reception_diplomatique', v_moi);
  v_pop := public.personnage_ajuster_pop_inf(v_moi, v_moi, v_dpop, NULL);
  UPDATE public.reservations_salle_reception
     SET data = data || jsonb_build_object('receptionDonnee', now(), 'invites', v_invites)
   WHERE id = v_id;
  PERFORM public.annonce_publique_interne(v_hote, CASE WHEN v_invites = 0
    THEN 'DIPLOMATIE : la réception de l''ambassade de ' || public.empire_nom_interne(p_empire) || ' s''est tenue devant une salle vide.'
    ELSE 'DIPLOMATIE : réception donnée à l''ambassade de ' || public.empire_nom_interne(p_empire) || ' (' || v_invites || ' invité' || CASE WHEN v_invites > 1 THEN 's' ELSE '' END || ').' END);
  RETURN jsonb_build_object('ok', true, 'invites', v_invites, 'delta_indice', v_did, 'delta_pop', v_dpop,
                            'indice', v_indice, 'pop', v_pop -> 'pop', 'paie', v_paie);
END; $function$;

-- ambassade_refuge_de(text) -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ambassade_refuge_de(p_nom text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT empire FROM public.ambassades_asiles
   WHERE demandeur = p_nom AND statut = 'accorde' LIMIT 1;
$function$;

-- ambassade_refugie_protege(text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ambassade_refugie_protege(p_nom text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public.ambassade_refuge_de(p_nom) IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.personnages_donnees d
                  WHERE d.name = p_nom AND d.current_building = 'quartier-ambassades');
$function$;

-- ambassade_reserver_salle(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ambassade_reserver_salle(p_empire text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE m jsonb; v_hote text; v_jour integer; v_id text; v_existant jsonb; v_paie jsonb;
BEGIN
  m := public.ambassade_ambassadeur_interne(p_empire);
  IF NOT (m ->> 'ok')::boolean THEN RETURN m; END IF;
  v_hote := m ->> 'hote';
  v_jour := public.jour_de_jeu_pays(v_hote);
  v_id := v_hote || '-' || v_jour;
  PERFORM pg_advisory_xact_lock(hashtext('salle_reception:' || v_id));
  SELECT data INTO v_existant FROM public.reservations_salle_reception WHERE id = v_id;
  IF v_existant IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'salle_deja_reservee', 'empire', v_existant ->> 'empire'); END IF;
  v_paie := public.payer_ordre(m ->> 'moi', 'reserver_salle_reception', 1, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  INSERT INTO public.reservations_salle_reception (id, pays_hote, jour, data)
  VALUES (v_id, v_hote, v_jour, jsonb_build_object('empire', p_empire, 'reservePar', m ->> 'moi'));
  RETURN jsonb_build_object('ok', true, 'jour', v_jour, 'paie', v_paie);
END; $function$;

-- ambassade_trancher_asile(uuid,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ambassade_trancher_asile(p_id uuid, p_accorder boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; r record; v_ident jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO r FROM public.ambassades_asiles WHERE id = p_id FOR UPDATE;
  IF NOT FOUND OR r.ambassadeur_pj IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'demande_introuvable'); END IF;
  IF r.statut <> 'demandee' THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_tranchee', 'statut', r.statut); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ambassades_ouvertes a
                  WHERE a.pays_hote = r.pays_hote AND a.empire = r.empire AND a.data ->> 'ambassadeur' = v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plus_en_poste'); END IF;
  UPDATE public.ambassades_asiles SET statut = CASE WHEN p_accorder THEN 'accorde' ELSE 'refuse' END, decide_le = now()
   WHERE id = p_id;
  v_ident := public.ambassade_identite(r.empire);
  IF p_accorder THEN
    PERFORM public.mail_systeme_poser_interne(v_ident ->> 'ambassade', r.demandeur, 'Asile politique accordé',
      'Son Excellence <strong>' || v_moi || '</strong> vous accorde l''asile politique.<br><br>'
      || 'Vous êtes en sécurité tant que vous restez au Quartier des Ambassades, et le bureau de l''' || (v_ident ->> 'ambassade')
      || ' vous est ouvert. <strong>Dès que vous en sortez, vous pouvez être arrêté(e).</strong>');
  ELSE
    PERFORM public.mail_systeme_poser_interne(v_ident ->> 'ambassade', r.demandeur, 'Demande d''asile refusée',
      'Son Excellence <strong>' || v_moi || '</strong> ne donne pas suite à votre demande d''asile politique.');
  END IF;
  RETURN jsonb_build_object('ok', true, 'statut', CASE WHEN p_accorder THEN 'accorde' ELSE 'refuse' END, 'demandeur', r.demandeur);
END; $function$;

-- ambassades_asiles_echoir(text) -> integer | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ambassades_asiles_echoir(p_demandeur text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v_ident jsonb; v_ok boolean; v_n integer := 0;
BEGIN
  FOR r IN SELECT * FROM public.ambassades_asiles
            WHERE statut = 'demandee' AND decision_prevue_le <= now()
              AND (p_demandeur IS NULL OR demandeur = p_demandeur)
            FOR UPDATE SKIP LOCKED
  LOOP
    v_ok := public.ambassade_dossier_menace(r.demandeur, r.pays_hote);
    UPDATE public.ambassades_asiles
       SET statut = CASE WHEN v_ok THEN 'accorde' ELSE 'refuse' END, decide_le = now()
     WHERE id = r.id;
    v_ident := public.ambassade_identite(r.empire);
    IF v_ok THEN
      PERFORM public.mail_systeme_poser_interne(
        v_ident ->> 'ambassade', r.demandeur, 'Asile politique accordé',
        'Après examen de votre dossier, Son Excellence <strong>' || (v_ident ->> 'ambassadeur')
        || '</strong> vous accorde l''asile politique.<br><br>'
        || 'Vous êtes en sécurité tant que vous restez au Quartier des Ambassades, et le bureau de l'''
        || (v_ident ->> 'ambassade') || ' vous est ouvert. <strong>Dès que vous en sortez, vous pouvez être arrêté(e).</strong><br><br>'
        || 'Le secrétariat de l''' || (v_ident ->> 'ambassade'));
    ELSE
      PERFORM public.mail_systeme_poser_interne(
        v_ident ->> 'ambassade', r.demandeur, 'Demande d''asile refusée',
        'Après examen de votre dossier, l''<strong>' || (v_ident ->> 'ambassade')
        || '</strong> ne peut donner suite à votre demande : rien n''y établit que vous soyez menacé(e).<br><br>'
        || 'Le secrétariat de l''' || (v_ident ->> 'ambassade'));
    END IF;
    v_n := v_n + 1;
  END LOOP;
  RETURN v_n;
END; $function$;

-- ambassades_audiences_echoir(text) -> integer | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ambassades_audiences_echoir(p_demandeur text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v_id jsonb; v_n integer := 0;
BEGIN
  UPDATE public.ambassades_audiences SET statut = 'expiree'
   WHERE statut = 'accordee' AND expire_le <= now()
     AND (p_demandeur IS NULL OR demandeur = p_demandeur);

  FOR r IN SELECT * FROM public.ambassades_audiences
            WHERE statut = 'demandee' AND ambassadeur_pj IS NULL
              AND accord_prevu_le <= now()
              AND (p_demandeur IS NULL OR demandeur = p_demandeur)
            FOR UPDATE SKIP LOCKED
  LOOP
    UPDATE public.ambassades_audiences
       SET statut = 'accordee', accordee_le = now(), expire_le = now() + interval '48 hours'
     WHERE id = r.id;
    v_id := public.ambassade_identite(r.empire);
    PERFORM public.mail_systeme_poser_interne(
      v_id ->> 'ambassade', r.demandeur, 'Audience accordée',
      'Son Excellence <strong>' || (v_id ->> 'ambassadeur') || '</strong> accepte de vous recevoir.<br><br>'
      || 'Présentez-vous à son bureau, au Quartier des Ambassades de Luthécia, dans les <strong>48 heures</strong>. '
      || 'Passé ce délai, l''audience sera caduque et il vous faudra en solliciter une nouvelle.<br><br>'
      || 'Le secrétariat de l''' || (v_id ->> 'ambassade'));
    v_n := v_n + 1;
  END LOOP;
  RETURN v_n;
END; $function$;

-- ambassades_audiences_echoir_toutes() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ambassades_audiences_echoir_toutes()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur');
  END IF;
  RETURN jsonb_build_object('ok', true,
    'accordees', public.ambassades_audiences_echoir(NULL),
    'asiles', public.ambassades_asiles_echoir(NULL));
END; $function$;

-- contact_organisation_choisir(text,text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.contact_organisation_choisir(p_joueur text, p_type_organisation text, p_exclues jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_r jsonb;
BEGIN
  -- `organisations.data` est un blob JSON ecrit par le client : on le lit, on n'y
  -- ecrit rien, et on ne suppose la presence d'aucune cle.
  --
  -- Une organisation SANS CHEF est ecartee ici et non par l'appelant : il n'y a
  -- personne a qui ecrire, donc ce n'est pas un choix valide.
  --
  -- A nombre de membres egal, l'identifiant tranche. Pas un critere de jeu : la
  -- seule facon de rendre le resultat reproductible.
  SELECT jsonb_build_object(
           'id',      o.id,
           'nom',     coalesce(d->>'nom', 'une organisation'),
           'chef',    d->>'chef',
           'membres', jsonb_array_length(coalesce(d->'membres', '[]'::jsonb)))
    INTO v_r
    FROM public.organisations o
    CROSS JOIN LATERAL (SELECT public.jsonb_ou_null(o.data) AS d) j
   WHERE d IS NOT NULL
     AND d->>'type' = p_type_organisation
     AND coalesce(d->>'chef', '') <> ''
     AND NOT (coalesce(p_exclues, '[]'::jsonb) ? o.id)
   ORDER BY jsonb_array_length(coalesce(d->'membres', '[]'::jsonb)) DESC, o.id ASC
   LIMIT 1;
  RETURN v_r;
END;
$function$;

-- contact_organisation_demander(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.contact_organisation_demander(p_passeur text, p_type_organisation text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi     text;
  v_passeur record;
  v_e       record;
  v_orga    jsonb;
  v_nom     text;
  v_corps   text;
  v_id      text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO v_passeur FROM public.contacts_organisations_passeurs p
   WHERE p.passeur = p_passeur AND p.type_organisation = p_type_organisation;
  IF v_passeur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'passeur_inconnu'); END IF;

  -- Verrou sur la ligne d'etat : deux clics simultanes ne doivent pas solliciter
  -- deux organisations d'un coup, ni deux fois la meme.
  SELECT * INTO v_e FROM public.contacts_organisations c
   WHERE c.joueur = v_moi AND c.passeur = p_passeur
     AND c.type_organisation = p_type_organisation
     FOR UPDATE;

  IF v_e IS NOT NULL AND now() < v_e.derniere_demande + interval '3 days' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_non_ecoule',
             'jours_restants', greatest(1, ceil(extract(epoch from
               (v_e.derniere_demande + interval '3 days') - now()) / 86400.0)::integer)); END IF;

  v_orga := public.contact_organisation_choisir(
              v_moi, p_type_organisation,
              coalesce(v_e.organisations_contactees, '[]'::jsonb));

  IF v_orga IS NULL THEN
    -- Le delai de trois jours N'EST PAS consomme : aucun message n'est parti.
    RETURN jsonb_build_object('ok', false, 'raison',
             CASE WHEN v_e IS NULL OR jsonb_array_length(v_e.organisations_contactees) = 0
                  THEN 'aucune_organisation' ELSE 'toutes_contactees' END); END IF;

  -- Le bouton ne voyage pas dans le HTML : marqueur textuel inerte, meme format
  -- que marqueurActionMail() cote navigateur.
  v_nom   := regexp_replace(v_moi, '[|\[\]]', '', 'g');
  v_corps := 'J''ai rencontré quelqu''un qui cherche un service. Contacte '
          || v_nom || ' de ma part.' || chr(10) || chr(10)
          || '[[act:ecrire_a|' || v_nom || ']]';

  v_id := 'co-' || (extract(epoch from clock_timestamp()) * 1000)::bigint
               || '-' || substr(md5(random()::text), 1, 6);
  PERFORM public.mail_systeme_poser_interne(
          v_passeur.expediteur, (v_orga->>'chef'), 'Quelqu''un à contacter', v_corps,
          to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'));

  INSERT INTO public.contacts_organisations
         (joueur, passeur, type_organisation, derniere_demande, organisations_contactees)
  VALUES (v_moi, p_passeur, p_type_organisation, now(), jsonb_build_array(v_orga->>'id'))
  ON CONFLICT (joueur, passeur, type_organisation) DO UPDATE
     SET derniere_demande = now(),
         organisations_contactees =
           public.contacts_organisations.organisations_contactees || jsonb_build_array(v_orga->>'id');

  -- Ne nomme PAS l'organisation : le passeur ne transmet aucun detail, dans les
  -- deux sens.
  RETURN jsonb_build_object('ok', true, 'rang',
           coalesce(jsonb_array_length(v_e.organisations_contactees), 0) + 1);
END;
$function$;

-- contact_organisation_etat(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.contact_organisation_etat(p_passeur text, p_type_organisation text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_e record; v_restant integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  IF NOT EXISTS (SELECT 1 FROM public.contacts_organisations_passeurs p
                  WHERE p.passeur = p_passeur AND p.type_organisation = p_type_organisation) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'passeur_inconnu'); END IF;

  SELECT * INTO v_e FROM public.contacts_organisations c
   WHERE c.joueur = v_moi AND c.passeur = p_passeur
     AND c.type_organisation = p_type_organisation;

  IF v_e IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'peut_demander', true,
                              'jours_restants', 0, 'deja_contactees', 0); END IF;

  v_restant := greatest(0, ceil(extract(epoch from
                 (v_e.derniere_demande + interval '3 days') - now()) / 86400.0)::integer);

  RETURN jsonb_build_object(
    'ok', true,
    'peut_demander', (now() >= v_e.derniere_demande + interval '3 days'),
    'jours_restants', v_restant,
    'deja_contactees', jsonb_array_length(v_e.organisations_contactees));
END;
$function$;

-- cotisation_renouveler(text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.cotisation_renouveler(p_orga_id text, p_membre text, p_saison integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_data jsonb; v_membres jsonb; v_i integer; v_trouve integer := -1;
  v_type text; v_pays text; v_ville text; v_nom_orga text;
  v_arg numeric; v_existe boolean; v_club text; v_bc jsonb; v_hist jsonb;
  v_montant numeric := 50;
BEGIN
  SELECT o.data::jsonb INTO v_data FROM public.organisations o
   WHERE o.id = p_orga_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok',false,'action','organisation_introuvable'); END IF;
  v_membres := CASE WHEN jsonb_typeof(v_data->'membres')='array' THEN v_data->'membres' ELSE '[]'::jsonb END;
  FOR v_i IN 0 .. greatest(0, jsonb_array_length(v_membres) - 1) LOOP
    IF (v_membres -> v_i ->> 'nom') = p_membre THEN v_trouve := v_i; EXIT; END IF;
  END LOOP;
  IF v_trouve < 0 THEN RETURN jsonb_build_object('ok',false,'action','membre_introuvable'); END IF;
  v_type := v_data ->> 'type'; v_pays := v_data ->> 'country'; v_ville := v_data ->> 'city';
  v_nom_orga := coalesce(v_data ->> 'nom', p_orga_id);

  SELECT true, coalesce(arg,0) INTO v_existe, v_arg FROM public.personnages
   WHERE name = p_membre FOR UPDATE;

  IF NOT coalesce(v_existe,false) OR v_arg < v_montant THEN
    -- RESILIATION : le membre quitte la liste, aucune dette n'est creee. Le courrier passe par
    -- l'unique ecrivain de public.mails ; il notifie, il ne decide pas.
    v_data := jsonb_set(v_data, '{membres}', v_membres - v_trouve);
    UPDATE public.organisations SET data = v_data::text WHERE id = p_orga_id;
    PERFORM public.mail_systeme_poser_interne(v_nom_orga, p_membre,
      'Fin d''adhésion — cotisation non renouvelée',
      'Votre adhésion à "' || v_nom_orga || '" a pris fin automatiquement : la cotisation de '
      || v_montant::text || ' FR n''a pas pu être prélevée. Aucune dette n''est créée.',
      to_char(now() AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'));
    RETURN jsonb_build_object('ok',true,'action','resiliation','membre',p_membre);
  END IF;

  UPDATE public.personnages_donnees SET arg = v_arg - v_montant WHERE name = p_membre;

  IF v_type = 'supporters' THEN
    IF p_saison IS NULL THEN
      RAISE EXCEPTION 'cotisation_renouveler : une organisation de supporters exige la saison';
    END IF;
    v_membres := jsonb_set(v_membres, ARRAY[v_trouve::text,'derniereCotisationSaison'], to_jsonb(p_saison));
    SELECT c.id INTO v_club FROM public.clubs_football c
     WHERE c.pays = v_pays AND c.ville = v_ville;
    IF v_club IS NOT NULL THEN
      SELECT b.data INTO v_bc FROM public.budgets_clubs b WHERE b.id = v_club FOR UPDATE;
      IF v_bc IS NULL THEN
        v_bc := jsonb_build_object('clubId', v_club, 'caisse', 0, 'historique', '[]'::jsonb,
                 'derniereSubventionJour', NULL,
                 'salaires', jsonb_build_object('titulaire',100,'remplacant',50,'primeVictoire',150));
      END IF;
      v_hist := CASE WHEN jsonb_typeof(v_bc->'historique')='array' THEN v_bc->'historique' ELSE '[]'::jsonb END;
      v_hist := v_hist || jsonb_build_array(jsonb_build_object('jour', NULL, 'montant', v_montant,
                  'motif', 'Cotisation supporter (renouvellement)'));
      IF jsonb_array_length(v_hist) > 50 THEN
        v_hist := (SELECT jsonb_agg(e) FROM (
          SELECT e FROM jsonb_array_elements(v_hist) WITH ORDINALITY t(e, n)
           ORDER BY n OFFSET jsonb_array_length(v_hist) - 50) z);
      END IF;
      v_bc := v_bc || jsonb_build_object(
                'caisse', greatest(0, coalesce(nullif(v_bc->>'caisse','')::numeric,0) + v_montant),
                'historique', v_hist);
      INSERT INTO public.budgets_clubs (id, data, updated_at) VALUES (v_club, v_bc, now())
      ON CONFLICT (id) DO UPDATE SET data = excluded.data, updated_at = now();
    END IF;
  ELSE
    v_membres := jsonb_set(v_membres, ARRAY[v_trouve::text,'derniereCotisationDate'],
                   to_jsonb(to_char(now() AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
    -- Correctif anterieur conserve : la cotisation d'un syndicat alimente SA caisse, sinon les
    -- 50 FR quittaient le personnage sans arriver nulle part.
    v_data := jsonb_set(v_data, '{caisse}',
                to_jsonb(coalesce(nullif(v_data->>'caisse','')::numeric,0) + v_montant), true);
  END IF;

  v_data := jsonb_set(v_data, '{membres}', v_membres);
  UPDATE public.organisations SET data = v_data::text WHERE id = p_orga_id;
  RETURN jsonb_build_object('ok',true,'action','renouvellement','membre',p_membre,
                            'montant',v_montant,'club',v_club);
END; $function$;

-- cron_journal_ecrire(text,date,text,text,jsonb,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.cron_journal_ecrire(p_tache text, p_jour date, p_statut text, p_erreur text DEFAULT NULL::text, p_contexte jsonb DEFAULT NULL::jsonb, p_duree_ms integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id  text;
  v_row public.cron_journal%ROWTYPE;
BEGIN
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur');
  END IF;
  IF p_tache IS NULL OR btrim(p_tache) = '' OR p_jour IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_incomplets');
  END IF;
  IF p_statut NOT IN ('demarree','ok','echec','ignoree') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'statut_invalide');
  END IF;

  v_id := p_tache || ':' || p_jour::text;

  INSERT INTO public.cron_journal (id, tache, jour, statut, debut, fin, duree_ms, erreur, contexte)
  VALUES (
    v_id, p_tache, p_jour, p_statut, now(),
    CASE WHEN p_statut = 'demarree' THEN NULL ELSE now() END,
    p_duree_ms, left(p_erreur, 2000), p_contexte
  )
  ON CONFLICT (id) DO UPDATE SET
    statut     = EXCLUDED.statut,
    -- Le premier debut est conserve : un reessai doit rester lisible comme un
    -- reessai, pas se maquiller en premiere execution.
    fin        = CASE WHEN EXCLUDED.statut = 'demarree' THEN NULL ELSE now() END,
    duree_ms   = coalesce(EXCLUDED.duree_ms, public.cron_journal.duree_ms),
    erreur     = EXCLUDED.erreur,
    contexte   = coalesce(EXCLUDED.contexte, public.cron_journal.contexte),
    tentatives = public.cron_journal.tentatives
                 + CASE WHEN EXCLUDED.statut = 'demarree' THEN 1 ELSE 0 END
  RETURNING * INTO v_row;

  RETURN jsonb_build_object(
    'ok', true, 'id', v_row.id, 'statut', v_row.statut, 'tentatives', v_row.tentatives
  );
END;
$function$;

-- diplomatie_repondre(text,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.diplomatie_repondre(p_id text, p_accepte boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; r record; v_type text; v_gain integer; v_paie jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF NOT public.mon_poste_est_dans('min_ae', v_pays) THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_ministre_ae'); END IF;
  SELECT * INTO r FROM public.propositions_diplomatiques WHERE id = p_id FOR UPDATE;
  IF NOT FOUND OR r.data ->> 'empireCible' IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'proposition_introuvable'); END IF;
  IF r.statut <> 'en_attente' THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_repondue'); END IF;
  v_type := r.data ->> 'type';
  v_gain := CASE v_type WHEN 'traite' THEN 12 WHEN 'negociation' THEN 8 ELSE 0 END;
  v_paie := public.payer_ordre(v_moi, 'diplomatie_bilaterale', 1, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  UPDATE public.propositions_diplomatiques
     SET statut = CASE WHEN p_accepte THEN 'acceptee' ELSE 'refusee' END,
         data = data || jsonb_build_object('statut', CASE WHEN p_accepte THEN 'acceptee' ELSE 'refusee' END,
                                           'reponduPar', v_moi, 'reponduLe', now())
   WHERE id = p_id;
  IF p_accepte THEN
    PERFORM public.indice_diplomatique_varier_interne(r.data ->> 'empireProposeur', v_gain, 'accord_' || coalesce(v_type, '?'), v_moi);
    PERFORM public.indice_diplomatique_varier_interne(v_pays, v_gain, 'accord_' || coalesce(v_type, '?'), v_moi);
    PERFORM public.annonce_publique_interne('global', CASE WHEN v_type = 'traite' THEN 'TRAITÉ' ELSE 'NÉGOCIATIONS DIPLOMATIQUES' END
      || ' : accord conclu entre ' || public.empire_nom_interne(r.data ->> 'empireProposeur') || ' et ' || public.empire_nom_interne(v_pays) || '.');
  ELSE
    PERFORM public.indice_diplomatique_varier_interne(v_pays, -v_gain, 'refus_' || coalesce(v_type, '?'), v_moi);
  END IF;
  RETURN jsonb_build_object('ok', true, 'statut', CASE WHEN p_accepte THEN 'acceptee' ELSE 'refusee' END,
                            'variation', CASE WHEN p_accepte THEN v_gain ELSE -v_gain END, 'paie', v_paie,
                            'proposition', r.data);
END; $function$;

-- diplomatie_traites_lire(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.diplomatie_traites_lire(p_empire text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  RETURN jsonb_build_object('ok', true, 'traites', coalesce((
    SELECT jsonb_agg(jsonb_build_object('type', p.data ->> 'details', 'le', coalesce(p.data ->> 'reponduLe', p.created_at::text))
                     ORDER BY p.created_at)
      FROM public.propositions_diplomatiques p
     WHERE p.statut = 'acceptee' AND p.data ->> 'type' = 'traite'
       AND ((p.data ->> 'empireProposeur' = v_pays AND p.data ->> 'empireCible' = p_empire)
         OR (p.data ->> 'empireProposeur' = p_empire AND p.data ->> 'empireCible' = v_pays))), '[]'::jsonb));
END; $function$;

-- don_argent_deposer(text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.don_argent_deposer(p_requete text, p_destinataire text, p_montant integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_moi text; v_deja record; v_id bigint;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF COALESCE(btrim(p_requete), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide');
  END IF;
  IF p_montant IS NULL OR p_montant <= 0 OR p_montant > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide');
  END IF;
  IF COALESCE(btrim(p_destinataire), '') = '' OR p_destinataire = v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_invalide');
  END IF;

  -- Rejeu : meme requete = meme resultat, aucun second debit.
  SELECT * INTO v_deja FROM public.dons_requetes WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'montant', v_deja.montant,
                              'destinataire', v_deja.destinataire);
  END IF;

  PERFORM 1 FROM public.personnages_donnees WHERE name = p_destinataire FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable');
  END IF;

  -- CONTREPARTIE REELLE : sans debit effectif, aucun depot. Fail-closed.
  IF NOT public.helvetia_debiter_fonds_ordinaires(v_moi, p_montant) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants');
  END IF;

  INSERT INTO public.dons_en_attente (destinataire, montant, expediteur, traite)
  VALUES (p_destinataire, p_montant, v_moi, false)
  RETURNING id INTO v_id;

  INSERT INTO public.dons_requetes (requete, expediteur, destinataire, montant, don_id)
  VALUES (p_requete, v_moi, p_destinataire, p_montant, v_id);

  RETURN jsonb_build_object('ok', true, 'don_id', v_id, 'montant', p_montant,
    'expediteur', v_moi, 'destinataire', p_destinataire,
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = v_moi),
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = v_moi));
END;
$function$;

-- empire_nom_interne(text) -> text | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.empire_nom_interne(p text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT CASE p WHEN 'republic' THEN 'Républia' WHEN 'narco' THEN 'El Estado'
                WHEN 'soviet' THEN 'Sovarka' WHEN 'khalija' THEN 'Al-Khalija' ELSE p END;
$function$;

-- employe_liberer(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.employe_liberer(p_pnj_id text, p_motif text DEFAULT 'licenciement'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_m record; v_job text;
BEGIN
  v_moi := CASE WHEN public.est_appel_serveur() THEN NULL ELSE public.mon_personnage() END;
  IF NOT public.est_appel_serveur() AND v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO v_m FROM public.pnj_membres WHERE id = p_pnj_id FOR UPDATE;
  IF v_m.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'employe_introuvable'); END IF;
  IF v_m.famille IS DISTINCT FROM 'employe' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_employe', 'famille', v_m.famille); END IF;
  IF v_moi IS NOT NULL AND v_m.proprietaire_pj IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_votre_employe'); END IF;

  SELECT e.job INTO v_job FROM public.pnj_employes_metier e WHERE e.pnj_id = p_pnj_id;

  IF v_m.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', true, 'deja_parti', true,
      'pnj_id', p_pnj_id, 'metier', v_job); END IF;

  UPDATE public.pnj_membres
     SET statut = 'disparu', leader_pj = NULL, leader_pnj_id = NULL,
         ville = NULL, building_id = NULL, room_id = NULL, rue_noeud_id = NULL, maj_le = now()
   WHERE id = p_pnj_id;
  RETURN jsonb_build_object('ok', true, 'pnj_id', p_pnj_id, 'metier', v_job, 'motif', p_motif);
END; $function$;

-- employe_mes_employes() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.employe_mes_employes()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  RETURN jsonb_build_object('ok', true, 'employes', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
             'pnj_id', m.id, 'nom', m.nom, 'metier', e.job, 'role', e.role_libelle,
             'genre', e.genre, 'cout_jour', e.cout_jour, 'pa', m.pa, 'liquide', m.liquide,
             'porte', (m.leader_pj = v_moi),
             'caracteristiques', public.pnj_caracteristiques_base(m.id))
           ORDER BY e.job, m.nom)
      FROM public.pnj_membres m JOIN public.pnj_employes_metier e ON e.pnj_id = m.id
     WHERE m.proprietaire_pj = v_moi AND m.statut = 'actif'), '[]'::jsonb));
END; $function$;

-- employe_metiers_recrutables() -> text[] | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.employe_metiers_recrutables()
 RETURNS text[]
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select coalesce(array_agg(metier order by metier), array[]::text[])
    from public.pnj_metiers_profils
   where recrutable;
$function$;

-- employe_pnj_id(text,text,text) -> text | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.employe_pnj_id(p_proprietaire text, p_metier text, p_nom text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT 'emp-' || p_metier || '-' || substr(md5(lower(btrim(p_proprietaire)) || '|' ||
                                                 lower(btrim(p_nom))), 1, 12);
$function$;

-- employe_recruter(text,text,text,text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.employe_recruter(p_metier text, p_nom text, p_genre text DEFAULT NULL::text, p_fn text DEFAULT NULL::text, p_pa integer DEFAULT NULL::integer, p_cost integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_max_employes constant integer := 10;
  v_moi text; v_prof record; v_id text; v_nom text; v_pay jsonb;
  v_pa integer; v_cost integer; v_deja integer; v_quota integer; v_nb integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT (p_metier = ANY (public.employe_metiers_recrutables())) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'metier_non_recrutable',
      'metier', COALESCE(p_metier, '<NULL>'),
      'recrutables', public.employe_metiers_recrutables()); END IF;
  v_nom := btrim(COALESCE(p_nom, ''));
  IF v_nom = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'nom_absent'); END IF;
  SELECT * INTO v_prof FROM public.pnj_metiers_profils WHERE metier = p_metier;
  IF v_prof IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'profil_metier_absent'); END IF;
  SELECT count(*) INTO v_deja
    FROM public.pnj_membres m WHERE m.famille = 'employe'
     AND m.proprietaire_pj = v_moi AND m.statut = 'actif';
  IF v_deja >= c_max_employes THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plafond_employes',
      'plafond', c_max_employes); END IF;
  IF p_metier = 'escort' THEN
    IF EXISTS (SELECT 1 FROM public.pnj_membres m
                 JOIN public.pnj_employes_metier e ON e.pnj_id = m.id
                WHERE m.proprietaire_pj = v_moi AND m.statut = 'actif'
                  AND e.job = 'escort' AND e.genre IS NOT DISTINCT FROM p_genre) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'quota_metier_atteint',
        'metier', p_metier, 'genre', p_genre); END IF;
  ELSE
    v_quota := COALESCE(v_prof.quota_par_joueur, 1);
    SELECT count(*) INTO v_nb FROM public.pnj_membres m
      JOIN public.pnj_employes_metier e ON e.pnj_id = m.id
     WHERE m.proprietaire_pj = v_moi AND m.statut = 'actif' AND e.job = p_metier;
    IF v_nb >= v_quota THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'quota_metier_atteint',
        'metier', p_metier, 'quota', v_quota, 'employes', v_nb); END IF;
  END IF;
  v_id := public.employe_pnj_id(v_moi, p_metier, v_nom);
  IF EXISTS (SELECT 1 FROM public.pnj_membres WHERE id = v_id AND statut = 'actif') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_employe', 'pnj_id', v_id); END IF;
  v_pa   := COALESCE(p_pa,   v_prof.pa_initial,   0);
  v_cost := COALESCE(p_cost, v_prof.cout_initial, 0);
  IF p_fn IS NOT NULL THEN
    v_pay := public.payer_ordre(v_moi, p_fn, v_pa, v_cost);
  ELSIF v_cost > 0 THEN
    v_pay := public.debiter_fonds_ordinaires(v_moi, v_cost);
  ELSE
    v_pay := jsonb_build_object('ok', true, 'montant', 0);
  END IF;
  IF COALESCE((v_pay->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'paiement_refuse', 'paiement', v_pay); END IF;
  INSERT INTO public.pnj_membres (id, famille, classe, nom, pays, proprietaire_pj,
      leader_pj, pa, statut, car_int, car_cha, car_vol, car_per, car_dup, car_ent)
  VALUES (v_id, 'employe', COALESCE(v_prof.classe, 'beta'), v_nom,
      (SELECT COALESCE(country, 'republic') FROM public.personnages_donnees WHERE name = v_moi),
      v_moi, v_moi, 12, 'actif',
      v_prof.car_int, v_prof.car_cha, v_prof.car_vol,
      v_prof.car_per, v_prof.car_dup, v_prof.car_ent)
  ON CONFLICT (id) DO UPDATE SET
      statut = 'actif', classe = EXCLUDED.classe,
      proprietaire_pj = EXCLUDED.proprietaire_pj,
      leader_pj = EXCLUDED.leader_pj, ville = NULL, building_id = NULL, room_id = NULL,
      car_int = EXCLUDED.car_int, car_cha = EXCLUDED.car_cha, car_vol = EXCLUDED.car_vol,
      car_per = EXCLUDED.car_per, car_dup = EXCLUDED.car_dup, car_ent = EXCLUDED.car_ent,
      maj_le = now();
  INSERT INTO public.pnj_employes_metier (pnj_id, job, role_libelle, cout_jour, genre, depuis_jour)
  VALUES (v_id, p_metier,
          COALESCE(v_prof.role_libelle,
                   CASE p_metier WHEN 'escort' THEN 'Escort — Agence Roxane Velours'
                                 WHEN 'informateur' THEN 'Informateur'
                                 ELSE initcap(p_metier) END),
          COALESCE(v_prof.cout_jour, 0), p_genre, NULL)
  ON CONFLICT (pnj_id) DO UPDATE SET
      job = EXCLUDED.job, role_libelle = EXCLUDED.role_libelle,
      cout_jour = EXCLUDED.cout_jour, genre = EXCLUDED.genre;
  RETURN jsonb_build_object('ok', true, 'pnj_id', v_id, 'metier', p_metier, 'nom', v_nom,
    'genre', p_genre, 'cout_jour', COALESCE(v_prof.cout_jour, 0),
    'cout_initial', v_cost, 'pa', v_pa,
    'caracteristiques', public.pnj_metier_profil(p_metier),
    'paiement', v_pay, 'employes', v_deja + 1, 'plafond', c_max_employes);
END; $function$;

-- employeur_candidats(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.employeur_candidats(p_employeur_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  c_max_employes constant integer := 10;
  v_moi text; v_pays text;
  v_emp public.pnj_employeurs%rowtype;
  v_deja integer;
begin
  v_moi := public.mon_personnage();
  if v_moi is null then
    return jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); end if;
  select coalesce(country, 'republic') into v_pays
    from public.personnages_donnees where name = v_moi;
  select * into v_emp from public.pnj_employeurs
   where employeur_id = p_employeur_id and pays = v_pays and actif;
  if v_emp.employeur_id is null then
    return jsonb_build_object('ok', false, 'raison', 'employeur_inconnu'); end if;
  select count(*) into v_deja from public.pnj_membres m
   where m.famille = 'employe' and m.proprietaire_pj = v_moi and m.statut = 'actif';
  return jsonb_build_object(
    'ok', true,
    'employeur_id', v_emp.employeur_id,
    'employeur', v_emp.nom,
    'pays', v_pays,
    'plafond_employes', c_max_employes,
    'employes_actuels', v_deja,
    'metiers', coalesce((
      select jsonb_agg(jsonb_build_object(
               'metier',           pr.metier,
               'libelle',          pr.role_libelle,
               'recrutable',       pr.recrutable,
               'cout_embauche',    coalesce(pr.cout_initial, 0),
               'cout_jour',        coalesce(pr.cout_jour, 0),
               'pa',               coalesce(pr.pa_initial, 0),
               'quota',            coalesce(pr.quota_par_joueur, 1),
               'employes',         (select count(*) from public.pnj_membres m
                                      join public.pnj_employes_metier e on e.pnj_id = m.id
                                     where m.proprietaire_pj = v_moi and m.statut = 'actif'
                                       and e.job = pr.metier),
               'caracteristiques', public.pnj_metier_profil(pr.metier))
             order by pr.metier)
        from public.pnj_metiers_profils pr
       where pr.metier in (select c.metier from public.pnj_candidats_catalogue c
                            where c.employeur_id = v_emp.employeur_id and c.actif)
    ), '[]'::jsonb),
    'candidats', coalesce((
      select jsonb_agg(jsonb_build_object(
               'candidat_id',  c.candidat_id,
               'metier',       c.metier,
               'nom',          c.nom,
               'genre',        c.genre,
               'accroche',     c.accroche,
               'portrait',     c.portrait,
               'vignette',     c.vignette,
               'cadrage',      c.cadrage,
               'deja_employe', exists (select 1 from public.pnj_membres m
                                         join public.pnj_employes_metier e on e.pnj_id = m.id
                                        where m.proprietaire_pj = v_moi and m.statut = 'actif'
                                          and e.candidat_id = c.candidat_id))
             order by c.metier, c.rang, c.nom)
        from public.pnj_candidats_catalogue c
       where c.employeur_id = v_emp.employeur_id and c.actif
    ), '[]'::jsonb));
end;
$function$;

-- employeur_embaucher(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.employeur_embaucher(p_candidat_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  c_max_employes constant integer := 10;
  v_moi text; v_pays text; v_id text; v_libelle text;
  v_cand public.pnj_candidats_catalogue%rowtype;
  v_emp  public.pnj_employeurs%rowtype;
  v_prof public.pnj_metiers_profils%rowtype;
  v_deja integer; v_quota integer; v_nb integer;
  v_pa integer; v_cost integer; v_pay jsonb; v_caisse jsonb := null;
begin
  v_moi := public.mon_personnage();
  if v_moi is null then
    return jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); end if;
  select coalesce(country, 'republic') into v_pays
    from public.personnages_donnees where name = v_moi;
  select * into v_cand from public.pnj_candidats_catalogue
   where candidat_id = p_candidat_id and actif;
  if v_cand.candidat_id is null then
    return jsonb_build_object('ok', false, 'raison', 'candidat_inconnu'); end if;
  select * into v_emp from public.pnj_employeurs
   where employeur_id = v_cand.employeur_id and actif;
  if v_emp.employeur_id is null then
    return jsonb_build_object('ok', false, 'raison', 'employeur_inconnu'); end if;
  if v_emp.pays <> v_pays then
    return jsonb_build_object('ok', false, 'raison', 'employeur_hors_pays'); end if;
  select * into v_prof from public.pnj_metiers_profils where metier = v_cand.metier;
  if v_prof.metier is null then
    return jsonb_build_object('ok', false, 'raison', 'profil_metier_absent'); end if;
  if not v_prof.recrutable then
    return jsonb_build_object('ok', false, 'raison', 'metier_non_recrutable',
                              'metier', v_cand.metier); end if;
  select count(*) into v_deja from public.pnj_membres m
   where m.famille = 'employe' and m.proprietaire_pj = v_moi and m.statut = 'actif';
  if v_deja >= c_max_employes then
    return jsonb_build_object('ok', false, 'raison', 'plafond_employes',
                              'plafond', c_max_employes); end if;
  v_quota := coalesce(v_prof.quota_par_joueur, 1);
  select count(*) into v_nb from public.pnj_membres m
    join public.pnj_employes_metier e on e.pnj_id = m.id
   where m.proprietaire_pj = v_moi and m.statut = 'actif' and e.job = v_cand.metier;
  if v_nb >= v_quota then
    return jsonb_build_object('ok', false, 'raison', 'quota_metier_atteint',
      'metier', v_cand.metier, 'quota', v_quota, 'employes', v_nb); end if;
  v_id := public.employe_pnj_id(v_moi, v_cand.metier, v_cand.candidat_id);
  if exists (select 1 from public.pnj_membres where id = v_id and statut = 'actif') then
    return jsonb_build_object('ok', false, 'raison', 'deja_employe',
                              'pnj_id', v_id, 'nom', v_cand.nom); end if;
  if v_prof.ordre_fn is not null then
    v_pa   := coalesce(v_prof.pa_initial, 0);
    v_cost := coalesce(v_prof.cout_initial, 0);
    if not exists (select 1 from public.ordres_couts o
                    where o.fn = v_prof.ordre_fn and o.pa = v_pa and o.cost = v_cost) then
      return jsonb_build_object('ok', false, 'raison', 'ordre_non_declare',
                                'fn', v_prof.ordre_fn, 'pa', v_pa, 'cout', v_cost); end if;
    v_pay := public.payer_ordre(v_moi, v_prof.ordre_fn, v_pa, v_cost);
  else
    v_pa   := 0;
    v_cost := coalesce(v_prof.cout_initial, 0);
    if v_cost > 0 then v_pay := public.debiter_fonds_ordinaires(v_moi, v_cost);
                  else v_pay := jsonb_build_object('ok', true, 'montant', 0); end if;
  end if;
  if coalesce((v_pay->>'ok')::boolean, false) is not true then
    return jsonb_build_object('ok', false, 'raison', 'paiement_refuse',
                              'paiement', v_pay, 'cout', v_cost); end if;
  if v_emp.caisse_id is not null and v_cost > 0 then
    perform set_config('rp.caisse_interne', 'on', true);
    v_caisse := public.caisse_institution_mouvement(v_emp.caisse_id, v_cost, false);
  end if;
  insert into public.pnj_membres (id, famille, classe, nom, pays, proprietaire_pj,
      leader_pj, statut, car_int, car_cha, car_vol, car_per, car_dup, car_ent)
  values (v_id, 'employe', coalesce(v_prof.classe, 'beta'), v_cand.nom, v_pays,
      v_moi, v_moi, 'actif',
      v_prof.car_int, v_prof.car_cha, v_prof.car_vol,
      v_prof.car_per, v_prof.car_dup, v_prof.car_ent)
  on conflict (id) do update set
      statut = 'actif', nom = excluded.nom, classe = excluded.classe,
      proprietaire_pj = excluded.proprietaire_pj, leader_pj = excluded.leader_pj,
      ville = null, building_id = null, room_id = null,
      car_int = excluded.car_int, car_cha = excluded.car_cha, car_vol = excluded.car_vol,
      car_per = excluded.car_per, car_dup = excluded.car_dup, car_ent = excluded.car_ent,
      maj_le = now();
  v_libelle := coalesce(v_prof.role_libelle, initcap(v_cand.metier)) || ' — ' || v_emp.nom;
  insert into public.pnj_employes_metier (pnj_id, job, role_libelle, cout_jour,
      genre, photo_url, photo_pos, candidat_id, depuis_jour)
  values (v_id, v_cand.metier, v_libelle, coalesce(v_prof.cout_jour, 0),
      v_cand.genre, v_cand.portrait, v_cand.cadrage, v_cand.candidat_id, null)
  on conflict (pnj_id) do update set
      job = excluded.job, role_libelle = excluded.role_libelle,
      cout_jour = excluded.cout_jour, genre = excluded.genre,
      photo_url = excluded.photo_url, photo_pos = excluded.photo_pos,
      candidat_id = excluded.candidat_id;
  return jsonb_build_object('ok', true,
    'pnj_id', v_id, 'candidat_id', v_cand.candidat_id, 'metier', v_cand.metier,
    'nom', v_cand.nom, 'genre', v_cand.genre, 'accroche', v_cand.accroche,
    'portrait', v_cand.portrait, 'vignette', v_cand.vignette, 'cadrage', v_cand.cadrage,
    'role_libelle', v_libelle,
    'employeur_id', v_emp.employeur_id, 'employeur', v_emp.nom,
    'cout_embauche', v_cost, 'cout_jour', coalesce(v_prof.cout_jour, 0), 'pa', v_pa,
    'caracteristiques', public.pnj_metier_profil(v_cand.metier),
    'paiement', v_pay, 'caisse_agence', v_caisse,
    'employes', v_deja + 1, 'plafond', c_max_employes,
    'quota', v_quota, 'employes_metier', v_nb + 1);
end;
$function$;

-- escort_piege_tenter(uuid,text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.escort_piege_tenter(p_requete uuid, p_cible text, p_pa integer, p_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a public.personnages_donnees; params jsonb; v jsonb; o jsonb; v_paie jsonb;
  v_dup integer; v_dis integer; c_dup integer; c_dis integer; v_taux integer; v_roll integer;
  v_t_enq integer; v_t_id integer; v_enquete boolean := false; v_identifie boolean := false;
BEGIN
  SELECT * INTO a FROM public.personnages_donnees WHERE name = public.mon_personnage() FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  params := jsonb_build_object('cible', p_cible, 'pa', p_pa, 'cost', p_cost);
  v := public.inventaire_action_rejouer_interne(a.name, p_requete, 'escort_piege', params); IF v IS NOT NULL THEN RETURN v; END IF;
  IF p_cible IS NULL OR p_cible = a.name OR NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_cible) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  IF public.inventaire_place_restante(a.inventory) < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  v_paie := public.payer_ordre(a.name, 'escort_piege', p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_dup := coalesce((a.stats ->> 'DUP')::numeric, 8)::integer;
  v_dis := coalesce(CASE WHEN jsonb_typeof(a.resources -> 'dis') = 'number' THEN (a.resources ->> 'dis')::numeric END, 50)::integer;
  c_dup := floor(random() * 6)::integer + 6;
  c_dis := floor(random() * 40)::integer + 30;
  v_taux := least(80, 30 + v_dup * 2 - floor(c_dup * 1.5)::integer);
  v_roll := floor(random() * 100)::integer + 1;
  IF v_roll <= v_taux THEN
    PERFORM public.ressource_ajuster_interne(a.name, 'inf', 10);
    PERFORM public.ressource_ajuster_interne(a.name, 'pop', 5);
    o := public.kompromat_objet_interne(p_cible, p_cible || ' impliqué(e) dans un scandale compromettant avec une escort.', coalesce(a.day, 1) + 10);
    v := public.inventaire_deposer_interne(a.name, o);
    IF (v ->> 'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'escort_piege: depot refuse'; END IF;
    v := v - 'qte' || jsonb_build_object('reussi', true, 'objet_id', o ->> 'id');
  ELSE
    v_t_enq := least(70, c_dup * 4 + c_dis / 10);
    IF floor(random() * 100)::integer + 1 <= v_t_enq THEN
      v_enquete := true;
      v_t_id := least(80, v_t_enq - v_dup * 2 - v_dis / 10);
      IF floor(random() * 100)::integer + 1 <= v_t_id THEN
        v_identifie := true;
        PERFORM public.ressource_ajuster_interne(a.name, 'pop', -15);
        PERFORM public.crime_dis_ajuster_interne(a.name, -10);
      END IF;
    END IF;
    v := jsonb_build_object('ok', true, 'reussi', false, 'enquete', v_enquete, 'identifie', v_identifie);
  END IF;
  v := v || jsonb_build_object('taux', v_taux, 'jet', v_roll)
       || (SELECT jsonb_build_object('pa', pa, 'arg', arg, 'liquide', liquide, 'inf', resources -> 'inf', 'pop', resources -> 'pop', 'dis', resources -> 'dis',
                                     'inventory', inventory, 'revision', inventory_revision)
             FROM public.personnages_donnees WHERE name = a.name);
  INSERT INTO public.inventaire_actions_recus VALUES (a.name, p_requete, 'escort_piege', params, v, now());
  RETURN v;
END; $function$;

-- escort_recruter(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.escort_recruter(p_escort_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_max_employes constant integer := 10;
  v_moi text; v_pays text; v_agence text; v_id text;
  v_esc  public.escorts_catalogue%ROWTYPE;
  v_prof public.pnj_metiers_profils%ROWTYPE;
  v_deja integer; v_pay jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT coalesce(country, 'republic') INTO v_pays
    FROM public.personnages_donnees WHERE name = v_moi;

  SELECT * INTO v_esc FROM public.escorts_catalogue
   WHERE escort_id = p_escort_id AND pays = v_pays AND actif;
  IF v_esc.escort_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'escort_inconnue'); END IF;

  SELECT * INTO v_prof FROM public.pnj_metiers_profils WHERE metier = 'escort';
  IF v_prof.metier IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'profil_metier_absent'); END IF;

  SELECT count(*) INTO v_deja FROM public.pnj_membres m
   WHERE m.famille = 'employe' AND m.proprietaire_pj = v_moi AND m.statut = 'actif';
  IF v_deja >= c_max_employes THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plafond_employes',
                              'plafond', c_max_employes); END IF;

  v_id := public.employe_pnj_id(v_moi, 'escort', p_escort_id);
  IF EXISTS (SELECT 1 FROM public.pnj_membres WHERE id = v_id AND statut = 'actif') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_employee',
                              'pnj_id', v_id, 'nom', v_esc.nom); END IF;

  v_pay := public.debiter_fonds_ordinaires(v_moi, v_prof.cout_initial);
  IF COALESCE((v_pay->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'paiement_refuse',
                              'paiement', v_pay, 'cout', v_prof.cout_initial); END IF;

  SELECT nom INTO v_agence FROM public.escorts_agences WHERE pays = v_pays;

  INSERT INTO public.pnj_membres (id, famille, classe, nom, pays, proprietaire_pj,
                                  leader_pj, pa, statut,
                                  car_int, car_cha, car_vol, car_per, car_dup, car_ent)
  VALUES (v_id, 'employe', 'beta', v_esc.nom, v_pays, v_moi, v_moi, 12, 'actif',
          v_prof.car_int, v_prof.car_cha, v_prof.car_vol,
          v_prof.car_per, v_prof.car_dup, v_prof.car_ent)
  ON CONFLICT (id) DO UPDATE SET
    statut = 'actif', nom = EXCLUDED.nom,
    proprietaire_pj = EXCLUDED.proprietaire_pj, leader_pj = EXCLUDED.leader_pj,
    ville = NULL, building_id = NULL, room_id = NULL,
    car_int = EXCLUDED.car_int, car_cha = EXCLUDED.car_cha, car_vol = EXCLUDED.car_vol,
    car_per = EXCLUDED.car_per, car_dup = EXCLUDED.car_dup, car_ent = EXCLUDED.car_ent,
    maj_le = now();

  INSERT INTO public.pnj_employes_metier (pnj_id, job, role_libelle, cout_jour, genre,
                                          escort_id, depuis_jour)
  VALUES (v_id, 'escort',
          'Escort — ' || coalesce(v_agence, 'Agence'),
          v_prof.cout_jour, v_esc.genre, v_esc.escort_id, NULL)
  ON CONFLICT (pnj_id) DO UPDATE SET
    job = EXCLUDED.job, role_libelle = EXCLUDED.role_libelle,
    cout_jour = EXCLUDED.cout_jour, genre = EXCLUDED.genre,
    escort_id = EXCLUDED.escort_id;

  RETURN jsonb_build_object('ok', true, 'pnj_id', v_id,
    'escort_id', v_esc.escort_id, 'nom', v_esc.nom, 'genre', v_esc.genre,
    'portrait', v_esc.portrait, 'vignette', v_esc.vignette, 'cadrage', v_esc.cadrage,
    'agence', v_agence, 'cout_jour', v_prof.cout_jour, 'cout_initial', v_prof.cout_initial,
    'caracteristiques', public.pnj_metier_profil('escort'),
    'paiement', v_pay, 'employes', v_deja + 1, 'plafond', c_max_employes);
END;
$function$;

-- escort_sociale_actuelle() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.escort_sociale_actuelle()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_id text; v_nom text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT c.escort_id INTO v_id FROM public.pnj_social_escort_choisi c WHERE c.joueur = v_moi;
  IF v_id IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'escort_id', NULL); END IF;
  SELECT nom INTO v_nom FROM public.escorts_catalogue WHERE escort_id = v_id;
  RETURN jsonb_build_object('ok', true, 'escort_id', v_id, 'nom', v_nom);
END;
$function$;

-- escort_sociale_choisir(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.escort_sociale_choisir(p_escort_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_avant text; v_avant_nom text;
  v_esc public.escorts_catalogue%ROWTYPE;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT coalesce(country, 'republic') INTO v_pays
    FROM public.personnages_donnees WHERE name = v_moi;

  SELECT * INTO v_esc FROM public.escorts_catalogue
   WHERE escort_id = p_escort_id AND pays = v_pays AND actif;
  IF v_esc.escort_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'escort_inconnue'); END IF;

  SELECT c.escort_id INTO v_avant
    FROM public.pnj_social_escort_choisi c WHERE c.joueur = v_moi;
  IF v_avant IS NOT DISTINCT FROM p_escort_id THEN
    RETURN jsonb_build_object('ok', true, 'inchange', true,
                              'escort_id', p_escort_id, 'nom', v_esc.nom); END IF;
  SELECT nom INTO v_avant_nom FROM public.escorts_catalogue WHERE escort_id = v_avant;

  INSERT INTO public.pnj_social_escort_choisi (joueur, escort_id, choisi_le)
       VALUES (v_moi, p_escort_id, now())
  ON CONFLICT (joueur) DO UPDATE
     SET escort_id = EXCLUDED.escort_id, choisi_le = now();

  INSERT INTO public.pnj_social_relations (pnj_id, joueur)
       VALUES (p_escort_id, v_moi)
  ON CONFLICT (pnj_id, joueur) DO NOTHING;

  RETURN jsonb_build_object('ok', true, 'escort_id', p_escort_id, 'nom', v_esc.nom,
                            'precedente', v_avant, 'precedente_nom', v_avant_nom);
END;
$function$;

-- escorts_agence() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.escorts_agence()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_agence text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT coalesce(country, 'republic') INTO v_pays
    FROM public.personnages_donnees WHERE name = v_moi;

  SELECT nom INTO v_agence FROM public.escorts_agences WHERE pays = v_pays;
  IF v_agence IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'agence', NULL,
                              'escorts', '[]'::jsonb); END IF;

  RETURN jsonb_build_object(
    'ok', true, 'pays', v_pays, 'agence', v_agence,
    'escorts', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
               'escort_id', c.escort_id, 'nom', c.nom, 'genre', c.genre,
               'portrait', c.portrait, 'vignette', c.vignette, 'cadrage', c.cadrage)
             ORDER BY c.genre, c.rang, c.nom)
        FROM public.escorts_catalogue c
       WHERE c.pays = v_pays AND c.actif), '[]'::jsonb));
END;
$function$;

-- etat_civil_date_interne(timestamp with time zone) -> text | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.etat_civil_date_interne(p_date timestamp with time zone)
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
 SELECT extract(day FROM p_date AT TIME ZONE 'Europe/Paris')::integer::text||' '||
 (ARRAY['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'])[extract(month FROM p_date AT TIME ZONE 'Europe/Paris')::integer]||' '||extract(year FROM p_date AT TIME ZONE 'Europe/Paris')::integer::text;
$function$;

-- etat_civil_document_recevoir(uuid,text,text,text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp, TimeZone=UTC
CREATE OR REPLACE FUNCTION public.etat_civil_document_recevoir(p_requete uuid, p_nom text, p_type text, p_reference text, p_pa integer, p_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
 SET "TimeZone" TO 'UTC'
AS $function$
DECLARE a public.personnages_donnees; v jsonb; o jsonb; params jsonb; paiement jsonb;
 dt timestamptz; ville text; titre text; texte text; cle text; ordre text; cout integer;
 m public.mariages; s public.successions; d jsonb; e record; evenements jsonb:='[]'; conjoint text; motif text; devise text;
BEGIN
 SELECT * INTO a FROM public.personnages_donnees WHERE name=public.mon_personnage() FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_requete IS NULL OR nullif(p_nom,'') IS NULL OR p_type IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides');END IF;
 params:=jsonb_build_object('nom',p_nom,'type',p_type,'reference',p_reference,'pa',p_pa,'cost',p_cost);
 v:=public.inventaire_action_rejouer_interne(a.name,p_requete,'etat_civil',params);IF v IS NOT NULL THEN RETURN v;END IF;
 IF (p_type IN('naissance','deces','fiche') AND nullif(p_reference,'') IS NOT NULL) OR (p_type IN('mariage','succession') AND nullif(p_reference,'') IS NULL) THEN RETURN jsonb_build_object('ok',false,'raison','reference_invalide');END IF;
 IF p_type='fiche' THEN
  IF (a.current_building IN('mairie','mairie-capitale') AND a.current_room='salle_archives') IS NOT TRUE THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
  IF p_pa IS DISTINCT FROM 0 OR p_cost IS DISTINCT FROM 0 THEN RETURN jsonb_build_object('ok',false,'raison','cout_non_declare');END IF;
  SELECT objet INTO o FROM public.objets_modeles WHERE id='fiche_historique:'||a.country||':'||p_nom;
 ELSE
  IF a.current_building='office-notarial' AND a.current_room='bureau_contrats' THEN ordre:='acte_officiel_notaire';cout:=100;
  ELSIF a.current_building IN('mairie','mairie-capitale') AND a.current_room='bureau_maire_adjoint'
    AND a.poste->>'id'='maire_adjoint' AND a.poste->>'city'=a.current_city
    AND public.poste_est_atteste(a.name,a.poste,a.country) THEN ordre:='acte_officiel_mairie';cout:=0;
  ELSIF a.current_building IN('tribunal','tribunal-local') AND a.current_room='bureau_magistrats'
    AND a.poste->>'id'='juge' AND (a.poste->>'city' IS NULL OR a.poste->>'city'=a.current_city)
    AND public.poste_est_atteste(a.name,a.poste,a.country) THEN ordre:='acte_officiel_juge';cout:=0;
  ELSIF a.current_building IN('mairie','mairie-capitale') AND a.current_room IN('hall_mairie','accueil_mairie') AND p_nom=a.name THEN ordre:='acte_officiel';cout:=50; -- 28/10/2026 : tarif du jeu (1 PA + 50)
  ELSE RETURN jsonb_build_object('ok',false,'raison','lieu_ou_autorite_refuse');END IF;
  IF p_pa IS DISTINCT FROM 1 OR p_cost IS DISTINCT FROM cout THEN RETURN jsonb_build_object('ok',false,'raison','cout_non_declare');END IF;
 END IF;
 IF p_type IN('naissance','fiche') AND o IS NULL THEN
  SELECT coalesce((SELECT created_at FROM public.personnages_donnees WHERE name=p_nom),created_at),public.etat_civil_ville_interne(a.country,city)
  INTO dt,ville FROM public.etat_civil_naissances WHERE nom=p_nom AND country=a.country LIMIT 1;
  IF dt IS NULL THEN SELECT created_at INTO dt FROM public.personnages_donnees WHERE name=p_nom;END IF;
  IF dt IS NOT NULL THEN
   titre:='Extrait d''acte de naissance';texte:=E'EXTRAIT D''ACTE DE NAISSANCE\n\n'||p_nom||', né(e) le '||public.etat_civil_date_interne(dt)||coalesce(' à '||ville,'')||'.';
   evenements:=evenements||jsonb_build_array(jsonb_build_object('annee',extract(year FROM dt),'texte',public.etat_civil_date_interne(dt)||' : naissance de '||p_nom||coalesce(', née à '||ville,'')||'.'));
  END IF;
 END IF;
 IF p_type IN('mariage','fiche') AND o IS NULL THEN
  FOR m IN SELECT * FROM public.mariages WHERE country=a.country AND (conjoint1=p_nom OR conjoint2=p_nom) AND (p_type='fiche' OR id=p_reference) ORDER BY created_at,id LOOP
   IF m.created_at IS NULL THEN CONTINUE;END IF;
   conjoint:=CASE WHEN m.conjoint1=p_nom THEN m.conjoint2 ELSE m.conjoint1 END;ville:=public.etat_civil_ville_interne(a.country,m.city);
   titre:='Extrait d''acte de mariage — '||conjoint;
   texte:=E'EXTRAIT D''ACTE DE MARIAGE\n\n'||p_nom||' et '||conjoint||', union célébrée le '||public.etat_civil_date_interne(m.created_at)||coalesce(' à '||ville,'')||'.';
   evenements:=evenements||jsonb_build_array(jsonb_build_object('annee',extract(year FROM m.created_at),'texte',public.etat_civil_date_interne(m.created_at)||' : mariage de '||p_nom||' avec '||conjoint||coalesce(', célébré à '||ville,'')||'.'));
   IF m.statut='dissous' THEN
    motif:=CASE WHEN to_jsonb(m)->>'raison_dissolution'='veuvage' THEN 'veuvage' ELSE 'divorce' END;
    texte:=texte||E'\n\nUnion dissoute ('||motif||').';
    evenements:=evenements||jsonb_build_array(jsonb_build_object('annee',extract(year FROM m.created_at),'texte','Union avec '||conjoint||' dissoute ('||motif||').'));
   END IF;
  END LOOP;
 END IF;
 IF p_type IN('deces','fiche') AND o IS NULL THEN
  FOR e IN SELECT created_at,city FROM public.etat_civil_deces WHERE nom=p_nom AND country=a.country ORDER BY created_at LIMIT 1 LOOP
   IF e.created_at IS NULL THEN CONTINUE;END IF;ville:=public.etat_civil_ville_interne(a.country,e.city);
   titre:='Extrait d''acte de décès';texte:=E'EXTRAIT D''ACTE DE DÉCÈS\n\n'||p_nom||', décédé(e) le '||public.etat_civil_date_interne(e.created_at)||coalesce(' à '||ville,'')||'.';
   evenements:=evenements||jsonb_build_array(jsonb_build_object('annee',extract(year FROM e.created_at),'texte',public.etat_civil_date_interne(e.created_at)||' : décès de '||p_nom||coalesce(' à '||ville,'')||'.'));
  END LOOP;
 END IF;
 IF p_type='succession' THEN
  SELECT * INTO s FROM public.successions WHERE id=p_reference AND country=a.country AND statut='resolue';
  IF FOUND THEN
   devise:=CASE a.country WHEN 'republic' THEN 'FR' WHEN 'narco' THEN 'PS' WHEN 'soviet' THEN 'RP' WHEN 'khalija' THEN 'DR' END;
   titre:='Acte de succession — '||s.defunt;
   FOR d IN SELECT value FROM jsonb_array_elements(s.dispositions) WHERE value->'resultat'->>'beneficiaire'=p_nom LOOP
    texte:=coalesce(texte,E'ACTE DE SUCCESSION\n\nSuccession de '||s.defunt||E', réglée.\nBénéficiaire : '||p_nom||E'\n\n')||
    CASE WHEN d->>'type'='argent' THEN '- Somme nette perçue : '||coalesce(d->>'part_nette','0')||' '||devise
    ELSE '- '||CASE WHEN d->>'type'='terrain' THEN 'Terrain' ELSE 'Entreprise' END||' : '||coalesce(d->>'libelle',d->>'id') END||E'\n';
   END LOOP;
  END IF;
 END IF;
 IF p_type='fiche' THEN
  IF o IS NULL AND (NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=p_nom) OR jsonb_array_length(evenements)=0) THEN RETURN jsonb_build_object('ok',false,'raison','personne_introuvable');END IF;
  IF o IS NULL THEN SELECT jsonb_build_object('name','Fiche d''état-civil — '||p_nom,'icon','ti-file-text','desc',string_agg(x.e->>'texte','<br><br>' ORDER BY (x.e->>'annee')::integer,x.n)) INTO o FROM jsonb_array_elements(evenements) WITH ORDINALITY x(e,n);END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(a.inventory) i WHERE i->>'name'=o->>'name') THEN RETURN jsonb_build_object('ok',false,'raison','deja_possede');END IF;
  o:=o||jsonb_build_object('id','fiche-etat-civil-'||gen_random_uuid());
 ELSE
  IF titre IS NULL OR texte IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acte_introuvable');END IF;
  cle:='acte-'||p_type||'-'||lower(regexp_replace(p_nom,'[[:space:]]+','-','g'))||CASE WHEN nullif(p_reference,'') IS NULL THEN '' ELSE '-'||lower(regexp_replace(p_reference,'[[:space:]]+','-','g')) END;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(a.inventory) i WHERE i->>'acteCle'=cle) THEN RETURN jsonb_build_object('ok',false,'raison','deja_possede');END IF;
  SELECT objet INTO STRICT o FROM public.objets_modeles WHERE id='acte:'||p_type;
  o:=o||jsonb_build_object('acteCle',cle,'name',titre,'concerne',p_nom,'desc',rtrim(texte,E'\n'));
 END IF;
 IF public.inventaire_place_restante(a.inventory)<1 THEN RETURN jsonb_build_object('ok',false,'raison','inventaire_plein');END IF;
 IF p_type<>'fiche' THEN paiement:=public.payer_ordre(a.name,ordre,p_pa,p_cost);IF (paiement->>'ok')::boolean IS DISTINCT FROM true THEN RETURN paiement;END IF;END IF;
 v:=public.inventaire_deposer_interne(a.name,o);
 IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'etat civil: depot refuse';END IF;
 v:=v||jsonb_build_object('objet',o->>'name','paie',paiement);
 INSERT INTO public.inventaire_actions_recus VALUES(a.name,p_requete,'etat_civil',params,v,now());RETURN v;
END; $function$;

-- etat_civil_ville_interne(text,text) -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.etat_civil_ville_interne(p_pays text, p_ville text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
 SELECT coalesce((SELECT nom FROM public.villes WHERE pays=p_pays AND ville=p_ville),nullif(p_ville,''));
$function$;

-- fermeture_definir_date_universelle() -> trigger | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.fermeture_definir_date_universelle()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.duree_jours IS NULL OR NEW.duree_jours < 1 OR NEW.duree_jours > 36500 THEN
    RAISE EXCEPTION 'Fermeture : duree_jours obligatoire (1..36500)';
  END IF;
  -- La base décide de la date, pas le navigateur ni le compteur individuel.
  NEW.date_fin_universelle := (now() AT TIME ZONE 'Europe/Paris')::date + NEW.duree_jours;
  RETURN NEW;
END;
$function$;

-- indice_diplomatique_ordre(text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.indice_diplomatique_ordre(p_fn text, p_pa integer, p_invites integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_paie jsonb; v_venus integer := 0; v_pop numeric; v_taux integer;
  v_reussi boolean := false; v_indice integer; i integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic'),
         coalesce(CASE WHEN jsonb_typeof(resources -> 'pop') = 'number' THEN (resources ->> 'pop')::numeric END, 50)
    INTO v_pays, v_pop FROM public.personnages_donnees WHERE name = v_moi;

  IF p_fn = 'mobilisation_nationale' THEN
    IF NOT public.mon_poste_est_dans('min_def', v_pays) THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_ministre_defense'); END IF;
  ELSIF p_fn IN ('banquet_diplo', 'reception_etat') THEN
    IF NOT public.mon_poste_est_dans('president', v_pays) THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_president'); END IF;
    IF p_fn = 'banquet_diplo' AND (coalesce(p_invites, 0) < 1 OR p_invites > 50) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'aucun_invite'); END IF;
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'ordre_inconnu');
  END IF;

  v_paie := public.payer_ordre(v_moi, p_fn, p_pa, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;

  IF p_fn = 'mobilisation_nationale' THEN
    PERFORM public.indice_diplomatique_varier_interne(d.pays, -5, 'mobilisation_' || v_pays, v_moi)
       FROM public.indices_diplomatiques d WHERE d.pays <> v_pays;
    v_reussi := true;
  ELSIF p_fn = 'banquet_diplo' THEN
    FOR i IN 1 .. p_invites LOOP
      IF random() < 0.7 THEN v_venus := v_venus + 1; END IF;
    END LOOP;
    v_reussi := v_venus = p_invites;
    IF v_reussi THEN PERFORM public.indice_diplomatique_varier_interne(v_pays, 8, 'banquet_diplomatique', v_moi); END IF;
  ELSE
    v_taux := least(95, greatest(5, 80 + floor((CASE WHEN v_pop > 20 THEN floor(v_pop - 20) ELSE -floor(20 - v_pop) END) / 2)::integer));
    v_reussi := floor(random() * 100) + 1 <= v_taux;
    IF v_reussi THEN PERFORM public.indice_diplomatique_varier_interne(v_pays, 5, 'reception_etat', v_moi); END IF;
  END IF;

  SELECT valeur INTO v_indice FROM public.indices_diplomatiques WHERE pays = v_pays;
  RETURN jsonb_build_object('ok', true, 'reussi', v_reussi, 'venus', v_venus, 'invites', coalesce(p_invites, 0),
                            'indice', v_indice, 'paie', v_paie);
END; $function$;

-- indice_diplomatique_varier_interne(text,integer,text,text) -> integer | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.indice_diplomatique_varier_interne(p_pays text, p_delta integer, p_cause text, p_acteur text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v integer;
BEGIN
  IF coalesce(p_delta, 0) = 0 THEN
    SELECT valeur INTO v FROM public.indices_diplomatiques WHERE pays = p_pays; RETURN v; END IF;
  UPDATE public.indices_diplomatiques SET valeur = greatest(0, least(100, valeur + p_delta)), maj_le = now()
   WHERE pays = p_pays RETURNING valeur INTO v;
  IF v IS NOT NULL THEN
    INSERT INTO public.indices_diplomatiques_journal (pays, delta, valeur_apres, cause, acteur)
    VALUES (p_pays, p_delta, v, coalesce(p_cause, '?'), p_acteur);
  END IF;
  RETURN v;
END; $function$;

-- indices_diplomatiques_lire() -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.indices_diplomatiques_lire()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT jsonb_build_object('ok', true, 'indices', coalesce(jsonb_object_agg(pays, valeur), '{}'::jsonb))
    FROM public.indices_diplomatiques;
$function$;

-- indices_villes_piete_du_registre() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.indices_villes_piete_du_registre()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.id IN ('republic_capitale', 'republic_ville_a', 'republic_ville_b') THEN
    NEW.data := CASE WHEN jsonb_typeof(NEW.data) = 'object' THEN NEW.data ELSE '{}'::jsonb END
      || jsonb_build_object('piete', public.piete_ville_calculee_interne(substr(NEW.id, length('republic_') + 1)));
  END IF;
  RETURN NEW;
END; $function$;

-- mariage_actif_de(text) -> mariages | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.mariage_actif_de(p_nom text)
 RETURNS mariages
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT * FROM public.mariages WHERE statut = 'actif' AND p_nom IN (conjoint1, conjoint2) LIMIT 1 $function$;

-- mariage_demander(uuid,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.mariage_demander(p_requete uuid, p_destinataire text, p_relation text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text := public.mon_personnage(); p record; dest text := nullif(btrim(coalesce(p_destinataire,'')),'');
  est_pj boolean; r jsonb; d jsonb; chance int; tirage int; v_id text;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR dest IS NULL OR dest = moi THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = moi FOR UPDATE;
  IF EXISTS (SELECT 1 FROM public.demandes_mariage WHERE id = 'demande-mariage-'||p_requete)
     OR EXISTS (SELECT 1 FROM public.mariages WHERE id = 'mariage-'||p_requete) THEN
    RETURN jsonb_build_object('ok',true,'rejeu',true); END IF;
  IF (public.mariage_actif_de(moi)).id IS NOT NULL THEN RETURN jsonb_build_object('ok',false,'raison','deja_marie'); END IF;
  IF (public.mariage_actif_de(dest)).id IS NOT NULL THEN RETURN jsonb_build_object('ok',false,'raison','destinataire_deja_marie'); END IF;
  est_pj := EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = dest);
  IF est_pj AND EXISTS (SELECT 1 FROM public.demandes_mariage WHERE statut IN ('en_attente','acceptee')
       AND ((demandeur = moi AND destinataire = dest) OR (demandeur = dest AND destinataire = moi))) THEN
    RETURN jsonb_build_object('ok',false,'raison','demande_deja_en_cours'); END IF;
  r := public.payer_ordre(moi, 'demander_mariage', 1, 0);
  IF r->>'ok' IS DISTINCT FROM 'true' THEN RETURN r; END IF;
  IF est_pj THEN
    v_id := 'demande-mariage-'||p_requete;
    INSERT INTO public.demandes_mariage(id, demandeur, destinataire, country, statut)
      VALUES (v_id, moi, dest, coalesce(p.country,'republic'), 'en_attente');
    RETURN r || jsonb_build_object('ok',true,'pnj',false,'demandeId',v_id);
  END IF;
  -- PNJ : le tirage a lieu ici. La relation (allié / ennemi) n'est connue que du navigateur ;
  -- l'appartenance au groupe est relue sur la présence.
  chance := CASE
    WHEN EXISTS (SELECT 1 FROM public.presences pr, jsonb_array_elements(CASE WHEN jsonb_typeof(pr.groupe_pnj::jsonb)='array' THEN pr.groupe_pnj::jsonb ELSE '[]' END) g
                 WHERE pr.name = moi AND g->>'nom' = dest) THEN 80
    WHEN p_relation = 'ally' THEN 70 WHEN p_relation = 'enemy' THEN 5 ELSE 35 END;
  tirage := 1 + floor(random() * 100)::int;
  IF tirage > chance THEN RETURN r || jsonb_build_object('ok',true,'pnj',true,'accepte',false); END IF;
  d := public.debiter_fonds_ordinaires(moi, 200);
  IF d->>'ok' IS DISTINCT FROM 'true' THEN
    RETURN r || jsonb_build_object('ok',true,'pnj',true,'accepte',true,'celebre',false,'raison','fonds_insuffisants'); END IF;
  INSERT INTO public.mariages(id, conjoint1, conjoint2, country, statut, jour_union, city)
    VALUES ('mariage-'||p_requete, moi, dest, coalesce(p.country,'republic'), 'actif', coalesce(p.day,1), p.current_city);
  RETURN jsonb_build_object('ok',true,'pnj',true,'accepte',true,'celebre',true,'mariageId','mariage-'||p_requete)
    || jsonb_strip_nulls(jsonb_build_object('pa',(SELECT pa FROM public.personnages_donnees WHERE name=moi),
         'arg',d->'arg','liquide',d->'liquide'));
END;
$function$;

-- mariage_dissoudre(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.mariage_dissoudre(p_raison text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text := public.mon_personnage(); m public.mariages; r jsonb := '{}'::jsonb;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  IF p_raison IS NULL OR p_raison NOT IN ('divorce','veuvage') THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  PERFORM 1 FROM public.personnages_donnees WHERE name = moi FOR UPDATE;
  -- Rejeu naturel : une seconde demande trouve « non_marie » et ne paie rien.
  m := public.mariage_actif_de(moi);
  IF m.id IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_marie'); END IF;
  IF p_raison = 'veuvage' THEN
    IF NOT EXISTS (SELECT 1 FROM public.successions WHERE defunt = CASE WHEN m.conjoint1 = moi THEN m.conjoint2 ELSE m.conjoint1 END) THEN
      RETURN jsonb_build_object('ok',false,'raison','succession_non_ouverte'); END IF;
  ELSE
    r := public.payer_ordre(moi, 'demander_divorce', 1, 200);
    IF r->>'ok' IS DISTINCT FROM 'true' THEN RETURN r; END IF;
  END IF;
  UPDATE public.mariages SET statut = 'dissous', raison_dissolution = p_raison, dissous_at = now() WHERE id = m.id;
  RETURN r || jsonb_build_object('ok',true,'mariageId',m.id,
    'conjoint', CASE WHEN m.conjoint1 = moi THEN m.conjoint2 ELSE m.conjoint1 END);
END;
$function$;

-- mariage_ecriture_ecran_refuser() -> trigger | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.mariage_ecriture_ecran_refuser()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN RETURN coalesce(NEW, OLD); END IF;
  RAISE EXCEPTION 'mariage_ecrit_par_le_serveur' USING ERRCODE = '42501';
END;
$function$;

-- mariage_officialiser(uuid,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.mariage_officialiser(p_requete uuid, p_conjoint text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text := public.mon_personnage(); p record; c record; dm record; r jsonb; v_id text := 'mariage-'||p_requete;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_conjoint IS NULL OR p_conjoint = moi THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  IF EXISTS (SELECT 1 FROM public.mariages WHERE id = v_id) THEN RETURN jsonb_build_object('ok',true,'rejeu',true,'mariageId',v_id); END IF;
  -- Verrous dans un ordre stable pour que deux célébrations croisées ne se bloquent pas.
  PERFORM 1 FROM public.personnages_donnees WHERE name IN (moi, p_conjoint) ORDER BY name FOR UPDATE;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = moi;
  SELECT * INTO c FROM public.personnages_donnees WHERE name = p_conjoint;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','conjoint_introuvable'); END IF;
  SELECT * INTO dm FROM public.demandes_mariage WHERE statut = 'acceptee'
    AND ((demandeur = moi AND destinataire = p_conjoint) OR (demandeur = p_conjoint AND destinataire = moi))
    ORDER BY created_at DESC LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','consentement_absent'); END IF;
  IF (public.mariage_actif_de(moi)).id IS NOT NULL OR (public.mariage_actif_de(p_conjoint)).id IS NOT NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','deja_marie'); END IF;
  IF p.current_building IS NULL OR c.current_building IS NULL OR p.current_room IS NULL OR c.current_room IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','conjoint_absent'); END IF;
  IF p.current_city IS DISTINCT FROM c.current_city OR p.current_building IS DISTINCT FROM c.current_building
     OR p.current_room IS DISTINCT FROM c.current_room OR p.country IS DISTINCT FROM c.country THEN
    RETURN jsonb_build_object('ok',false,'raison','conjoint_absent'); END IF;
  r := public.payer_ordre(moi, 'officialiser_mariage', 2, 200);
  IF r->>'ok' IS DISTINCT FROM 'true' THEN RETURN r; END IF;
  INSERT INTO public.mariages(id, conjoint1, conjoint2, country, statut, jour_union, city)
    VALUES (v_id, moi, p_conjoint, coalesce(p.country,'republic'), 'actif', coalesce(p.day,1), p.current_city);
  UPDATE public.demandes_mariage SET statut = 'celebree' WHERE id = dm.id;
  RETURN r || jsonb_build_object('ok',true,'mariageId',v_id);
END;
$function$;

-- mariage_repondre(text,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.mariage_repondre(p_demande text, p_accepter boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text := public.mon_personnage(); dm record;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  SELECT * INTO dm FROM public.demandes_mariage WHERE id = p_demande FOR UPDATE;
  IF NOT FOUND OR dm.destinataire IS DISTINCT FROM moi THEN RETURN jsonb_build_object('ok',false,'raison','demande_introuvable'); END IF;
  IF dm.statut <> 'en_attente' THEN RETURN jsonb_build_object('ok', dm.statut = CASE WHEN p_accepter THEN 'acceptee' ELSE 'refusee' END,'raison','deja_repondu','statut',dm.statut); END IF;
  UPDATE public.demandes_mariage SET statut = CASE WHEN p_accepter THEN 'acceptee' ELSE 'refusee' END WHERE id = p_demande;
  RETURN jsonb_build_object('ok',true,'statut',CASE WHEN p_accepter THEN 'acceptee' ELSE 'refusee' END,'demandeur',dm.demandeur);
END;
$function$;

-- naturalisation_traiter(text,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.naturalisation_traiter(p_demande_id text, p_accepter boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_acteur text; v_pays text; v_d record; v_rembours integer := 0; v_id bigint;
BEGIN
  -- Autorite : exiger_poste leve si le compte n'est pas le Ministre de l'Interieur en exercice.
  v_acteur := public.exiger_poste('min_int');
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_acteur;

  SELECT * INTO v_d FROM public.demandes_naturalisation
   WHERE id = p_demande_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'demande_introuvable');
  END IF;
  -- Un ministre ne traite que les demandes visant SON pays.
  IF v_d.pays_vise IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;
  IF COALESCE(v_d.statut, 'pending') <> 'pending' THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'statut', v_d.statut);
  END IF;
  -- Delai de 48 h : la ligne porte deja l'echeance, le serveur la fait respecter.
  IF v_d.date_traitement_possible IS NOT NULL
     AND (EXTRACT(epoch FROM now()) * 1000) < v_d.date_traitement_possible THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_non_ecoule');
  END IF;

  IF p_accepter THEN
    UPDATE public.demandes_naturalisation SET statut = 'acceptee' WHERE id = p_demande_id;
    RETURN jsonb_build_object('ok', true, 'statut', 'acceptee', 'demandeur', v_d.demandeur);
  END IF;

  -- REFUS : remboursement de la moitie, montant relu sur la ligne, jamais fourni par le client.
  v_rembours := floor(COALESCE(v_d.montant, 0) * 0.5)::integer;
  UPDATE public.demandes_naturalisation SET statut = 'refusee' WHERE id = p_demande_id;
  IF v_rembours > 0 THEN
    INSERT INTO public.dons_en_attente (destinataire, montant, expediteur, traite)
    VALUES (v_d.demandeur, v_rembours, 'Service de l''Immigration', false)
    RETURNING id INTO v_id;
  END IF;
  RETURN jsonb_build_object('ok', true, 'statut', 'refusee', 'demandeur', v_d.demandeur,
                            'remboursement', v_rembours, 'don_id', v_id);
END;
$function$;

-- organisation_adhesion_payante(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.organisation_adhesion_payante(p_requete text, p_orga text, p_grade text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_recu jsonb; v_json jsonb; v_paie jsonb; v_cout record; v_nouveau numeric; v_res jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_orga IS DISTINCT FROM 'orga_syndicat_dockers_republic_ville_a' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'adhesion_payante_inconnue');
  END IF;
  v_recu := public.caisse_collective_recu_interne(p_requete, v_moi, 'se_syndiquer', p_orga);
  IF v_recu IS NOT NULL THEN RETURN v_recu; END IF;

  SELECT data::jsonb INTO v_json FROM public.organisations WHERE id = p_orga FOR UPDATE;
  IF v_json IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'organisation_introuvable'); END IF;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_json->'membres', '[]'::jsonb)) m WHERE m->>'nom' = v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_membre');
  END IF;

  SELECT pa, cost INTO v_cout FROM public.ordres_couts WHERE fn = 'se_syndiquer' ORDER BY pa, cost LIMIT 1;
  v_paie := public.payer_ordre(v_moi, 'se_syndiquer', v_cout.pa, v_cout.cost);
  IF NOT coalesce((v_paie->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paie->>'raison', 'paiement_refuse'), 'paiement', v_paie);
  END IF;

  v_json := jsonb_set(v_json, '{membres}', coalesce(v_json->'membres', '[]'::jsonb) || jsonb_build_array(
    jsonb_build_object('nom', v_moi, 'grade', left(coalesce(nullif(btrim(coalesce(p_grade, '')), ''), 'Adherent'), 60),
                       'gradeIdx', 0, 'rejointLe', coalesce((SELECT day FROM public.personnages_donnees WHERE name = v_moi), 1),
                       'derniereCotisationDate', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'))));
  UPDATE public.organisations SET data = v_json::text WHERE id = p_orga;
  v_nouveau := public.organisation_caisse_ajuster_interne(p_orga, v_cout.cost);

  v_res := jsonb_build_object('ok', true, 'caisse', v_nouveau, 'paiement', v_paie);
  RETURN public.caisse_collective_recu_noter_interne(p_requete, v_moi, 'se_syndiquer', p_orga, v_res);
END $function$;

-- organisation_caisse_ajuster_interne(text,numeric) -> numeric | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.organisation_caisse_ajuster_interne(p_orga text, p_delta numeric)
 RETURNS numeric
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_txt text; v_json jsonb; v_solde numeric;
BEGIN
  SELECT data INTO v_txt FROM public.organisations WHERE id = p_orga FOR UPDATE;
  IF NOT FOUND OR v_txt IS NULL OR NOT (v_txt IS JSON OBJECT) THEN
    RAISE EXCEPTION 'organisation_introuvable: %', p_orga;
  END IF;
  v_json := v_txt::jsonb;
  v_solde := CASE WHEN jsonb_typeof(v_json->'caisse') = 'number' THEN (v_json->>'caisse')::numeric ELSE 0 END;
  IF v_solde + p_delta < 0 THEN RETURN NULL; END IF;
  UPDATE public.organisations
     SET data = jsonb_set(v_json, '{caisse}', to_jsonb(v_solde + p_delta))::text
   WHERE id = p_orga;
  RETURN v_solde + p_delta;
END $function$;

-- organisation_ordre_financier(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.organisation_ordre_financier(p_requete text, p_orga text, p_fn text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_recu jsonb; v_json jsonb; v_type text; v_gest text; v_cout record;
        v_paie jsonb; v_solde numeric; v_montant numeric; v_nouveau numeric; v_res jsonb; v_fiche jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_fn NOT IN ('orga_collecte', 'orga_dividendes') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ordre_inconnu');
  END IF;
  v_recu := public.caisse_collective_recu_interne(p_requete, v_moi, p_fn, coalesce(p_orga, ''));
  IF v_recu IS NOT NULL THEN RETURN v_recu; END IF;

  SELECT data::jsonb INTO v_json FROM public.organisations WHERE id = p_orga FOR UPDATE;
  IF v_json IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'organisation_introuvable'); END IF;
  v_type := v_json->>'type';
  IF (p_fn = 'orga_collecte' AND v_type IS DISTINCT FROM 'religieuse')
     OR (p_fn = 'orga_dividendes' AND v_type IS DISTINCT FROM 'economique') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ordre_hors_type');
  END IF;
  v_gest := coalesce(nullif(btrim(coalesce(v_json->>'tresorier', '')), ''), v_json->>'chef');
  IF v_gest IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'organisation_sans_responsable'); END IF;
  IF v_gest <> v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_gestionnaire_caisse', 'gestionnaire', v_gest);
  END IF;

  v_solde := CASE WHEN jsonb_typeof(v_json->'caisse') = 'number' THEN (v_json->>'caisse')::numeric ELSE 0 END;
  IF p_fn = 'orga_dividendes' AND floor(v_solde * 0.3) < 10 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_vide', 'solde', v_solde);
  END IF;

  SELECT pa, cost INTO v_cout FROM public.ordres_couts WHERE fn = p_fn ORDER BY pa, cost LIMIT 1;
  v_paie := public.payer_ordre(v_moi, p_fn, v_cout.pa, v_cout.cost);
  IF NOT coalesce((v_paie->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paie->>'raison', 'paiement_refuse'), 'paiement', v_paie);
  END IF;

  IF p_fn = 'orga_collecte' THEN
    v_montant := 200 + floor(random() * 500);
    v_nouveau := public.organisation_caisse_ajuster_interne(p_orga, v_montant);
  ELSE
    v_montant := floor(v_solde * 0.3);
    v_nouveau := public.organisation_caisse_ajuster_interne(p_orga, -v_montant);
    IF v_nouveau IS NULL THEN RAISE EXCEPTION 'dividendes: caisse insuffisante'; END IF;
    v_fiche := public.assemblee_crediter_joueur(v_moi, v_montant::integer);
  END IF;

  v_res := jsonb_build_object('ok', true, 'ordre', p_fn, 'montant', v_montant, 'caisse', v_nouveau,
                              'paiement', v_paie, 'fiche', v_fiche);
  RETURN public.caisse_collective_recu_noter_interne(p_requete, v_moi, p_fn, p_orga, v_res);
END $function$;

-- organisation_vainqueur_election(jsonb) -> text | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.organisation_vainqueur_election(p_election jsonb)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
-- Même décompte que verifierElectionsOrganisations : candidats dans l'ordre, le premier qui
-- dépasse strictement le maximum courant l'emporte.
DECLARE c jsonb; v_voix integer; v_max integer := -1; v_vainqueur text;
BEGIN
  FOR c IN SELECT e FROM jsonb_array_elements(coalesce(p_election->'candidats', '[]'::jsonb)) e LOOP
    SELECT count(*) INTO v_voix FROM jsonb_each_text(coalesce(p_election->'votes', '{}'::jsonb)) v
     WHERE v.value = c->>'nom';
    IF v_voix > v_max THEN v_max := v_voix; v_vainqueur := c->>'nom'; END IF;
  END LOOP;
  RETURN v_vainqueur;
END $function$;

-- organisations_finances_garder() -> trigger | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.organisations_finances_garder()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_av jsonb; v_ap jsonb; v_chef_av text; v_est_chef boolean; v_election boolean := false;
        v_vainqueur text; m jsonb; a jsonb; v_membres jsonb := '[]'::jsonb; v_cle text;
BEGIN
  IF current_user NOT IN ('anon', 'authenticated') THEN RETURN NEW; END IF;
  IF NEW.data IS NULL OR NOT (NEW.data IS JSON OBJECT) THEN
    RAISE EXCEPTION 'organisation_donnees_illisibles' USING ERRCODE = '42501';
  END IF;
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RAISE EXCEPTION 'organisation_acteur_non_authentifie' USING ERRCODE = '42501'; END IF;
  v_ap := NEW.data::jsonb;

  IF TG_OP = 'INSERT' THEN
    IF coalesce((v_ap->>'caisse')::numeric, 0) <> 0 THEN
      RAISE EXCEPTION 'organisation_caisse_initiale_interdite' USING ERRCODE = '42501';
    END IF;
    IF nullif(btrim(coalesce(v_ap->>'tresorier', '')), '') IS NOT NULL THEN
      RAISE EXCEPTION 'organisation_tresorier_initial_interdit' USING ERRCODE = '42501';
    END IF;
    IF NOT ((v_ap->>'fondateur') = v_moi AND (v_ap->>'chef') = v_moi)
       AND NOT (coalesce((v_ap->>'chefEstPnj')::boolean, false)
                AND NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_ap->>'chef')) THEN
      RAISE EXCEPTION 'organisation_fondateur_usurpe' USING ERRCODE = '42501';
    END IF;
    IF EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_ap->'membres', '[]'::jsonb)) x
                WHERE x->>'nom' IS DISTINCT FROM v_moi) THEN
      RAISE EXCEPTION 'organisation_fondee_avec_des_membres' USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  v_av := CASE WHEN OLD.data IS JSON OBJECT THEN OLD.data::jsonb ELSE '{}'::jsonb END;
  v_chef_av := v_av->>'chef';
  v_est_chef := v_chef_av IS NOT NULL AND v_chef_av = v_moi;

  -- La caisse est TOUJOURS celle du serveur.
  v_ap := jsonb_set(v_ap, '{caisse}', coalesce(v_av->'caisse', '0'::jsonb));

  -- Clôture d'élection : seule voie de changement de direction sans le chef.
  IF (v_ap->>'chef') IS DISTINCT FROM v_chef_av AND NOT v_est_chef THEN
    v_vainqueur := public.organisation_vainqueur_election(v_av->'election');
    v_election := coalesce((v_av->'election'->>'enCours')::boolean, false)
                  AND (v_av->'election'->>'phase') = 'vote'
                  AND v_vainqueur IS NOT NULL AND (v_ap->>'chef') = v_vainqueur
                  AND EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_av->'membres', '[]'::jsonb)) x
                               WHERE x->>'nom' = v_vainqueur);
    IF NOT v_election THEN
      RAISE EXCEPTION 'organisation_direction_non_autorisee' USING ERRCODE = '42501';
    END IF;
  END IF;

  IF NOT v_est_chef THEN
    FOREACH v_cle IN ARRAY ARRAY['tresorier', 'fondateur'] LOOP
      IF v_av ? v_cle THEN v_ap := jsonb_set(v_ap, ARRAY[v_cle], v_av->v_cle); ELSE v_ap := v_ap - v_cle; END IF;
    END LOOP;
    IF NOT v_election THEN
      IF v_av ? 'chefEstPnj' THEN v_ap := jsonb_set(v_ap, '{chefEstPnj}', v_av->'chefEstPnj'); END IF;
    END IF;

    -- Membres : grades conservés, entrée au grade 0 pour soi seulement, aucun retrait d'autrui.
    FOR m IN SELECT e FROM jsonb_array_elements(coalesce(v_ap->'membres', '[]'::jsonb)) e LOOP
      SELECT e INTO a FROM jsonb_array_elements(coalesce(v_av->'membres', '[]'::jsonb)) e WHERE e->>'nom' = m->>'nom' LIMIT 1;
      IF a IS NOT NULL THEN
        IF NOT (v_election AND m->>'nom' = v_vainqueur) THEN
          m := m || jsonb_build_object('grade', a->'grade', 'gradeIdx', a->'gradeIdx');
        END IF;
      ELSIF m->>'nom' = v_moi THEN
        IF coalesce((m->>'gradeIdx')::integer, 0) <> 0 THEN
          RAISE EXCEPTION 'organisation_grade_non_autorise' USING ERRCODE = '42501';
        END IF;
      ELSIF EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = m->>'nom') THEN
        RAISE EXCEPTION 'organisation_adhesion_non_autorisee' USING ERRCODE = '42501';
      END IF;
      v_membres := v_membres || jsonb_build_array(m);
      a := NULL;
    END LOOP;
    FOR a IN SELECT e FROM jsonb_array_elements(coalesce(v_av->'membres', '[]'::jsonb)) e LOOP
      IF a->>'nom' IS DISTINCT FROM v_moi
         AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_membres) x WHERE x->>'nom' = a->>'nom') THEN
        v_membres := v_membres || jsonb_build_array(a);   -- blob périmé : le membre reste
      END IF;
    END LOOP;
    v_ap := jsonb_set(v_ap, '{membres}', v_membres);

    -- Votes : chacun le sien.
    IF jsonb_typeof(v_ap->'election'->'votes') = 'object' THEN
      IF EXISTS (SELECT 1 FROM jsonb_each(v_ap->'election'->'votes') n
                  WHERE n.key <> v_moi AND (v_av->'election'->'votes'->n.key) IS DISTINCT FROM n.value)
         AND NOT v_election THEN
        RAISE EXCEPTION 'organisation_vote_pour_autrui' USING ERRCODE = '42501';
      END IF;
    END IF;
  END IF;

  NEW.data := v_ap::text;
  RETURN NEW;
END $function$;

-- organisations_politique_autorite() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.organisations_politique_autorite()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi        text;
  v_av         jsonb;   -- le blob AVANT (NULL a l'insertion)
  v_ap         jsonb;   -- le blob APRES
  v_politique  boolean;
  v_chef_avant text;
  v_est_chef   boolean;
  v_m          text;
  v_election   boolean;
BEGIN
  -- LE SERVEUR N'EST PAS CONCERNE. Les crons et les RPC reservees a service_role -- la cotisation,
  -- le contact d'organisation, l'observation d'un agent -- ecrivent legitimement, et ce garde-fou
  -- ne protege pas la base d'elle-meme.
  IF public.est_appel_serveur() THEN
    RETURN CASE TG_OP WHEN 'DELETE' THEN OLD ELSE NEW END;
  END IF;

  v_av := CASE WHEN TG_OP = 'INSERT' OR OLD.data IS NULL OR NOT (OLD.data IS JSON OBJECT)
               THEN NULL ELSE OLD.data::jsonb END;
  v_ap := CASE WHEN TG_OP = 'DELETE' OR NEW.data IS NULL OR NOT (NEW.data IS JSON OBJECT)
               THEN NULL ELSE NEW.data::jsonb END;

  -- CE GARDE-FOU NE CONCERNE QUE LES PARTIS POLITIQUES. Une organisation qui l'est AVANT ou APRES
  -- est gardee : sans le « avant », on changerait le type pour echapper au controle.
  v_politique := (v_av ->> 'type') = 'politique' OR (v_ap ->> 'type') = 'politique';
  IF NOT v_politique THEN
    RETURN CASE TG_OP WHEN 'DELETE' THEN OLD ELSE NEW END;
  END IF;

  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RAISE EXCEPTION 'parti_acteur_non_authentifie' USING ERRCODE = '42501';
  END IF;

  -- UN BLOB DE PARTI DOIT RESTER LISIBLE. Ecrire du texte non-JSON effacerait la composition du
  -- parti pour tout le monde -- y compris pour la regle de solidarite.
  IF TG_OP <> 'DELETE' AND v_ap IS NULL THEN
    RAISE EXCEPTION 'parti_donnees_illisibles' USING ERRCODE = '42501';
  END IF;

  v_chef_avant := v_av ->> 'chef';
  v_est_chef   := (v_chef_avant IS NOT NULL AND v_chef_avant = v_moi);

  -- ---------------------------------------------------------------------------- DISSOLUTION
  IF TG_OP = 'DELETE' THEN
    IF NOT v_est_chef AND (v_av ->> 'fondateur') IS DISTINCT FROM v_moi THEN
      RAISE EXCEPTION 'parti_dissolution_non_autorisee' USING ERRCODE = '42501';
    END IF;
    RETURN OLD;
  END IF;

  -- ---------------------------------------------------------------------------- CREATION
  IF TG_OP = 'INSERT' THEN
    -- ON NE FONDE UN PARTI QU'EN SON PROPRE NOM, et on n'y place personne d'autre que soi.
    IF (v_ap ->> 'fondateur') IS DISTINCT FROM v_moi THEN
      RAISE EXCEPTION 'parti_fondateur_usurpe' USING ERRCODE = '42501';
    END IF;
    IF EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_ap -> 'membres', '[]'::jsonb)) m
                WHERE m ->> 'nom' IS DISTINCT FROM v_moi) THEN
      RAISE EXCEPTION 'parti_fonde_avec_des_membres' USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  -- ---------------------------------------------------------------------------- LE CHEF DECIDE
  IF v_est_chef THEN
    RETURN NEW;   -- son parti, sa composition
  END IF;

  -- ---------------------------------------------------------------------------- LA DIRECTION
  -- Seule une election interne REELLEMENT en cours peut faire changer la direction sans que le
  -- chef l'ecrive -- c'est la resolution d'election, qui tourne dans le navigateur de n'importe
  -- quel joueur. Et le nouveau chef doit avoir ete DEJA membre : sans cela, on se couronnerait
  -- chef d'un parti ou l'on n'est pas, puis on s'y ajouterait au titre de chef.
  IF (v_ap ->> 'chef') IS DISTINCT FROM v_chef_avant THEN
    v_election := coalesce((v_av -> 'election' ->> 'enCours')::boolean, false)
                  AND (v_av -> 'election' ->> 'phase') = 'vote';
    IF NOT v_election THEN
      RAISE EXCEPTION 'parti_direction_non_autorisee' USING ERRCODE = '42501';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_av -> 'membres', '[]'::jsonb)) m
                    WHERE m ->> 'nom' = (v_ap ->> 'chef')) THEN
      RAISE EXCEPTION 'parti_direction_hors_du_parti' USING ERRCODE = '42501';
    END IF;
  END IF;

  -- ---------------------------------------------------------------------------- LES ADHESIONS
  -- CHAQUE NOM AJOUTE A LA LISTE DES MEMBRES est examine. C'est ici que l'attaque est fermee.
  FOR v_m IN
    SELECT m ->> 'nom' FROM jsonb_array_elements(coalesce(v_ap -> 'membres', '[]'::jsonb)) m
     WHERE NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_av -> 'membres', '[]'::jsonb)) a
                        WHERE a ->> 'nom' = m ->> 'nom')
  LOOP
    IF v_m = v_moi THEN
      -- ON NE S'INVITE PAS SOI-MEME : il faut que le chef l'ait fait, et la liste des invitations
      -- est gardee plus bas.
      IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_av -> 'invitationsEnvoyees', '[]'::jsonb)) i
                      WHERE i ->> 'nom' = v_moi) THEN
        RAISE EXCEPTION 'parti_adhesion_non_invitee' USING ERRCODE = '42501';
      END IF;
    ELSIF EXISTS (SELECT 1 FROM public.personnages_donnees pd WHERE pd.name = v_m) THEN
      -- UN AUTRE JOUEUR : seul le chef peut le faire entrer.
      RAISE EXCEPTION 'parti_adhesion_non_autorisee' USING ERRCODE = '42501';
    ELSE
      -- UN PNJ RECRUTE : permis a un membre du parti, jamais a un etranger.
      IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_av -> 'membres', '[]'::jsonb)) a
                      WHERE a ->> 'nom' = v_moi) THEN
        RAISE EXCEPTION 'parti_recrutement_hors_du_parti' USING ERRCODE = '42501';
      END IF;
    END IF;
  END LOOP;

  -- CHAQUE NOM RETIRE. On quitte un parti quand on veut ; on n'en exclut pas un autre.
  FOR v_m IN
    SELECT a ->> 'nom' FROM jsonb_array_elements(coalesce(v_av -> 'membres', '[]'::jsonb)) a
     WHERE NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_ap -> 'membres', '[]'::jsonb)) m
                        WHERE m ->> 'nom' = a ->> 'nom')
  LOOP
    IF v_m IS DISTINCT FROM v_moi THEN
      RAISE EXCEPTION 'parti_exclusion_non_autorisee' USING ERRCODE = '42501';
    END IF;
  END LOOP;

  -- ---------------------------------------------------------------------------- LES INVITATIONS
  -- LA PORTE DE L'ADHESION DE SOI-MEME. Si n'importe qui pouvait y poser son nom, le controle des
  -- adhesions ci-dessus ne vaudrait rien.
  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(coalesce(v_ap -> 'invitationsEnvoyees', '[]'::jsonb)) i
     WHERE NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_av -> 'invitationsEnvoyees', '[]'::jsonb)) j
                        WHERE j ->> 'nom' = i ->> 'nom')) THEN
    RAISE EXCEPTION 'parti_invitation_non_autorisee' USING ERRCODE = '42501';
  END IF;
  -- On refuse une invitation qui nous concerne ; on ne retire pas celle d'un autre.
  FOR v_m IN
    SELECT j ->> 'nom' FROM jsonb_array_elements(coalesce(v_av -> 'invitationsEnvoyees', '[]'::jsonb)) j
     WHERE NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_ap -> 'invitationsEnvoyees', '[]'::jsonb)) i
                        WHERE i ->> 'nom' = j ->> 'nom')
  LOOP
    IF v_m IS DISTINCT FROM v_moi THEN
      RAISE EXCEPTION 'parti_retrait_invitation_non_autorise' USING ERRCODE = '42501';
    END IF;
  END LOOP;

  -- ---------------------------------------------------------------------------- LES DEMANDES
  -- On demande pour soi, on retire sa propre demande. Le chef, lui, est passe bien plus haut.
  FOR v_m IN
    SELECT d ->> 'nom' FROM jsonb_array_elements(coalesce(v_ap -> 'demandesAdhesion', '[]'::jsonb)) d
     WHERE NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_av -> 'demandesAdhesion', '[]'::jsonb)) e
                        WHERE e ->> 'nom' = d ->> 'nom')
  LOOP
    IF v_m IS DISTINCT FROM v_moi THEN
      RAISE EXCEPTION 'parti_demande_pour_autrui' USING ERRCODE = '42501';
    END IF;
  END LOOP;

  RETURN NEW;
END;
$function$;

-- personnage_ajuster_pop_inf(text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.personnage_ajuster_pop_inf(p_cible text, p_pop integer, p_inf integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_res jsonb;
BEGIN
  IF COALESCE(btrim(p_cible), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide');
  END IF;
  IF COALESCE(abs(p_pop), 0) > 100 OR COALESCE(abs(p_inf), 0) > 100 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delta_invalide');
  END IF;
  UPDATE public.personnages
     SET resources = (
           CASE WHEN p_inf IS NULL THEN r.base
                ELSE jsonb_set(r.base, '{inf}', to_jsonb(GREATEST(0, LEAST(100,
                  COALESCE(CASE WHEN jsonb_typeof(r.base -> 'inf') = 'number' THEN (r.base ->> 'inf')::numeric END, 0) + p_inf))))
           END)
    FROM (SELECT jsonb_set(
            CASE WHEN jsonb_typeof(pp.resources) = 'object' THEN pp.resources ELSE '{}'::jsonb END,
            '{pop}', to_jsonb(GREATEST(0, LEAST(100,
              COALESCE(CASE WHEN jsonb_typeof(pp.resources -> 'pop') = 'number' THEN (pp.resources ->> 'pop')::numeric END, 50)
              + COALESCE(p_pop, 0))))) AS base
            FROM public.personnages pp WHERE pp.name = p_cible) r
   WHERE public.personnages.name = p_cible
   RETURNING public.personnages.resources INTO v_res;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
  END IF;
  RETURN jsonb_build_object('ok', true, 'pop', v_res -> 'pop', 'inf', v_res -> 'inf');
END;
$function$;

-- personnage_ajuster_pop_inf(text,text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.personnage_ajuster_pop_inf(p_acteur text, p_cible text, p_pop integer, p_inf integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_res jsonb; v_base jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);

  IF coalesce(btrim(p_cible), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide');
  END IF;
  IF coalesce(abs(p_pop), 0) > 100 OR coalesce(abs(p_inf), 0) > 100 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delta_invalide');
  END IF;

  SELECT jsonb_set(
           CASE WHEN jsonb_typeof(pp.resources) = 'object' THEN pp.resources ELSE '{}'::jsonb END,
           '{pop}', to_jsonb(greatest(0, least(100,
             coalesce(CASE WHEN jsonb_typeof(pp.resources -> 'pop') = 'number'
                           THEN (pp.resources ->> 'pop')::numeric END, 50)
             + coalesce(p_pop, 0)))))
    INTO v_base
    FROM public.personnages_donnees pp WHERE pp.name = p_cible FOR UPDATE;

  IF v_base IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
  END IF;

  UPDATE public.personnages_donnees
     SET resources = CASE WHEN p_inf IS NULL THEN v_base
            ELSE jsonb_set(v_base, '{inf}', to_jsonb(greatest(0, least(100,
                   coalesce(CASE WHEN jsonb_typeof(v_base -> 'inf') = 'number'
                                 THEN (v_base ->> 'inf')::numeric END, 0) + p_inf))))
          END
   WHERE name = p_cible
   RETURNING resources INTO v_res;

  RETURN jsonb_build_object('ok', true, 'pop', v_res -> 'pop', 'inf', v_res -> 'inf');
END;
$function$;

-- personnage_ajuster_pop_inf(text,text,integer,integer,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.personnage_ajuster_pop_inf(p_acteur text, p_cible text, p_pop integer, p_inf integer, p_cause text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_res jsonb; v_ecrit jsonb;
  v_poste text; v_pays text;
  v_min integer; v_max integer;
  v_pop_lue numeric; v_inf_lue numeric;
  v_pop_attendue numeric; v_inf_attendue numeric;
  v_serveur boolean := public.est_appel_serveur();
BEGIN
  IF NOT v_serveur THEN PERFORM public.exiger_acteur(p_acteur); END IF;

  IF coalesce(btrim(coalesce(p_cible,'')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide');
  END IF;

  -- Aucune mecanique du jeu ne modifie l'INF d'un AUTRE personnage aujourd'hui : l'influence
  -- d'une organisation est une autre jauge, portee par la table organisations. On refuse donc,
  -- plutot que de laisser une porte ouverte sans usage.
  IF p_inf IS NOT NULL AND NOT v_serveur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inf_sans_cause');
  END IF;

  SELECT pd.poste->>'id', pd.country INTO v_poste, v_pays
    FROM public.personnages_donnees pd WHERE pd.name = p_acteur;

  -- REGISTRE DES CAUSES. Chaque ligne = une mecanique reelle, son autorite et son amplitude.
  IF v_serveur THEN
    v_min := -100; v_max := 100;

  ELSIF p_cause = 'rumeur_pj' THEN
    -- Action grise ouverte a tout joueur. Perte tiree dans 5..20 (appliquerEffetRumeur).
    RETURN jsonb_build_object('ok', false, 'raison', 'cause_par_le_serveur', 'cause', p_cause); -- rumeur_lancer (27/10/2026)

  ELSIF p_cause = 'rumeur_gouvernement' THEN
    -- Meme action, cible gouvernementale. Perte tiree dans 1..5, appliquee a chaque titulaire.
    RETURN jsonb_build_object('ok', false, 'raison', 'cause_par_le_serveur', 'cause', p_cause); -- rumeur_lancer (27/10/2026)

  ELSIF p_cause = 'excommunication' THEN
    -- Reserve au Grand Pretre national en exercice. Le Grand Pretre n'est pas un poste porte par
    -- la fiche : c'est la ligne titulaires_pnj(pays, 'grand_pretre', NULL), que le client compare
    -- deja au nom du joueur (estGrandPretreActuel). Meme source de verite cote serveur.
    IF NOT EXISTS (SELECT 1 FROM public.titulaires_pnj t
                    WHERE t.poste_id = 'grand_pretre' AND t.city IS NULL
                      AND t.nom_pnj = p_acteur) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante',
                                'cause', p_cause, 'requis', 'grand_pretre');
    END IF;
    v_min := -15; v_max := -15;

  ELSIF p_cause IN ('dementi_reussi', 'dementi_rate') THEN
    -- Ordre « Dementi officiel » : requiresPost president (palais) ou min_info (ministere).
    IF v_poste IS NULL OR v_poste NOT IN ('president', 'min_info') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante',
                                'cause', p_cause, 'poste_reel', coalesce(v_poste,'(aucun)'));
    END IF;
    IF p_cause = 'dementi_reussi' THEN v_min := 1; v_max := 100;
    ELSE v_min := -100; v_max := -1; END IF;

  ELSIF p_cause = 'sentence_torture' THEN
    -- Ordre « Rendre la sentence » : requiresPost juge. -100 ramene la POP exactement a zero.
    IF v_poste IS DISTINCT FROM 'juge' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante',
                                'cause', p_cause, 'poste_reel', coalesce(v_poste,'(aucun)'));
    END IF;
    v_min := -100; v_max := -100;

  ELSIF p_cause IN ('assemblee_rappel', 'assemblee_sanction', 'assemblee_suspension_seance') THEN
    -- LA DISCIPLINE DE SEANCE (arbitrage du 11 octobre 2026). L'autorite n'est PAS lue sur la
    -- fiche : la presidence de l'Assemblee est un poste NOMME, et son seul point de verite est le
    -- registre `postes_attribues`, lu par `assemblee_president`.
    IF v_pays IS NULL OR public.assemblee_president(v_pays) IS DISTINCT FROM p_acteur THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante',
                                'cause', p_cause, 'requis', 'president_assemblee');
    END IF;
    -- UNE SUSPENSION VOLONTAIRE SE PAIE SOI-MEME. Le President ne peut pas faire porter son cout
    -- a un depute : la cause ne vise que lui.
    IF p_cause = 'assemblee_suspension_seance' AND p_cible IS DISTINCT FROM p_acteur THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_doit_etre_l_acteur', 'cause', p_cause);
    END IF;
    -- AMPLITUDE EXACTE, PAS UNE FOURCHETTE. 15 points pour un rappel, 20 pour une sanction, 20
    -- pour une suspension volontaire. Le registre refusera tout autre montant.
    IF p_cause = 'assemblee_rappel' THEN v_min := -15; v_max := -15;
    ELSE                                 v_min := -20; v_max := -20; END IF;

  ELSIF p_cause = 'football_match' THEN
    -- Gain de popularite d'un titulaire apres un match : +20 (participation) ou +30 (victoire).
    -- RESIDU ASSUME : le championnat n'a pas de moteur serveur, il avance depuis les navigateurs
    -- des joueurs. Aucun poste ne peut donc etre exige ici. L'amplitude est bornee aux deux
    -- seules valeurs declarees et le sens est POSITIF : le pire abus possible est d'elever la POP
    -- d'un personnage, jamais de l'abaisser. Fermeture definitive = moteur serveur du championnat.
    IF coalesce(p_pop,0) NOT IN (20, 30) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'delta_hors_cause',
                                'cause', p_cause, 'pop', p_pop);
    END IF;
    v_min := 20; v_max := 30;

  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'cause_non_declaree', 'cause', p_cause);
  END IF;

  IF coalesce(p_pop, 0) < v_min OR coalesce(p_pop, 0) > v_max THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delta_hors_cause',
                              'cause', p_cause, 'pop', p_pop, 'min', v_min, 'max', v_max);
  END IF;

  -- LA LECTURE SOUS VERROU. C'est la base qu'on va ANNONCER au trigger : 50 est la valeur par
  -- defaut d'une popularite jamais ecrite, comme partout ailleurs dans le jeu.
  SELECT coalesce(CASE WHEN jsonb_typeof(pp.resources -> 'pop') = 'number'
                       THEN (pp.resources ->> 'pop')::numeric END, 50),
         coalesce(CASE WHEN jsonb_typeof(pp.resources -> 'inf') = 'number'
                       THEN (pp.resources ->> 'inf')::numeric END, 0),
         CASE WHEN jsonb_typeof(pp.resources) = 'object' THEN pp.resources ELSE '{}'::jsonb END
    INTO v_pop_lue, v_inf_lue, v_ecrit
    FROM public.personnages_donnees pp WHERE pp.name = p_cible FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
  END IF;

  -- LE PROTOCOLE DU TRIGGER : on annonce la base lue, on ecrit la valeur voulue, et le trigger
  -- applique la DIFFERENCE a la valeur reelle du moment. Sans `popBase`, il restaurait l'ancienne
  -- valeur -- c'est le defaut que cette migration corrige. On n'ecrete pas ici : le trigger borne
  -- lui-meme entre 0 et 100, et ecreter deux fois ferait perdre le sens de la difference.
  v_ecrit := jsonb_set(v_ecrit, '{popBase}', to_jsonb(v_pop_lue));
  v_ecrit := jsonb_set(v_ecrit, '{pop}', to_jsonb(v_pop_lue + coalesce(p_pop, 0)));
  v_pop_attendue := greatest(0, least(100, v_pop_lue + coalesce(p_pop, 0)));

  IF p_inf IS NOT NULL THEN
    v_ecrit := jsonb_set(v_ecrit, '{infBase}', to_jsonb(v_inf_lue));
    v_ecrit := jsonb_set(v_ecrit, '{inf}', to_jsonb(v_inf_lue + p_inf));
    v_inf_attendue := greatest(0, least(100, v_inf_lue + p_inf));
  END IF;

  UPDATE public.personnages_donnees SET resources = v_ecrit
   WHERE name = p_cible
   RETURNING resources INTO v_res;

  -- ET ELLE NE MENT PLUS. Si la valeur rendue n'est pas celle attendue, un garde-fou a annule
  -- l'ecriture : on le DIT, au lieu de repondre « ok » comme avant. C'est exactement ce silence
  -- qui a permis a ce defaut de survivre.
  IF coalesce(CASE WHEN jsonb_typeof(v_res -> 'pop') = 'number'
                   THEN (v_res ->> 'pop')::numeric END, 50) IS DISTINCT FROM v_pop_attendue THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ecriture_annulee', 'cause', p_cause,
                              'attendue', v_pop_attendue, 'obtenue', v_res -> 'pop');
  END IF;
  IF p_inf IS NOT NULL
     AND coalesce(CASE WHEN jsonb_typeof(v_res -> 'inf') = 'number'
                       THEN (v_res ->> 'inf')::numeric END, 0) IS DISTINCT FROM v_inf_attendue THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ecriture_annulee', 'cause', p_cause,
                              'attendue_inf', v_inf_attendue, 'obtenue_inf', v_res -> 'inf');
  END IF;

  RETURN jsonb_build_object('ok', true, 'pop', v_res -> 'pop', 'inf', v_res -> 'inf',
                            'cause', p_cause);
END;
$function$;

-- personnage_pays_declare() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.personnage_pays_declare()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF coalesce(btrim(NEW.country), '') = '' THEN
    RAISE EXCEPTION 'pays_absent : un personnage doit appartenir a un empire declare';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.villes v WHERE v.pays = NEW.country) THEN
    RAISE EXCEPTION 'pays_non_declare : % n''est pas un empire du referentiel', NEW.country;
  END IF;
  RETURN NEW;
END;
$function$;

-- personnages_archiver_suppression() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.personnages_archiver_suppression()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_claims jsonb; v_role text;
BEGIN
  BEGIN
    v_claims := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  EXCEPTION WHEN others THEN v_claims := NULL;
  END;

  v_role := nullif(current_setting('role', true), 'none');
  IF v_role IS NULL OR v_role = '' THEN v_role := session_user; END IF;

  INSERT INTO public.personnages_supprimes
    (personnage_id, nom, user_id, ligne, chemin, origine,
     role_sql, session_sql, jwt_role, jwt_sub, application, client_addr,
     backend_pid, transaction_id, requete)
  VALUES (
    OLD.id, OLD.name, OLD.user_id, to_jsonb(OLD),
    CASE WHEN coalesce(current_setting('rp.suppression_via_vue', true), '') = '1'
         THEN 'vue' ELSE 'direct' END,
    nullif(current_setting('rp.suppression_origine', true), ''),
    v_role, session_user,
    v_claims ->> 'role', v_claims ->> 'sub',
    nullif(current_setting('application_name', true), ''),
    inet_client_addr(),
    pg_backend_pid(),
    txid_current()::text,
    left(coalesce(current_query(), ''), 2000));

  RETURN OLD;
END;
$function$;

-- personnages_attester_poste() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.personnages_attester_poste()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;

  IF TG_OP = 'INSERT' THEN
    IF NOT public.poste_est_atteste(NEW.name, NEW.poste, NEW.country) THEN
      NEW.poste := NULL;
    END IF;
    IF NOT public.poste_est_atteste(NEW.name, NEW.poste_depute, NEW.country) THEN
      NEW.poste_depute := NULL;
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.poste IS DISTINCT FROM OLD.poste
     AND NOT public.poste_est_atteste(NEW.name, NEW.poste, NEW.country) THEN
    NEW.poste := OLD.poste;
  END IF;
  IF NEW.poste_depute IS DISTINCT FROM OLD.poste_depute
     AND NOT public.poste_est_atteste(NEW.name, NEW.poste_depute, NEW.country) THEN
    NEW.poste_depute := OLD.poste_depute;
  END IF;
  RETURN NEW;
END;
$function$;
