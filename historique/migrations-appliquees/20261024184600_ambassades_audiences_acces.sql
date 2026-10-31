-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261024185346.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 24/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261024185346.
-- Eprouvee avant application en transaction annulee : 14 cas joueur PNJ + 4 cas ambassadeur joueur.
-- Droits verifies apres coup : aucune fonction pour anon ; table fermee a anon et authenticated.
-- Baseline NON reextrait (comme les autres migrations de ce repertoire) : a faire au prochain
-- passage de reextraction (WORKFLOW-SUPABASE.md, etape 5).
-- ============================================================================
-- AUDIENCES AUPRES DES AMBASSADEURS -- 2/2 : lecture, acces aux bureaux, accord par un
-- joueur ambassadeur, passe de nuit. Depend de 20261024184500_ambassades_audiences.sql.
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- MES AUDIENCES : constate les echeances, puis rend ce que l'ecran peut afficher.
-- L'echeance prevue d'une demande n'est JAMAIS rendue.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.ambassade_mes_audiences()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_liste jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  PERFORM public.ambassades_audiences_echoir(v_moi);
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'empire', a.empire, 'statut', a.statut,
           'ambassadeur', public.ambassade_identite(a.empire) ->> 'ambassadeur',
           'demandee_le', a.demandee_le, 'accordee_le', a.accordee_le, 'expire_le', a.expire_le)
         ORDER BY a.demandee_le), '[]'::jsonb)
    INTO v_liste
    FROM public.ambassades_audiences a
   WHERE a.demandeur = v_moi AND a.statut IN ('demandee','accordee');
  RETURN jsonb_build_object('ok', true, 'audiences', v_liste,
    'en_attente', (SELECT count(*) FROM jsonb_array_elements(v_liste) e WHERE e ->> 'statut' = 'demandee'));
END; $function$;
REVOKE ALL ON FUNCTION public.ambassade_mes_audiences() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ambassade_mes_audiences() TO authenticated;

-- ---------------------------------------------------------------------------
-- ACCES A UN BUREAU D'AMBASSADEUR : decide ici, jamais par l'ecran.
-- ---------------------------------------------------------------------------
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

  -- Le joueur ambassadeur en poste entre dans son propre bureau.
  IF EXISTS (SELECT 1 FROM public.ambassades_ouvertes a
              WHERE a.pays_hote = v_pays AND a.empire = p_empire
                AND a.data ->> 'ambassadeur' = v_moi) THEN
    RETURN jsonb_build_object('ok', true, 'motif', 'ambassadeur');
  END IF;

  PERFORM public.ambassades_audiences_echoir(v_moi);
  SELECT expire_le INTO v_expire FROM public.ambassades_audiences
   WHERE demandeur = v_moi AND empire = p_empire AND statut = 'accordee' AND expire_le > now();
  IF v_expire IS NOT NULL THEN
    RETURN jsonb_build_object('ok', true, 'motif', 'audience', 'expire_le', v_expire);
  END IF;
  RETURN jsonb_build_object('ok', false, 'raison', 'sur_audience');
END; $function$;
REVOKE ALL ON FUNCTION public.ambassade_acces_bureau(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ambassade_acces_bureau(text) TO authenticated;

-- ---------------------------------------------------------------------------
-- L'AMBASSADEUR JOUEUR ACCORDE UNE AUDIENCE (bouton de son mail).
-- ---------------------------------------------------------------------------
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
REVOKE ALL ON FUNCTION public.ambassade_accorder_audience(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ambassade_accorder_audience(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- PASSE DE NUIT : constate les echeances des joueurs absents. Serveur seulement.
-- ---------------------------------------------------------------------------
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
  RETURN jsonb_build_object('ok', true, 'accordees', public.ambassades_audiences_echoir(NULL));
END; $function$;
REVOKE ALL ON FUNCTION public.ambassades_audiences_echoir_toutes() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ambassades_audiences_echoir_toutes() TO service_role;
