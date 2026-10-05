-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260916135730
-- Nom original      : football_primes_phases_finales
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-16 13:57:30 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : a6e73766ec60ba7912d6ed561f49084e
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
-- LES PRIMES DES PHASES FINALES SUIVENT LE MEME CHEMIN (16 septembre 2026).
--
-- Le coeur du versement est extrait dans une seule fonction interne, appelee par la journee
-- comme par le tour : une seule regle, un seul registre, aucune divergence possible entre les
-- deux voies -- c'est exactement la divergence qui avait produit le « double effet playoffs »
-- corrige le 5 septembre.
--
-- La cle de reference distingue la rencontre ('j4' ou 'quarts_aller'), le reste est identique.

CREATE OR REPLACE FUNCTION public.football_primes_match(p_saison integer, p_cle text, p_m jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_cote text; v_club text; v_role text; v_nom text;
  v_sal jsonb; v_montant integer; v_victoire boolean; v_ref text; v_affiche text;
  v_total integer; v_verses integer := 0; v_somme integer := 0; v_ignores integer := 0;
  v_detail jsonb := '[]'::jsonb;
BEGIN
  IF NOT coalesce((p_m->>'played')::boolean, true) THEN
    RETURN jsonb_build_object('verses', 0, 'total', 0, 'deja_versees', 0, 'detail', '[]'::jsonb);
  END IF;
  v_affiche := (p_m->>'home') || '-' || (p_m->>'away');

  FOREACH v_cote IN ARRAY ARRAY['home', 'away'] LOOP
    v_club := p_m->>v_cote;
    CONTINUE WHEN coalesce(v_club, '') = '';
    v_total := 0;
    v_victoire := CASE WHEN v_cote = 'home'
                       THEN coalesce((p_m->>'scoreHome')::int, 0) > coalesce((p_m->>'scoreAway')::int, 0)
                       ELSE coalesce((p_m->>'scoreAway')::int, 0) > coalesce((p_m->>'scoreHome')::int, 0) END;

    SELECT coalesce(data->'salaires', '{}'::jsonb) INTO v_sal
      FROM public.budgets_clubs WHERE id = v_club;
    v_sal := jsonb_build_object(
      'titulaire',     coalesce((v_sal->>'titulaire')::int, 100),
      'remplacant',    coalesce((v_sal->>'remplacant')::int, 50),
      'primeVictoire', coalesce((v_sal->>'primeVictoire')::int, 150));

    FOREACH v_role IN ARRAY ARRAY['titulaires', 'remplacants'] LOOP
      FOR v_nom IN
        SELECT n FROM public.football_noms_composition(
          coalesce(p_m #> ARRAY['compositions', v_cote, v_role],
                   p_m #> ARRAY['live', 'compositionFigee', v_cote, v_role])) n
      LOOP
        CONTINUE WHEN NOT EXISTS (
          SELECT 1 FROM public.personnages_donnees d
           WHERE d.name = v_nom
             AND d.licence_sportive ->> 'clubId' = v_club
             AND coalesce(d.licence_sportive ->> 'statut', '') = 'active');

        v_montant := CASE WHEN v_role = 'titulaires'
                          THEN (v_sal->>'titulaire')::int
                               + CASE WHEN v_victoire THEN (v_sal->>'primeVictoire')::int ELSE 0 END
                          ELSE (v_sal->>'remplacant')::int END;
        CONTINUE WHEN coalesce(v_montant, 0) <= 0;

        v_ref := 's' || p_saison || '-' || p_cle || '-' || v_affiche || '-' || v_nom || '-' || v_role;
        BEGIN
          INSERT INTO public.football_primes_versees
            (reference, saison, journee, affiche, beneficiaire, club, role, montant)
          VALUES (v_ref, p_saison, nullif(regexp_replace(p_cle, '\D', '', 'g'), '')::int,
                  v_affiche, v_nom, v_club, v_role, v_montant);
        EXCEPTION WHEN unique_violation THEN
          v_ignores := v_ignores + 1;
          CONTINUE;
        END;

        UPDATE public.personnages_donnees
           SET arg = coalesce(arg, 0) + v_montant
         WHERE name = v_nom;

        v_verses := v_verses + 1; v_somme := v_somme + v_montant; v_total := v_total + v_montant;
        v_detail := v_detail || jsonb_build_object('nom', v_nom, 'club', v_club,
                                                   'role', v_role, 'montant', v_montant);
      END LOOP;
    END LOOP;

    IF v_total > 0 THEN
      UPDATE public.budgets_clubs
         SET data = jsonb_set(data, '{caisse}',
                      to_jsonb(greatest(0, coalesce((data->>'caisse')::int, 0) - v_total)))
       WHERE id = v_club;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('verses', v_verses, 'total', v_somme,
                            'deja_versees', v_ignores, 'detail', v_detail);
END; $$;

CREATE OR REPLACE FUNCTION public.football_primes_journee(p_journee integer)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_data jsonb; v_saison integer; v_j jsonb; v_m jsonb; v_r jsonb;
  v_verses integer := 0; v_somme integer := 0; v_ignores integer := 0; v_detail jsonb := '[]'::jsonb;
BEGIN
  IF auth.uid() IS NULL AND NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'appelant_non_authentifie');
  END IF;

  SELECT data INTO v_data FROM public.championnat WHERE id = 2 FOR UPDATE;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'championnat_absent');
  END IF;
  v_saison := coalesce((v_data->>'numero')::int, 0);

  SELECT j INTO v_j FROM jsonb_array_elements(coalesce(v_data->'calendrier', '[]'::jsonb)) j
   WHERE (j->>'numero')::int = p_journee;
  IF v_j IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'journee_inconnue');
  END IF;

  FOR v_m IN SELECT m FROM jsonb_array_elements(coalesce(v_j->'matchs', '[]'::jsonb)) m LOOP
    v_r := public.football_primes_match(v_saison, 'j' || p_journee, v_m);
    v_verses := v_verses + (v_r->>'verses')::int;
    v_somme  := v_somme  + (v_r->>'total')::int;
    v_ignores:= v_ignores+ (v_r->>'deja_versees')::int;
    v_detail := v_detail || (v_r->'detail');
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'journee', p_journee, 'verses', v_verses,
                            'total', v_somme, 'deja_versees', v_ignores, 'detail', v_detail);
