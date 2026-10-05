-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260929213620
-- Nom original      : t1_equiper_soldat_pose_un_objet
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-29 21:36:20 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 809a2a27415c856d5f947781b5d10393
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
create or replace function public.militaire_equiper_soldat(
  p_compagnie_id text, p_section_id text, p_matricule text, p_categorie text)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE
  g record; v_sec jsonb; v_stock jsonb; v_sol jsonb; v_anc text; v_dispo int;
  v_pnj text; v_rendu text;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  IF p_categorie NOT IN ('corps_a_corps','arme_de_poing','mitraillette') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'categorie_invalide');
  END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;
  v_stock := CASE WHEN jsonb_typeof(v_sec->'stockArmes') = 'object' THEN v_sec->'stockArmes'
                  ELSE jsonb_build_object('arme_de_poing',0,'mitraillette',0) END;
  SELECT s INTO v_sol FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) s
   WHERE s->>'matricule' = p_matricule LIMIT 1;
  IF v_sol IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'soldat_introuvable'); END IF;

  SELECT sm.pnj_id INTO v_pnj
    FROM public.pnj_soldats_metier sm JOIN public.pnj_membres m ON m.id = sm.pnj_id
   WHERE sm.compagnie_id = p_compagnie_id AND sm.section_id = p_section_id
     AND sm.matricule = p_matricule AND m.statut = 'actif';
  IF v_pnj IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'soldat_introuvable'); END IF;

  v_anc := public.militaire_arme_operationnelle(v_pnj);
  IF v_anc = p_categorie THEN RETURN jsonb_build_object('ok', true, 'rejeu', true, 'arme', v_anc); END IF;

  IF p_categorie <> 'corps_a_corps' THEN
    v_dispo := GREATEST(0, COALESCE((v_stock->>p_categorie)::int, 0));
    IF v_dispo <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_section_insuffisant', 'categorie', p_categorie);
    END IF;
    v_stock := v_stock || jsonb_build_object(p_categorie, v_dispo - 1);
  END IF;

  IF v_anc IN ('arme_de_poing','mitraillette') THEN
    v_stock := v_stock || jsonb_build_object(v_anc,
                 GREATEST(0, COALESCE((v_stock->>v_anc)::int, 0)) + 1);
    DELETE FROM public.pnj_possessions
     WHERE id = (SELECT p.id FROM public.pnj_possessions p
                  WHERE p.pnj_id = v_pnj AND p.objet->>'type' = 'arme'
                    AND coalesce(p.objet->>'produitMilitaire', p.objet->>'name') = v_anc
                  ORDER BY p.id LIMIT 1);
  END IF;

  IF p_categorie <> 'corps_a_corps' THEN
    INSERT INTO public.pnj_possessions (pnj_id, objet, origine)
    VALUES (v_pnj, jsonb_build_object(
      'id', 'mil-' || replace(gen_random_uuid()::text, '-', ''),
      'type', 'arme', 'sousType', 'militaire', 'origineMilitaire', true,
      'lot', 'stock-section', 'produitMilitaire', p_categorie,
      'name', CASE p_categorie WHEN 'arme_de_poing' THEN 'Pistolet militaire'
                               ELSE 'Mitraillette' END,
      'icon', 'ti-crosshair', 'legal', true,
      'imageUrl', CASE p_categorie
        WHEN 'arme_de_poing' THEN 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-pistolet-militaire.png'
        ELSE 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-mitraillette-militaire.png' END,
      'desc', 'Arme reglementaire, remise depuis le stock de la section.'), 'socle');
  END IF;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('stockArmes', v_stock))
   WHERE id = p_compagnie_id;
  v_rendu := public.militaire_arme_recalculer(v_pnj);

  RETURN jsonb_build_object('ok', true, 'matricule', p_matricule, 'arme', v_rendu,
                            'ancienne', v_anc, 'stock', v_stock);
END; $fn$;

comment on function public.militaire_equiper_soldat(text,text,text,text) is
  'Equipe un PNJ soldat depuis le stock d''armes de sa section. Depuis le lot T elle POSE UN VRAI OBJET dans pnj_possessions au lieu d''ecrire une categorie abstraite, et rend au stock l''arme precedemment portee. L''arme operationnelle est ensuite recalculee depuis les possessions : les deux chemins -- stock de section et transfert d''objet -- ne peuvent plus se contredire.';

revoke all on function public.militaire_equiper_soldat(text,text,text,text) from public, anon, authenticated;
grant execute on function public.militaire_equiper_soldat(text,text,text,text) to authenticated, service_role;