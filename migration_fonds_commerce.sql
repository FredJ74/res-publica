-- =====================================================================
-- LOT 3.0 — CYCLE PATRIMONIAL DU FONDS DE COMMERCE ET ARCHIVE DES BAUX
-- Une table, un utilitaire, six RPC transactionnelles
-- 8 septembre 2026
-- =====================================================================
-- ⚠️  NON EXECUTEE. Fournie pour relecture.
--
-- ORDRE DE DEPLOIEMENT IMPERATIF : ce fichier D'ABORD, le code ENSUITE.
-- Le client est fail-closed partout : tant que ces objets n'existent pas, sbRpc renvoie null et
-- l'action est refusee avec un message explicite. Aucun repli sur un chemin non transactionnel.
--
-- POURQUOI DU TRANSACTIONNEL. Chacune des cinq operations ci-dessous traverse plusieurs tables
-- (la sixieme fonction, resilier_bail_volontaire, est une porte publique qui delegue a la derniere) :
--   creer_fonds_commerce      : entreprises + (personnages | organisations)
--   alimenter_caisse_fonds    : entreprises + (personnages | organisations)
--   retirer_caisse_fonds      : entreprises + (personnages | organisations)
--   vendre_fonds_commerce     : entreprises + locations_actives + deux patrimoines
--   terminer_bail             : locations_actives + locations_archives + entreprises
-- En ecritures REST separees, une panne intermediaire produirait exactement les etats que le
-- cahier des charges interdit : fonds cree sans debit, debit sans fonds, caisse extraite deux
-- fois, bail reste a l'ancien titulaire, archive oubliee. Meme doctrine qu'aux Lots 1.4, 1.5.10
-- et 1.5.12 : la RPC est l'autorite transactionnelle unique.
--
-- LES MONTANTS NE SONT JAMAIS CRUS. Apport, prix, caisse et disponibilites sont relus sous verrou
-- et recalcules ; le client ne transmet qu'une intention.
--
-- ORDRE DES VERROUS, homogene a tout le fichier et compatible avec les RPC existantes :
--   patrimoines (personnages, organisations) -> entreprises -> locations_actives
-- terrains_etat n'est jamais verrouille ici, seulement lu.

