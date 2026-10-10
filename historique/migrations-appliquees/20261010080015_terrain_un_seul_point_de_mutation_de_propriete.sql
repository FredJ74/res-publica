-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010080015 (UTC), nom `terrain_un_seul_point_de_mutation_de_propriete`.
-- Le registre passe de 596 a 597 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 bb1caec7f63b21be25a2214312db203f, 6730 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- TERRAIN : UN SEUL POINT DE MUTATION DE PROPRIETE
--
-- L'inventaire a trouve TROIS portes d'entree pour un seul acte. `finaliserAchatTerrain` est la
mutation centrale, et le solde du prix etait deja parti cote serveur quand son ecriture, avalee,
pouvait echouer : L'ACHETEUR PAYAIT ET NE RECEVAIT RIEN. L'historique public de la vente, avale
lui aussi et portant un `Date.now()`, pouvait acter une vente inexistante -- deux fois.
`terrain_proprietaire_muter(terrain, titre, patch, reference)` change le contrat : le client
transmet un PATCH, fusionne par le serveur sur l'etat REEL lu sous verrou. Deux defauts
disparaissent avec le blob -- le patch partiel qui ecrase tout, et le cache perime qui ecrase le
serveur. Elle verifie le TITRE invoque, refuse un terrain gele par une succession, et DATE
l'identifiant de la vente pour qu'un rejeu n'en cree pas une seconde.
--
-- CE QUI RESTE OUVERT, ET C'EST DIT : `terrains_etat` demeure accessible en ecriture a
-- `authenticated`. Cette surface fait partie des « 37 tables a resserrer », hors de ce lot.
--
-- ELLE VA PAR PAIRE AVEC : `plateau-pnj.js` (`finaliserAchatTerrain`, qui gagne un titre et une purge),
-- `plateau-justice-economie.js` (les deux branches de `traiterActeVente` ; suppression de
-- `accepterRachat`, SANS APPELANT, qui creditait le vendeur par un `state.arg += prix` client) et
-- `plateau-organisations-quetes.js` (`remettreRecompenseQuete`, qui envoyait QUATRE CLES a une
-- primitive ecrivant le blob entier -- le terrain gagne perdait surface, valeur et ville).
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CHANTIER 5, GROUPE « MUTER LE PROPRIETAIRE D'UN TERRAIN » (10 octobre 2026)
--
-- L'INVENTAIRE A DIT TROIS PORTES D'ENTREE POUR UN SEUL ACTE, et chacune avait son defaut.
--   . plateau-pnj.js:4385, finaliserAchatTerrain -- la mutation centrale, atteinte par les DEUX
--     branches d'achat. Le solde du prix est deja parti cote serveur (deduireCoutOrdre ->
--     payer_ordre) quand l'ecriture arrive, et elle est avalee : L'ACHETEUR PAIE ET NE RECOIT
--     RIEN. L'historique public de la vente, ecrit juste apres et avale lui aussi, pouvait de son
--     cote acter une vente qui n'existe pas.
--   . plateau-justice-economie.js:285, accepterRachat -- SANS AUCUN APPELANT (mesure faite sur
--     tout le depot). Fonction morte qui annoncait « Terrain vendu ! », envoyait un courrier de
--     transfert, et creditait le vendeur cote client.
--   . plateau-organisations-quetes.js:365, remettreRecompenseQuete -- envoyait a sbSetTerrainState
--     un objet de QUATRE CLES. Or sbSetTerrainState ecrit `data` EN ENTIER : ce terrain perdait
--     surface, valeur, ville et tout le reste. Le correctif de ce patron, revendique ailleurs dans
--     le depot, n'avait jamais ete propage jusqu'ici.
--
-- CE QUE LA PORTE CHANGE, ET C'EST LE POINT D'ARCHITECTURE. Le client ne transmet plus un BLOB
-- ENTIER relu dans son cache, mais un PATCH. La fusion se fait sur l'etat REEL lu en base sous
-- verrou. Deux defauts disparaissent d'un coup : le patch partiel qui ecrase tout, et le blob
-- perime d'un cache client qui ecrase ce que le serveur (cron de minuit, RPC d'un autre joueur) a
-- ecrit entre-temps.
--
-- ET ELLE VERIFIE LE TITRE. Le client declare au nom de quoi il mute, et le serveur le controle :
--   'compromis'        -> le blob porte compromis=true ET compromisPar = l'acteur ;
--   'achat_direct'     -> le blob porte achatDirect.demandeur = l'acteur ;
--   'recompense_quete' -> une quete de p_reference est 'resolue' ET resolu_par = l'acteur ;
--   'serveur'          -> reserve a un appel sans personnage (mon_personnage() IS NULL).
-- Le gel successoral est refuse ici aussi, cote serveur, et plus seulement dans le navigateur.
--
-- CE QUI RESTE OUVERT, ET C'EST DIT. public.terrains_etat demeure accessible en ecriture a
-- `authenticated` : un client pourrait encore muter un terrain sans passer par cette porte. Cette
-- surface fait partie des « 37 tables a resserrer », explicitement hors de ce lot. La porte ferme
-- les trois chemins DU JEU et donne le point unique a partir duquel ce resserrement sera possible.
--
-- AUCUNE REGLE DE JEU N'EST MODIFIEE : memes titres de propriete, meme copropriete conjugale (le
-- client la resout, comme avant, par sbGetMariageActif), memes montants, meme historique public.

