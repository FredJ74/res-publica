-- ============================================================================
-- CAISSES : PLUS DE CREATION D'ARGENT SUR DEMANDE DU NAVIGATEUR (26 octobre 2026)
-- ============================================================================
-- AUDIT_UNE_SEULE_VERITE.md §1.2. Trois portes laissaient un joueur connecte crediter une caisse
-- d'un montant de son choix, sans que cet argent existe nulle part :
--   * caisse_institution_mouvement et sa variante plafonnee : un credit (montant positif) ne
--     passait par aucune autorite, sur n'importe quelle caisse d'institution ;
--   * caisse_client_mouvement : un credit vers une caisse de son pays passait sans controle ;
--   * batiment_caisse_mouvement : tout montant, dans les deux sens, sur toute caisse de batiment.
--
-- LA REGLE : un credit demande par le navigateur ne peut verser que de l'argent qui vient de
-- quitter reellement quelqu'un. Le serveur tient un registre des FONDS EN TRANSIT, par joueur :
--   * quand le joueur paie un ordre (payer_ordre appele par son navigateur), le montant y entre ;
--   * quand il debite une caisse avec autorite (caisse_client_mouvement), le montant y entre ;
--   * un credit demande par son navigateur doit les consommer ; sinon il est refuse et journalise.
-- Les fonds en transit expirent apres 15 minutes. Les fonctions du serveur qui creditent une caisse
-- dans la meme transaction que le paiement (la plupart) ne passent pas par ce registre.
--
-- Les deux virements entre une usine et le ministere des Finances, et la vente de bois a une
-- imprimerie, passent desormais entierement par le serveur (une seule transaction) :
--   * usine_virer_vers_ministere : le directeur de l'usine, 1 PA ;
--   * ministere_virer_vers_usine : le Ministre des Finances, 1 PA (ordre de facade
--     « Gestion industrielle et portuaire ») ;
--   * imprimerie_acheter_bois : le vendeur sur place, 0 PA ; prix = cours de reference du bois
--     + 10 % (5 FR -> 5,50 FR, comme l'ecran) ; plafond de 10 bois en stock (imprimerie PNJ).
--     Avant, la caisse etait debitee par le serveur mais l'argent n'arrivait au vendeur que sur
--     l'ecran (il disparaissait au rechargement) et le bois ne quittait pas son inventaire reel.
-- Les primitives heritees sont retirees au navigateur ; il passe par
-- batiment_caisse_client_crediter pour les recettes de redaction.
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.fonds_en_transit (
  id       bigserial PRIMARY KEY,
  acteur   text NOT NULL,
  montant  numeric NOT NULL CHECK (montant >= 0),
  origine  text NOT NULL,
  cree_le  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS fonds_en_transit_acteur ON public.fonds_en_transit (acteur, cree_le);
ALTER TABLE public.fonds_en_transit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.fonds_en_transit FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.fonds_transit_deposer_interne(p_acteur text, p_montant numeric, p_origine text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF p_acteur IS NULL OR coalesce(p_montant, 0) <= 0 THEN RETURN; END IF;
  DELETE FROM public.fonds_en_transit WHERE acteur = p_acteur AND cree_le < now() - interval '15 minutes';
  INSERT INTO public.fonds_en_transit (acteur, montant, origine) VALUES (p_acteur, p_montant, coalesce(p_origine, '?'));
END; $function$;
REVOKE ALL ON FUNCTION public.fonds_transit_deposer_interne(text, numeric, text) FROM PUBLIC, anon, authenticated;

-- Consomme p_montant des fonds en transit du joueur (les plus anciens d'abord). Tout ou rien.
CREATE OR REPLACE FUNCTION public.fonds_transit_consommer_interne(p_acteur text, p_montant numeric)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_dispo numeric; v_reste numeric := p_montant; r record;
BEGIN
  IF p_acteur IS NULL OR coalesce(p_montant, 0) <= 0 THEN RETURN false; END IF;
  SELECT coalesce(sum(montant), 0) INTO v_dispo FROM public.fonds_en_transit
   WHERE acteur = p_acteur AND cree_le >= now() - interval '15 minutes';
  IF v_dispo < p_montant THEN RETURN false; END IF;
  FOR r IN SELECT id, montant FROM public.fonds_en_transit
            WHERE acteur = p_acteur AND cree_le >= now() - interval '15 minutes'
            ORDER BY id FOR UPDATE LOOP
    EXIT WHEN v_reste <= 0;
    IF r.montant <= v_reste THEN
      DELETE FROM public.fonds_en_transit WHERE id = r.id; v_reste := v_reste - r.montant;
    ELSE
      UPDATE public.fonds_en_transit SET montant = montant - v_reste WHERE id = r.id; v_reste := 0;
    END IF;
  END LOOP;
  RETURN true;
END; $function$;
REVOKE ALL ON FUNCTION public.fonds_transit_consommer_interne(text, numeric) FROM PUBLIC, anon, authenticated;

-- payer_ordre : un paiement fait par le navigateur alimente les fonds en transit du joueur.
DO $mig$
DECLARE v_def text; v_new text;
  v_frag text := E'  RETURN jsonb_build_object(\n    ''ok'', true, ''pa'', v_pa - coalesce(p_pa,0),';
  v_ajout text := E'  -- FONDS EN TRANSIT (26/10/2026) : ce que le navigateur vient de payer pourra etre verse a une\n  -- caisse par lui, et rien d''autre. Seulement pour un paiement demande directement par le navigateur.\n  IF coalesce(p_cost, 0) > 0 AND coalesce(current_setting(''request.path'', true), '''') = ''/rpc/payer_ordre'' THEN\n    PERFORM public.fonds_transit_deposer_interne(p_acteur, p_cost, ''ordre:'' || v_fn);\n  END IF;\n\n';
BEGIN
  v_def := pg_get_functiondef('public.payer_ordre(text,text,integer,integer)'::regprocedure);
  IF position('fonds_transit_deposer_interne' in v_def) > 0 THEN RETURN; END IF;
  v_new := replace(v_def, v_frag, v_ajout || v_frag);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch non applique : payer_ordre'; END IF;
  EXECUTE v_new;
END $mig$;

-- caisse_client_mouvement : un debit autorise alimente les fonds en transit ; un credit les consomme.
CREATE OR REPLACE FUNCTION public.caisse_client_mouvement(p_caisse text, p_delta numeric, p_motif text DEFAULT NULL::text, p_plafonne boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_existe boolean; v_solde numeric; v_verse numeric; v_res jsonb; v_raison text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF coalesce(btrim(p_caisse),'') = '' OR p_delta IS NULL OR p_delta = 0 OR abs(p_delta) > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  IF v_pays IS NULL OR p_caisse NOT LIKE v_pays || '\_%' THEN
    v_raison := 'caisse_hors_pays';
  ELSE
    SELECT true, (data->>'solde')::numeric INTO v_existe, v_solde FROM public.caisses_batiments WHERE id = p_caisse;
    IF NOT coalesce(v_existe, false) THEN v_raison := 'caisse_inexistante';
    ELSIF p_delta < 0 OR p_plafonne THEN v_raison := public.caisse_refus_autorite(p_caisse, v_pays);
    -- CREDIT : seulement ce que le joueur vient reellement de payer ou de prelever (26/10/2026).
    ELSIF NOT public.fonds_transit_consommer_interne(v_moi, p_delta) THEN v_raison := 'credit_non_adosse';
    END IF;
  END IF;
  IF v_raison IS NOT NULL THEN
    INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
    VALUES (v_moi, p_caisse, p_delta, p_motif, false, v_raison);
    RETURN jsonb_build_object('ok', false, 'raison', v_raison);
  END IF;
  IF p_plafonne THEN
    v_verse := least(greatest(coalesce(v_solde,0), 0), abs(p_delta));
    IF v_verse <= 0 THEN
      INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
      VALUES (v_moi, p_caisse, p_delta, p_motif, false, 'solde_nul');
      RETURN jsonb_build_object('ok', true, 'verse', 0, 'solde', coalesce(v_solde,0));
    END IF;
    v_res := public.caisse_institution_mouvement(p_caisse, -v_verse, true);
    INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
    VALUES (v_moi, p_caisse, -v_verse, p_motif, coalesce((v_res->>'ok')::boolean,false), v_res->>'raison');
    IF coalesce((v_res->>'ok')::boolean, false) THEN
      PERFORM public.fonds_transit_deposer_interne(v_moi, v_verse, 'caisse:' || p_caisse);
      RETURN jsonb_build_object('ok', true, 'verse', v_verse, 'solde', (SELECT (data->>'solde')::numeric FROM public.caisses_batiments WHERE id = p_caisse));
    END IF;
    RETURN jsonb_build_object('ok', false, 'raison', v_res->>'raison', 'verse', 0);
  END IF;
  v_res := public.caisse_institution_mouvement(p_caisse, p_delta, true);
  INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
  VALUES (v_moi, p_caisse, p_delta, p_motif, coalesce((v_res->>'ok')::boolean,false), v_res->>'raison');
  IF coalesce((v_res->>'ok')::boolean, false) THEN
    IF p_delta < 0 THEN PERFORM public.fonds_transit_deposer_interne(v_moi, -p_delta, 'caisse:' || p_caisse); END IF;
    RETURN jsonb_build_object('ok', true, 'solde', (SELECT (data->>'solde')::numeric FROM public.caisses_batiments WHERE id = p_caisse));
  END IF;
  -- Credit refuse par la primitive : on rend les fonds consommes.
  IF p_delta > 0 THEN PERFORM public.fonds_transit_deposer_interne(v_moi, p_delta, 'rendu:' || p_caisse); END IF;
  RETURN v_res;
END; $function$;
REVOKE ALL ON FUNCTION public.caisse_client_mouvement(text, numeric, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.caisse_client_mouvement(text, numeric, text, boolean) TO authenticated;

