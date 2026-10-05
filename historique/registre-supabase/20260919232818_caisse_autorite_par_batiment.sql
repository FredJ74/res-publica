-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919232818
-- Nom original      : caisse_autorite_par_batiment
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-19 23:28:18 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : d6f6081b7d561d93647fbbbb8540735a
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
-- §1A — LA CAISSE N'EST PLUS « VOICI UNE CAISSE, VOICI ±N »
-- =====================================================================
-- LE DEFAUT DU LOT PRECEDENT, RECONNU. caisse_client_mouvement n'exigeait que
-- « la caisse existe et appartient au pays du joueur ». Etre citoyen ne donne
-- evidemment pas le droit de debiter le Palais presidentiel.
--
-- LE MODELE REPRIS, ET IL EXISTAIT DEJA : caisse_ministere_mouvement derive le
-- poste requis DE L'IDENTIFIANT DE LA CAISSE (<pays>_gouvernement-<poste>) puis
-- appelle exiger_poste(). On generalise exactement ce raisonnement a toutes les
-- caisses institutionnelles, via un registre -- plutot que d'ecrire une RPC par
-- batiment.
--
-- ASYMETRIE ASSUMEE, ET ELLE EST FONDEE :
--   DEBIT  = sortir de l'argent public. Exige le poste qui repond de cette
--            caisse. C'est l'exploit demontre par l'audit (Palais vide a 0).
--   CREDIT = verser dans une caisse publique. 17 des 29 sites du jeu sont des
--            recettes (taxe, vente, amende, cotisation) versees par un citoyen
--            ordinaire, qui n'a par construction aucun poste. Les exiger d'un
--            poste casserait l'economie entiere sans fermer aucun exploit :
--            donner de l'argent a l'Etat n'est pas une attaque.
--            La creation monetaire, elle, est fermee ailleurs -- c'est la fiche
--            du joueur qui ne doit pas pouvoir fabriquer la somme versee.
--
-- Les caisses NON institutionnelles (marche, hotel, stade, dispensaire, port,
-- lieux de culte...) n'ont pas de poste titulaire identifiable : leurs debits
-- restent ouverts et JOURNALISES, en attendant que chaque mecanique marchande
-- porte elle-meme son autorite. C'est dit tel quel, pas presente comme ferme.

CREATE TABLE IF NOT EXISTS public.caisses_autorites (
  motif        text PRIMARY KEY,   -- suffixe de batiment, apres <pays>_
  est_prefixe  boolean NOT NULL DEFAULT false,
  postes_debit text[]  NOT NULL,
  note         text
);
ALTER TABLE public.caisses_autorites ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.caisses_autorites FROM PUBLIC, anon, authenticated;

INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES
  ('palais-presidentiel', false, '{president}',              'presidence'),
  ('gouvernement-',       true,  '{}',                       'ministere : le poste est lu dans l identifiant'),
  ('assemblee',           false, '{}',                       'assemblee : chemin serveur dedie (assemblee_debiter_caisse_plafonne)'),
  ('mairie',              true,  '{maire,maire_adjoint}',    'mairies, toutes villes'),
  ('commissariat',        true,  '{commissaire,min_int}',    'commissariats'),
  ('tribunal',            true,  '{juge,min_just}',          'tribunaux'),
  ('caserne-militaire',   false, '{commandant,min_def}',     'caserne'),
  ('qhs-prison',          false, '{min_int,min_just}',       'quartier haute securite'),
  ('reserve-nationale',   false, '{min_fin}',                'reserve nationale')
ON CONFLICT (motif) DO UPDATE
  SET est_prefixe=EXCLUDED.est_prefixe, postes_debit=EXCLUDED.postes_debit, note=EXCLUDED.note;

