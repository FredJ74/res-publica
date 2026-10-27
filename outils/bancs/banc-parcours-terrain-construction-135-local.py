#!/usr/bin/env python3
"""Même base jetable : acquisition, permis, appels de fonds, travaux et réception.
Réutilise les corps et migrations existants, aucun accès Supabase ni joueur réel.
"""
from pathlib import Path
import importlib.util,re,json,uuid,subprocess,sys
from concurrent.futures import ThreadPoolExecutor
R=Path(__file__).resolve().parents[2]
MUTANT=next((x.split('=',1)[1] for x in sys.argv if x.startswith('--mutant=')),None)
sys.argv[:]=[x for x in sys.argv if not x.startswith('--mutant=')]
spec=importlib.util.spec_from_file_location('banque',R/'outils/bancs/banc-terrain-banque-135-local.py');banque=importlib.util.module_from_spec(spec);spec.loader.exec_module(banque)
def suite(db,q,srv):
 import psycopg2
 from psycopg2.extras import Json
 n=0
 def check(v,msg):
  nonlocal n
  assert v,msg;n+=1;print('OK parcours terrain',msg,flush=True)
 def lire(sql,args=()):q.execute(sql,args);return q.fetchone()[0]
 def fn(path,nom):
  s=(R/path).read_text();a=s.index('CREATE OR REPLACE FUNCTION public.'+nom+'(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',s[a:],re.S);return s[a:a+m.end()]
 def table(domaine,nom,pk=None):
  if lire('SELECT to_regclass(%s)',('public.'+nom,)):return
  s=(R/f'baseline/domaines/{domaine}/10_tables.sql').read_text();q.execute(re.search(r'CREATE TABLE public\.'+nom+r' \(.*?\n\);',s,re.S)[0])
  if pk:q.execute(f'ALTER TABLE {nom} ADD PRIMARY KEY({pk})')
 q.execute('ALTER TABLE personnages_donnees ADD COLUMN poste jsonb,ADD COLUMN user_id uuid;UPDATE personnages_donnees SET user_id=id;ALTER TABLE terrains_etat ADD COLUMN niveau_construction text')
 for d,t,p in [('immobilier-et-territoire','villes',None),('finances-publiques','caisses_batiments','id'),('finances-publiques','caisses_autorites',None),('finances-publiques','caisses_mouvements_clients',None),('politique-et-elections','cycles_electoraux',None),('immobilier-et-territoire','batiments_etat','id'),('economie','chantiers_besoins_jour',None),('economie','entrepots_par_ville',None),('economie','ressources_economie','cle'),('economie','entreprises_constantes','cle'),('economie','chantiers_paliers','palier'),('immobilier-et-territoire','locations_actives','id')]:table(d,t,p)
 q.execute("INSERT INTO villes VALUES('republic','capitale','Luthécia',true,1)")
 for t in ['caisses_autorites','chantiers_besoins_jour','entreprises_constantes','chantiers_paliers']:q.execute((R/f'baseline/seeds/90_socle/{t}.sql').read_text())
 q.execute((R/'baseline/seeds/92_mixte/entrepots_par_ville.sql').read_text())
 tarifs=json.loads(subprocess.check_output(['node','-e',"const fs=require('fs'),vm=require('vm'),c=vm.createContext({window:{},console});vm.runInContext(fs.readFileSync('data.js','utf8'),c);console.log(vm.runInContext('JSON.stringify(RESSOURCES_ECONOMIE)',c))"],cwd=R,text=True))
 for cle in ['bois','minerai','metal']:q.execute('INSERT INTO ressources_economie(cle,prix_base) VALUES(%s,%s)',(cle,tarifs[cle]['prixBase']))
 for f,nom in [('baseline/domaines/socle/20_fonctions.sql','acteur_poste_courant'),('baseline/domaines/socle/20_fonctions.sql','exiger_poste'),('baseline/domaines/finances-publiques/20_fonctions-1.sql','caisse_institution_mouvement'),('baseline/domaines/immobilier-et-territoire/20_fonctions.sql','batiment_etat_lire'),('baseline/domaines/economie/20_fonctions-1.sql','entrepot_caisse_id'),('baseline/domaines/economie/20_fonctions-1.sql','entrepot_caisse_mouvement'),('baseline/domaines/economie/20_fonctions-1.sql','approvisionner_chantier'),('migrations/20261019064000_organisations_equipements_collectifs.sql','organisation_equipement_exiger'),('baseline/domaines/politique-et-elections/20_fonctions.sql','poste_est_atteste')]:q.execute(fn(f,nom))
 for nom in ['chantier_lancer','chantier_verser','chantier_travailler']:q.execute(fn('baseline/domaines/economie/20_fonctions-1.sql',nom))
 q.execute(fn('outils/bancs/banc-fixture-terrain-chantier-acte-avant-commandes.sql','terrain_chantier_acte'))
 migrations=['20261022123319_chantier_financeurs_et_appels.sql','20261022123320_chantier_jour_transactionnel.sql','20261022123321_chantier_approvisionnement_caisse_unique.sql','20261022124055_chantier_autorite_et_recus.sql','20261022124056_chantier_commandes_et_reception.sql','20261022125121_chantier_recu_relecture.sql','20261022125728_chantier_fermer_commandes_non_versionnees.sql','20261022125942_chantier_plan_initial.sql','20261022125943_chantier_plan_raccordement.sql','20261022130417_chantier_gardes_legacy_et_travail.sql','20261022143001_construction_delais_quatre_empires.sql','20261025070000_chantier_taux_horaire.sql']
 for nom in migrations:q.execute((R/'migrations'/nom).read_text());q.execute((R/'migrations'/nom).read_text())
 if '--vol135' in sys.argv:
  spec_vol=importlib.util.spec_from_file_location('vol135',R/'outils/bancs/banc-vigiles-vol-135-local.py')
  module_vol=importlib.util.module_from_spec(spec_vol);spec_vol.loader.exec_module(module_vol)
  module_vol.installer_sur_parcours(q)
 if MUTANT:
  nom,avant,apres={
   'jour_rejoue':('chantier_jour_traiter(text)',"IF ch->>'jourTraite'=jour THEN",'IF false THEN'),
   'prix_uniformises':('terrain_acquisition_commande(text,text,jsonb,uuid)',"surface:=coalesce((e->>'surface')::numeric,fiche.surface);prix:=coalesce((e->>'valeur_totale')::numeric,fiche.prix_achat);",'surface:=2150;prix:=25800;'),
   'tranche_modifiee':('chantier_appel_fonds_interne(jsonb,jsonb)','THEN .70 ELSE','THEN .75 ELSE')
  }[MUTANT]
  d=lire('SELECT pg_get_functiondef(%s::regprocedure)',('public.'+nom,));assert d.count(avant)==1;q.execute(d.replace(avant,apres))
 q.execute("INSERT INTO personnages_donnees(name,country,current_city,current_building,stats,hp,pa,liquide,arg,day,user_id) VALUES('Parcours terrain fixture','republic','capitale','terrain-a-batir-2','{\"CHA\":13}',100,100,1000000,2000000,1,NULL);UPDATE personnages_donnees SET user_id=id WHERE name='Parcours terrain fixture';INSERT INTO comptes_bancaires(id,personnage,banque,solde) VALUES('parcours','Parcours terrain fixture','nationale',1000000);SET hg.acteur='Parcours terrain fixture';SET hg.serveur='on'")
 q.execute("INSERT INTO caisses_batiments(id,data) VALUES('republic_gouvernement-min_fin','{\"solde\":0}'),('republic_entrepot_capitale','{\"solde\":0}');INSERT INTO batiments_etat(id,country,city,building_id,data) VALUES('republic_capitale_entrepot-logistique-luthecia','republic','capitale','entrepot-logistique-luthecia','{\"entrepot\":{\"stock\":{\"bois\":100000,\"minerai\":100000,\"metal\":100000}}}')")
 parcelles=json.loads(subprocess.check_output(['node',str(R/'outils/generateurs/generer_terrains_occupation.cjs')],cwd=R,text=True))['parcelles']
 def parcours(terrain,palier,occupation=None):
  cle='republic_'+terrain
  q.execute("UPDATE personnages_donnees SET current_building=%s WHERE name='Parcours terrain fixture'",(terrain,))
  capital_initial=lire("SELECT arg FROM personnages_donnees WHERE name='Parcours terrain fixture'")
  q.execute("SELECT surface,prix_achat FROM terrains_referentiel WHERE pays='republic' AND ville='capitale' AND batiment=%s",(terrain,));surface,prix=q.fetchone()
  fiche=next(p for p in parcelles if p['pays']=='republic' and p['ville']=='capitale' and p['id']==terrain)
  check(surface==fiche['surface'] and prix==fiche['prix'],'referentiel SQL conforme aux caracteristiques propres du jeu '+terrain)
  q.execute('SELECT duree_jours,cout_total,apport_minimal FROM chantiers_paliers WHERE palier=%s',(palier,));jours,total,apport=q.fetchone()
  jours,total,apport=int(jours),int(total),int(apport)
  # Seuls les états initiaux de la fixture sont préparés. Les titres et autorisations viennent des commandes.
  q.execute("INSERT INTO terrains_etat(id,country,building_id,data) VALUES(%s,'republic',%s,%s) ON CONFLICT(id) DO UPDATE SET data=excluded.data,proprietaire=NULL,niveau_construction=NULL",(cle,terrain,json.dumps({'city':'capitale','pnj':occupation,'dateGeneration':1})))
  def acquisition(action,params,nonce):return lire('SELECT terrain_acquisition_commande(%s,%s,%s,%s)',(terrain,action,Json(params),nonce))
  def commande(action,params,nonce):return lire('SELECT chantier_commande(%s,%s,%s,%s)',('ch-'+terrain+'-'+nonce,terrain,action,Json(params)))
  def etat():return lire('SELECT data::jsonb FROM terrains_etat WHERE id=%s',(cle,))
  def fonds():return lire("SELECT jsonb_build_array(arg,liquide,(SELECT solde FROM comptes_bancaires WHERE id='parcours')) FROM personnages_donnees WHERE name='Parcours terrain fixture'")
  if occupation:
   avant=fonds();r=acquisition('compromis',{'occupation':'1:'+occupation,'permis':palier},str(uuid.uuid4()))
   check(not r['ok'] and r['raison']=='terrain_occupe' and fonds()==avant,'occupation bloque le compromis sans paiement '+occupation)
   q.execute('CREATE OR REPLACE FUNCTION terrain_negociation_jet_interne() RETURNS integer LANGUAGE sql AS $$SELECT 1$$')
   requete=str(uuid.uuid4());r=lire('SELECT terrain_negociation_conclure(%s,%s,1000,%s)',(terrain,'1:'+occupation,requete))
   check(r['ok'] and r['accepte'] and etat()['pnj'] is None and fonds()[0]==avant[0]-1000,'liberation par le moteur commun de negociation '+occupation)
   avant=fonds();r=lire('SELECT terrain_negociation_conclure(%s,%s,1000,%s)',(terrain,'1:'+occupation,requete))
   check(r.get('rejeu') and fonds()==avant,'reponse perdue de negociation aucun second versement')
   capital_initial=fonds()[0]
  nonce=str(uuid.uuid4());r=acquisition('compromis',{'occupation':'1:','permis':palier},nonce)
  check(r['ok'],'compromis avec permis par la vraie commande acquisition')
  check(etat()['surface']==surface and etat()['valeur_totale']==prix,'superficie et prix propres a '+terrain)
  check(acquisition('compromis',{'occupation':'1:','permis':palier},nonce)['rejeu'],'reprise du compromis sans paiement ni permis supplementaires')
  q.execute("UPDATE personnages_donnees SET current_building='office-notarial' WHERE name='Parcours terrain fixture'")
  avant=fonds();r=acquisition('acte_compromis',{},str(uuid.uuid4()));check(not r['ok'] and fonds()==avant,'clause de permis non satisfaite refuse le titre sans debit')
  # Avance des échéances uniquement dans la base jetable, sans sommeil et sans raccourcir la durée.
  duree=int(etat()['permis']['dureeInstruction'])
  for j in range(duree):
   if j:q.execute("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{permis,jourInstruction}',to_jsonb(((now() AT TIME ZONE 'Europe/Paris')::date-1)::text))::text WHERE id=%s",(cle,))
   r=lire('SELECT terrain_permis_instruction_jour(%s)',(cle,));check(r['ok'],'instruction permis jour commun '+str(j+1))
  check(etat()['constructionAutorisee'],'accord tacite issu de la vraie instruction')
  r=acquisition('acte_compromis',{},str(uuid.uuid4()));check(r['ok'] and etat()['proprietaire']=='Parcours terrain fixture','acte notarial titre obtenu sans mutation fictive')
  check(fonds()[0]==capital_initial-prix,'prix total exact depot impute une fois')
  q.execute("UPDATE personnages_donnees SET current_building=%s WHERE name='Parcours terrain fixture'",(terrain,))
  avant=fonds();nonce='parcours-lancer-135';r=commande('lancer',{'palier':palier,'apport':str(apport)},nonce)
  check(r['ok'] and etat()['chantier']['dureeJours']==jours,'lancement 35 pour cent et delai incompressible '+str(jours))
  check(fonds()[2]==avant[2]-apport and fonds()[1]==avant[1],'lancement prioritairement bancaire sans toucher au liquide')
  apres=fonds();check(commande('lancer',{'palier':palier,'apport':str(apport)},nonce)['rejeu'] and fonds()==apres,'reponse lancement perdue sans second apport')
  r=commande('receptionner',{},'parcours-trop-tot-135');check(not r['ok'],'reception prematuree refusee')
  if '--vol135' in sys.argv:
   # Meme chantier reel : affectation, tentative non destructive sur son stock,
   # puis tous les jours, lots et reception. Identite/horloge de ce banc restent fictives.
   q.execute("UPDATE personnages_donnees SET current_room='terrain' WHERE name='Parcours terrain fixture';INSERT INTO pnj_membres(id,famille,classe,nom,pays,proprietaire_pj,leader_pj,statut,pa) VALUES('vigile-integration135','employe','alpha','Agent integration','republic','Parcours terrain fixture','Parcours terrain fixture','actif',12) ON CONFLICT(id) DO UPDATE SET leader_pj=excluded.leader_pj,ville=NULL,building_id=NULL,room_id=NULL;INSERT INTO pnj_employes_metier(pnj_id,job,role_libelle,candidat_id) VALUES('vigile-integration135','agent_securite','Agent','integration135') ON CONFLICT(pnj_id) DO NOTHING")
   a=lire('SELECT chantier_vigiles_affecter(%s,ARRAY[\'vigile-integration135\'])',(terrain,));check(a['ok'],'affectation commune dans le parcours '+terrain)
   check(lire('SELECT chantier_securite_lire(%s)',(terrain,))['nombre']==1,'presence reelle du vigile dans le parcours '+terrain)
   avant=fonds();avant_ch=etat()['chantier'];r=commande('voler',{'matiere':'bois'},'tentative-vol-135')
   check(r['ok'] and not r['reussite'] and r['vigiles']==1,'vol serveur avec protection dans le parcours '+terrain)
   check(fonds()==avant and etat()['chantier']==avant_ch,'tentative echouee conserve financement et stock '+terrain)
   r=commande('voler',{'matiere':'bois'},'tentative-vol-135');check(r['rejeu'],'reprise du vol sans doublon avant travaux '+terrain)
  for jour in range(jours):
   q.execute("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{chantier,jourTraite}',to_jsonb(((now() AT TIME ZONE 'Europe/Paris')::date-1)::text))::text WHERE id=%s",(cle,))
   r=lire('SELECT chantier_jour_traiter(%s)',(cle,));check(r['ok'] and etat()['chantier']['progressionJours']==jour+1,'jour construction '+str(jour+1))
   ch=etat()['chantier'];attendu=apport if jour+1<jours/3 else total*70//100 if jour+1<jours*2/3 else total
   check(ch['totalVerse']==attendu,'appel de fonds cumul 35 70 100 jour '+str(jour+1))
   avant=fonds();terrain_avant=etat();q.execute("UPDATE personnages_donnees SET day=day+1 WHERE name='Parcours terrain fixture'")
   rejeu=lire('SELECT chantier_jour_traiter(%s)',(cle,));check(rejeu.get('rejeu') and fonds()==avant and etat()==terrain_avant,'rejeu quotidien aucun paiement supplementaire apres jour personnel '+str(jour+1))
  if palier in ('commerce_premium','building'):
   lots=[{'id':'lot-commerce','label':'Commerce','surface':600 if palier=='commerce_premium' else 300,'destination':'commerce'}]
   if palier=='building':lots.append({'id':'lot-logement','label':'Appartement','surface':150,'destination':'appartement'})
   r=commande('plan',{'lots':lots,'valider':True},'plan-initial-135');check(r['ok'],'plan initial valide par le moteur commun')
  def photo():return lire("SELECT jsonb_build_array((SELECT jsonb_agg(t ORDER BY id) FROM terrains_etat t),(SELECT jsonb_agg(c ORDER BY id) FROM caisses_batiments c),(SELECT jsonb_agg(p ORDER BY name) FROM personnages_donnees p),(SELECT jsonb_agg(c ORDER BY id) FROM comptes_bancaires c),(SELECT jsonb_agg(r ORDER BY acteur,requete) FROM chantier_commandes_recus r),(SELECT jsonb_agg(d ORDER BY id) FROM dossiers_urbanisme d),(SELECT jsonb_agg(o ORDER BY id) FROM objets_recus o))")
  q.execute("CREATE OR REPLACE FUNCTION panne_reception_parcours() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_reception_parcours';END$$;CREATE TRIGGER panne_reception_parcours BEFORE INSERT ON chantier_commandes_recus FOR EACH ROW EXECUTE FUNCTION panne_reception_parcours()")
  avant=photo()
  try:commande('receptionner',{},'parcours-reception-135');raise AssertionError('panne attendue')
  except psycopg2.Error as ex:check('panne_reception_parcours' in str(ex) and photo()==avant,'panne apres reception annule caisse stocks lots archives et recu')
  q.execute('DROP TRIGGER panne_reception_parcours ON chantier_commandes_recus')
  def recevoir(_):
   with psycopg2.connect(srv.get_uri()) as cc:
    cur=cc.cursor();cur.execute("SET hg.acteur='Parcours terrain fixture';SET hg.serveur='on'");cur.execute('SELECT chantier_commande(%s,%s,%s,%s)',('ch-'+terrain+'-parcours-reception-135',terrain,'receptionner',Json({})));return cur.fetchone()[0]
  with ThreadPoolExecutor(max_workers=2) as pool:reponses=list(pool.map(recevoir,[0,1]))
  check(all(r['ok'] for r in reponses) and sum(bool(r.get('rejeu')) for r in reponses)==1,'deux receptions concurrentes un seul traitement confirme')
  r=next(r for r in reponses if not r.get('rejeu'));check(r['ok'],'reception vraie du chantier acheve')
  e=etat();check(e['niveau_construction']==palier and e['surface']==surface and e['proprietaire']=='Parcours terrain fixture','batiment recu superficie et titre conserves')
  if palier in ('commerce_premium','building'):check(len(e['subdivisions'])==len(lots) and e['planInitialValide'],'lots receptionnes accessibles sans reinitialiser le plan')
  avant=fonds();recu=commande('receptionner',{},'parcours-reception-135');check(recu.get('rejeu') and fonds()==avant,'reprise reception aucun second reliquat ou paiement')
  check(lire("SELECT count(*) FROM dossiers_urbanisme WHERE building_id=%s AND demandeur='Parcours terrain fixture' AND type_evenement='accord_tacite'",(terrain,))==1,'archive permis unique conservee apres reception')
  with psycopg2.connect(srv.get_uri()) as cc:
   cur=cc.cursor();cur.execute("SET hg.acteur='Parcours terrain fixture';SET hg.serveur='on'");cur.execute('SELECT data::jsonb FROM terrains_etat WHERE id=%s',(cle,));recharge=cur.fetchone()[0]
   cur.execute('SELECT chantier_commande_recu(%s)',('ch-'+terrain+'-parcours-reception-135',));recu=cur.fetchone()[0]
   check(recharge==e and recu['ok'] and recu['terminee'],'nouvelle session retrouve titre permis lots et recu de reception')
 for terrain,palier,occupation in [('terrain-a-batir-1','hangar','squatter_cool'),('terrain-a-batir-2','commerce_standard',None),('terrain-a-batir-3','commerce_premium','squatter_agr'),('terrain-a-batir-4','building',None),('terrain-a-batir-5','hangar',None)]:parcours(terrain,palier,occupation)
 print(json.dumps({'parcours_terrain_construction':True,'assertions':n,'production':False,'temps_simule_sur_fixture':True,'contrat_vol_prepare':('--vol135' in sys.argv),'benediction_hypothetique':('--vol135' in sys.argv)}))
def tout(db,q,srv):banque.suite(db,q,srv);suite(db,q,srv)
if __name__=='__main__':banque.m.main(tout)
