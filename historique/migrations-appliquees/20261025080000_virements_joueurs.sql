-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261025194235.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 25/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261025194235.
-- Eprouvee apres application en transaction annulee (refus sans cout, virement, nuit, rejeu, compte insuffisant). Baseline NON reextrait.
-- ============================================================================
-- VIREMENTS ENTRE JOUEURS -- 1/2 (GAME-DESIGN-BNE.md, la paie -- decisions de Fred du 25 octobre 2026)
-- ============================================================================
-- La paie d'un employe est MANUELLE : le jeu ne tient pas de contrat. Il facilite seulement le
-- virement. Valide par Fred :
--   - virement simple, a la Banque Nationale : du compte du joueur vers celui d'un autre joueur,
--     1 PA, un seul versement ; le destinataire sans compte en recoit un ;
--   - virement automatique, cree a la Banque Nationale pour 1 PA : beneficiaire, montant,
--     frequence quotidienne ou hebdomadaire ; verse la nuit par le serveur ;
--   - arret gratuit, depuis l'interface personnelle ;
--   - compte insuffisant une nuit : rien n'est verse ce jour-la, les deux joueurs recoivent un
--     mail, le virement reste actif.
-- Argent : de comptes_bancaires (banque 'nationale') a comptes_bancaires ; `arg` (fortune totale)
-- suit des deux cotes. Rien n'est cree ni detruit. Idempotente. Aucun acte de joueur.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.virements_automatiques (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  emetteur      text NOT NULL,
  beneficiaire  text NOT NULL,
  montant       integer NOT NULL CHECK (montant BETWEEN 1 AND 10000000),
  frequence     text NOT NULL CHECK (frequence IN ('jour', 'semaine')),
  actif         boolean NOT NULL DEFAULT true,
  cree_le       timestamptz NOT NULL DEFAULT now(),
  prochain_le   date NOT NULL,
  dernier_le    date,
  arrete_le     timestamptz,
  CHECK (emetteur <> beneficiaire)
);
CREATE INDEX IF NOT EXISTS virements_automatiques_echeances ON public.virements_automatiques (prochain_le) WHERE actif;
ALTER TABLE public.virements_automatiques ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.virements_automatiques FROM PUBLIC, anon, authenticated;

INSERT INTO public.ordres_couts (fn, pa, cost) VALUES
  ('virement_joueur', 1, 0), ('virement_automatique', 1, 0)
ON CONFLICT DO NOTHING;

-- Le mouvement d'argent, interne. Verrous dans un ordre fixe (nom croissant) : deux virements
-- croises ne s'interbloquent pas.
CREATE OR REPLACE FUNCTION public.virement_executer_interne(p_emetteur text, p_beneficiaire text, p_montant numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_solde numeric; v_compte text; v_pays_b text; v_compte_b text;
BEGIN
  IF p_montant IS NULL OR p_montant <= 0 OR p_montant <> trunc(p_montant) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;
  PERFORM 1 FROM public.personnages_donnees WHERE name IN (p_emetteur, p_beneficiaire) ORDER BY name FOR UPDATE;
  SELECT country INTO v_pays_b FROM public.personnages_donnees WHERE name = p_beneficiaire;
  IF v_pays_b IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'beneficiaire_introuvable'); END IF;
  SELECT id, coalesce(solde, 0) INTO v_compte, v_solde FROM public.comptes_bancaires
   WHERE personnage = p_emetteur AND banque = 'nationale' FOR UPDATE;
  IF v_compte IS NULL OR v_solde < p_montant THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'solde_insuffisant', 'solde', coalesce(v_solde, 0)); END IF;
  SELECT id INTO v_compte_b FROM public.comptes_bancaires
   WHERE personnage = p_beneficiaire AND banque = 'nationale' FOR UPDATE;
  IF v_compte_b IS NULL THEN
    v_compte_b := 'nationale_' || p_beneficiaire;
    INSERT INTO public.comptes_bancaires (id, personnage, pays, banque, solde, updated_at)
    VALUES (v_compte_b, p_beneficiaire, coalesce(v_pays_b, 'republic'), 'nationale', 0, now())
    ON CONFLICT (id) DO NOTHING;
  END IF;
  UPDATE public.comptes_bancaires SET solde = solde - p_montant, updated_at = now() WHERE id = v_compte;
  UPDATE public.comptes_bancaires SET solde = solde + p_montant, updated_at = now() WHERE id = v_compte_b;
  UPDATE public.personnages_donnees SET arg = coalesce(arg, 0) - p_montant, updated_at = now() WHERE name = p_emetteur;
  UPDATE public.personnages_donnees SET arg = coalesce(arg, 0) + p_montant, updated_at = now() WHERE name = p_beneficiaire;
  RETURN jsonb_build_object('ok', true, 'montant', p_montant, 'solde', v_solde - p_montant);
