-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913132351
-- Nom original      : chantier_b_autorite_institutionnelle_et_pouvoirs_judiciaires
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 13:23:51 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 976891228167d87834dcd7f5a993b4eb
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
-- ============================================================================
-- CHANTIER B — POUVOIRS INSTITUTIONNELS : L'AUTORITE SE VERIFIE AU SERVEUR
-- 13 septembre 2026.
-- ============================================================================
-- Le durcissement RLS a rendu inoperantes deux actions legitimes qui ecrivaient
-- directement sur la ligne d'autrui : la prolongation de peine prononcee par un
-- juge, et la grace presidentielle. On ne rouvre PAS cette ecriture directe : on
-- la deplace derriere des RPC qui verifient l'autorite reelle de l'appelant.
--
-- AUCUNE REGLE INVENTEE. Les deux regles existent deja, en toutes lettres :
--   * rendre_sentence porte requiresPost:'juge' (data.js:3972) ;
--   * confirmerGrace s'ouvre sur exigerPoste('president', 'Seul le President
--     peut accorder ou refuser une grace.') (plateau-politique.js:5908).
-- On ne fait que les transposer la ou elles ne sont plus contournables.

-- --- LA BRIQUE : jumelle serveur de exigerPoste() -------------------------
-- exigerPoste() vit cote client et ne prouve rien : le poste y est lu dans
-- state.poste, que le joueur controle. Ici le poste est relu SUR LA LIGNE du
-- personnage du compte connecte -- ni le nom ni le poste ne viennent du client.
CREATE OR REPLACE FUNCTION public.exiger_poste(p_poste text)
RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_nom text; v_poste text;
BEGIN
  -- Le serveur (cron, endpoints /api/*) traverse : il n'a pas de personnage.
  IF public.est_appel_serveur() THEN RETURN NULL; END IF;

  SELECT p.name, p.poste->>'id' INTO v_nom, v_poste
  FROM public.personnages_donnees p
  WHERE p.user_id = auth.uid()
  LIMIT 1;

  IF v_nom IS NULL THEN
    RAISE EXCEPTION 'acteur_non_authentifie: aucun personnage rattache a ce compte'
      USING ERRCODE = '42501';
  END IF;
  IF v_poste IS DISTINCT FROM p_poste THEN
    RAISE EXCEPTION 'autorite_insuffisante: poste % requis, poste reel %',
      p_poste, coalesce(v_poste, '(aucun)') USING ERRCODE = '42501';
  END IF;
  RETURN v_nom;
END;
$$;
GRANT EXECUTE ON FUNCTION public.exiger_poste(text) TO anon, authenticated;

-- --- PROLONGATION DE PEINE (autorite : juge) -----------------------------
-- Reproduit exactement prolongerDetentionActive : motifs concatenes (jamais
-- remplaces), jour_fin augmente de la somme des jours, bascule QHS optionnelle,
-- et le miroir est_emprisonne du condamne mis a jour dans la meme transaction.
CREATE OR REPLACE FUNCTION public.justice_prolonger_peine(
  p_cible text, p_motifs jsonb, p_forcer_qhs boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_juge text; v_peine jsonb; v_detention_id text;
  v_jours_supp int; v_jour_fin_actuel int; v_nouveau_jour_fin int;
  v_motifs_actuels jsonb;
BEGIN
  v_juge := public.exiger_poste('juge');

  IF p_motifs IS NULL OR jsonb_typeof(p_motifs) <> 'array' OR jsonb_array_length(p_motifs) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'motifs_absents');
  END IF;

  SELECT est_emprisonne INTO v_peine FROM public.personnages_donnees
  WHERE name = p_cible FOR UPDATE;
  IF v_peine IS NULL OR jsonb_typeof(v_peine) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_non_detenue');
  END IF;
  v_detention_id := v_peine->>'detentionId';
  IF v_detention_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'detention_sans_registre');
  END IF;

  SELECT coalesce(sum((m->>'jours')::int), 0) INTO v_jours_supp
  FROM jsonb_array_elements(p_motifs) m;

  v_jour_fin_actuel := coalesce((v_peine->>'jourFin')::int, 0);
  v_nouveau_jour_fin := v_jour_fin_actuel + v_jours_supp;

  SELECT coalesce(motifs, '[]'::jsonb) INTO v_motifs_actuels
  FROM public.detentions WHERE id = v_detention_id FOR UPDATE;

  UPDATE public.detentions
  SET motifs = v_motifs_actuels || p_motifs,
      jour_fin = v_nouveau_jour_fin,
      qhs = CASE WHEN p_forcer_qhs THEN true ELSE qhs END
  WHERE id = v_detention_id;

  UPDATE public.personnages_donnees
  SET est_emprisonne = v_peine
        || jsonb_build_object('jours', coalesce((v_peine->>'jours')::int, 0) + v_jours_supp)
        || jsonb_build_object('jourFin', v_nouveau_jour_fin)
        || CASE WHEN p_forcer_qhs THEN jsonb_build_object('qhs', true) ELSE '{}'::jsonb END
  WHERE name = p_cible;

  RETURN jsonb_build_object('ok', true, 'juge', v_juge, 'cible', p_cible,
                            'jours_ajoutes', v_jours_supp, 'jour_fin', v_nouveau_jour_fin);
END;
$$;
REVOKE ALL ON FUNCTION public.justice_prolonger_peine(text, jsonb, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.justice_prolonger_peine(text, jsonb, boolean) TO authenticated;

-- --- GRACE PRESIDENTIELLE (autorite : president) -------------------------
-- Reproduit confirmerGrace : liberation de la source canonique
-- (personnages.est_emprisonne) ET cloture du registre avec mode_fin explicite.
-- Le verdict rendu dit si quelqu'un a REELLEMENT ete libere : c'est lui qui
-- conditionne l'annonce publique, comme aujourd'hui -- une grace annoncee mais
-- non appliquee est pire qu'une grace qui echoue.
CREATE OR REPLACE FUNCTION public.presidence_gracier(p_condamne text, p_jour integer DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_president text; v_peine jsonb; v_detention_id text;
BEGIN
  v_president := public.exiger_poste('president');

  SELECT est_emprisonne INTO v_peine FROM public.personnages_donnees
  WHERE name = p_condamne FOR UPDATE;
  IF v_peine IS NULL OR jsonb_typeof(v_peine) <> 'object' THEN
    RETURN jsonb_build_object('ok', true, 'libere', false, 'raison', 'non_detenu');
  END IF;

  v_detention_id := v_peine->>'detentionId';
  UPDATE public.personnages_donnees SET est_emprisonne = NULL WHERE name = p_condamne;

  IF v_detention_id IS NOT NULL THEN
    UPDATE public.detentions
    SET mode_fin = 'grace_presidentielle',
        jour_fin_effective = p_jour,
        date_fin_effective = now()
    WHERE id = v_detention_id AND mode_fin IS NULL;
  END IF;

  RETURN jsonb_build_object('ok', true, 'libere', true,
                            'president', v_president, 'condamne', p_condamne);
END;
$$;
REVOKE ALL ON FUNCTION public.presidence_gracier(text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.presidence_gracier(text, integer) TO authenticated;