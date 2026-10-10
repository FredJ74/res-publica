-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010123828 (UTC), nom `terrain_la_porte_du_decoupage_en_lots`.
-- Le registre passe de 618 a 619 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 43704705d5dd7fce38ff305864d86482, 8473 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- L'ETAT D'UN TERRAIN -- 4/4 : LE DECOUPAGE EN LOTS
--
-- Six des dix-neuf `sbSetTerrainState` avales sont ici, et elles sont le cas d'ecole du
-- dernier-ecrivain-gagnant : toutes reecrivaient le tableau `subdivisions` ENTIER depuis le cache
-- du navigateur, alors que trois acteurs le touchent (proprietaire, locataire, visiteur signant un
-- bail). La porte ne prend plus le tableau mais les lots a poser et les identifiants a retirer,
-- fusionnes par `lot.id` sous verrou ; elle verifie l'AUTORITE par acte, jamais le verdict de
-- decoupage, qui reste le verdict unique de plateau-immobilier.js.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- L'ETAT D'UN TERRAIN -- 4/4 : LE DECOUPAGE EN LOTS
-- Chantier 5, les 19 `sbSetTerrainState` avales (10 octobre 2026).
--
-- SIX DES DIX-NEUF ECRITURES SONT ICI, et elles sont le cas d'ecole du DERNIER-ECRIVAIN-GAGNANT :
-- toutes faisaient `setTerrainState(id, { subdivisions: subdivisions })` avec le TABLEAU ENTIER
-- relu dans le cache du navigateur. Or ce tableau est touche par TROIS acteurs differents :
--
--   * le PROPRIETAIRE cree un lot, ou propose d'en agrandir un (deux ecritures) ;
--   * le LOCATAIRE accepte ou refuse cet agrandissement (deux ecritures) ;
--   * un VISITEUR signe un bail, ce qui pose `lot.locataire` (une ecriture) ;
--   * et la fin d'un bail libere ce meme champ (une ecriture de plus, dans plateau-immobilier.js,
--     la seule des dix-neuf qui n'etait meme pas attendue).
--
-- Deux de ces acteurs agissant dans la meme minute, le second ecrasait le premier -- un lot cree
-- disparaissait, ou un locataire revenait d'entre les morts. Et comme l'ecriture etait avalee,
-- personne ne le voyait.
--
-- LA PORTE NE PREND PLUS LE TABLEAU : elle prend LES LOTS A POSER et LES IDENTIFIANTS A RETIRER,
-- et les fusionne par `lot.id` dans le tableau relu sous verrou. Deux acteurs qui touchent deux
-- lots differents ne se detruisent plus ; deux acteurs qui touchent le MEME lot se serialisent.
--
-- CE QU'ELLE NE FAIT PAS : elle ne refait aucun verdict de decoupage. `verdictAjoutLot`,
-- `peutDiviser`, `surfaceTerrainConnue`, `batimentDivisible` sont le VERDICT UNIQUE du jeu et
-- vivent dans plateau-immobilier.js -- les porter ici en ferait une seconde version. Ce que la
-- porte verifie, c'est l'AUTORITE, celle que les ecrans posaient deja :
--   `doOuvrirDivisionTerrain` -> if (!estTitulaire(ts.proprietaire)) « Vous n'etes pas proprietaire »

