-- =====================================================================================
-- REPAS ET BOISSONS SUR PLACE — défaut reproduit le 29/10/2026 (Claude).
--
-- Dans un commerce de joueur, « Consommer sur place » refusait toute boisson, tout encas
-- servi, tout plat et tout menu : `consommer_sur_place_commerce` passe par le moteur d'achat
-- commun, qui refuse les génériques ni individualisés ni empilables
-- (`generique_regime_indetermine`). Or ce sont précisément ceux de la restauration servie
-- (boisson, encas, plat simple, plat élaboré, menu gastronomique). Reproduit au rôle
-- authenticated sur la chocolaterie d'Angie : « Dégustation à notre fontaine de chocolat »
-- (sur place uniquement) ne pouvait être ni achetée ni consommée. Seuls les produits « à
-- emporter » passaient.
--
-- Correctif : la consommation sur place pose un drapeau de transaction ; le moteur d'achat
-- accepte alors ces génériques (la livraison, une pile, est retirée aussitôt par la
-- consommation, comme avant pour les produits à emporter). L'achat à emporter de ces mêmes
-- génériques reste refusé. Prix, taxes, stock, effets : inchangés. Idempotente.
-- =====================================================================================
DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef((SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                                WHERE n.nspname = 'public' AND p.proname = 'acheter_produit_commerce_interne'));
  IF strpos(v_def, 'hg.consommation_sur_place') > 0 THEN RETURN; END IF;
  v_new := replace(v_def, $a$  IF NOT v_gen.individualise AND NOT v_gen.empilable THEN$a$,
                          $n$  IF NOT v_gen.individualise AND NOT v_gen.empilable
     AND coalesce(current_setting('hg.consommation_sur_place', true), '') <> 'on' THEN$n$);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch achat non applique : fragment introuvable'; END IF;
  EXECUTE v_new;
END $mig$;

DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.consommer_sur_place_commerce(text,text,text,text)'::regprocedure);
  IF strpos(v_def, 'hg.consommation_sur_place') > 0 THEN RETURN; END IF;
  v_new := replace(v_def, $a$ v_achat:=public.acheter_produit_commerce_interne(p_requete,p_acheteur,p_fonds_id,p_reference_id,1);$a$,
                          $n$ PERFORM set_config('hg.consommation_sur_place','on',true);
 v_achat:=public.acheter_produit_commerce_interne(p_requete,p_acheteur,p_fonds_id,p_reference_id,1);
 PERFORM set_config('hg.consommation_sur_place','',true);$n$);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch sur place non applique : fragment introuvable'; END IF;
  EXECUTE v_new;
END $mig$;
