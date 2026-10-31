-- Autorité et commandement sont indépendants (décision Fred, 28/10/2026).
-- Un chef peut déposer les PNJ prêtés qui suivent son groupe, mais ne peut les
-- reprendre après séparation : la reprise exige l'autorité administrative.
-- Préserver pnj_peut_conduire pour le détachement existant, ne changer que pnj_prendre.
DO $autorite$
DECLARE s text; ancien text; nouveau text;
BEGIN
 s:=pg_get_functiondef('public.pnj_prendre(text[])'::regprocedure);
 ancien:='IF NOT public.pnj_peut_conduire(v_moi, r.id) THEN';
 nouveau:='IF NOT public.pnj_peut_administrer(v_moi, r.id) THEN';
 IF position(nouveau IN s)>0 AND position(ancien IN s)=0 THEN RETURN; END IF;
 IF (length(s)-length(replace(s,ancien,'')))/length(ancien)<>1 THEN
   RAISE EXCEPTION 'reprise_autorite_definition_non_examinee';
 END IF;
 EXECUTE replace(s,ancien,nouveau);
END $autorite$;
