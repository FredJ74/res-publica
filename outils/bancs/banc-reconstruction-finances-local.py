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
    # Helvetia : vraies fonctions financieres et vrai payer_ordre ; services annexes
    # de memoire politique/transition simules, aucune banque ni don de production.
    for t in ['caisses_batiments','bnr_refinancements_helvetia','ordres_couts','ordres_couts_inconnus','ordres_couts_ecarts','presidence_memoire_ordres','fiche_hausses_observees','indices_villes']:
        q.execute(table(t))
    for n in ['est_mon_personnage','exiger_acteur','payer_ordre','helvetia_assurer_liquidite','helvetia_debiter_source','helvetia_crediter_destination','helvetia_ie_national','helvetia_taux_refinancement_bnr']:
        q.execute(fonction(n))
    q.execute("CREATE FUNCTION rp_transition_active(text) RETURNS boolean LANGUAGE sql AS $$SELECT false$$")
    banque_source=(ROOT/'baseline/domaines/banque/20_fonctions.sql').read_text()
    for n in ['ouvrir_compte_helvetia','deposer_helvetia','retirer_helvetia','fermer_compte_helvetia','creer_placement_helvetia','creer_pret_helvetia','rembourser_pret_helvetia_integral','accepter_accord_helvetia']:
        for f in re.findall(r'CREATE OR REPLACE FUNCTION public\.'+re.escape(n)+r'\(.*?\$function\$;',banque_source,re.S):q.execute(f)
    q.execute("INSERT INTO ordres_couts(fn,pa,cost) VALUES('gerer_finances',0,0),('compte_offshore',0,0),('emprunter_prive',1,0)")
    q.execute("INSERT INTO caisses_batiments(id,data) VALUES('republic_banque-privee','{\"solde\":500000}')")
    q.execute("TRUNCATE comptes_bancaires; UPDATE personnages_donnees SET arg=30000,liquide=30000,pa=10,current_building='banque-privee',current_room='bureau_prive' WHERE name='Alice'")
    helv=(ROOT/'migrations/20261017091047_helvetia_requetes_atomiques.sql').read_text()
    q.execute(helv);q.execute(helv)
    garde=(ROOT/'migrations/20261017091428_garde_sauvegardes_financieres.sql').read_text()
    q.execute(garde);q.execute(garde)
    def helvetia(op,args,key):
        return scalar('SELECT hg_fin_helvetia(%s::uuid,%s,%s,%s::jsonb)',(f'00000000-0000-0000-0000-{key:012d}','Alice',op,json.dumps(args)))
    auth()
    r=helvetia('ouvrir',{},100)
    assert r['etat']['liquide']=='20000.00'
    assert r['etat']['comptes'][0]['solde']=='10000.00'
    assert helvetia('ouvrir',{},100)['rejeu']
    ok('Helvetia ouverture : capital conserve, recu rejouable')
    r=helvetia('deposer',{'montant':'5.50','source':'liquide'},101)
    assert r['etat']['liquide']=='19994.50' and r['etat']['comptes'][0]['solde']=='10005.50'
    assert helvetia('deposer',{'montant':'5.50','source':'liquide'},101)['rejeu']
    r=helvetia('retirer',{'montant':'5.50','destination':'liquide'},102)
    assert r['etat']['liquide']=='20000.00' and r['etat']['comptes'][0]['solde']=='10000.00'
    assert helvetia('retirer',{'montant':'5.50','destination':'liquide'},102)['rejeu']
    ok('Helvetia depot et retrait fractionnaires : toutes contreparties et rejeux')
    for montant in ['5.505',5.5,'999999.00']:
        try:helvetia('deposer',{'montant':montant,'source':'liquide'},103)
        except psycopg2.Error:pass
        else:raise AssertionError('montant Helvetia invalide accepte')
    q.execute('RESET ROLE')
    assert scalar("SELECT liquide FROM personnages_donnees WHERE name='Alice'")==20000
    assert scalar("SELECT count(*) FROM hg_fin_requetes WHERE requete='00000000-0000-0000-0000-000000000103'")==0
    ok('Helvetia refus : chiffres binaires, sous-centime et fonds insuffisants sans recu partiel')
    q.execute("CREATE FUNCTION fixture_pret_fail() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_creation_pret'; END$$; CREATE TRIGGER fixture_pret_fail BEFORE INSERT ON prets FOR EACH ROW EXECUTE FUNCTION fixture_pret_fail()")
    auth()
    try:helvetia('emprunter',{'montant':'1000.00','duree':5},104)
    except psycopg2.Error as e:assert 'panne_creation_pret' in str(e),str(e)
    else:raise AssertionError('panne pret non injectee')
    q.execute('RESET ROLE')
    assert scalar("SELECT pa FROM personnages_donnees WHERE name='Alice'")==10
    assert scalar("SELECT solde FROM comptes_bancaires WHERE banque='helvetia'")==10000
    assert scalar("SELECT (data->>'solde')::numeric FROM caisses_batiments WHERE id='republic_banque-privee'")==500000
    q.execute('DROP TRIGGER fixture_pret_fail ON prets')
    ok('Helvetia pret : panne apres paiement PA et reserve annule toutes contreparties')
    auth()
    r=helvetia('emprunter',{'montant':'1000.00','duree':5},104);id_pret=r['resultat']['id']
    assert helvetia('emprunter',{'montant':'1000.00','duree':5},104)['rejeu']
    assert r['etat']['comptes'][0]['solde']=='11000.00'
    q.execute('RESET ROLE');assert scalar("SELECT pa FROM personnages_donnees WHERE name='Alice'")==9
    assert scalar('SELECT montant_restant FROM prets WHERE id=%s',(id_pret,))==1120
    auth();r=helvetia('rembourser',{'pret_id':id_pret,'sources':[{'type':'liquide','montant':'1120.00'}]},105)
    assert helvetia('rembourser',{'pret_id':id_pret,'sources':[{'type':'liquide','montant':'1120.00'}]},105)['rejeu']
    assert r['etat']['liquide']=='18880.00'
    q.execute('RESET ROLE');assert scalar('SELECT montant_restant FROM prets WHERE id=%s',(id_pret,))==0
    ok('Helvetia pret et remboursement : dette, capital, PA et non-repetition')
    auth();r=helvetia('placer',{'montant':'500.50','type':'declare'},106)
    assert r['etat']['comptes'][0]['solde']=='10499.50'
    assert helvetia('placer',{'montant':'500.50','type':'declare'},106)['rejeu']
    q.execute('RESET ROLE');assert scalar('SELECT montant FROM placements_bancaires')==__import__('decimal').Decimal('500.50')
    auth();r=helvetia('fermer',{'destination':'liquide'},107)
    assert r['etat']['comptes'][0]['solde']=='0.00' and helvetia('fermer',{'destination':'liquide'},107)['rejeu']
    q.execute('RESET ROLE')
    q.execute("UPDATE prets SET statut='contentieux',montant_restant=1120,proposition_en_attente=true,accord_actif=false WHERE id=%s",(id_pret,))
    auth();r=helvetia('accord',{'pret_id':id_pret},108)
    assert helvetia('accord',{'pret_id':id_pret},108)['rejeu']
    q.execute('RESET ROLE');assert scalar('SELECT montant_restant FROM prets WHERE id=%s',(id_pret,))==1344
    ok('Helvetia placement, fermeture et accord : centimes, etats et majoration unique')
    auth()
    try:scalar("SELECT ouvrir_compte_helvetia('Alice')")
    except psycopg2.Error as e:assert e.pgcode=='42501'
    else:raise AssertionError('ancien circuit direct encore autorise')
    q.execute('RESET ROLE')
    q.execute("UPDATE personnages_donnees SET current_room='ailleurs' WHERE name='Alice'");auth()
    try:helvetia('ouvrir',{},109)
    except psycopg2.Error as e:assert e.pgcode=='42501'
    else:raise AssertionError('Helvetia accessible hors bureau')
    q.execute('RESET ROLE');ok('Helvetia acces territorial et fermeture des anciennes RPC directes')
    q.execute("GRANT UPDATE ON personnages TO authenticated")
    q.execute("UPDATE personnages_donnees SET liquide=liquide+2000 WHERE name='Alice'")
    vrai=scalar("SELECT liquide FROM personnages_donnees WHERE name='Alice'")
    auth()
    try:q.execute("UPDATE personnages SET liquide=0 WHERE name='Alice'")
    except psycopg2.Error as e:assert e.pgcode=='42501' and 'transaction_financiere_requise' in str(e)
    else:raise AssertionError('ancienne sauvegarde a ecrase le solde')
    q.execute("UPDATE personnages SET bio='profil valide' WHERE name='Alice'")
    try:q.execute("INSERT INTO hg_fin_actes_en_cours VALUES(txid_current(),'Alice')")
    except psycopg2.Error as e:assert e.pgcode=='42501'
    else:raise AssertionError('marqueur prive falsifiable')
    q.execute("SELECT set_config('hg.finances_interne','on',false)")
    try:q.execute("UPDATE personnages SET liquide=0 WHERE name='Alice'")
    except psycopg2.Error as e:assert e.pgcode=='42501'
    else:raise AssertionError('GUC falsifie contourne le controle')
    q.execute('RESET ROLE')
    assert scalar("SELECT liquide FROM personnages_donnees WHERE name='Alice'")==vrai
    assert scalar("SELECT bio FROM personnages_donnees WHERE name='Alice'")=='profil valide'
    assert scalar('SELECT count(*) FROM hg_fin_actes_en_cours')==0
    ok('sauvegarde : credit serveur preserve, profil autorise, marqueur et GUC non falsifiables')
    q.execute(table('objets_recus'));q.execute(table('batiments_etat'));q.execute(table('ressources_economie'))
    q.execute('ALTER TABLE objets_recus ENABLE ROW LEVEL SECURITY; ALTER TABLE objets_recus ADD PRIMARY KEY(id); CREATE UNIQUE INDEX fixture_personnage_nom ON personnages_donnees(name)')
    q.execute(fonction('tracts_reclamer_don'))
    q.execute((ROOT/'migrations/20261016131932_reception_objets_atomique.sql').read_text())
    for n in ['mon_personnage','batiment_caisse_mouvement','batiment_etat_lire']:q.execute(fonction(n))
    q.execute("INSERT INTO ressources_economie(cle,prix_base) VALUES('bois',5)")
    q.execute("INSERT INTO batiments_etat(id,country,city,building_id,data) VALUES('republic_capitale_la-tribune','republic','capitale','la-tribune','{\"imprimerie\":{\"stockBois\":0,\"caisse\":100}}')")
    q.execute("UPDATE personnages_donnees SET current_city='capitale',current_building='la-tribune',current_room='accueil_tribune',inventory='[{\"stackKey\":\"bois\",\"qty\":20}]',arg=0,liquide=0 WHERE name='Alice'")
    bois=(ROOT/'migrations/20261017091745_bois_imprimerie_transaction_atomique.sql').read_text()
    q.execute(bois);q.execute(bois)
    def vendre(qte,key):
        return scalar('SELECT hg_fin_bois_vendre(%s::uuid,%s,%s::jsonb)',(f'00000000-0000-0000-0000-{key:012d}','Alice',json.dumps(qte)))
    auth();q.execute("SELECT set_config('request.path','/rpc/hg_fin_bois_vendre',false)")
    r=vendre(3,200);assert r['resultat']=={'quantite':3,'montant':'16.50','prix_unitaire':'5.50'}
    assert r['etat']['liquide']=='16.50' and r['inventory'][0]['qty']==17
    assert vendre(3,200)['rejeu']
    q.execute('RESET ROLE')
    d=scalar("SELECT batiment_etat_lire(data) FROM batiments_etat")['imprimerie']
    assert d=={'stockBois':3,'caisse':83.5},d
    ok('bois : 3 unites a 5.50 FR, inventaire/stock/caisse/credit et recu atomiques')
    auth();r=vendre(17,201);assert r['resultat']['quantite']==7 and r['resultat']['montant']=='38.50'
    assert r['inventory'][0]['qty']==10
    q.execute('RESET ROLE');d=scalar("SELECT batiment_etat_lire(data) FROM batiments_etat")['imprimerie']
    assert d=={'stockBois':10,'caisse':45},d
    auth()
    try:vendre(1,202)
    except psycopg2.Error as e:assert 'capacite_insuffisante' in str(e)
    else:raise AssertionError('depassement plafond bois')
    q.execute('RESET ROLE');ok('bois : vente partielle historique conservee et plafond PNJ infranchissable')
    q.execute("UPDATE batiments_etat SET data='{\"imprimerie\":{\"stockBois\":0,\"caisse\":100}}'")
    q.execute("CREATE FUNCTION fixture_bois_fail() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.arg<>OLD.arg THEN RAISE EXCEPTION 'panne_credit_bois'; END IF; RETURN NEW; END$$; CREATE TRIGGER fixture_bois_fail BEFORE UPDATE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION fixture_bois_fail()")
    auth()
    try:vendre(1,203)
    except psycopg2.Error as e:assert 'panne_credit_bois' in str(e),str(e)
    else:raise AssertionError('panne bois non injectee')
    q.execute('RESET ROLE');assert scalar("SELECT inventory->0->>'qty' FROM personnages_donnees WHERE name='Alice'")=='10'
    assert scalar("SELECT batiment_etat_lire(data)->'imprimerie'->>'caisse' FROM batiments_etat")=='100'
    assert scalar("SELECT count(*) FROM hg_fin_requetes WHERE requete='00000000-0000-0000-0000-000000000203'")==0
    q.execute('DROP TRIGGER fixture_bois_fail ON personnages_donnees')
    ok('bois : panne au credit apres caisse et retrait inventaire annule toutes les contreparties')
    auth()
    try:vendre(1.5,204)
    except psycopg2.Error:pass
    else:raise AssertionError('quantite bois fractionnaire acceptee')
    q.execute('RESET ROLE');q.execute("UPDATE personnages_donnees SET current_room='redaction' WHERE name='Alice'");auth()
    try:vendre(1,204)
    except psycopg2.Error as e:assert e.pgcode=='42501'
    else:raise AssertionError('vente bois hors atelier')
    q.execute('RESET ROLE');ok('bois : quantites entieres et presence reelle obligatoire')
    print(f'{groups}/{groups} groupes PostgreSQL reussis')
    cn.close()
    server.cleanup()
