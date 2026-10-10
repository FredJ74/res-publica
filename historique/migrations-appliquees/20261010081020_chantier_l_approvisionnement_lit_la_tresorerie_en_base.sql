-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010081020 (UTC), nom `chantier_l_approvisionnement_lit_la_tresorerie_en_base`.
-- Le registre passe de 598 a 599 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 dac4a6950ec3329cf51ee0b41187f96d, 6141 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- CHANTIER : L'APPROVISIONNEMENT LIT LA TRESORERIE EN BASE
--
-- Deux defauts, dont un que l'inventaire ne nommait pas. (1) `approvisionner_chantier` debite
l'ENTREPOT dans sa transaction, mais la contrepartie cote chantier ne vivait que dans le
`sbSetTerrainState` avale qui suivait : perdue, la marchandise etait DETRUITE. Et le repli
`|| { depense: 0 }` presentait une panne de RPC comme « rien a acheter ». (2) PLUS GRAVE : le
navigateur transmettait lui-meme `p_tresorerie`, qui BORNE le pouvoir d'achat -- un client
modifie annoncant une tresorerie enorme pouvait vider l'entrepot sans rien payer.
`chantier_approvisionner(terrain, cle, entrepot, besoin, jour)` lit le chantier DANS LE BLOB du
terrain sous verrou, delegue au moteur, puis ecrit la contrepartie dans la meme transaction ; et
elle verifie que le terrain est bien celui de l'acteur. `approvisionner_chantier` perd son droit
d'EXECUTE pour `authenticated`.
--
-- ELLE VA PAR PAIRE AVEC : `plateau-justice-economie.js` (`confirmerConstruction`, `confirmerReconfiguration`).
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CHANTIER 5, CHAINE 5 -- L'APPROVISIONNEMENT D'UN CHANTIER (10 octobre 2026)
--
-- DEUX DEFAUTS, DONT UN PLUS GRAVE QUE CELUI DE L'INVENTAIRE.
--
-- 1. CELUI QUE L'INVENTAIRE NOMMAIT. approvisionner_chantier DEBITE L'ENTREPOT dans sa propre
--    transaction, mais la contrepartie cote chantier -- le stock livre et la tresorerie depensee --
--    ne vivait que dans un `sbSetTerrainState(...).catch(() => {})` qui suivait. Perdue, la
--    marchandise etait DETRUITE : l'entrepot avait vendu, le chantier n'avait rien recu, et sa
--    tresorerie n'avait rien paye. Le repli `|| { depense: 0 }` ajoutait sa part : une panne de la
--    RPC se presentait comme « rien a acheter », donc comme un succes.
--
-- 2. CELUI QUE L'INSPECTION A TROUVE, ET IL EST PIRE. Le client transmettait lui-meme
--    p_tresorerie et p_stock_chantier. Or c'est p_tresorerie qui borne le pouvoir d'achat :
--    `v_abordable := floor((p_tresorerie - v_depense) / v_prix)`. Un client modifie annoncant une
--    tresorerie enorme pouvait donc VIDER L'ENTREPOT sans rien payer -- le debit du chantier,
--    lui, n'etait jamais ecrit par le serveur. Le commentaire du chantier C l'assumait comme une
--    limite (« ils vivent dans terrains_etat, que ce lot ne migre pas ») ; terrains_etat est
--    desormais lu en SQL, donc la limite tombe.
--
-- CE QUE LA PORTE FAIT. Elle lit le chantier DANS LE BLOB DU TERRAIN, sous verrou -- stock et
-- tresorerie compris -- delegue a approvisionner_chantier, qui reste l'unique moteur du cote
-- entrepot, puis ecrit la contrepartie dans le meme blob et la meme transaction. Le client ne
-- transmet plus que ce qui n'est pas une autorite : le besoin du jour (une formule, bornee de
-- toute facon par le stock reel et la tresorerie reelle) et le jour de jeu de l'evenement.
--
-- ELLE VERIFIE AUSSI LA PROPRIETE : seul le proprietaire du terrain approvisionne son chantier.
-- Rien n'empechait un tiers de le faire.
--
-- AUCUNE REGLE DE JEU N'EST MODIFIEE : memes trois materiaux dans le meme ordre, memes prix lus
-- dans le miroir, meme reserve militaire opposable, meme evenement 'approvisionnement'. Les deux
-- familles de chantier -- construction et reamenagement -- passent par la meme porte, la ou le
-- navigateur avait deux fois le meme code.

