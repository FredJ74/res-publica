-- =====================================================================
-- LOT 1.4 — MOTEUR UNIFIE DES LOYERS
-- Enrichissement des baux historiques + RPC transactionnelle de prelevement
-- 6 septembre 2026
-- =====================================================================
-- ⚠️  NON EXECUTEE. Fournie pour relecture.
--
-- ORDRE DE DEPLOIEMENT IMPERATIF : ce fichier D'ABORD, le code ENSUITE.
-- Le moteur est fail-closed : tant que la RPC n'existe pas, il ne preleve rien (echec visible,
-- jamais de mouvement d'argent sur un schema incomplet) ; et tant que les baux historiques ne
-- portent pas destinationLoyer, la RPC les refuse au lieu de deviner ou aller.
--
-- =====================================================================
-- PARTIE 1 — ENRICHISSEMENT DES 7 BAUX HISTORIQUES
-- =====================================================================
-- Au Lot 1.3, localKey / destinationLoyer / orgaAutorisee etaient DERIVES a la lecture cote
-- client. Le moteur serveur ne peut pas s'appuyer sur cette derivation : il faudrait dupliquer
-- en PL/pgSQL la regle metier de plateau-immobilier.js, avec un risque permanent de divergence.
-- Ces trois champs sont donc materialises une fois pour toutes sur les baux existants.
--
-- Etat verifie en LECTURE SEULE avant redaction : 7 lignes, toutes country='republic', toutes au
-- format d'id 'country:buildingId:roomId:city' (migration du Lot 1.3 bis deja appliquee), aucune
-- ne portant destinationLoyer. Aucun box, aucun logement social, aucune chambre de clinique.
--
-- REGLE DE DERIVATION, identique a destinationLoyerPourLocal() (plateau-immobilier.js) :
--   roomId commencant par 'lot_dyn_'  -> {"type":"titulaire_murs"}   (lot prive)
--   data->>'isBox' = true             -> {"type":"caisse_batiment"}  (box portuaire)
--   data->>'chambreClinique' = true   -> null                        (aucun loyer reel)
--   tout le reste                     -> {"type":"municipal"}        (local public/municipal)
-- Les 7 baux tombent tous dans le dernier cas.
--
-- IDEMPOTENCE : le WHERE exclut toute ligne portant deja destinationLoyer.

-- 1.a CONTROLE PREALABLE — a lancer seul (attendu : 7 lignes, destination_calculee='municipal')
SELECT id,
       data ->> 'locataire' AS locataire,
       data ->> 'prix'      AS prix,
       data ? 'destinationLoyer' AS a_deja_destination,
       CASE
         WHEN (data ->> 'chambreClinique') = 'true' THEN 'aucune'
         WHEN (data ->> 'isBox') = 'true'           THEN 'caisse_batiment'
         WHEN (data ->> 'roomId') LIKE 'lot\_dyn\_%' THEN 'titulaire_murs'
         ELSE 'municipal'
       END AS destination_calculee
FROM locations_actives
ORDER BY id;

-- 1.b ENRICHISSEMENT
UPDATE locations_actives
SET data = data
  || jsonb_build_object(
       'localKey',
       (data ->> 'country') || '|' || (data ->> 'city') || '|'
       || (data ->> 'buildingId') || '|' || (data ->> 'roomId'),
       'orgaAutorisee',
       COALESCE((data ->> 'orgaAutorisee')::boolean, true),
       'destinationLoyer',
       CASE
         WHEN (data ->> 'chambreClinique') = 'true' THEN 'null'::jsonb
         WHEN (data ->> 'isBox') = 'true'
           THEN jsonb_build_object('type', 'caisse_batiment', 'buildingId', data ->> 'buildingId')
         WHEN (data ->> 'roomId') LIKE 'lot\_dyn\_%'
           THEN jsonb_build_object('type', 'titulaire_murs')
         ELSE jsonb_build_object('type', 'municipal',
                                 'pays', data ->> 'country', 'ville', data ->> 'city')
       END)
WHERE NOT (data ? 'destinationLoyer');

-- 1.c CONTROLE POSTERIEUR (attendu : 0)
SELECT count(*) AS baux_sans_destination
FROM locations_actives
WHERE NOT (data ? 'destinationLoyer');