END; $$;

-- Les tours de phase finale : memes regles, meme registre. La finale est un match unique.
CREATE OR REPLACE FUNCTION public.football_primes_tour(p_manche text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_data jsonb; v_saison integer; v_liste jsonb; v_m jsonb; v_r jsonb; v_chemin text[];
  v_verses integer := 0; v_somme integer := 0; v_ignores integer := 0; v_detail jsonb := '[]'::jsonb;
BEGIN
  IF auth.uid() IS NULL AND NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'appelant_non_authentifie');
  END IF;

  v_chemin := CASE p_manche
    WHEN 'quarts_aller'  THEN ARRAY['playoffs','quarts','aller']
    WHEN 'quarts_retour' THEN ARRAY['playoffs','quarts','retour']
    WHEN 'demies_aller'  THEN ARRAY['playoffs','demies','aller']
    WHEN 'demies_retour' THEN ARRAY['playoffs','demies','retour']
    WHEN 'finale'        THEN ARRAY['playoffs','finale','resultat'] END;
  IF v_chemin IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'manche_inconnue');
  END IF;

  SELECT data INTO v_data FROM public.championnat WHERE id = 2 FOR UPDATE;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'championnat_absent');
  END IF;
  v_saison := coalesce((v_data->>'numero')::int, 0);

  v_liste := v_data #> v_chemin;
  IF v_liste IS NULL OR jsonb_typeof(v_liste) = 'null' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'manche_non_jouee');
  END IF;
  IF jsonb_typeof(v_liste) = 'object' THEN v_liste := jsonb_build_array(v_liste); END IF;

  FOR v_m IN SELECT m FROM jsonb_array_elements(v_liste) m LOOP
    v_r := public.football_primes_match(v_saison, p_manche, v_m);
    v_verses := v_verses + (v_r->>'verses')::int;
    v_somme  := v_somme  + (v_r->>'total')::int;
    v_ignores:= v_ignores+ (v_r->>'deja_versees')::int;
    v_detail := v_detail || (v_r->'detail');
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'manche', p_manche, 'verses', v_verses,
                            'total', v_somme, 'deja_versees', v_ignores, 'detail', v_detail);
END; $$;

REVOKE ALL ON FUNCTION public.football_primes_match(integer, text, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.football_primes_journee(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.football_primes_tour(text)       FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.football_primes_journee(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.football_primes_tour(text)       TO authenticated;