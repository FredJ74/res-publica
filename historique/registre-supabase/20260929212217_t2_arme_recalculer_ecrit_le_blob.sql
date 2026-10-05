-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260929212217
-- Nom original      : t2_arme_recalculer_ecrit_le_blob
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-29 21:22:17 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 72045aff713cfdc37343b5e4f27a71e0
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
-- L'ARME EST UN AXE METIER, ET SON MAGASIN EST LE BLOB.
-- Constat du banc : militaire_blob_projeter reecrit leaderCourant, ville,
-- buildingId, roomId et pa depuis le socle -- mais PAS l'arme, parce que l'arme
-- n'est pas un axe du socle. C'est pnj_miroir_compagnie qui l'IMPORTE du blob.
-- Ecrire seulement pnj_soldats_metier.arme etait donc un piege a retardement :
-- la valeur deduite aurait tenu jusqu'a la prochaine ecriture du blob, puis le
-- miroir aurait reimporte l'ancienne categorie et desarme le soldat en silence.
--
-- On ecrit donc LES DEUX, dans la meme transaction : le magasin metier (blob) et
-- sa colonne de lecture (pnj_soldats_metier). Le miroir reimportera exactement ce
-- qui vient d'etre ecrit -- l'operation est idempotente, et aucun axe du socle
-- n'est detourne de son role.
create or replace function public.militaire_arme_recalculer(p_pnj_id text)
returns text
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_arme text; v_compagnie text; v_mat text; v_data jsonb;
BEGIN
  SELECT sm.compagnie_id, sm.matricule INTO v_compagnie, v_mat
    FROM public.pnj_soldats_metier sm WHERE sm.pnj_id = p_pnj_id;
  IF v_compagnie IS NULL THEN RETURN NULL; END IF;

  v_arme := public.militaire_arme_operationnelle(p_pnj_id);
  UPDATE public.pnj_soldats_metier SET arme = v_arme WHERE pnj_id = p_pnj_id;

  -- Le blob, soldat par soldat, sans toucher a quoi que ce soit d'autre : on
  -- reecrit la seule cle 'arme' de la seule entree qui porte ce matricule.
  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = v_compagnie FOR UPDATE;
  IF v_data IS NOT NULL THEN
    UPDATE public.compagnies_militaires
       SET data = jsonb_set(v_data, '{sections}', (
             SELECT coalesce(jsonb_agg(
               CASE WHEN EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) so
                                  WHERE so->>'matricule' = v_mat)
                    THEN jsonb_set(s, '{soldats}', (
                           SELECT coalesce(jsonb_agg(
                             CASE WHEN so->>'matricule' = v_mat
                                  THEN so || jsonb_build_object('arme', v_arme)
                                  ELSE so END ORDER BY o2), '[]'::jsonb)
                             FROM jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb))
                                  WITH ORDINALITY AS t2(so, o2)))
                    ELSE s END ORDER BY o1), '[]'::jsonb)
               FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb))
                    WITH ORDINALITY AS t1(s, o1))),
           updated_at = now()
     WHERE id = v_compagnie;
  END IF;

  PERFORM public.militaire_blob_projeter(v_compagnie);
  RETURN v_arme;
END; $fn$;

comment on function public.militaire_arme_recalculer(text) is
  'Recalcule l''arme operationnelle d''un PNJ soldat depuis ses possessions et l''ecrit AUX DEUX ENDROITS : le blob de compagnie, qui est le magasin de cet axe metier, et pnj_soldats_metier.arme, que le moteur de combat lit. Ecrire seulement la seconde laisserait pnj_miroir_compagnie reimporter l''ancienne categorie a la prochaine ecriture du blob, et desarmer le soldat en silence.';