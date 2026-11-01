#!/usr/bin/env python3
"""Manifeste de collecte uniquement : ni connexion, ni contenu de production."""
import hashlib,importlib.util,json
from pathlib import Path
R=Path(__file__).resolve().parents[2]
TABLES=('postes_nommes_regles','ressources_economie','chantiers_paliers','chantiers_besoins_jour','entreprises_constantes','recettes_production','recettes_commerce','commerces_types','commerces_dotations','armureries_dotations','entreprises_prix_rachat','offres_emploi_bne')
def module(n,p):
 s=importlib.util.spec_from_file_location(n,R/p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def select_unique(sql):
 from pglast import parse_sql
 from pglast.visitors import Visitor
 class Lecture(Visitor):
  def visit(self,ancestors,node):
   if type(node).__name__ in ('InsertStmt','UpdateStmt','DeleteStmt','MergeStmt','CopyStmt','CallStmt','DoStmt','CreateStmt','DropStmt','AlterTableStmt','SelectIntoStmt'):raise ValueError('Mutation interdite')
   if type(node).__name__=='SelectStmt' and node.intoClause:raise ValueError('SELECT INTO interdit')
 ns=parse_sql(sql)
 if len(ns)!=1 or type(ns[0].stmt).__name__!='SelectStmt':raise ValueError('SELECT unique requis')
 Lecture()(ns)
 return sql.strip().rstrip(';')+';'
def manifeste():
 r=module('relais_collecte219','outils/livraison/relais-canonique-219.py')
 p=module('prevol_collecte219','outils/livraison/requetes-prevol-actualise-219.py')
 q=[{'id':'canonique','fichier':'relais-canonique.json','sql':select_unique(r.requete()),'format':'Objet HG_RELAIS_CANONIQUE_219_V1, validé et matérialisé par relais-canonique-219.py --verifier --sortie-privee ; fournit les quatre exports, contrôle et registre.'}]
 # Réutiliser le SELECT des racines, sans son enveloppe transactionnelle locale.
 root=(R/'outils/bancs/empreinte-catalogue-racine.sql').read_text();start=root.index('\nWITH\n');end=root.rindex('\nROLLBACK;')
 q.append({'id':'empreinte','fichier':'EMPREINTE-PRODUCTION.json','sql':select_unique(root[start:end]),'format':'Objet empreinte : version_serveur, registre {lignes,derniere}, six categories avec racines et seaux.'})
 for nom,sql in p.requetes():q.append({'id':nom,'fichier':nom+'.json','sql':select_unique(sql),'format':'Objet JSON direct ; conserver snapshot et releve_utc.'})
 mesures=','.join("'"+t+"',(SELECT jsonb_build_object('lignes',count(*),'empreinte',md5(coalesce(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text)::text,'[]'))) FROM public."+t+' x)' for t in TABLES)
 locale="(SELECT jsonb_build_object('collate',datcollate,'ctype',datctype,'provider',datlocprovider,'datlocale',COALESCE(to_jsonb(d)->>'datlocale',to_jsonb(d)->>'daticulocale'),'version',datcollversion,'version_actuelle',pg_database_collation_actual_version(oid)) FROM pg_database d WHERE datname=current_database())"
 sql="SELECT jsonb_build_object('snapshot',pg_current_snapshot()::text,'releve_utc',now(),'registre',(SELECT count(*) FROM supabase_migrations.schema_migrations),'derniere_version',(SELECT max(version) FROM supabase_migrations.schema_migrations),'referentiels',jsonb_build_object("+mesures+"),'locale',"+locale+",'ordres_couts',(SELECT jsonb_build_object('lignes',count(*),'md5',md5(string_agg(fn||'|'||pa||'|'||cost,E'\\n' ORDER BY fn COLLATE \"C\",pa,cost)),'sentinelle',(SELECT empreinte FROM public.ordres_couts_empreinte WHERE seul)) FROM public.ordres_couts));"
 q.append({'id':'references','fichier':'REFERENTIELS-PRODUCTION.json','sql':select_unique(sql),'format':'Profil exact du pilote : registre entier, derniere_version, douze referentiels {lignes,empreinte}, ordres_couts {lignes,md5,sentinelle}, locale. Le profil LOCALE-PRODUCTION.json reprend registre, derniere_version et locale sans les renuméroter.'})
 prive=('postes_nommes_regles','chantiers_paliers','entreprises_constantes','recettes_commerce')
 contenu=','.join("'"+t+"',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text),'[]'::jsonb) FROM public."+t+' x)' for t in prive)
 sql="SELECT jsonb_build_object('releve_le',now(),'registre',(SELECT jsonb_build_object('lignes',count(*),'derniere',max(version)) FROM supabase_migrations.schema_migrations),'locale',"+locale+",'referentiels',jsonb_build_object("+contenu+"));"
 q.append({'id':'capture_privee','fichier':'referentiels-prives-hg219-coupe-courante.json','sql':select_unique(sql),'format':'Enveloppe exacte du chargeur privé : releve_le, registre, locale, quatre tables complètes. Ne pas ajouter de clé ni convertir les nombres.'})
 for e in q:e['sha256_requete']=hashlib.sha256(e['sql'].encode()).hexdigest()
 return {'format':'HG219_COLLECTE_CERTIFICATION_V1','connexion_effectuee':False,'production_modifiee':False,'coupe_annoncee_non_certifiee':{'registre':1021,'derniere':'20261101134313','tarifs':439},'protocole':['Intégrateur uniquement, canal privé. Ne jamais publier les sorties dans Git ou les commentaires.','Exécuter les SELECT dans UNE même transaction REPEATABLE READ READ ONLY, puis ROLLBACK ; sinon vérifier absence de changement du registre et ne pas prétendre au même snapshot.','Conserver les octets originaux ; fichier mode 600, dossier hors Git mode 700. Transmettre SHA-256 indépendant de chaque fichier.','Vérifier les registres concordants (sans imposer artificiellement 1021), version 17.6, douze tables, six catégories, ICU en-US/153.121 ; toute évolution impose une nouvelle coupe cohérente.','Le MD5 canonique utilise | et saut de ligne, tri COLLATE C ; ne pas lui substituer le MD5 diagnostique avec : et virgules.','Regénérer via rendre.py/seeds.py après validation du relais, jamais modifier les SQL générés à la main. Le pilote exige les profils externes, les exports, le registre, capture-couts {snapshot,releve_utc,ordres_couts}, la capture privée avec SHA, et les sources/deltas réconciliés de la coupe.','Le fichier capture-couts.json reprend les clés snapshot/releve_utc/ordres_couts du résultat referentiels sans recomposer les triples. Les observations partielles ne servent jamais à compléter une ligne absente.'], 'requetes':q}
if __name__=='__main__':print(json.dumps(manifeste(),ensure_ascii=False,indent=2))
