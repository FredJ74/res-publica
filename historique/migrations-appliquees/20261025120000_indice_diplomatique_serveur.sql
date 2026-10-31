-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261025220648.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 25/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261025220648.
-- Eprouvee apres application en transaction annulee (bancs SQL du 25/10). Baseline NON reextrait.
-- ============================================================================
-- INDICE DIPLOMATIQUE : UN PAR PAYS, TENU PAR LE SERVEUR (decisions de Fred du 25 octobre 2026)
-- ============================================================================
-- « Dans le jeu, il ne doit y avoir qu'une seule realite, celle du serveur. Il faut donc le rendre
-- reel. » -- « Un indice par pays. Plus tard, nous verrons a quoi sert concretement cet indice. »
-- Avant : INDICES_NATIONAUX[pays].ID vivait dans la memoire du navigateur (data.js) ; chaque
-- joueur avait le sien, perdu au rechargement.
-- Desormais : une ligne par pays (valeurs de depart = celles de data.js), bornee a 0..100, que
-- seul le serveur modifie, avec un journal. Le navigateur la lit par indices_diplomatiques_lire().
-- Ce fichier pose aussi les actions de l'ambassadeur qui la font varier :
--   * ouvrir une ambassade : +8 (ambassade_ouvrir, deja serveur) ;
--   * reserver la Salle de Reception : par le serveur (le navigateur ecrivait la ligne) ;
--   * reception diplomatique AVEC PRESENCE (Fred) : +1 indice et +1 popularite de l'ambassadeur
--     par joueur du pays hote present dans la Salle de Reception (l'ambassadeur exclu), plafonds
--     +10 et +5 ; aucun invite : -3 et -3. 2 PA, 1 200 FR, salle reservee, une par reservation ;
--   * mecenat culturel : +3 indice, +8 popularite, 1 PA, 600 FR (effets inchanges).
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.indices_diplomatiques (
  pays   text PRIMARY KEY CHECK (pays IN ('republic', 'narco', 'soviet', 'khalija')),
  valeur integer NOT NULL CHECK (valeur BETWEEN 0 AND 100),
  maj_le timestamptz NOT NULL DEFAULT now()
);
INSERT INTO public.indices_diplomatiques (pays, valeur) VALUES
  ('republic', 40), ('narco', 20), ('soviet', 30), ('khalija', 50)
ON CONFLICT (pays) DO NOTHING;
ALTER TABLE public.indices_diplomatiques ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.indices_diplomatiques FROM anon, authenticated;

CREATE TABLE IF NOT EXISTS public.indices_diplomatiques_journal (
  id          bigserial PRIMARY KEY,
  pays        text NOT NULL,
  delta       integer NOT NULL,
  valeur_apres integer NOT NULL,
  cause       text NOT NULL,
  acteur      text,
  le          timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.indices_diplomatiques_journal ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.indices_diplomatiques_journal FROM anon, authenticated;

-- Seul point d'ecriture. Rend la nouvelle valeur (NULL si pays inconnu).
CREATE OR REPLACE FUNCTION public.indice_diplomatique_varier_interne(p_pays text, p_delta integer, p_cause text, p_acteur text DEFAULT NULL)
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
REVOKE ALL ON FUNCTION public.indice_diplomatique_varier_interne(text, integer, text, text) FROM PUBLIC, anon, authenticated;

-- Lecture publique pour l'affichage : { "republic": 40, ... }
CREATE OR REPLACE FUNCTION public.indices_diplomatiques_lire()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT jsonb_build_object('ok', true, 'indices', coalesce(jsonb_object_agg(pays, valeur), '{}'::jsonb))
    FROM public.indices_diplomatiques;
$function$;
REVOKE ALL ON FUNCTION public.indices_diplomatiques_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.indices_diplomatiques_lire() TO authenticated;

-- Ouvrir une ambassade : +8 pour le pays qui l'ouvre.
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
REVOKE ALL ON FUNCTION public.ambassade_ouvrir(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ambassade_ouvrir(text) TO authenticated;

-- L'ambassadeur en poste pour cet empire, sur place au Quartier des Ambassades.
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
REVOKE ALL ON FUNCTION public.ambassade_ambassadeur_interne(text) FROM PUBLIC, anon, authenticated;

-- Reserver la Salle de Reception pour aujourd'hui (jour de jeu du pays hote). 1 PA.
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
REVOKE ALL ON FUNCTION public.ambassade_reserver_salle(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ambassade_reserver_salle(text) TO authenticated;

-- La reservation ne s'ecrit plus depuis le navigateur.
DROP POLICY IF EXISTS "salle reservee par un ambassadeur accredite" ON public.reservations_salle_reception;
REVOKE INSERT, UPDATE, DELETE ON public.reservations_salle_reception FROM anon, authenticated;

-- Organiser la reception, avec presence.
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

  -- Les invites : les joueurs du pays hote presents dans la Salle de Reception, l'ambassadeur exclu.
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
  RETURN jsonb_build_object('ok', true, 'invites', v_invites, 'delta_indice', v_did, 'delta_pop', v_dpop,
                            'indice', v_indice, 'pop', v_pop -> 'pop', 'paie', v_paie);
END; $function$;
REVOKE ALL ON FUNCTION public.ambassade_reception_organiser(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ambassade_reception_organiser(text) TO authenticated;

-- Mecenat culturel : +3 indice, +8 popularite.
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
  RETURN jsonb_build_object('ok', true, 'indice', v_indice, 'pop', v_pop -> 'pop', 'paie', v_paie);
END; $function$;
REVOKE ALL ON FUNCTION public.ambassade_mecenat(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ambassade_mecenat(text) TO authenticated;

-- L'ordre « Corrompre un homologue local » est supprime (Fred : on ne code pas les interactions
-- humaines, comme la corruption entre joueurs).
DELETE FROM public.ordres_couts WHERE fn = 'corrompre_homologue_local';