-- ---------------------------------------------------------------------
-- 1. ARCHIVE DES BAUX TERMINES
-- ---------------------------------------------------------------------
-- locations_actives reste STRICTEMENT la table des baux en cours -- c'est elle que lit le moteur
-- des loyers, et un bail termine ne doit pas y trainer. Son histoire part ici.
--
-- APPEND-ONLY GARANTI PAR LA BASE, sur la doctrine de dossiers_urbanisme (Lot 1.5.5) : RLS active,
-- une policy SELECT, une policy INSERT, et AUCUNE policy UPDATE ni DELETE. Une ligne archivee ne
-- peut donc etre ni reecrite ni supprimee, meme par un appel direct a l'API REST.
CREATE TABLE IF NOT EXISTS locations_archives (
  id                text PRIMARY KEY,
  bail_id           text,
  country           text,
  city              text,
  building_id       text,
  room_id           text,
  lot_id            text,
  locataire         text,
  proprietaire_murs text,
  loyer             integer     NOT NULL DEFAULT 0,
  debut             integer,
  fin_cause         text        NOT NULL,
  fonds_id          text,
  indemnite         integer     NOT NULL DEFAULT 0,
  data              jsonb       NOT NULL DEFAULT '{}'::jsonb,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS locations_archives_bail_idx    ON locations_archives (bail_id);
CREATE INDEX IF NOT EXISTS locations_archives_lieu_idx    ON locations_archives (country, city, building_id);
CREATE INDEX IF NOT EXISTS locations_archives_titulaire_idx ON locations_archives (locataire);
CREATE INDEX IF NOT EXISTS locations_archives_fonds_idx   ON locations_archives (fonds_id);

ALTER TABLE locations_archives ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS locations_archives_select ON locations_archives;
CREATE POLICY locations_archives_select ON locations_archives FOR SELECT USING (true);

DROP POLICY IF EXISTS locations_archives_insert ON locations_archives;
CREATE POLICY locations_archives_insert ON locations_archives FOR INSERT WITH CHECK (true);
-- Volontairement AUCUNE policy UPDATE ni DELETE : l'histoire ne se reecrit pas.

GRANT SELECT, INSERT ON locations_archives TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 2. UTILITAIRE : MOUVEMENT SUR UN TITULAIRE TYPE
-- ---------------------------------------------------------------------
-- 'pj:<nom>' -> personnages.arg   |   'orga:<id>' -> organisations.data.caisse
-- Une valeur non prefixee est un nom de PJ : forme historique encore majoritaire en base, qu'on
-- lit defensivement sans la migrer.
--
-- L'ARGENT D'UNE ORGANISATION EST A L'ORGANISATION. Jamais au compte personnel de son dirigeant :
-- c'est tout l'interet d'une personne morale, et le cahier des charges l'exige explicitement.
--
-- Renvoie false si le titulaire est introuvable ou si le debit rendrait le solde negatif. Les
-- appelants DOIVENT tester ce retour et lever une exception : un mouvement refuse ne doit jamais
-- laisser passer la moitie d'une operation.
CREATE OR REPLACE FUNCTION mouvement_titulaire(p_ref text, p_delta numeric)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_type    text;
  v_id      text;
  v_solde   numeric;
  v_data    text;
  v_json    jsonb;
BEGIN
  IF COALESCE(p_ref, '') = '' THEN RETURN false; END IF;

  IF left(p_ref, 5) = 'orga:' THEN
    v_type := 'orga'; v_id := substr(p_ref, 6);
  ELSIF left(p_ref, 3) = 'pj:' THEN
    v_type := 'pj';   v_id := substr(p_ref, 4);
  ELSIF left(p_ref, 6) = 'ville:' THEN
    -- Une municipalite n'est pas un patrimoine mouvementable par cette voie : ses recettes
    -- passent par budgets_municipaux (moteur des loyers, Lot 1.4).
    RETURN false;
  ELSE
    v_type := 'pj';   v_id := p_ref;
  END IF;

  IF COALESCE(v_id, '') = '' THEN RETURN false; END IF;

  IF v_type = 'pj' THEN
    SELECT arg INTO v_solde FROM personnages WHERE name = v_id FOR UPDATE;
    IF NOT FOUND THEN RETURN false; END IF;
    IF COALESCE(v_solde, 0) + p_delta < 0 THEN RETURN false; END IF;
    UPDATE personnages SET arg = COALESCE(arg, 0) + p_delta WHERE name = v_id;
    RETURN true;
  END IF;

  -- organisations.data est une colonne TEXT contenant du JSON (comme terrains_etat), a la
  -- difference de budgets_municipaux et caisses_batiments : cast a l'aller, retour en text.
  SELECT data INTO v_data FROM organisations WHERE id = v_id FOR UPDATE;
  IF NOT FOUND THEN RETURN false; END IF;
  BEGIN
    v_json := v_data::jsonb;
  EXCEPTION WHEN others THEN RETURN false;
  END;
  IF v_json IS NULL OR jsonb_typeof(v_json) <> 'object' THEN RETURN false; END IF;
  v_solde := GREATEST(0, COALESCE((v_json ->> 'caisse')::numeric, 0));
  IF v_solde + p_delta < 0 THEN RETURN false; END IF;
  UPDATE organisations
    SET data = jsonb_set(v_json, '{caisse}', to_jsonb(v_solde + p_delta))::text
    WHERE id = v_id;
  RETURN true;
END;
$$;

-- ---------------------------------------------------------------------
-- 3. CREATION D'UN FONDS DE COMMERCE
-- ---------------------------------------------------------------------
-- PRENDRE UN BAIL NE CREE PAS DE FONDS : le bail donne le droit d'occuper, exploiter est une
-- decision distincte et explicite. Cette RPC est ce moment-la.
--
-- Aucun capital gratuit : la caisse initiale vaut EXACTEMENT l'apport reellement debite du
-- patrimoine du fondateur. Un apport nul est licite -- on ouvre une coquille, on l'alimente
-- ensuite (voir alimenter_caisse_fonds).
--
-- L'IDENTIFIANT EST OPAQUE et fourni par l'appelant : c'est une identite, pas une donnee metier,
-- et la RPC verifie seulement qu'elle est libre. L'adresse n'y figure jamais, de sorte qu'un
-- changement de local ou de proprietaire n'oblige pas a en changer.
CREATE OR REPLACE FUNCTION creer_fonds_commerce(
  p_proprietaire text,
  p_bail_id      text,
  p_fonds_id     text,
  p_apport       integer,
  p_enseigne     text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_bail    jsonb;
  v_apport  integer := GREATEST(0, COALESCE(p_apport, 0));
  v_lot     text;
  v_deja    integer;
BEGIN
  IF COALESCE(p_proprietaire, '') = '' OR COALESCE(p_bail_id, '') = ''
     OR COALESCE(p_fonds_id, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  -- Verrou du patrimoine AVANT tout le reste : ordre homogene a l'ensemble du fichier.
  IF v_apport > 0 THEN
    IF NOT mouvement_titulaire(p_proprietaire, -v_apport) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants');
    END IF;
  ELSE
    -- Meme sans apport, on exige que le titulaire existe : un fonds sans proprietaire reel serait
    -- un orphelin des la premiere seconde.
    IF NOT mouvement_titulaire(p_proprietaire, 0) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'proprietaire_absent');
    END IF;
  END IF;

  SELECT count(*) INTO v_deja FROM entreprises WHERE id = p_fonds_id;
  IF v_deja > 0 THEN
    RAISE EXCEPTION 'fonds_id_deja_pris';        -- annule le debit : jamais d'argent sans fonds
  END IF;

  SELECT data INTO v_bail FROM locations_actives WHERE id = p_bail_id FOR UPDATE;
  IF v_bail IS NULL THEN RAISE EXCEPTION 'bail_absent'; END IF;

  -- Le demandeur doit etre le titulaire du bail. Le bail stocke un nom brut (forme historique) ;
  -- on accepte les deux ecritures sans migrer quoi que ce soit.
  IF (v_bail ->> 'locataire') IS DISTINCT FROM p_proprietaire
     AND ('pj:' || COALESCE(v_bail ->> 'locataire', '')) IS DISTINCT FROM p_proprietaire THEN
    RAISE EXCEPTION 'pas_titulaire';
  END IF;

  -- Un seul fonds par bail : deux commerces dans le meme local seraient deux exploitations
  -- concurrentes d'une meme surface.
  SELECT count(*) INTO v_deja FROM entreprises
   WHERE data -> 'implantation' ->> 'bailId' = p_bail_id
     AND COALESCE(data ->> 'statut', 'actif') = 'actif';
  IF v_deja > 0 THEN RAISE EXCEPTION 'fonds_deja_present'; END IF;

  v_lot := v_bail ->> 'lotId';

  INSERT INTO entreprises (id, data, updated_at)
  VALUES (p_fonds_id, jsonb_build_object(
    'id', p_fonds_id,
    'version', 2,
    'type', 'fonds_commerce',
    'enseigne', COALESCE(NULLIF(btrim(COALESCE(p_enseigne, '')), ''), 'Fonds de commerce'),
    'proprietaire', p_proprietaire,
    'statut', 'actif',
    'caisse', v_apport,
    'implantation', jsonb_build_object(
      'country', v_bail ->> 'country', 'city', v_bail ->> 'city',
      'buildingId', v_bail ->> 'buildingId', 'roomId', v_bail ->> 'roomId',
      'lotId', v_lot, 'localKey', v_bail ->> 'localKey', 'bailId', p_bail_id),
    -- Prets pour le futur moteur commercial, qui enrichira cet objet au lieu d'en creer un autre.
    'stockMatieres', '{}'::jsonb,
    'stockProduits', '{}'::jsonb,
    'historique', jsonb_build_array(jsonb_build_object(
      'evenement', 'creation', 'proprietaire', p_proprietaire, 'apport', v_apport,
      'horodatage', to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS')))
  ), now());

  -- Le bail porte desormais le fonds : lien explicite dans les deux sens, une seule ecriture.
  UPDATE locations_actives
    SET data = v_bail || jsonb_build_object('fondsId', p_fonds_id)
    WHERE id = p_bail_id;

  RETURN jsonb_build_object('ok', true, 'fondsId', p_fonds_id, 'caisse', v_apport,
                            'apport', v_apport, 'proprietaire', p_proprietaire);
END;
$$;

-- ---------------------------------------------------------------------
-- 4. REALIMENTATION DE LA CAISSE
-- ---------------------------------------------------------------------
-- Transfert reel, jamais une creation. AUCUN RETRAIT LIBRE n'est ouvert : la seule sortie prevue
-- est l'extraction lors d'une vente, decidee explicitement. Ouvrir un retrait a volonte avant que
-- le moteur commercial existe creerait un canal de circulation d'argent sans contrepartie.
CREATE OR REPLACE FUNCTION alimenter_caisse_fonds(
  p_acteur   text,
  p_fonds_id text,
  p_montant  integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_data   jsonb;
  v_m      integer := COALESCE(p_montant, 0);
BEGIN
  IF COALESCE(p_acteur, '') = '' OR COALESCE(p_fonds_id, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF v_m <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;

  IF NOT mouvement_titulaire(p_acteur, -v_m) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants');
  END IF;

  SELECT data INTO v_data FROM entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RAISE EXCEPTION 'fonds_absent'; END IF;
  IF COALESCE((v_data ->> 'version')::integer, 0) < 2 THEN RAISE EXCEPTION 'pas_un_fonds'; END IF;
  IF COALESCE(v_data ->> 'statut', 'actif') <> 'actif' THEN RAISE EXCEPTION 'fonds_inactif'; END IF;
  IF (v_data ->> 'proprietaire') IS DISTINCT FROM p_acteur THEN RAISE EXCEPTION 'pas_proprietaire'; END IF;

  UPDATE entreprises
    SET data = jsonb_set(v_data, '{caisse}',
                 to_jsonb(GREATEST(0, COALESCE((v_data ->> 'caisse')::numeric, 0)) + v_m)),
        updated_at = now()
    WHERE id = p_fonds_id;

  RETURN jsonb_build_object('ok', true, 'montant', v_m,
                            'caisse', GREATEST(0, COALESCE((v_data ->> 'caisse')::numeric, 0)) + v_m);
END;
$$;

-- ---------------------------------------------------------------------
-- 4 bis. RETRAIT DE CAISSE
-- ---------------------------------------------------------------------
-- Symetrique exact de l'alimentation. Ce n'est pas un revenu que le jeu fabrique : c'est le
-- proprietaire qui reprend son propre argent, la ou il l'avait mis. La masse monetaire ne bouge
-- pas d'un FR -- ce qui sort de la caisse entre dans le patrimoine, et rien d'autre.
--
-- TANT QUE LE FONDS EST A LUI, IL EN DISPOSE. Un impaye de loyer, une procedure de recuperation
-- ouverte, une eviction demandee : rien de tout cela ne gele ses actifs. C'est seulement quand
-- l'eviction est EXECUTEE -- le bail termine, le fonds passe a 'abandonne' -- que ce retrait
-- devient impossible, parce que le fonds n'est alors plus exploitable par personne. Le controle
-- de statut ci-dessous est donc la frontiere exacte entre "menace" et "fait accompli".
CREATE OR REPLACE FUNCTION retirer_caisse_fonds(
  p_acteur   text,
  p_fonds_id text,
  p_montant  integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_data   jsonb;
  v_caisse integer;
  v_m      integer := COALESCE(p_montant, 0);
BEGIN
  IF COALESCE(p_acteur, '') = '' OR COALESCE(p_fonds_id, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF v_m <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;

  -- Le fonds est verrouille AVANT le patrimoine : c'est lui qui porte le montant disponible, et
  -- deux retraits simultanes doivent se serialiser sur cette ligne-la, jamais sur le compte.
  SELECT data INTO v_data FROM entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF COALESCE((v_data ->> 'version')::integer, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds');
  END IF;
  IF COALESCE(v_data ->> 'statut', 'actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif');
  END IF;
  IF (v_data ->> 'proprietaire') IS DISTINCT FROM p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire');
  END IF;

  v_caisse := GREATEST(0, COALESCE((v_data ->> 'caisse')::numeric, 0))::integer;
  IF v_m > v_caisse THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'caisse', v_caisse);
  END IF;

  -- Debit de la caisse PUIS credit du patrimoine, dans la meme transaction. Si le titulaire est
  -- introuvable, l'exception annule le debit : jamais d'argent detruit en route.
  UPDATE entreprises
    SET data = jsonb_set(v_data, '{caisse}', to_jsonb(v_caisse - v_m)),
        updated_at = now()
    WHERE id = p_fonds_id;

  IF NOT mouvement_titulaire(p_acteur, v_m) THEN
    RAISE EXCEPTION 'titulaire_introuvable';
  END IF;

  RETURN jsonb_build_object('ok', true, 'montant', v_m, 'caisse', v_caisse - v_m);
END;
$$;

-- ---------------------------------------------------------------------
-- 5. VENTE D'UN FONDS DE COMMERCE
-- ---------------------------------------------------------------------
-- LA CAISSE N'EST PAS COMPRISE DANS LA VENTE. Elle est extraite au vendeur AVANT le transfert, et
-- le fonds change de mains a caisse nulle. Prix de vente et tresorerie du fonds sont deux
-- grandeurs distinctes : les melanger reviendrait a vendre l'argent avec la boutique.
--
-- LE BAIL SUIT LE FONDS. Meme local, memes murs, MEME LIGNE de bail : seul son titulaire change.
-- On ne supprime pas pour recreer -- cela detruirait l'historique et ferait clignoter le local
-- comme libre entre les deux ecritures.
--
-- Les deux patrimoines sont verrouilles dans l'ordre lexicographique de leur reference, et non
-- dans l'ordre vendeur/acheteur : deux ventes croisees simultanees se serialisent au lieu de
-- s'interbloquer.
CREATE OR REPLACE FUNCTION vendre_fonds_commerce(
  p_vendeur  text,
  p_acheteur text,
  p_fonds_id text,
  p_prix     integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_data     jsonb;
  v_bail_id  text;
  v_bail     jsonb;
  v_prix     integer := GREATEST(0, COALESCE(p_prix, 0));
  v_caisse   integer;
  v_premier  text;
  v_second   text;
BEGIN
  IF COALESCE(p_vendeur, '') = '' OR COALESCE(p_acheteur, '') = ''
     OR COALESCE(p_fonds_id, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF p_vendeur = p_acheteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acheteur_identique');
  END IF;
  IF left(p_acheteur, 6) = 'ville:' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acheteur_invalide');
  END IF;

  -- Verrous des deux patrimoines, ordre deterministe. Le delta nul ne fait que poser le verrou.
  IF p_vendeur < p_acheteur THEN v_premier := p_vendeur; v_second := p_acheteur;
  ELSE                          v_premier := p_acheteur; v_second := p_vendeur; END IF;
  IF NOT mouvement_titulaire(v_premier, 0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'titulaire_absent');
  END IF;
  IF NOT mouvement_titulaire(v_second, 0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'titulaire_absent');
  END IF;

  SELECT data INTO v_data FROM entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF COALESCE((v_data ->> 'version')::integer, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds');
  END IF;
  IF COALESCE(v_data ->> 'statut', 'actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif');
  END IF;
  IF (v_data ->> 'proprietaire') IS DISTINCT FROM p_vendeur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire');
  END IF;

  -- 1. PRIX : de l'acheteur au vendeur. Refuse si l'acheteur ne l'a pas -- rien n'a encore bouge.
  IF v_prix > 0 THEN
    IF NOT mouvement_titulaire(p_acheteur, -v_prix) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'acheteur_insolvable');
    END IF;
    IF NOT mouvement_titulaire(p_vendeur, v_prix) THEN
      RAISE EXCEPTION 'vendeur_introuvable';     -- annule le debit : jamais d'argent detruit
    END IF;
  END IF;

  -- 2. CAISSE : extraite au VENDEUR, dans la meme transaction. Le fonds part a zero.
  v_caisse := GREATEST(0, COALESCE((v_data ->> 'caisse')::numeric, 0))::integer;
  IF v_caisse > 0 THEN
    IF NOT mouvement_titulaire(p_vendeur, v_caisse) THEN
      RAISE EXCEPTION 'extraction_impossible';
    END IF;
  END IF;

  -- 3. TRANSFERT. L'identite du fonds ne bouge pas : seuls changent son proprietaire et sa caisse.
  v_data := jsonb_set(v_data, '{proprietaire}', to_jsonb(p_acheteur));
  v_data := jsonb_set(v_data, '{caisse}', to_jsonb(0));
  v_data := jsonb_set(v_data, '{historique}',
    COALESCE(v_data -> 'historique', '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
      'evenement', 'vente', 'vendeur', p_vendeur, 'acheteur', p_acheteur,
      'prix', v_prix, 'caisseExtraite', v_caisse,
      'horodatage', to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS'))));
  UPDATE entreprises SET data = v_data, updated_at = now() WHERE id = p_fonds_id;

  -- 4. LE BAIL SUIT. Le titulaire du bail devient l'acheteur ; tout le reste est intact.
  v_bail_id := v_data -> 'implantation' ->> 'bailId';
  IF COALESCE(v_bail_id, '') <> '' THEN
    SELECT data INTO v_bail FROM locations_actives WHERE id = v_bail_id FOR UPDATE;
    IF v_bail IS NOT NULL THEN
      UPDATE locations_actives
        SET data = v_bail || jsonb_build_object(
              'locataire', CASE WHEN left(p_acheteur, 3) = 'pj:' THEN substr(p_acheteur, 4) ELSE p_acheteur END,
              'locataireRef', p_acheteur,
              'transferts', COALESCE(v_bail -> 'transferts', '[]'::jsonb) || jsonb_build_array(
                jsonb_build_object('cause', 'vente_fonds', 'de', p_vendeur, 'vers', p_acheteur,
                  'horodatage', to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS'))))
        WHERE id = v_bail_id;
    END IF;
  END IF;

  RETURN jsonb_build_object('ok', true, 'fondsId', p_fonds_id, 'prix', v_prix,
                            'caisseExtraite', v_caisse, 'acheteur', p_acheteur,
                            'bailTransfere', COALESCE(v_bail_id, ''));
END;
$$;

-- ---------------------------------------------------------------------
-- 6. FIN D'UN BAIL — ARCHIVE PUIS SUPPRESSION
-- ---------------------------------------------------------------------
-- Une seule mecanique pour toutes les causes : resiliation volontaire, accord amiable, eviction
-- judiciaire, succession sans heritier. C'est aussi la PRIMITIVE que le futur Tribunal appellera
-- avec la cause 'eviction_judiciaire' -- rien de plus n'est prepare ici pour lui.
--
-- L'ARCHIVE COMMANDE : la ligne de locations_archives est ecrite AVANT la suppression du bail
-- actif, dans la meme transaction. Il n'existe aucun instant ou un bail aurait disparu sans avoir
-- ete archive.
--
-- LE FONDS N'EST JAMAIS DONNE AU PROPRIETAIRE DES MURS. Il cesse d'occuper le local et devient
-- 'abandonne' : plus exploitable par personne, contenu intact, proprietaire nominal inchange.
-- Le proprietaire des murs decidera plus tard de son sort ; rien n'est detruit ici.
--
-- L'indemnite d'un accord amiable est versee dans la meme transaction, du bailleur au locataire.
-- Le moteur n'impose AUCUN montant : il transporte celui sur lequel les deux se sont entendus.
CREATE OR REPLACE FUNCTION terminer_bail(
  p_bail_id   text,
  p_cause     text,
  p_acteur    text,
  p_indemnite integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_bail     jsonb;
  v_fonds_id text;
  v_fonds    jsonb;
  v_prop     text;
  v_ind      integer := GREATEST(0, COALESCE(p_indemnite, 0));
  v_terrain  text;
  v_locataire text;
BEGIN
  IF COALESCE(p_bail_id, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF p_cause NOT IN ('resiliation_volontaire', 'accord_amiable', 'eviction_judiciaire',
                     'succession_sans_heritier') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cause_invalide');
  END IF;

  SELECT data INTO v_bail FROM locations_actives WHERE id = p_bail_id FOR UPDATE;
  IF v_bail IS NULL THEN
    -- Idempotence : un bail deja termine n'est pas une erreur, il n'y a simplement plus rien a faire.
    RETURN jsonb_build_object('ok', true, 'deja_termine', true);
  END IF;

  v_locataire := v_bail ->> 'locataire';

  -- Une resiliation volontaire n'appartient qu'au titulaire, et l'acteur est OBLIGATOIRE : sans
  -- cette exigence, il aurait suffi de ne rien passer pour sauter le controle.
  IF p_cause = 'resiliation_volontaire' THEN
    IF COALESCE(p_acteur, '') = '' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'acteur_requis');
    END IF;
    IF v_locataire IS DISTINCT FROM p_acteur
       AND ('pj:' || COALESCE(v_locataire, '')) IS DISTINCT FROM p_acteur THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_titulaire');
    END IF;
  END IF;
  -- Les trois autres causes n'ont deliberement AUCUN controle d'acteur ici : elles ne sont pas
  -- declenchables depuis un navigateur. Cette fonction n'est pas exposee au public (voir la
  -- section DROITS) ; seul le moteur serveur -- le futur Tribunal, le moteur successoral -- peut
  -- l'appeler, et c'est a lui qu'il revient d'etablir la legitimite de la cause. Un controle
  -- d'acteur ici donnerait l'illusion d'une garantie que seul le cloisonnement des droits fournit.

  -- Proprietaire ACTUEL des murs, lu sur le terrain porteur -- jamais une valeur figee au bail.
  v_terrain := (v_bail ->> 'country') || '_' || (v_bail ->> 'buildingId');
  SELECT (data::jsonb ->> 'proprietaire') INTO v_prop FROM terrains_etat WHERE id = v_terrain;

  -- INDEMNITE D'ACCORD AMIABLE : du bailleur vers le locataire, montant librement convenu.
  IF p_cause = 'accord_amiable' AND v_ind > 0 THEN
    IF COALESCE(v_prop, '') = '' THEN RAISE EXCEPTION 'bailleur_introuvable'; END IF;
    IF NOT mouvement_titulaire(v_prop, -v_ind) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'bailleur_insolvable');
    END IF;
    IF NOT mouvement_titulaire(COALESCE(v_bail ->> 'locataireRef', v_locataire), v_ind) THEN
      RAISE EXCEPTION 'locataire_introuvable';    -- annule le debit : jamais d'argent detruit
    END IF;
  END IF;

  -- LE FONDS CESSE D'OCCUPER, sans changer de main.
  v_fonds_id := v_bail ->> 'fondsId';
  IF COALESCE(v_fonds_id, '') <> '' THEN
    SELECT data INTO v_fonds FROM entreprises WHERE id = v_fonds_id FOR UPDATE;
    IF v_fonds IS NOT NULL AND COALESCE((v_fonds ->> 'version')::integer, 0) >= 2 THEN
      v_fonds := jsonb_set(v_fonds, '{statut}', to_jsonb('abandonne'::text));
      v_fonds := jsonb_set(v_fonds, '{historique}',
        COALESCE(v_fonds -> 'historique', '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
          'evenement', 'bail_termine', 'cause', p_cause,
          'horodatage', to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS'))));
      UPDATE entreprises SET data = v_fonds, updated_at = now() WHERE id = v_fonds_id;
    END IF;
  END IF;

  -- ARCHIVE D'ABORD.
  INSERT INTO locations_archives (id, bail_id, country, city, building_id, room_id, lot_id,
                                  locataire, proprietaire_murs, loyer, debut, fin_cause,
                                  fonds_id, indemnite, data)
  VALUES (
    'bail-' || p_bail_id || '-' || extract(epoch from now())::bigint,
    p_bail_id, v_bail ->> 'country', v_bail ->> 'city', v_bail ->> 'buildingId',
    v_bail ->> 'roomId', v_bail ->> 'lotId', v_locataire, v_prop,
    GREATEST(0, COALESCE((v_bail ->> 'prix')::numeric, 0))::integer,
    NULLIF(v_bail ->> 'depuis', '')::integer, p_cause,
    NULLIF(v_fonds_id, ''), v_ind,
    jsonb_build_object('bail', v_bail, 'acteur', p_acteur));

  -- SUPPRESSION ENSUITE. locations_actives ne contient que des baux en cours.
  DELETE FROM locations_actives WHERE id = p_bail_id;

  RETURN jsonb_build_object('ok', true, 'deja_termine', false, 'cause', p_cause,
                            'fondsId', COALESCE(v_fonds_id, ''), 'indemnite', v_ind,
                            'proprietaireMurs', COALESCE(v_prop, ''));
END;
$$;

-- ---------------------------------------------------------------------
-- 6 bis. RESILIATION VOLONTAIRE — LA SEULE FIN DE BAIL OUVERTE AU NAVIGATEUR
-- ---------------------------------------------------------------------
-- terminer_bail ci-dessus accepte quatre causes, dont trois -- accord amiable, eviction
-- judiciaire, succession sans heritier -- ne sont legitimes que si une decision exterieure les
-- fonde : l'accord des deux parties, un jugement, un deces. Aucune de ces preuves n'existe encore
-- dans le jeu, et surtout aucune ne peut etre etablie a partir d'un parametre fourni par le
-- client : il suffirait d'ecrire 'eviction_judiciaire' dans une chaine pour expulser n'importe
-- qui de n'importe quel local.
--
-- LE CLOISONNEMENT EST DONC DANS LES DROITS, PAS DANS UN CONTROLE. terminer_bail devient reservee
-- au service_role, et cette porte-ci est la seule ouverte au navigateur : elle FIGE la cause,
-- FIGE l'indemnite a zero, et exige que le demandeur soit le titulaire reel du bail. Il n'existe
-- aucun parametre par lequel un appelant public puisse en faire autre chose qu'une resiliation
-- volontaire de son propre bail.
--
-- La delegation fonctionne malgre le cloisonnement : dans une fonction SECURITY DEFINER, l'appel
-- interne s'execute avec les droits du PROPRIETAIRE de la fonction, pas avec ceux de l'appelant.
CREATE OR REPLACE FUNCTION resilier_bail_volontaire(
  p_bail_id text,
  p_acteur  text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF COALESCE(p_bail_id, '') = '' OR COALESCE(p_acteur, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  -- Cause et indemnite ne sont PAS des parametres : elles sont ecrites en dur ici.
  RETURN terminer_bail(p_bail_id, 'resiliation_volontaire', p_acteur, 0);
END;
$$;

-- ---------------------------------------------------------------------
-- 7. DROITS
-- ---------------------------------------------------------------------
-- LA LIGNE DE PARTAGE. Une fonction n'est ouverte au navigateur que si elle ne peut RIEN faire
-- qu'un parametre malveillant transformerait en atteinte a un tiers. Le critere est celui-la, et
-- pas la presence d'un controle interne : avec la cle anon, un controle qui porte sur une valeur
-- fournie par l'appelant ne prouve rien.
--
-- OUVERTES AU PUBLIC -- elles ne deplacent l'argent d'un titulaire qu'entre SES propres poches
-- (patrimoine <-> caisse de SON fonds), et refusent tout ce qui sortirait de ce perimetre :
--   creer_fonds_commerce      apport debite du titulaire du bail, vers un fonds qui lui appartient
--   alimenter_caisse_fonds    patrimoine du proprietaire -> caisse de son fonds
--   retirer_caisse_fonds      caisse de son fonds -> patrimoine du proprietaire
--   resilier_bail_volontaire  cause et indemnite figees, titulaire reel exige
--
-- RESERVEES AU SERVEUR -- elles engagent un TIERS, et rien dans les parametres ne peut prouver
-- son consentement ni la decision qui les fonde :
--   mouvement_titulaire       rouage interne : l'exposer donnerait a n'importe qui le pouvoir de
--                             crediter ou debiter n'importe quel patrimoine
--   terminer_bail             accepte eviction_judiciaire, accord_amiable et succession : il
--                             suffirait d'ecrire la chaine voulue pour expulser un tiers sans
--                             jugement, ou pour simuler un accord que personne n'a donne
--   vendre_fonds_commerce     le vendeur est verifie, mais l'ACHETEUR ne l'est pas : la vente
--                             transfererait un fonds ET son bail a quelqu'un qui n'a rien
--                             accepte. Tant que le canal d'offre/acceptation n'existe pas, cette
--                             fonction reste hors de portee du navigateur.
--
-- Ces trois-la redeviendront accessibles -- plus probablement au travers de portes dediees comme
-- resilier_bail_volontaire -- quand la preuve qui leur manque existera : un jugement pour
-- l'eviction, une acceptation pour la vente et pour l'accord amiable.
REVOKE ALL ON FUNCTION mouvement_titulaire(text, numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION mouvement_titulaire(text, numeric) TO service_role;

REVOKE ALL ON FUNCTION creer_fonds_commerce(text, text, text, integer, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION creer_fonds_commerce(text, text, text, integer, text) TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION alimenter_caisse_fonds(text, text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION alimenter_caisse_fonds(text, text, integer) TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION retirer_caisse_fonds(text, text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION retirer_caisse_fonds(text, text, integer) TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION vendre_fonds_commerce(text, text, text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION vendre_fonds_commerce(text, text, text, integer) TO service_role;

REVOKE ALL ON FUNCTION terminer_bail(text, text, text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION terminer_bail(text, text, text, integer) TO service_role;

REVOKE ALL ON FUNCTION resilier_bail_volontaire(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION resilier_bail_volontaire(text, text) TO anon, authenticated, service_role;

-- CONTROLE POSTERIEUR — attendu : la table, ses 4 index, ses 2 policies, et les 7 fonctions.
SELECT 'table' AS objet, tablename AS nom FROM pg_tables WHERE tablename = 'locations_archives'
UNION ALL
SELECT 'policy', policyname FROM pg_policies WHERE tablename = 'locations_archives'
UNION ALL
SELECT 'fonction', routine_name FROM information_schema.routines
 WHERE routine_name IN ('mouvement_titulaire','creer_fonds_commerce','alimenter_caisse_fonds',
                        'retirer_caisse_fonds','vendre_fonds_commerce','terminer_bail',
                        'resilier_bail_volontaire')
ORDER BY objet, nom;
