#!/usr/bin/env python3
"""Socle #66 et moteurs SQL reels sur PostgreSQL jetable ; auth/horloge de test, aucune production."""
from pathlib import Path
import tempfile,re,json
from concurrent.futures import ThreadPoolExecutor
R=Path(__file__).resolve().parents[2]
def fonction(f,nom):
 s=(R/f).read_text();a=s.index('CREATE OR REPLACE FUNCTION public.'+nom+'(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',s[a:],re.S);return s[a:a+m.end()]
def main():
 import pgserver,psycopg2
 from psycopg2.extras import Json
 server=pgserver.get_server(tempfile.mkdtemp(prefix='hg-immobilier66-'),cleanup_mode='delete');uri=server.get_uri();n=0
 try:
  with psycopg2.connect(uri) as db:
   db.autocommit=True;q=db.cursor()
   q.execute("CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role;CREATE SCHEMA auth;CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$SELECT NULL::uuid$$")
   tables={'personnage-et-presence':['personnages_donnees'],'immobilier-et-territoire':['terrains_etat','terrains_historique_ventes','locations_actives','villes'],'economie':['entreprises','entreprises_constantes','entreprises_prix_rachat','ordres_couts','ordres_couts_inconnus','ordres_couts_ecarts'],'banque':['comptes_bancaires'],'finances-publiques':['caisses_batiments','caisses_mouvements_clients','recettes_municipales'],'politique-et-elections':['presidence_memoire_ordres'],'communication':['mails','mails_envois_systeme']}
   for d,ts in tables.items():
    src=(R/f'baseline/domaines/{d}/10_tables.sql').read_text()
    for t in ts:q.execute(re.search(r'CREATE TABLE public\.'+t+r' \(.*?\n\);',src,re.S)[0])
   for t,pk in [('personnages_donnees','name'),('terrains_etat','id'),('entreprises','id'),('locations_actives','id'),('comptes_bancaires','id'),('mails','id'),('caisses_batiments','id'),('recettes_municipales','pays,ville,jour,canal'),('ordres_couts_inconnus','fn')]:q.execute(f'ALTER TABLE {t} ADD PRIMARY KEY({pk})')
   q.execute("""ALTER TABLE ordres_couts_ecarts ADD UNIQUE(fn,pa,cost);CREATE VIEW personnages AS SELECT * FROM personnages_donnees;
    CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql STABLE AS $$SELECT nullif(current_setting('test.acteur',true),'')$$;
    CREATE FUNCTION est_appel_serveur() RETURNS boolean LANGUAGE sql STABLE AS $$SELECT coalesce(current_setting('test.serveur',true),'')='oui'$$;
    CREATE FUNCTION exiger_acteur(text) RETURNS void LANGUAGE plpgsql AS $$BEGIN IF $1 IS DISTINCT FROM mon_personnage() THEN RAISE EXCEPTION 'acteur_non_authentifie';END IF;END$$;
    CREATE FUNCTION acteur_poste_courant() RETURNS TABLE(poste_id text) LANGUAGE sql AS $$SELECT poste->>'id' FROM personnages_donnees WHERE name=mon_personnage()$$;
    CREATE FUNCTION salaire_caisse_de(text,text,text) RETURNS text LANGUAGE sql AS $$SELECT $2||'_mairie_'||$3$$;
    INSERT INTO entreprises_constantes VALUES('acompte_compromis',1000);INSERT INTO entreprises_prix_rachat VALUES('hotel-republica',380000);
    INSERT INTO ordres_couts VALUES('officialiser_transaction',1,0);
    INSERT INTO villes VALUES('republic','capitale','Luthécia',true,1);
    INSERT INTO caisses_batiments VALUES('republic_mairie_capitale','{\"solde\":0}',now());""")
   for f,ts in [('banque',['helvetia_debiter_fonds_ordinaires','helvetia_crediter_destination']),('economie1',['entreprise_prix_rachat','entreprise_signer_compromis','entreprise_acte_rachat','entreprise_ajouter_historique']),('economie2',['payer_ordre','vendre_fonds_commerce']),('finances',['caisse_institution_mouvement','recette_municipale']),('socle',['mouvement_titulaire']),('communication',['mail_systeme_poser_interne'])]:
    fichier={'banque':'banque/20_fonctions.sql','economie1':'economie/20_fonctions-1.sql','economie2':'economie/20_fonctions-2.sql','finances':'finances-publiques/20_fonctions-1.sql','socle':'socle/20_fonctions.sql','communication':'communication/20_fonctions.sql'}[f]
    for nom in ts:q.execute(fonction('baseline/domaines/'+fichier,nom))
   for ligne in (R/'baseline/domaines/finances-publiques/30_contraintes.sql').read_text().splitlines():
    if 'ADD CONSTRAINT recettes_municipales_canal_check ' in ligne or 'ADD CONSTRAINT recettes_municipales_montant_check ' in ligne:q.execute(ligne)
   mig=(R/'migrations/20261021203047_immobilier_offres_fonds_murs.sql').read_text();q.execute(mig);q.execute(mig)
   def ok(v,t):
    nonlocal n
    assert v,t;n+=1;print('OK',t,flush=True)
   def acteur(nom):q.execute("SELECT set_config('test.acteur',%s,false)",(nom,))
   def appel(fn,args=()):q.execute('SELECT '+fn+'('+','.join(['%s']*len(args))+')',args);return q.fetchone()[0]
   def pj(nom,solde=1000000,poste=None):
    q.execute("INSERT INTO personnages_donnees(name,user_id,country,current_city,current_building,current_room,hp,pa,arg,liquide,poste) VALUES(%s,gen_random_uuid(),'republic','capitale','office-notarial','bureau_contrats',100,10,%s,%s,%s)",(nom,solde,solde,Json(poste)))
    q.execute("INSERT INTO comptes_bancaires(id,personnage,pays,banque,solde) VALUES(%s,%s,'republic','nationale',0)",(nom,nom))
   for nom in ['Acheteur','Autre','Locataire','Vendeur']:pj(nom)
   pj('Pauvre',2000)
   pj('Maire',poste={'id':'maire','city':'capitale'})
   q.execute("INSERT INTO entreprises(id,data) VALUES('hotel','{\"id\":\"hotel\",\"type\":\"brasserie\",\"country\":\"republic\",\"city\":\"capitale\",\"buildingId\":\"hotel-republica\",\"proprietaire\":\"PNJ\",\"caisse\":100,\"stock\":{\"vin\":7}}'),('sans-surface','{\"id\":\"sans-surface\",\"type\":\"bar\",\"country\":\"republic\",\"city\":\"capitale\",\"buildingId\":\"autre-bar\",\"proprietaire\":\"PNJ\"}')")
   q.execute("SET test.serveur='oui'");ok(appel('immobilier_raccorder_pnj')['raccordes']==2,'raccordement commun, sans moteur propre au batiment');ok(appel('immobilier_raccorder_pnj')['raccordes']==0,'initialisation idempotente');q.execute("SET test.serveur='non'")
   bien='republic:capitale:hotel-republica'
   acteur('Maire');v=appel('immobilier_offre_deposer',('murs',bien,'murs',None));ok(v['ok'],'offre murs municipaux deposee')
   acteur('Acheteur');q.execute("SET test.serveur='oui'");v=appel('immobilier_offre_deposer',('fonds',bien,'fonds',None));ok(v['ok'],'fonds PNJ au catalogue existant');q.execute("SET test.serveur='non'")
   cat=appel('immobilier_catalogue',('republic',));ok(sorted(int(o['prix']) for o in cat['offres'])==[180000,380000],'1200 m2 a 150 et fonds distinct de 380000')
   v=appel('immobilier_offre_deposer',('incomplet','republic:capitale:autre-bar','fonds',None));ok(v['raison']=='fiche_incomplete','aucune vente avec surface inventee')
   v=appel('immobilier_acte_finaliser',('achat-conjoint',['fonds','murs']));ok(v['ok'] and v['prix_total']=='560000','achat conjoint atomique des deux actifs')
   q.execute("SELECT liquide,pa FROM personnages_donnees WHERE name='Acheteur'");ok(q.fetchone()==(440000,9),'un prix total et un seul PA, acompte deduit')
   q.execute("SELECT data->>'proprietaire',data->'stock' FROM entreprises WHERE id='hotel'");ok(q.fetchone()==('Acheteur',{'vin':7}),'fonds et stocks conserves')
   q.execute("SELECT proprietaire,data::jsonb->>'proprietaire' FROM terrains_etat WHERE building_id='hotel-republica'");ok(q.fetchone()==('Acheteur','Acheteur'),'deux representations du meme titre coherentes')
   q.execute("SELECT data->>'solde' FROM caisses_batiments WHERE id='republic_mairie_capitale'");ok(q.fetchone()[0]=='180000','prix des murs verse a la caisse municipale existante')
   ok(appel('immobilier_acte_finaliser',('achat-conjoint',['murs','fonds']))['rejeu'],'reponse perdue : meme acte sans second paiement')
   ok(appel('immobilier_acte_finaliser',('achat-conjoint',['fonds']))['raison']=='requete_reutilisee','identifiant de reprise lie aux actifs')
   # Vente PJ : prix souverain, aucun plafond derive du bareme.
   v=appel('immobilier_offre_deposer',('revente-murs',bien,'murs','7'));ok(v['ok'],'prix PJ libre, inferieur a la reference')
   q.execute("INSERT INTO locations_actives(id,country,data) VALUES('bail','republic','{\"country\":\"republic\",\"city\":\"capitale\",\"buildingId\":\"hotel-republica\",\"roomId\":\"restaurant\",\"locataire\":\"Locataire\",\"prix\":123}')")
   acteur('Autre');ok(appel('immobilier_acte_finaliser',('occupation-change',['revente-murs']))['raison']=='occupation_modifiee','nouvel occupant exige une offre actualisee, pas de droit invente')
   # Bien independant pour la priorite, donnees de fixture, aucun batiment particulier dans le moteur.
   q.execute("SET test.serveur='oui';INSERT INTO terrains_etat(id,country,building_id,proprietaire,data) VALUES('titre2','republic','batiment2','Vendeur','{\"proprietaire\":\"Vendeur\",\"city\":\"capitale\",\"subdivisions\":[{\"id\":\"lot\",\"surface\":300}]}');INSERT INTO immobilier_biens VALUES('bien2','republic','capitale','batiment2','titre2',NULL,300);INSERT INTO locations_actives VALUES('bail2','republic','{\"country\":\"republic\",\"city\":\"capitale\",\"buildingId\":\"batiment2\",\"roomId\":\"lot_dyn_lot\",\"locataire\":\"Locataire\",\"prix\":123}',now());SET test.serveur='non'")
   acteur('Vendeur');ok(appel('immobilier_offre_deposer',('priorite','bien2','murs','45000'))['ok'],'proprietaire vend sans accord de l exploitant')
   q.execute("SELECT count(*) FROM mails WHERE to_player='Locataire'");ok(q.fetchone()[0]==1,'un courrier automatique')
   appel('immobilier_offre_deposer',('priorite','bien2','murs','45000'));q.execute("SELECT count(*) FROM mails WHERE to_player='Locataire'");ok(q.fetchone()[0]==1,'rejeu depot : aucun second courrier')
   acteur('Autre');ok(all(o['id']!='priorite' for o in appel('immobilier_catalogue',('republic',))['offres']),'offre non publiee aux tiers pendant 72 heures')
   ok(appel('immobilier_acte_finaliser',('tiers-trop-tot',['priorite']))['raison']=='priorite_exploitant','tiers refuse avant toute depense')
   acteur('Locataire');ok(any(o['id']=='priorite' and o['prioritaire'] for o in appel('immobilier_catalogue',('republic',))['offres']),'locataire voit son offre prioritaire')
   q.execute("SELECT data FROM locations_actives WHERE id='bail2'");bail=q.fetchone()[0]
   ok(appel('immobilier_acte_finaliser',('preempter',['priorite']))['ok'],'exercice de la priorite au prix annonce')
   q.execute("SELECT data FROM locations_actives WHERE id='bail2'");ok(q.fetchone()[0]==bail,'achat des murs : bail et loyer inchanges')
   q.execute("SELECT solde FROM comptes_bancaires WHERE personnage='Vendeur'");ok(q.fetchone()[0]==45000,'vendeur effectivement credite')
   # Revente et refus explicite.
   ok(appel('immobilier_offre_deposer',('offre-refus','bien2','murs','60000'))['ok'],'nouvelle offre, prix propre au proprietaire')
   # Occupant et vendeur identiques : publication directe, pas de preemption artificielle.
   q.execute("SELECT statut FROM immobilier_offres WHERE id='offre-refus'");ok(q.fetchone()[0]=='disponible','proprietaire occupant : pas de priorite contre soi-meme')
   acteur('Autre');ok(appel('immobilier_acte_finaliser',('acheter-refus',['offre-refus']))['ok'],'vente a un tiers apres publication')
   ok(appel('immobilier_offre_deposer',('refus-test','bien2','murs','70000'))['ok'],'offre a nouveau prioritaire pour le locataire')
   acteur('Locataire');ok(appel('immobilier_priorite_refuser',('refus-test',))['ok'],'refus explicite du locataire')
   acteur('Acheteur');ok(any(o['id']=='refus-test' for o in appel('immobilier_catalogue',('republic',))['offres']),'refus publie immediatement, sans attendre trois jours')
   # Les deux droits d un meme bien peuvent avoir des vendeurs differents.
   acteur('Acheteur');ok(appel('immobilier_offre_deposer',('revente-fonds',bien,'fonds','999999'))['ok'],'fonds PJ libre, au-dessus du prix public')
   acteur('Autre');ok(appel('immobilier_offre_deposer',('fraude',bien,'fonds','1'))['raison']=='offre_existante','un tiers ne remplace pas une offre existante')
   # Expiration : aucune connexion necessaire ; le cron utilise le meme horodatage autoritaire.
   q.execute("UPDATE immobilier_offres SET statut='priorite',refus_le=NULL,publication_le=NULL,priorite_fin=clock_timestamp()-interval '1 second' WHERE id='refus-test'")
   acteur('Acheteur');ok(any(o['id']=='refus-test' for o in appel('immobilier_catalogue',('republic',))['offres']),'horloge serveur ouvre l offre a echeance meme avant materialisation cron')
   q.execute("SET test.serveur='oui'");ok(appel('immobilier_priorites_publier')['publiees']==1,'publication serveur sans navigateur');ok(appel('immobilier_priorites_publier')['publiees']==0,'cron idempotent');q.execute("SET test.serveur='non'")
   # Moteur de fonds V2 existant : caisse extraite au vendeur, bail suit le fonds, murs inchanges.
   q.execute("""SET test.serveur='oui';
    INSERT INTO terrains_etat(id,country,building_id,proprietaire,data) VALUES('titre3','republic','local3','Autre','{"proprietaire":"Autre","city":"capitale"}');
    INSERT INTO entreprises VALUES('fonds-v2','{"version":2,"proprietaire":"pj:Vendeur","statut":"actif","caisse":120,"implantation":{"bailId":"bail3"},"historique":[]}',now());
    INSERT INTO immobilier_biens VALUES('bien3','republic','capitale','local3','titre3','fonds-v2',200);
    INSERT INTO locations_actives VALUES('bail3','republic','{"country":"republic","city":"capitale","buildingId":"local3","roomId":"lot_dyn_3","locataire":"Vendeur","prix":44}',now());
    SET test.serveur='non'""")
   acteur('Vendeur');ok(appel('immobilier_offre_deposer',('vente-v2','bien3','fonds','20000'))['ok'],'offre consentie d un fonds de modele deux')
   q.execute("SELECT solde FROM comptes_bancaires WHERE personnage='Vendeur'");avant_vendeur=q.fetchone()[0]
   acteur('Acheteur');ok(appel('immobilier_acte_finaliser',('acheter-v2',['vente-v2']))['ok'],'cession via le moteur de fonds existant avec paiement externe unique')
   q.execute("SELECT data->>'proprietaire',data->>'caisse' FROM entreprises WHERE id='fonds-v2'");ok(q.fetchone()==('pj:Acheteur','0'),'caisse extraite, identite opaque et fonds conserves')
   q.execute("SELECT solde FROM comptes_bancaires WHERE personnage='Vendeur'");ok(q.fetchone()[0]==avant_vendeur+20120,'prix et tresorerie distincts credites une seule fois')
   q.execute("SELECT data->>'locataire',data->>'prix' FROM locations_actives WHERE id='bail3'");ok(q.fetchone()==('Acheteur','44'),'fonds transfere le titulaire du bail, pas son loyer')
   q.execute("SELECT proprietaire FROM terrains_etat WHERE id='titre3'");ok(q.fetchone()[0]=='Autre','fonds seul ne transfere jamais les murs')
   # Demi-achat : echec de credit final doit annuler debit, frais et tout titre.
   acteur('Autre');ok(appel('immobilier_offre_deposer',('murs3','bien3','murs','10000'))['ok'],'vendeur de murs distinct du vendeur de fonds')
   acteur('Acheteur');ok(appel('immobilier_offre_deposer',('fonds3','bien3','fonds','30000'))['ok'],'offre conjointe composee de deux vendeurs')
   appel('immobilier_priorite_refuser',('murs3',));acteur('Locataire');q.execute("SELECT liquide,pa FROM personnages_donnees WHERE name='Locataire'");avant_acheteur=q.fetchone()
   q.execute("CREATE FUNCTION panne_acte() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.personnage='Autre' AND NEW.solde>OLD.solde THEN RAISE EXCEPTION 'panne credit simulee';END IF;RETURN NEW;END$$;CREATE TRIGGER panne_acte BEFORE UPDATE ON comptes_bancaires FOR EACH ROW EXECUTE FUNCTION panne_acte()")
   try:appel('immobilier_acte_finaliser',('demi-achat',['murs3','fonds3']))
   except psycopg2.Error:ok(True,'panne de credit provoquee apres premier transfert')
   else:raise AssertionError('panne non declenchee')
   q.execute("SELECT liquide,pa FROM personnages_donnees WHERE name='Locataire'");ok(q.fetchone()==avant_acheteur,'rollback du debit et du PA')
   q.execute("SELECT data->>'proprietaire' FROM entreprises WHERE id='fonds-v2'");ok(q.fetchone()[0]=='pj:Acheteur','rollback du premier titre de l achat conjoint')
   q.execute("SELECT count(*) FROM immobilier_actes WHERE requete='demi-achat'");ok(q.fetchone()[0]==0,'aucun recu de succes pour une transaction annulee')
   q.execute('DROP TRIGGER panne_acte ON comptes_bancaires')
   ok(appel('immobilier_acte_finaliser',('demi-achat',['murs3','fonds3']))['ok'],'reprise du meme acte apres rollback : deux vendeurs PJ servis atomiquement')
   q.execute("SELECT proprietaire FROM terrains_etat WHERE id='titre3'");ok(q.fetchone()[0]=='Locataire','titre des murs du vendeur distinct transfere')
   ok(appel('immobilier_offre_deposer',('concurrence-fonds','bien3','fonds','30000'))['ok'],'nouvelle offre sur le fonds acquis, memes mecanismes')
   # Achat concurrent : un seul vainqueur, aucun debit du perdant.
   acteur('Locataire');q.execute("SELECT liquide,pa FROM personnages_donnees WHERE name IN('Vendeur','Locataire') ORDER BY name");avant_concurrence=q.fetchall()
   def acheter(nom):
    with psycopg2.connect(uri) as cx:
     cx.autocommit=True
     with cx.cursor() as z:
      z.execute("SELECT set_config('test.acteur',%s,false)",(nom,));z.execute("SELECT immobilier_acte_finaliser(%s,ARRAY['concurrence-fonds'])",('concurrent-'+nom,));return z.fetchone()[0]
   with ThreadPoolExecutor(max_workers=2) as pool:verdicts=list(pool.map(acheter,['Vendeur','Autre']))
   ok(sum(v['ok'] for v in verdicts)==1,'un seul acheteur concurrent')
   ok(any(v.get('raison')=='offre_vendue' for v in verdicts),'perdant refuse avant mutation')
   # Imprimerie : appel du circuit historique reel, sans copier sa cession ni sa caisse.
   q.execute("CREATE FUNCTION assemblee_requete_ouvrir(text,text,text) RETURNS jsonb LANGUAGE sql AS $$SELECT NULL::jsonb$$;CREATE FUNCTION assemblee_requete_clore(text,jsonb) RETURNS jsonb LANGUAGE sql AS $$SELECT $2$$")
   q.execute(fonction('historique/sql-racine/migrations/migration_20260920_caisses_marqueur_interne.sql','imprimerie_cession_finaliser'))
   q.execute("""SET test.serveur='oui';
    INSERT INTO caisses_batiments VALUES('republic_gouvernement-min_fin','{"solde":0}',now());
    INSERT INTO entreprises_constantes VALUES('prix_rachat_imprimerie',180000);
    INSERT INTO terrains_etat(id,country,building_id,proprietaire,data) VALUES('titre4','republic','imprimerie-fixture','Vendeur','{"proprietaire":"Vendeur","city":"capitale"}');
    INSERT INTO entreprises VALUES('imprimerie-fixture','{"id":"imprimerie-fixture","type":"imprimerie","country":"republic","city":"capitale","buildingId":"imprimerie-fixture","proprietaire":"PNJ","pretDemande":{"statut":"attente_validation"}}',now());
    INSERT INTO immobilier_biens VALUES('bien4','republic','capitale','imprimerie-fixture','titre4','imprimerie-fixture',300);SET test.serveur='non';""")
   acteur('Autre');q.execute("SET test.serveur='oui'");ok(appel('immobilier_offre_deposer',('imprimerie','bien4','fonds',None))['ok'],'imprimerie par la meme fiche commune');q.execute("SET test.serveur='non'")
   acteur('Pauvre');q.execute("SELECT liquide,pa FROM personnages_donnees WHERE name='Pauvre'");avant_pauvre=q.fetchone()
   ok(appel('immobilier_acte_finaliser',('pret-attente',['imprimerie']))['raison']=='pret_en_attente','clause de pret existante refuse avant tout mouvement')
   q.execute("UPDATE entreprises SET data=data-'pretDemande' WHERE id='imprimerie-fixture'")
   v=appel('immobilier_acte_finaliser',('deficit',['imprimerie']));ok(v['raison']=='fonds_insuffisants','insuffisance apres tentative d acompte : refus atomique')
   q.execute("SELECT liquide,pa FROM personnages_donnees WHERE name='Pauvre'");ok(q.fetchone()==avant_pauvre,'aucune perte de l acompte ni du PA apres refus de solde')
   q.execute("SELECT data ? 'compromis' FROM entreprises WHERE id='imprimerie-fixture'");ok(q.fetchone()[0]==False,'pas de compromis orphelin apres transaction refusee')
   acteur('Autre');q.execute("SELECT liquide,pa FROM personnages_donnees WHERE name='Autre'");avant_imprimerie=q.fetchone()
   ok(appel('immobilier_acte_finaliser',('acheter-imprimerie',['imprimerie']))['ok'],'cession imprimerie existante appelee sous la transaction commune')
   q.execute("SELECT liquide,pa FROM personnages_donnees WHERE name='Autre'");ok(q.fetchone()==(avant_imprimerie[0]-180000,avant_imprimerie[1]-1),'un prix imprimeur et un seul PA, acompte compris')
   q.execute("SELECT data->>'solde' FROM caisses_batiments WHERE id='republic_gouvernement-min_fin'");ok(q.fetchone()[0]=='180000','la caisse Etat historique encaisse exactement le prix')
   # Forcer une erreur du courrier annule aussi la mise en vente et sa fenetre.
   q.execute("SET test.serveur='oui';INSERT INTO terrains_etat(id,country,building_id,proprietaire,data) VALUES('titre5','republic','local5','Autre','{\"proprietaire\":\"Autre\",\"city\":\"capitale\"}');INSERT INTO immobilier_biens VALUES('bien5','republic','capitale','local5','titre5',NULL,300);INSERT INTO locations_actives VALUES('bail5','republic','{\"country\":\"republic\",\"city\":\"capitale\",\"buildingId\":\"local5\",\"locataire\":\"Locataire\",\"prix\":123}',now());SET test.serveur='non'")
   q.execute("CREATE FUNCTION panne_mail() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne mail simulee';END$$;CREATE TRIGGER panne_mail BEFORE INSERT ON mails FOR EACH ROW EXECUTE FUNCTION panne_mail()")
   try:appel('immobilier_offre_deposer',('mail-absent','bien5','murs','999'))
   except psycopg2.Error:pass
   else:raise AssertionError('offre sans notification acceptee')
   q.execute("SELECT count(*) FROM immobilier_offres WHERE id='mail-absent'");ok(q.fetchone()[0]==0,'courrier absent : aucune priorite silencieuse ouverte')
   q.execute('DROP TRIGGER panne_mail ON mails')
   # Raccordement du loyer : fonctions SQL reelles, meme bail, bailleur resolve au paiement.
   for nom in ['bail_destination_attestee','prelever_loyer_bail']:
    q.execute(fonction('baseline/domaines/immobilier-et-territoire/20_fonctions.sql',nom))
   loyers=(R/'migrations/20261021203832_immobilier_loyers_titres.sql').read_text();q.execute(loyers);q.execute(loyers)
   q.execute("SELECT data FROM locations_actives WHERE id='bail2'");d_bail=q.fetchone()[0]
   ok(appel('bail_destination_attestee',(Json(d_bail),))['type']=='titulaire_murs','ancien bail redirige selon les murs actuels sans reecrire ses clauses')
   q.execute("SELECT arg FROM personnages_donnees WHERE name='Autre'");arg_avant=q.fetchone()[0]
   q.execute("SET test.serveur='oui'");ok(appel('prelever_loyer_bail',('bail2',))=='paye','moteur de perception existant conserve')
   q.execute("SELECT arg FROM personnages_donnees WHERE name='Autre'");ok(q.fetchone()[0]==arg_avant+123,'loyer verse au nouveau proprietaire, pas au precedent')
   ok(appel('prelever_loyer_bail',('bail2',))=='deja_preleve','aucun double loyer apres reprise cron')
   ok(appel('bail_destination_attestee',(Json({'country':'republic','city':'capitale','buildingId':'autre-batiment','roomId':'salle'}),))['type']=='municipal','baux non raccordes conservent leur regime')
   ok(appel('bail_destination_attestee',(Json({'isBox':True,'chambreClinique':True,'buildingId':'local5'}),)) is None,'priorite de l exemption clinique preservee meme sur donnees historiques mixtes')
   # Un ancien titre PJ et sa surface ne sont jamais convertis en bien municipal.
   q.execute("""INSERT INTO entreprises VALUES('pnj-dans-murs-pj','{"id":"pnj-dans-murs-pj","type":"bar","country":"republic","city":"capitale","buildingId":"deja-prive","proprietaire":"PNJ"}',now());
    INSERT INTO terrains_etat(id,country,building_id,proprietaire,data) VALUES('prive-ancien','republic','deja-prive','Vendeur','{"city":"capitale","surface":450,"proprietaire":"Vendeur","subdivisions":[{"id":"historique","surface":90}]}');""")
   q.execute("SELECT data FROM terrains_etat WHERE id='prive-ancien'");titre_avant=q.fetchone()[0]
   ok(appel('immobilier_raccorder_pnj')['raccordes']==1,'raccordement dun commerce dans des murs deja prives')
   q.execute("SELECT proprietaire,data FROM terrains_etat WHERE id='prive-ancien'");ok(q.fetchone()==('Vendeur',titre_avant),'titre PJ, subdivisions et geometrie inchanges')
   q.execute("SELECT surface FROM immobilier_biens WHERE building_id='deja-prive'");ok(q.fetchone()[0]==450,'superficie persistante prioritaire sur toute valeur par defaut')
   q.execute("SET test.serveur='non'")
   # Une ancienne copie ne remet pas le vendeur apres la vente et ne contourne pas le notaire.
   acteur('Vendeur')
   try:q.execute("UPDATE terrains_etat SET proprietaire='Vendeur',data=(data::jsonb||'{\"proprietaire\":\"Vendeur\"}')::text WHERE id='titre2'")
   except psycopg2.Error as e:ok(e.pgcode=='42501','ancien snapshot de titre refuse au serveur')
   else:raise AssertionError('titre restaure par ancien proprietaire')
   acteur('Autre');etat=appel('immobilier_acte_etat',('acheter-imprimerie',));ok(etat['termine'] and etat['verdict']['ok'],'reconciliation authentifiee dun acte apres F5')
   acteur('Locataire');ok(not appel('immobilier_acte_etat',('acheter-imprimerie',))['termine'],'recu dun autre compte non expose')
   q.execute("SET test.serveur='oui'");v=appel('immobilier_references_publier');ok(v['ok'] and v['publiees']==0 and v['non_valorisees']==1,'prix de fonds absent : aucune valeur inventee');q.execute("INSERT INTO entreprises_prix_rachat VALUES('deja-prive',5000)");v=appel('immobilier_references_publier');ok(v['ok'] and v['publiees']==1,'publication initiale serveur des seules references completes')
   ok(appel('immobilier_references_publier')['publiees']==0,'references publiques idempotentes et aucune revente PJ automatique')
   q.execute("SET test.serveur='non'")
   pj('Ministre',poste={'id':'min_fin','city':'capitale'})
   q.execute("CREATE FUNCTION exiger_poste(text) RETURNS text LANGUAGE plpgsql AS $$BEGIN IF NOT EXISTS(SELECT 1 FROM acteur_poste_courant() WHERE poste_id=$1) THEN RAISE EXCEPTION 'poste_non_autorise';END IF;RETURN mon_personnage();END$$")
   q.execute(fonction('baseline/domaines/economie/20_fonctions-1.sql','entreprise_acte_preemption'))
   q.execute("SET test.serveur='oui';UPDATE entreprises SET data=data||'{\"preemptionEtat\":\"attente_acte\"}' WHERE id='pnj-dans-murs-pj';SET test.serveur='non'")
   acteur('Ministre');ok(appel('entreprise_acte_preemption',('Ministre','pnj-dans-murs-pj','État',None,0,0))['ok'],'pouvoir de preemption Etat existant preserve, distinct de celui du locataire')
   q.execute("SELECT proprietaire FROM terrains_etat WHERE id='prive-ancien'");ok(q.fetchone()[0]=='Vendeur','preemption du fonds ne prend toujours pas les murs PJ')
   # Sources non PJ : pas de reference de prix inventee pour les autres empires.
   q.execute("SET test.serveur='oui';INSERT INTO terrains_etat(id,country,building_id,proprietaire,data) VALUES('sov-titre','sovarka','local','Vendeur','{\"proprietaire\":\"Vendeur\",\"city\":\"capitale\"}');INSERT INTO immobilier_biens VALUES('sov','sovarka','capitale','local','sov-titre',NULL,450);UPDATE personnages_donnees SET country='sovarka' WHERE name='Vendeur';SET test.serveur='non'")
   acteur('Vendeur');ok(appel('immobilier_offre_deposer',('sov-offre','sov','murs','123'))['raison']=='regime_revente_non_arbitre','liberte PJ de Republia non extrapolee a Sovarka')
   q.execute("SET test.serveur='oui';UPDATE personnages_donnees SET country='republic' WHERE name='Vendeur';SET test.serveur='non'")
   # Un service autonome reste capable de regler un titre hors vente : aucune regression du calendrier.
   q.execute("SET test.serveur='oui';UPDATE terrains_etat SET proprietaire='Locataire',data=(data::jsonb||'{\"proprietaire\":\"Locataire\"}')::text WHERE id='titre5';SET test.serveur='non'")
   q.execute("SELECT proprietaire FROM terrains_etat WHERE id='titre5'");ok(q.fetchone()[0]=='Locataire','mutation serveur autonome non remplacee par un nouveau moteur')
   q.execute("SELECT data->>'proprietaire' FROM entreprises WHERE id='fonds-v2'");titulaire_fonds=q.fetchone()[0].removeprefix('pj:')
   acteur(titulaire_fonds);ok(appel('immobilier_offre_deposer',('gratuit','bien3','fonds','0'))['ok'],'prix PJ nul accepte sans plancher derive du bareme')
   q.execute("SET test.serveur='oui';UPDATE entreprises SET data=data||'{\"caisse\":0.5}' WHERE id='fonds-v2';SET test.serveur='non'")
   acteur('Pauvre');q.execute("SELECT pa,liquide FROM personnages_donnees WHERE name='Pauvre'");frais_avant=q.fetchone()
   ok(appel('immobilier_acte_finaliser',('fraction-historique',['gratuit']))['raison']=='etat_financier_non_entier','ancienne caisse fractionnaire refusee, jamais arrondie silencieusement')
   q.execute("SELECT pa,liquide FROM personnages_donnees WHERE name='Pauvre'");ok(q.fetchone()==frais_avant,'refus fractionnaire avant toute contrepartie')
   q.execute("SET test.serveur='oui';UPDATE entreprises SET data=data||'{\"caisse\":0}' WHERE id='fonds-v2';SET test.serveur='non'")
   ok(appel('immobilier_acte_finaliser',('libre-zero',['gratuit']))['ok'],'cession sans prix impose, frais d acte existants seulement')
   ok(appel('immobilier_offre_deposer',('<img-src=x>','bien3','fonds','1'))['raison']=='parametres_invalides','identifiant de courrier non injectable')
   ok(appel('immobilier_acte_finaliser',('<script>',['gratuit']))['raison']=='requete_invalide','identifiant historique strictement borne')
   q.execute("SET test.serveur='oui';INSERT INTO terrains_etat(id,country,building_id,proprietaire,data) VALUES('municipal-test','republic','municipal-test','ville:republic_capitale','{\"proprietaire\":\"ville:republic_capitale\",\"city\":\"capitale\"}');INSERT INTO immobilier_biens VALUES('municipal-test','republic','capitale','municipal-test','municipal-test',NULL,100);INSERT INTO locations_actives(id,country,data) VALUES('bail-municipal','republic','{\"country\":\"republic\",\"city\":\"capitale\",\"buildingId\":\"municipal-test\",\"locataire\":\"Locataire\"}');SET test.serveur='non'")
   acteur('Maire');ok(appel('immobilier_offre_deposer',('municipal-priorite','municipal-test','murs',None))['ok'],'offre municipale avec locataire')
   ok(any(o['id']=='municipal-priorite' for o in appel('immobilier_catalogue',('republic',))['offres']),'autorite municipale conserve la vue de son offre privee')
   acteur('Autre');ok(all(o['id']!='municipal-priorite' for o in appel('immobilier_catalogue',('republic',))['offres']),'visibilite municipale ne publie pas la priorite aux tiers')
   # Droits de tables et RPC.
   q.execute("SELECT has_table_privilege('authenticated','immobilier_offres','UPDATE'),has_function_privilege('anon','immobilier_acte_finaliser(text,text[])','EXECUTE')");ok(q.fetchone()==(False,False),'aucune ecriture directe ou acte anonyme')
   q.execute("ALTER TABLE recettes_municipales DROP CONSTRAINT recettes_municipales_canal_check;ALTER TABLE recettes_municipales ADD CONSTRAINT recettes_municipales_canal_check CHECK(canal IN('taxe_fonciere','loyer','taxe_transaction','cession_immobiliere','autre_canal_vivant'))")
   try:q.execute(mig)
   except psycopg2.Error as e:
    db.rollback();ok('canaux_municipaux_non_examines' in str(e),'migration refuse une extension de contrainte non examinee')
   else:raise AssertionError('extension vivante effacee')
   q.execute("SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid='recettes_municipales'::regclass AND conname='recettes_municipales_canal_check'")
   ok('autre_canal_vivant' in q.fetchone()[0],'contrainte inconnue preservee apres refus')
  print(f'{n}/{n} scenarios PostgreSQL locaux reussis ; auth simulee, production non verifiee.')
 finally:server.cleanup()
if __name__=='__main__':main()
