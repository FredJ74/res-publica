-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260916194916
-- Nom original      : justice_condamnations_recherchees_canoniques
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-16 19:49:16 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 508f0c4a0b807d52592f949d5e06b689
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
-- LES CONDAMNES ENCORE LIBRES ONT UNE SOURCE CANONIQUE (16 septembre 2026).
--
-- LE DEFAUT. Un avis de recherche vivait dans le blob personnages.recherche, ecrit par
-- read-modify-write depuis le navigateur du JUGE. Depuis le chantier B cette ecriture est
-- refusee : personne n'etait jamais mis sous avis de recherche -- ni les condamnes du tribunal,
-- ni les deserteurs. Pire, la relecture du blob d'autrui renvoyant `[]`, une reouverture naive
-- de l'ecriture aurait EFFACE tous les avis existants de la cible.
--
-- PAS DE NOUVELLE TABLE. `jugements` existait deja, vide, et porte exactement la bonne notion :
-- accuse, motif, peine, juge, jour, et surtout `executee` -- qui distingue le condamne encore
-- LIBRE (executee = false, donc recherche) de la peine deja subie. On s'y adosse plutot que de
-- dupliquer. Seul ajout, additif : une colonne `data` pour conserver l'entree telle que le jeu
-- la compose aujourd'hui (motifs, affaire, reliquat...), sans rien perdre.
--
-- UNE PERSONNE RECHERCHEE N'EST PAS DETENUE : aucune ligne `detentions` n'est creee tant que la
-- condamnation n'est pas executee. C'est la regle posee par le game design.

ALTER TABLE public.jugements ADD COLUMN IF NOT EXISTS data jsonb;
CREATE INDEX IF NOT EXISTS jugements_accuse_actifs
  ON public.jugements (accuse) WHERE executee = false;

ALTER TABLE public.jugements ENABLE ROW LEVEL SECURITY;
DO $$
DECLARE pol record;
BEGIN
  FOR pol IN SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename='jugements'
  LOOP EXECUTE format('DROP POLICY IF EXISTS %I ON public.jugements', pol.policyname); END LOOP;
END $$;
-- Une condamnation est un acte public : lisible. Mais aucun client ne la prononce lui-meme.
CREATE POLICY jugements_lecture ON public.jugements
  FOR SELECT TO anon, authenticated USING (true);

-- PRONONCER. Reserve au juge -- la meme autorite que rendre_sentence (data.js).
CREATE OR REPLACE FUNCTION public.justice_condamner(p_cible text, p_entree jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_juge text; v_id text; v_pays text; v_ville text; v_jours integer;
BEGIN
  v_juge := public.exiger_poste('juge');
  IF v_juge IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF p_entree IS NULL OR jsonb_typeof(p_entree) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'entree_invalide');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_cible) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
  END IF;

  SELECT coalesce(p_entree->>'country', country), coalesce(p_entree->>'ville_condamnation', current_city)
    INTO v_pays, v_ville FROM public.personnages_donnees WHERE name = v_juge;
  SELECT coalesce(sum((m->>'jours')::int), 0) INTO v_jours
    FROM jsonb_array_elements(coalesce(p_entree->'motifs', '[]'::jsonb)) m;

  v_id := coalesce(nullif(p_entree->>'id', ''),
                   'rech-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-'
                     || substr(md5(random()::text), 1, 6));

  INSERT INTO public.jugements (id, country, city, accuse, motif, peine, juge, jour, executee, data)
  VALUES (v_id, v_pays, v_ville, p_cible,
          coalesce(p_entree #>> '{motifs,0,type}', 'Condamnation'),
          v_jours::text || ' jours', v_juge,
          coalesce((p_entree->>'jour_affaire')::int, 0), false,
          p_entree || jsonb_build_object('id', v_id))
  ON CONFLICT (id) DO NOTHING;

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'accuse', p_cible, 'jours', v_jours);
END; $$;

-- LIRE les condamnations actives d'un personnage : le strict necessaire, rien de plus.
CREATE OR REPLACE FUNCTION public.justice_recherches(p_nom text)
RETURNS TABLE (id text, country text, ville_condamnation text, motif text, jours integer, data jsonb)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT j.id, j.country, j.city, j.motif,
         coalesce((SELECT sum((m->>'jours')::int)
                     FROM jsonb_array_elements(coalesce(j.data->'motifs', '[]'::jsonb)) m), 0)::int,
         j.data
    FROM public.jugements j
   WHERE j.accuse = p_nom AND j.executee = false
   ORDER BY j.created_at;
$$;

-- EXECUTER une condamnation : c'est ici, et seulement ici, que « recherche » devient « detenu ».
-- La detention passe par la primitive canonique deja utilisee par l'arrestation d'urgence et
-- l'enquete -- aucune seconde mecanique de prison.
CREATE OR REPLACE FUNCTION public.justice_executer_condamnation(p_jugement_id text, p_ville text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_acteur text; v_j record; v_jours integer; v_motif text; v_res jsonb; v_det record;
BEGIN
  v_acteur := public.exiger_poste('commissaire');
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  -- Verrou : deux executions simultanees de la meme condamnation ne peuvent pas coexister.
  SELECT * INTO v_j FROM public.jugements WHERE id = p_jugement_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'condamnation_introuvable');
  END IF;
  IF v_j.executee THEN
    RETURN jsonb_build_object('ok', true, 'deja_executee', true, 'accuse', v_j.accuse);
  END IF;

  -- Deja detenu : la peine s'ajoute a la detention en cours plutot que d'en ouvrir une seconde.
  SELECT * INTO v_det FROM public.detention_active(v_j.accuse);
  IF v_det.id IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_deja_detenue');
  END IF;

  v_jours := coalesce((SELECT sum((m->>'jours')::int)
                         FROM jsonb_array_elements(coalesce(v_j.data->'motifs', '[]'::jsonb)) m), 0);
  IF v_jours <= 0 THEN v_jours := 3; END IF;   -- meme repli que le flagrant delit du client
  v_motif := coalesce(v_j.motif, 'Avis de recherche');

  v_res := public.detention_ouvrir_interne(
             v_j.accuse, v_motif, v_jours, coalesce(p_ville, v_j.city), v_j.country,
             coalesce(v_j.data->'motifs', '[]'::jsonb), v_acteur,
             coalesce(v_j.data->>'issue_judiciaire', 'condamnation_executee'));
  IF NOT coalesce((v_res->>'ok')::boolean, false) THEN
    RETURN v_res;
  END IF;

  UPDATE public.jugements SET executee = true WHERE id = p_jugement_id;

  RETURN jsonb_build_object('ok', true, 'accuse', v_j.accuse, 'jours', v_jours,
                            'detention_id', v_res->>'detention_id', 'motif', v_motif);
END; $$;

REVOKE ALL ON FUNCTION public.justice_condamner(text, jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.justice_executer_condamnation(text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.justice_recherches(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.justice_condamner(text, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.justice_executer_condamnation(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.justice_recherches(text) TO anon, authenticated;