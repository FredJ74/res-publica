-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010092658 (UTC), nom `bne_quatre_actes_une_transaction_chacun`.
-- Le registre passe de 609 a 610 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 5e0bc0510e12bba3066ffbb6aa42e5a1, 7514 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- CHANTIER 5, CHAINE 20 : LES QUATRE ACTES DU BNE
--
-- `bne_agir` est UNE porte pour les quatre chemins, parce que les quatre font la meme chose :
-- muter le blob partage des affectations sous verrou, apres avoir relu le plafond dans le miroir.
-- `p_acte` est une liste CLOSE (prendre, reserver, trancher_garder, trancher_prendre,
-- demissionner). Aucune regle de jeu n'est modifiee ; ce qui change, c'est que le plafond est relu
-- DANS la transaction et que le blob est verrouille.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CHANTIER 5, CHAINE 20 -- LES QUATRE ACTES DU BNE (10 octobre 2026)
--
-- UNE SEULE PORTE POUR LES QUATRE CHEMINS, parce que les quatre font exactement la meme chose :
-- muter le blob partage des affectations sous verrou, apres avoir relu le plafond dans le miroir.
-- Le navigateur avait quatre fois la meme lecture-modification-ecriture.
--
-- `p_acte` est une liste CLOSE : 'prendre', 'reserver', 'trancher_garder', 'trancher_prendre',
-- 'demissionner'. Aucun autre n'est accepte.
--
-- AUCUNE REGLE DE JEU N'EST MODIFIEE : meme forme de blob (`{ <offre>: [ { pjNom, statut } ] }`),
-- memes trois statuts ('actif', 'en_attente_arbitrage'), meme plafond, meme interdiction de
-- postuler avec une candidature deja en attente, meme conservation du poste actuel pendant
-- l'arbitrage. Ce qui change : le plafond est relu DANS LA TRANSACTION, et le blob est verrouille.

