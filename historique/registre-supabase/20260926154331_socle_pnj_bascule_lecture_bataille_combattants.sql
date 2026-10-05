-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260926154331
-- Nom original      : socle_pnj_bascule_lecture_bataille_combattants
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-26 15:43:31 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 084d5b9f1f8916eb3d886e1dbe248ef9
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
-- BASCULE DE LECTURE : militaire_bataille_combattants lit le socle. 26 septembre 2026.
--
-- SEMANTIQUE : « pour un camp engage dans une bataille, rendre la fiche de combat de chaque
-- combattant encore en lice ». Deux branches : les PJ (inchangee, elle lit personnages_donnees
-- et leur inventaire) et les SOLDATS PNJ, retrouves par (compagnie, section, matricule) depuis
-- les engagements deja enregistres.
--
-- Ce n'est PAS une lecture de presence : elle ne filtre ni la position ni la reserve. Elle
-- retrouve par IDENTITE des soldats deja engages. Le filtre `en_reserve` n'a donc pas lieu
-- d'etre ici -- l'ajouter serait inventer une regle. La correspondance se fait sur le
-- matricule, unique par construction (index unique sur pnj_soldats_metier.matricule).
--
-- `nom` RESTE NULL, VOLONTAIREMENT. Les soldats du blob n'ont AUCUNE cle `nom` : l'ancienne
-- lecture faisait sol->>'nom' et rendait donc toujours NULL. Le socle, lui, porte un `nom`
-- (le matricule). Le remplir ici serait une amelioration d'affichage -- donc un changement de
-- comportement, meme s'il parait meilleur. Consigne explicite : NULL reste NULL. Un lot separe
-- traitera la question.

CREATE OR REPLACE FUNCTION public.militaire_bataille_combattants(
  p_bataille_id bigint, p_camp text)
RETURNS TABLE(eng_id bigint, est_pj boolean, nom text, compagnie_id text, section_id text,
              matricule text, pa integer, comp_tir numeric, comp_cac numeric, arme_feu boolean,
              arme_cle text, bonus_arme integer, def_per numeric, def_dup numeric,
              saute_round integer, groupe_id text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
  SELECT e.id, true, e.personnage, e.compagnie_id, e.section_id, NULL::text,
         greatest(0, coalesce(pd.pa, 0)),
         coalesce((pd.competences_militaires->>'tir')::numeric, 0),
         coalesce((pd.competences_militaires->>'combat_rapproche')::numeric, 0),
         (af.cle IS NOT NULL),
         coalesce(af.cle, ac.cle),
         coalesce(af.bonus, ac.bonus, 0),
         public.assemblee_stat_base(pd.stats, 'PER'),
         public.assemblee_stat_base(pd.stats, 'DUP'),
         e.saute_round, e.groupe_id
    FROM public.batailles_engagements e
    JOIN public.personnages_donnees pd ON pd.name = e.personnage
    LEFT JOIN LATERAL (
      SELECT b.cle, b.bonus FROM jsonb_array_elements(
               CASE WHEN jsonb_typeof(pd.inventory)='array' THEN pd.inventory ELSE '[]'::jsonb END) i
        JOIN public.militaire_armes_bonus b
          ON b.cle = coalesce(i->>'produitMilitaire', i->>'name')
       WHERE i->>'type' = 'arme' AND b.mode = 'feu'
       ORDER BY b.bonus DESC LIMIT 1) af ON true
    LEFT JOIN LATERAL (
      SELECT b.cle, b.bonus FROM jsonb_array_elements(
               CASE WHEN jsonb_typeof(pd.inventory)='array' THEN pd.inventory ELSE '[]'::jsonb END) i
        JOIN public.militaire_armes_bonus b
          ON b.cle = coalesce(i->>'produitMilitaire', i->>'name')
       WHERE i->>'type' = 'arme' AND b.mode = 'cac'
       ORDER BY b.bonus DESC LIMIT 1) ac ON true
   WHERE e.bataille_id = p_bataille_id AND e.camp = p_camp
     AND e.personnage IS NOT NULL AND e.sorti_round IS NULL

  UNION ALL

  SELECT e.id, false,
         NULL::text,                      -- << NULL comme historiquement, PAS le matricule
         e.compagnie_id, e.section_id, e.matricule,
         greatest(0, coalesce(m.pa, 0)),
         coalesce((sm.formation->>'tir')::numeric, 0),
         coalesce((sm.formation->>'combat_rapproche')::numeric, 0),
         coalesce(sm.arme,'corps_a_corps') IN ('arme_de_poing','mitraillette'),
         coalesce(sm.arme,'corps_a_corps'),
         public.militaire_bonus_arme(coalesce(sm.arme,'corps_a_corps'),
           CASE WHEN coalesce(sm.arme,'corps_a_corps') IN ('arme_de_poing','mitraillette')
                THEN 'feu' ELSE 'cac' END),
         public.militaire_defense_pnj('PER'),
         public.militaire_defense_pnj('DUP'),
         e.saute_round, e.groupe_id
    FROM public.batailles_engagements e
    JOIN public.pnj_soldats_metier sm ON sm.matricule = e.matricule
    JOIN public.pnj_membres m ON m.id = sm.pnj_id
   WHERE e.bataille_id = p_bataille_id AND e.camp = p_camp
     AND e.matricule IS NOT NULL AND e.sorti_round IS NULL
     AND m.id LIKE e.compagnie_id || '-%'
     AND sm.section_id = e.section_id;
$function$;