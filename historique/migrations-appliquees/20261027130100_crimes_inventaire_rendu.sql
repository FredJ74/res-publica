-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261027184053.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 27/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261027184053.
-- ============================================================================
-- CRIMES : L'INVENTAIRE RENDU PAR LE SERVEUR EST ADOPTABLE PAR L'ECRAN (27 octobre 2026)
-- ============================================================================
-- L'inventaire d'un joueur n'est ecrit que par le serveur (inventaire_revision_garder), et l'ecran
-- n'adopte une reponse que si elle porte `inventory` et sa `revision` (sbAdopterInventaireServeur).
-- Les fonctions de crime rendaient `inventaire` seul : l'ecran d'un inventaire versionne refusait
-- de l'adopter et affichait l'ancien (explosif ou poison encore presents, cargaison ou faux
-- document absents) jusqu'au rechargement. Elles rendent desormais aussi `inventory` et `revision`.
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.crime_etat_acteur_interne(p_nom text)
 RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$ SELECT jsonb_build_object('pa', pa, 'arg', arg, 'liquide', liquide, 'dis', resources -> 'dis',
              'recherche', recherche, 'inventaire', inventory, 'inventory', inventory, 'revision', inventory_revision)
        FROM public.personnages_donnees WHERE name = p_nom $$;

DO $do$
DECLARE v_def text; v_fn text;
BEGIN
  FOREACH v_fn IN ARRAY ARRAY['public.crime_explosifs(text)', 'public.crime_empoisonner(text)'] LOOP
    v_def := pg_get_functiondef(v_fn::regprocedure);
    IF position('''revision''' IN v_def) = 0 THEN
      v_def := replace(v_def, '''inventaire'', (SELECT inventory FROM public.personnages_donnees WHERE name = v_moi)',
        '''inventaire'', (SELECT inventory FROM public.personnages_donnees WHERE name = v_moi), '
        || '''inventory'', (SELECT inventory FROM public.personnages_donnees WHERE name = v_moi), '
        || '''revision'', (SELECT inventory_revision FROM public.personnages_donnees WHERE name = v_moi)');
      IF position('''revision''' IN v_def) = 0 THEN RAISE EXCEPTION '% : motif introuvable', v_fn; END IF;
      EXECUTE v_def;
    END IF;
  END LOOP;
END $do$;
REVOKE ALL ON FUNCTION public.crime_etat_acteur_interne(text) FROM PUBLIC, anon, authenticated;
