-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010091934 (UTC), nom `candidature_la_table_et_le_scrutin_dans_une_transaction`.
-- Le registre passe de 606 a 607 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 b91cdd700546b055e6a4ea72aee460cd, 6650 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- CHANTIER 5, CHAINE 19 : LE DEPOT DE CANDIDATURE
--
-- Le code tenait le blob du cycle pour un cache best-effort ; la mesure montre que le
-- depouillement ne lit QUE ce blob, jamais la table `candidatures`. Un candidat dont la ligne est
-- attestee pouvait donc etre absent du bulletin si l'ecriture avalee du blob se perdait.
-- `candidature_deposer` ecrit les deux representations dans une transaction, sous FOR UPDATE du
-- cycle, sans modifier aucune regle de jeu.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CHANTIER 5, CHAINE 19 -- LE DEPOT DE CANDIDATURE (10 octobre 2026)
--
-- L'INVENTAIRE DISAIT « le code assume explicitement le blob comme cache best-effort ». LE CODE SE
-- TROMPAIT, ET LA MESURE LE MONTRE.
--
-- `sbDeposerCandidature` insere la ligne `candidatures` et son retour est teste -- avec meme un
-- remboursement de PA atteste en cas de refus. Puis `sbSaveCycleElectoral(...).catch(() => {})`
-- ecrit le blob du cycle, et un commentaire affirme : « reste un cache best-effort, ecrit ensuite,
-- jamais la source de verite ».
--
-- OR LE DEPOUILLEMENT NE LIT QUE LE BLOB. Mesure faite dans api/cron-minuit.js :
-- `resoudreScrutinSimple` et `resoudreScrutinDepute` lisent `cycle.candidats` (lignes 462, 481,
-- 511) ; la table `candidatures` n'y est JAMAIS lue -- zero occurrence de `sbGet('candidatures'`
-- dans tout le fichier. Le blob n'est donc pas un cache : POUR LE SCRUTIN, C'EST LA SOURCE.
--
-- CONSEQUENCE REELLE : un candidat qui a paye ses 2 PA, dont la ligne `candidatures` est bien
-- ecrite et attestee, est ABSENT DU BULLETIN si l'ecriture avalee du blob se perd. Il ne peut
-- meme pas s'en apercevoir : son nom figure dans la table, et `syncCyclesDepuisSupabase` relit le
-- blob. C'est le verrou racine deja identifie le 1er octobre -- « le depouillement ne voit ni
-- candidats ni bulletins » -- vu par son autre bout.
--
-- CE QUE LA PORTE FAIT. Les DEUX representations dans une transaction : la ligne `candidatures`
-- et le tableau `candidats` du blob. Le blob est verrouille FOR UPDATE, et l'ajout est un `||`
-- atomique -- deux candidats qui se declarent en meme temps figurent tous les deux au bulletin.
--
-- AUCUNE REGLE DE JEU N'EST MODIFIEE. Meme identifiant de ligne (pays_cle_nom[_scrutin]), meme
-- forme de candidat dans le blob, memes champs. La porte REFUSE une seconde candidature du meme
-- joueur au meme scrutin -- ce que la cle primaire faisait deja -- et le dit, au lieu de laisser
-- l'appelant deviner.

