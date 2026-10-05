-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917220800
-- Nom original      : militaire_soldat_depart_et_service_trigger
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 22:08:00 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : a21435412c31fc272aa7a3689dbe2ae3
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
-- ---- Retrait d'un soldat PJ : demission ou renvoi. JAMAIS une mort. ----
-- Un depart administratif libere une place et ne cree ni ne detruit aucun PNJ. Le GD insiste :
-- ne jamais assimiler depart administratif et mort au combat. Le PNJ eventuellement remplace
-- lors de l'arrivee reste en reserve ; sa reaffectation est une decision du Lieutenant, jamais
-- un effet de bord automatique.
CREATE OR REPLACE FUNCTION public.militaire_soldat_retirer(
  p_compagnie_id text, p_section_id text, p_nom text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  v_moi text; v_data jsonb; v_sec jsonb; v_sols jsonb; v_avant int; v_apres int;
  v_lieut text; v_par text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(coalesce(p_nom,'')),'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nom_invalide'); END IF;

  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id;
  IF v_sec IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'section_introuvable'); END IF;
  v_lieut := v_sec->>'lieutenantNom';

  -- DEUX AUTORITES LEGITIMES, et deux seulement : le soldat lui-meme (demission) ou le Lieutenant
  -- de sa section (renvoi). Tout autre acteur est refuse.
  IF v_moi = p_nom THEN v_par := 'demission';
  ELSIF v_lieut IS NOT NULL AND v_lieut = v_moi THEN v_par := 'renvoi';
  ELSE RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;

  v_sols := CASE WHEN jsonb_typeof(v_sec->'soldats') = 'array' THEN v_sec->'soldats' ELSE '[]'::jsonb END;
  v_avant := jsonb_array_length(v_sols);
  SELECT coalesce(jsonb_agg(sol ORDER BY pos), '[]'::jsonb) INTO v_sols
    FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos)
   WHERE NOT (coalesce((sol->>'pj')::boolean, false) AND sol->>'nom' = p_nom);
  v_apres := jsonb_array_length(v_sols);
  IF v_apres = v_avant THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_soldat_de_cette_section');
  END IF;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(v_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;

  -- La periode de service se termine ici : c'est elle, et non le calepin, qui fait foi.
  PERFORM public.militaire_service_fermer(p_nom, 'soldat');

  RETURN jsonb_build_object('ok', true, 'motif', v_par, 'nom', p_nom,
    'effectif', v_apres, 'places_libres', 24 - v_apres);
END; $fn$;
REVOKE ALL ON FUNCTION public.militaire_soldat_retirer(text,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.militaire_soldat_retirer(text,text,text) FROM anon;
GRANT EXECUTE ON FUNCTION public.militaire_soldat_retirer(text,text,text) TO authenticated, service_role;

-- ---- Le trigger de perte de poste clot aussi la periode de service de l'officier ----
-- Il couvrait deja la rupture du lien operationnel. Meme evenement, meme endroit : un officier
-- qui perd son poste -- demission, revocation, ARRESTATION pour crime -- voit sa periode de
-- service se fermer. Un seul declencheur pour une seule verite.
CREATE OR REPLACE FUNCTION public.personnages_lien_militaire_rompu() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE v_ancien text; v_nouveau text;
BEGIN
  v_ancien  := coalesce(OLD.poste->>'id', '');
  v_nouveau := coalesce(NEW.poste->>'id', '');

  IF v_ancien = 'lieutenant' AND v_nouveau IS DISTINCT FROM 'lieutenant' THEN
    -- OLD porte la DERNIERE position canonique connue du chef : c'est la que ses hommes restent.
    PERFORM public.militaire_lien_operationnel_rompre(
      OLD.name, OLD.current_city, OLD.current_building, OLD.current_room);
  END IF;

  IF v_ancien IN ('lieutenant','capitaine','commandant') AND v_nouveau IS DISTINCT FROM v_ancien THEN
    PERFORM public.militaire_service_fermer(OLD.name, v_ancien);
  END IF;

  -- Prise de fonction : la periode s'ouvre au moment ou le poste est reellement porte par la
  -- fiche, quel que soit le chemin (RPC de nomination, tirage au sort, cron).
  IF v_nouveau IN ('lieutenant','capitaine','commandant') AND v_nouveau IS DISTINCT FROM v_ancien THEN
    PERFORM public.militaire_service_ouvrir(NEW.name, coalesce(NEW.country,'republic'), v_nouveau,
              NEW.poste->>'compagnieId', NEW.poste->>'sectionId');
  END IF;

  RETURN NEW;
END;
$fn$;