-- Poste requis pour debiter une caisse donnee. NULL = caisse non institutionnelle
-- (aucune autorite identifiable a ce jour), '{}' = chemin serveur uniquement.
CREATE OR REPLACE FUNCTION public.caisse_postes_requis(p_caisse text, p_pays text)
RETURNS text[]
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE v_suffixe text; r record; v_poste text;
BEGIN
  v_suffixe := regexp_replace(p_caisse, '^' || p_pays || '_', '');

  -- Ministere : le poste EST dans l'identifiant, comme le fait deja
  -- caisse_ministere_mouvement.
  v_poste := substring(v_suffixe from '^gouvernement-(.+)$');
  IF v_poste IS NOT NULL THEN RETURN ARRAY[v_poste]; END IF;

  SELECT * INTO r FROM public.caisses_autorites c
   WHERE (NOT c.est_prefixe AND c.motif = v_suffixe)
      OR (c.est_prefixe AND v_suffixe LIKE c.motif || '%')
   ORDER BY c.est_prefixe LIMIT 1;
  IF NOT FOUND THEN RETURN NULL; END IF;
  RETURN r.postes_debit;
END;
$fn$;
REVOKE ALL ON FUNCTION public.caisse_postes_requis(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.caisse_postes_requis(text, text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.caisse_client_mouvement(
  p_caisse text, p_delta numeric, p_motif text DEFAULT NULL, p_plafonne boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE
  v_moi text; v_pays text; v_existe boolean; v_solde numeric; v_verse numeric;
  v_res jsonb; v_raison text; v_postes text[];
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;

  IF coalesce(btrim(p_caisse),'') = '' OR p_delta IS NULL OR p_delta = 0
     OR abs(p_delta) > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  IF v_pays IS NULL OR p_caisse NOT LIKE v_pays || '\_%' THEN
    v_raison := 'caisse_hors_pays';
  ELSE
    SELECT true, (data->>'solde')::numeric INTO v_existe, v_solde
      FROM public.caisses_batiments WHERE id = p_caisse;
    IF NOT coalesce(v_existe, false) THEN
      v_raison := 'caisse_inexistante';
    ELSIF p_delta < 0 OR p_plafonne THEN
      -- SORTIE D'ARGENT PUBLIC : autorite exigee.
      v_postes := public.caisse_postes_requis(p_caisse, v_pays);
      IF v_postes IS NOT NULL THEN
        IF array_length(v_postes, 1) IS NULL THEN
          v_raison := 'caisse_reservee_au_serveur';
        ELSIF NOT EXISTS (SELECT 1 FROM public.acteur_poste_courant() a
                           WHERE a.poste_id = ANY (v_postes) AND a.pays = v_pays) THEN
          v_raison := 'autorite_insuffisante';
        END IF;
      END IF;
    END IF;
  END IF;

  IF v_raison IS NOT NULL THEN
    INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
    VALUES (v_moi, p_caisse, p_delta, p_motif, false, v_raison);
    RETURN jsonb_build_object('ok', false, 'raison', v_raison);
  END IF;

  IF p_plafonne THEN
    v_verse := least(greatest(coalesce(v_solde,0), 0), abs(p_delta));
    IF v_verse <= 0 THEN
      INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
      VALUES (v_moi, p_caisse, p_delta, p_motif, false, 'solde_nul');
      RETURN jsonb_build_object('ok', true, 'verse', 0, 'solde', coalesce(v_solde,0));
    END IF;
    v_res := public.caisse_institution_mouvement(p_caisse, -v_verse, true);
    INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
    VALUES (v_moi, p_caisse, -v_verse, p_motif, coalesce((v_res->>'ok')::boolean,false), v_res->>'raison');
    IF coalesce((v_res->>'ok')::boolean, false) THEN
      RETURN jsonb_build_object('ok', true, 'verse', v_verse,
        'solde', (SELECT (data->>'solde')::numeric FROM public.caisses_batiments WHERE id = p_caisse));
    END IF;
    RETURN jsonb_build_object('ok', false, 'raison', v_res->>'raison', 'verse', 0);
  END IF;

  v_res := public.caisse_institution_mouvement(p_caisse, p_delta, true);
  INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
  VALUES (v_moi, p_caisse, p_delta, p_motif, coalesce((v_res->>'ok')::boolean,false), v_res->>'raison');
  IF coalesce((v_res->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', true,
      'solde', (SELECT (data->>'solde')::numeric FROM public.caisses_batiments WHERE id = p_caisse));
  END IF;
  RETURN v_res;
END;
$fn$;