CREATE OR REPLACE FUNCTION public.terrain_proprietaire_muter(
  p_terrain_id text, p_titre text, p_patch jsonb, p_reference text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE
  v_moi text; v_data jsonb; v_cle text; v_prix numeric; v_n integer; v_nouveau text;
BEGIN
  IF p_titre NOT IN ('compromis','achat_direct','recompense_quete','serveur') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'titre_inconnu');
  END IF;
  IF p_patch IS NULL OR jsonb_typeof(p_patch) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'patch_invalide');
  END IF;

  v_moi := public.mon_personnage();
  IF p_titre = 'serveur' THEN
    IF v_moi IS NOT NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'titre_reserve_au_serveur');
    END IF;
  ELSIF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT t.id, t.data::jsonb INTO v_cle, v_data FROM public.terrains_etat t
   WHERE t.id = p_terrain_id OR t.building_id = p_terrain_id
   ORDER BY (t.id = p_terrain_id) DESC LIMIT 1 FOR UPDATE;
  IF v_cle IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'terrain_introuvable'); END IF;
  v_data := coalesce(v_data, '{}'::jsonb);

  -- LE GEL SUCCESSORAL EST REFUSE AU SERVEUR, plus seulement dans le navigateur.
  IF coalesce(v_data ->> 'succession_gel', '') <> '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'terrain_gele');
  END IF;

  IF p_titre = 'compromis' THEN
    IF coalesce((v_data ->> 'compromis')::boolean, false) IS NOT TRUE
       OR (v_data ->> 'compromisPar') IS DISTINCT FROM v_moi THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_compromis');
    END IF;
  ELSIF p_titre = 'achat_direct' THEN
    IF (v_data -> 'achatDirect' ->> 'demandeur') IS DISTINCT FROM v_moi THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_achat_direct');
    END IF;
  ELSIF p_titre = 'recompense_quete' THEN
    IF NOT EXISTS (SELECT 1 FROM public.quetes_actives q
                    WHERE q.id = p_reference AND q.statut = 'resolue' AND q.resolu_par = v_moi) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_ma_quete');
    END IF;
  END IF;

  -- LA FUSION SE FAIT SUR L'ETAT REEL, SOUS VERROU : un patch partiel n'efface plus rien, et un
  -- cache client perime ne peut plus ecraser le serveur.
  v_data := v_data || p_patch;
  v_nouveau := nullif(v_data ->> 'proprietaire', '');

  UPDATE public.terrains_etat
     SET data = v_data::text, proprietaire = v_nouveau, updated_at = now()
   WHERE id = v_cle;

  -- L'HISTORIQUE PUBLIC DE LA VENTE, DANS LA MEME TRANSACTION. Son identifiant est DATE et non
  -- horodate a la milliseconde : un rejeu le meme jour sur le meme terrain ne cree pas une seconde
  -- ligne, et le registre ne peut plus acter une vente qui n'a pas eu lieu.
  v_prix := nullif(p_patch ->> 'valeur_totale', '')::numeric;
  IF p_titre IN ('compromis','achat_direct') AND v_prix IS NOT NULL AND v_nouveau IS NOT NULL THEN
    INSERT INTO public.terrains_historique_ventes (id, country, building_id, proprietaire, prix)
    SELECT 'vente-' || t.building_id || '-' || to_char(now() AT TIME ZONE 'UTC','YYYYMMDD')
             || '-' || v_nouveau,
           t.country, t.building_id, v_nouveau, v_prix
      FROM public.terrains_etat t WHERE t.id = v_cle
    ON CONFLICT (id) DO NOTHING;
    GET DIAGNOSTICS v_n = ROW_COUNT;
  ELSE
    v_n := 0;
  END IF;

  RETURN jsonb_build_object('ok', true, 'titre', p_titre, 'cle', v_cle,
    'proprietaire', v_nouveau, 'vente_consignee', v_n = 1, 'etat', v_data);
END; $fn$;

REVOKE ALL ON FUNCTION public.terrain_proprietaire_muter(text, text, jsonb, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.terrain_proprietaire_muter(text, text, jsonb, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.terrain_proprietaire_muter(text, text, jsonb, text)
  TO authenticated, service_role;