-- =====================================================================================
-- REMISE SOUS VERSION DE batiment_etat_sous_cle_ecrire -- SANS AUCUN CHANGEMENT DE COMPORTEMENT
-- 26 septembre 2026
--
-- POURQUOI CE FICHIER EXISTE. La fonction tourne en production depuis le Chantier C
-- (commit 859b0f6, 13 septembre 2026) mais son corps n'a JAMAIS ete versionne : aucun
-- fichier du depot, ni a la racine ni dans .scratch/, ne la contient. Seul le banc
-- .scratch/banc_fermeture_batiments_etat.py l'appelle. L'autorite serveur de la police et
-- des douanes n'etait donc pas reconstructible depuis le depot -- anomalie de
-- reproductibilite, pas de securite.
--
-- CE FICHIER NE CHANGE RIEN. Le corps ci-dessous est la transcription EXACTE de
-- pg_get_functiondef() releve en production le 26 septembre 2026 (8781 caracteres).
-- L'appliquer est un no-op strict, verifiable en comparant pg_get_functiondef() avant et
-- apres. Aucune correction, aucun ajout de garde, aucun renommage n'a ete glisse ici :
-- les defauts connus (voir plus bas) sont laisses EN PLACE, volontairement, pour qu'un
-- eventuel correctif soit un commit distinct et relisible.
--
-- DEPENDANCES (toutes deja en production) :
--   public.est_appel_serveur()
--   public.jsonb_cle_economique_presente(jsonb)
--   public.jsonb_cles_hors_liste(jsonb, text[])
--   public.batiment_etat_lire(jsonb)
--   table public.batiments_etat (id, country, city, building_id, data, updated_at)
--
-- DROITS EN PRODUCTION (a ne pas modifier ici) :
--   prosecdef = true (SECURITY DEFINER), proprietaire postgres
--   proacl    = {postgres=X, authenticated=X, service_role=X}   -- anon absent, correct
--   table batiments_etat : authenticated a SELECT seulement (rxtm), policy de lecture
--                          publique ; aucune ecriture directe possible depuis le client.
--
-- USAGES CONNUS :
--   client  : supabase.js sbSetBatimentEtat() -> 7 sous-cles
--             (blocus, effectifsPolice, effectifsDouane, candidatures, parCaisse,
--              controles, offres)
--   serveur : appels avec est_appel_serveur() vrai, qui court-circuitent le bloc
--             d'autorite mais PAS les validations de forme.
--   banc    : .scratch/banc_fermeture_batiments_etat.py (D1/D2/D3, E4)
--
-- A SAVOIR POUR LA SUITE, constate en lisant ce corps -- aucun de ces points n'est
-- corrige ici :
--   1) data est du JSON DOUBLEMENT ENCODE : l'ecriture fait to_jsonb(v_etat::text), donc
--      jsonb_typeof(data::jsonb) vaut 'string'. Toute requete doit passer par
--      ((data::jsonb)#>>'{}')::jsonb ou par batiment_etat_lire(). C'est ce piege qui m'a
--      fait annoncer a tort « 0 douanier en production ».
--   2) La validation ne porte que sur la FORME, le POSTE et des BORNES -- jamais sur la
--      quantite ni sur le processus : un commissaire peut ecrire jusqu'a 200 policiers a
--      PER/VOL = 100 en une seule requete acceptee. Modele d'autorite d'une generation en
--      retard sur le militaire post-21/09.
--   3) 'effectifsDouane' exige le poste chef_douanes, alors que la paye de ces memes
--      douaniers exige min_int sur gouvernement-min_int : deux postes mutuellement
--      exclusifs, d'ou la paye refusee depuis le 12 septembre. Le correctif fait l'objet
--      d'une proposition separee (RPC metier dediee), pas de ce fichier.

CREATE OR REPLACE FUNCTION public.batiment_etat_sous_cle_ecrire(p_pays text, p_ville text, p_batiment text, p_sous_cle text, p_valeur jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id text; v_serveur boolean; v_poste jsonb; v_moi text;
  v_data jsonb; v_etat jsonb; v_mauvaise text; v_el jsonb; v_sous jsonb; v_n numeric;
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
             OR public.jsonb_cles_hors_liste(v_el->'stats', ARRAY['PER','VOL']) IS NOT NULL THEN
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
END; $function$;

-- Droits : rien a reposer, ils sont deja corrects en production. Lignes laissees en
-- commentaire pour qu'une reconstruction a neuf de la base les retrouve.
-- REVOKE ALL ON FUNCTION public.batiment_etat_sous_cle_ecrire(text,text,text,text,jsonb) FROM PUBLIC, anon;
-- GRANT EXECUTE ON FUNCTION public.batiment_etat_sous_cle_ecrire(text,text,text,text,jsonb) TO authenticated, service_role;
