#!/usr/bin/env python3
"""Recette isolée #1020 puis quatre migrations #1085, lues sans modifier sa branche.
--contrats exécute séparément les critères restant à intégrer par Claude : un rouge
reste un rouge, aucun expectedFailure ni remplacement de fonction métier.
"""
import argparse, importlib.util, json, subprocess, sys, tempfile, unittest, uuid
from pathlib import Path
R=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--postgres-bin',required=True);p.add_argument('--ordres-ref',default='77d457ad8e67702de8df5dec372f0596fa898737');p.add_argument('--contrats',action='store_true');opt=p.parse_args()
files=['migrations/20261117170000_goulag_ordres_internes_registre.sql','migrations/20261117170500_goulag_ordres_internes_detention.sql','migrations/20261117171000_goulag_ordres_internes_bureau_mirador.sql','migrations/20261117171500_goulag_ordres_internes_raccord_evasion.sql','outils/bancs/test-goulag-ordres-internes-postgresql-20261117.py','outils/bancs/banc-goulag-ordres-internes-retour-arriere-20261117.sql']
tmp=tempfile.TemporaryDirectory(prefix='hg-1085-lecture-');T=Path(tmp.name)
for f in files:
 d=T/f;d.parent.mkdir(parents=True,exist_ok=True);d.write_bytes(subprocess.check_output(['git','show',opt.ordres_ref+':'+f],cwd=R))
for d,s in [('outils/baseline',R/'outils/baseline'),('baseline',R/'baseline'),('data.js',R/'data.js')]:
 (T/d).symlink_to(s,target_is_directory=s.is_dir())
sys.argv=[str(T/files[4]),'--postgres-bin',opt.postgres_bin,'--moteur-1020',str(R)]
spec=importlib.util.spec_from_file_location('claude1085',T/files[4]);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
D,V,J=m.DETENU,m.VISITEUR,m.JUGE
class Raccords(m.OrdresInternes):
 def test_raccord_verrou_conserve(self):
  self.assertFalse(self.sql('SELECT active FROM public.sovarka_goulag_configuration'))
  self.q.execute('SAVEPOINT verrou')
  with self.assertRaises(m.psycopg2.errors.CheckViolation):self.q.execute('UPDATE public.sovarka_goulag_configuration SET active=true')
  self.q.execute('ROLLBACK TO verrou')
 def test_raccord_sommeil_partage_camp_toundra(self):
  self.detenu(jours=5,pa=20);self.client();self.assertTrue(self.sql('SELECT public.sovarka_goulag_dormir()')['ok'])
  self.assertTrue(self.sql("SELECT public.sovarka_goulag_detenu_aller('entree_qhs')")['ok']);self.graine(lambda j:j<=80)
  self.assertTrue(self.sql("SELECT public.goulag_toundra_demarrer('starovka')")['ok'])
  avant=self.sql(f"SELECT public.goulag_toundra_lire()")['pa'];r=self.sql("SELECT public.goulag_toundra_agir('dormir')")
  self.assertFalse(r['ok'],r);self.assertEqual(self.val(f"SELECT pa FROM public.personnages_donnees WHERE name='{D}'"),avant)
 def test_raccord_routes_et_refuge(self):
  for destination,total,ville,rue in [('starovka',7,'ville_a','starovka-rue-stade'),('krasnov',10,'ville_b','krasnov-camp-bucherons')]:
   self.admin();self.q.execute('SAVEPOINT itineraire');self.detenu(jours=1,piece='entree_qhs',pa=20)
   self.client();self.graine(lambda j:j<=80);r=self.sql('SELECT public.goulag_toundra_demarrer(%s)',(destination,));self.assertTrue(r['ok'],r);self.assertEqual(r['peine_gelee_secondes'],86400)
   for jour in range(total):
    self.client()
    if jour==4:self.assertTrue(self.sql("SELECT public.goulag_toundra_agir('champignons_refuser')")['ok'])
    for action in ['abri','dormir','progresser']:
     r=self.sql('SELECT public.goulag_toundra_agir(%s)',(action,));self.assertTrue(r['ok'],r)
    self.admin();self.q.execute("UPDATE public.sovarka_goulag_traversees SET debut_le=debut_le-1,jour_abri=jour_abri-1,jour_sommeil=jour_sommeil-1,jour_progression=jour_progression-1 WHERE nom=%s",(D,))
    if jour<total-1:self.q.execute('UPDATE public.personnages_donnees SET pa_repos_le=pa_repos_le-1 WHERE name=%s',(D,))
   self.assertEqual(self.sql('SELECT (current_city,current_street,pa)::text FROM public.personnages_donnees WHERE name=%s',(D,)),f'({ville},{rue},1)')
   self.client();self.assertTrue(self.sql('SELECT public.sovarka_goulag_refuge_rejoindre()')['ok'])
   self.assertEqual(self.sql('SELECT public.sovarka_goulag_refuge_nuit(5)')['bois_preleves'],5)
   self.admin();self.q.execute('UPDATE public.sovarka_goulag_refuges SET arrivee_le=arrivee_le-1,derniere_nuit=derniere_nuit-1 WHERE nom=%s',(D,))
   self.client();self.assertEqual(self.sql('SELECT public.sovarka_goulag_refuge_nuit(3)')['bois_preleves'],3)
   self.admin();self.q.execute('UPDATE public.sovarka_goulag_refuges SET arrivee_le=arrivee_le-2 WHERE nom=%s',(D,))
   self.client();self.assertTrue(self.sql('SELECT public.sovarka_goulag_refuge_terminer(0)')['ok'])
   self.admin();self.assertEqual(self.sql('SELECT jours_restants FROM public.sovarka_goulag_registre WHERE nom=%s',(D,)),1)
   self.q.execute('ROLLBACK TO itineraire')
