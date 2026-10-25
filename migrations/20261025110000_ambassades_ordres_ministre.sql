-- APPLIQUEE le 25/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261025210049.
-- Eprouvee apres application en transaction annulee (autorite, ouverture, doublon, nomination, demission, expulsion). Baseline NON reextrait.
-- ============================================================================
-- AMBASSADES : LES QUATRE ACTIONS DU MINISTRE DES AFFAIRES ETRANGERES PAR LE SERVEUR
-- (25 octobre 2026 ; AUDIT_AMBASSADES.md R5, R6, R9 ; regle de Fred : une seule realite)
-- ============================================================================
-- Ouvrir une ambassade, nommer et demettre son ambassadeur, expulser un ambassadeur etranger.
-- Avant : le navigateur prelevait les PA, ecrivait la ligne sans lire la reponse, annoncait le
-- succes et notifiait quoi qu'il arrive (R5) ; l'echeance d'expulsion venait de son horloge (R6) ;
-- le message promettait une arrestation qui n'existe pas (R9).
-- Desormais chaque action verifie l'autorite (ministre AE du pays concerne), l'etat de la ligne,
-- preleve 2 PA (cout declare de « Ambassades et ambassadeurs ») dans la meme transaction, ecrit,
-- et previent l'interesse. Un refus ne coute rien. L'echeance d'expulsion est posee par le
-- serveur (24 h) ; la passe de nuit existante met fin a la mission a l'echeance.
-- L'ARRESTATION DE L'EXPULSE (decision du 15 juillet, 3 jours) suppose de savoir s'il est encore
-- dans le pays : le voyage entre empires n'existe pas encore, elle sera branchee avec lui.
-- Conventions existantes conservees : id = pays_hote || '-' || empire ; data.ambassadeur ;
-- data.expulsionEcheance en millisecondes (lu par traiterExpulsionsAmbassadeursServeur).
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

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
REVOKE ALL ON FUNCTION public.ambassade_ministre_interne() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.ambassade_ouvrir(p_pays_hote text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE m jsonb; v_pays text; v_paie jsonb; v_id text;
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
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'pa', v_paie -> 'pa');
END; $function$;
REVOKE ALL ON FUNCTION public.ambassade_ouvrir(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ambassade_ouvrir(text) TO authenticated;

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
REVOKE ALL ON FUNCTION public.ambassade_nommer(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ambassade_nommer(text, text) TO authenticated;

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
REVOKE ALL ON FUNCTION public.ambassade_demettre(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ambassade_demettre(text) TO authenticated;

-- Expulser l'ambassadeur d'un autre empire en poste dans MON pays. 24 h, a l'heure du serveur.
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
REVOKE ALL ON FUNCTION public.ambassade_expulser(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ambassade_expulser(text) TO authenticated;
