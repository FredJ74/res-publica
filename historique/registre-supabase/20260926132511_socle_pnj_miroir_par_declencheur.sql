-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260926132511
-- Nom original      : socle_pnj_miroir_par_declencheur
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-26 13:25:11 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 393fb08dcae6f66d5b6151820cb2ab20
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
-- DOUBLE ECRITURE DU SOCLE -- PAR DECLENCHEUR, NON PAR RETOUCHE DES 14 FONCTIONS
-- 26 septembre 2026.
--
-- POURQUOI UN DECLENCHEUR PLUTOT QUE 14 MIROIRS A LA MAIN.
-- Le brief demande « zero ecriture militaire oubliee avant activation ». Retoucher 14
-- fonctions laisse exactement ce risque : il suffit qu'une quinzieme apparaisse, ou qu'un
-- chemin d'ecriture m'ait echappe, pour que le socle derive en silence. Un declencheur sur
-- compagnies_militaires est EXHAUSTIF PAR CONSTRUCTION : toute ecriture du blob, par
-- n'importe quelle fonction, presente ou future, resynchronise le socle dans LA MEME
-- transaction. Un echec du miroir annule donc l'ecriture metier -- le fail-closed est gratuit,
-- il n'y a rien a inventer.
--
-- COUT : O(n) par ecriture militaire, sur 96 lignes. Sans consequence : les fonctions
-- militaires reecrivent DEJA le tableau soldats entier a chaque mutation, elles sont donc
-- deja O(n). Le declencheur ne change pas l'ordre de grandeur.
--
-- CE QU'IL NE FAIT PAS : il ne touche jamais au blob. Le blob reste l'AUTORITE, le socle est
-- son miroir. La bascule d'autorite est une etape ulterieure et distincte.
--
-- CE QU'IL PRESERVE : les PA, l'entrainement, l'arme, le matricule, la section, l'etat
-- reserve, le chef et la position, tous repris du blob. Et il ne fabrique rien : un soldat
-- absent du blob est retire du socle, un soldat nouveau y est ajoute.

CREATE OR REPLACE FUNCTION public.pnj_miroir_compagnie(p_compagnie text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $fn$
DECLARE c record; v_pays text; v_vus text[] := '{}'; v_sup integer := 0; v_maj integer := 0;
        s jsonb; sol jsonb; v_id text; v_sec text; v_res boolean;
BEGIN
  SELECT * INTO c FROM public.compagnies_militaires WHERE id = p_compagnie;
  IF c.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  v_pays := c.data->>'pays';

  -- Sections puis reserve : meme traitement, seul en_reserve/section_id change.
  FOR s IN SELECT value FROM jsonb_array_elements(COALESCE(c.data->'sections','[]'::jsonb)) LOOP
    v_sec := s->>'id'; v_res := false;
    FOR sol IN SELECT value FROM jsonb_array_elements(COALESCE(s->'soldats','[]'::jsonb)) LOOP
      CONTINUE WHEN COALESCE((sol->>'pj')::boolean, false) IS TRUE;
      v_id := p_compagnie || '-' || (sol->>'matricule');
      v_vus := v_vus || v_id;
      INSERT INTO public.pnj_membres (id, famille, nom, pays, proprietaire_poste,
          leader_pj, ville, building_id, room_id, pa, statut)
      VALUES (v_id, 'soldat', COALESCE(sol->>'matricule','?'), v_pays, 'lieutenant',
          sol->>'leaderCourant', sol->>'ville', sol->>'buildingId', sol->>'roomId',
          COALESCE((sol->>'pa')::integer, 12), 'actif')
      ON CONFLICT (id) DO UPDATE SET
          leader_pj = EXCLUDED.leader_pj, ville = EXCLUDED.ville,
          building_id = EXCLUDED.building_id, room_id = EXCLUDED.room_id,
          pa = EXCLUDED.pa, maj_le = now();
      INSERT INTO public.pnj_soldats_metier (pnj_id, matricule, section_id, en_reserve, arme, formation)
      VALUES (v_id, sol->>'matricule', v_sec, v_res, sol->>'arme',
              COALESCE(sol->'formation','{}'::jsonb))
      ON CONFLICT (pnj_id) DO UPDATE SET
          section_id = EXCLUDED.section_id, en_reserve = EXCLUDED.en_reserve,
          arme = EXCLUDED.arme, formation = EXCLUDED.formation;
      v_maj := v_maj + 1;
    END LOOP;
  END LOOP;

  FOR sol IN SELECT value FROM jsonb_array_elements(COALESCE(c.data->'reserve','[]'::jsonb)) LOOP
    v_id := p_compagnie || '-' || (sol->>'matricule');
    v_vus := v_vus || v_id;
    INSERT INTO public.pnj_membres (id, famille, nom, pays, proprietaire_poste,
        leader_pj, ville, building_id, room_id, pa, statut)
    VALUES (v_id, 'soldat', COALESCE(sol->>'matricule','?'), v_pays, 'lieutenant',
        sol->>'leaderCourant', sol->>'ville', sol->>'buildingId', sol->>'roomId',
        COALESCE((sol->>'pa')::integer, 12), 'actif')
    ON CONFLICT (id) DO UPDATE SET
        leader_pj = EXCLUDED.leader_pj, ville = EXCLUDED.ville,
        building_id = EXCLUDED.building_id, room_id = EXCLUDED.room_id,
        pa = EXCLUDED.pa, maj_le = now();
    INSERT INTO public.pnj_soldats_metier (pnj_id, matricule, section_id, en_reserve, arme, formation)
    VALUES (v_id, sol->>'matricule', NULL, true, sol->>'arme',
            COALESCE(sol->'formation','{}'::jsonb))
    ON CONFLICT (pnj_id) DO UPDATE SET
        section_id = NULL, en_reserve = true,
        arme = EXCLUDED.arme, formation = EXCLUDED.formation;
    v_maj := v_maj + 1;
  END LOOP;

  -- Un soldat disparu du blob (mort au combat, retire du contingent) disparait du socle.
  -- On ne le passe PAS a 'mort' : ce serait inventer une regle. Le blob est l'autorite, et
  -- s'il ne le contient plus, il n'existe plus.
  DELETE FROM public.pnj_membres
   WHERE id LIKE p_compagnie || '-%' AND NOT (id = ANY(v_vus));
  v_sup := ROW_COUNT_PLACEHOLDER_NON_UTILISE;
  RETURN jsonb_build_object('ok', true, 'synchronises', v_maj);
END; $fn$;

-- Le declencheur : APRES toute ecriture du blob, dans la meme transaction.
CREATE OR REPLACE FUNCTION public.pnj_miroir_compagnie_trg() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  -- On ne miroite que si le blob a reellement change, pour ne pas payer O(n) sur un
  -- UPDATE qui ne touche que updated_at.
  IF TG_OP = 'UPDATE' AND NEW.data IS NOT DISTINCT FROM OLD.data THEN RETURN NEW; END IF;
  PERFORM public.pnj_miroir_compagnie(NEW.id);
  RETURN NEW;
END; $$;

CREATE TRIGGER trg_pnj_miroir_compagnie
  AFTER INSERT OR UPDATE ON public.compagnies_militaires
  FOR EACH ROW EXECUTE FUNCTION public.pnj_miroir_compagnie_trg();

REVOKE ALL ON FUNCTION public.pnj_miroir_compagnie(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.pnj_miroir_compagnie(text) TO service_role;