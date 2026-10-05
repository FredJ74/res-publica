-- =============================================================================
-- LES BAUX : DESTINATION DERIVEE, AUTORITE D'ECRITURE, CLE COHERENTE
-- =============================================================================
-- Date d'application en production : 20 septembre 2026.
--
-- CE FICHIER EST UN RATTRAPAGE DE VERSIONNEMENT. Il reproduit l'ETAT FINAL
-- present en production, pas l'historique de la session.
--
-- MIGRATIONS DE PRODUCTION ABSORBEES, DANS L'ORDRE CHRONOLOGIQUE :
--   20260920121515  bail_destination_attestee
--       cree bail_destination_attestee(jsonb) et rebranche
--       prelever_loyer_bail() dessus.
--   20260920130008  baux_autorite_et_cle_coherente
--       cree bail_je_suis_locataire, bail_autorite_municipale,
--       bail_proprietaire_des_murs, bail_autorite_de, bail_cle_coherente ;
--       pose le trigger trg_bail_cle_coherente ; remplace les politiques
--       publiques de locations_actives et active la RLS.
--
-- L'ORDRE EST STRUCTURANT : bail_destination_attestee (121515) precede 130008
-- et prelever_loyer_bail l'appelle. Les politiques de 130008 s'appuient sur
-- bail_autorite_de, defini juste au-dessus d'elles. Ne pas reordonner.
--
-- DEPENDANCES A REJOUER AVANT CE FICHIER
-- -----------------------------------------------------------------------------
--   * migration_locations_actives_country.sql  -- colonne country de la table.
--   * migration_loyers_unifies_lot14.sql       -- OBLIGATOIRE : c'est ce fichier
--     qui cree prelever_loyer_bail(text) et ses droits. La section 1 bis
--     ci-dessous la REDEFINIT ; elle ne la cree pas de zero avec ses GRANT.
--   * public.mon_personnage() et public.est_appel_serveur() : socle du
--     chantier B (auth / RLS) puis 20260919231313 (est_appel_serveur fail
--     closed). Aucun de ces deux socles n'a de fichier dedie dans le depot.
--   * public.terrains_etat, public.personnages_donnees : socle du jeu.
--
-- CE QUI N'EXISTE PAS DANS CE LOT
-- -----------------------------------------------------------------------------
-- Aucune reparation ponctuelle de donnees. Les deux migrations de production
-- n'ecrivent AUCUN UPDATE ni DELETE sur les lignes de locations_actives --
-- verifie sur le texte d'origine des deux. Il n'y a donc pas de section
-- « reparation ponctuelle » ici, contrairement aux autres lots du jour.


-- =============================================================================
-- 1. 20260920121515 — LA DESTINATION D'UN LOYER NE SE LIT PLUS DANS LE BAIL
-- =============================================================================
-- §6.3 — LA DESTINATION D'UN LOYER NE SE LIT PLUS DANS LE BAIL
-- ---------------------------------------------------------------------------
-- L'INVARIANT VIOLE. prelever_loyer_bail() est une RPC rigoureuse : FOR UPDATE,
-- anti-rejeu par jourPaiement, credit avant debit, aucune destination implicite.
-- Toute cette rigueur etait sans effet, parce que son ENTREE est falsifiable :
-- locations_actives est ouverte en ecriture directe a tout joueur connecte
-- (verifie sous veritable role authenticated). Un joueur pouvait donc ecrire
--     destinationLoyer = {"type":"titulaire_murs","titulaire":"<lui-meme>"}
-- sur le bail d'autrui, et la RPC payait fidelement -- elle lit le `titulaire`
-- explicite EN PRIORITE, un repli de compatibilite pour les baux anterieurs.
--
-- CE QUI CHANGE. La destination est desormais DERIVEE du local, jamais lue dans
-- le bail. C'est un portage fidele de destinationLoyerPourLocal()
-- (plateau-immobilier.js) : meme regle, meme ordre, memes quatre cas. Le champ
-- destinationLoyer du bail devient purement informatif.
--
-- L'INVARIANT AJOUTE : une destination ne peut designer que LE BIEN DU BAIL.
--   * titulaire_murs  -> plus jamais de titulaire explicite. Le proprietaire est
--                        resolu dans terrains_etat au moment du prelevement, ce
--                        que la RPC savait deja faire (c'etait meme le
--                        comportement voulu, documente comme tel : « le loyer
--                        appartient au proprietaire ACTUEL »).
--   * caisse_batiment -> le buildingId est celui du bail, pas un autre. Sans
--                        cela, on pouvait diriger un loyer vers la caisse d'une
--                        institution que l'on dirige.
--   * municipal       -> pays et ville sont ceux du bail.
--
-- Cela NE FERME PAS l'ecriture directe sur locations_actives : fabriquer ou
-- resilier un bail reste possible et reste a traiter. Mais l'argent, lui, ne
-- peut plus etre detourne vers une poche choisie.