END; $function$;
REVOKE ALL ON FUNCTION public.virement_executer_interne(text, text, numeric) FROM PUBLIC, anon, authenticated;

-- Virement simple, a la Banque Nationale. 1 PA ; un refus ne coute rien (sous-bloc).
CREATE OR REPLACE FUNCTION public.banque_virement(p_beneficiaire text, p_montant integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_bat text; v_paie jsonb; v_res jsonb; v_b text := btrim(coalesce(p_beneficiaire, ''));
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT current_building INTO v_bat FROM public.personnages_donnees WHERE name = v_moi;
  IF v_bat IS DISTINCT FROM 'banque-nationale' THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF v_b = v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'beneficiaire_invalide'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_b) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'beneficiaire_introuvable'); END IF;
  IF p_montant IS NULL OR p_montant <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;
  BEGIN
    v_paie := public.payer_ordre(v_moi, 'virement_joueur', 1, 0);
    IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
    v_res := public.virement_executer_interne(v_moi, v_b, p_montant);
    IF coalesce((v_res ->> 'ok')::boolean, false) IS NOT TRUE THEN
      RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'hg_virement_refuse';
    END IF;
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM = 'hg_virement_refuse' THEN RETURN v_res; END IF;
    RAISE;
  END;
  PERFORM public.mail_systeme_poser_interne('Banque Nationale', v_b, 'Virement reçu',
    '<strong>' || v_moi || '</strong> vous a viré <strong>' || p_montant || ' FR</strong> sur votre compte de la Banque Nationale.<br><br>Laurent Barre, directeur d''agence');
  RETURN jsonb_build_object('ok', true, 'montant', p_montant, 'beneficiaire', v_b,
                            'pa', v_paie -> 'pa', 'solde_national', v_res -> 'solde',
                            'arg', (SELECT arg FROM public.personnages_donnees WHERE name = v_moi));
END; $function$;
REVOKE ALL ON FUNCTION public.banque_virement(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.banque_virement(text, integer) TO authenticated;

-- Virement automatique, cree a la Banque Nationale. 1 PA. Premier versement : la nuit suivante.
CREATE OR REPLACE FUNCTION public.banque_virement_automatique_creer(p_beneficiaire text, p_montant integer, p_frequence text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_bat text; v_paie jsonb; v_id uuid; v_b text := btrim(coalesce(p_beneficiaire, ''));
        v_demain date := ((now() AT TIME ZONE 'Europe/Paris')::date + 1);
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT current_building INTO v_bat FROM public.personnages_donnees WHERE name = v_moi;
  IF v_bat IS DISTINCT FROM 'banque-nationale' THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF v_b = v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'beneficiaire_invalide'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_b) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'beneficiaire_introuvable'); END IF;
  IF p_montant IS NULL OR p_montant NOT BETWEEN 1 AND 10000000 THEN RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;
  IF p_frequence NOT IN ('jour', 'semaine') THEN RETURN jsonb_build_object('ok', false, 'raison', 'frequence_invalide'); END IF;
  v_paie := public.payer_ordre(v_moi, 'virement_automatique', 1, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  INSERT INTO public.virements_automatiques (emetteur, beneficiaire, montant, frequence, prochain_le)
  VALUES (v_moi, v_b, p_montant, p_frequence, v_demain) RETURNING id INTO v_id;
  PERFORM public.mail_systeme_poser_interne('Banque Nationale', v_b, 'Virement automatique mis en place',
    '<strong>' || v_moi || '</strong> a mis en place un virement automatique de <strong>' || p_montant || ' FR</strong> '
    || CASE WHEN p_frequence = 'jour' THEN 'par jour' ELSE 'par semaine' END
    || ' en votre faveur. Premier versement dans la nuit.<br><br>Laurent Barre, directeur d''agence');
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'prochain_le', v_demain, 'pa', v_paie -> 'pa');
END; $function$;
REVOKE ALL ON FUNCTION public.banque_virement_automatique_creer(text, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.banque_virement_automatique_creer(text, integer, text) TO authenticated;

