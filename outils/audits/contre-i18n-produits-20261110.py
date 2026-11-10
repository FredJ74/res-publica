"""Contre-épreuves des catalogues, copies temporaires ; aucune donnée de joueur."""
from pathlib import Path
import json,shutil,subprocess,tempfile
R=Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='hg-produits-contre-') as d:
 t=Path(d);(t/'outils/audits').mkdir(parents=True);shutil.copytree(R/'i18n',t/'i18n')
 shutil.copy(R/'outils/audits/audit-i18n-editorial.cjs',t/'outils/audits')
 def verdict():
  p=subprocess.run(['node',str(t/'outils/audits/audit-i18n-editorial.cjs')],capture_output=True,text=True)
  return p.returncode,json.loads(p.stdout)
 assert verdict()[0]==0
 p=t/'i18n/economic-catalog-resources.js';original=p.read_text()
 needle='    "material_metal_label": "معدن",';assert original.count(needle)==1
 p.write_text(original.replace(needle,''));code,r=verdict();assert code!=0 and 'economicCatalog.material_metal_label' in r['results']['ar']['missing']
 p.write_text(original)
 p=t/'i18n/commerce-production-resources.js';original=p.read_text();needle='{{values.salary}} FR Lohn.';assert original.count(needle)==1
 p.write_text(original.replace(needle,'{{values.absent}} FR Lohn.'));code,r=verdict();assert code!=0 and 'commerceProduction.served' in r['results']['de']['placeholderMismatch']
 print(json.dumps({'catalogue_initial_conforme':True,'matiere_arabe_absente_detectee':True,'salaire_allemand_mal_parametre_detecte':True,'production':False}))
