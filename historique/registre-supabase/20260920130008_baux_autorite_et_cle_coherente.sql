-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920130008
-- Nom original      : baux_autorite_et_cle_coherente
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-20 13:00:08 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 8c15ebb46f84c709fb093c2304167fc7
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