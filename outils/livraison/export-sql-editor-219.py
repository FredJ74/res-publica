#!/usr/bin/env python3
"""Collecte atomique en un SELECT ; assemble CSV/JSON vérifié hors Git. Aucune connexion."""
import argparse,base64,binascii,csv,hashlib,importlib.util,io,json,os,re,tarfile,tempfile
from datetime import datetime,timezone
from decimal import Decimal
from pathlib import Path
R=Path(__file__).resolve().parents[2]
FORMAT='HG219_SQL_EDITOR_V1'
MANIFESTE='MANIFESTE-PRIVE-219.json'
COLONNES=('capture_sha256','snapshot','fichier','partie','parties','octets_fichier','sha256_fichier','octets_fragment','sha256_fragment','donnees_base64')
MAX_OCTETS=256*1024*1024
SQL=R/'outils/bancs/COLLECTE-ATOMIQUE-219.sql'
def module(n,p):
 s=importlib.util.spec_from_file_location(n,R/p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def manifeste():return module('collecte_editor219','outils/livraison/manifeste-collecte-certification-219.py').manifeste()
def h(b):return hashlib.sha256(b).hexdigest()
def litteral(s):return "'"+s.replace("'","''")+"'"
def generer_sql(entrees=None,taille=8192):
 if type(taille) is not int or not 128<=taille<=16384:raise ValueError('Taille de fragment invalide')
 mf=manifeste();entrees=mf['requetes'] if entrees is None else entrees
 if [(e['id'],e['fichier']) for e in entrees]!=[(e['id'],e['fichier']) for e in mf['requetes']]:raise ValueError('Les sept ensembles canoniques sont obligatoires')
 valider_select=module('select_editor219','outils/livraison/manifeste-collecte-certification-219.py').select_unique
 ctes=['collecte_'+e['id']+'(payload) AS MATERIALIZED (\n'+valider_select(e['sql']).rstrip(';')+'\n)' for e in entrees]
 fichiers='\nUNION ALL\n'.join('SELECT '+litteral(e['fichier'])+' AS fichier,convert_to(payload::text,\'UTF8\') AS donnees FROM '+'collecte_'+e['id'] for e in entrees)
 source=json.dumps({e['id']:e['sha256_requete'] for e in mf['requetes']},sort_keys=True)
 ctes+=['fichiers AS MATERIALIZED ('+fichiers+')',"annuaire AS MATERIALIZED (SELECT convert_to(jsonb_build_object('format',"+litteral(FORMAT)+",'snapshot',pg_current_snapshot()::text,'releve_utc',timezone('UTC',now())::text,'server_version_num',current_setting('server_version_num'),'requetes_sha256',"+litteral(source)+"::jsonb,'fichiers',(SELECT jsonb_agg(jsonb_build_object('fichier',fichier,'octets',octet_length(donnees),'sha256',encode(sha256(donnees),'hex')) ORDER BY fichier COLLATE \"C\") FROM fichiers))::text,'UTF8') AS donnees)","tout AS MATERIALIZED (SELECT * FROM fichiers UNION ALL SELECT "+litteral(MANIFESTE)+",donnees FROM annuaire)"]
 sql="""-- Généré par outils/livraison/export-sql-editor-219.py --generer-sql.
-- Un seul SELECT = un seul instantané PostgreSQL pour les sept ensembles.
-- Aucun DDL, DML, ordre métier ou lecture de lignes de joueurs/auth.users.
-- SQL Editor : désactiver la limite de lignes, Run, puis Download CSV.
-- Le résultat reste PRIVÉ. Aucun fragment ne doit être collé dans GitHub.
-- Ne pas relancer pour compléter un ancien CSV : exporter une nouvelle capture entière.
WITH
"""+',\n'.join(ctes)+"""
SELECT encode(sha256(a.donnees),'hex') AS capture_sha256,
       pg_current_snapshot()::text AS snapshot,t.fichier,
       n AS partie,((octet_length(t.donnees)+TAILLE-1)/TAILLE)::int AS parties,
       octet_length(t.donnees) AS octets_fichier,encode(sha256(t.donnees),'hex') AS sha256_fichier,
       octet_length(fragment.donnees) AS octets_fragment,
       encode(sha256(fragment.donnees),'hex') AS sha256_fragment,
       replace(encode(fragment.donnees,'base64'),E'\\n','') AS donnees_base64
FROM tout t CROSS JOIN annuaire a
CROSS JOIN LATERAL generate_series(1,((octet_length(t.donnees)+TAILLE-1)/TAILLE)::int) n
CROSS JOIN LATERAL (SELECT substring(t.donnees FROM (n-1)*TAILLE+1 FOR TAILLE) AS donnees) fragment
ORDER BY t.fichier COLLATE "C",n;
""".replace('TAILLE',str(taille))
 return sql

def objet_unique(paires):
 d={}
 for k,v in paires:
  if k in d:raise ValueError('Clé JSON dupliquée')
  d[k]=v
 return d
def lire_json(b):
 return json.loads(b,parse_float=Decimal,object_pairs_hook=objet_unique,parse_constant=lambda x:(_ for _ in ()).throw(ValueError('Nombre JSON invalide')))
def json_exact(v):
 if isinstance(v,Decimal):
  if not v.is_finite():raise ValueError('Décimal non fini')
  return str(v)
 if isinstance(v,dict):return '{'+','.join(json.dumps(k,ensure_ascii=False)+':'+json_exact(x) for k,x in v.items())+'}'
 if isinstance(v,list):return '['+','.join(json_exact(x) for x in v)+']'
 return json.dumps(v,ensure_ascii=False,allow_nan=False)
def entier(v):
 if isinstance(v,bool) or not re.fullmatch(r'[0-9]+',str(v)):raise ValueError('Entier de transport invalide')
 n=int(v)
 if n>MAX_OCTETS:raise ValueError('Limite de taille dépassée')
 return n
def decoder(lignes,sha256_attendu=None):
 attendu={e['fichier'] for e in manifeste()['requetes']};groupes={};identites=set();snapshots=set();total_lu=0
 if not isinstance(lignes,list) or not lignes:raise ValueError('Capture vide')
 for row in lignes:
  if set(row)!=set(COLONNES):raise ValueError('Colonnes de fragments invalides')
  nom=row['fichier']
  if nom not in attendu|{MANIFESTE}:raise ValueError('Fichier inattendu')
  for cle in ('capture_sha256','sha256_fichier','sha256_fragment'):
   if not isinstance(row[cle],str) or not re.fullmatch('[a-f0-9]{64}',row[cle]):raise ValueError('SHA-256 invalide')
  identites.add(row['capture_sha256']);snapshots.add(row['snapshot'])
  if len(identites)!=1 or len(snapshots)!=1:raise ValueError('Captures ou snapshots mélangés')
  n,parts,octets,nb=map(entier,(row['partie'],row['parties'],row['octets_fichier'],row['octets_fragment']))
  if not 1<=n<=parts or parts>100000 or not 0<octets<=MAX_OCTETS or not 0<nb<=16384:raise ValueError('Numérotation ou longueur invalide')
  if not isinstance(row['donnees_base64'],str) or len(row['donnees_base64'])>22000:raise ValueError('Fragment excessif')
  try:b=base64.b64decode(row['donnees_base64'],validate=True)
  except (ValueError,binascii.Error):raise ValueError('Base64 invalide') from None
  if len(b)!=nb or h(b)!=row['sha256_fragment']:raise ValueError('Fragment altéré ou tronqué')
  total_lu+=len(b)
  if total_lu>MAX_OCTETS:raise ValueError('Capture excessive')
  g=groupes.setdefault(nom,{'parts':parts,'octets':octets,'sha':row['sha256_fichier'],'fragments':{}})
  if (parts,octets,row['sha256_fichier'])!=(g['parts'],g['octets'],g['sha']) or n in g['fragments']:raise ValueError('Métadonnées contradictoires ou fragment dupliqué')
  g['fragments'][n]=b
 if set(groupes)!=attendu|{MANIFESTE}:raise ValueError('Ensemble complet absent')
 fichiers={}
 for nom,g in groupes.items():
  if set(g['fragments'])!=set(range(1,g['parts']+1)):raise ValueError('Fragment manquant')
  b=b''.join(g['fragments'][n] for n in range(1,g['parts']+1))
  if len(b)!=g['octets'] or h(b)!=g['sha']:raise ValueError('Fichier altéré')
  fichiers[nom]=b
 cap=next(iter(identites));snap=next(iter(snapshots))
 if h(fichiers[MANIFESTE])!=cap or (sha256_attendu and cap!=sha256_attendu):raise ValueError('Empreinte de capture différente')
 ann=lire_json(fichiers[MANIFESTE])
 if ann.get('format')!=FORMAT or ann.get('snapshot')!=snap or ann.get('server_version_num')!='170006':raise ValueError('Provenance ou version de capture invalide')
 specs=ann.get('fichiers',[])
 if len(specs)!=7 or {x['fichier'] for x in specs}!=attendu:raise ValueError('Annuaire incomplet')
 for x in specs:
  if x['octets']!=len(fichiers[x['fichier']]) or x['sha256']!=h(fichiers[x['fichier']]):raise ValueError('Annuaire contraire au contenu')
 if ann.get('requetes_sha256')!={e['id']:e['sha256_requete'] for e in manifeste()['requetes']}:raise ValueError('Requêtes différentes du collecteur attendu')
 return fichiers,ann,cap

def normaliser_date(s):
 t=datetime.fromisoformat(s)
 return t.replace(tzinfo=timezone.utc) if t.tzinfo is None else t.astimezone(timezone.utc)
def verifier_documents(fichiers,ann):
 d={e['id']:lire_json(fichiers[e['fichier']]) for e in manifeste()['requetes']}
 canon=module('relais_editor219','outils/livraison/relais-canonique-219.py');canon.valider(d['canonique'])
 reg=d['canonique']['registre'];versions=[x['version'] for x in reg]
 if not versions or len(versions)!=len(set(versions)) or any(not re.fullmatch('[0-9]{14}',v) for v in versions):raise ValueError('Registre invalide')
 coupe={'lignes':len(reg),'derniere':max(versions)};ref=d['references']
 if len(reg)<1022:raise ValueError('Coupe antérieure au minimum annoncé 1022')
 if d['registre']['registre']!=reg or d['empreinte']['registre']!=coupe or d['capture_privee']['registre']!=coupe or (ref['registre'],ref['derniere_version'])!=(len(reg),max(versions)):raise ValueError('Registres de coupes différentes')
 if d['registre']['server_version_num']!='170006' or d['empreinte']['version_serveur']!='17.6':raise ValueError('PostgreSQL 17.6 requis')
 for k in ('canonique','registre','catalogue_cible','referentiels','references'):
  if d[k]['snapshot']!=ann['snapshot']:raise ValueError('Snapshots différents')
  if normaliser_date(d[k]['releve_utc'])!=normaliser_date(ann['releve_utc']):raise ValueError('Relevés de dates différentes')
 if normaliser_date(d['capture_privee']['releve_le'])!=normaliser_date(ann['releve_utc']):raise ValueError('Capture privée de date différente')
 loc=ref['locale']
 if set(loc)!=set(('collate','ctype','provider','datlocale','version','version_actuelle')) or (loc['provider'],loc['datlocale'],loc['version'],loc['version_actuelle'])!=('i','en-US','153.121','153.121') or d['capture_privee']['locale']!=loc:raise ValueError('Locale incohérente ou différente')
 families={'relations','fonctions','index','politiques','contraintes','declencheurs'}
 if set(d['empreinte']['categories'])!=families:raise ValueError('Six racines obligatoires')
 for v in d['empreinte']['categories'].values():
  if not re.fullmatch('[a-f0-9]{32}',v['racine']) or type(v['objets']) is not int or v['objets']<0 or not isinstance(v['seaux'],dict):raise ValueError('Racine invalide')
 noms=set(module('noms_editor219','outils/livraison/manifeste-collecte-certification-219.py').TABLES)
 if set(ref['referentiels'])!=noms or set(d['referentiels']['referentiels'])!=noms:raise ValueError('Douze référentiels requis')
 for table,v in ref['referentiels'].items():
  if type(v['lignes']) is not int or v['lignes']<0 or not re.fullmatch('[a-f0-9]{32}',v['empreinte']) or len(d['referentiels']['referentiels'][table])!=v['lignes']:raise ValueError('Cardinalité ou contrôle invalide')
 prive=module('prive_editor219','outils/bancs/referentiels-prives-clone-219.py')
 if set(d['capture_privee']['referentiels'])!=set(prive.TABLES):raise ValueError('Capture privée incomplète')
 for table in prive.TABLES:
  if d['capture_privee']['referentiels'][table]!=d['referentiels']['referentiels'][table]:raise ValueError('Contenus privés contradictoires')
 diff=module('triples_editor219','outils/baseline/comparer-couts-captures.py');couts=d['referentiels']['ordres_couts'];ts=sorted(diff.triples(couts))
 md5=hashlib.md5('\n'.join('%s|%d|%d'%x for x in ts).encode()).hexdigest()
 if ref['ordres_couts']['lignes']!=len(ts) or ref['ordres_couts']['md5']!=md5 or d['referentiels']['couts_controle']!={'lignes':len(ts),'md5':md5}:raise ValueError('Tarifs incomplets ou empreinte canonique contradictoire')
 sent=d['referentiels']['couts_sentinelle']
 if len(sent)!=1 or sent[0].get('seul') is not True or sent[0].get('empreinte')!=ref['ordres_couts']['sentinelle']:raise ValueError('Sentinelle contradictoire')
 # Vérification PostgreSQL des douze MD5 et six racines sur clone reste obligatoire.
 return d,canon

def charger_lignes(paths):
 lignes=[]
 for p in paths:
  if p.stat().st_size>MAX_OCTETS*2:raise ValueError('Fichier de transport excessif')
  with p.open(encoding='utf-8-sig',newline='') as f:
   if p.suffix.lower()=='.csv':
    csv.field_size_limit(MAX_OCTETS);reader=csv.DictReader(f)
    if len(reader.fieldnames or [])!=len(COLONNES) or set(reader.fieldnames)!=set(COLONNES):raise ValueError('En-têtes CSV invalides')
    lignes.extend(reader)
   else:
    x=lire_json(f.read())
    if not isinstance(x,list):raise ValueError('Liste JSON des lignes requise')
    lignes.extend(x)
 return lignes

def assembler(paths,destination,sha256_attendu=None):
 destination=Path(destination).resolve();relais=module('destination_editor219','outils/livraison/relais-canonique-219.py')
 if any(relais.marqueur_git_actif(p) for p in (destination,*destination.parents)):raise ValueError('Destination privée hors Git requise')
 if destination.exists():raise ValueError('Destination neuve requise')
 fichiers,ann,cap=decoder(charger_lignes(paths),sha256_attendu);d,canon=verifier_documents(fichiers,ann)
 destination.parent.mkdir(parents=True,exist_ok=True)
 with tempfile.TemporaryDirectory(prefix='.hg219-assemble-',dir=destination.parent) as tmp:
  stage=Path(tmp)/'paquet';stage.mkdir(mode=0o700)
  def ecrire(n,b):
   p=stage/n;p.parent.mkdir(mode=0o700,parents=True,exist_ok=True);fd=os.open(p,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
   with os.fdopen(fd,'wb') as f:f.write(b)
  for n,b in fichiers.items():ecrire(n,b)
  canon.materialiser(d['canonique'],stage/'catalogue')
  locale={k:d['references'][k] for k in ('registre','derniere_version','locale')}
  ecrire('LOCALE-PRODUCTION.json',json_exact(locale).encode())
  couts={k:d['referentiels'][k] for k in ('snapshot','releve_utc','ordres_couts')}
  ecrire('capture-couts.json',json_exact(couts).encode())
  controle={'capture_sha256':cap,'empreinte_independante_verifiee':bool(sha256_attendu),'snapshot':ann['snapshot'],'registre':d['empreinte']['registre'],'catalogue_certifie':False,'fichiers':{str(p.relative_to(stage)):{'octets':p.stat().st_size,'sha256':h(p.read_bytes())} for p in sorted(stage.rglob('*')) if p.is_file()}}
  ecrire('INTEGRITE-IMPORT.json',json_exact(controle).encode())
  archive=Path(tmp)/'exports-certification-219.tar.gz'
  with tarfile.open(archive,'w:gz') as tar:
   for p in sorted(stage.rglob('*')):
    if p.is_file():tar.add(p,arcname=str(p.relative_to(stage)),recursive=False)
  archive.chmod(0o600);archive.rename(stage/archive.name);stage.rename(destination)
 return {'capture_sha256':cap,'registre':controle['registre'],'fichiers':len(controle['fichiers']),'archive_sha256':h((destination/archive.name).read_bytes()),'catalogue_certifie':False}

def main():
 a=argparse.ArgumentParser(description=__doc__);g=a.add_mutually_exclusive_group(required=True);g.add_argument('--generer-sql',action='store_true');g.add_argument('--verifier-sql',action='store_true');g.add_argument('--assembler',type=Path,nargs='+');a.add_argument('--destination',type=Path);a.add_argument('--sha256-manifeste');o=a.parse_args()
 if o.generer_sql:SQL.write_text(generer_sql());print(str(SQL));return
 if o.verifier_sql:
  sql=generer_sql()
  if SQL.read_text()!=sql or not module('workflow_editor219','outils/baseline/verifier-workflow.py').select_catalogue_sans_ecriture(sql):raise SystemExit('SQL généré différent ou hors lecture seule')
  print(json.dumps({'sql_identique':True,'select_unique_lecture':True,'sha256':h(SQL.read_bytes())}));return
 if not o.destination:a.error('--destination requis')
 if o.sha256_manifeste and not re.fullmatch('[a-f0-9]{64}',o.sha256_manifeste):a.error('SHA-256 invalide')
 try:rapport=assembler(o.assembler,o.destination,o.sha256_manifeste)
 except Exception as ex:raise SystemExit('Capture refusée : '+type(ex).__name__+'. Aucun contenu privé affiché.') from None
 print(json.dumps(rapport,ensure_ascii=False))
if __name__=='__main__':main()
