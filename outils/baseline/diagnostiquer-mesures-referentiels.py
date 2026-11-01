#!/usr/bin/env python3
"""Compare en lecture seule la capture reçue, les anciennes attentes et la source.

Ne réécrit ni baseline, ni observation, ni vérificateur. Aucune connexion base.
Ce rapport ne remplace pas le verdict de verifier-referentiels.py.
"""
import argparse,hashlib,json,re,subprocess,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
GENERATEURS={
 'ordres_couts':('generer_ordres_couts.py','--empreinte'),
 'ressources_economie':('generer_ordres_couts.py','--ressources-empreinte'),
 'postes_nommes_regles':('generer_postes_nommes.py','--empreinte'),
 'pa_bonus_differes':('generer_pa_bonus_differes.py','--empreinte'),
 'villes':('generer_villes.py','--empreinte'),
}

def diagnostiquer(mesures,provenance):
    p=Path(mesures);lignes=json.loads(p.read_text());meta=json.loads(Path(provenance).read_text())
    if meta.get('format')!='HG_RELAIS_CANONIQUE_219_V1' or not meta.get('snapshot'):
        raise ValueError('Provenance canonique requise')
    if len(lignes)!=5 or {x['table_name'] for x in lignes}!=set(GENERATEURS):
        raise ValueError('Cinq mesures exactes requises, aucune valeur inventée')
    attentes=json.loads((R/'outils/baseline/referentiels.json').read_text())['empreintes']['miroirs'];resultats=[]
    for x in lignes:
        if type(x['lignes']) is not int or x['lignes']<0 or any(not re.fullmatch('[a-f0-9]{16}',str(x[k])) for k in ('posee','reelle')):
            raise ValueError('Mesure invalide')
        nom=x['table_name'];generateur,option=GENERATEURS[nom]
        calculee=subprocess.check_output([sys.executable,str(R/'outils/generateurs'/generateur),option],cwd=R,text=True).strip()
        if not re.fullmatch('[a-f0-9]{16}',calculee):raise ValueError('Sortie générateur invalide')
        historique=attentes[nom]
        resultats.append({'table':nom,'lignes_capturees':x['lignes'],'generateur_actuel':calculee,
                          'contenu_capture':x['reelle'],'sentinelle_capturee':x['posee'],
                          'attente_historique':historique['data_js'],
                          'ancienne_mesure_contenu':historique['reelle'],
                          'contenu_concordant':calculee==x['reelle'],
                          'sentinelle_concordante':x['posee']==x['reelle'],
                          'mesure_versionnee_perimee':historique['reelle']!=x['reelle'] or historique['lignes']!=x['lignes']})
    return {'lecture_seule':True,'controle_global_non_modifie':True,'provenance':meta,
            'mesures_source_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'resultats':resultats}

if __name__=='__main__':
    a=argparse.ArgumentParser(description=__doc__);a.add_argument('mesures');a.add_argument('provenance');o=a.parse_args()
    print(json.dumps(diagnostiquer(o.mesures,o.provenance),ensure_ascii=False,indent=2))
