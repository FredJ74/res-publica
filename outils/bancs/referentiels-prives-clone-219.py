"""Charge quatre captures statiques dans le seul clone local ; jamais en production.

Les lignes ne figurent ni dans Git ni dans les rapports. Le contenu JSON brut
est transmis à PostgreSQL pour préserver exactement nombres et objets JSON.
La certification des douze tables reste la barrière indépendante du pilote.
"""
import hashlib,json
from decimal import Decimal
from pathlib import Path
TABLES=('postes_nommes_regles','chantiers_paliers','entreprises_constantes','recettes_commerce')
R=Path(__file__).resolve().parents[2]

def normaliser_locale(cle,v):
 return v.lower().replace('-','').replace('_','') if cle in ('collate','ctype') and isinstance(v,str) else v

def lire_capture(chemin,reference,sha256_attendu=None):
 p=Path(chemin).resolve()
 if p.is_relative_to(R):raise ValueError('Capture privée interdite dans le dépôt')
 octets=p.read_bytes();empreinte=hashlib.sha256(octets).hexdigest()
 if sha256_attendu is not None and empreinte!=sha256_attendu:raise ValueError('SHA-256 privé différent de l’empreinte attendue')
 brut=octets.decode('utf-8')
 try:obj=json.loads(brut,parse_float=Decimal)
 except (ValueError,TypeError):raise ValueError('Capture privée JSON invalide') from None
 chemin_json=[]
 # Sortie JSON directe ou enveloppe execute_sql explicitement nommée.
 if isinstance(obj,list) and len(obj)==1:obj=obj[0];chemin_json.append('0')
 if isinstance(obj,dict) and set(obj)=={'export_referentiels_manquants_219'}:
  obj=obj['export_referentiels_manquants_219'];chemin_json.append('export_referentiels_manquants_219')
 if not isinstance(obj,dict) or set(obj)!={'releve_le','registre','locale','referentiels'}:raise ValueError('Enveloppe privée incomplète ou inattendue')
 if obj['registre']!={'lignes':reference['registre'],'derniere':reference['derniere_version']}:raise ValueError('Registre privé différent de la référence')
 if not isinstance(obj['locale'],dict) or not obj['releve_le']:raise ValueError('Provenance de capture absente')
 if not reference.get('locale'):raise ValueError('Observation externe de locale absente')
 if any(normaliser_locale(k,obj['locale'].get(k))!=normaliser_locale(k,v) for k,v in reference['locale'].items()):raise ValueError('Locale de capture contraire au relevé externe')
 refs=obj['referentiels']
 if not isinstance(refs,dict) or set(refs)!=set(TABLES):raise ValueError('Seulement les quatre tables statiques autorisées')
 for table in TABLES:
  lignes=refs[table]
  if not isinstance(lignes,list) or len(lignes)!=reference['referentiels'][table]['lignes']:raise ValueError('Cardinalité privée différente : '+table)
  if not all(isinstance(ligne,dict) for ligne in lignes):raise ValueError('Lignes privées invalides : '+table)
 return brut,obj,chemin_json,empreinte

def verifier_locale(q,capture):
 q.execute("SELECT datcollate,datctype,datlocprovider,COALESCE(to_jsonb(d)->>'datlocale',to_jsonb(d)->>'daticulocale'),datcollversion,pg_database_collation_actual_version(oid) FROM pg_database d WHERE datname=current_database()")
 observe=dict(zip(('collate','ctype','provider','datlocale','version','version_actuelle'),q.fetchone()))
 attendu=capture['locale']
 if set(attendu)!=set(observe):raise ValueError('Relevé de locale incomplet : datlocale et versions de collation requis')
 # Seuls les alias libc UTF-8 sont normalisés, jamais ICU ni ses versions.
 ecarts=[k for k in observe if normaliser_locale(k,observe[k])!=normaliser_locale(k,attendu[k])]
 if ecarts:raise ValueError('Locale du clone différente : '+','.join(ecarts))
 return {'conforme':True,'locale':observe}

def charger(q,chemin,reference,sha256_attendu=None):
 if q.connection.info.host and not q.connection.info.host.startswith('/'):raise ValueError('Socket PostgreSQL local requis pour les captures')
 # Les schémas déjà reconstruits doivent précéder cette étape.
 brut,capture,racine,h=lire_capture(chemin,reference,sha256_attendu)
 locale=verifier_locale(q,capture)
 q.execute('SAVEPOINT capture_refs219')
 try:
  for table in TABLES:
   q.execute("SELECT a.attname FROM pg_attribute a WHERE a.attrelid=%s::regclass AND a.attnum>0 AND NOT a.attisdropped ORDER BY a.attnum",('public.'+table,));colonnes={x[0] for x in q.fetchall()}
   if not all(set(x)==colonnes for x in capture['referentiels'][table]):raise ValueError('Capture de ligne incomplète : '+table)
   # Préserver les clés encore référencées par d'autres graines : aucun
   # DELETE/recréation de parent identique, aucune contrainte désactivée.
   q.execute("SELECT a.attname FROM pg_constraint c CROSS JOIN LATERAL unnest(c.conkey) WITH ORDINALITY x(num,n) JOIN pg_attribute a ON a.attrelid=c.conrelid AND a.attnum=x.num WHERE c.conrelid=%s::regclass AND c.contype='p' ORDER BY x.n",('public.'+table,));pk=[x[0] for x in q.fetchall()]
   if not pk:raise ValueError('Clé primaire statique absente : '+table)
   ident=lambda nom:'"'+nom.replace('"','""')+'"'
   affectations=','.join(ident(k)+'=EXCLUDED.'+ident(k) for k in sorted(colonnes-set(pk)))
   source='jsonb_populate_recordset(NULL::public.'+table+',%s::jsonb #> %s::text[])'
   param=(brut,racine+['referentiels',table])
   q.execute('INSERT INTO public.'+table+' SELECT * FROM '+source+' ON CONFLICT ('+','.join(map(ident,pk))+') DO UPDATE SET '+affectations,param)
   egalite=' AND '.join('ancien.'+ident(k)+' IS NOT DISTINCT FROM nouveau.'+ident(k) for k in pk)
   q.execute('DELETE FROM public.'+table+' ancien WHERE NOT EXISTS(SELECT 1 FROM '+source+' nouveau WHERE '+egalite+')',param)
  vide=reference['referentiels']['offres_emploi_bne']
  if vide!={'lignes':0,'empreinte':'d751713988987e9331980363e24189ce'}:raise ValueError('BNE vide non attesté par la référence')
  q.execute('DELETE FROM public.offres_emploi_bne')
  mesures={}
  for table in (*TABLES,'offres_emploi_bne'):
   q.execute("SELECT count(*),md5(COALESCE(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text)::text,'[]')) FROM public."+table+' x');n,empreinte=q.fetchone()
   mesures[table]={'lignes':n,'empreinte':empreinte}
   if mesures[table]!=reference['referentiels'][table]:raise ValueError('Empreinte privée différente : '+table)
  q.execute('RELEASE SAVEPOINT capture_refs219')
  return {'capture_sha256':h,'lignes':sum(x['lignes'] for x in mesures.values()),'tables':mesures,'locale':locale,'donnees_joueurs_importees':False}
 except Exception as ex:
  q.execute('ROLLBACK TO SAVEPOINT capture_refs219');q.execute('RELEASE SAVEPOINT capture_refs219')
  # Les diagnostics du moteur peuvent contenir des valeurs de lignes privées.
  if isinstance(ex,ValueError):raise
  raise ValueError('Chargement privé annulé : '+type(ex).__name__) from None
