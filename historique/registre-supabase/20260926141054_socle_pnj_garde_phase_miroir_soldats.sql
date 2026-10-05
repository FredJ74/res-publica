-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260926141054
-- Nom original      : socle_pnj_garde_phase_miroir_soldats
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-26 14:10:54 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 4adbdbe1832252e6435396b50dc2dce9
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
-- GARDE DE PHASE MIROIR : le socle ne doit JAMAIS ecrire seul un axe que le blob detient.
-- 26 septembre 2026.
--
-- LE DANGER. Pendant la phase miroir, le blob militaire est l'AUTORITE et le socle son reflet.
-- Or les primitives generiques pnj_quitter_groupe / pnj_transferer / pnj_prendre /
-- pnj_pa_debiter ecrivent le SOCLE. Appelees sur un soldat, elles creeraient immediatement une
-- divergence blob/socle que le comparateur verrait -- et, pire, le prochain declenchement du
-- miroir ecraserait leur effet en resynchronisant depuis le blob. L'action paraitrait reussir
-- puis se defaire toute seule.
--
-- CE QUE LE COMPARATEUR COMPARE, donc ce qui est dangereux :
--   leader, ville, batiment, piece, pa, arme, entrainement, reserve, section, proprietaire,
--   statut  -> ces axes appartiennent au blob tant qu'il est autoritaire.
-- CE QU'IL NE COMPARE PAS, donc ce qui est sans risque :
--   liquide et possessions -- ils N'EXISTENT PAS dans le blob. Ce sont des capacites NEUVES
--   apportees par le socle : un soldat n'avait ni argent ni inventaire avant lui. Aucune
--   divergence n'est donc possible sur ces deux axes.
--
-- LA REGLE POSEE ICI : pendant la phase miroir, les primitives generiques qui touchent un axe
-- partage REFUSENT la famille 'soldat'. Les mouvements de soldats doivent passer par les RPC
-- militaires (militaire_deposer_soldats, militaire_recuperer_soldats,
-- militaire_affecter_leader, militaire_reposer_section, militaire_ordre_collectif...), qui
-- ecrivent le blob -- et le declencheur miroir met le socle a jour.
-- DONNER / RETIRER de l'argent et des objets restent ouverts a toutes les familles.
--
-- A LA BASCULE D'AUTORITE, cette garde sera retiree : c'est une bride de transition, pas une
-- regle de jeu. Le drapeau la rend explicite et revocable en une ligne.

CREATE TABLE IF NOT EXISTS public.pnj_transitions (
  cle text PRIMARY KEY, actif boolean NOT NULL, note text
);
REVOKE ALL ON public.pnj_transitions FROM anon, authenticated, PUBLIC;

INSERT INTO public.pnj_transitions (cle, actif, note) VALUES
  ('soldats_blob_autoritaire', true,
   'VRAI tant que compagnies_militaires est l''autorite d''ecriture des soldats. Tant que ce '
   'drapeau est vrai, les primitives generiques du socle refusent la famille soldat sur les '
   'axes partages (leader, position, PA) : ces mouvements passent par les RPC militaires, et '
   'le declencheur miroir propage. A PASSER A FAUX au moment de la bascule d''autorite, apres '
   'quoi les primitives generiques deviennent le chemin normal.')
ON CONFLICT (cle) DO NOTHING;

CREATE OR REPLACE FUNCTION public.pnj_axe_partage_verrouille(p_ids text[])
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT m.id FROM public.pnj_membres m
   WHERE m.id = ANY(p_ids) AND m.famille = 'soldat'
     AND EXISTS (SELECT 1 FROM public.pnj_transitions t
                  WHERE t.cle = 'soldats_blob_autoritaire' AND t.actif)
   LIMIT 1;
$$;

-- On enveloppe les trois primitives concernees par la garde, sans toucher a leur logique :
-- on la recree depuis sa propre definition en inserant le refus juste apres le BEGIN.
DO $mig$
DECLARE f record; d text; v_n integer := 0;
  c_garde text := '
  IF public.pnj_axe_partage_verrouille(p_ids) IS NOT NULL THEN
    RETURN jsonb_build_object(''ok'', false, ''raison'', ''soldat_axe_blob_autoritaire'',
      ''pnj'', public.pnj_axe_partage_verrouille(p_ids),
      ''explication'', ''Pendant la phase miroir, les mouvements de soldats passent par les RPC militaires : le blob reste l autorite et le declencheur met le socle a jour.'');
  END IF;';
BEGIN
  FOR f IN SELECT p.oid, p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
           WHERE n.nspname='public'
             AND p.proname IN ('pnj_quitter_groupe','pnj_transferer','pnj_prendre','pnj_pa_debiter')
  LOOP
    d := pg_get_functiondef(f.oid);
    IF position('pnj_axe_partage_verrouille' in d) > 0 THEN CONTINUE; END IF;
    IF position(E'\nBEGIN\n' in d) = 0 THEN
      RAISE EXCEPTION 'BEGIN introuvable dans %, garde non posee', f.proname; END IF;
    d := overlay(d placing (E'\nBEGIN' || c_garde) from position(E'\nBEGIN\n' in d)
                 for length(E'\nBEGIN'));
    EXECUTE d;
    v_n := v_n + 1;
  END LOOP;
  IF v_n <> 4 THEN RAISE EXCEPTION 'attendu 4 fonctions gardees, obtenu %', v_n; END IF;
END $mig$;