CREATE OR REPLACE FUNCTION public.bne_agir(
  p_acte text, p_offre text, p_offre_ancienne text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE
  v_moi text; v_pays text; v_id text; v_etat jsonb; v_offres jsonb;
  v_places integer; v_prises integer; v_actuel text; v_n integer; v_liste jsonb;
BEGIN
  IF p_acte NOT IN ('prendre','reserver','trancher_garder','trancher_prendre','demissionner') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acte_inconnu');
  END IF;
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pays_inconnu'); END IF;

  -- LE BLOB EST PARTAGE : il porte les affectations de TOUS les joueurs. Verrou de ligne.
  v_id := v_pays || '_national_bne';
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat
   WHERE id = v_id FOR UPDATE;
  v_offres := CASE WHEN jsonb_typeof(coalesce(v_etat,'{}'::jsonb) -> 'offres') = 'object'
                   THEN v_etat -> 'offres' ELSE '{}'::jsonb END;

  -- L'EMPLOI ACTUEL ET LA RESERVATION EN ATTENTE, LUS DANS LE BLOB VERROUILLE.
  SELECT cle INTO v_actuel FROM (
    SELECT o.key AS cle FROM jsonb_each(v_offres) o,
           jsonb_array_elements(CASE WHEN jsonb_typeof(o.value)='array' THEN o.value ELSE '[]'::jsonb END) e
     WHERE e ->> 'pjNom' = v_moi AND e ->> 'statut' = 'actif' LIMIT 1) z;

  IF p_acte IN ('prendre','reserver') THEN
    IF EXISTS (SELECT 1 FROM jsonb_each(v_offres) o,
                 jsonb_array_elements(CASE WHEN jsonb_typeof(o.value)='array' THEN o.value ELSE '[]'::jsonb END) e
                WHERE e ->> 'pjNom' = v_moi AND e ->> 'statut' = 'en_attente_arbitrage') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'arbitrage_en_attente');
    END IF;

    -- LE PLAFOND VIENT DU MIROIR, PAS DU CLIENT, ET IL EST LU DANS LA TRANSACTION.
    SELECT places INTO v_places FROM public.offres_emploi_bne WHERE id = p_offre;
    IF v_places IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'offre_inconnue');
    END IF;
    SELECT count(*) INTO v_prises
      FROM jsonb_array_elements(
             CASE WHEN jsonb_typeof(v_offres -> p_offre)='array'
                  THEN v_offres -> p_offre ELSE '[]'::jsonb END) e
     WHERE e ->> 'statut' IN ('actif','en_attente_arbitrage');
    IF v_prises >= v_places THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'poste_complet',
                                'places', v_places, 'prises', v_prises);
    END IF;
    IF v_actuel IS NOT NULL AND v_actuel = p_offre THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'deja_en_poste');
    END IF;

    v_liste := CASE WHEN jsonb_typeof(v_offres -> p_offre)='array'
                    THEN v_offres -> p_offre ELSE '[]'::jsonb END;
    v_liste := v_liste || jsonb_build_array(jsonb_build_object(
      'pjNom', v_moi,
      'statut', CASE WHEN v_actuel IS NULL THEN 'actif' ELSE 'en_attente_arbitrage' END));
    v_offres := jsonb_set(v_offres, ARRAY[p_offre], v_liste, true);

  ELSIF p_acte = 'trancher_garder' THEN
    -- La reservation en attente est liberee, le poste actuel est conserve.
    v_liste := (SELECT coalesce(jsonb_agg(e), '[]'::jsonb)
                  FROM jsonb_array_elements(
                         CASE WHEN jsonb_typeof(v_offres -> p_offre)='array'
                              THEN v_offres -> p_offre ELSE '[]'::jsonb END) e
                 WHERE NOT (e ->> 'pjNom' = v_moi AND e ->> 'statut' = 'en_attente_arbitrage'));
    v_offres := jsonb_set(v_offres, ARRAY[p_offre], v_liste, true);

  ELSIF p_acte = 'trancher_prendre' THEN
    -- L'ancien poste est quitte, la reservation devient active.
    IF p_offre_ancienne IS NOT NULL
       AND EXISTS (SELECT 1 FROM public.offres_emploi_bne WHERE id = p_offre_ancienne) THEN
      v_liste := (SELECT coalesce(jsonb_agg(e), '[]'::jsonb)
                    FROM jsonb_array_elements(
                           CASE WHEN jsonb_typeof(v_offres -> p_offre_ancienne)='array'
                                THEN v_offres -> p_offre_ancienne ELSE '[]'::jsonb END) e
                   WHERE NOT (e ->> 'pjNom' = v_moi AND e ->> 'statut' = 'actif'));
      v_offres := jsonb_set(v_offres, ARRAY[p_offre_ancienne], v_liste, true);
    END IF;
    v_liste := (SELECT coalesce(jsonb_agg(
                   CASE WHEN e ->> 'pjNom' = v_moi AND e ->> 'statut' = 'en_attente_arbitrage'
                        THEN e || jsonb_build_object('statut','actif') ELSE e END), '[]'::jsonb)
                  FROM jsonb_array_elements(
                         CASE WHEN jsonb_typeof(v_offres -> p_offre)='array'
                              THEN v_offres -> p_offre ELSE '[]'::jsonb END) e);
    v_offres := jsonb_set(v_offres, ARRAY[p_offre], v_liste, true);

  ELSE  -- demissionner
    IF v_actuel IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'aucun_emploi');
    END IF;
    v_liste := (SELECT coalesce(jsonb_agg(e), '[]'::jsonb)
                  FROM jsonb_array_elements(
                         CASE WHEN jsonb_typeof(v_offres -> v_actuel)='array'
                              THEN v_offres -> v_actuel ELSE '[]'::jsonb END) e
                 WHERE NOT (e ->> 'pjNom' = v_moi AND e ->> 'statut' = 'actif'));
    v_offres := jsonb_set(v_offres, ARRAY[v_actuel], v_liste, true);
  END IF;

  INSERT INTO public.batiments_etat (id, country, city, building_id, data, updated_at)
  VALUES (v_id, v_pays, 'national', 'bne',
          to_jsonb((coalesce(v_etat,'{}'::jsonb) || jsonb_build_object('offres', v_offres))::text),
          now())
  ON CONFLICT (id) DO UPDATE SET data = excluded.data, updated_at = now();

  -- L'EMPLOI ACTUEL RELU APRES MUTATION : c'est lui que le client recopie dans son cache.
  SELECT cle INTO v_actuel FROM (
    SELECT o.key AS cle FROM jsonb_each(v_offres) o,
           jsonb_array_elements(CASE WHEN jsonb_typeof(o.value)='array' THEN o.value ELSE '[]'::jsonb END) e
     WHERE e ->> 'pjNom' = v_moi AND e ->> 'statut' = 'actif' LIMIT 1) z;

  RETURN jsonb_build_object('ok', true, 'acte', p_acte, 'offres', v_offres,
                            'emploi_actuel', v_actuel);
END; $fn$;

REVOKE ALL ON FUNCTION public.bne_agir(text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.bne_agir(text, text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.bne_agir(text, text, text) TO authenticated, service_role;