CREATE OR REPLACE FUNCTION public.bail_destination_attestee(p_data jsonb)
RETURNS jsonb
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    -- Un bail sans loyer reel n'a pas de destination.
    WHEN coalesce((p_data ->> 'chambreClinique')::boolean, false) THEN NULL
    -- Box portuaire multi-tenant : caisse du batiment DU BAIL.
    WHEN coalesce((p_data ->> 'isBox')::boolean, false)
      THEN jsonb_build_object('type', 'caisse_batiment',
                              'buildingId', p_data ->> 'buildingId')
    -- Lot dynamique d'un bien subdivise : le proprietaire des murs, resolu au
    -- moment du prelevement. Aucun titulaire n'est inscrit ici, volontairement.
    WHEN left(coalesce(p_data ->> 'roomId', ''), 8) = 'lot_dyn_'
      THEN jsonb_build_object('type', 'titulaire_murs')
    -- Tout le reste : la commune du bail.
    ELSE jsonb_build_object('type', 'municipal',
                            'pays',  coalesce(p_data ->> 'country', 'republic'),
                            'ville', coalesce(p_data ->> 'city', 'capitale'))
  END;
$$;
REVOKE ALL ON FUNCTION public.bail_destination_attestee(jsonb) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.bail_destination_attestee(jsonb) TO service_role;


-- =============================================================================
-- 1 bis. prelever_loyer_bail() REBRANCHEE SUR LA DESTINATION ATTESTEE
-- =============================================================================
-- LA MIGRATION D'ORIGINE NE POUVAIT PAS ETRE RECOPIEE TELLE QUELLE. Elle
-- procedait par un DO $mig$ qui relisait pg_proc.prosrc et y faisait DEUX
-- remplacements de texte, avec RAISE EXCEPTION si le motif etait introuvable.
-- Un tel patch n'est rejouable que sur la version exacte d'avant : rejoue sur
-- l'etat actuel, il echouerait (« bloc destination introuvable »), et sur un
-- autre etat il produirait un resultat different. Conformement a la regle du
-- lot -- on photographie l'ETAT FINAL, pas le chemin -- la fonction est ici
-- redonnee ENTIERE, exactement telle que la production la porte
-- (pg_get_functiondef, 20 septembre 2026).
--
-- LES DEUX SEULS CHANGEMENTS APPORTES CE JOUR-LA, tous deux visibles ci-dessous
-- et commentes sur place :
--   (a) la destination vient de bail_destination_attestee(), plus du bail ;
--   (b) v_titulaire n'est plus lu dans la destination : il est force a NULL,
--       donc le proprietaire reel de terrains_etat fait toujours foi.
--
-- ARTEFACT CONSERVE TEL QUEL : le test `IF v_dest IS NULL OR jsonb_typeof(v_dest)
-- = 'null'` qui suit immediatement le nouveau bloc est desormais redondant (le
-- bloc au-dessus a deja traite le cas NULL). Il est en production, il est donc
-- ici. On ne corrige rien.
--
-- AUCUN GRANT n'est repose : le CREATE OR REPLACE de production conservait les
-- droits existants, qui viennent de migration_loyers_unifies_lot14.sql.

