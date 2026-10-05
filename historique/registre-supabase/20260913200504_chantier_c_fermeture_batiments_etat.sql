-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913200504
-- Nom original      : chantier_c_fermeture_batiments_etat
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-13 20:05:04 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 02d16e48592848e428d69584e6442958
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
-- CHANTIER C / PHASE 2 — FERMETURE DE batiments_etat (13 septembre 2026)
--
-- Constat de depart : RLS n'etait meme pas activee sur batiments_etat, et anon detenait
-- INSERT/UPDATE/DELETE. N'importe quel navigateur pouvait donc PATCHer le blob complet d'un
-- batiment et s'ecrire une caisse, un stock ou un prix arbitraires. C'est le verrou 5 du harnais.
--
-- Principe retenu, conforme a la consigne : AUCUN chemin generique d'ecriture du blob. La seule
-- porte restante pour le navigateur est une RPC qui n'accepte QU'UNE sous-cle a la fois, prise
-- dans une liste blanche de 7 sous-cles non economiques, avec controle d'autorite et validation
-- de forme. Les sous-cles economiques (caisse, stock, stockMatieres, stockProduits, reserves,
-- prixManuel, repartition, port, entrepot, usine, sante, imprimerie...) sont refusees a la porte,
-- et les RPC economiques dediees ecrites plus tot dans ce chantier restent le seul acces.

-- ---------------------------------------------------------------------------------------------
-- 1. Detecteur recursif de cle economique, a n'importe quelle profondeur.
--    Deuxieme filet apres la liste blanche de sous-cles : empeche de dissimuler une mutation
--    economique DANS une valeur non economique (ex. blocus.caisse, candidatures.x.stock).
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.jsonb_cle_economique_presente(p_val jsonb)
RETURNS text LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE v_cle text; v_sous jsonb; v_res text;
BEGIN
  IF p_val IS NULL THEN RETURN NULL; END IF;

  IF jsonb_typeof(p_val) = 'object' THEN
    FOR v_cle, v_sous IN SELECT key, value FROM jsonb_each(p_val) LOOP
      IF lower(v_cle) = ANY (ARRAY[
            'caisse','caisses','stock','stocks','stockmatieres','stockproduits','stockbois',
            'stockmedical','reserve','reserves','prix','prixmanuel','prixachat','prixvente',
            'prixunitaire','repartition','arg','liquide','banque','inventory','inventaire',
            'solde','production','chaines','montant','salaire','tresorerie','budget','fonds',
            'loyer','imprimerie','entrepot','entrepots','usine','usines','sante','terrain',
            'commerce','journal','pret','prets','dette','dettes','taxe','impot']) THEN
        RETURN v_cle;
      END IF;
      v_res := public.jsonb_cle_economique_presente(v_sous);
      IF v_res IS NOT NULL THEN RETURN v_res; END IF;
    END LOOP;

  ELSIF jsonb_typeof(p_val) = 'array' THEN
    FOR v_sous IN SELECT value FROM jsonb_array_elements(p_val) LOOP
      v_res := public.jsonb_cle_economique_presente(v_sous);
      IF v_res IS NOT NULL THEN RETURN v_res; END IF;
    END LOOP;
  END IF;

  RETURN NULL;
END; $$;

-- ---------------------------------------------------------------------------------------------
-- 2. Verificateur de liste blanche de cles d'un objet (forme exacte attendue).
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.jsonb_cles_hors_liste(p_obj jsonb, p_autorisees text[])
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT key FROM jsonb_each(p_obj)
  WHERE jsonb_typeof(p_obj) = 'object' AND NOT (key = ANY (p_autorisees))
  LIMIT 1;
$$;

