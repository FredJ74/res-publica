-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260916080143
-- Nom original      : pa_socle_serveur_gains
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-16 08:01:43 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : e87a699ca99e76153341d882d8cc2bbe
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
-- PA SERVEUR-AUTORITAIRES — LOT 1 : LES GAINS PASSENT AU SERVEUR.
--
-- LA FAILLE. personnages.pa est ecrit par le client (sbPayloadPersonnage publie la colonne a
-- chaque sauvegarde de fiche) et payer_ordre lit cette valeur comme solde authentique : un joueur
-- pouvait se donner 999 PA puis faire accepter ses ordres. L'audit a de plus etabli que le CHEMIN
-- GENERIQUE de doOrder ne passe par aucune primitive serveur -- il debite state.pa en memoire et
-- rien d'autre.
--
-- ORDRE DES OPERATIONS. On ne ferme jamais l'ecriture avant d'avoir raccorde les gains : ce lot
-- pose d'abord les primitives de GAIN cote serveur. Le verrou vient au lot suivant.
--
-- AUCUN CHIFFRE DE GAME DESIGN N'EST MODIFIE : plafond 30, +12 par nuit, QHS 1 ou 3 en
-- remplacement, +2 par ration au refectoire, bonus differes 1 ou 3 selon la source. Tout est
-- repris tel quel du client.

-- ---------------------------------------------------------------------------
-- 1. OU LE SERVEUR GARDE SES COMPTEURS. Deux champs neufs, jamais ecrits par un client (le
--    verrou du lot suivant les protege au meme titre que pa).
-- ---------------------------------------------------------------------------
ALTER TABLE public.personnages_donnees
  ADD COLUMN IF NOT EXISTS bonus_pa_differe integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS pa_repos_le date;

-- Valeur de depart d'un personnage : le client la choisissait (creation.js, pa: 10) et pouvait
-- donc naitre avec 999 PA. Elle devient un defaut serveur.
ALTER TABLE public.personnages_donnees ALTER COLUMN pa SET DEFAULT 10;

-- ---------------------------------------------------------------------------
-- 2. MIROIR DES BONUS DIFFERES. Genere depuis les VRAIS modules par
--    .scratch/generer_pa_bonus_differes.py : sans lui, soit le bonus disparait (regression de
--    game design), soit le client choisit son montant (la faille qu'on ferme).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pa_bonus_differes (
  source  text PRIMARY KEY,
  montant integer NOT NULL CHECK (montant > 0 AND montant <= 10)
);
CREATE TABLE IF NOT EXISTS public.pa_bonus_differes_empreinte (
  seul boolean PRIMARY KEY DEFAULT true CHECK (seul), empreinte text NOT NULL, pose_le timestamptz DEFAULT now()
);
DELETE FROM public.pa_bonus_differes;
INSERT INTO public.pa_bonus_differes (source, montant) VALUES
  ('diner_affaires', 3),
  ('menu_gastronomique_1', 3),
  ('menu_gastronomique_2', 3),
  ('menu_gastronomique_3', 3),
  ('menu_psm_1', 3),
  ('menu_psm_2', 3),
  ('menu_psm_3', 3),
  ('repas_gastronomique', 1),
  ('sandwich', 1),
  ('service_etage_hotel', 1);
INSERT INTO public.pa_bonus_differes_empreinte (seul, empreinte) VALUES (true, '1c02ca809fdb9b8b')
ON CONFLICT (seul) DO UPDATE SET empreinte = EXCLUDED.empreinte, pose_le = now();

ALTER TABLE public.pa_bonus_differes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pa_bonus_differes_lecture ON public.pa_bonus_differes;
CREATE POLICY pa_bonus_differes_lecture ON public.pa_bonus_differes
  FOR SELECT TO anon, authenticated USING (true);
REVOKE INSERT, UPDATE, DELETE ON public.pa_bonus_differes FROM anon, authenticated;

-- Bonus de chambre d'hotel : meme doctrine, le montant est declare cote serveur et non lu dans
-- la reservation, que le client ecrit. Recopie de confortMap (plateau-personnage.js).
CREATE TABLE IF NOT EXISTS public.pa_bonus_hotel (
  building_id text PRIMARY KEY,
  montant     integer NOT NULL CHECK (montant > 0 AND montant <= 10)
);
DELETE FROM public.pa_bonus_hotel;
INSERT INTO public.pa_bonus_hotel (building_id, montant) VALUES
  ('hotel-republica', 2), ('hotel-port', 2), ('hotel-mineur', 2), ('palais-presidentiel', 8);
