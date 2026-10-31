#!/usr/bin/env python3
"""Migration réelle #283 sur PostgreSQL jetable, PJ purement fictif, rollback intégral."""
import json
import tempfile
from pathlib import Path
import pgserver
import psycopg2
from psycopg2.extras import Json

ROOT = Path(__file__).resolve().parents[2]

def main():
    srv = pgserver.get_server(tempfile.mkdtemp(prefix="hg-verrou-inventaire-"), cleanup_mode="delete")
    conn = None
    try:
        conn = psycopg2.connect(srv.get_uri())
        cur = conn.cursor()
        cur.execute("""
            CREATE ROLE authenticated;
            CREATE TABLE public.personnages_donnees(
                name text PRIMARY KEY,
                user_id text NOT NULL,
                inventory jsonb NOT NULL DEFAULT '[]'::jsonb,
                inventory_revision bigint NOT NULL DEFAULT 0
            );
            CREATE TABLE public.inventaire_ecarts_observes(acteur text, objet jsonb);
            CREATE FUNCTION public.inventaire_reception_etat(p_acteur text)
            RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
            BEGIN
              IF current_setting('hg.uid', true) IS DISTINCT FROM
                   (SELECT user_id FROM public.personnages_donnees WHERE name=p_acteur)
              THEN RAISE EXCEPTION 'personnage_non_autorise'; END IF;
              PERFORM 1 FROM public.personnages_donnees WHERE name=p_acteur FOR UPDATE;
              RETURN jsonb_build_object('ok',true);
            END $$;
            CREATE FUNCTION public.fixture_inventaire_revision() RETURNS trigger
            LANGUAGE plpgsql AS $$
            BEGIN
              IF NEW.inventory IS DISTINCT FROM OLD.inventory THEN
                NEW.inventory_revision := OLD.inventory_revision + 1;
              END IF;
              RETURN NEW;
            END $$;
            CREATE TRIGGER fixture_revision BEFORE UPDATE OF inventory
              ON public.personnages_donnees FOR EACH ROW
              EXECUTE FUNCTION public.fixture_inventaire_revision();
        """)
        cur.execute((ROOT / "outils/bancs/fixtures/inventaire-sauver-revision-production-20261031.sql").read_text())
        cur.execute("SELECT md5(pg_get_functiondef('public.inventaire_sauver_revision(text,bigint,jsonb)'::regprocedure))")
        hash_before=cur.fetchone()[0]
        assert hash_before=="57e01e4f842ef10ea8dd01dc99b3de9a", ("empreinte PG differente",hash_before)
        cur.execute((ROOT / "migrations/20261031124000_verrou_ajouts_inventaire_prepare.sql").read_text())
        cur.execute("SELECT pg_get_functiondef('public.inventaire_sauver_revision(text,bigint,jsonb)'::regprocedure)")
        new_body=cur.fetchone()[0]
        assert "ajout_inventaire_interdit" in new_body
        assert "INSERT INTO public.inventaire_ecarts_observes" not in new_body
        cur.execute("GRANT USAGE ON SCHEMA public TO authenticated")
        cur.execute("GRANT SELECT ON public.personnages_donnees, public.inventaire_ecarts_observes TO authenticated")
        cur.execute("GRANT EXECUTE ON FUNCTION public.inventaire_sauver_revision(text,bigint,jsonb) TO authenticated")
        ancien=[{"id":"bois","qty":3},{"id":"ticket"}]
        cur.execute("INSERT INTO personnages_donnees(name,user_id,inventory,inventory_revision) VALUES ('Fixture','uid-fictif',%s,5)",(Json(ancien),))
        # Le simulateur ne crée que des identités de fixture.
        cur.execute("SELECT set_config('hg.uid','uid-fictif',true),set_config('role','authenticated',true)")
        tests=0
        def snapshot():
            cur.execute("SELECT inventory,inventory_revision FROM personnages_donnees WHERE name='Fixture'")
            return cur.fetchone()
        def commander(revision,inventory):
            cur.execute("SELECT public.inventaire_sauver_revision('Fixture',%s,%s)",(revision,Json(inventory)))
            return cur.fetchone()[0]
        def check(condition,message):
            nonlocal tests
            assert condition,message
            tests+=1
            print("OK",tests,message,flush=True)
        before=snapshot()
        v=commander(5,ancien+[{"id":"or"}])
        check(v.get("raison")=="ajout_inventaire_interdit" and snapshot()==before,"nouvel objet refuse sans mutation")
        v=commander(5,ancien)
        check(v.get("ok") and v["revision"]==5 and snapshot()==before,"sauvegarde identique sans effet")
        v=commander(5,[{"id":"bois","qty":2},{"id":"ticket"}])
        check(v.get("ok") and v["revision"]==6,"decrement autorise")
        before=snapshot()
        v=commander(5,[{"id":"bois","qty":1}])
        check(v.get("raison")=="inventaire_perime" and snapshot()==before,"revision perimee refusee")
        v=commander(6,[{"id":"bois","qty":4},{"id":"ticket"}])
        check(v.get("raison")=="ajout_inventaire_interdit" and snapshot()==before,"hausse de pile refusee")
        v=commander(6,[{"id":"bois","qty":2},{"id":"ticket"},{"id":"ticket"}])
        check(v.get("raison")=="ajout_inventaire_interdit" and snapshot()==before,"duplicata refuse")
        v=commander(6,[{"id":"bois","qty":2}])
        check(v.get("ok") and v["revision"]==7,"retrait autorise")
        cur.execute("SELECT count(*) FROM inventaire_ecarts_observes")
        check(cur.fetchone()[0]==0,"aucune observation parasite apres refus")
        conn.rollback()   # Aucune donnée métier ni fixture conservée.
        print(json.dumps({"assertions":tests,"production":False,"rollback":True}))
    finally:
        if conn: conn.close()
        srv.cleanup()

if __name__ == "__main__":
    main()