-- ---------------------------------------------------------------------------------------------
-- 3. La seule ecriture cliente restante sur batiments_etat.
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.batiment_etat_sous_cle_ecrire(
  p_pays text, p_ville text, p_batiment text, p_sous_cle text, p_valeur jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id text; v_serveur boolean; v_poste jsonb; v_moi text;
  v_data jsonb; v_etat jsonb; v_mauvaise text; v_el jsonb; v_sous jsonb; v_n numeric;
BEGIN
  IF p_pays IS NULL OR p_ville IS NULL OR p_batiment IS NULL OR p_sous_cle IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'arguments_manquants');
  END IF;
  v_id := p_pays || '_' || p_ville || '_' || p_batiment;
  v_serveur := public.est_appel_serveur();

  -- 3.1 Liste blanche de sous-cles. Tout le reste du blob est economique et hors d'atteinte.
  IF p_sous_cle NOT IN ('blocus','effectifsPolice','effectifsDouane','candidatures',
                        'parCaisse','controles','offres') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'sous_cle_non_autorisee');
  END IF;

  -- 3.2 Aucune cle economique dissimulee dans la valeur, a quelque profondeur que ce soit.
  v_mauvaise := public.jsonb_cle_economique_presente(p_valeur);
  IF v_mauvaise IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cle_economique_interdite', 'cle', v_mauvaise);
  END IF;

  -- 3.3 Identite reelle de l'appelant (jamais le nom transmis par le client).
  IF NOT v_serveur THEN
    SELECT p.name, p.poste INTO v_moi, v_poste
    FROM public.personnages_donnees p WHERE p.user_id = auth.uid() LIMIT 1;
    IF v_moi IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
    END IF;
  END IF;

  -- 3.4 Autorite, par sous-cle. Regles EXISTANTES du jeu, recopiees telles quelles depuis les
  --     gardes clientes (commissaireLocalValide, chefDouanesValide) qui restent en place.
  IF NOT v_serveur THEN
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
      -- Ecrit par l'expediteur lui-meme au moment de fermer sa caisse : aucun poste requis,
      -- c'est la regle actuelle. Seul l'emplacement partage est impose.
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

  -- 3.5 Validation de forme, sous-cle par sous-cle. Bornes tirees des constantes existantes.
  IF p_sous_cle IN ('effectifsPolice','effectifsDouane') THEN
    IF jsonb_typeof(p_valeur) <> 'object' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
    END IF;
    IF public.jsonb_cles_hors_liste(p_valeur,
         ARRAY['policiers','douaniers','dernierPaiementJour']) IS NOT NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
    END IF;
    v_sous := COALESCE(p_valeur->'policiers', p_valeur->'douaniers');
    IF v_sous IS NOT NULL THEN
      IF jsonb_typeof(v_sous) <> 'array' OR jsonb_array_length(v_sous) > 200 THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
      END IF;
      FOR v_el IN SELECT value FROM jsonb_array_elements(v_sous) LOOP
        IF jsonb_typeof(v_el) <> 'object'
           OR public.jsonb_cles_hors_liste(v_el, ARRAY['matricule','type','maitreNom','chienNom',
                'stats','buildingId','roomId','rueNoeudId','recruteLe']) IS NOT NULL
           OR (v_el->>'type') NOT IN ('standard','cynophile') THEN
          RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
        END IF;
        IF v_el ? 'stats' THEN
          IF public.jsonb_cles_hors_liste(v_el->'stats', ARRAY['PER','VOL']) IS NOT NULL THEN
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
      -- Le meneur declare est TOUJOURS l'appelant reel : un nom transmis ne prouve rien.
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
         OR (v_el->>'resultat') NOT IN ('positif','negatif') THEN
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
           OR (v_el->>'statut') NOT IN ('actif','en_attente_arbitrage') THEN
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

  -- 3.6 Ecriture : UNE sous-cle, sous verrou de ligne, dans le double encodage existant
  --     (data est une CHAINE JSON dans une colonne jsonb).
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

-- ---------------------------------------------------------------------------------------------
-- 4. Repartition portuaire : RPC dediee (la sous-cle 'port' est economique, elle n'entre pas
--    dans la liste blanche ci-dessus). Seul le pourcentage de ventilation est ecrit ; le stock,
--    les arrivages, les exportations et la caisse du port restent intouchables par ce chemin.
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fixer_repartition_port(
  p_cle text, p_capitale numeric, p_ville_a numeric, p_ville_b numeric)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id text := 'republic_ville_a_port-sainte-marie';
        v_data jsonb; v_etat jsonb; v_port jsonb;
BEGIN
  PERFORM public.exiger_poste('capitaine_port');

  IF p_cle IS NULL OR NOT EXISTS (SELECT 1 FROM public.ressources_economie WHERE cle = p_cle) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue');
  END IF;
  IF p_capitale IS NULL OR p_ville_a IS NULL OR p_ville_b IS NULL
     OR p_capitale < 0 OR p_ville_a < 0 OR p_ville_b < 0
     OR abs((p_capitale + p_ville_a + p_ville_b) - 100) > 0.1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'repartition_invalide');
  END IF;

  SELECT data INTO v_data FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'port_absent'); END IF;

  v_etat := COALESCE(public.batiment_etat_lire(v_data), '{}'::jsonb);
  v_port := COALESCE(v_etat->'port', '{}'::jsonb);
  v_port := jsonb_set(v_port, ARRAY['repartition'],
              COALESCE(v_port->'repartition', '{}'::jsonb), true);
  v_port := jsonb_set(v_port, ARRAY['repartition', p_cle],
              jsonb_build_object('capitale', p_capitale, 'ville_a', p_ville_a,
                                 'ville_b', p_ville_b), true);
  v_etat := jsonb_set(v_etat, ARRAY['port'], v_port, true);

  UPDATE public.batiments_etat SET data = to_jsonb(v_etat::text), updated_at = now()
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'repartition', v_port->'repartition'->p_cle);
END; $$;

-- ---------------------------------------------------------------------------------------------
-- 5. Fermeture de la table. La lecture reste ouverte (81 sites de lecture cote client, aucune
--    donnee privee dans ce blob) ; l'ecriture directe disparait pour anon et authenticated.
--    Le cron passe par service_role, les RPC ci-dessus par SECURITY DEFINER.
-- ---------------------------------------------------------------------------------------------
ALTER TABLE public.batiments_etat ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow anon insert" ON public.batiments_etat;
DROP POLICY IF EXISTS "batiments_etat lecture publique" ON public.batiments_etat;
CREATE POLICY "batiments_etat lecture publique" ON public.batiments_etat FOR SELECT USING (true);

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.batiments_etat FROM anon, authenticated;

-- Piege Supabase deja rencontre trois fois : ALTER DEFAULT PRIVILEGES accorde EXECUTE a anon
-- sur toute nouvelle fonction publique. REVOKE ... FROM PUBLIC ne suffit pas, il faut nommer anon.
REVOKE EXECUTE ON FUNCTION public.jsonb_cle_economique_presente(jsonb) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.jsonb_cles_hors_liste(jsonb, text[]) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.batiment_etat_sous_cle_ecrire(text, text, text, text, jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fixer_repartition_port(text, numeric, numeric, numeric) TO anon, authenticated;
