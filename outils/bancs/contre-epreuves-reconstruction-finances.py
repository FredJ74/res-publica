#!/usr/bin/env python3
"""Reinjecte des pertes/duplications dans des copies, jamais dans les sources ni en production.
Les empreintes des definitions futures sont recalculees DANS LA COPIE MUTANTE pour que
la contre-epreuve atteigne le comportement metier, sans echouer seulement sur la garde DDL.
"""
import hashlib,json,re,shutil,subprocess,sys,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
CAS=[
 ('fraction de centime acceptee','20261017090342_precision_monetaire_reconstruction.sql','VALUE=trunc(VALUE,2)','true','centime invalide accepte'),
 ('loyer repaye le meme jour','20261017090621_loyers_banque_prioritaire_atomiques.sql',"IF (v_data ->> 'jourPaiement') = v_jour THEN","IF false THEN",'AssertionError'),
 ('loyer preleve malgre fonds insuffisants','20261017090621_loyers_banque_prioritaire_atomiques.sql','IF v_banque + greatest(0,coalesce(v_liquide,0)) < v_prix THEN','IF false THEN','AssertionError'),
 ('liquide prioritaire au lieu de banque','20261017090621_loyers_banque_prioritaire_atomiques.sql','v_debit_banque:=least(v_prix,v_banque);','v_debit_banque:=greatest(0,v_prix-greatest(0,coalesce(v_liquide,0)));','AssertionError'),
 ('corps de don modifiable apres confirmation','20261017090721_receptions_dons_atomiques_et_revisions.sql',"IF v_recu.corps IS DISTINCT FROM v_corps THEN","IF false THEN",'meme UUID accepte un autre corps'),
 ('credit du don perdu apres marquage','20261017090721_receptions_dons_atomiques_et_revisions.sql','SET arg=coalesce(arg,0)+v_total','SET arg=coalesce(arg,0)','don_credit_non_applique'),
 ('ancienne sauvegarde autorisee a toucher les soldes','20261017091428_garde_sauvegardes_financieres.sql','IF NOT v_acte_financier THEN','IF false THEN','ancienne sauvegarde a ecrase le solde'),
 ('bois rachete au mauvais prix','20261017091745_bois_imprimerie_transaction_atomique.sql','prix:=round(prix*1.10,2)','prix:=round(prix*1.00,2)','AssertionError'),
 ('bois non retire de inventaire','20261017091745_bois_imprimerie_transaction_atomique.sql','r:=public.inventaire_sauver_revision(p_personnage,v.inventory_revision,inv);',"r:='{\"ok\":true}'::jsonb;",'bois_mouvement_non_applique'),
]
res=[]
for nom,fichier,avant,apres,erreur in CAS:
 with tempfile.TemporaryDirectory(prefix='hg-contre-finances-') as t:
  d=Path(t);(d/'outils/bancs').mkdir(parents=True);(d/'baseline').symlink_to(ROOT/'baseline',target_is_directory=True)
  shutil.copytree(ROOT/'migrations',d/'migrations')
  bench='banc-reconstruction-finances-local.py';shutil.copy2(ROOT/'outils/bancs'/bench,d/'outils/bancs'/bench)
  p=d/'migrations'/fichier;s=p.read_text();assert s.count(avant)==1,(nom,s.count(avant))
  modifie=s.replace(avant,apres)
  # Le coutour de test autorise sa propre definition mutante ; pas la production.
  for corps in re.findall(r'AS \$function\$(.*?)\$function\$;',s,re.S):
   if avant in corps:
    modifie=modifie.replace(hashlib.md5(corps.encode()).hexdigest(),hashlib.md5(corps.replace(avant,apres).encode()).hexdigest())
  p.write_text(modifie)
  proc=subprocess.run([sys.executable,str(d/'outils/bancs'/bench)],capture_output=True,text=True,timeout=90)
  sortie=proc.stdout+proc.stderr;ok=proc.returncode!=0 and erreur in sortie
  res.append({'cas':nom,'regression_detectee':ok,'code':proc.returncode})
  print(('OK ' if ok else 'ECHEC ')+nom,flush=True)
  if not ok:print(sortie[-1800:])
print(json.dumps(res,ensure_ascii=False))
raise SystemExit(0 if all(r['regression_detectee'] for r in res) else 1)
