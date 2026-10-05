-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919173155
-- Nom original      : cellule_fin_evasion_alerte
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 17:31:55 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 9d933ef492adc6a1c7168de0a169f264
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LOT 5 — Alerte au Ministre proprietaire, fin de mission et evasion.
--
-- ARBITRAGE GD : la fin naturelle a J+10 suit EXACTEMENT la meme regle de
-- sortie que la fin volontaire. Il n'y a pas de cas « agent abandonne ».
-- Les deux chemins appellent donc la MEME routine ; seul `mode_fin` de la
-- cellule distingue le moment ('volontaire' / 'naturelle').
--
-- A toute fin de cellule :
--   agent libre survivant -> disparu
--   agent detenu          -> disparu, ET sa detention est CLOTUREE avec
--                            mode_fin = 'evasion' (valeur DEJA existante, deja
--                            rendue en rouge dans le registre carceral)
--   agent mort            -> reste mort
--   la memoire adverse    -> intacte, rien n'est supprime
--   l'historique          -> conserve, aucune ligne effacee

-- --------------------------------------------------------------------------
-- Alerte au Ministre de la Defense proprietaire. Il apprend QUE son agent est
-- arrete et SOUS QUELLE COUVERTURE -- jamais ce que l'adversaire a decouvert.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cellule_alerter_ministre(
  p_cellule_id text, p_couverture text, p_sujet text, p_corps text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_pays text; v_destinataire text;
