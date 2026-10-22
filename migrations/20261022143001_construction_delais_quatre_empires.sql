-- #57 PREPAREE. Les quatre empires actuels sont NON P2W. Aucun debit, aucune donnee reecrite.
BEGIN;
DO $p$ DECLARE h text;s text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.terrain_chantier_acte(text,text,text,integer,integer)');
IF h='81ffe6296a45947ee242e685ff3eea01' THEN
s:=replace(s,$a$  IF p_acte NOT IN ('chantier_accelerer', 'chantier_materiaux_voler') THEN$a$,$b$  -- Arbitrage : republic, soviet, narco et khalija sont tous non P2W.
  -- Aucun pays futur n'est autorise implicitement ; il faudra un arbitrage explicite.
  IF p_acte='chantier_accelerer' THEN RETURN jsonb_build_object('ok',false,'raison','delai_incompressible');END IF;
  IF p_acte NOT IN ('chantier_accelerer', 'chantier_materiaux_voler') THEN$b$);EXECUTE s;
ELSIF h='aee482fdff5312df105be6db713eef43' THEN
s:=replace(s,$a$  IF p_acte NOT IN ('chantier_accelerer', 'chantier_materiaux_voler') THEN$a$,$b$  -- Arbitrage : republic, soviet, narco et khalija sont tous non P2W.
  -- Aucun pays futur n'est autorise implicitement ; il faudra un arbitrage explicite.
  IF p_acte='chantier_accelerer' THEN RETURN jsonb_build_object('ok',false,'raison','delai_incompressible');END IF;
  IF p_acte NOT IN ('chantier_accelerer', 'chantier_materiaux_voler') THEN$b$);EXECUTE s;
ELSIF h IS NULL OR h NOT IN('12ed8b103e2b5462f4555475cb1009ef','e607ff4dff0b68c3c3abca87a35e8d0a') THEN RAISE EXCEPTION 'definition_non_examinee: terrain_chantier_acte';END IF;
END;$p$;
COMMIT;
