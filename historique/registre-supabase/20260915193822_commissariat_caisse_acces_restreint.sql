-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260915193822
-- Nom original      : commissariat_caisse_acces_restreint
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-15 19:38:22 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 1b361baa8b8eb34b5479c7bff9a324b2
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
-- COMMISSARIAT — LOT 2 : LA CAISSE N'EST PLUS UNE INFORMATION PUBLIQUE.
--
-- CE QUE L'AUDIT A ETABLI. L'ordre « Consulter la caisse » n'etait pas l'exposition, seulement sa
-- vitrine : caisses_batiments portait une policy SELECT USING(true) pour PUBLIC, donc n'importe
-- quel client lisait les 151 lignes, tous pays et tous batiments confondus, avec la cle anon.
-- Restreindre le seul ordre aurait ete cosmetique. Deux autres fuites existaient pour la MEME
-- caisse : l'ecran public « consulter les indices locaux » de l'Hotel de Ville, qui affiche le
-- solde des six caisses communales dont le commissariat, et un oracle de lecture par RPC.
--
-- PERIMETRE ASSUME. Ce lot ferme la caisse DU COMMISSARIAT, qui est son objet. Les autres
-- consultations publiques du jeu (administration du port, soldes ministeriels dans la description
-- des pieces, PNJ Marcel Ancre, cinq autres caisses communales) sont des choix de game design
-- propres a d'autres batiments : elles sont laissees intactes et signalees pour arbitrage, plutot
-- que cassees au passage. La policy est donc restreinte par motif d'identifiant, pas supprimee.

-- 1. La lecture publique cesse pour les seules caisses de commissariat.
DROP POLICY IF EXISTS "caisses_batiments lecture publique" ON public.caisses_batiments;
CREATE POLICY "caisses_batiments lecture publique hors commissariat"
  ON public.caisses_batiments FOR SELECT TO anon, authenticated
  USING (id NOT LIKE '%commissariat%');

-- 2. ORACLE DE LECTURE PAR RPC. caisse_institution_mouvement_plafonne(id, 0) n'ecrivait rien et
--    renvoyait le solde : lecture gratuite, sans trace, de n'importe quelle caisse. Idem pour
--    caisse_institution_mouvement(id, 0). Les deux refusent desormais le mouvement nul et ne
--    renvoient plus le solde. Verifie : aucun appelant du depot ne lit r.solde
--    (crediterCaisseBatiment le retournait, sa valeur n'etait exploitee nulle part).
CREATE OR REPLACE FUNCTION public.caisse_institution_mouvement(
  p_id text, p_delta numeric, p_exiger_existant boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_data jsonb; v_solde numeric; v_existe boolean;
BEGIN
  IF COALESCE(btrim(p_id), '') = '' OR p_delta IS NULL OR p_delta = 0
     OR abs(p_delta) > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  SELECT data INTO v_data FROM public.caisses_batiments WHERE id = p_id FOR UPDATE;
  v_existe := FOUND;
  IF p_exiger_existant AND NOT v_existe THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_absente');
  END IF;

  v_solde := CASE WHEN v_existe AND jsonb_typeof(v_data -> 'solde') = 'number'
                  THEN (v_data ->> 'solde')::numeric ELSE 0 END;
  IF v_solde + p_delta < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'solde_insuffisant');
  END IF;

  IF v_existe THEN
    UPDATE public.caisses_batiments
       SET data = coalesce(v_data, '{}'::jsonb) || jsonb_build_object('solde', v_solde + p_delta),
           updated_at = now()
     WHERE id = p_id;
  ELSE
    INSERT INTO public.caisses_batiments (id, data, updated_at)
    VALUES (p_id, jsonb_build_object('solde', v_solde + p_delta), now());
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.caisse_institution_mouvement_plafonne(p_id text, p_montant numeric)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_data jsonb; v_solde numeric; v_verse numeric; v_existe boolean;
BEGIN
  IF COALESCE(btrim(p_id), '') = '' OR p_montant IS NULL OR p_montant <= 0
     OR p_montant > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  SELECT data INTO v_data FROM public.caisses_batiments WHERE id = p_id FOR UPDATE;
  v_existe := FOUND;
  v_solde := CASE WHEN v_existe AND jsonb_typeof(v_data -> 'solde') = 'number'
                  THEN (v_data ->> 'solde')::numeric ELSE 0 END;
  v_verse := LEAST(GREATEST(v_solde, 0), p_montant);

  IF v_verse > 0 AND v_existe THEN
    UPDATE public.caisses_batiments
       SET data = coalesce(v_data, '{}'::jsonb) || jsonb_build_object('solde', v_solde - v_verse),
           updated_at = now()
     WHERE id = p_id;
  END IF;

  RETURN jsonb_build_object('ok', true, 'verse', v_verse);
END;
$$;

-- 3. LECTURE CONTROLEE. Remplace la lecture directe de la table pour les fonctions qui ont
--    legitimement a gerer ou administrer une caisse de commissariat :
--      - le commissaire, pour SA ville (son mandat est municipal) ;
--      - le ministre de l'Interieur et le president, pour tout leur empire ;
--      - le maire et son adjoint, pour leur ville (ils financent deja les batiments communaux).
CREATE OR REPLACE FUNCTION public.caisse_commissariat_lire(p_id text)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_nom text; v_poste text; v_poste_city text; v_pays text;
  v_solde numeric; v_autorise boolean := false;
BEGIN
  IF p_id IS NULL OR p_id NOT LIKE '%commissariat%' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_hors_perimetre');
  END IF;

  SELECT a.nom, a.poste_id, a.poste_city, a.pays
    INTO v_nom, v_poste, v_poste_city, v_pays
    FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  -- La caisse doit appartenir a l'empire de l'acteur : l'identifiant commence par son pays.
  IF p_id NOT LIKE v_pays || '\_%' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;

  IF v_poste IN ('president', 'min_int') THEN
    v_autorise := true;
  ELSIF v_poste IN ('commissaire', 'maire', 'maire_adjoint') AND v_poste_city IS NOT NULL THEN
    -- La caisse d'une ville porte son nom : republic_commissariat_capitale.
    v_autorise := (p_id LIKE '%\_' || v_poste_city);
  END IF;

  IF NOT v_autorise THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;

  SELECT CASE WHEN jsonb_typeof(c.data -> 'solde') = 'number'
              THEN (c.data ->> 'solde')::numeric ELSE 0 END
    INTO v_solde FROM public.caisses_batiments c WHERE c.id = p_id;

  RETURN jsonb_build_object('ok', true, 'solde', coalesce(v_solde, 0));
END;
$$;
REVOKE ALL ON FUNCTION public.caisse_commissariat_lire(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.caisse_commissariat_lire(text) TO authenticated, service_role;