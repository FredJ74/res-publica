-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919232339
-- Nom original      : salaire_civil_atteste
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-19 23:23:39 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : f2a06ee3f1735bcfbeafe113c91adaf1
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
-- =====================================================================
-- §2 — LE SALAIRE CIVIL CESSE D'ETRE CREE PAR LE NAVIGATEUR
-- =====================================================================
-- AUJOURD'HUI : plateau-personnage.js:1756 fait, a l'ordre Dormir,
--     state.arg += salaire ; state.liquide += salaire ;
-- le montant venant de SALAIRES[poste] lu DANS LE NAVIGATEUR. Le depot le
-- documente lui-meme (data.js:7330) comme « de la creation monetaire cliente ».
-- 17 entrees de SALAIRES + 7 offres du Bureau National de l'Emploi = 24 sources.
--
-- CE LOT CHANGE L'AUTORITE, PAS L'ECONOMIE.
--   CHANGE : le montant est decide par le serveur depuis un miroir declare,
--            l'anti-rejeu est porte par une cle unique, le credit est fait en
--            base. Le navigateur ne peut plus annoncer ce que vaut son salaire.
--   NE CHANGE PAS : aucune caisse n'est debitee, exactement comme aujourd'hui.
--            Le revenu universel de 150 FR est une creation monetaire assumee
--            (decision GD). Pour les salaires de POSTE et d'EMPLOI, le financeur
--            reel n'est pas tranche : decider ici reviendrait a inventer une
--            regle economique. Point inscrit en arbitrage GD, mecanique actuelle
--            reproduite a l'identique.
--
-- MODELE REUTILISE : militaire_solde_percevoir, deja en production — identite par
-- mon_personnage(), bareme serveur, anti-rejeu par la cle, et JOUR REEL
-- (now() AT TIME ZONE 'Europe/Paris')::date plutot qu'un compteur client.

CREATE TABLE IF NOT EXISTS public.salaires_civils_declares (
  cle       text PRIMARY KEY,
  categorie text NOT NULL CHECK (categorie IN ('poste','emploi','universel')),
  montant   integer NOT NULL CHECK (montant >= 0)
);
ALTER TABLE public.salaires_civils_declares ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.salaires_civils_declares FROM PUBLIC, anon, authenticated;

INSERT INTO public.salaires_civils_declares (cle, categorie, montant) VALUES
  ('president','poste',5000), ('pm','poste',3500),
  ('min_int','poste',2800), ('min_fin','poste',2800), ('min_just','poste',2800),
  ('min_def','poste',2800), ('min_info','poste',2800), ('min_ae','poste',2800),
  ('depute','poste',1200), ('senateur','poste',1200),
  ('juge','poste',1800), ('commissaire','poste',1000),
  ('maire','poste',800), ('adj_maire','poste',500),
  ('gouverneur','poste',1500), ('prefet','poste',900),
  ('serveur_luthecia','emploi',200), ('docker_psm','emploi',220),
  ('hotelier_montrouge','emploi',250), ('secretaire_nationale','emploi',300),
  ('commercant_national','emploi',220), ('banquier_national','emploi',450),
  ('hotesse_ambassade','emploi',280),
  ('default','universel',150)
ON CONFLICT (cle) DO UPDATE SET categorie = EXCLUDED.categorie, montant = EXCLUDED.montant;

CREATE TABLE IF NOT EXISTS public.salaires_civils_verses (
  id         text PRIMARY KEY,           -- <personnage>:<date> : l'anti-rejeu EST la cle
  personnage text NOT NULL,
  jour       date NOT NULL,
  origine    text NOT NULL,
  cle        text NOT NULL,
  montant    integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.salaires_civils_verses ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.salaires_civils_verses FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.salaire_civil_percevoir()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE
  v_moi text; v_pays text; v_poste text; v_grade text;
  v_jour date; v_id text; v_cle text; v_origine text; v_montant integer;
  v_offres jsonb; v_offre text;
  v_arg numeric; v_liquide numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT coalesce(country,'republic'), poste ->> 'id'
    INTO v_pays, v_poste
    FROM public.personnages_donnees WHERE name = v_moi;

  -- Les militaires sont payes par la caserne : jamais ici.
  v_grade := public.militaire_grade_effectif(v_moi);
  IF v_grade IS NOT NULL OR coalesce(v_poste,'') IN ('soldat','lieutenant','capitaine','commandant') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'paye_par_la_caserne');
  END IF;

  IF v_poste IS NOT NULL THEN
    SELECT s.cle, s.categorie, s.montant INTO v_cle, v_origine, v_montant
      FROM public.salaires_civils_declares s WHERE s.cle = v_poste AND s.categorie = 'poste';
  END IF;

  IF v_cle IS NULL THEN
    SELECT coalesce(e.data -> 'offres', e.data -> 'bne' -> 'offres')
      INTO v_offres FROM public.batiments_etat e WHERE e.id = v_pays || '_national_bne';
    IF v_offres IS NOT NULL AND jsonb_typeof(v_offres) = 'object' THEN
      SELECT t.k INTO v_offre
        FROM jsonb_each(v_offres) AS t(k, v)
        WHERE EXISTS (
          SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(t.v)='array' THEN t.v ELSE '[]'::jsonb END) o
           WHERE o ->> 'pjNom' = v_moi AND coalesce(o ->> 'statut','actif') = 'actif')
        LIMIT 1;
      IF v_offre IS NOT NULL THEN
        SELECT s.cle, s.categorie, s.montant INTO v_cle, v_origine, v_montant
          FROM public.salaires_civils_declares s WHERE s.cle = v_offre AND s.categorie = 'emploi';
      END IF;
    END IF;
  END IF;

  IF v_cle IS NULL THEN
    SELECT s.cle, s.categorie, s.montant INTO v_cle, v_origine, v_montant
      FROM public.salaires_civils_declares s WHERE s.cle = 'default';
  END IF;

  IF v_montant IS NULL OR v_montant <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bareme_absent');
  END IF;

  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_id   := v_moi || ':' || v_jour::text;

  BEGIN
    INSERT INTO public.salaires_civils_verses (id, personnage, jour, origine, cle, montant)
    VALUES (v_id, v_moi, v_jour, v_origine, v_cle, v_montant);
  EXCEPTION WHEN unique_violation THEN
    SELECT coalesce(arg,0), coalesce(liquide,0) INTO v_arg, v_liquide
      FROM public.personnages_donnees WHERE name = v_moi;
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_percu_aujourdhui',
                              'jour', v_jour, 'arg', v_arg, 'liquide', v_liquide);
  END;

  UPDATE public.personnages_donnees
     SET liquide = coalesce(liquide,0) + v_montant,
         arg     = coalesce(arg,0)     + v_montant,
         updated_at = now()
   WHERE name = v_moi
   RETURNING arg, liquide INTO v_arg, v_liquide;

  RETURN jsonb_build_object('ok', true, 'montant', v_montant, 'origine', v_origine,
                            'cle', v_cle, 'jour', v_jour, 'arg', v_arg, 'liquide', v_liquide);
END;
$fn$;

REVOKE ALL ON FUNCTION public.salaire_civil_percevoir() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.salaire_civil_percevoir() TO authenticated, service_role;