CREATE OR REPLACE FUNCTION public.prelever_loyer_bail(p_bail_id text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
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
  SELECT *
  INTO v_bail
  FROM locations_actives
  WHERE id = p_bail_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN 'bail_absent';
  END IF;

  v_data      := v_bail.data;
  v_locataire := v_data ->> 'locataire';
  v_prix      := COALESCE((v_data ->> 'prix')::numeric, 0);

  -- Anti-rejeu : un seul prélèvement par bail et par jour réel.
  IF (v_data ->> 'jourPaiement') = v_jour THEN
    RETURN 'deja_preleve';
  END IF;

  -- Usages sans loyer réel.
  IF v_prix <= 0
     OR (v_data ->> 'chambreClinique') = 'true'
     OR v_locataire IS NULL
  THEN
    UPDATE locations_actives
    SET data = v_data || jsonb_build_object('jourPaiement', v_jour)
    WHERE id = p_bail_id;

    RETURN 'ignore_sans_loyer';
  END IF;

  -- DESTINATION ATTESTEE (20 septembre 2026). Elle n'est plus lue dans le bail --
  -- ecriture directe falsifiable -- mais DERIVEE du local, par la meme regle que le
  -- client (destinationLoyerPourLocal). Le champ destinationLoyer du bail n'est plus
  -- qu'informatif. Fail-closed inchange : pas de destination -> pas de mouvement.
  v_dest := public.bail_destination_attestee(v_data);
  IF v_dest IS NULL THEN
    UPDATE locations_actives
    SET data = v_data || jsonb_build_object('jourPaiement', v_jour)
    WHERE id = p_bail_id;
    RETURN 'ignore_sans_loyer';
  END IF;

  IF v_dest IS NULL OR jsonb_typeof(v_dest) = 'null' THEN
    UPDATE locations_actives
    SET data = v_data || jsonb_build_object('jourPaiement', v_jour)
    WHERE id = p_bail_id;

    RETURN 'ignore_sans_loyer';
  END IF;

  v_dest_type := v_dest ->> 'type';

  -- Verrou du locataire.
  SELECT arg
  INTO v_arg
  FROM personnages
  WHERE name = v_locataire
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN 'locataire_absent';
  END IF;

  -- Impayé.
  IF COALESCE(v_arg, 0) < v_prix THEN
    IF COALESCE((v_data ->> 'avertissement')::boolean, false) THEN
      RETURN 'expulsion_requise';
    END IF;

    UPDATE locations_actives
    SET data = v_data
      || jsonb_build_object(
           'avertissement', true,
           'jourPaiement', v_jour
         )
    WHERE id = p_bail_id;

    RETURN 'avertissement';
  END IF;

  -- Crédit de la destination.
  IF v_dest_type = 'municipal' THEN

    v_pays  := COALESCE(v_dest ->> 'pays',  v_data ->> 'country');
    v_ville := COALESCE(v_dest ->> 'ville', v_data ->> 'city');
    v_cle   := v_pays || '_' || v_ville;

    UPDATE budgets_municipaux
    SET data = jsonb_set(
                 COALESCE(data, '{}'::jsonb),
                 '{caisse}',
                 to_jsonb(
                   COALESCE((data ->> 'caisse')::numeric, 0) + v_prix
                 )
               ),
        updated_at = now()
    WHERE id = v_cle;

    GET DIAGNOSTICS v_maj = ROW_COUNT;

    IF v_maj = 0 THEN
      INSERT INTO budgets_municipaux (id, data, updated_at)
      VALUES (
        v_cle,
        jsonb_build_object('caisse', v_prix),
        now()
      );
    END IF;

  ELSIF v_dest_type = 'titulaire_murs' THEN

    -- Le titulaire explicite n'est PLUS lu : c'etait la porte par laquelle un bail
    -- falsifie redirigeait le loyer. Le proprietaire ACTUEL fait foi, toujours.
    v_titulaire := NULL;

    IF v_titulaire IS NULL OR v_titulaire = '' THEN
      SELECT (data::jsonb ->> 'proprietaire')
      INTO v_titulaire
      FROM terrains_etat
      WHERE country = (v_data ->> 'country')
        AND building_id = (v_data ->> 'buildingId');
    END IF;

    IF v_titulaire IS NULL OR v_titulaire = '' THEN
      RAISE EXCEPTION 'destination_introuvable';
    END IF;

    -- Organisation propriétaire.
    IF left(v_titulaire, 5) = 'orga:' THEN

      v_orga_id := substr(v_titulaire, 6);

      IF v_orga_id = '' THEN
        RAISE EXCEPTION 'destination_introuvable';
      END IF;

      SELECT data
      INTO v_orga_data
      FROM organisations
      WHERE id = v_orga_id
      FOR UPDATE;

      IF NOT FOUND THEN
        RAISE EXCEPTION 'destination_introuvable';
      END IF;

      IF v_orga_data IS NULL OR btrim(v_orga_data) = '' THEN
        RAISE EXCEPTION 'destination_introuvable';
      END IF;

      UPDATE organisations
      SET data = jsonb_set(
                   v_orga_data::jsonb,
                   '{caisse}',
                   to_jsonb(
                     COALESCE(
                       (v_orga_data::jsonb ->> 'caisse')::numeric,
                       0
                     ) + v_prix
                   )
                 )::text
      WHERE id = v_orga_id;

    ELSE

      -- PJ propriétaire, avec compatibilité ancien format nom brut.
      IF left(v_titulaire, 3) = 'pj:' THEN
        v_titulaire := substr(v_titulaire, 4);
      END IF;

      UPDATE personnages
      SET arg = COALESCE(arg, 0) + v_prix
      WHERE name = v_titulaire;

      GET DIAGNOSTICS v_maj = ROW_COUNT;

      IF v_maj = 0 THEN
        RAISE EXCEPTION 'destination_introuvable';
      END IF;

    END IF;

  ELSIF v_dest_type = 'caisse_batiment' THEN

    v_building := COALESCE(
      v_dest ->> 'buildingId',
      v_data ->> 'buildingId'
    );

    v_cle := (v_data ->> 'country') || '_' || v_building;

    UPDATE caisses_batiments
    SET data = jsonb_set(
                 COALESCE(data, '{}'::jsonb),
                 '{solde}',
                 to_jsonb(
                   COALESCE((data ->> 'solde')::numeric, 0) + v_prix
                 )
               ),
        updated_at = now()
    WHERE id = v_cle;

    GET DIAGNOSTICS v_maj = ROW_COUNT;

    IF v_maj = 0 THEN
      INSERT INTO caisses_batiments (id, data, updated_at)
      VALUES (
        v_cle,
        jsonb_build_object('solde', v_prix),
        now()
      );
    END IF;

  ELSE
    RAISE EXCEPTION 'destination_introuvable';
  END IF;

  -- Débit du locataire seulement après crédit valide.
  UPDATE personnages
  SET arg = COALESCE(arg, 0) - v_prix
  WHERE name = v_locataire;

  UPDATE locations_actives
  SET data = (v_data - 'avertissement')
    || jsonb_build_object(
         'jourPaiement', v_jour,
         'dernierLoyerPaye', v_jour
       )
  WHERE id = p_bail_id;

  RETURN 'paye';
END;
$$;


-- =============================================================================
-- 2. 20260920130008 — FERMETURE DE locations_actives
-- =============================================================================
-- §6.3 — FERMETURE DE locations_actives
-- ---------------------------------------------------------------------------
-- EXPLOITS MESURES sous veritable role authenticated : fabriquer un bail a
-- 999 999 FR sur le bien d'autrui, et resilier le bail d'autrui. (Le troisieme,
-- le detournement du beneficiaire, a ete neutralise au lot precedent en derivant
-- la destination du local au lieu de la lire dans le bail.)
--
-- INVENTAIRE DES 12 PRODUCTEURS, fait avant d'ecrire la moindre regle. Ils se
-- ramenent a TROIS autorites, et pas une de moins :
--
--   (1) LE LOCATAIRE LUI-MEME -- 9 sites sur 12 :
--       confirmerLocation, doLouerCeLot, confirmerLocationBox,
--       doTransfertCliniquePrivee (le patient est l'appelant : verifie),
--       confirmerVisitesChambreUI, resilierBox,
--       resilierLogementSocialSiDepartMontrouge, libererChambreCliniquePatient,
--       et la reconversion d'entrepot dans payerLocations -- qui ne traite que
--       les baux dont on est titulaire (garde estTitulaire(), verifiee).
--   (2) LA MAIRIE DE LA VILLE -- attribution et retrait d'un logement social
--       (attribuerLogementSocial, Montrouge). Maire ou Maire Adjoint.
--   (3) LE PROPRIETAIRE DES MURS -- suppression du bail d'un lot quand il
--       supprime la subdivision (doSupprimerSubdivision -> supprimerBailDuLot).
--
-- On ne simplifie PAS ces trois regles en une seule : un locataire n'est pas un
-- proprietaire, et la mairie n'a d'autorite que sur sa ville.
--
-- LA LECTURE RESTE OUVERTE. sbLoadLocations charge tous les baux du pays pour
-- afficher l'occupation des locaux -- c'est une information publique dans le
-- jeu, et la fermer casserait l'affichage. Signale comme tel.

CREATE OR REPLACE FUNCTION public.bail_je_suis_locataire(p_data jsonb)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$ SELECT coalesce(p_data ->> 'locataire', '') = coalesce(public.mon_personnage(), '\x00'); $$;

-- Autorite municipale : maire ou adjoint DE LA VILLE du bail. La ville vient du
-- poste, jamais de la position du personnage.
CREATE OR REPLACE FUNCTION public.bail_autorite_municipale(p_data jsonb)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.personnages_donnees d
     WHERE d.user_id = auth.uid()
       AND (d.poste ->> 'id') IN ('maire', 'maire_adjoint')
       AND (d.poste ->> 'city') IS NOT DISTINCT FROM coalesce(p_data ->> 'city', 'capitale')
  );
$$;

-- Proprietaire des murs. terrains_etat.data est un TEXTE contenant du JSON, et
-- le proprietaire peut etre nu, prefixe 'pj:' ou 'orga:' (reference typee du
-- Lot 1.0 bis). On ne reconnait ici que la personne : une organisation
-- proprietaire n'a pas d'utilisateur connecte a qui attribuer l'ecriture.
CREATE OR REPLACE FUNCTION public.bail_proprietaire_des_murs(p_data jsonb)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_moi text; v_prop text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN false; END IF;
  SELECT (t.data::jsonb ->> 'proprietaire') INTO v_prop
    FROM public.terrains_etat t
   WHERE t.country = coalesce(p_data ->> 'country', 'republic')
     AND t.building_id = (p_data ->> 'buildingId')
   LIMIT 1;
  IF v_prop IS NULL OR btrim(v_prop) = '' THEN RETURN false; END IF;
  IF left(v_prop, 3) = 'pj:' THEN v_prop := substr(v_prop, 4); END IF;
  RETURN v_prop = v_moi;
EXCEPTION WHEN OTHERS THEN
  RETURN false;   -- data illisible : aucune autorite accordee
END;
$$;

CREATE OR REPLACE FUNCTION public.bail_autorite_de(p_data jsonb)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT public.bail_je_suis_locataire(p_data)
      OR public.bail_autorite_municipale(p_data)
      OR public.bail_proprietaire_des_murs(p_data);
$$;

REVOKE ALL ON FUNCTION public.bail_je_suis_locataire(jsonb)      FROM public, anon;
REVOKE ALL ON FUNCTION public.bail_autorite_municipale(jsonb)    FROM public, anon;
REVOKE ALL ON FUNCTION public.bail_proprietaire_des_murs(jsonb)  FROM public, anon;
REVOKE ALL ON FUNCTION public.bail_autorite_de(jsonb)            FROM public, anon;
GRANT EXECUTE ON FUNCTION public.bail_je_suis_locataire(jsonb)     TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.bail_autorite_municipale(jsonb)   TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.bail_proprietaire_des_murs(jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.bail_autorite_de(jsonb)           TO authenticated, service_role;

-- LA CLE DOIT DECRIRE LE BAIL QU'ELLE PORTE.
-- L'identifiant est deterministe cote client :
--     pays:buildingId:roomId:ville           (bail exclusif)
--     pays:buildingId:roomId:ville:locataire (box portuaire, multi-tenant)
-- C'est cette cle qui porte l'invariant « jamais deux baux actifs sur le meme
-- local » -- l'atomicite de la prise de bail repose entierement sur la PRIMARY
-- KEY. Un id qui ne correspondrait pas a son contenu permettrait d'ouvrir un
-- second bail sur un local deja occupe : on l'interdit ici plutot que de s'en
-- remettre a la bonne foi du client.
CREATE OR REPLACE FUNCTION public.bail_cle_coherente()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_base text;
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;
  IF NEW.data IS NULL THEN
    RAISE EXCEPTION 'bail_sans_donnees' USING ERRCODE = '42501';
  END IF;
  v_base := coalesce(NEW.data ->> 'country', 'republic') || ':' ||
            coalesce(NEW.data ->> 'buildingId', '')      || ':' ||
            coalesce(NEW.data ->> 'roomId', '')          || ':' ||
            coalesce(NEW.data ->> 'city', '');
  IF NEW.id <> v_base
     AND NEW.id <> v_base || ':' || coalesce(NEW.data ->> 'locataire', '') THEN
    RAISE EXCEPTION 'bail_cle_incoherente' USING ERRCODE = '42501';
  END IF;
  -- Le pays de la colonne doit suivre celui du bail.
  IF coalesce(NEW.country, '') IS DISTINCT FROM coalesce(NEW.data ->> 'country', 'republic') THEN
    NEW.country := NEW.data ->> 'country';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_bail_cle_coherente ON public.locations_actives;
CREATE TRIGGER trg_bail_cle_coherente
  BEFORE INSERT OR UPDATE ON public.locations_actives
  FOR EACH ROW EXECUTE FUNCTION public.bail_cle_coherente();

-- Les politiques existantes etaient en USING (true) / WITH CHECK (true).
DROP POLICY IF EXISTS "Ecriture publique locations" ON public.locations_actives;
DROP POLICY IF EXISTS "Lecture publique locations"  ON public.locations_actives;
DROP POLICY IF EXISTS "Maj publique locations"      ON public.locations_actives;

CREATE POLICY locations_lecture ON public.locations_actives
  FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY locations_ecriture ON public.locations_actives
  FOR INSERT TO authenticated WITH CHECK (public.bail_autorite_de(data));

CREATE POLICY locations_maj ON public.locations_actives
  FOR UPDATE TO authenticated
  USING (public.bail_autorite_de(data))
  WITH CHECK (public.bail_autorite_de(data));

CREATE POLICY locations_resiliation ON public.locations_actives
  FOR DELETE TO authenticated USING (public.bail_autorite_de(data));

ALTER TABLE public.locations_actives ENABLE ROW LEVEL SECURITY;
