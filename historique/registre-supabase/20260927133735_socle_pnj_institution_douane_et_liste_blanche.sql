-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927133735
-- Nom original      : socle_pnj_institution_douane_et_liste_blanche
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-27 13:37:35 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : b30a02f928c065f9aeba3362a8ef9e82
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
-- LOT 2b — L'INSTITUTION DOUANES ET SON AUTORITE (27 septembre 2026)
--
-- Le socle ne sait pas ce qu'est un Chef des Douanes. Il demande a l'institution qui detient
-- l'autorite sur un perimetre, exactement comme il le fait pour le militaire. `douane` est donc
-- enregistree avec son resolveur, et le mot « chef_douanes » n'existe que dans ce resolveur.
--
-- FIDELITE A LA PORTE HISTORIQUE. Le controle existant est `chefDouanesValide()` cote client et,
-- cote serveur, `poste->>'id' = 'chef_douanes'` avec le service fige a ville_a/port-sainte-marie.
-- Le resolveur reproduit cela sans le durcir ni l'elargir : le detenteur de l'autorite est le PJ
-- qui porte le poste dans ce pays, et rien d'autre.
--
-- UN TITULAIRE PNJ N'EST PAS UNE AUTORITE. `titulaires_pnj` contient un Chef des Douanes PNJ.
-- C'est un occupant de poste de classe Gamma, pas un detenteur d'autorite : tant qu'aucun PJ ne
-- porte le poste, l'autorite est A PERSONNE -- meme doctrine que la reserve militaire.
CREATE OR REPLACE FUNCTION public.douane_autorite_de_perimetre(p_pays text, p_perimetre text)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_nom text;
BEGIN
  -- Le service des douanes est unique et fige. Un perimetre inconnu n'ouvre aucune autorite.
  IF p_perimetre IS DISTINCT FROM 'ville_a:port-sainte-marie' THEN RETURN NULL; END IF;
  SELECT pd.name INTO v_nom
    FROM public.personnages_donnees pd
   WHERE COALESCE(pd.country, 'republic') = p_pays
     AND pd.poste->>'id' = 'chef_douanes'
   ORDER BY pd.name
   LIMIT 1;
  RETURN v_nom;              -- NULL legitime : aucun PJ ne porte le poste aujourd'hui.
END; $$;

INSERT INTO public.pnj_institutions (institution, resolveur, note) VALUES
  ('douane', 'douane_autorite_de_perimetre',
   'Perimetre = ''<ville>:<batiment>'' du service des douanes. Autorite : le PJ portant le poste '
   'chef_douanes dans ce pays. Un titulaire PNJ du poste n''est PAS une autorite.')
ON CONFLICT (institution) DO UPDATE SET resolveur = EXCLUDED.resolveur, note = EXCLUDED.note;

