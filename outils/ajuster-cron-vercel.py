#!/usr/bin/env python3
"""Maintient le cron quotidien a minuit Europe/Paris, sans nouvel appel Vercel."""
import datetime,json
from pathlib import Path
from zoneinfo import ZoneInfo

def planification_minuit_paris(instant):
    if instant.tzinfo is None:
        raise ValueError('instant UTC/zone requis')
    heures=instant.astimezone(ZoneInfo('Europe/Paris')).utcoffset().total_seconds()/3600
    if heures not in (1,2):
        raise ValueError('decalage Paris inattendu')
    return f'0 {24-int(heures)} * * *'

def ajuster(chemin,instant=None):
    config=json.loads(chemin.read_text())
    cron=[c for c in config.get('crons',[]) if c.get('path')=='/api/cron-minuit']
    if len(cron)!=1:
        raise ValueError('cron-minuit unique requis')
    souhaite=planification_minuit_paris(instant or datetime.datetime.now(datetime.timezone.utc))
    if cron[0]['schedule']==souhaite:
        return False
    cron[0]['schedule']=souhaite
    chemin.write_text(json.dumps(config,indent=2,ensure_ascii=False)+'\n')
    return True

if __name__=='__main__':
    print('Cron ajuste.' if ajuster(Path(__file__).resolve().parents[1]/'vercel.json') else 'Cron deja conforme, aucun commit necessaire.')
