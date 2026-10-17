#!/usr/bin/env python3
"""Uniquement PostgreSQL jetable local. Aucun DSN ni acces de production accepte.
Les tables, la vue et le trigger personnage viennent du baseline non modifie.
Les services Supabase externes sont explicitement simules (auth.uid/role).
"""
from pathlib import Path
import sys, tempfile, re, json
from concurrent.futures import ThreadPoolExecutor
import pgserver, psycopg2
ROOT=Path(__file__).resolve().parents[2]

def fonction(nom):
    matches=[]
    for p in (ROOT/'baseline/domaines').glob('*/*fonctions*.sql'):
        matches+=re.findall(r'CREATE OR REPLACE FUNCTION public\.'+re.escape(nom)+r'\(.*?\$function\$;',p.read_text(),re.S)
    assert len(matches)==1,(nom,len(matches))
    return matches[0]

def table(nom):
    for p in (ROOT/'baseline/domaines').glob('*/10_tables*.sql'):
        m=re.search(r'CREATE TABLE public\.'+re.escape(nom)+r' \(.*?\n\);',p.read_text(),re.S)
        if m:return m[0]
    raise AssertionError(nom)

if len(sys.argv)>1:raise SystemExit('Ce banc cree exclusivement sa propre base jetable; aucun argument accepte.')
with tempfile.TemporaryDirectory(prefix='hg-finances-') as tmp:
    server=pgserver.get_server(Path(tmp)/'pgdata')
    cn=psycopg2.connect(server.get_uri());cn.autocommit=True;q=cn.cursor()
    q.execute("CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role; CREATE SCHEMA auth; CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$SELECT nullif(current_setting('hg.uid',true),'')::uuid$$; GRANT USAGE ON SCHEMA auth TO authenticated; GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated;")
    q.execute(fonction('est_appel_serveur'))
    for t in ['personnages_donnees','comptes_bancaires','placements_bancaires','prets','dons_en_attente','dons_requetes']:
        q.execute(table(t))
    q.execute((ROOT/'baseline/domaines/personnage-et-presence/40_vues.sql').read_text())
    q.execute(fonction('personnages_vue_modifier'))
    q.execute('CREATE TRIGGER hg_fixture_vue INSTEAD OF UPDATE ON public.personnages FOR EACH ROW EXECUTE FUNCTION public.personnages_vue_modifier()')
    q.execute("GRANT SELECT ON personnages TO authenticated; COMMENT ON VIEW personnages IS 'fixture droits conserves'; COMMENT ON COLUMN personnages.liquide IS 'fixture colonne'; INSERT INTO personnages_donnees(name,country,arg,liquide,banque,user_id) VALUES('Alice','republic',2000,2000,0,'00000000-0000-0000-0000-000000000001'),('Bob','republic',0,NULL,0,'00000000-0000-0000-0000-000000000002')")
    def scalar(sql,params=None):
        q.execute(sql,params);return q.fetchone()[0]
    groups=0
    def ok(nom):
        global groups
        groups+=1;print('OK',nom,flush=True)
    migration=(ROOT/'migrations/20261017090342_precision_monetaire_reconstruction.sql').read_text()
    q.execute(migration);q.execute(migration)
    assert scalar("SELECT liquide::text FROM personnages_donnees WHERE name='Alice'")=='2000'
    assert scalar("SELECT liquide FROM personnages_donnees WHERE name='Bob'") is None
    assert scalar("SELECT has_table_privilege('authenticated','personnages','SELECT')")
    assert scalar("SELECT obj_description('personnages'::regclass)")=='fixture droits conserves'
    assert scalar("SELECT count(*) FROM pg_trigger WHERE tgrelid='personnages'::regclass AND NOT tgisinternal")==1
    ok('precision rejouable, NULL, soldes, vue, droits, commentaires et trigger conserves')
    for v in ['5.505','NaN','Infinity','-Infinity']:
        try:q.execute('UPDATE personnages_donnees SET liquide=%s WHERE name=\'Alice\'',(v,))
        except psycopg2.Error:pass
        else:raise AssertionError('centime invalide accepte '+v)
    q.execute("UPDATE personnages SET liquide=5.50 WHERE name='Alice'")
    assert scalar("SELECT liquide::text FROM personnages_donnees WHERE name='Alice'")=='5.50'
    assert scalar("SELECT hg_fr_texte(-0.50)")=='-0.50'
    assert scalar("SELECT hg_fr_lire('\"5.50\"')::text")=='5.50'
    for v in ['5.50','"5.505"','null','"1e2"']:
        try:q.execute('SELECT hg_fr_lire(%s::jsonb)',(v,))
        except psycopg2.Error:pass
        else:raise AssertionError('transport invalide accepte '+v)
    ok('fractions de centime refusees sans arrondi, chaine obligatoire, ecriture via vraie vue')
    # Un echec de conversion annule le DDL ET conserve les donnees, meme hors des personnages.
    q.execute('ALTER TABLE comptes_bancaires ALTER COLUMN solde TYPE numeric USING solde::numeric')
    q.execute("INSERT INTO comptes_bancaires(id,personnage,pays,banque,solde) VALUES('subcent','Alice','republic','nationale',5.505)")
    try:q.execute(migration)
    except psycopg2.Error:q.execute('ROLLBACK')
    else:raise AssertionError('historique fractionnaire silencieusement arrondi')
    assert scalar("SELECT solde FROM comptes_bancaires WHERE id='subcent'")==__import__('decimal').Decimal('5.505')
    assert scalar("SELECT count(*) FROM personnages")==2
    q.execute("DELETE FROM comptes_bancaires WHERE id='subcent'");q.execute(migration)
    ok('historique hors centime bloque toute conversion, rollback conserve donnees et vue')
    # Services annexes simules : destination municipale connue, recette transactionnelle.
    # La fonction de prelevement est la VRAIE fonction archivee puis migree.
    q.execute(table('locations_actives'))
    q.execute("CREATE TABLE fixture_recettes(montant numeric); CREATE FUNCTION bail_destination_attestee(jsonb) RETURNS jsonb LANGUAGE sql AS $$SELECT '{\"type\":\"municipal\",\"pays\":\"republic\",\"ville\":\"capitale\"}'::jsonb$$; CREATE FUNCTION recette_municipale(text,text,numeric,text) RETURNS jsonb LANGUAGE plpgsql AS $$BEGIN INSERT INTO fixture_recettes VALUES($3); RETURN '{\"ok\":true}'::jsonb; END$$;")
    q.execute(fonction('prelever_loyer_bail'))
    loyer=(ROOT/'migrations/20261017090621_loyers_banque_prioritaire_atomiques.sql').read_text()
    q.execute(loyer);q.execute(loyer)
    def reset(banque,liquide,prix='5.50'):
        q.execute("TRUNCATE locations_actives,fixture_recettes,comptes_bancaires")
        q.execute("UPDATE personnages_donnees SET liquide=%s,arg=12345 WHERE name='Alice'",(liquide,))
        q.execute("INSERT INTO comptes_bancaires(id,personnage,pays,banque,solde) VALUES('national','Alice','republic','nationale',%s),('helvetia','Alice','republic','helvetia',9999),('autre-pays','Alice','khalija','nationale',9999)",(banque,))
        q.execute("INSERT INTO locations_actives(id,country,data) VALUES('bail','republic',%s::jsonb)",(json.dumps({'locataire':'Alice','prix':prix}),))
    reset('10.00','20.00')
    assert scalar("SELECT prelever_loyer_bail('bail')")=='paye'
    assert scalar("SELECT solde FROM comptes_bancaires WHERE id='national'")==__import__('decimal').Decimal('4.50')
    assert scalar("SELECT liquide FROM personnages WHERE name='Alice'")==20
    assert scalar("SELECT arg FROM personnages WHERE name='Alice'")==12345
    assert scalar("SELECT prelever_loyer_bail('bail')")=='deja_preleve'
    assert scalar('SELECT count(*) FROM fixture_recettes')==1
    ok('loyer banque prioritaire, arg preserve, autres banques exclues, rejeu sans debit')
    reset('2.00','10.00')
    assert scalar("SELECT prelever_loyer_bail('bail')")=='paye'
    assert scalar("SELECT solde FROM comptes_bancaires WHERE id='national'")==0
    assert scalar("SELECT liquide FROM personnages WHERE name='Alice'")==__import__('decimal').Decimal('6.50')
    ok('loyer complement liquide exact apres epuisement du compte national')
    reset('2.00','3.00')
    assert scalar("SELECT prelever_loyer_bail('bail')")=='avertissement'
    assert scalar("SELECT solde FROM comptes_bancaires WHERE id='national'")==2
    assert scalar("SELECT liquide FROM personnages WHERE name='Alice'")==3
    assert scalar('SELECT count(*) FROM fixture_recettes')==0
    ok('fonds totaux insuffisants : aucun debit ni credit, avertissement conserve')
    reset('2.00','3.50')
    assert scalar("SELECT prelever_loyer_bail('bail')")=='paye'
    assert scalar("SELECT liquide FROM personnages WHERE name='Alice'")==0
    ok('total exactement egal et solde nul')
    reset('2.00','10.00')
    q.execute("CREATE FUNCTION fixture_fail() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_apres_credit'; END$$; CREATE TRIGGER fixture_fail BEFORE UPDATE ON comptes_bancaires FOR EACH ROW EXECUTE FUNCTION fixture_fail()")
    try:q.execute("SELECT prelever_loyer_bail('bail')")
    except psycopg2.Error as e:assert 'panne_apres_credit' in str(e)
    else:raise AssertionError('panne non injectee')
    assert scalar('SELECT count(*) FROM fixture_recettes')==0
    assert scalar("SELECT solde FROM comptes_bancaires WHERE id='national'")==2
    assert scalar("SELECT liquide FROM personnages WHERE name='Alice'")==10
    assert scalar("SELECT data->>'jourPaiement' FROM locations_actives WHERE id='bail'") is None
    q.execute('DROP TRIGGER fixture_fail ON comptes_bancaires')
    ok('panne apres credit : rollback recette, banque, liquide et marqueur')
    reset('2.00','10.00')
    def concurrent(_):
        c=psycopg2.connect(server.get_uri());c.autocommit=True
        with c.cursor() as cur:cur.execute("SELECT prelever_loyer_bail('bail')");v=cur.fetchone()[0]
        c.close();return v
    with ThreadPoolExecutor(max_workers=2) as pool: result=list(pool.map(concurrent,range(2)))
    assert sorted(result)==['deja_preleve','paye'],result
    assert scalar('SELECT sum(montant) FROM fixture_recettes')==__import__('decimal').Decimal('5.50')
    ok('deux connexions concurrentes : un seul prelevement et une seule contrepartie')
    q.execute('SET ROLE authenticated')
    try:q.execute("SELECT prelever_loyer_bail('bail')")
    except psycopg2.Error as e:assert e.pgcode=='42501'
    else:raise AssertionError('RPC serveur accessible au navigateur')
    q.execute('RESET ROLE')
    ok('loyer reserve au serveur, aucune invocation directe du navigateur')
    dons_migration=(ROOT/'migrations/20261017090721_receptions_dons_atomiques_et_revisions.sql').read_text()
    q.execute(dons_migration);q.execute(dons_migration)
    q.execute("INSERT INTO dons_en_attente(id,destinataire,montant) VALUES(1,'Alice',5.50),(2,'Alice',3.25),(3,'Bob',100),(4,'Alice',1.25)")
    uid='00000000-0000-0000-0000-000000000001'
    def auth():
        q.execute('SET ROLE authenticated');q.execute("SELECT set_config('hg.uid',%s,false)",(uid,))
    def appel(ids,key='00000000-0000-0000-0000-000000000010',nom='Alice'):
        return scalar('SELECT hg_fin_dons_recevoir(%s::uuid,%s,%s::jsonb)',(key,nom,json.dumps(ids)))
    q.execute("UPDATE personnages_donnees SET arg=100 WHERE name='Alice'");auth()
    r=appel(['1','2']);assert r['resultat']=={'montant':'8.75','nombre':2}
    assert r['etat']['arg']=='108.75'
    assert isinstance(r['etat']['revision'],str)
    r2=appel(['2','1']);assert r2['rejeu'] and r2['resultat']==r['resultat']
    r3=appel(['1','2'],'00000000-0000-0000-0000-000000000011')
    assert r3['resultat']=={'montant':'0.00','nombre':0}
    ok('dons : credit et marqueurs atomiques, centimes, rejeu meme UUID et nouvelle tentative')
    try:appel(['1'])
    except psycopg2.Error as e:assert e.pgcode=='22023'
    else:raise AssertionError('meme UUID accepte un autre corps')
    try:appel(['4','3'],'00000000-0000-0000-0000-000000000012')
    except psycopg2.Error as e:assert e.pgcode=='42501'
    else:raise AssertionError('don etranger accepte')
    try:appel(['3'],'00000000-0000-0000-0000-000000000013','Bob')
    except psycopg2.Error as e:assert e.pgcode=='42501'
    else:raise AssertionError('personnage etranger accepte')
    try:scalar('SELECT * FROM hg_fin_requetes')
    except psycopg2.Error as e:assert e.pgcode=='42501'
    else:raise AssertionError('recus exposes')
    try:q.execute('UPDATE dons_en_attente SET traite=true WHERE id=4')
    except psycopg2.Error as e:assert e.pgcode=='42501'
    else:raise AssertionError('marquage direct autorise')
    q.execute('RESET ROLE')
    assert scalar('SELECT traite FROM dons_en_attente WHERE id=4') is False
    ok('dons : acteur/propriete/corps controles, refus integral et droits directs fermes')
    q.execute("CREATE FUNCTION fixture_don_fail() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.arg<>OLD.arg THEN RAISE EXCEPTION 'panne_credit_don'; END IF; RETURN NEW; END$$; CREATE TRIGGER fixture_don_fail BEFORE UPDATE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION fixture_don_fail()")
    auth()
    try:appel(['4'],'00000000-0000-0000-0000-000000000014')
    except psycopg2.Error as e:assert 'panne_credit_don' in str(e)
    else:raise AssertionError('panne don non injectee')
    q.execute('RESET ROLE')
    assert scalar('SELECT traite FROM dons_en_attente WHERE id=4') is False
    assert scalar("SELECT count(*) FROM hg_fin_requetes WHERE requete='00000000-0000-0000-0000-000000000014'")==0
    q.execute('DROP TRIGGER fixture_don_fail ON personnages_donnees')
    ok('dons : panne entre marquage et credit annule aussi marqueur et recu')
    def don_concurrent(i):
        c=psycopg2.connect(server.get_uri());c.autocommit=True
        with c.cursor() as cur:
            cur.execute('SET ROLE authenticated');cur.execute("SELECT set_config('hg.uid',%s,false)",(uid,))
            cur.execute('SELECT hg_fin_dons_recevoir(%s::uuid,%s,%s::jsonb)',('00000000-0000-0000-0000-00000000001'+str(5+i),'Alice','["4"]'))
            result=cur.fetchone()[0]
        c.close();return result
    with ThreadPoolExecutor(max_workers=2) as pool:result=list(pool.map(don_concurrent,range(2)))
    assert sum(int(r['resultat']['nombre']) for r in result)==1
    assert scalar("SELECT arg FROM personnages_donnees WHERE name='Alice'")==110
    ok('dons : deux connexions, deux intentions, un seul credit du meme don')
    # Un ancien recu conserve son resultat, mais transporte un etat ACTUEL.
    q.execute("UPDATE personnages_donnees SET arg=arg+2000 WHERE name='Alice'");auth()
    r=appel(['1','2']);assert r['etat']['arg']=='2110.00' and r['resultat']['montant']=='8.75'
    q.execute('RESET ROLE')
    ok('reponse tardive : recu immuable et photographie serveur actualisee apres credit')
    print(f'{groups}/{groups} groupes PostgreSQL reussis')
    cn.close()
    server.cleanup()
