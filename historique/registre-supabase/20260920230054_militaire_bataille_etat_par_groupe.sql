-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920230054
-- Nom original      : militaire_bataille_etat_par_groupe
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-20 23:00:54 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : ab044299d9e9d0fdb65a5f28e2af0621
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
-- L'ecran de combat doit savoir si une decision est attendue de CE joueur,
-- pour SON groupe, et combien de secondes il lui reste. La doctrine de camp
-- disparait de la reponse : elle n'existe plus.
CREATE OR REPLACE FUNCTION public.militaire_bataille_etat(p_bataille_id bigint DEFAULT NULL::bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE
  v_moi text; v_id bigint; b record; g record; v_camp text; v_reste integer;
  v_rounds jsonb; v_hostiles text[]; v_secondes integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  IF p_bataille_id IS NULL THEN
    SELECT e.bataille_id INTO v_id FROM public.batailles_engagements e
      JOIN public.batailles bb ON bb.id = e.bataille_id
     WHERE e.personnage = v_moi AND bb.statut = 'en_cours'
     ORDER BY bb.debut_ts DESC LIMIT 1;
    IF v_id IS NULL THEN RETURN jsonb_build_object('ok', true, 'bataille', NULL); END IF;
  ELSE
    v_id := p_bataille_id;
  END IF;

  SELECT * INTO b FROM public.batailles WHERE id = v_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'bataille_introuvable'); END IF;

  v_camp := public.militaire_bataille_mon_camp(v_id, v_moi);
  IF v_camp IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'non_engage'); END IF;

  -- Mon groupe : celui ou je suis engage.
  SELECT gg.* INTO g FROM public.batailles_groupes gg
    JOIN public.batailles_engagements e
      ON e.bataille_id = gg.bataille_id AND e.groupe_id = gg.groupe_id
   WHERE gg.bataille_id = v_id AND e.personnage = v_moi LIMIT 1;

  v_hostiles := public.militaire_camps_hostiles(v_id, v_camp);
  SELECT count(*) INTO v_reste FROM public.militaire_bataille_combattants(v_id, v_camp);
  SELECT coalesce(jsonb_agg(r.rapport ORDER BY r.numero), '[]'::jsonb) INTO v_rounds
    FROM public.batailles_rounds r WHERE r.bataille_id = v_id AND r.camp = v_camp;

  v_secondes := CASE WHEN g.attente_depuis IS NULL THEN NULL
    ELSE greatest(0, 90 - extract(epoch FROM now() - g.attente_depuis))::integer END;

  RETURN jsonb_build_object('ok', true, 'bataille', jsonb_build_object(
    'id', b.id, 'statut', b.statut, 'round_courant', b.round_courant,
    'lieu', jsonb_build_object('ville', b.ville, 'batiment', b.batiment, 'piece', b.piece),
    'mon_camp', v_camp, 'camps_adverses', v_hostiles,
    'camp_adverse', coalesce(v_hostiles[1], '—'),
    'mon_effectif_actuel', v_reste,
    -- Mon groupe, unite de decision
    'mon_groupe', g.groupe_id,
    'mon_groupe_effectif_initial', g.effectif_initial,
    'mon_groupe_restants', (SELECT count(*) FROM public.batailles_engagements e2
                             WHERE e2.bataille_id = v_id AND e2.groupe_id = g.groupe_id
                               AND e2.sorti_round IS NULL),
    'mon_effectif_initial', g.effectif_initial,
    'je_suis_leader', (g.leader IS NOT NULL AND g.leader = v_moi),
    'mon_chef', g.leader,
    'decision_attendue', (g.attente_depuis IS NOT NULL AND g.decision IS NULL),
    'secondes_restantes', v_secondes,
    'ma_decision', g.decision,
    'mon_groupe_replie', (g.sorti_round IS NOT NULL),
    'issue', b.issue, 'rounds', v_rounds));
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_etat(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_bataille_etat(bigint) TO authenticated, service_role;