CREATE OR REPLACE FUNCTION public.terrain_lots_acte(
  p_terrain_id text, p_acte text, p_lots jsonb DEFAULT NULL, p_retirer text[] DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp' AS $fn$
DECLARE
  v_moi text; v_pays text; v_lu jsonb; v_etat jsonb; v_lots jsonb; v_final jsonb;
  v_neuf jsonb; v_lot jsonb; v_remplacant jsonb; v_id text; v_i integer; v_n integer := 0;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_acte NOT IN ('lot_ajouter', 'lot_fusion_proposer', 'lot_fusion_accepter',
                    'lot_fusion_refuser', 'lot_louer', 'lot_bail_libere') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acte_inconnu');
  END IF;
  IF p_lots IS NOT NULL AND jsonb_typeof(p_lots) <> 'array' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'lots_invalides');
  END IF;
  IF coalesce(jsonb_array_length(coalesce(p_lots, '[]'::jsonb)), 0) = 0
     AND coalesce(array_length(p_retirer, 1), 0) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'rien_a_ecrire');
  END IF;
  SELECT d.country INTO v_pays FROM public.personnages_donnees d WHERE d.name = v_moi LIMIT 1;

  v_lu := public.terrain_etat_verrouiller_interne(p_terrain_id);
  v_etat := v_lu -> 'etat';
  IF (v_lu ->> 'gele')::boolean THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'terrain_gele');
  END IF;
  v_lots := coalesce(v_etat -> 'subdivisions', '[]'::jsonb);
  IF jsonb_typeof(v_lots) <> 'array' THEN v_lots := '[]'::jsonb; END IF;

  -- AUTORITE PAR ACTE. Les deux actes du proprietaire passent par le jumeau SQL de `estTitulaire`,
  -- qui reconnait `pj:<nom>` comme la chaine nue. Les autres sont le fait du locataire ou du
  -- visiteur : les ecrans ne leur demandaient rien d'autre que de concerner leur propre lot, et
  -- c'est ce que la porte verifie lot par lot.
  IF p_acte IN ('lot_ajouter', 'lot_fusion_proposer') THEN
    IF NOT public.titulaire_est_moi(v_etat ->> 'proprietaire') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire');
    END IF;
  ELSIF p_acte IN ('lot_fusion_accepter', 'lot_fusion_refuser') THEN
    FOR v_lot IN SELECT * FROM jsonb_array_elements(coalesce(p_lots, '[]'::jsonb)) LOOP
      v_id := v_lot ->> 'id';
      IF NOT EXISTS (
        SELECT 1 FROM jsonb_array_elements(v_lots) e
         WHERE (e.value ->> 'id') = v_id
           AND (e.value -> 'propositionAgrandissement') IS NOT NULL
           AND public.titulaire_est_moi(e.value ->> 'locataire')) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'aucune_proposition_sur_mon_lot', 'lot', v_id);
      END IF;
    END LOOP;
  ELSIF p_acte = 'lot_louer' THEN
    -- Le bail est pris ATOMIQUEMENT ailleurs (`locations_actives`, cle primaire). Cette ecriture
    -- n'est que le miroir transitoire que le cron des loyers lit encore : la porte verifie donc
    -- seulement que le locataire pose est bien l'appelant.
    FOR v_lot IN SELECT * FROM jsonb_array_elements(coalesce(p_lots, '[]'::jsonb)) LOOP
      IF NOT public.titulaire_est_moi(v_lot ->> 'locataire') THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_bail', 'lot', v_lot ->> 'id');
      END IF;
    END LOOP;
  ELSIF p_acte = 'lot_bail_libere' THEN
    -- Fin de bail : le miroir se vide. Le champ pose doit etre NUL -- on ne liberera jamais un lot
    -- en y INSTALLANT quelqu'un.
    FOR v_lot IN SELECT * FROM jsonb_array_elements(coalesce(p_lots, '[]'::jsonb)) LOOP
      IF nullif(btrim(coalesce(v_lot ->> 'locataire', '')), '') IS NOT NULL THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'liberation_qui_installe', 'lot', v_lot ->> 'id');
      END IF;
    END LOOP;
  END IF;

  -- FUSION PAR IDENTIFIANT DE LOT. Un lot dont l'identifiant existe est REMPLACE ; sinon il est
  -- ajoute. Les identifiants de `p_retirer` disparaissent. Le reste du tableau n'est pas touche.
  v_neuf := '[]'::jsonb;
  FOR v_i IN 0 .. greatest(0, jsonb_array_length(v_lots) - 1) LOOP
    v_lot := v_lots -> v_i;
    v_id := v_lot ->> 'id';
    IF v_id IS NOT NULL AND p_retirer IS NOT NULL AND v_id = ANY (p_retirer) THEN
      v_n := v_n + 1;
      CONTINUE;
    END IF;
    IF v_id IS NOT NULL THEN
      v_remplacant := NULL;
      SELECT e.value INTO v_remplacant FROM jsonb_array_elements(coalesce(p_lots, '[]'::jsonb)) e
       WHERE (e.value ->> 'id') = v_id LIMIT 1;
      IF v_remplacant IS NOT NULL THEN v_lot := v_remplacant; END IF;
    END IF;
    v_neuf := v_neuf || jsonb_build_array(v_lot);
  END LOOP;
  -- Les lots envoyes qui n'existaient pas encore sont AJOUTES, dans l'ordre d'arrivee.
  FOR v_lot IN SELECT * FROM jsonb_array_elements(coalesce(p_lots, '[]'::jsonb)) LOOP
    IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_neuf) e
                    WHERE (e.value ->> 'id') = (v_lot ->> 'id')) THEN
      v_neuf := v_neuf || jsonb_build_array(v_lot);
    END IF;
  END LOOP;

  v_final := public.terrain_etat_fusionner_interne(p_terrain_id,
               jsonb_build_object('subdivisions', v_neuf), v_pays);
  RETURN jsonb_build_object('ok', true, 'acte', p_acte, 'etat', v_final,
    'lots', v_neuf, 'retires', v_n);
END; $fn$;

REVOKE ALL ON FUNCTION public.terrain_lots_acte(text, text, jsonb, text[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.terrain_lots_acte(text, text, jsonb, text[]) TO authenticated, service_role;

DO $p$
DECLARE v_def text;
BEGIN
  IF NOT has_function_privilege('authenticated',
        'public.terrain_lots_acte(text,text,jsonb,text[])'::regprocedure, 'EXECUTE')
     OR has_function_privilege('anon',
        'public.terrain_lots_acte(text,text,jsonb,text[])'::regprocedure, 'EXECUTE') THEN
    RAISE EXCEPTION 'les droits de la porte des lots sont faux';
  END IF;
  v_def := pg_get_functiondef('public.terrain_lots_acte(text,text,jsonb,text[])'::regprocedure);
  IF v_def LIKE '%p_subdivisions%' THEN
    RAISE EXCEPTION 'la porte des lots accepte encore le tableau entier';
  END IF;
  IF v_def NOT LIKE '%titulaire_est_moi%' THEN
    RAISE EXCEPTION 'la porte des lots ne verifie aucune autorite';
  END IF;
  IF v_def NOT LIKE '%aucune_proposition_sur_mon_lot%' OR v_def NOT LIKE '%pas_mon_bail%'
     OR v_def NOT LIKE '%liberation_qui_installe%' THEN
    RAISE EXCEPTION 'les refus par acte de la porte des lots sont incomplets';
  END IF;
  IF v_def LIKE '%UPDATE public.terrains_etat%' OR v_def LIKE '%INSERT INTO public.terrains_etat%' THEN
    RAISE EXCEPTION 'la porte des lots ecrit la table directement';
  END IF;
  RAISE NOTICE 'Les 5 preuves structurelles de la porte des lots sont vertes.';
END $p$;