ALTER TABLE public.pa_bonus_hotel ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pa_bonus_hotel_lecture ON public.pa_bonus_hotel;
CREATE POLICY pa_bonus_hotel_lecture ON public.pa_bonus_hotel
  FOR SELECT TO anon, authenticated USING (true);
REVOKE INSERT, UPDATE, DELETE ON public.pa_bonus_hotel FROM anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. PRIMITIVE INTERNE DE CREDIT. Jamais exposee : elle ne porte aucune regle, seulement le
--    plafond. Toutes les RPC de gain passent par elle.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.pa_crediter_interne(p_nom text, p_montant integer)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_pa integer;
BEGIN
  UPDATE public.personnages_donnees
     SET pa = least(30, greatest(0, coalesce(pa, 0) + greatest(0, coalesce(p_montant, 0))))
   WHERE name = p_nom
   RETURNING pa INTO v_pa;
  RETURN v_pa;
END;
$$;
REVOKE ALL ON FUNCTION public.pa_crediter_interne(text, integer) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. BONUS DIFFERE. Le client dit d'ou vient le bonus, le serveur dit combien il vaut.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.pa_bonus_differe_crediter(p_acteur text, p_source text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_montant integer; v_total integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT montant INTO v_montant FROM public.pa_bonus_differes WHERE source = p_source;
  IF v_montant IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'source_non_declaree');
  END IF;
  -- Plafonne a la reserve maximale : une accumulation sans fin n'aurait aucun sens, le bonus
  -- etant consomme au prochain Dormir et le stock plafonne a 30.
  UPDATE public.personnages_donnees
     SET bonus_pa_differe = least(30, coalesce(bonus_pa_differe, 0) + v_montant)
   WHERE name = p_acteur
   RETURNING bonus_pa_differe INTO v_total;
  RETURN jsonb_build_object('ok', true, 'montant', v_montant, 'bonus_differe', v_total);
