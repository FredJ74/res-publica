-- Prévol lecture seule : l'autorité d'administration est distincte de la conduite.
DO $test$
DECLARE s text;
BEGIN
 s:=pg_get_functiondef('public.pnj_prendre(text[])'::regprocedure);
 IF position('IF NOT public.pnj_peut_conduire(v_moi, r.id) THEN' IN s)=0
   AND position('IF NOT public.pnj_peut_administrer(v_moi, r.id) THEN' IN s)=0 THEN
   RAISE EXCEPTION 'reprise_pnj_signature_inattendue';
 END IF;
 s:=pg_get_functiondef('public.pnj_peut_administrer(text,text)'::regprocedure);
 IF position('pnj_autorite_de' IN s)=0 THEN RAISE EXCEPTION 'autorite_commune_absente'; END IF;
 s:=pg_get_functiondef('public.pnj_peut_conduire(text,text)'::regprocedure);
 IF position('leader_pj' IN s)=0 THEN RAISE EXCEPTION 'commandement_commun_absent'; END IF;
 RAISE NOTICE 'OK: autorité != conduite ; migration de reprise vérifiable';
END $test$;
