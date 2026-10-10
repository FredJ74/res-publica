-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010123639 (UTC), nom `titulaire_est_moi_et_rectification_de_deux_affirmations`.
-- Le registre passe de 617 a 618 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 3b9c8314d5fe7e9396f3182f1f3672a2, 4941 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- LE JUMEAU SQL DE `estTitulaire`, ET DEUX RECTIFICATIONS
--
-- Rectification 1 : `terrain_permis_acte` comparait `data.proprietaire` au nom nu de l'appelant,
-- alors qu'un proprietaire peut etre note `pj:<nom>` ou `orga:<id>` -- un terrain `pj:Ben` aurait
-- refuse Ben sur son propre plan. `titulaire_est_moi` reproduit `estTitulaire(ref)` et la porte du
-- permis est patchee en place. Rectification 2 : l'affirmation de la migration precedente sur la
-- necessite de l'arithmetique `double precision` n'est pas etablie -- la contre-epreuve en
-- `numeric` exact donne le meme resultat sur les 184 cas de la grille, c'est une precaution.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LE JUMEAU SQL DE `estTitulaire`, ET DEUX RECTIFICATIONS
-- Chantier 5, les 19 `sbSetTerrainState` (10 octobre 2026).
--
-- RECTIFICATION 1 -- UNE REGRESSION QUE J'AI INTRODUITE DEUX MIGRATIONS PLUS TOT, et qu'une
-- relecture du code client a trouvee avant qu'elle ne sorte. `terrain_permis_acte` compare
-- `data.proprietaire` au nom de l'appelant :
--     IF nullif(v_etat ->> 'proprietaire', '') IS DISTINCT FROM v_moi
-- Or le proprietaire d'un terrain n'est PAS toujours un nom nu. `parserTitulaire` (plateau-core.js)
-- reconnait trois formes : `pj:<nom>`, `orga:<id>`, et la chaine nue -- une donnee historique,
-- toujours un nom de personnage. `estTitulaire(ref)` compare donc (type, id) apres normalisation,
-- et `titulaireCourant()` vaut TOUJOURS `pj:<nom>`. Un terrain dont le proprietaire est note
-- `pj:Ben` aurait vu Ben refuse sur sa propre modification de plan.
--
-- La beta ne porte aujourd'hui aucun proprietaire prefixe -- un seul, et c'est un residu de banc
-- (`zztest-chantier-proprio`) -- donc le defaut n'a frappe personne. Il aurait frappe au premier
-- terrain achete apres ce lot.
--
-- UNE SEULE IMPLEMENTATION, et c'est le sens de cette migration : `titulaire_est_moi` reproduit
-- `estTitulaire(ref)` -- et `mouvement_titulaire` savait deja decouper ce prefixe, preuve que le
-- besoin etait la. Une organisation n'est jamais « moi » : `titulaireCourant()` est toujours un
-- `pj:`, donc un terrain detenu par une organisation ne passe par aucune de ces portes. C'est le
-- comportement actuel, a l'identique.
--
-- RECTIFICATION 2 -- UNE AFFIRMATION DE MA MIGRATION PRECEDENTE N'EST PAS ETABLIE. L'en-tete de
-- `terrain_chantier_acte` dit que l'arithmetique `double precision` est necessaire parce que
-- « deux arithmetiques differentes peuvent basculer un seuil dans des sens opposes ». La
-- contre-epreuve a ete faite : la MEME grille de 184 chantiers recalculee en `numeric` exact
-- donne EXACTEMENT le meme resultat, sur les cinq grandeurs, y compris aux durees a tiers non
-- binaires (7, 10). Le choix de `double precision` reste le bon -- il recopie l'arithmetique du
-- client au lieu de parier sur une equivalence -- mais c'est une PRECAUTION, pas une necessite
-- mesuree, et le corps archive de cette migration dit le contraire. Les faits gagnent.

CREATE OR REPLACE FUNCTION public.titulaire_est_moi(p_ref text)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp' AS $fn$
DECLARE v_moi text; v_brut text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN false; END IF;
  v_brut := btrim(coalesce(p_ref, ''));
  IF v_brut = '' THEN RETURN false; END IF;
  -- `orga:` et `ville:` ne sont jamais « moi » : titulaireCourant() est toujours un `pj:`.
  IF left(v_brut, 5) = 'orga:' OR left(v_brut, 6) = 'ville:' THEN RETURN false; END IF;
  IF left(v_brut, 3) = 'pj:' THEN RETURN btrim(substr(v_brut, 4)) = v_moi; END IF;
  -- Chaine non typee : donnee historique, toujours un nom de personnage aujourd'hui.
  RETURN v_brut = v_moi;
END; $fn$;

REVOKE ALL ON FUNCTION public.titulaire_est_moi(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.titulaire_est_moi(text) TO authenticated, service_role;

-- PATCH EN PLACE DE LA PORTE DU PERMIS. On ne retape pas son corps : on remplace le seul fragment
-- fautif, et on leve si le fragment n'est pas trouve.
DO $m$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.terrain_permis_acte(text,text,jsonb)'::regprocedure);
  v_new := replace(v_def,
    'IF nullif(v_etat ->> ''proprietaire'', '''') IS DISTINCT FROM v_moi THEN',
    'IF NOT public.titulaire_est_moi(v_etat ->> ''proprietaire'') THEN');
  IF v_new = v_def THEN
    RAISE EXCEPTION 'le fragment de comparaison du proprietaire est introuvable dans la porte du permis';
  END IF;
  EXECUTE v_new;
END $m$;

DO $p$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.terrain_permis_acte(text,text,jsonb)'::regprocedure);
  IF v_def NOT LIKE '%titulaire_est_moi(v_etat ->> ''proprietaire'')%' THEN
    RAISE EXCEPTION 'la porte du permis ne passe pas par le jumeau de estTitulaire';
  END IF;
  IF v_def LIKE '%''proprietaire'', '''') IS DISTINCT FROM v_moi%' THEN
    RAISE EXCEPTION 'la comparaison fautive subsiste dans la porte du permis';
  END IF;
  -- LE JUMEAU RECONNAIT LES TROIS FORMES, et refuse les deux qui ne sont jamais « moi ».
  v_def := pg_get_functiondef('public.titulaire_est_moi(text)'::regprocedure);
  IF v_def NOT LIKE '%''orga:''%' OR v_def NOT LIKE '%''ville:''%' OR v_def NOT LIKE '%''pj:''%' THEN
    RAISE EXCEPTION 'le jumeau de estTitulaire ne connait pas les trois prefixes';
  END IF;
  IF has_function_privilege('anon', 'public.titulaire_est_moi(text)'::regprocedure, 'EXECUTE') THEN
    RAISE EXCEPTION 'anon peut appeler le jumeau de estTitulaire';
  END IF;
  RAISE NOTICE 'Les 4 preuves structurelles de la rectification sont vertes.';
END $p$;
