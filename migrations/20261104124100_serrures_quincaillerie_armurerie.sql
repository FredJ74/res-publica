-- APPLIQUEE le 04/11/2026 par Claude (registre serrures_quincaillerie_armurerie_20261104124100), structure eprouvee en transaction annulee
-- avant application, puis banc annule outils/bancs/banc-serrures.sql joue en production : vert.
-- 4 novembre 2026 -- SERRURES, etape 2 : la quincaillerie dans le circuit des armureries (issue #434).
--
-- Les armureries de Republia fabriquent et vendent desormais deux articles de quincaillerie
-- (serrure a cle, cle vierge). Ce ne sont pas des armes : ils restent hors de recettes_production
-- (circuit des armes, registre, marche noir) et sont lus dans recettes_commerce, source
-- 'quincaillerie' (quincaillerie_recette_interne, etape 1).
--
-- Trois patchs en place (jamais un corps retape -- WORKFLOW-SUPABASE.md) :
--   * commerce_produire : une recette inconnue des armes est cherchee en quincaillerie ; PA,
--     portions et matieres de la recette, main-d'oeuvre au tarif commun (50 FR/PA) ;
--   * commerce_vendre_produit_interne : la quincaillerie est au catalogue de l'armurerie,
--     jamais au marche noir ;
--   * commerce_fixer_parametres : le proprietaire PJ fixe prix et plafonds de la quincaillerie
--     comme pour ses armes (pas de fourchette en armurerie).
-- Idempotente : un patch deja applique est reconnu a sa marque et n'est pas rejoue.

DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.commerce_produire(text,text,text,text)'::regprocedure);
  IF strpos(v_def, 'quincaillerie_armurerie_v1') = 0 THEN
    v_new := replace(v_def,
$a$    SELECT * INTO v_prod FROM public.recettes_production WHERE id = p_recette AND pays = v_pays;
    IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'recette_inconnue'); END IF;
    v_materiaux := v_prod.materiaux;
    v_portions  := 1;
    v_prix_fixe := NULL;
    SELECT valeur INTO v_pa_requis FROM public.entreprises_constantes WHERE cle = 'pa_production_armurerie';
    SELECT valeur INTO v_salaire   FROM public.entreprises_constantes WHERE cle = 'salaire_production_armurerie';
  ELSE$a$,
$b$    SELECT * INTO v_prod FROM public.recettes_production WHERE id = p_recette AND pays = v_pays;
    IF FOUND THEN
    v_materiaux := v_prod.materiaux;
    v_portions  := 1;
    v_prix_fixe := NULL;
    SELECT valeur INTO v_pa_requis FROM public.entreprises_constantes WHERE cle = 'pa_production_armurerie';
    SELECT valeur INTO v_salaire   FROM public.entreprises_constantes WHERE cle = 'salaire_production_armurerie';
    ELSE
      -- quincaillerie_armurerie_v1 (serrures, 04/11/2026) : articles non-armes de l'armurerie.
      SELECT * INTO v_rec FROM public.quincaillerie_recette_interne(p_recette, v_pays);
      IF v_rec.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'recette_inconnue'); END IF;
      v_materiaux := v_rec.materiaux;
      v_portions  := v_rec.portions;
      v_pa_requis := v_rec.pa;
      v_prix_fixe := NULL;
      SELECT valeur INTO v_mo FROM public.entreprises_constantes WHERE cle = 'cout_main_oeuvre_pa_alimentaire';
      v_salaire := v_rec.pa * COALESCE(v_mo, 0);
    END IF;
  ELSE$b$);
    IF v_new = v_def THEN RAISE EXCEPTION 'patch commerce_produire non applique'; END IF;
    EXECUTE v_new;
  END IF;

  v_def := pg_get_functiondef('public.commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric)'::regprocedure);
  IF strpos(v_def, 'quincaillerie_armurerie_v1') = 0 THEN
    v_new := replace(v_def,
$a$                      WHERE id = v_id AND pays = v_pays) INTO v_au_catalogue;$a$,
$b$                      WHERE id = v_id AND pays = v_pays)
          -- quincaillerie_armurerie_v1 : au comptoir seulement, jamais au marche noir.
          OR (p_mode <> 'marche_noir' AND (SELECT q.id FROM public.quincaillerie_recette_interne(v_id, v_pays) q) IS NOT NULL)
        INTO v_au_catalogue;$b$);
    IF v_new = v_def THEN RAISE EXCEPTION 'patch commerce_vendre_produit_interne non applique'; END IF;
    EXECUTE v_new;
  END IF;

  v_def := pg_get_functiondef('public.commerce_fixer_parametres(text,text,jsonb,jsonb,jsonb)'::regprocedure);
  IF strpos(v_def, 'quincaillerie_armurerie_v1') = 0 THEN
    v_new := replace(v_def,
$a$      IF NOT EXISTS (SELECT 1 FROM public.recettes_production WHERE id = v_k AND pays = v_pays) THEN$a$,
$b$      IF NOT EXISTS (SELECT 1 FROM public.recettes_production WHERE id = v_k AND pays = v_pays)
         AND (SELECT q.id FROM public.quincaillerie_recette_interne(v_k, v_pays) q) IS NULL THEN -- quincaillerie_armurerie_v1$b$);
    IF v_new = v_def OR (length(v_new) - length(v_def)) <> 2 * (length($b$      IF NOT EXISTS (SELECT 1 FROM public.recettes_production WHERE id = v_k AND pays = v_pays)
         AND (SELECT q.id FROM public.quincaillerie_recette_interne(v_k, v_pays) q) IS NULL THEN -- quincaillerie_armurerie_v1$b$)
         - length($a$      IF NOT EXISTS (SELECT 1 FROM public.recettes_production WHERE id = v_k AND pays = v_pays) THEN$a$)) THEN
      RAISE EXCEPTION 'patch commerce_fixer_parametres : deux occurrences attendues (prix, plafonds)';
    END IF;
    EXECUTE v_new;
  END IF;
END $mig$;
