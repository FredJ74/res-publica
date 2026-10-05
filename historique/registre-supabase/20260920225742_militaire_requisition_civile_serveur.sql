-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920225742
-- Nom original      : militaire_requisition_civile_serveur
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-20 22:57:42 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 45852d314192096f142e478a67eae9d8
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
-- =====================================================================================
-- REQUISITION CIVILE : LA DECISION DU MINISTRE PRODUIT ENFIN UN EFFET (21 septembre 2026)
-- =====================================================================================
-- CE QUI ETAIT CASSE. confirmerRequisitionCivile ecrivait section.civilsRequisitionnes par
-- sbSaveCompagnie (refuse par la policy de compagnies_militaires : ni Commandant ni Capitaine),
-- puis bouclait 24 sbUpdate sur la fiche des AUTRES joueurs (refuses par le trigger
-- personnages_vue_modifier, motif personnage_non_possede), le tout avale par un .catch(() => {}).
-- Seuls les 24 mails partaient : les convoques n'etaient convoques nulle part, aucun delai
-- n'existait, et « Se presenter a mon affectation » ne trouvait donc jamais de convocation.
--
-- DOCTRINE APPLIQUEE. On n'ecrit JAMAIS sur la fiche d'un autre joueur depuis le navigateur :
-- une RPC SECURITY DEFINER verifie le poste min_def ATTESTE (exiger_poste, qui lit le poste
-- reel en base, pas celui que le client pretend), verifie la mobilisation nationale, tire au
-- sort les civils, ecrit le blob de la compagnie ET les 24 fiches, et paie les 3 PA au miroir.
-- Le client ne garde que ce qu'il est legitime a faire : envoyer les mails de convocation.
--
-- Bareme et perimetre inchanges : 24 civils, 48 h de delai, memes postes exclus du tirage
-- (officiers, ministres, maire), une seule requisition par section.
CREATE OR REPLACE FUNCTION public.militaire_requisition_civile(p_compagnie_id text, p_section_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  c_pa       constant integer := 3;
  c_heures   constant integer := 48;
  c_effectif constant integer := 24;
  v_moi text; v_pays text; v_pa integer; v_mobilisee boolean;
  v_data jsonb; v_sec jsonb; v_liste jsonb; v_noms text[];
  v_deadline numeric; v_paye jsonb;
BEGIN
  -- Poste ATTESTE : exiger_poste leve 42501 si l'appelant n'est pas reellement min_def.
  v_moi := public.exiger_poste('min_def');
  IF v_moi IS NULL THEN v_moi := public.mon_personnage(); END IF;
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT coalesce(p.country, 'republic'), coalesce(p.pa, 0) INTO v_pays, v_pa
    FROM public.personnages_donnees p WHERE p.name = v_moi FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  SELECT coalesce((b.data->>'mobilisationNationaleActive')::boolean, false) INTO v_mobilisee
    FROM public.budgets_nationaux b WHERE b.id = v_pays;
  IF NOT coalesce(v_mobilisee, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mobilisation_inactive');
  END IF;

  SELECT c.data INTO v_data FROM public.compagnies_militaires c
   WHERE c.id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable');
  END IF;
  IF v_data->>'pays' IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections', '[]'::jsonb)) s
   WHERE s->>'id' = p_section_id;
  IF v_sec IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'section_introuvable');
  END IF;
  IF coalesce(v_sec->>'lieutenantNom', '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'section_sans_lieutenant');
  END IF;
  IF jsonb_array_length(coalesce(v_sec->'civilsRequisitionnes', '[]'::jsonb)) > 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_requisitionnee');
  END IF;
  IF v_pa < c_pa THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'requis', c_pa, 'pa_reel', v_pa);
  END IF;

  -- TIRAGE AU SORT, cote serveur : le client ne choisit plus qui est requisitionne. Memes
  -- exclusions que la liste d'origine (officiers, ministres, maire) + le ministre lui-meme.
  SELECT array_agg(q.name) INTO v_noms FROM (
    SELECT p.name FROM public.personnages_donnees p
     WHERE coalesce(p.domicile->>'country', p.country, 'republic') = v_pays
       AND coalesce(p.poste->>'id', '') NOT IN ('lieutenant','capitaine','commandant','min_def',
             'president','pm','min_int','min_fin','min_just','min_info','min_ae','maire')
       AND p.name <> v_moi
     ORDER BY random() LIMIT c_effectif) q;
  IF v_noms IS NULL OR array_length(v_noms, 1) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_civil_eligible');
  END IF;

  v_deadline := floor(extract(epoch FROM now()) * 1000) + c_heures * 3600000;
  SELECT jsonb_agg(jsonb_build_object('nom', n, 'statut', 'convoque', 'deadline', v_deadline))
    INTO v_liste FROM unnest(v_noms) n;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(v_data, p_section_id,
                  v_sec || jsonb_build_object('civilsRequisitionnes', v_liste))
   WHERE id = p_compagnie_id;

  UPDATE public.personnages_donnees p
     SET requisition = jsonb_build_object('compagnieId', p_compagnie_id, 'sectionId', p_section_id,
                                          'deadline', v_deadline, 'statut', 'convoque')
   WHERE p.name = ANY(v_noms);

  v_paye := public.payer_ordre(v_moi, 'mobilisation_nationale', c_pa, 0);
  IF NOT coalesce((v_paye->>'ok')::boolean, false) THEN
    RAISE EXCEPTION 'militaire_requisition_civile: paiement refuse (%)',
      coalesce(v_paye->>'raison', 'motif inconnu');
  END IF;

  RETURN jsonb_build_object('ok', true, 'convoques', to_jsonb(v_noms),
    'nombre', array_length(v_noms, 1), 'deadline', v_deadline, 'delai_heures', c_heures,
    'section', v_sec->>'numero', 'lieutenant', v_sec->>'lieutenantNom', 'pa', v_paye->'pa');
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_requisition_civile(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_requisition_civile(text, text) TO authenticated, service_role;