-- ---------------------------------------------------------------------------------------
-- LA LISTE BLANCHE DES CARACTERISTIQUES S'ELARGIT -- POUR LES DOUANIERS SEULEMENT
-- ---------------------------------------------------------------------------------------
-- Elle n'acceptait que PER et VOL, pour la police comme pour la douane. Les douaniers recoivent
-- desormais les six caracteristiques du referentiel. La branche POLICE est laissee STRICTEMENT
-- INCHANGEE : ce lot ne touche pas a la police.
CREATE OR REPLACE FUNCTION public.batiment_etat_sous_cle_ecrire(
  p_pays text, p_ville text, p_batiment text, p_sous_cle text, p_valeur jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE
  v_id text; v_serveur boolean; v_poste jsonb; v_moi text;
  v_data jsonb; v_etat jsonb; v_mauvaise text; v_el jsonb; v_sous jsonb; v_n numeric;
  v_cles_stats text[];
BEGIN
  IF p_pays IS NULL OR p_ville IS NULL OR p_batiment IS NULL OR p_sous_cle IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'arguments_manquants');
  END IF;
  v_id := p_pays || '_' || p_ville || '_' || p_batiment;
  v_serveur := public.est_appel_serveur();

  IF p_sous_cle NOT IN ('blocus','effectifsPolice','effectifsDouane','candidatures',
                        'parCaisse','controles','offres') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'sous_cle_non_autorisee');
  END IF;

  v_mauvaise := public.jsonb_cle_economique_presente(p_valeur);
  IF v_mauvaise IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cle_economique_interdite', 'cle', v_mauvaise);
  END IF;

  IF NOT v_serveur THEN
    SELECT p.name, p.poste INTO v_moi, v_poste
    FROM public.personnages_donnees p WHERE p.user_id = auth.uid() LIMIT 1;
    IF v_moi IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
    END IF;

    IF p_sous_cle = 'effectifsPolice' THEN
      IF (v_poste->>'id') IS DISTINCT FROM 'commissaire'
         OR (v_poste->>'city') IS DISTINCT FROM p_ville
         OR p_batiment NOT IN ('commissariat','commissariat-local') THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
      END IF;
    ELSIF p_sous_cle = 'effectifsDouane' THEN
      IF (v_poste->>'id') IS DISTINCT FROM 'chef_douanes'
         OR p_ville <> 'ville_a' OR p_batiment <> 'port-sainte-marie' THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
      END IF;
    ELSIF p_sous_cle = 'controles' THEN
      IF (v_poste->>'id') IS DISTINCT FROM 'chef_douanes'
         OR v_id <> 'global_national_dissimulation-fret' THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
      END IF;
    ELSIF p_sous_cle = 'parCaisse' THEN
      IF v_id <> 'global_national_dissimulation-fret' THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'emplacement_invalide');
      END IF;
    ELSIF p_sous_cle = 'candidatures' THEN
      IF p_ville <> 'national' OR p_batiment <> 'candidatures_postes' THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'emplacement_invalide');
      END IF;
    ELSIF p_sous_cle = 'offres' THEN
      IF p_ville <> 'national' OR p_batiment <> 'bne' THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'emplacement_invalide');
      END IF;
    END IF;
  END IF;

  IF p_sous_cle IN ('effectifsPolice','effectifsDouane') THEN
    IF jsonb_typeof(p_valeur) <> 'object'
       OR public.jsonb_cles_hors_liste(p_valeur,
            ARRAY['policiers','douaniers','dernierPaiementJour']) IS NOT NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
    END IF;
    -- LA SEULE DIFFERENCE AVEC LA VERSION PRECEDENTE : les six caracteristiques du referentiel
    -- sont acceptees pour la douane. La police reste sur PER/VOL, a l'identique.
    v_cles_stats := CASE WHEN p_sous_cle = 'effectifsDouane'
                         THEN public.pnj_caracteristiques_cles()
                         ELSE ARRAY['PER','VOL']::text[] END;
    v_sous := COALESCE(p_valeur->'policiers', p_valeur->'douaniers');
    IF v_sous IS NOT NULL THEN
      IF jsonb_typeof(v_sous) <> 'array' OR jsonb_array_length(v_sous) > 200 THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
      END IF;
      FOR v_el IN SELECT value FROM jsonb_array_elements(v_sous) LOOP
        IF jsonb_typeof(v_el) <> 'object'
           OR public.jsonb_cles_hors_liste(v_el, ARRAY['matricule','type','maitreNom','chienNom',
                'stats','buildingId','roomId','rueNoeudId','recruteLe']) IS NOT NULL
           OR COALESCE(v_el->>'type', 'standard') NOT IN ('standard','cynophile') THEN
          RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
        END IF;
        IF v_el ? 'stats' THEN
          IF jsonb_typeof(v_el->'stats') <> 'object'
             OR public.jsonb_cles_hors_liste(v_el->'stats', v_cles_stats) IS NOT NULL THEN
            RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
          END IF;
          FOR v_n IN SELECT (value#>>'{}')::numeric FROM jsonb_each(v_el->'stats') LOOP
            IF v_n < 0 OR v_n > 100 THEN
              RETURN jsonb_build_object('ok', false, 'raison', 'stat_hors_bornes');
            END IF;
          END LOOP;
        END IF;
      END LOOP;
    END IF;

  ELSIF p_sous_cle = 'blocus' THEN
    IF jsonb_typeof(p_valeur) NOT IN ('null','object') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
    END IF;
    IF jsonb_typeof(p_valeur) = 'object' THEN
      IF public.jsonb_cles_hors_liste(p_valeur, ARRAY['syndicatId','syndicatNom','revendication',
           'nbMilitants','intensite','leaderActuel','lanceLe',
           'dernierRenouvellementTimestamp']) IS NOT NULL THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
      END IF;
      IF COALESCE((p_valeur->>'intensite')::numeric, 0) < 0
         OR COALESCE((p_valeur->>'intensite')::numeric, 0) > 100
         OR COALESCE((p_valeur->>'nbMilitants')::numeric, 0) < 0
         OR COALESCE((p_valeur->>'nbMilitants')::numeric, 0) > 10000 THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'valeur_hors_bornes');
      END IF;
      IF NOT v_serveur THEN
        p_valeur := jsonb_set(p_valeur, '{leaderActuel}', to_jsonb(v_moi));
      END IF;
    END IF;

  ELSIF p_sous_cle = 'parCaisse' THEN
    IF jsonb_typeof(p_valeur) <> 'object' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
    END IF;
    FOR v_el IN SELECT value FROM jsonb_each(p_valeur) LOOP
      IF jsonb_typeof(v_el) <> 'number' OR (v_el#>>'{}')::numeric < 0
         OR (v_el#>>'{}')::numeric > 100 THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'valeur_hors_bornes');
      END IF;
    END LOOP;

  ELSIF p_sous_cle = 'controles' THEN
    IF jsonb_typeof(p_valeur) <> 'object' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
    END IF;
    FOR v_el IN SELECT value FROM jsonb_each(p_valeur) LOOP
      IF jsonb_typeof(v_el) <> 'object'
         OR public.jsonb_cles_hors_liste(v_el, ARRAY['resultat','controleeLe']) IS NOT NULL
         OR COALESCE(v_el->>'resultat', '') NOT IN ('positif','negatif') THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
      END IF;
    END LOOP;

  ELSIF p_sous_cle = 'offres' THEN
    IF jsonb_typeof(p_valeur) <> 'object' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
    END IF;
    FOR v_sous IN SELECT value FROM jsonb_each(p_valeur) LOOP
      IF jsonb_typeof(v_sous) <> 'array' OR jsonb_array_length(v_sous) > 100 THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
      END IF;
      FOR v_el IN SELECT value FROM jsonb_array_elements(v_sous) LOOP
        IF jsonb_typeof(v_el) <> 'object'
           OR public.jsonb_cles_hors_liste(v_el, ARRAY['pjNom','statut']) IS NOT NULL
           OR COALESCE(v_el->>'statut', '') NOT IN ('actif','en_attente_arbitrage') THEN
          RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
        END IF;
      END LOOP;
    END LOOP;

  ELSIF p_sous_cle = 'candidatures' THEN
    IF jsonb_typeof(p_valeur) <> 'object' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
    END IF;
    FOR v_sous IN SELECT value FROM jsonb_each(p_valeur) LOOP
      IF jsonb_typeof(v_sous) <> 'object'
         OR public.jsonb_cles_hors_liste(v_sous, ARRAY['posteId','city','candidats',
              'echeanceTs','autoriteNom','traitee']) IS NOT NULL THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
      END IF;
      IF v_sous ? 'candidats' AND jsonb_typeof(v_sous->'candidats') <> 'array' THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
      END IF;
    END LOOP;
  END IF;

  SELECT data INTO v_data FROM public.batiments_etat WHERE id = v_id FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.batiments_etat (id, country, city, building_id, data)
    VALUES (v_id, p_pays, p_ville, p_batiment,
            to_jsonb(jsonb_build_object(p_sous_cle, p_valeur)::text));
    RETURN jsonb_build_object('ok', true, 'valeur', p_valeur);
  END IF;

  v_etat := COALESCE(public.batiment_etat_lire(v_data), '{}'::jsonb);
  v_etat := jsonb_set(v_etat, ARRAY[p_sous_cle], p_valeur, true);

  UPDATE public.batiments_etat
     SET data = to_jsonb(v_etat::text), updated_at = now()
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'valeur', p_valeur);
END; $$;

REVOKE ALL ON FUNCTION public.douane_autorite_de_perimetre(text,text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.douane_autorite_de_perimetre(text,text) TO service_role;