"""Contre-épreuves réelles de l'auditeur, copies temporaires, aucune donnée joueur."""
from pathlib import Path
import tempfile,shutil,subprocess,json
R=Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='hg-gestion-contre-') as d:
 t=Path(d);(t/'outils/audits').mkdir(parents=True);shutil.copytree(R/'i18n',t/'i18n');shutil.copy(R/'outils/audits/audit-i18n-editorial.cjs',t/'outils/audits')
 def verdict():
  p=subprocess.run(['node',str(t/'outils/audits/audit-i18n-editorial.cjs')],capture_output=True,text=True)
  return p.returncode,json.loads(p.stdout)
 assert verdict()[0]==0
 p=t/'i18n/commerce-management-resources.js';original=p.read_text();needle='        "stockMax": "Max. Bestand",';assert original.count(needle)==1
 p.write_text(original.replace(needle,''));code,x=verdict();assert code!=0 and 'commercepj.col.stockMax' in x['results']['de']['missing'];p.write_text(original)
 p=t/'i18n/administration-economy-resources.js';original=p.read_text();needle='Notartermin am {{values.date}}';assert original.count(needle)==1
 p.write_text(original.replace(needle,'Notartermin am {{values.absent}}'));code,x=verdict();assert code!=0 and 'administrationEconomy.directLandPurchase' in x['results']['de']['placeholderMismatch']
 print(json.dumps({'original_conforme':True,'colonne_stock_allemande_absente_detectee':True,'date_notaire_invalide_detectee':True,'production':False}))
