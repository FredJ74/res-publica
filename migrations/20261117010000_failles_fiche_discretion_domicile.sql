-- Failles de l'audit du 16/11/2026 (outils/audits/AUDIT-FAILLES-20261116.md), feu vert de Fred le 17/11.
-- Colonnes de la fiche que l'écran pouvait encore écrire librement par la vue `personnages`.
--
-- 1. La porte `personnages_vue_modifier` garde désormais, pour un appel venu de l'écran :
--    - la discrétion (`resources.dis`) : une hausse ne vient que du serveur, une baisse reste admise ;
--    - `effets_actifs` et `bonus_lobbyiste` : l'écran ne fait déjà qu'adopter les valeurs du serveur ;
--    - `domicile` : le changement passe par la commande `domicile_changer` ci-dessous ;
--    - les points de vie : jamais au-dessus de 100 (soins encore calculés à l'écran : chantier à suivre).
-- 2. `pelerinage_accomplir` : le pèlerinage (2 PA, coût du référentiel `ordres_couts`) donne +10 DIS au serveur.
-- 3. `domicile_changer` : domicile = ville où se trouve le joueur, 200 de sa monnaie, débités au serveur.
-- 4. `rumeurs_organisations_cibles` n'est plus exécutable sans connexion (elle listait les organisations criminelles).
--
-- Idempotente : le patch ne s'applique qu'une fois (marque `failles_audit_20261117`), les fonctions sont en
-- CREATE OR REPLACE, les droits sont reposés à l'identique.

DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.personnages_vue_modifier()'::regprocedure);
  IF position('failles_audit_20261117' in v_def) > 0 THEN
    RETURN;
  END IF;
  v_new := replace(v_def,
$ancien$    NEW.detention_qhs     := v_canon.detention_qhs;
$ancien$,
$nouveau$    NEW.detention_qhs     := v_canon.detention_qhs;
    -- failles_audit_20261117 : colonnes que seul le serveur écrit.
    NEW.effets_actifs     := v_canon.effets_actifs;
    NEW.bonus_lobbyiste   := v_canon.bonus_lobbyiste;
    NEW.domicile          := v_canon.domicile;
    IF coalesce(NEW.hp, 0) > greatest(100, coalesce(v_canon.hp, 0)) THEN
      NEW.hp := greatest(100, coalesce(v_canon.hp, 0));
    END IF;
    IF jsonb_typeof(NEW.resources -> 'dis') = 'number'
       AND (NEW.resources ->> 'dis')::numeric >
           coalesce(CASE WHEN jsonb_typeof(v_canon.resources -> 'dis') = 'number'
                         THEN (v_canon.resources ->> 'dis')::numeric END, 50) THEN
      NEW.resources := jsonb_set(NEW.resources, '{dis}',
        coalesce(CASE WHEN jsonb_typeof(v_canon.resources -> 'dis') = 'number'
                      THEN v_canon.resources -> 'dis' END, to_jsonb(50)));
    END IF;
$nouveau$);
  IF v_new = v_def THEN
    RAISE EXCEPTION 'patch non applique : le fragment de personnages_vue_modifier ne correspond pas';
  END IF;
  EXECUTE v_new;
END $mig$;

CREATE OR REPLACE FUNCTION public.pelerinage_accomplir()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_nom text := public.mon_personnage();
  v_pa integer; v_cost integer; v_pay jsonb; r record;
BEGIN
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT o.pa, o.cost INTO v_pa, v_cost FROM public.ordres_couts o WHERE o.fn = 'pelerin';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ordre_inconnu');
  END IF;
  v_pay := public.payer_ordre_interne(v_nom, 'pelerin', coalesce(v_pa, 0), coalesce(v_cost, 0));
  IF coalesce((v_pay ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RETURN v_pay;
  END IF;
  PERFORM public.crime_dis_ajuster_interne(v_nom, 10);
  SELECT d.pa, d.liquide, d.arg, (d.resources ->> 'dis')::numeric AS dis
    INTO r FROM public.personnages_donnees d WHERE d.name = v_nom;
  RETURN jsonb_build_object('ok', true, 'gain_dis', 10, 'dis', r.dis, 'pa', r.pa,
                            'liquide', r.liquide, 'arg', r.arg);
END;
$function$;

CREATE OR REPLACE FUNCTION public.domicile_changer()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_cout constant integer := 200;
  v_nom text := public.mon_personnage();
  v_pays text; v_ville text; v_ancien jsonb; v_jour integer; v_pris numeric; r record;
BEGIN
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT d.country, d.current_city, d.domicile, coalesce(d.day, 1)
    INTO v_pays, v_ville, v_ancien, v_jour
    FROM public.personnages_donnees d WHERE d.name = v_nom FOR UPDATE;
  IF v_ville IS NULL OR v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'position_inconnue');
  END IF;
  IF v_ancien ->> 'country' = v_pays AND v_ancien ->> 'city' = v_ville THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_domicilie');
  END IF;
  BEGIN
    v_pris := public.argent_debiter_interne(v_nom, c_cout);
    IF coalesce(v_pris, 0) < c_cout THEN
      RAISE EXCEPTION 'fonds_insuffisants';
    END IF;
  EXCEPTION WHEN raise_exception THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'cout', c_cout);
  END;
  UPDATE public.personnages_donnees
     SET domicile = jsonb_build_object('country', v_pays, 'city', v_ville, 'depuis', v_jour)
   WHERE name = v_nom;
  SELECT d.domicile, d.liquide, d.arg INTO r FROM public.personnages_donnees d WHERE d.name = v_nom;
  RETURN jsonb_build_object('ok', true, 'cout', c_cout, 'ancien', v_ancien,
                            'domicile', r.domicile, 'liquide', r.liquide, 'arg', r.arg);
END;
$function$;

REVOKE ALL ON FUNCTION public.pelerinage_accomplir() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.domicile_changer() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pelerinage_accomplir() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.domicile_changer() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.rumeurs_organisations_cibles() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rumeurs_organisations_cibles() TO authenticated, service_role;