CREATE OR REPLACE FUNCTION public.chantier_approvisionner(
  p_terrain_id text, p_cle_chantier text, p_entrepot text, p_besoin jsonb,
  p_jour integer DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE
  v_moi text; v_cle text; v_data jsonb; v_ch jsonb; v_pays text; v_ville text;
  v_plan jsonb; v_dep numeric; v_evts jsonb;
BEGIN
  IF p_cle_chantier NOT IN ('chantier','chantierReamenagement') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chantier_inconnu');
  END IF;
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT t.id, t.data::jsonb, t.country INTO v_cle, v_data, v_pays
    FROM public.terrains_etat t
   WHERE t.id = p_terrain_id OR t.building_id = p_terrain_id
   ORDER BY (t.id = p_terrain_id) DESC LIMIT 1 FOR UPDATE;
  IF v_cle IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'terrain_introuvable'); END IF;
  v_data := coalesce(v_data, '{}'::jsonb);

  -- SEUL LE PROPRIETAIRE APPROVISIONNE SON CHANTIER. Rien ne le verifiait.
  IF (v_data ->> 'proprietaire') IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_terrain');
  END IF;

  v_ch := v_data -> p_cle_chantier;
  IF v_ch IS NULL OR jsonb_typeof(v_ch) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_chantier');
  END IF;
  v_ville := coalesce(nullif(v_data ->> 'city', ''), 'capitale');

  -- LE STOCK ET LA TRESORERIE VIENNENT DE LA BASE, PLUS DU NAVIGATEUR. C'est le second defaut.
  v_plan := public.approvisionner_chantier(
    v_moi, v_pays, v_ville, p_entrepot, coalesce(p_besoin, '{}'::jsonb),
    coalesce(v_ch -> 'stockMateriaux', '{}'::jsonb),
    greatest(0, coalesce((v_ch ->> 'tresorerie')::numeric, 0)));
  IF NOT coalesce((v_plan ->> 'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison',
                              coalesce(v_plan ->> 'raison','approvisionnement_refuse'));
  END IF;
  v_dep := coalesce((v_plan ->> 'depense')::numeric, 0);

  -- LA CONTREPARTIE, DANS LA MEME TRANSACTION QUE LE DEBIT DE L'ENTREPOT.
  IF v_dep > 0 THEN
    v_evts := CASE WHEN jsonb_typeof(v_ch -> 'evenements') = 'array'
                   THEN v_ch -> 'evenements' ELSE '[]'::jsonb END;
    v_evts := v_evts || jsonb_build_array(jsonb_build_object(
      'cle', 'approvisionnement', 'jour', coalesce(p_jour, 1),
      'achats', v_plan -> 'achats', 'cout', v_dep));
    v_ch := v_ch
      || jsonb_build_object('stockMateriaux', v_plan -> 'stockChantier',
           'tresorerie', greatest(0, coalesce((v_ch ->> 'tresorerie')::numeric, 0) - v_dep),
           'evenements', v_evts);
    v_data := jsonb_set(v_data, ARRAY[p_cle_chantier], v_ch, true);
    UPDATE public.terrains_etat SET data = v_data::text, updated_at = now() WHERE id = v_cle;
  END IF;

  RETURN jsonb_build_object('ok', true, 'depense', v_dep, 'achats', v_plan -> 'achats',
    'cle', v_cle, 'chantier', v_ch);
END; $fn$;

REVOKE ALL ON FUNCTION public.chantier_approvisionner(text, text, text, jsonb, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.chantier_approvisionner(text, text, text, jsonb, integer) FROM anon;
GRANT EXECUTE ON FUNCTION public.chantier_approvisionner(text, text, text, jsonb, integer)
  TO authenticated, service_role;

-- L'ANCIEN CHEMIN EST FERME AU NAVIGATEUR. approvisionner_chantier reste le moteur du cote
-- entrepot, mais elle n'est plus appelable directement par un client : c'etait par elle que la
-- tresorerie dictee passait. Elle demeure accessible au serveur et a la porte ci-dessus (qui la
-- traverse en SECURITY DEFINER appartenant a postgres).
REVOKE EXECUTE ON FUNCTION
  public.approvisionner_chantier(text, text, text, text, jsonb, jsonb, numeric)
  FROM authenticated;