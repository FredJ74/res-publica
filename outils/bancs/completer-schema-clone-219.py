"""Métadonnées seules des tables exclues du monde neuf, pour le clone de catalogue.

Réutilise les phases de rendre.py ; ne change ni sa classification ni le baseline.
Aucune ligne des tables d'archives/snapshots n'est extraite ou insérée.
"""
from collections import defaultdict
import csv,sys,re,hashlib,subprocess
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(R/'outils/baseline'))
import rendre
def diagnostic_generateurs(q,decouper,attendus):
 """Un essai déterministe des sources existantes, toujours annulé.

 Ne remplace ni les données réelles manquantes ni le verdict strict. Aucun
 tarif ou libellé n'est deviné à partir d'une empreinte.
 """
 q.execute('SAVEPOINT diagnostic_sources_refs')
 cle={'postes_nommes_regles':'poste_id','chantiers_paliers':'palier','entreprises_constantes':'cle','recettes_commerce':'id'}
 erreurs={}
 try:
  for script in ['generer_miroirs_chantiers.py','generer_miroirs_entreprises.py','generer_postes_nommes.py']:
   q.execute('SAVEPOINT source_ref')
   try:
    texte=subprocess.check_output([sys.executable,str(R/'outils/generateurs'/script),'--sql'],text=True,cwd=R)
    if script=='generer_postes_nommes.py':texte='INSERT INTO public.postes_nommes_regles(poste_id,label,nomme_par,scope,autorite_scope) VALUES '+texte+';'
    for ast,ordre in decouper(texte):
     if type(ast).__name__!='InsertStmt' or ast.relation.relname not in cle:continue
     table=ast.relation.relname
     if ast.onConflictClause is None:
      colonnes=[c.name for c in ast.cols];pk=cle[table]
      ordre=ordre.rstrip().rstrip(';')+' ON CONFLICT ('+rendre.identifiant(pk)+') DO UPDATE SET '+','.join(rendre.identifiant(c)+'=EXCLUDED.'+rendre.identifiant(c) for c in colonnes if c!=pk)+';'
     q.execute(ordre)
   except Exception as ex:
    erreurs[script]=str(ex);q.execute('ROLLBACK TO SAVEPOINT source_ref')
   finally:q.execute('RELEASE SAVEPOINT source_ref')
  mesures={}
  for table in cle:
   q.execute("SELECT count(*),md5(COALESCE(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text)::text,'[]')) FROM public."+table+' x');n,h=q.fetchone()
   mesures[table]={'lignes':n,'empreinte':h,'concorde_reference':{'lignes':n,'empreinte':h}==attendus[table]}
  return {'essai_annule':True,'modification_des_attentes':False,'erreurs_generateurs':erreurs,'mesures':mesures}
 except Exception as ex:
  return {'essai_annule':True,'erreur':str(ex)}
 finally:q.execute('ROLLBACK TO SAVEPOINT diagnostic_sources_refs')
def restituer_bornes(definition):
 # BETWEEN est décomposé APRÈS l'analyse des AND. Le déparseur perd cette
 # origine : rejouer ses comparaisons aplatit autrement l'arbre booléen.
 expr=r'(?:COALESCE\([a-z_][a-z_0-9]*,\s*-?\d+\)|[a-z_][a-z_0-9]*)'
 motif=re.compile(r'\(\((?P<expr>'+expr+r') >= (?P<bas>-?\d+)\) AND \((?P=expr) <= (?P<haut>-?\d+)\)\)',re.I)
 return motif.sub(lambda m:'('+m['expr']+' BETWEEN '+m['bas']+' AND '+m['haut']+')',definition)
def restituer_checks(q,exports,equivalentes):
 exp,_=rendre.charger_exports(str(exports));preuves=[]
 for c in exp['contraintes']:
  if c['genre']!='c':continue
  q.execute('SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid=%s::regclass AND conname=%s',('public.'+c['tbl'],c['nom']));ligne=q.fetchone()
  if ligne and ligne[0]!=c['definition']:
   actuelle=ligne[0];source=c['definition'];corrigee=restituer_bornes(source)
   assert equivalentes(actuelle)==equivalentes(source),'CHECK différent sémantiquement'
   assert corrigee!=source,'Origine du dépliage CHECK non reconnue'
   tbl=rendre.identifiant(c['tbl']);nom=rendre.identifiant(c['nom'])
   q.execute('ALTER TABLE public.'+tbl+' DROP CONSTRAINT '+nom+';ALTER TABLE public.'+tbl+' ADD CONSTRAINT '+nom+' '+corrigee)
   q.execute('SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid=%s::regclass AND conname=%s',('public.'+c['tbl'],c['nom']));apres=q.fetchone()[0]
   assert apres==source,'L’arbre CHECK reconstitué ne reproduit pas la source exacte'
   preuves.append({'table':c['tbl'],'contrainte':c['nom'],'avant':hashlib.md5(actuelle.encode()).hexdigest(),'source_et_apres':hashlib.md5(apres.encode()).hexdigest(),'regle':'BETWEEN déplié après analyse des AND ; définition source exacte retrouvée'})
 return preuves
def preparer(exports):
 exp,_=rendre.charger_exports(str(exports))
 with (R/'baseline/classification-donnees.csv').open() as f:
  exclues={x['table'] for x in csv.DictReader(f,delimiter=';') if x['strategie']=='hors_baseline'}
 obj={k:[] for k in rendre.VIDE}
 for k in ['colonnes','sequences','contraintes','index','triggers','rls','policies']:
  obj[k]=[x for x in exp.get(k,[]) if x.get('tbl') in exclues]
 sequences={x['sequence'] for x in obj['sequences']}
 obj['droits']=[x for x in exp['droits_relations'] if x['objet'] in exclues|sequences]
 obj['droits_colonnes']=[x for x in exp['droits_colonnes'] if x['tbl'] in exclues]
 obj['commentaires']=[x for x in exp['commentaires'] if x.get('objet') in exclues]
 man=defaultdict(list)
 avant='\n'.join(rendre.phase_tables(obj,man,exp))
 apres=[]
 for fn in [rendre.phase_contraintes,rendre.phase_index,rendre.phase_triggers,rendre.phase_rls,rendre.phase_droits,rendre.phase_commentaires]:
  apres.extend(fn(obj,man,exp))
 return avant,'\n'.join(apres),{'tables_metadata_seules':sorted(exclues),'lignes_copiees':0,'colonnes':len(obj['colonnes'])}
