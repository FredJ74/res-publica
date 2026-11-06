-- #379, lot 3a (Claude, 03/11/2026) : bonus de location du chef d'organisation décidé par le serveur.
-- Règle existante de l'écran (appliquerBonusLocation), inchangée : quand le loyer d'un bail
-- domicilié pour une organisation est réellement payé, le chef de cette organisation reçoit 30 %
-- (arrondi inférieur) des bonus POP et INF du local. Le bail impayé ne rapporte rien.
-- Désormais posé dans prelever_loyer_bail, au moment même du paiement (cron de minuit), au lieu
-- d'être ajouté par le navigateur au réveil. Les bonus viennent du bail, attesté par le
-- référentiel des locaux (trigger location_local_tarif_attester).
-- Dépend de 20261103230000 (jauges_effet_appliquer_interne).

DO $prevol$
BEGIN
 IF to_regprocedure('public.jauges_effet_appliquer_interne(text,integer,integer,integer)') IS NULL THEN
  RAISE EXCEPTION '379_lot3a_lot_presidence_absent'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.prelever_loyer_bail(text)')
     AND (md5(prosrc)='7d5ec3aeba1b83dcb7145324f35dbf5e' OR position('hg379_bonus_location_v1' in prosrc)>0)) THEN
  RAISE EXCEPTION '379_lot3a_prelever_loyer_divergent'; END IF;
END $prevol$;

DO $patch$
DECLARE v_def text; v_ancre text; v_ajout text;
BEGIN
 v_def:=pg_get_functiondef('public.prelever_loyer_bail(text)'::regprocedure);
 IF position('hg379_bonus_location_v1' in v_def)>0 THEN RETURN; END IF;
 v_ancre:=E'  RETURN ''paye'';\nEND;';
 v_ajout:=$a$  -- hg379_bonus_location_v1 : 30 % des bonus POP/INF du local au chef de l'organisation
  -- domiciliée, seulement quand le loyer vient d'être payé (règle de appliquerBonusLocation).
  v_orga_id:=nullif(btrim(coalesce(v_data->>'orgaId','')),'');
  IF v_orga_id IS NOT NULL AND (coalesce((v_data->>'bonusPOP')::numeric,0)>0 OR coalesce((v_data->>'bonusINF')::numeric,0)>0) THEN
    BEGIN
      SELECT o.data::jsonb->>'chef' INTO v_orga_data FROM public.organisations o WHERE o.id=v_orga_id;
    EXCEPTION WHEN invalid_text_representation THEN v_orga_data:=NULL;
    END;
    IF v_orga_data IS NOT NULL AND (v_orga_data=v_locataire OR v_locataire='orga:'||v_orga_id) THEN
      PERFORM public.jauges_effet_appliquer_interne(v_orga_data,
        floor(greatest(0,coalesce((v_data->>'bonusPOP')::numeric,0))*0.3)::integer,
        floor(greatest(0,coalesce((v_data->>'bonusINF')::numeric,0))*0.3)::integer,0);
    END IF;
  END IF;
$a$;
 IF (length(v_def)-length(replace(v_def,v_ancre,'')))/length(v_ancre)<>1 THEN RAISE EXCEPTION '379_lot3a_ancre_loyer'; END IF;
 EXECUTE replace(v_def,v_ancre,v_ajout||v_ancre);
END $patch$;
NOTIFY pgrst,'reload schema';