-- =====================================================================
-- PARTIE 2 — RPC TRANSACTIONNELLE prelever_loyer_bail(text)
-- =====================================================================
-- POURQUOI UNE RPC. Un prelevement de loyer est au minimum DEUX ecritures : debit du locataire
-- (personnages.arg) et credit de la destination (budgets_municipaux, personnages ou
-- caisses_batiments). Via l'API REST elles sont forcement separees : une panne entre les deux
-- detruit ou cree de l'argent. C'est exactement le defaut du moteur historique
-- preleverLoyersLots, qui debitait le locataire puis creditait le proprietaire en deux appels --
-- et ne creditait personne si le proprietaire n'existait plus, l'argent disparaissant.
--
-- Meme doctrine que creer_placement_national / les RPC Helvetia deja en production : la RPC est
-- l'autorite transactionnelle unique.
--
-- GARANTIES
--   - Verrou FOR UPDATE sur le bail PUIS sur le personnage : deux passages concurrents du cron
--     ne peuvent pas double-prelever le meme bail le meme jour.
--   - Anti-rejeu : jour_paiement (date du jour, timezone Europe/Paris) memorise sur le bail.
--     Un second appel le meme jour renvoie 'deja_preleve' sans rien ecrire.
--   - Aucun debit sans credit : si la destination est introuvable ou non creditable (PJ disparu,
--     organisation inexistante, type inconnu), la fonction leve une exception et TOUT est annule
--     -- jamais d'argent detruit, jamais de loyer preleve sans beneficiaire.
--   - Fail-closed : destinationLoyer absent -> exception, aucun mouvement.
--
-- RETOUR : un texte, consomme tel quel par le cron.
--   'paye' | 'deja_preleve' | 'ignore_sans_loyer' | 'avertissement' | 'expulsion_requise'
--   | 'locataire_absent' | 'destination_absente' | 'destination_introuvable'
--
-- SECURITE : SECURITY DEFINER, indispensable pour ecrire personnages / budgets_municipaux /
-- organisations / caisses_batiments sous RLS.
--
-- QUI PEUT APPELER : service_role UNIQUEMENT.
--
-- Le raisonnement, en deux temps. Le cron s'authentifiait aupres de PostgREST avec la cle ANON
-- (api/cron-minuit.js), cle PUBLIQUE puisque committee dans supabase.js et lisible par n'importe
-- quel navigateur. Laisser anon executer cette RPC aurait donc donne a TOUT joueur le pouvoir de
-- declencher lui-meme le prelevement d'un bail dont il connait l'id -- donc de precipiter un
-- avertissement ou une expulsion chez un rival. Capacite NOUVELLE, refusee par le GD.
-- Symetriquement, revoquer anon SANS rien d'autre aurait bloque le seul appelant reel : 403,
-- sbRpc null, plus aucun loyer preleve -- panne silencieuse et totale.
--
-- La sortie est une identite serveur, deja en usage dans ce projet et jamais exposee au client :
-- SUPABASE_SERVICE_ROLE_KEY (variable d'environnement Vercel). Precedent direct : la securisation
-- de journal_editions du 3 septembre 2026 (migration_journal_editions_securisation.sql), ou le
-- meme cron ecrit deja via service_role au travers de api/_journal-generation.js. On reprend cette
-- convention telle quelle, pour ce seul appel : le cron passe HEADERS_SERVICE a sbRpc uniquement
-- pour prelever_loyer_bail ; ses autres appels REST et ses 5 autres RPC restent sur anon.
--
-- service_role contourne RLS par nature, mais N'HERITE PAS des droits revoques a PUBLIC : le
-- GRANT ci-dessous lui est donc explicitement NECESSAIRE.
--
-- PREREQUIS DE DEPLOIEMENT : SUPABASE_SERVICE_ROLE_KEY doit exister dans l'environnement Vercel.
-- Elle y est deja (le journal quotidien ne pourrait pas s'ecrire sinon), mais si elle venait a
-- manquer, le cron detecte son absence AVANT tout appel, trace la cause et ne preleve rien.

CREATE OR REPLACE FUNCTION prelever_loyer_bail(p_bail_id text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_bail        locations_actives%ROWTYPE;
  v_data        jsonb;
  v_locataire   text;
  v_prix        numeric;
  v_dest        jsonb;
  v_dest_type   text;
  v_pays        text;
  v_ville       text;
  v_building    text;
  v_arg         numeric;
  v_jour        text := to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD');
  v_cle         text;
  v_titulaire   text;
  v_orga_id     text;
  v_orga_data   text;
  v_maj         integer;
BEGIN
  SELECT * INTO v_bail FROM locations_actives WHERE id = p_bail_id FOR UPDATE;
  IF NOT FOUND THEN RETURN 'bail_absent'; END IF;

  v_data      := v_bail.data;
  v_locataire := v_data ->> 'locataire';
  v_prix      := COALESCE((v_data ->> 'prix')::numeric, 0);

  -- Anti-rejeu : un seul prelevement par bail et par jour reel.
  IF (v_data ->> 'jourPaiement') = v_jour THEN RETURN 'deja_preleve'; END IF;

  -- Usages sans loyer reel (chambre de clinique, bail a prix nul) : aucun transfert artificiel.
  IF v_prix <= 0 OR (v_data ->> 'chambreClinique') = 'true' OR v_locataire IS NULL THEN
    UPDATE locations_actives SET data = v_data || jsonb_build_object('jourPaiement', v_jour)
      WHERE id = p_bail_id;
    RETURN 'ignore_sans_loyer';
  END IF;

  -- Fail-closed : sans destination explicite, on ne devine pas ou va l'argent.
  IF NOT (v_data ? 'destinationLoyer') THEN RETURN 'destination_absente'; END IF;
  v_dest := v_data -> 'destinationLoyer';
  IF v_dest IS NULL OR jsonb_typeof(v_dest) = 'null' THEN
    UPDATE locations_actives SET data = v_data || jsonb_build_object('jourPaiement', v_jour)
      WHERE id = p_bail_id;
    RETURN 'ignore_sans_loyer';
  END IF;
  v_dest_type := v_dest ->> 'type';

  -- Locataire verrouille : le solde lu ne peut plus bouger avant la fin de la transaction.
  SELECT arg INTO v_arg FROM personnages WHERE name = v_locataire FOR UPDATE;
  IF NOT FOUND THEN RETURN 'locataire_absent'; END IF;

  ------------------------------------------------------------------ impaye
  IF COALESCE(v_arg, 0) < v_prix THEN
    IF COALESCE((v_data ->> 'avertissement')::boolean, false) THEN
      RETURN 'expulsion_requise';           -- le cron supprime le bail et notifie
    END IF;
    UPDATE locations_actives
      SET data = v_data || jsonb_build_object('avertissement', true, 'jourPaiement', v_jour)
      WHERE id = p_bail_id;
    RETURN 'avertissement';
  END IF;

  ------------------------------------------------------------------ credit
  IF v_dest_type = 'municipal' THEN
    v_pays  := COALESCE(v_dest ->> 'pays',  v_data ->> 'country');
    v_ville := COALESCE(v_dest ->> 'ville', v_data ->> 'city');
    v_cle   := v_pays || '_' || v_ville;
    -- Caisse municipale DEPENSABLE (budgets_municipaux.data.caisse), jamais caisses_batiments.
    UPDATE budgets_municipaux
      SET data = jsonb_set(COALESCE(data, '{}'::jsonb), '{caisse}',
                 to_jsonb(COALESCE((data ->> 'caisse')::numeric, 0) + v_prix)),
          updated_at = now()
      WHERE id = v_cle;
    GET DIAGNOSTICS v_maj = ROW_COUNT;
    IF v_maj = 0 THEN
      INSERT INTO budgets_municipaux (id, data, updated_at)
      VALUES (v_cle, jsonb_build_object('caisse', v_prix), now());
    END IF;

  ELSIF v_dest_type = 'titulaire_murs' THEN
    -- Titulaire lu sur le bail s'il y est, sinon sur le terrain porteur (source de verite).
    v_titulaire := v_dest ->> 'titulaire';
    IF v_titulaire IS NULL OR v_titulaire = '' THEN
      SELECT (data::jsonb ->> 'proprietaire') INTO v_titulaire
      FROM terrains_etat
      WHERE country = (v_data ->> 'country') AND building_id = (v_data ->> 'buildingId');
    END IF;
    IF v_titulaire IS NULL OR v_titulaire = '' THEN
      RAISE EXCEPTION 'destination_introuvable';   -- annule tout : aucun debit sans credit
    END IF;

    -- Le titulaire des murs peut etre un PJ ou une ORGANISATION (arbitrage du 6 septembre 2026 :
    -- une organisation peut posseder, percevoir des loyers et garder ce profit dans sa caisse).
    -- La forme de la reference est celle du Lot 1.0 bis :
    --   'orga:<id>'  -> organisation      'pj:<nom>' ou nom brut -> personnage
    -- AUCUNE migration n'est requise : les donnees existantes restent des noms bruts, seule une
    -- future propriete organisationnelle s'ecrira en forme typee.
    IF left(v_titulaire, 5) = 'orga:' THEN
      v_orga_id := substr(v_titulaire, 6);
      IF v_orga_id = '' THEN RAISE EXCEPTION 'destination_introuvable'; END IF;
      -- organisations.data est une colonne TEXT contenant du JSON (comme terrains_etat, et
      -- contrairement a budgets_municipaux/caisses_batiments qui sont jsonb) : cast a l'aller,
      -- retour en text. FOR UPDATE serialise deux passages concurrents du cron sur la meme
      -- organisation.
      SELECT data INTO v_orga_data FROM organisations WHERE id = v_orga_id FOR UPDATE;
      IF NOT FOUND THEN RAISE EXCEPTION 'destination_introuvable'; END IF;
      -- Blob absent ou vide : jsonb_set(NULL, ...) renverrait NULL, ce qui ecraserait la ligne
      -- ET perdrait le credit alors que le locataire, lui, serait debite. On refuse.
      IF v_orga_data IS NULL OR btrim(v_orga_data) = '' THEN
        RAISE EXCEPTION 'destination_introuvable';
      END IF;
      UPDATE organisations
        SET data = jsonb_set(v_orga_data::jsonb, '{caisse}',
                    to_jsonb(COALESCE((v_orga_data::jsonb ->> 'caisse')::numeric, 0) + v_prix))::text
        WHERE id = v_orga_id;
      -- Le loyer va a la CAISSE de l'organisation, jamais au compte personnel de son chef.
      -- Aucun droit de retrait/virement/depense n'est cree ici : la gouvernance (chef, futur
      -- poste de tresorier) appartient a un chantier ulterieur, et peutAgirPourOrganisation()
      -- reste ferme.
    ELSE
      IF left(v_titulaire, 3) = 'pj:' THEN v_titulaire := substr(v_titulaire, 4); END IF;
      UPDATE personnages SET arg = COALESCE(arg, 0) + v_prix WHERE name = v_titulaire;
      GET DIAGNOSTICS v_maj = ROW_COUNT;
      IF v_maj = 0 THEN
        RAISE EXCEPTION 'destination_introuvable';
      END IF;
    END IF;

  ELSIF v_dest_type = 'caisse_batiment' THEN
    v_building := COALESCE(v_dest ->> 'buildingId', v_data ->> 'buildingId');
    v_cle := (v_data ->> 'country') || '_' || v_building;
    UPDATE caisses_batiments
      SET data = jsonb_set(COALESCE(data, '{}'::jsonb), '{solde}',
                 to_jsonb(COALESCE((data ->> 'solde')::numeric, 0) + v_prix)),
          updated_at = now()
      WHERE id = v_cle;
    GET DIAGNOSTICS v_maj = ROW_COUNT;
    IF v_maj = 0 THEN
      INSERT INTO caisses_batiments (id, data, updated_at)
      VALUES (v_cle, jsonb_build_object('solde', v_prix), now());
    END IF;

  ELSE
    RAISE EXCEPTION 'destination_introuvable';
  END IF;

  ------------------------------------------------------------------ debit
  UPDATE personnages SET arg = COALESCE(arg, 0) - v_prix WHERE name = v_locataire;

  UPDATE locations_actives
    SET data = (v_data - 'avertissement')
               || jsonb_build_object('jourPaiement', v_jour, 'dernierLoyerPaye', v_jour)
    WHERE id = p_bail_id;

  RETURN 'paye';
END;
$$;

-- Droits d'execution : voir la note SECURITE ci-dessus. Le navigateur (anon) ne doit JAMAIS
-- pouvoir declencher un prelevement ; seul le cron, porteur de l'identite serveur, le peut.
REVOKE ALL ON FUNCTION prelever_loyer_bail(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION prelever_loyer_bail(text) FROM anon;
REVOKE ALL ON FUNCTION prelever_loyer_bail(text) FROM authenticated;
GRANT EXECUTE ON FUNCTION prelever_loyer_bail(text) TO service_role;

-- CONTROLE POSTERIEUR DES DROITS — attendu : une seule ligne, 'service_role'.
-- (aucune ligne 'anon' ni 'authenticated' ne doit apparaitre)
SELECT grantee, privilege_type
FROM information_schema.role_routine_grants
WHERE routine_name = 'prelever_loyer_bail'
ORDER BY grantee;

-- =====================================================================
-- CE QUI N'EST **PAS** FAIT ICI :
--   - aucune suppression de subdivisions[].locataire / .loyer : ces champs restent la
--     description physique du lot (prix demande, base de l'indemnite d'eviction) ; ils cessent
--     seulement d'etre une source de verite FINANCIERE ;
--   - aucune bascule GLOBALE de titulaire vers 'pj:' / 'orga:' : les donnees existantes restent
--     des noms bruts. La RPC sait seulement LIRE la forme typee, ce qui rend possible une
--     propriete organisationnelle sans migration ;
--   - aucun droit de gouvernance sur la caisse d'une organisation (retrait, virement, depense,
--     poste de tresorier) : ce lot ne fait que CREDITER ;
--   - aucune eviction negociee, aucune recuperation de fonds/stock/caisse (Lot 3.0) ;
--   - aucun changement de la frequence : un prelevement par bail et par jour reel.
-- =====================================================================
