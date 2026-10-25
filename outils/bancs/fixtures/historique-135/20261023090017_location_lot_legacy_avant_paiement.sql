-- #94 PREPAREE. Preserve les gardes exactes du depot #112 et des decisions urbanisme.
BEGIN;
DO $p$ DECLARE h text;s text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.payer_ordre(text,text,integer,integer)');
IF h IN('92234a6b14ff176d2c2c2236f705683e','9a461bfc3c33f04f342ce6f5586393a7','c3098e80ece8a156c8ad393284a816de') THEN
s:=regexp_replace(s,'BEGIN', $nouveau$BEGIN
  IF v_fn='louer_lot_ici' THEN RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise');END IF;$nouveau$);EXECUTE s;
ELSIF h IS NULL OR h NOT IN('dbbf6983f02e3dad47471d9ce2986968','d2bb47bf851552799397beba72a2a400','cb40019bbe21a4a7a5e78b59dd0a3243') THEN RAISE EXCEPTION 'definition_non_examinee: payer_ordre location';END IF;
END;$p$;
COMMIT;
