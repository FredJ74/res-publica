#!/usr/bin/env python3
"""PostgreSQL jetable exclusivement : vrais moteurs, banque/fiscalite/auth de fixture."""
import argparse,importlib.util,re,tempfile,json
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
ROOT=Path(__file__).resolve().parents[2]
PARENT=ROOT/'migrations/20261019213444_catalogue_et_offrir_a_boire.sql'
MIGRATION=ROOT/'migrations/20261019221500_luthecia_cartes_et_diners.sql'
def definition(nom,f):
 s=f.read_text();a=s.index('CREATE OR REPLACE FUNCTION public.'+nom+'(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',s[a:],re.S);return s[a:a+m.end()]
def table(nom,f):
 s=f.read_text();a=s.index('CREATE TABLE public.'+nom+' (');b=s.index('\n);',a)+3;return s[a:b]
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--local-jetable',action='store_true',required=True);p.add_argument('--correctif-reservation',action='store_true');args=p.parse_args()
 import pgserver,psycopg2
 spec=importlib.util.spec_from_file_location('boire_fixture',ROOT/'outils/bancs/banc-offrir-boire-local.py');fixture=importlib.util.module_from_spec(spec);spec.loader.exec_module(fixture)
 schema=re.sub(r'CREATE TABLE recettes_commerce\([^;]+;',table('recettes_commerce',ROOT/'baseline/domaines/economie/10_tables.sql'),fixture.SCHEMA)
 schema=re.sub(r"INSERT INTO recettes_commerce VALUES[^;]+;",'',schema)
 server=pgserver.get_server(tempfile.mkdtemp(prefix='hg-restaurant-'),cleanup_mode='delete');uri=server.get_uri();db=psycopg2.connect(uri);db.autocommit=True;c=db.cursor();c.execute(schema)
 c.execute("ALTER TABLE personnages_donnees ADD COLUMN bonus_pa_differe integer DEFAULT 0; ALTER TABLE personnages_donnees ADD COLUMN employes jsonb DEFAULT '[]'; ALTER TABLE personnages_donnees ADD COLUMN escort_active jsonb DEFAULT '[]'")
 if args.correctif_reservation:
  c.execute("ALTER TABLE personnages_donnees ADD COLUMN reservation_hotel jsonb; CREATE TABLE pa_bonus_hotel(building_id text PRIMARY KEY,montant integer); INSERT INTO pa_bonus_hotel VALUES('hotel-republica',2)")
 for t,f in [('tournees','personnage-et-presence'),('invitations_diner','personnage-et-presence'),('pnj_membres','socle-PNJ'),('pa_bonus_differes','finances-publiques')]:c.execute(table(t,ROOT/('baseline/domaines/'+f+'/10_tables.sql')))
 c.execute('ALTER TABLE tournees ADD PRIMARY KEY(id); ALTER TABLE invitations_diner ADD PRIMARY KEY(id)')
 # Projection reelle des identites de couverture ; seules les tables annexes sont minimales.
 c.execute("CREATE TABLE agents_renseignement(id text,nom_couverture text,role text,pays_couverture text,cellule_id text,leader_courant text,statut text); CREATE TABLE cellules_renseignement(id text,statut text); CREATE FUNCTION agent_portrait_chemin(text,text) RETURNS text LANGUAGE sql AS $$ SELECT NULL::text $$")
 c.execute(definition('agents_couverture_de_mon_groupe',ROOT/'baseline/domaines/renseignement/20_fonctions.sql'))

 for n,f in [('commerce_produire','baseline/domaines/economie/20_fonctions-1.sql'),('commerce_vendre_produit','baseline/domaines/economie/20_fonctions-1.sql'),('fonds_reference_produire_lots','migrations/20261018231225_assemblage_composants_stocks_reels.sql'),('tournee_cloturer','baseline/domaines/personnage-et-presence/20_fonctions.sql'),('commerce_cout_revient_portion','baseline/domaines/economie/20_fonctions-1.sql')]:c.execute(definition(n,ROOT/f))
 c.execute(PARENT.read_text())
 c.execute("INSERT INTO entreprises_constantes VALUES('cout_main_oeuvre_pa_alimentaire',50),('stock_max_commerce',20); INSERT INTO pa_bonus_differes VALUES('diner_affaires',3)")
 # Recettes reelles du baseline, sans modifier les fichiers generes.
 seeds=(ROOT/'baseline/seeds/92_mixte/recettes_commerce.sql').read_text()
 ids=['vin','cafe_boisson','biere_pression','snack_buvette','menu_gastronomique_1','menu_gastronomique_2','menu_gastronomique_3','menu_psm_1']
 for id in ids:
  ligne=next(l for l in seeds.splitlines() if l.startswith('INSERT INTO') and "VALUES ('"+id+"'," in l);c.execute(ligne)
 c.execute("CREATE FUNCTION matiere_refus_circuit_legal_lot(text,jsonb,text) RETURNS jsonb LANGUAGE sql AS $$ SELECT NULL::jsonb $$")
 # Vrai moteur de vente, paiement de fixture avec refus/panne apres mutation pour eprouver rollback.
 c.execute("""CREATE OR REPLACE FUNCTION payer_ordre(text,text,integer,integer) RETURNS jsonb LANGUAGE plpgsql AS $$ BEGIN
 UPDATE personnages_donnees SET pa=pa-$3,liquide=liquide-$4,arg=arg-$4 WHERE name=$1 AND pa>=$3 AND liquide>=$4;
 IF NOT FOUND THEN RETURN '{"ok":false,"raison":"fonds_ou_pa_insuffisants"}'; END IF;
 IF (SELECT erreur FROM reglages) THEN RAISE EXCEPTION 'panne_paiement_fixture'; END IF;
 IF (SELECT refus FROM reglages) THEN RETURN '{"ok":false,"raison":"debit_refuse_fixture"}'; END IF;
 RETURN '{"ok":true}'; END $$""")
 n=0
 def check(v,msg):
  nonlocal n;n+=1;assert v,msg
 def q(sql,args=()):c.execute(sql,args);return c.fetchone()[0]
 def acteur(nom='Alice'):q("SELECT set_config('test.acteur',%s,false)",(nom,))
 base={'type':'brasserie','country':'republic','city':'capitale','buildingId':'hotel-republica','roomId':None,'proprietaire':'Alice','caisse':5000,'carte':ids[:-1], 'stockProduits':{'menu_gastronomique_1':5,'menu_gastronomique_2':5,'menu_gastronomique_3':5,'vin':8,'snack_buvette':7},'stockMatieres':{'fruits_legumes':40,'poisson':40,'viande':40,'cereales':40,'produits_exotiques':40},'coutMoyenMatieres':{'fruits_legumes':4,'poisson':4,'viande':5,'cereales':3,'produits_exotiques':6},'parametres':{'prixVente':dict.fromkeys(ids[:-1],77),'stockMax':dict.fromkeys(ids[:-1],20)},'historique':[]}
 c.execute('INSERT INTO entreprises VALUES(%s,%s,now())',('restaurant',json.dumps(base)))
 c.execute("INSERT INTO entreprises VALUES('autre','{\"type\":\"brasserie\",\"country\":\"republic\",\"city\":\"ville_a\",\"buildingId\":\"capitaine-sauvage\",\"carte\":[]}',now())")
 ancien=q("SELECT data FROM entreprises WHERE id='autre'");avant=q("SELECT data FROM entreprises WHERE id='restaurant'")
 c.execute(MIGRATION.read_text());premier=q("SELECT data FROM entreprises WHERE id='restaurant'");c.execute(MIGRATION.read_text());check(q("SELECT data FROM entreprises WHERE id='restaurant'")==premier,'migration rejouee sans reinitialisation');check(q("SELECT data FROM entreprises WHERE id='autre'")==ancien,'autre commerce intact')
 if args.correctif_reservation:c.execute((ROOT/'migrations/20261020114246_reservation_republica_accueil.sql').read_text())
 check(premier['stockProduits']['snack_buvette']==7 and premier['stockProduits']['vin']==8,'stocks historiques conserves');check(premier['caisse']==avant['caisse'],'caisse non dupliquee');check(premier['stockProduits']['champagne_luthecia']==0,'aucune boisson fictive');check(not any(x.startswith('menu_') for x in premier['cartesParPiece']['bar']),'aucun repas au bar');check('snack_buvette' in premier['cartesParPiece']['bar'] and 'snack_buvette' not in premier['cartesParPiece']['restaurant'],'cacahuetes uniquement bar');check('amuse_bouche_luthecia' in premier['cartesParPiece']['restaurant'],'amuse bouche');check('cocktail_luthecia' not in premier['cartesParPiece']['restaurant'],'pas cocktail restaurant');check(q("SELECT pa FROM recettes_commerce WHERE id='menu_psm_1'")==1,'autre restaurant PA intact')
 def reset():
  c.execute('DELETE FROM invitations_diner; DELETE FROM personnages_donnees; DELETE FROM taxes; UPDATE reglages SET refus=false,erreur=false')
  d=json.loads(json.dumps(premier));d['stockProduits']['champagne_luthecia']=10;d['stockProduits']['cocktail_luthecia']=10;c.execute("UPDATE entreprises SET data=%s WHERE id='restaurant'",(json.dumps(d),))
  for nom in ['Alice','Bob','Claire']:c.execute("INSERT INTO personnages_donnees(name,country,current_city,current_building,current_room,arg,liquide,pa,hp,moral,resources,stats,day,bonus_pa_differe) VALUES(%s,'republic','capitale','hotel-republica','restaurant',1000,1000,20,50,50,'{\"inf\":5}','{\"ENT\":5}',1,0)",(nom,))
  acteur()
 def creer(req='diner-test-000001',invite='Bob',pnj=False):return q('SELECT restaurant_diner_creer(%s,%s,%s,%s)',(req,invite,pnj,'Message'))
 def accepter(id,oui=True):
  acteur('Bob');v=q('SELECT restaurant_diner_repondre(%s,%s,%s)',(id,oui,'Reponse'));acteur();return v
 def servir(id):return q('SELECT restaurant_diner_servir(%s)',(id,))
 reset();id=creer()['id'];check(creer().get('rejeu'),'creation idempotente');check(not creer(invite='Claire')['ok'],'cle liee a intention');check(servir(id)['raison']=='acceptation_requise','pas de service sans acceptation');check(accepter(id)['ok'],'acceptation');check(accepter(id).get('rejeu'),'double acceptation');check(not accepter(id,False)['ok'],'pas de changement de reponse')
 r=servir(id);check(r['ok'] and r['repas']==2 and r['champagnes']==2 and r['total']==300,'composition exacte');check(servir(id).get('rejeu'),'rejeu service');check(q("SELECT liquide FROM personnages_donnees WHERE name='Alice'")==700,'un debit');check(q("SELECT pa FROM personnages_donnees WHERE name='Alice'")==18,'deux PA');check(q("SELECT count(*) FROM personnages_donnees WHERE name IN('Alice','Bob') AND hp=60 AND moral=52 AND resources->>'inf'='10' AND bonus_pa_differe=3")==2,'effets deux convives une fois');check(q("SELECT data->'stockProduits'->>'champagne_luthecia' FROM entreprises WHERE id='restaurant'")=='8','deux champagnes consommes');check(q("SELECT data->'stockProduits'->>'menu_gastronomique_1' FROM entreprises WHERE id='restaurant'")=='3','deux repas consommes');check(q('SELECT sum(montant) FROM taxes')==30,'une taxation')
 for champ in ['champagne_luthecia','menu_gastronomique_1']:
  reset();id=creer()['id'];accepter(id)
  stocks={'champagne_luthecia':1,'menu_gastronomique_1':5} if champ=='champagne_luthecia' else {'champagne_luthecia':10,'menu_gastronomique_1':0,'menu_gastronomique_2':0,'menu_gastronomique_3':0}
  for k,v in stocks.items():c.execute("UPDATE entreprises SET data=jsonb_set(data,ARRAY['stockProduits',%s],%s) WHERE id='restaurant'",(k,json.dumps(v)))
  check(not servir(id)['ok'],'stock insuffisant');check(q("SELECT liquide FROM personnages_donnees WHERE name='Alice'")==1000,'pas debit partiel');check(q("SELECT hp FROM personnages_donnees WHERE name='Bob'")==50,'pas effet partiel')
 for condition in ['liquide=0,arg=0','pa=0']:
  reset();id=creer()['id'];accepter(id);c.execute('UPDATE personnages_donnees SET '+condition+" WHERE name='Alice'");check(not servir(id)['ok'],'argent ou PA insuffisants');check(q("SELECT data->'stockProduits'->>'champagne_luthecia' FROM entreprises WHERE id='restaurant'")=='10','stocks intacts si refus')
 reset();id=creer()['id'];accepter(id);c.execute('UPDATE reglages SET refus=true');check(not servir(id)['ok'],'debit refuse apres ecriture');check(q("SELECT liquide FROM personnages_donnees WHERE name='Alice'")==1000 and q("SELECT pa FROM personnages_donnees WHERE name='Alice'")==20,'rollback paiement partiellement refuse')
 reset();id=creer()['id'];accepter(id);c.execute('UPDATE reglages SET erreur=true')
 try:servir(id);raise AssertionError('panne attendue')
 except psycopg2.Error:pass
 check(q("SELECT liquide FROM personnages_donnees WHERE name='Alice'")==1000,'panne rollback');c.execute('UPDATE reglages SET erreur=false');check(servir(id)['ok'],'reprise apres panne')
 reset();id=creer()['id'];accepter(id);c.execute("UPDATE personnages_donnees SET current_room='bar' WHERE name='Bob'");check(servir(id)['raison']=='action_obsolete','invite parti');check(q("SELECT liquide FROM personnages_donnees WHERE name='Alice'")==1000,'aucun debit obsolete')
 reset();id=creer()['id'];accepter(id)
 def concurrent(_):
  d=psycopg2.connect(uri);d.autocommit=True;cc=d.cursor();cc.execute("SELECT set_config('test.acteur','Alice',false)");cc.execute('SELECT restaurant_diner_servir(%s)',(id,));r=cc.fetchone()[0];d.close();return r
 with ThreadPoolExecutor(2) as pool:rs=list(pool.map(concurrent,range(2)))
 check(all(x['ok'] for x in rs) and sum(bool(x.get('rejeu')) for x in rs)==1,'concurrence un service');check(q("SELECT liquide FROM personnages_donnees WHERE name='Alice'")==700,'un debit concurrent')
 reset();c.execute("UPDATE personnages_donnees SET current_room='bar' WHERE name='Alice'")
 v=q("SELECT commerce_vendre_produit('Alice','restaurant','[{\"produit\":\"menu_gastronomique_1\",\"qte\":1}]')");check(not v['ok'],'appel direct repas depuis bar refuse');v=q("SELECT commerce_produire('Alice','restaurant','menu_gastronomique_1',NULL)");check(not v['ok'],'production menu depuis bar refuse')
 for recette in ['champagne_luthecia','cocktail_luthecia']:
  reset();c.execute("UPDATE personnages_donnees SET current_room='bar' WHERE name='Alice'");v=q('SELECT commerce_produire(%s,%s,%s,NULL)',('Alice','restaurant',recette));check(v['ok'] and v['paPreleves']==2 and v['portions']==9,'lot boisson premium');check(q("SELECT data->'stockProduits'->>%s FROM entreprises WHERE id='restaurant'",(recette,))=='19','neuf verres reels');check(q("SELECT data->'stockMatieres'->>'fruits_legumes' FROM entreprises WHERE id='restaurant'")=='38','double matieres')
 reset();c.execute("UPDATE entreprises SET data=jsonb_set(jsonb_set(data,'{proprietaire}','\"PNJ\"'),'{salaries}','[{\"ref\":\"pj:Alice\",\"actif\":true}]') WHERE id='restaurant'");c.execute("UPDATE personnages_donnees SET current_room='bar' WHERE name='Alice'");v=q("SELECT commerce_produire('Alice','restaurant','champagne_luthecia',NULL)");check(v['ok'] and v['prixVente']==25,'marge minimum x2 autorise 25');c.execute("UPDATE entreprises SET data=jsonb_set(data,'{coutMoyenMatieres,fruits_legumes}','20') WHERE id='restaurant'");avant=q("SELECT data FROM entreprises WHERE id='restaurant'");v=q("SELECT commerce_produire('Alice','restaurant','champagne_luthecia',NULL)");check(v['raison']=='marge_pnj_insuffisante','hausse cout ne contourne pas marge');check(q("SELECT data FROM entreprises WHERE id='restaurant'")==avant,'refus marge aucun effet')
 reset();avant=q("SELECT data->'stockMatieres' FROM entreprises WHERE id='restaurant'");v=q("SELECT commerce_produire('Alice','restaurant','menu_gastronomique_1',NULL)");check(v['ok'] and v['paPreleves']==3 and v['prixVente']==125,'menu trois PA et 125');apres=q("SELECT data->'stockMatieres' FROM entreprises WHERE id='restaurant'");check(avant['poisson']-apres['poisson']==1 and avant['viande']-apres['viande']==1,'matieres menu non triplees')
 reset();id=creer()['id'];accepter(id,False);check(not servir(id)['ok'],'refus pas facture');check(q("SELECT liquide FROM personnages_donnees WHERE name='Alice'")==1000,'refus fonds intacts');acteur('Claire');check(not q('SELECT restaurant_diner_servir(%s)',(id,))['ok'],'tiers refuse');acteur('');check(not creer()['ok'],'session refusee')
 # Les memes boissons passent par la tournee existante, uniquement au bar.
 reset();c.execute("UPDATE personnages_donnees SET current_room='bar' WHERE name IN('Alice','Bob')");v=q("SELECT tournee_creer('tournee-restaurant-00001','restaurant','champagne_luthecia',ARRAY['Bob'])");check(v['ok'],'champagne en tournee');acteur('Bob');q("SELECT tournee_repondre((SELECT id FROM invitations_diner WHERE tournee_id='tournee-restaurant-00001'),true)");acteur();v=q("SELECT tournee_cloturer('tournee-restaurant-00001',true)");check(v['ok'] and v['total']==50,'tarif tournee inchange');check(q("SELECT hp FROM personnages_donnees WHERE name='Bob'")==55,'bonus tournee inchange');c.execute("DELETE FROM tournees")
 reset();check(not q("SELECT tournee_creer('tournee-restaurant-00002','restaurant','cocktail_luthecia',ARRAY['Bob'])")['ok'],'cocktail tournee interdit depuis restaurant')
 # Prix individuels et recette ordinaire restent reels.
 reset();v=q("SELECT commerce_vendre_produit('Alice','restaurant','[{\"produit\":\"champagne_luthecia\",\"qte\":1}]')");check(v['ok'] and v['total']==25,'champagne individuel restaurant 25');v=q("SELECT commerce_vendre_produit('Alice','restaurant','[{\"produit\":\"cocktail_luthecia\",\"qte\":1}]')");check(not v['ok'],'cocktail individuel interdit au restaurant');v=q("SELECT commerce_vendre_produit('Alice','restaurant','[{\"produit\":\"menu_gastronomique_1\",\"qte\":1}]')");check(v['ok'] and v['total']==125,'menu individuel 125')
 reset();c.execute("UPDATE entreprises SET data=jsonb_set(jsonb_set(jsonb_set(data,'{proprietaire}','\"PNJ\"'),'{salaries}','[{\"ref\":\"pj:Alice\",\"actif\":true}]'),'{stockProduits,vin}','0') WHERE id='restaurant'");v=q("SELECT commerce_produire('Alice','restaurant','menu_gastronomique_1',NULL)");check(v['ok'] and v['prixVente']==125,'exception PNJ gastronomique seulement');v=q("SELECT commerce_produire('Alice','restaurant','vin',NULL)");check(v['ok'] and v['prixVente']==7,'prix automatique vin ordinaire preserve')
 # Deux actes distincts avec 300 FR disponibles : un seul service, aucun demi-debit.
 reset();id1=creer()['id'];id2=creer('diner-test-000002')['id'];accepter(id1);accepter(id2);c.execute("UPDATE personnages_donnees SET liquide=300,arg=300 WHERE name='Alice'")
 def autres(id):
  d=psycopg2.connect(uri);d.autocommit=True;cc=d.cursor();cc.execute("SELECT set_config('test.acteur','Alice',false)");cc.execute('SELECT restaurant_diner_servir(%s)',(id,));v=cc.fetchone()[0];d.close();return v
 with ThreadPoolExecutor(2) as pool:rs=list(pool.map(autres,[id1,id2]))
 check(sum(bool(v['ok']) for v in rs)==1,'deux actes concurrence fonds');check(q("SELECT liquide FROM personnages_donnees WHERE name='Alice'")==0,'aucun decouvert');check(q("SELECT hp FROM personnages_donnees WHERE name='Bob'")==60,'un seul bonus sur les deux actes')
 # Probabilites PNJ existantes : neutre 60, ennemi 20, groupe 95. Tirage serveur, recu stable.
 reset();check(q("SELECT restaurant_luthecia_pnj_chance('Alice','Gaston Sauceblanche')")==60,'PNJ neutre 60');check(q("SELECT restaurant_luthecia_pnj_chance('Alice','Marie Leblanc')")==20,'PNJ ennemi 20');c.execute("UPDATE personnages_donnees SET employes='[{\"nom\":\"Temoin PNJ\",\"inGroupe\":true}]' WHERE name='Alice'");check(q("SELECT restaurant_luthecia_pnj_chance('Alice','Temoin PNJ')")==95,'groupe 95');check(not creer(invite='Inconnu',pnj=True)['ok'],'PNJ inexistant refuse')
 seed=None
 for candidat in [x/100 for x in range(-99,100)]:
  q('SELECT setseed(%s)',(candidat,));u=q('SELECT random()')
  if u<0.19:seed=candidat;break
 assert seed is not None
 q('SELECT setseed(%s)',(seed,));v=creer(invite='Gaston Sauceblanche',pnj=True);check(v['statut']=='acceptee','tirage PNJ accepte');check(creer(invite='Gaston Sauceblanche',pnj=True)['statut']==v['statut'],'PNJ ne retire pas au rejeu');check(servir(v['id'])['ok'],'diner PNJ');check(q("SELECT hp FROM personnages_donnees WHERE name='Alice'")==60,'bonus organisateur PNJ');check(q("SELECT hp FROM personnages_donnees WHERE name='Bob'")==50,'aucun tiers credite')
 reset();c.execute("UPDATE personnages_donnees SET employes='[{\"nom\":\"Temoin PNJ\",\"inGroupe\":true}]' WHERE name='Alice'");q('SELECT setseed(%s)',(seed,));v=creer(invite='Temoin PNJ',pnj=True);check(v['statut']=='acceptee','groupe accepte');c.execute("UPDATE personnages_donnees SET employes='[]' WHERE name='Alice'");check(servir(v['id'])['raison']=='action_obsolete','groupe parti refuse sans debit')
 # Agent porte : meme source d'autorite que le groupe client, nom de couverture seulement.
 reset();c.execute("INSERT INTO cellules_renseignement VALUES('cellule','active'); INSERT INTO agents_renseignement VALUES('agent','Couverture Test','analyste','republic','cellule','Alice','actif')")
 check(q("SELECT restaurant_luthecia_pnj_chance('Alice','Couverture Test')")==95,'agent porte reconnu par projection serveur')
 acteur('Bob');check(q("SELECT restaurant_luthecia_pnj_chance('Bob','Couverture Test')") is None,'agent pas dans groupe tiers');acteur()
 c.execute("UPDATE cellules_renseignement SET statut='inactive'");check(q("SELECT restaurant_luthecia_pnj_chance('Alice','Couverture Test')") is None,'agent cellule inactive absent')
 # Lecture et acquittement ne declenchent pas de nouvel acte.
 reset();id=creer()['id'];accepter(id);servir(id);acteur('Bob');check(len(q('SELECT restaurant_diner_suivre()')['invitations'])==1,'invite retrouve resultat apres rechargement');check(q('SELECT restaurant_diner_acquitter(%s)',(id,))['ok'],'acquittement propre');check(q('SELECT restaurant_diner_acquitter(%s)',(id,)).get('rejeu'),'double acquittement');check(len(q('SELECT restaurant_diner_suivre()')['invitations'])==0,'pas de notification recurrente');acteur()
 # Les refus observes doivent venir du garde de cette migration, pas d'un privilege absent de fixture.
 c.execute('GRANT SELECT,UPDATE,DELETE ON invitations_diner TO authenticated');c.execute('SET ROLE authenticated')
 try:c.execute('UPDATE invitations_diner SET resultat_service=NULL');raise AssertionError('recu falsifie')
 except psycopg2.Error:pass
 c.execute('RESET ROLE');check(q('SELECT resultat_service FROM invitations_diner WHERE id=%s',(id,))['ok'],'recu non falsifiable')
 # Provisionnement futur et unicite de l entreprise, sans remettre de stocks fictifs.
 c.execute("DELETE FROM entreprises WHERE id='restaurant'");d=json.loads(json.dumps(base));d['stockProduits']={};c.execute("INSERT INTO entreprises VALUES('nouveau',%s,now())",(json.dumps(d),));nouveau=q("SELECT data FROM entreprises WHERE id='nouveau'");check(nouveau['versionGastronomieLuthecia']==1 and nouveau['stockProduits']['champagne_luthecia']==0,'creation future configuree sans credit');check(nouveau['parametres']['prixVente']['amuse_bouche_luthecia']==77,'prix ancien snack preserve')
 # Une fonction deja presente mais inconnue ne doit jamais etre ecrasee au rejeu.
 c.execute("CREATE OR REPLACE FUNCTION restaurant_luthecia_est_commerce(d jsonb) RETURNS boolean LANGUAGE sql IMMUTABLE AS $$ SELECT false $$")
 avant=q("SELECT data FROM entreprises WHERE id='nouveau'")
 try:c.execute(MIGRATION.read_text());raise AssertionError('definition inconnue ecrasee')
 except psycopg2.Error as e:
  c.execute('ROLLBACK');check('fonction_restaurant_preexistante_differente' in str(e),'definition inconnue refusee explicitement')
 check(q("SELECT data FROM entreprises WHERE id='nouveau'")==avant,'prevol refuse avant toute mutation')
 c.execute(definition('restaurant_luthecia_est_commerce',MIGRATION))
 print(f'{n}/{n} assertions PostgreSQL locales reussies. Banque/auth/fiscalite de fixture, pas Supabase.')
 db.close()
if __name__=='__main__':main()
