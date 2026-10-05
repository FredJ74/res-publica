-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927142933
-- Nom original      : socle_pnj_primitives_pa_alpha
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 14:29:33 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 700fefdbf6527a62e95eaabe01dfb261
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
-- CHECKPOINT A (1/4) — LES PRIMITIVES DE PA GENERIQUES DE LA CLASSE ALPHA (27 septembre 2026)
--
-- Le socle possedait deja le DEBIT. Il lui manquait le CREDIT et la FIXATION ABSOLUE, dont le
-- metier militaire a besoin (ration, bivouac, repos, degats de bataille). Les trois partagent
-- exactement les memes gardes -- axe, classe, statut -- et la meme regle universelle : 0 PA
-- signifie la mort.
--
-- CE QUE LE SOCLE DECIDE : le plafond (12), le plancher (0), la mort a 0, et qui a le droit de
-- depenser (alpha seulement).
-- CE QUE LE METIER DECIDE : quel ordre coute ou rapporte combien. Aucune de ces primitives ne
-- connait la ration, le bivouac ni la bataille.

CREATE OR REPLACE FUNCTION public.pnj_pa_max()
RETURNS integer LANGUAGE sql IMMUTABLE AS $$ SELECT 12; $$;

-- Garde commune aux trois primitives. Renvoie NULL si tout est en ordre, sinon le refus nomme.
CREATE OR REPLACE FUNCTION public.pnj_pa_garde(p_ids text[])
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_bloque text; v_hors text; v_classe text;
BEGIN
  v_bloque := public.pnj_axe_verrouille(p_ids, 'pa');
  IF v_bloque IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'axe_pa_hors_socle', 'pnj', v_bloque,
      'explication', 'Les PA de cette famille vivent encore dans son magasin historique.');
  END IF;
  SELECT m.id, public.pnj_classe_de(m.id) INTO v_hors, v_classe
    FROM public.pnj_membres m
   WHERE m.id = ANY(p_ids) AND COALESCE(public.pnj_classe_de(m.id), '') <> 'alpha'
   LIMIT 1;
  IF v_hors IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'classe_sans_consommation_de_pa',
      'pnj', v_hors, 'classe', COALESCE(v_classe, 'non_declaree'),
      'explication', 'Seule la classe alpha voit ses PA varier pour agir.');
  END IF;
  RETURN NULL;
END; $$;

-- CREDIT. Plafonne, jamais au-dela du maximum du socle. Ne tue personne : on ne meurt pas d'un gain.
CREATE OR REPLACE FUNCTION public.pnj_pa_crediter(p_ids text[], p_gain integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_refus jsonb; v_n integer := 0;
BEGIN
  v_refus := public.pnj_pa_garde(p_ids);
  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;
  IF p_gain IS NULL OR p_gain < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'gain_invalide'); END IF;
  UPDATE public.pnj_membres
     SET pa = least(public.pnj_pa_max(), pa + p_gain), maj_le = now()
   WHERE id = ANY(p_ids) AND statut = 'actif';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'touches', v_n, 'gain', p_gain);
END; $$;

-- FIXATION ABSOLUE. Le moteur de combat calcule une valeur, il ne raisonne pas en delta.
-- La regle universelle s'applique quand meme : arriver a 0 PA declenche le cycle de mort.
-- Le chemin metier qui suit (retrait du blob) trouvera alors un PNJ deja mort, et ne deposera
-- pas ses affaires une seconde fois -- pnj_mourir est idempotente.
CREATE OR REPLACE FUNCTION public.pnj_pa_fixer(p_ids text[], p_valeur integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_refus jsonb; r record; v_n integer := 0; v_morts integer := 0; v_val integer;
BEGIN
  v_refus := public.pnj_pa_garde(p_ids);
  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;
  IF p_valeur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'valeur_invalide'); END IF;
  v_val := least(public.pnj_pa_max(), greatest(0, p_valeur));
  FOR r IN SELECT id FROM public.pnj_membres
            WHERE id = ANY(p_ids) AND statut = 'actif' FOR UPDATE LOOP
    UPDATE public.pnj_membres SET pa = v_val, maj_le = now() WHERE id = r.id;
    v_n := v_n + 1;
    IF v_val = 0 THEN PERFORM public.pnj_mourir(r.id, 'degats'); v_morts := v_morts + 1; END IF;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'touches', v_n, 'morts', v_morts, 'valeur', v_val);
END; $$;

-- Le debit reprend la garde commune, pour que les trois disent exactement la meme chose.
CREATE OR REPLACE FUNCTION public.pnj_pa_debiter(p_ids text[], p_cout integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_refus jsonb; r record; v_morts integer := 0; v_touches integer := 0; v_reste integer;
BEGIN
  v_refus := public.pnj_pa_garde(p_ids);
  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;
  IF p_cout IS NULL OR p_cout < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_invalide'); END IF;
  FOR r IN SELECT id, pa FROM public.pnj_membres
            WHERE id = ANY(p_ids) AND statut = 'actif' FOR UPDATE LOOP
    v_reste := greatest(0, r.pa - p_cout);
    UPDATE public.pnj_membres SET pa = v_reste, maj_le = now() WHERE id = r.id;
    v_touches := v_touches + 1;
    IF v_reste = 0 THEN PERFORM public.pnj_mourir(r.id, 'degats'); v_morts := v_morts + 1; END IF;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'touches', v_touches, 'morts', v_morts);
END; $$;

REVOKE ALL ON FUNCTION public.pnj_pa_max()                     FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_pa_garde(text[])             FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_pa_crediter(text[],integer)  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_pa_fixer(text[],integer)     FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.pnj_pa_crediter(text[],integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.pnj_pa_fixer(text[],integer)    TO service_role;