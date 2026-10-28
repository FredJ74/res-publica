-- Un prêt d'agents exige l'autorité administrative sur chaque PNJ.
-- Le commandement opérationnel seul ne permet pas de prêter à son tour.
DO $controle$
DECLARE f text; ancien text; nouveau text;
BEGIN
 f:=pg_get_functiondef('public.pnj_transferer(text[],text,boolean)'::regprocedure);
 ancien:='IF v_moi IS NOT NULL AND NOT public.pnj_peut_conduire(v_moi, r.id) THEN';
 nouveau:='IF v_moi IS NOT NULL AND NOT public.pnj_peut_administrer(v_moi, r.id) THEN';
 IF position(nouveau IN f)>0 THEN RETURN; END IF;
 IF (length(f)-length(replace(f,ancien,'')))/length(ancien)<>1 THEN
   RAISE EXCEPTION 'transfert_pnj_definition_non_examinee';
 END IF;
 EXECUTE replace(f,ancien,nouveau);
END $controle$;
