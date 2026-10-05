-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919173220
-- Nom original      : arrestation_agent_alerte_ministre
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 17:32:20 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 71ee44a9152592c5b51911efdcd29d33
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
-- Branche l'alerte immediate au Ministre de la Defense proprietaire sur
-- l'arrestation reelle d'un de ses agents. Le message dit QUE l'agent est
-- arrete et SOUS QUELLE COUVERTURE -- jamais ce que l'Etat adverse a decouvert
-- lors de son enquete, ni le niveau atteint.
CREATE OR REPLACE FUNCTION public.detention_ouvrir_interne(
  p_nom text, p_raison text, p_jours integer, p_city text, p_country text,
  p_motifs jsonb, p_autorite text, p_issue text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id         text := 'det-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' ||
                       substr(md5(random()::text), 1, 6);
  v_jour_cible integer;
  v_deja       jsonb;
  v_pnj        record;
  v_cellule    text;
BEGIN
  SELECT coalesce(d.day, 1), d.est_emprisonne INTO v_jour_cible, v_deja
    FROM public.personnages_donnees d WHERE d.name = p_nom FOR UPDATE;

  IF NOT FOUND THEN
    SELECT * INTO v_pnj FROM public.detention_cible_pnj(p_nom, p_country);
    IF v_pnj.systeme IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
    END IF;
    IF v_pnj.statut = 'detenu' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_deja_detenue');
    END IF;
    IF NOT v_pnj.arretable THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_non_arretable',
                                'niveau_connu', v_pnj.niveau_connu, 'niveau_requis', 2);
    END IF;

    v_jour_cible := public.jour_de_jeu_pays(p_country);
    INSERT INTO public.detentions (id, country, city, nom, raison, jour_debut, jour_fin, qhs,
                                   motifs, autorite, issue_judiciaire, ville_condamnation, provenance)
    VALUES (v_id, p_country, p_city, p_nom, p_raison, v_jour_cible, v_jour_cible + p_jours, false,
            p_motifs, p_autorite, p_issue, p_city, v_pnj.systeme);

    UPDATE public.agents_renseignement
       SET statut = 'detenu', detention_id = v_id, detenu_depuis = now(),
           leader_courant = NULL, maj_le = now()
     WHERE id = v_pnj.agent_id
    RETURNING cellule_id INTO v_cellule;

    PERFORM public.cellule_alerter_ministre(v_cellule, p_nom,
      'Agent arrete — ' || p_nom,
      'Votre agent operant sous l''identite de couverture « ' || p_nom ||
      ' » a ete arrete par les autorites de ' || p_country || ' a ' || p_city ||
      '. Il ne peut plus collecter ni etre deplace.');

    RETURN jsonb_build_object('ok', true, 'detention_id', v_id,
                              'jour_debut', v_jour_cible, 'jour_fin', v_jour_cible + p_jours,
                              'provenance', v_pnj.systeme);
  END IF;

  -- ---- Branche PJ : strictement le code historique. ----
  IF v_deja IS NOT NULL AND jsonb_typeof(v_deja) = 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_deja_detenue');
  END IF;

  INSERT INTO public.detentions (id, country, city, nom, raison, jour_debut, jour_fin, qhs,
                                 motifs, autorite, issue_judiciaire, ville_condamnation)
  VALUES (v_id, p_country, p_city, p_nom, p_raison, v_jour_cible, v_jour_cible + p_jours, false,
          p_motifs, p_autorite, p_issue, p_city);

  UPDATE public.personnages_donnees
     SET est_emprisonne = jsonb_build_object(
           'jours', p_jours, 'jourFin', v_jour_cible + p_jours, 'raison', p_raison,
           'detentionId', v_id, 'qhs', false, 'city', p_city, 'country', p_country,
           'debutTs', (extract(epoch from clock_timestamp())*1000)::bigint)
   WHERE name = p_nom;

  RETURN jsonb_build_object('ok', true, 'detention_id', v_id,
                            'jour_debut', v_jour_cible, 'jour_fin', v_jour_cible + p_jours);
END;
$function$;
