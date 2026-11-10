"""Contre-épreuves de l'auditeur existant, copies temporaires sans accès extérieur."""
from pathlib import Path
import tempfile,shutil,subprocess,json
R=Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='hg-i18n-contre-')as tmp:
 t=Path(tmp);(t/'outils/audits').mkdir(parents=True);(t/'i18n').mkdir()
 shutil.copy(R/'outils/audits/audit-i18n-editorial.cjs',t/'outils/audits')
 for f in (R/'i18n').glob('*.js'):shutil.copy(f,t/'i18n'/f.name)
 def execute():
  p=subprocess.run(['node',str(t/'outils/audits/audit-i18n-editorial.cjs')],text=True,capture_output=True)
  return p.returncode,json.loads(p.stdout)
 code,_=execute();assert code==0
 p=t/'i18n/inventory-ui-resources.js';original=p.read_text()
 needle='    "consume": "Konsumieren",';assert original.count(needle)==1
 p.write_text(original.replace(needle,''));code,data=execute();assert code!=0 and 'inventoryUi.consume'in data['results']['de']['missing']
 p.write_text(original.replace('Läuft an Tag {{values.day}} ab','Läuft an Tag {{values.absent}} ab'))
 code,data=execute();assert code!=0 and 'inventoryUi.expiresDay'in data['results']['de']['placeholderMismatch']
 print(json.dumps({'original_conforme':True,'cle_supprimee_detectee':True,'variable_renommee_detectee':True,'production':False}))
