#!/usr/bin/env python3
"""#110 : banque transactionnelle en PostgreSQL jetable, sans Supabase ni joueur reel."""
from pathlib import Path
import tempfile,re
import pgserver,psycopg2
R=Path(__file__).resolve().parents[2]
sql=(R/'migrations/20261023000000_fontaine_exclusivite_sur_place.sql').read_text()
assert "1c5e04f8c73e2ddb64f0b14686b4a931" in sql
assert "a2fa09c304ac4090945db10959719b48" in sql
# Sur ce moteur de test, seuls les deux corps fictifs remplacent les deux corps
# vivants; le garde d'empreintes est verifie statiquement puis retire pour
# executer la migration reelle sur ces deux fonctions fictives.
sql=re.sub(r"DO [\s\S]*?moteur_commerce_non_examine[\s\S]*?END \$g\$;", "",sql,count=1)
assert "moteur_commerce_non_examine" not in sql
server=pgserver.get_server(tempfile.mkdtemp(prefix='hg-fontaine-110-'),cleanup_mode='delete')
conn=psycopg2.connect(server.get_uri());conn.autocommit=True;c=conn.cursor()
n=0
def test(condition,message):
 global n
 assert condition,message
 n+=1
 print('OK',message)
try:
 c.execute("CREATE ROLE anon; CREATE ROLE authenticated; CREATE TABLE public.entreprises(id text primary key,data jsonb);"
           "CREATE TABLE public.ventes_snapshots(requete text primary key, reference text, quantite integer);")
 c.execute("""CREATE FUNCTION public.acheter_produit_commerce(p_requete text,p_acheteur text,p_fonds_id text,p_reference_id text,p_quantite integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $f$
 BEGIN
 IF EXISTS(SELECT 1 FROM ventes_snapshots WHERE requete=p_requete) THEN
 RETURN jsonb_build_object('ok',true,'rejeu',true); END IF;
 INSERT INTO ventes_snapshots VALUES(p_requete,p_reference_id,p_quantite);
 RETURN jsonb_build_object('ok',true,'rejeu',false);END $f$;
 CREATE FUNCTION public.consommer_sur_place_commerce(p_requete text,p_acheteur text,p_fonds_id text,p_reference_id text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $f$
 DECLARE achat jsonb; BEGIN
 achat:=public.acheter_produit_commerce(p_requete,p_acheteur,p_fonds_id,p_reference_id,1);
 RETURN achat;END $f$;
 GRANT EXECUTE ON FUNCTION public.acheter_produit_commerce(text,text,text,text,integer) TO authenticated;
 GRANT EXECUTE ON FUNCTION public.consommer_sur_place_commerce(text,text,text,text) TO authenticated;""")
 c.execute("INSERT INTO entreprises VALUES('fonds',%s::jsonb)",('{"references":{"fontaine":{"venteSurPlaceUniquement":true},"boisson":{}}}',))
 c.execute(sql)
 c.execute("SELECT has_function_privilege('authenticated','public.acheter_produit_commerce_interne(text,text,text,text,integer)','EXECUTE'),"
           "has_function_privilege('anon','public.acheter_produit_commerce_interne(text,text,text,text,integer)','EXECUTE')")
 test(c.fetchone()==(False,False),'coeur transactionnel inaccessible aux roles joueurs')
 c.execute("SET ROLE authenticated")
 c.execute("SELECT public.acheter_produit_commerce('vente-1','Acheteur','fonds','fontaine',1)")
 test(c.fetchone()[0]=={'ok':False,'raison':'consommation_sur_place_uniquement'},'fontaine refusee a emporter')
 c.execute('RESET ROLE')
 c.execute("SELECT count(*) FROM ventes_snapshots")
 test(c.fetchone()[0]==0,'achat refuse sans trace financiere')
 c.execute('SET ROLE authenticated')
 c.execute("SELECT public.consommer_sur_place_commerce('vente-2','Acheteur','fonds','fontaine')")
 test(c.fetchone()[0]['ok'] is True,'fontaine acceptee sur place')
 c.execute("SELECT public.consommer_sur_place_commerce('vente-2','Acheteur','fonds','fontaine')")
 test(c.fetchone()[0]['rejeu'] is True,'rejeu sur place idempotent')
 c.execute("SELECT public.acheter_produit_commerce('vente-3','Acheteur','fonds','boisson',1)")
 test(c.fetchone()[0]['ok'] is True,'produit ordinaire vendu a emporter')
 c.execute('RESET ROLE')
 c.execute("SELECT count(*) FROM ventes_snapshots")
 test(c.fetchone()[0]==2,'une preuve par achat effectue')
 c.execute('SET ROLE authenticated')
 try:
  c.execute("SELECT public.acheter_produit_commerce_interne('vente-4','Acheteur','fonds','fontaine',1)")
  raise AssertionError('coeur prive accessible')
 except psycopg2.errors.InsufficientPrivilege:
  test(True,'appel direct au coeur refuse')
 c.execute("RESET ROLE")
 print(f'{n}/{n} assertions, zero donnees de production')
finally:
 conn.close();server.cleanup()
