-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260918142113
-- Nom original      : militaire_assigner_mission_sans_escorte
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-18 14:21:13 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 9fe3a1d91cbffc789501c6097242abde
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
-- ESCORTE RETIREE (18 septembre 2026, arbitrage GD).
--
-- 'escorter' etait assignable, affichee (« Escorte en cours »), et n'a jamais rien fait : son seul
-- effet, suivreEscorteAvecMoi, a ete neutralise au lot leaderCourant parce qu'il ecrivait une
-- position SANS ville et ecrasait leaderCourant -- il regressait deux lots a lui seul.
--
-- La fonction d'escorte n'est PAS perdue, elle est ailleurs et elle marche : militaire_affecter_leader
-- confie N hommes a un PJ physiquement present, qui les mene ensuite via leaderCourant. Un soldat
-- qui suit un chef n'a pas de position propre -- le deplacement est donc automatique et gratuit par
-- construction, et l'affectation passe par l'AUTORITE du Lieutenant au lieu d'etre un effet de bord
-- du deplacement de l'escorte.
--
-- LA SIGNATURE NE CHANGE PAS, DEFAUT COMPRIS. Retirer p_cible -- ou seulement son DEFAULT --
-- creerait une SURCHARGE et laisserait l'ancienne primitive joignable par les clients en cache.
-- Le parametre reste donc accepte, et simplement ignore.
--
-- Aucune section en production ne portait de mission au moment du retrait (verifie avant) : il n'y
-- a donc aucune donnee 'escorter' a conserver ni a migrer.
CREATE OR REPLACE FUNCTION public.militaire_assigner_mission(
  p_compagnie_id text, p_section_id text, p_mission text, p_cible text DEFAULT NULL::text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE g record; v_sec jsonb;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  IF p_mission NOT IN ('bloquer_acces','securiser','assassiner','arreter','surveiller') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mission_invalide');
  END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;
  -- cibleEscorte est retire de la section a chaque assignation : plus aucune mission ne l'utilise,
  -- et laisser trainer un champ mort ferait croire un jour qu'il veut encore dire quelque chose.
  v_sec := (v_sec - 'cibleEscorte') || jsonb_build_object('mission', p_mission);
  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id, v_sec)
   WHERE id = p_compagnie_id;
  RETURN jsonb_build_object('ok', true, 'mission', p_mission);
END;
$$;

REVOKE ALL ON FUNCTION public.militaire_assigner_mission(text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_assigner_mission(text, text, text, text) TO authenticated;