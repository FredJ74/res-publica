-- APPLIQUEE le 25/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261025194255.
-- ============================================================================
-- VIREMENTS ENTRE JOUEURS -- 2/2 : liste, arret, passe de nuit (suite de
-- 20261025080000_virements_joueurs.sql, decisions de Fred du 25 octobre 2026).
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

-- Ce que le joueur voit : les virements qu'il emet et ceux qu'il recoit, actifs.
CREATE OR REPLACE FUNCTION public.virements_automatiques_mes()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  RETURN jsonb_build_object('ok', true, 'virements', coalesce((
    SELECT jsonb_agg(jsonb_build_object('id', v.id, 'emetteur', v.emetteur, 'beneficiaire', v.beneficiaire,
             'montant', v.montant, 'frequence', v.frequence, 'prochain_le', v.prochain_le,
             'dernier_le', v.dernier_le, 'emis', v.emetteur = v_moi) ORDER BY v.cree_le)
      FROM public.virements_automatiques v
     WHERE v.actif AND (v.emetteur = v_moi OR v.beneficiaire = v_moi)), '[]'::jsonb));
END; $function$;
REVOKE ALL ON FUNCTION public.virements_automatiques_mes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.virements_automatiques_mes() TO authenticated;

-- Arret gratuit, par l'emetteur seul, de n'importe ou.
CREATE OR REPLACE FUNCTION public.virement_automatique_arreter(p_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  UPDATE public.virements_automatiques SET actif = false, arrete_le = now()
   WHERE id = p_id AND emetteur = v_moi AND actif RETURNING * INTO v;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'virement_introuvable'); END IF;
  PERFORM public.mail_systeme_poser_interne('Banque Nationale', v.beneficiaire, 'Virement automatique arrêté',
    '<strong>' || v.emetteur || '</strong> a arrêté le virement automatique de ' || v.montant || ' FR qu''il vous versait.<br><br>Laurent Barre, directeur d''agence');
  RETURN jsonb_build_object('ok', true);
END; $function$;
REVOKE ALL ON FUNCTION public.virement_automatique_arreter(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.virement_automatique_arreter(uuid) TO authenticated;

-- La passe de nuit (cron, service_role). Chaque echeance est traitee une fois : l'echeance avance
-- que le versement passe ou non (rien n'est verse ce jour-la si le compte ne suffit pas).
CREATE OR REPLACE FUNCTION public.virements_automatiques_executer()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v record; v_res jsonb; v_auj date := (now() AT TIME ZONE 'Europe/Paris')::date;
        v_ok integer := 0; v_ko integer := 0; v_freq text;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur'); END IF;
  FOR v IN SELECT * FROM public.virements_automatiques WHERE actif AND prochain_le <= v_auj
            ORDER BY prochain_le, cree_le FOR UPDATE SKIP LOCKED
  LOOP
    v_freq := CASE WHEN v.frequence = 'jour' THEN 'par jour' ELSE 'par semaine' END;
    IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v.emetteur)
       OR NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v.beneficiaire) THEN
      UPDATE public.virements_automatiques SET actif = false, arrete_le = now() WHERE id = v.id;
      CONTINUE;
    END IF;
    v_res := public.virement_executer_interne(v.emetteur, v.beneficiaire, v.montant);
    IF coalesce((v_res ->> 'ok')::boolean, false) THEN
      v_ok := v_ok + 1;
      UPDATE public.virements_automatiques SET dernier_le = v_auj,
             prochain_le = v_auj + CASE WHEN v.frequence = 'jour' THEN 1 ELSE 7 END WHERE id = v.id;
    ELSE
      v_ko := v_ko + 1;
      UPDATE public.virements_automatiques
         SET prochain_le = v_auj + CASE WHEN v.frequence = 'jour' THEN 1 ELSE 7 END WHERE id = v.id;
      PERFORM public.mail_systeme_poser_interne('Banque Nationale', v.emetteur, 'Virement automatique non versé',
        'Votre virement automatique de ' || v.montant || ' FR ' || v_freq || ' à <strong>' || v.beneficiaire
        || '</strong> n''a pas pu être versé : votre compte ne suffisait pas. Il reste actif.<br><br>Laurent Barre, directeur d''agence');
      PERFORM public.mail_systeme_poser_interne('Banque Nationale', v.beneficiaire, 'Virement automatique non versé',
        'Le virement automatique de ' || v.montant || ' FR ' || v_freq || ' que vous verse <strong>' || v.emetteur
        || '</strong> n''a pas pu être versé : son compte ne suffisait pas.<br><br>Laurent Barre, directeur d''agence');
    END IF;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'verses', v_ok, 'non_verses', v_ko);
END; $function$;
REVOKE ALL ON FUNCTION public.virements_automatiques_executer() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.virements_automatiques_executer() TO service_role;
