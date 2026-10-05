-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920132657
-- Nom original      : guerres_autorite_serveur
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-20 13:26:57 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 37037768d09aea6cbb89a7140e43a7f6
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
-- §6.3 — LA TABLE guerres PASSE AU SERVEUR
-- ---------------------------------------------------------------------------
-- ETAT CONSTATE : table absente des migrations du depot (creee hors depot),
-- RLS desactivee, trois politiques en USING(true), et DEUX ecritures directes
-- depuis le navigateur -- la seule table du chantier militaire dans ce cas,
-- alors que trois RPC militaires lisent son contenu pour decider si un combat
-- est legal.
--
-- LES QUATRE AUTORITES, etablies avant d'ecrire quoi que ce soit :
--   * DECLARER LA GUERRE ...... president. Attestee par une garde explicite dans
--     le code : exigerPoste('president', 'Seul le President peut declarer la guerre.').
--   * PROPOSER UNE TREVE ....... min_ae. Attestee : l'ordre 'proposer_treve' est
--     declare avec requiresPost:'min_ae'.
--   * ACTIVER LE CESSEZ-LE-FEU . min_def. Doublement attestee : l'ordre
--     'activer_cessez_le_feu' declare requiresPost:'min_def', et l'ecran porte
--     la garde state.poste?.id !== 'min_def'.
--   * ACCEPTER LA TREVE ........ ISOLEE. La fonction accepterTreve() existe mais
--     n'a AUCUN appelant et AUCUNE garde : l'etape est injoignable aujourd'hui.
--     On ne lui invente donc pas d'autorite ; elle n'a pas de porte serveur ici.
--
-- AUCUNE REGLE DIPLOMATIQUE N'EST MODIFIEE. Meme forme de donnees, memes
-- statuts, meme sequence. Seul change qui a le droit d'ecrire.

CREATE OR REPLACE FUNCTION public.guerre_acteur_poste(p_poste text)
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT coalesce(d.country, 'republic')
    FROM public.personnages_donnees d
   WHERE d.user_id = auth.uid() AND (d.poste ->> 'id') = p_poste
   LIMIT 1;
$$;
REVOKE ALL ON FUNCTION public.guerre_acteur_poste(text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.guerre_acteur_poste(text) TO authenticated, service_role;

-- 1. DECLARER LA GUERRE — le President, et son pays est celui de sa fiche.
CREATE OR REPLACE FUNCTION public.guerre_declarer(p_pays_attaque text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_pays text; v_id text;
BEGIN
  v_pays := public.guerre_acteur_poste('president');
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_president');
  END IF;
  IF p_pays_attaque IS NULL OR btrim(p_pays_attaque) = '' OR p_pays_attaque = v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide');
  END IF;
  -- Une seule guerre active entre deux memes pays, quel que soit le sens.
  IF EXISTS (SELECT 1 FROM public.guerres g
              WHERE g.statut = 'active'
                AND ((g.data ->> 'attaquant' = v_pays AND g.data ->> 'attaque' = p_pays_attaque)
                  OR (g.data ->> 'attaque' = v_pays AND g.data ->> 'attaquant' = p_pays_attaque))) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'guerre_deja_active');
  END IF;

  v_id := 'guerre-' || (extract(epoch from clock_timestamp()) * 1000)::bigint;
  INSERT INTO public.guerres (id, statut, data)
  VALUES (v_id, 'active', jsonb_build_object(
    'attaquant', v_pays, 'attaque', p_pays_attaque,
    'jourDebut', public.jour_de_jeu_pays(v_pays), 'ceasefire', NULL));

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'attaquant', v_pays, 'attaque', p_pays_attaque);
END;
$$;

-- 2. PROPOSER UNE TREVE — le Ministre des Affaires Etrangeres d'un des deux pays.
CREATE OR REPLACE FUNCTION public.guerre_treve_proposer(p_guerre_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_pays text; v_moi text; g record;
BEGIN
  v_pays := public.guerre_acteur_poste('min_ae');
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_ministre_ae');
  END IF;
  v_moi := public.mon_personnage();

  SELECT * INTO g FROM public.guerres WHERE id = p_guerre_id FOR UPDATE;
  IF NOT FOUND OR g.statut <> 'active' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'guerre_introuvable');
  END IF;
  IF v_pays NOT IN (g.data ->> 'attaquant', g.data ->> 'attaque') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pays_non_belligerant');
  END IF;

  UPDATE public.guerres
     SET data = g.data || jsonb_build_object('ceasefire', jsonb_build_object(
           'proposePar', v_moi, 'accepteePar', NULL, 'actifPar', '{}'::jsonb))
   WHERE id = p_guerre_id;

  RETURN jsonb_build_object('ok', true, 'proposePar', v_moi);
END;
$$;

-- 3. ACTIVER LE CESSEZ-LE-FEU — le Ministre de la Defense, pour SON pays.
--    Quand les deux cotes l'ont active, la guerre se termine. Regle inchangee.
CREATE OR REPLACE FUNCTION public.guerre_cessez_le_feu_activer(p_guerre_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_pays text; g record; v_cf jsonb; v_actif jsonb; v_tous boolean;
BEGIN
  v_pays := public.guerre_acteur_poste('min_def');
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_ministre_defense');
  END IF;

  SELECT * INTO g FROM public.guerres WHERE id = p_guerre_id FOR UPDATE;
  IF NOT FOUND OR g.statut <> 'active' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'guerre_introuvable');
  END IF;
  IF v_pays NOT IN (g.data ->> 'attaquant', g.data ->> 'attaque') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pays_non_belligerant');
  END IF;

  v_cf := g.data -> 'ceasefire';
  IF v_cf IS NULL OR jsonb_typeof(v_cf) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_treve_proposee');
  END IF;

  v_actif := coalesce(v_cf -> 'actifPar', '{}'::jsonb) || jsonb_build_object(v_pays, true);
  v_tous  := (v_actif ? (g.data ->> 'attaquant')) AND (v_actif ? (g.data ->> 'attaque'));

  UPDATE public.guerres
     SET statut = CASE WHEN v_tous THEN 'terminee' ELSE 'active' END,
         data   = g.data || jsonb_build_object('ceasefire', v_cf || jsonb_build_object('actifPar', v_actif))
   WHERE id = p_guerre_id;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'terminee', v_tous);
END;
$$;

REVOKE ALL ON FUNCTION public.guerre_declarer(text) FROM public, anon;
REVOKE ALL ON FUNCTION public.guerre_treve_proposer(text) FROM public, anon;
REVOKE ALL ON FUNCTION public.guerre_cessez_le_feu_activer(text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.guerre_declarer(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.guerre_treve_proposer(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.guerre_cessez_le_feu_activer(text) TO authenticated, service_role;