CREATE OR REPLACE FUNCTION public.candidature_deposer(
  p_poste text, p_city text, p_cle_scrutin numeric, p_candidat jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE
  v_moi text; v_pays text; v_cle text; v_id_cand text; v_id_cycle text;
  v_data jsonb; v_cands jsonb; v_n integer; v_city text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF p_candidat IS NULL OR jsonb_typeof(p_candidat) <> 'object'
     OR coalesce(p_candidat ->> 'nom', '') <> v_moi THEN
    -- ON NE SE PORTE CANDIDAT QUE POUR SOI. Le client transmettait son propre nom dans l'objet :
    -- le serveur le relit, et refuse qu'il en nomme un autre.
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_nom');
  END IF;

  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pays_inconnu');
  END IF;

  -- LA CLE DU CYCLE EST CELLE DU CLIENT, A LA LETTRE : <poste> ou <poste>_<ville>. Elle est
  -- reconstruite ici, et non recue, pour qu'un client ne puisse pas viser un autre scrutin.
  v_city := nullif(btrim(coalesce(p_city, '')), '');
  v_cle := p_poste || CASE WHEN v_city IS NOT NULL THEN '_' || v_city ELSE '' END;
  v_id_cycle := v_pays || '_' || v_cle;

  SELECT c.data::jsonb INTO v_data FROM public.cycles_electoraux c
   WHERE c.id = v_id_cycle FOR UPDATE;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cycle_introuvable', 'cle', v_id_cycle);
  END IF;

  v_cands := CASE WHEN jsonb_typeof(v_data -> 'candidats') = 'array'
                  THEN v_data -> 'candidats' ELSE '[]'::jsonb END;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_cands) e WHERE e ->> 'nom' = v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_candidat');
  END IF;

  v_id_cand := v_pays || '_' || v_cle || '_' || v_moi
    || CASE WHEN p_cle_scrutin IS NOT NULL THEN '_' || trim(to_char(p_cle_scrutin, 'FM999999999999999'))
            ELSE '' END;

  INSERT INTO public.candidatures (id, country, poste_id, city, nom, programme, archetype, created_at)
  VALUES (v_id_cand, v_pays, p_poste, v_city, v_moi,
          p_candidat ->> 'programme', p_candidat ->> 'archetype', now())
  ON CONFLICT (id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_candidat');
  END IF;

  -- LE BULLETIN, DANS LA MEME TRANSACTION QUE LA LIGNE ATTESTEE.
  v_data := jsonb_set(v_data, '{candidats}', v_cands || jsonb_build_array(p_candidat), true);
  UPDATE public.cycles_electoraux SET data = v_data::text, updated_at = now()
   WHERE id = v_id_cycle;

  RETURN jsonb_build_object('ok', true, 'action', 'deposee', 'cycle', v_data,
                            'id_candidature', v_id_cand);
END; $fn$;

REVOKE ALL ON FUNCTION public.candidature_deposer(text, text, numeric, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.candidature_deposer(text, text, numeric, jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public.candidature_deposer(text, text, numeric, jsonb)
  TO authenticated, service_role;

DO $$
DECLARE v_def text; v_acl text;
BEGIN
  SELECT pg_get_functiondef(p.oid),
         coalesce(array_to_string(p.proacl::text[], ' | '), '(defaut)')
    INTO v_def, v_acl
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname='public' AND p.proname='candidature_deposer';
  IF v_def IS NULL THEN RAISE EXCEPTION 'P1 : la porte est absente'; END IF;
  IF v_acl LIKE '%anon=%' THEN RAISE EXCEPTION 'P2 : anon peut se porter candidat'; END IF;
  IF v_def NOT LIKE '%FOR UPDATE%' THEN RAISE EXCEPTION 'P3 : le cycle n''est pas verrouille'; END IF;
  IF v_def NOT LIKE '%INSERT INTO public.candidatures%'
     OR v_def NOT LIKE '%UPDATE public.cycles_electoraux%' THEN
    RAISE EXCEPTION 'P4 : les deux representations ne sont pas ecrites'; END IF;
  IF v_def NOT LIKE '%pas_mon_nom%' THEN
    RAISE EXCEPTION 'P5 : le nom du candidat n''est pas verifie'; END IF;
  IF v_def NOT LIKE '%ON CONFLICT (id) DO NOTHING%' THEN
    RAISE EXCEPTION 'P6 : l''insertion n''est pas protegee contre le rejeu'; END IF;
  -- P7 : la table candidatures garde sa cle primaire -- c'est la seconde garde.
  IF NOT EXISTS (SELECT 1 FROM pg_constraint k JOIN pg_class c ON c.oid=k.conrelid
                  WHERE c.relname='candidatures' AND k.contype='p') THEN
    RAISE EXCEPTION 'P7 : candidatures a perdu sa cle primaire'; END IF;
  RAISE NOTICE 'candidature_deposer : 7 preuves structurelles conformes.';
END $$;
