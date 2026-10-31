#!/usr/bin/env python3
"""Raccorde les huit générateurs existants aux seeds du monde neuf.

Les valeurs viennent exclusivement des générateurs de data.js. Aucune lecture
de joueur, aucune mise à jour d'empreinte observée, aucun accès distant.
"""
import hashlib,json,subprocess,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
GENERATEURS={
 'villes':('generer_villes.py','--sql','pays,ville,nom,est_capitale,rang'),
 'ordres_couts':('generer_ordres_couts.py','--sql','fn,pa,cost'),
 'pa_bonus_differes':('generer_pa_bonus_differes.py','--sql','source,montant'),
 'postes_nommes_regles':('generer_postes_nommes.py','--sql','poste_id,label,nomme_par,scope,autorite_scope'),
 'ressources_economie':('generer_ordres_couts.py','--ressources-sql','cle,prix_base,prix_achat_fournisseur,plafond,source'),
 'recettes_militaires':('generer_recettes_militaires.py','--sql','produit,label,materiaux,pa,produit_par_lot,type_objet,sous_type,prix_pnj,capacite'),
 'infractions':('generer_infractions.py','--sql','id,libelle,categorie,jours_reference,amende_reference,detect_rate,bareme_propre,detectable'),
 'infractions_categories':('generer_infractions.py','--sql-categories','id,libelle,jours_reference,amende_reference'),
}

def rendre(verifier=False):
    b=R/'baseline/seeds';p=b/'INVENTAIRE.json';inv=json.loads(p.read_text());sorties={}
    for table,(nom,option,colonnes) in GENERATEURS.items():
        valeurs=subprocess.check_output([sys.executable,str(R/'outils/generateurs'/nom),option],cwd=R,text=True).strip()
        if not valeurs.startswith('('):raise ValueError('VALUES du générateur attendues : '+table)
        sorties[table]='-- Généré depuis data.js par outils/generateurs/'+nom+' '+option+'.\n-- Ne pas retoucher ; régénérer avec outils/baseline/regenerer-seeds-miroirs.py.\nINSERT INTO public.'+table+' ('+colonnes+') VALUES\n'+valeurs+'\nON CONFLICT DO NOTHING;\n'
    # Tous les générateurs ont réussi AVANT le premier fichier écrit.
    if verifier:
        for table,sql in sorties.items():
            if (b/('95_a-regenerer/'+table+'.sql')).read_text()!=sql:
                raise ValueError('Seed miroir différent du générateur : '+table)
        print('8 seeds conformes aux générateurs réexécutés, aucune écriture.')
        return
    for table,sql in sorties.items():
        cle='95_a-regenerer/'+table+'.sql';(b/cle).write_text(sql)
        inv['fichiers'][cle]=hashlib.md5(sql.encode()).hexdigest()
    inv['miroirs_generes']={t:{'generateur':g[0],'option':g[1]} for t,g in GENERATEURS.items()}
    p.write_text(json.dumps(inv,ensure_ascii=False,indent=1,sort_keys=True)+'\n')
    print('8 seeds régénérés depuis leurs sources, aucune observation distante modifiée.')

if __name__=='__main__':rendre('--verifier' in sys.argv)