class Contrats(m.OrdresInternes):
 def test_contrat_interrogateur_un_pa(self):
  self.detenu(pa=20);self.present();self.client(2);req=str(uuid.uuid4());r=self.sql('SELECT public.sovarka_goulag_interroger(%s,%s)',(D,req));self.assertTrue(r['ok'],r)
  self.assertEqual(self.val('SELECT pa FROM public.personnages_donnees WHERE name=%s',(V,)),19)
  self.client(2);self.assertTrue(self.sql('SELECT public.sovarka_goulag_interroger(%s,%s)',(D,req))['rejeu']);self.assertEqual(self.val('SELECT pa FROM public.personnages_donnees WHERE name=%s',(V,)),19)
 def test_contrat_juge_sanction_un_pa(self):
  self.detenu();self.juge();self.client(4);r=self.sql('SELECT public.sovarka_goulag_sanctionner(%s,1,%s)',(D,str(uuid.uuid4())));self.assertTrue(r['ok'],r);self.assertEqual(self.val('SELECT pa FROM public.personnages_donnees WHERE name=%s',(J,)),19)
 def test_contrat_corruption_definitive(self):
  # Règle définitive de Fred (17/11) : cadeau obligatoire, min(90, 70 + 10 + 2 × CHARME), objet consommé.
  self.assertIsNone(self.sql("SELECT to_regclass('public.sovarka_goulag_parametres')"))
  self.detenu(piece='mirador');pain={'name':'Pain','type':'nourriture','stackKey':'pain'}
  pile=dict(pain,stackable=True,qty=2)
  self.q.execute('UPDATE public.personnages_donnees SET inventory=%s WHERE name=%s',(m.Json([pile]),D))
  self.client();r=self.sql("SELECT public.sovarka_goulag_corrompre(%s)",(str(uuid.uuid4()),))
  self.assertEqual((r['ok'],r['raison']),(False,'cadeau_obligatoire'))
  self.assertEqual(self.val('SELECT inventory FROM public.personnages_donnees WHERE name=%s',(D,)),[pile])
  self.assertEqual(self.sql('SELECT count(*) FROM public.sovarka_goulag_corruptions'),0)
  for cha,attendu in [(None,90),(0,80),(3,86),(5,90),(-5,70)]:
   self.admin();self.q.execute('UPDATE public.sovarka_goulag_registre SET corruption_bonus=false')
   self.q.execute('UPDATE public.personnages_donnees SET stats=%s,inventory=%s WHERE name=%s',(m.Json({} if cha is None else {'CHA':cha}),m.Json([pile]),D))
   self.client();self.graine(lambda j:j>attendu)
   r=self.sql('SELECT public.sovarka_goulag_corrompre(%s,0,%s)',(str(uuid.uuid4()),m.Json(pain)))
   self.assertEqual((r['ok'],r['reussi'],r['taux']),(True,False,attendu),cha)
   self.assertEqual(r['inventory'],[dict(pile,qty=1)])
 def test_contrat_corruption_reussie_refus_sans_perte(self):
  # Validé par Fred : tant que le bonus à 95 % n'a pas servi, refus sans consommer d'objet.
  self.detenu(piece='mirador',pa=20);montre={'name':'Montre','type':'objet','stackKey':'montre'};pain={'name':'Pain','type':'nourriture','stackKey':'pain'}
  self.q.execute('UPDATE public.personnages_donnees SET stats=%s,inventory=%s WHERE name=%s',(m.Json({'CHA':0}),m.Json([montre,pain]),D))
  self.client();self.graine(lambda j:j<=80);self.assertTrue(self.sql('SELECT public.sovarka_goulag_corrompre(%s,0,%s)',(str(uuid.uuid4()),m.Json(montre)))['reussi'])
  r=self.sql('SELECT public.sovarka_goulag_corrompre(%s,0,%s)',(str(uuid.uuid4()),m.Json(pain)))
  self.assertEqual((r['ok'],r['raison']),(False,'gardien_deja_corrompu'))
  self.assertEqual(self.val('SELECT inventory FROM public.personnages_donnees WHERE name=%s',(D,)),[pain])
  self.assertEqual(self.sql('SELECT count(*) FROM public.sovarka_goulag_corruptions'),1)
  self.q.execute('UPDATE public.personnages_donnees SET current_room=%s WHERE name=%s',('entree_qhs',D))
  self.client();self.graine(lambda j:80<j<=95);self.assertTrue(self.sql("SELECT public.goulag_toundra_demarrer('starovka')")['ok'])
  self.assertEqual(self.val('SELECT (taux,corruption)::text FROM public.sovarka_goulag_tentatives'),'(95,t)')
 def test_contrat_absence_minuit_sans_evasion(self):
  # Validé par Fred : détenu hors du camp sans évasion, statut Détenu conservé, incident enregistré.
  self.detenu(jours=4)
  self.q.execute("UPDATE public.personnages_donnees SET current_city='capitale',current_building='dispensaire-public',current_room='chambre_1' WHERE name=%s",(D,))
  r=self.sql('SELECT public.sovarka_goulag_controle_minuit(current_date)');self.assertEqual((r['absents'],r['en_fuite']),(1,0))
  self.assertEqual(self.sql("SELECT (statut_controle,present_controle,jours_restants)::text FROM public.sovarka_goulag_registre WHERE detention_id='fx-det'"),'(detenu,f,4)')
  self.assertEqual(self.sql("SELECT count(*) FROM public.sovarka_goulag_incidents WHERE nature='absence_minuit' AND details->>'motif'='hors_du_camp'"),1)
  self.assertIsNone(self.sql("SELECT mode_fin FROM public.detentions WHERE id='fx-det'"))
  self.assertTrue(self.sql('SELECT public.sovarka_goulag_controle_minuit(current_date)')['deja_fait'])
 def test_contrat_transfert_detention_commencee(self):
  # Validé par Fred : une détention commencée hors du goulag puis transférée reprend ses jours restants.
  self.activer()
  self.q.execute("UPDATE public.personnages_donnees SET current_city='capitale',current_building='commissariat',current_room='prison',est_emprisonne=jsonb_build_object('debutTs',extract(epoch from now()-interval '3 days')*1000,'jours',10,'detentionId','fx-cours') WHERE name=%s",(D,))
  self.q.execute("INSERT INTO public.detentions(id,nom,country,city,qhs,jour_debut,jour_fin,created_at) VALUES('fx-cours',%s,'soviet','capitale',false,1,11,now()-interval '3 days')",(D,))
  self.q.execute("SELECT set_config('rp.goulag_jugement_interne','valide',true)")
  self.q.execute("UPDATE public.personnages_donnees SET current_city='qhs',current_building='qhs-prison',current_room='cellules_qhs' WHERE name=%s",(D,))
  self.sql("SELECT public.detention_qhs_poser_interne(%s,'fx-cours','Transfert au goulag')",(D,))
  self.q.execute('SET CONSTRAINTS ALL IMMEDIATE')
  self.assertEqual(self.sql("SELECT jours_restants FROM public.sovarka_goulag_registre WHERE detention_id='fx-cours'"),7)
  self.client();self.assertEqual(self.sql('SELECT public.sovarka_goulag_dormir()')['jours_restants'],6)
 def nouveau_jugement(self):
  self.admin();self.juge();self.q.execute("UPDATE public.personnages_donnees SET current_city='capitale',current_building='tribunal',current_room='bureau_juge' WHERE name=%s",(J,))
  self.q.execute("INSERT INTO public.plaintes_en_cours(id,country,city,data) VALUES('fx-addition','soviet','capitale',%s)",(json.dumps({'status':'saisie','audience_ouverte_le':'fixture','cible':D}),))
  self.client(4);r=self.sql("SELECT public.sovarka_goulag_juger('fx-addition','vol',30)");self.assertTrue(r['ok'],r);self.admin();self.q.execute('SET CONSTRAINTS ALL IMMEDIATE')
 def test_contrat_transfert_par_jugement_reel(self):
  # Détention ordinaire de 10 jours commencée il y a 3 jours, puis condamnation au goulag de 30 jours :
  # jours restants au transfert (7) + peine prononcée (30), comptée une seule fois.
  self.activer()
  self.q.execute("UPDATE public.personnages_donnees SET current_city='capitale',current_building='commissariat',current_room='prison',est_emprisonne=jsonb_build_object('debutTs',extract(epoch from now()-interval '3 days')*1000,'jours',10,'detentionId','fx-ordinaire','city','capitale') WHERE name=%s",(D,))
  self.q.execute("INSERT INTO public.detentions(id,nom,country,city,qhs,jour_debut,jour_fin,created_at) VALUES('fx-ordinaire',%s,'soviet','capitale',false,1,11,now()-interval '3 days')",(D,))
  self.nouveau_jugement()
  self.assertEqual(self.sql("SELECT jours_restants FROM public.sovarka_goulag_registre WHERE detention_id='fx-ordinaire'"),37)
  self.assertEqual(self.sql("SELECT count(*) FROM public.sovarka_goulag_registre_jugements WHERE jugement_id='jug-fx-addition'"),1)
 def test_contrat_peine_ajoutee_en_detention(self):
  self.detenu(jours=5);self.nouveau_jugement();self.assertEqual(self.sql("SELECT jours_restants FROM public.sovarka_goulag_registre WHERE detention_id='fx-det'"),35)
 def test_contrat_reincarceration_et_nouvelle_peine(self):
  self.detenu(jours=5,piece='entree_qhs',pa=20);self.client();self.graine(lambda j:j<=80);self.assertTrue(self.sql("SELECT public.goulag_toundra_demarrer('starovka')")['ok'])
  self.admin();self.q.execute('UPDATE public.sovarka_goulag_traversees SET en_cours=false WHERE nom=%s',(D,));self.nouveau_jugement()
  self.assertEqual(self.sql("SELECT r.jours_restants FROM public.sovarka_goulag_registre r JOIN public.detentions d ON d.id=r.detention_id WHERE r.nom=%s AND d.mode_fin IS NULL",(D,)),35)
 def test_contrat_rejeu_lie_a_interrogateur(self):
  self.detenu(pa=20);self.present();self.juge();self.client(2);req=str(uuid.uuid4());self.assertTrue(self.sql('SELECT public.sovarka_goulag_interroger(%s,%s)',(D,req))['ok'])
  self.client(4);r=self.sql('SELECT public.sovarka_goulag_interroger(%s,%s)',(D,req));self.assertFalse(r['ok'],r)
 def test_contrat_rejeu_sanction_lie_au_juge(self):
  self.detenu();self.juge();req=str(uuid.uuid4());self.client(4)
  self.assertTrue(self.sql('SELECT public.sovarka_goulag_sanctionner(%s,1,%s)',(D,req))['ok'])
  self.admin();self.present(V,'bureau_chef')
  self.q.execute("UPDATE public.personnages_donnees SET poste='{\"id\":\"juge\",\"city\":\"ville_b\"}' WHERE name=%s",(V,))
  self.q.execute("INSERT INTO public.postes_attribues(id,country,poste_id,city,titulaire,source) VALUES('fx-autre-juge','soviet','juge','ville_b',%s,'fixture')",(V,))
  self.client(2);r=self.sql('SELECT public.sovarka_goulag_sanctionner(%s,1,%s)',(D,req));self.assertFalse(r['ok'],r)

try:
 suite=(unittest.TestSuite(Contrats(n) for n in sorted(Contrats.__dict__) if n.startswith('test_contrat_')) if opt.contrats else unittest.defaultTestLoader.loadTestsFromTestCase(Raccords))
 print('Source #1085 :',opt.ordres_ref,flush=True);res=unittest.TextTestRunner(verbosity=2).run(suite);sys.exit(not res.wasSuccessful())
finally:tmp.cleanup()
