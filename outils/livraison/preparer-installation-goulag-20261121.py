#!/usr/bin/env python3
"""Assemble les 22 sources approuvées, sans connexion ni activation."""
import argparse
import hashlib
import json
from pathlib import Path

R = Path(__file__).resolve().parents[2]
PRE = """
SET LOCAL lock_timeout='3s';
SET LOCAL statement_timeout='60s';
DO $$ BEGIN
 IF to_regclass('public.sovarka_goulag_configuration') IS NOT NULL THEN
  RAISE EXCEPTION 'goulag_deja_installe_controle_requis';
 END IF;
END $$;
CREATE TEMP TABLE hg_goulag_install_empreintes(nom text PRIMARY KEY,nb bigint,empreinte text) ON COMMIT DROP;
DO $$ DECLARE t text; n bigint; h text; BEGIN
 FOREACH t IN ARRAY ARRAY['personnages_donnees','detentions','jugements','plaintes_en_cours','navigation_lieux_regles','caisses_autorites','caisses_batiments'] LOOP
  EXECUTE format('SELECT count(*),md5(coalesce(string_agg(md5(to_jsonb(x)::text),'''' ORDER BY md5(to_jsonb(x)::text)),'''')) FROM public.%I x',t) INTO n,h;
  INSERT INTO hg_goulag_install_empreintes VALUES(t,n,h);
 END LOOP;
END $$;
CREATE TEMP TABLE hg_goulag_routes_avant ON COMMIT DROP AS
 SELECT to_jsonb(r) AS valeur FROM public.rue_noeuds_serveur r
 WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-ecole-foret';
INSERT INTO hg_goulag_install_empreintes
 SELECT 'routes_hors_raccord',count(*),md5(coalesce(string_agg(md5(to_jsonb(r)::text),'' ORDER BY md5(to_jsonb(r)::text)),''))
 FROM public.rue_noeuds_serveur r
 WHERE NOT(country='soviet' AND city='ville_b' AND noeud IN ('krasnov-rue-ecole-foret','krasnov-camp-bucherons'));
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.rue_noeuds_serveur WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-camp-bucherons') THEN
  RAISE EXCEPTION 'camp_deja_reference_a_controler';
 END IF;
END $$;
"""
POST = """
DO $$ DECLARE r record; n bigint; h text; BEGIN
 IF public.sovarka_goulag_ouvert() IS DISTINCT FROM false THEN RAISE EXCEPTION 'ouverture_interdite'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.sovarka_goulag_configuration'::regclass
  AND conname='sovarka_goulag_activation_figee' AND convalidated) THEN RAISE EXCEPTION 'verrou_absent'; END IF;
 IF EXISTS(SELECT 1 FROM public.sovarka_goulag_configuration WHERE active IS DISTINCT FROM false) THEN RAISE EXCEPTION 'activation_interdite'; END IF;
 FOR r IN SELECT * FROM hg_goulag_install_empreintes WHERE nom<>'routes_hors_raccord' LOOP
  EXECUTE format('SELECT count(*),md5(coalesce(string_agg(md5(to_jsonb(x)::text),'''' ORDER BY md5(to_jsonb(x)::text)),'''')) FROM public.%I x',r.nom) INTO n,h;
  IF n<>r.nb OR h<>r.empreinte THEN RAISE EXCEPTION 'donnees_metier_modifiees:%',r.nom; END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND c.relkind='r' AND c.relname LIKE 'sovarka_goulag_%' AND NOT c.relrowsecurity) THEN
  RAISE EXCEPTION 'rls_goulag_absente'; END IF;
END $$;
DO $$ DECLARE avant jsonb; attendu jsonb; actuel jsonb; n bigint; h text; r record; BEGIN
 SELECT valeur INTO STRICT avant FROM hg_goulag_routes_avant;
 attendu:=jsonb_set(avant,'{voisins}',CASE WHEN (avant->'voisins') ? 'krasnov-camp-bucherons'
  THEN avant->'voisins' ELSE (avant->'voisins')||'["krasnov-camp-bucherons"]'::jsonb END);
 attendu:=jsonb_set(attendu,'{directions}',jsonb_set(coalesce(avant->'directions','{}'::jsonb),'{liens}',
  coalesce(avant#>'{directions,liens}','{}'::jsonb)||'{"droite":"krasnov-camp-bucherons"}'::jsonb));
 SELECT to_jsonb(x) INTO STRICT actuel FROM public.rue_noeuds_serveur x
  WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-ecole-foret';
 IF actuel IS DISTINCT FROM attendu THEN RAISE EXCEPTION 'raccord_ecole_non_conforme'; END IF;
 SELECT to_jsonb(x) INTO STRICT actuel FROM public.rue_noeuds_serveur x
  WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-camp-bucherons';
 attendu:='{"country":"soviet","city":"ville_b","noeud":"krasnov-camp-bucherons","voisins":["krasnov-rue-ecole-foret"],"directions":{"liens":{"arriere":"krasnov-rue-ecole-foret"},"parArrivee":{}}}'::jsonb;
 IF actuel IS DISTINCT FROM attendu THEN RAISE EXCEPTION 'camp_non_conforme'; END IF;
 SELECT count(*),md5(coalesce(string_agg(md5(to_jsonb(x)::text),'' ORDER BY md5(to_jsonb(x)::text)),'')) INTO n,h
  FROM public.rue_noeuds_serveur x
  WHERE NOT(country='soviet' AND city='ville_b' AND noeud IN ('krasnov-rue-ecole-foret','krasnov-camp-bucherons'));
 SELECT * INTO STRICT r FROM hg_goulag_install_empreintes WHERE nom='routes_hors_raccord';
 IF n<>r.nb OR h<>r.empreinte THEN RAISE EXCEPTION 'autres_routes_modifiees'; END IF;
END $$;
"""

def preparer(mode):
    from pglast import parse_sql
    files = [p for p in sorted((R / 'migrations').glob('*goulag*.sql')) if '105000' not in p.name]
    if len(files) != 22:
        raise ValueError('Lot inattendu : contrôler les nouvelles migrations')
    for p in files:
        if any(type(s.stmt).__name__ == 'TransactionStmt' for s in parse_sql(p.read_text())):
            raise ValueError('Transaction interne interdite : ' + p.name)
    sql = PRE + '\n'.join('-- SOURCE ' + p.name + '\n' + p.read_text() for p in files) + POST
    if mode == 'rollback':
        sql = "BEGIN ISOLATION LEVEL REPEATABLE READ;\n" + sql + "\nSELECT 'installation_verifiee_et_annulee' AS controle, public.sovarka_goulag_ouvert() AS ouvert;\nROLLBACK;"
    return {'mode': mode, 'sql': sql, 'sha256': hashlib.sha256(sql.encode()).hexdigest(),
            'sources': [{'path': str(p.relative_to(R)), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in files]}

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=['rollback', 'apply'], default='rollback')
    args = parser.parse_args()
    print(json.dumps(preparer(args.mode)))
