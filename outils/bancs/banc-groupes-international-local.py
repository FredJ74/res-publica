#!/usr/bin/env python3
"""Suite native #219. Les changements de pays ci-dessous éprouvent la position,
pas encore un billet international ni un passage en douane."""
import importlib.util,sys,re
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('transport',R/'outils/bancs/banc-groupes-transports-local.py');t=importlib.util.module_from_spec(sp);sp.loader.exec_module(t)
def suite(ctx,suivante=None):
 q,cas,rpc,exige,sql=[ctx[x] for x in ['q','cas','rpc','exige','sql']]
 q.execute("SELECT to_regclass('public.postes_attribues')")
 if q.fetchone()[0] is None:
  src=(R/'baseline/domaines/postes-et-institutions/10_tables.sql').read_text();q.execute(re.search(r'CREATE TABLE public.postes_attribues \(.*?\n\);',src,re.S)[0])
 # Mandats fictifs attestés au registre existant, cohérents avec le décor acquis.
 q.execute("INSERT INTO postes_attribues(id,country,poste_id,city,titulaire,source) VALUES('comm-B','republic','commissaire','capitale','B','fixture'),('comm-C','republic','commissaire','ville_a','C','fixture')")
 p=R/'migrations/20261031115807_pnj_position_pays_physique.sql'
 q.execute(p.read_text());q.execute(p.read_text())
 p=R/'migrations/20261031115808_police_autorite_registre_poste.sql';q.execute(p.read_text());q.execute(p.read_text())
 if '--contre-pays' in sys.argv:
  q.execute("SELECT pg_get_functiondef('public.pnj_position_effective(text)'::regprocedure)")
  ancien=q.fetchone()[0];a="SELECT CASE WHEN m.leader_pj IS NOT NULL THEN d.country\n    WHEN m.leader_pnj_id IS NOT NULL THEN coalesce(l.position_pays,l.pays)\n    ELSE coalesce(m.position_pays,m.pays) END,"
  assert ancien.count(a)==1;q.execute(ancien.replace(a,'SELECT m.pays,'))
 if '--contre-autorite' in sys.argv:
  a=t.lots.amb.rondes.interieur.natif.rue.force.corps.g.audit
  q.execute(a.fonction('baseline/domaines/justice/20_fonctions-2.sql','police_autorite_de_perimetre'))
 ctx['c'].commit()
 def origine():
  q.execute("SELECT id,pays,proprietaire_institution,proprietaire_perimetre,proprietaire_pj,public.pnj_autorite_de(id) FROM pnj_membres WHERE leader_pj='B' ORDER BY id");return q.fetchall()
 def etranger():
  sql("UPDATE personnages_donnees SET country='soviet',current_city='capitale',current_building='centre-multinodal-luthecia',current_room='hall_gare',current_street=NULL WHERE name IN ('A','B')")
 def suit():
  avant=origine();etranger()
  q.execute("SELECT count(*) FROM pnj_membres m CROSS JOIN LATERAL pnj_position_effective(m.id) pe WHERE leader_pj='B' AND pe.pays='soviet'");assert q.fetchone()[0]==7
  assert origine()==avant,'le déplacement transfère une autorité institutionnelle'
 cas('international_position_7_PNJ_suit_pays_reel_sans_transferer_autorite',suit)
 def depose():
  etranger();exige(rpc('pnj_deployer_unite',(['police-republic-capitale-P1'],True),qui='B'))
  q.execute("SELECT m.pays,m.position_pays,pe.pays,pe.ville FROM pnj_membres m CROSS JOIN LATERAL pnj_position_effective(m.id) pe WHERE m.id='police-republic-capitale-P1'")
  assert q.fetchone()==('republic','soviet','soviet','capitale')
  # Un rechargement relit la même position du socle, pas celle d'origine.
  q.execute("SELECT pnj_co_present('B','police-republic-capitale-P1')");assert q.fetchone()[0] is True
 cas('international_depose_conserve_pays_physique_et_copresence',depose)
 def ancre():
  etranger();ids=['police-republic-capitale-P1','police-republic-capitale-P2']
  exige(rpc('pnj_deployer_unite',(ids,True),qui='B'))
  q.execute('SELECT count(*) FROM unnest(%s::text[]) x CROSS JOIN LATERAL pnj_position_effective(x) pe WHERE pe.pays=\'soviet\'',(ids,));assert q.fetchone()[0]==2
 cas('international_unite_detachee_ancre_et_suiveur_meme_pays',ancre)
 def reprise():
  etranger();exige(rpc('pnj_deployer_unite',(['police-republic-capitale-P1','cie-S1'],False),qui='B'))
  exige(rpc('pnj_prendre',(['police-republic-capitale-P1'],),qui='B'))
  exige(rpc('pnj_prendre',(['cie-S1'],),qui='B'),'autorite_insuffisante')
  exige(rpc('pnj_prendre',(['cie-S1'],),qui='A'))
 cas('international_reprise_police_propre_soldat_reserve_autorite_origine',reprise)
 def revoque():
  etranger();sql("DELETE FROM postes_attribues WHERE titulaire='B'")
  q.execute("SELECT pnj_peut_administrer('B','police-republic-capitale-P1')");assert q.fetchone()[0] is False
  # L'ancien poste de présentation ne remplace jamais le registre.
  sql("UPDATE personnages_donnees SET country='republic' WHERE name='B'")
  q.execute("SELECT pnj_peut_administrer('B','police-republic-capitale-P1')");assert q.fetchone()[0] is False
 cas('international_mandat_revoque_pas_recree_par_ancien_cache_poste',revoque)
 def ecriture_directe():
  q.execute('GRANT UPDATE(position_pays),SELECT(id,position_pays) ON pnj_membres TO authenticated')
  q.execute('SAVEPOINT patch_interdit')
  try:
   q.execute("SELECT set_config('role','authenticated',true),set_config('request.path','/rest/v1/pnj_membres',true)")
   q.execute("UPDATE pnj_membres SET position_pays='soviet' WHERE id='cie-S1'")
  except Exception as e:
   q.execute('ROLLBACK TO SAVEPOINT patch_interdit');assert 'position_pnj_reservee_au_serveur' in str(e),e
  else:raise AssertionError('pays physique réécrit directement par le navigateur')
 cas('international_pays_physique_pas_modifiable_par_PATCH_client',ecriture_directe)
 def garde_rejeu():
  q.execute('ALTER TABLE pnj_membres DISABLE TRIGGER pnj_position_pays_garde');q.execute('SAVEPOINT garde')
  try:q.execute((R/'migrations/20261031115807_pnj_position_pays_physique.sql').read_text())
  except Exception as e:
   q.execute('ROLLBACK TO SAVEPOINT garde');assert 'garde_pays_pnj_non_conforme' in str(e),e
  else:raise AssertionError('trigger désactivé accepté au rejeu')
 cas('international_rejeu_refuse_garde_desactivee',garde_rejeu)
 if suivante is not None:suivante(ctx)
def lancer(suivante=None):
 amb=t.lots.amb;rondes=amb.rondes;interieur=rondes.interieur;natif=interieur.natif;rue=natif.rue;f=rue.force
 return f.corps.g.main(lambda c:f.corps.extension(c,lambda c:f.suite(c,lambda c:rue.suite(c,lambda c:natif.suite(c,lambda c:interieur.suite(c,lambda c:rondes.suite(c,lambda c:amb.suite(c,lambda c:t.lots.suite(c,lambda c:t.suite(c,lambda c:suite(c,suivante)))))))))))
if __name__=='__main__':sys.exit(lancer())