END;
$$;
REVOKE ALL ON FUNCTION public.pa_bonus_differe_crediter(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pa_bonus_differe_crediter(text, text) TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. REPOS NOCTURNE. Reproduit exactement doDormir : +12, ou remplacement par 1/3 en QHS, plus
--    le bonus differe atteste, le tout plafonne a 30.
--
--    ANCRAGE. Le client ne peut plus servir d'horloge : state.day et dernier_dormir sont des
--    colonnes qu'il ecrit. Le rythme reel du jeu est d'une recuperation par jour REEL -- c'est
--    runMidnightUpdate, declenche a minuit reel, qui fait avancer state.day et donc rouvre le
--    droit de dormir. On ancre donc la garde sur la date de Paris, ce qui reproduit le rythme
--    existant sans rien devoir au client. Le temps du jeu n'est pas redessine : seule la
--    recuperation des PA est gardee ici.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.pa_repos_nocturne(p_acteur text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_pa integer; v_qhs jsonb; v_bonus integer; v_deja date;
  v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_nouveau integer; v_plafond_qhs integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT coalesce(pa, 0), detention_qhs, coalesce(bonus_pa_differe, 0), pa_repos_le
    INTO v_pa, v_qhs, v_bonus, v_deja
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;
  IF v_deja IS NOT NULL AND v_deja >= v_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_repose', 'pa', v_pa);
  END IF;

  IF v_qhs IS NOT NULL AND jsonb_typeof(v_qhs) = 'object' AND (v_qhs ->> 'enQHS')::boolean IS TRUE THEN
    -- Sanction QHS : REMPLACE le stock, elle ne s'y ajoute pas (comportement d'origine).
    v_plafond_qhs := CASE WHEN (v_qhs ->> 'paLimite1Jour')::boolean IS TRUE THEN 1 ELSE 3 END;
    v_nouveau := least(30, greatest(0, v_plafond_qhs + v_bonus));
    IF (v_qhs ->> 'paLimite1Jour')::boolean IS TRUE THEN
      UPDATE public.personnages_donnees
         SET detention_qhs = v_qhs || jsonb_build_object('paLimite1Jour', false)
       WHERE name = p_acteur;
    END IF;
  ELSE
    v_nouveau := least(30, greatest(0, v_pa + 12 + v_bonus));
  END IF;

  UPDATE public.personnages_donnees
     SET pa = v_nouveau, bonus_pa_differe = 0, pa_repos_le = v_jour
   WHERE name = p_acteur;

  RETURN jsonb_build_object('ok', true, 'pa', v_nouveau, 'bonus_consomme', v_bonus,
                            'qhs', (v_qhs ->> 'enQHS')::boolean IS TRUE);
END;
$$;
REVOKE ALL ON FUNCTION public.pa_repos_nocturne(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pa_repos_nocturne(text) TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 6. BONUS DE CHAMBRE D'HOTEL. Une fois par repos, et seulement apres lui.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.pa_bonus_chambre(p_acteur text, p_batiment text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_montant integer; v_pa integer; v_resa jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT montant INTO v_montant FROM public.pa_bonus_hotel WHERE building_id = p_batiment;
  IF v_montant IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hotel_non_declare');
  END IF;
  SELECT reservation_hotel INTO v_resa
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_resa IS NULL OR jsonb_typeof(v_resa) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_reservation');
  END IF;
  -- La reservation est consommee ici : un bonus par sejour, jamais rejouable.
  UPDATE public.personnages_donnees SET reservation_hotel = NULL WHERE name = p_acteur;
  v_pa := public.pa_crediter_interne(p_acteur, v_montant);
  RETURN jsonb_build_object('ok', true, 'pa', v_pa, 'montant', v_montant);
END;
$$;
REVOKE ALL ON FUNCTION public.pa_bonus_chambre(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pa_bonus_chambre(text, text) TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 7. REFECTOIRE : le montant cesse de venir du client.
--    p_pa_max et p_gain etaient des parametres : un client pouvait demander p_gain = 999.
--    Ils sont conserves dans la signature pour ne casser aucun appelant, mais IGNORES.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.refectoire_repas(
  p_pays text, p_joueur text, p_jour integer,
  p_pa_max integer DEFAULT 30, p_gain integer DEFAULT 2)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_pj public.personnages%ROWTYPE; v_stats jsonb; v_data jsonb; v_ref jsonb;
  v_rations integer; v_pa integer;
BEGIN
  PERFORM public.exiger_acteur(p_joueur);
  IF COALESCE(btrim(p_pays), '') = '' OR COALESCE(btrim(p_joueur), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  SELECT * INTO v_pj FROM public.personnages WHERE name = p_joueur FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_absent'); END IF;
  IF COALESCE(v_pj.current_building, '') <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  v_stats := CASE WHEN jsonb_typeof(v_pj.stats) = 'object' THEN v_pj.stats ELSE '{}'::jsonb END;
  IF COALESCE((v_stats ->> 'repasCaserneJour')::integer, -1) = p_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_mange');
  END IF;

  SELECT data INTO v_data FROM public.budgets_nationaux WHERE id = p_pays FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'refectoire_vide'); END IF;
  v_data := COALESCE(v_data, '{}'::jsonb);
  v_ref := COALESCE(v_data -> 'refectoire', '{}'::jsonb);
  v_rations := COALESCE((v_ref ->> 'rations')::integer, 0);
  IF v_rations <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'refectoire_vide'); END IF;

  UPDATE public.budgets_nationaux
     SET data = v_data || jsonb_build_object('refectoire', v_ref || jsonb_build_object('rations', v_rations - 1))
   WHERE id = p_pays;

  -- +2 PA, plafond 30 : constantes SERVEUR. p_gain et p_pa_max sont ignores.
  v_pa := LEAST(30, GREATEST(0, COALESCE(v_pj.pa, 0)) + 2);
  UPDATE public.personnages_donnees
     SET pa = v_pa, stats = v_stats || jsonb_build_object('repasCaserneJour', p_jour)
   WHERE name = p_joueur;

  RETURN jsonb_build_object('ok', true, 'pa', v_pa, 'gain', 2, 'rations_restantes', v_rations - 1);
END;
$$;