BEGIN
  SELECT c.pays_proprietaire INTO v_pays
    FROM public.cellules_renseignement c WHERE c.id = p_cellule_id;
  IF v_pays IS NULL THEN RETURN; END IF;

  -- Titulaire reel du poste : un PJ s'il y en a un, sinon le PNJ du registre.
  SELECT d.name INTO v_destinataire FROM public.personnages_donnees d
   WHERE d.country = v_pays AND d.poste ->> 'id' = 'min_def' LIMIT 1;
  IF v_destinataire IS NULL THEN
    SELECT t.nom_pnj INTO v_destinataire FROM public.titulaires_pnj t
     WHERE t.country = v_pays AND t.poste_id = 'min_def' LIMIT 1;
  END IF;
  IF v_destinataire IS NULL THEN RETURN; END IF;

  INSERT INTO public.mails (id, from_player, to_player, subject, body, time, read)
  VALUES ('ce-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' ||
          substr(md5(random()::text), 1, 6),
          'Service de renseignement', v_destinataire, p_sujet, p_corps,
          to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'), false);
END;
$function$;

-- --------------------------------------------------------------------------
-- Routine de cloture COMMUNE aux deux fins.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cellule_renseignement_clore(
  p_cellule_id text, p_mode text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_statut text; v_evades integer := 0; v_disparus integer := 0; v_morts integer := 0;
BEGIN
  SELECT c.statut INTO v_statut FROM public.cellules_renseignement c
   WHERE c.id = p_cellule_id FOR UPDATE;
  IF v_statut IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cellule_introuvable');
  END IF;
  IF v_statut <> 'active' THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'cellule_deja_close');
  END IF;

  SELECT count(*) INTO v_morts FROM public.agents_renseignement
   WHERE cellule_id = p_cellule_id AND statut = 'mort';

  -- Agents DETENUS : la detention est CLOTUREE, jamais supprimee. Le registre
  -- affichera donc « Evasion », et l'histoire de la detention reste lisible.
  WITH detenus AS (
    SELECT id, detention_id FROM public.agents_renseignement
     WHERE cellule_id = p_cellule_id AND statut = 'detenu'
  ), fermeture AS (
    UPDATE public.detentions d
       SET mode_fin = 'evasion',
           jour_fin_effective = public.jour_de_jeu_pays(d.country),
           date_fin_effective = now()
      FROM detenus x
     WHERE d.id = x.detention_id AND d.mode_fin IS NULL
    RETURNING d.id
  )
  SELECT count(*) INTO v_evades FROM fermeture;

  UPDATE public.agents_renseignement
     SET statut = 'disparu', leader_courant = NULL,
         ville = NULL, building_id = NULL, room_id = NULL, maj_le = now()
   WHERE cellule_id = p_cellule_id AND statut IN ('actif', 'detenu');
  GET DIAGNOSTICS v_disparus = ROW_COUNT;

  UPDATE public.cellules_renseignement
     SET statut = CASE WHEN p_mode = 'echec_agents' THEN 'echec' ELSE 'terminee' END,
         mode_fin = p_mode, terminee_le = now()
   WHERE id = p_cellule_id;

  RETURN jsonb_build_object('ok', true, 'cellule', p_cellule_id, 'mode_fin', p_mode,
    'agents_disparus', v_disparus, 'evasions', v_evades, 'morts', v_morts);
END;
$function$;

-- --------------------------------------------------------------------------
-- Fin VOLONTAIRE : le ministre proprietaire renonce au temps restant.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cellule_renseignement_terminer(p_cellule_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text; v_poste text; v_pays text; v_proprio text;
BEGIN
  SELECT a.nom, a.poste_id, a.pays INTO v_nom, v_poste, v_pays
    FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF v_poste IS DISTINCT FROM 'min_def' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;
  SELECT c.pays_proprietaire INTO v_proprio
    FROM public.cellules_renseignement c WHERE c.id = p_cellule_id;
  IF v_proprio IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cellule_introuvable');
  END IF;
  IF v_proprio IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cellule_d_un_autre_empire');
  END IF;
  -- Aucun remboursement : le cout n'est jamais rendu.
  RETURN public.cellule_renseignement_clore(p_cellule_id, 'volontaire');
END;
$function$;

-- --------------------------------------------------------------------------
-- Fin NATURELLE a J+10, et echec quand les quatre agents sont morts. Pour le
-- cron (service_role uniquement).
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cellules_renseignement_balayer()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v_nat integer := 0; v_ech integer := 0;
BEGIN
  -- Echec : les quatre agents morts.
  FOR r IN SELECT c.id FROM public.cellules_renseignement c
            WHERE c.statut = 'active'
              AND NOT EXISTS (SELECT 1 FROM public.agents_renseignement a
                               WHERE a.cellule_id = c.id AND a.statut <> 'mort')
  LOOP
    PERFORM public.cellule_renseignement_clore(r.id, 'echec_agents');
    v_ech := v_ech + 1;
  END LOOP;

  -- Echeance atteinte.
  FOR r IN SELECT c.id FROM public.cellules_renseignement c
            WHERE c.statut = 'active' AND c.echeance_le <= now()
  LOOP
    PERFORM public.cellule_renseignement_clore(r.id, 'naturelle');
    v_nat := v_nat + 1;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'fins_naturelles', v_nat, 'echecs', v_ech);
END;
$function$;

-- --------------------------------------------------------------------------
-- Liberation des detentions PNJ arrivees a terme. Le cron historique pilote la
-- liberation depuis les FICHES de personnages : il ne verrait jamais un
-- detenu PNJ. Cette fonction couvre ce trou, sans toucher au chemin PJ.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.detentions_pnj_liberer_echues()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v_n integer := 0;
BEGIN
  FOR r IN
    SELECT d.id, d.country, a.id AS agent_id
      FROM public.detentions d
      JOIN public.agents_renseignement a ON a.detention_id = d.id
     WHERE d.provenance = 'agent_renseignement'
       AND d.mode_fin IS NULL
       AND d.jour_fin_effective IS NULL
       AND a.statut = 'detenu'
       AND a.detenu_depuis IS NOT NULL
       AND now() >= a.detenu_depuis + ((d.jour_fin - d.jour_debut) * interval '1 day')
  LOOP
    UPDATE public.detentions
       SET mode_fin = 'purgee', jour_fin_effective = public.jour_de_jeu_pays(r.country),
           date_fin_effective = now()
     WHERE id = r.id;
    UPDATE public.agents_renseignement
       SET statut = 'actif', detention_id = NULL, detenu_depuis = NULL, maj_le = now()
     WHERE id = r.agent_id;
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'liberations', v_n);
END;
$function$;

REVOKE ALL ON FUNCTION public.cellule_alerter_ministre(text,text,text,text)   FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.cellule_renseignement_clore(text,text)          FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.cellules_renseignement_balayer()                FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.detentions_pnj_liberer_echues()                 FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cellule_alerter_ministre(text,text,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.cellule_renseignement_clore(text,text)        TO service_role;
GRANT EXECUTE ON FUNCTION public.cellules_renseignement_balayer()              TO service_role;
GRANT EXECUTE ON FUNCTION public.detentions_pnj_liberer_echues()               TO service_role;

REVOKE ALL ON FUNCTION public.cellule_renseignement_terminer(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cellule_renseignement_terminer(text) TO authenticated, service_role;
