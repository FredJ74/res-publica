#!/usr/bin/env python3
"""Prépare un SELECT de relais cohérent, ou valide son fichier privé. Aucune connexion.

Réutilise les quatre requêtes canoniques, leur contrôle global et le générateur
seeds. Les colonnes ci-dessous forment une liste blanche d'extraction de contenu,
pas un second schéma : aucun DDL n'en est produit. Les sources de téléversements
liées à des comptes ne figurent jamais parmi les lignes copiées.
"""
import argparse
import hashlib
from datetime import datetime
import json
import os
from pathlib import Path
import sys
import tempfile

R = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(R / 'outils/baseline'))
import rendre
import requetes
import seeds

# Colonnes authored constatées dans le catalogue privé et relues le 31 octobre.
# maj_le de ordres_generiques est omis : son DEFAULT now() appartient au monde neuf.
REFERENCES = {
 'locaux_loyers_referentiel': 'batiment:text piece:text ville:text prix:integer bonus_pop:integer bonus_inf:integer bonus_dis:integer label:text louable:boolean signature_serveur:boolean',
 'objets_achetables': 'ordre:text modele:text',
 'objets_modeles': 'id:text objet:jsonb',
 'ordres_generiques': 'fn:text taux_reussite:integer toujours_reussi:boolean effets:jsonb batiments:text[] poste_requis:text',
 'rue_noeuds_serveur': 'country:text city:text noeud:text voisins:text[]',
 'rue_sorties_batiments': 'country:text city:text noeud:text building:text',
 'scandales_predefinis': 'id:integer texte:text',
 'terrain_actions_regles': 'id:boolean data:jsonb',
 'terrains_referentiel': 'pays:text ville:text batiment:text surface:numeric prix_achat:numeric',
 'tracts_pnj_catalogue': 'pays:text ville:text building_id:text room_id:text nom:text car_vol:integer',
}
FORMAT = 'HG_RELAIS_CANONIQUE_219_V1'


def requete():
    cls = seeds.classification()
    for table in REFERENCES:
        if cls[table]['categorie'] == 'C' or cls[table]['strategie'] != 'seed_complet':
            raise ValueError('Table non autorisée pour ce relais : ' + table)
    colonnes = []
    for table, spec in REFERENCES.items():
        for rang, terme in enumerate(spec.split(), 1):
            nom, typ = terme.split(':')
            colonnes.append(dict(tbl=table, attname=nom, type=typ, attnum=rang))
    extraction = seeds.requete({'colonnes':colonnes, 'contraintes':[]}, sorted(REFERENCES))
    ctes = [nom + ' AS (' + sql.strip().rstrip(';') + ')' for nom, sql in requetes.EXPORTS.items()]
    ctes += ['controle AS (' + requetes.requete_controle_global().rstrip(';') + ')',
             'mesures_referentiels(table_name,lignes,posee,reelle) AS (' + json.loads((R/'outils/baseline/referentiels.json').read_text())['empreintes']['_requete_de_mesure'].strip().rstrip(';') + ')',
             'graines AS (' + extraction + ')',
             "registre AS (SELECT coalesce(jsonb_agg(jsonb_build_object('version',version,'name',name) ORDER BY version),'[]'::jsonb) AS lignes FROM supabase_migrations.schema_migrations)",
             "lignes AS (SELECT x.* FROM graines, jsonb_to_recordset(coalesce(nullif(export_seeds->'export_seeds','null'::jsonb),'[]'::jsonb)) AS x(tbl text,rang bigint,ligne text))",
             'cibles(tbl) AS (VALUES ' + requetes.litteral(REFERENCES) + ')']
    champs = ["'format','" + FORMAT + "'", "'snapshot',pg_current_snapshot()::text", "'releve_utc',timezone('UTC',now())::text"]
    champs += ["'" + n + "'," + n + '.' + n for n in requetes.EXPORTS]
    champs += ["'controle_global',controle.controle_global", "'registre',registre.lignes",
               "'referentiels_controle',(SELECT jsonb_agg(to_jsonb(m) ORDER BY table_name) FROM mesures_referentiels m)",
               "'export_seeds',coalesce(nullif(graines.export_seeds->'export_seeds','null'::jsonb),'[]'::jsonb)",
               "'seeds_controle',(SELECT jsonb_agg(jsonb_build_object('table',c.tbl,'lignes',(SELECT count(*) FROM lignes l WHERE l.tbl=c.tbl),'empreinte',(SELECT md5(coalesce(string_agg(l.ligne,'|' ORDER BY l.rang),'')) FROM lignes l WHERE l.tbl=c.tbl)) ORDER BY c.tbl) FROM cibles c)"]
    return ('-- Lecture seule : une instruction, un snapshot, aucune donnée PJ.\nWITH ' + ',\n'.join(ctes) +
            '\nSELECT jsonb_build_object(' + ',\n'.join(champs) + ') AS relais_canonique_219\nFROM ' +
            ','.join(list(requetes.EXPORTS) + ['controle','graines','registre']) + ';\n')


def verifier_ligne_seed(ligne):
    # Une empreinte de transport n'autorise jamais à exécuter un autre ordre.
    # Seuls les INSERT de littéraux émis par seeds.requete sont admissibles.
    from pglast import parse_sql, ast
    try:
        arbres = parse_sql(ligne['ligne'])
    except Exception:
        raise ValueError('Ligne de seed SQL invalide') from None
    if len(arbres) != 1 or not isinstance(arbres[0].stmt, ast.InsertStmt):
        raise ValueError('Ligne de seed hors contrat INSERT')
    q = arbres[0].stmt
    attendues = [x.split(':')[0] for x in REFERENCES[ligne['tbl']].split()]
    if q.relation.schemaname != 'public' or q.relation.relname != ligne['tbl'] or [x.name for x in (q.cols or ())] != attendues:
        raise ValueError('Cible ou colonnes de seed hors liste blanche')
    valeurs = q.selectStmt.valuesLists if q.selectStmt else None
    extras = any(getattr(q.selectStmt, k, None) for k in ['withClause','sortClause','lockingClause','limitOffset','limitCount','fromClause','whereClause','op']) if q.selectStmt else True
    if q.withClause or q.onConflictClause or q.returningList or extras or not valeurs or len(valeurs) != 1 or len(valeurs[0]) != len(attendues) or any(not isinstance(x, ast.A_Const) for x in valeurs[0]):
        raise ValueError('Seed non littéral ou commande supplémentaire')


def valider(document):
    if isinstance(document, list) and len(document) == 1:
        document = document[0]
    if isinstance(document, dict) and 'relais_canonique_219' in document:
        document = document['relais_canonique_219']
    if not isinstance(document, dict) or document.get('format') != FORMAT:
        raise ValueError('Format de relais absent : aucune ancienne enveloppe réparée implicitement')
    if not document.get('snapshot') or not document.get('releve_utc'):
        raise ValueError('Provenance temporelle absente')
    with tempfile.TemporaryDirectory(prefix='hg-relais-verification-') as d:
        for nom in rendre.EXPORTS_ATTENDUS:
            (Path(d)/(nom+'.json')).write_text(json.dumps({nom:document.get(nom)}))
        exp, _ = rendre.charger_exports(d)
    for f in exp['fonctions']:
        if hashlib.md5(f['definition'].encode()).hexdigest() != f['empreinte']:
            raise ValueError('Empreinte de fonction contradictoire')
    ctl = document['controle_global']
    for cle in ['colonnes_de_vues']:
        if cle not in ctl['totaux']:
            raise ValueError('Contrôle global incomplet : ' + cle)
    for cle in ['fonctions_security_invoker','tables_sans_rls']:
        if cle not in ctl['securite']:
            raise ValueError('Contrôle global incomplet : ' + cle)
    # Chaque chiffre est confronté à un autre bloc du même snapshot, jamais
    # remplacé par ce qu'attend le dépôt.
    mesures = {
        'tables':len({c['tbl'] for c in exp['colonnes'] if c['kind']=='r'}),
        'colonnes':len(exp['colonnes']), 'colonnes_de_vues':sum(c['kind']=='v' for c in exp['colonnes']),
        'contraintes':len(exp['contraintes']), 'index':len(exp['index']),
        'fonctions':len(exp['fonctions']), 'sequences':len(exp['sequences']),
        'vues':len(exp['vues']), 'triggers':len(exp['triggers']), 'policies':len(exp['policies']),
    }
    if any(ctl['totaux'].get(cle) != n for cle,n in mesures.items()):
        raise ValueError('Comptes structure/contrôle global contradictoires')
    if datetime.fromisoformat(document['releve_utc']) != datetime.fromisoformat(ctl['releve_le']):
        raise ValueError('Relevés non simultanés : aucune promotion du baseline')
    refs = document.get('referentiels_controle', [])
    noms_refs = {'ordres_couts','ressources_economie','pa_bonus_differes','postes_nommes_regles','villes'}
    if len(refs) != len(noms_refs) or {x.get('table_name') for x in refs} != noms_refs:
        raise ValueError('Mesure des référentiels incomplète')
    registre = document['registre']
    versions = [x['version'] for x in registre]
    if len(versions) != len(set(versions)) or len(versions) != ctl['registre']['entrees']:
        raise ValueError('Registre incohérent')
    if max(versions,default=None) != ctl['registre']['derniere_version']:
        raise ValueError('Dernière version du registre contradictoire')
    controles = document['seeds_controle']
    if len(controles) != len(REFERENCES) or {x['table'] for x in controles} != set(REFERENCES):
        raise ValueError('Manifeste des seeds incomplet ou dupliqué')
    lignes = document['export_seeds']
    if any(x['tbl'] not in REFERENCES for x in lignes):
        raise ValueError('Ligne hors liste blanche de seeds')
    for ligne in lignes:verifier_ligne_seed(ligne)
    for c in controles:
        ls = sorted((x for x in lignes if x['tbl'] == c['table']),key=lambda x:x['rang'])
        if len(ls) != c['lignes'] or len({x['rang'] for x in ls}) != len(ls):
            raise ValueError('Compte/rangs de seed incohérents')
        emp = hashlib.md5('|'.join(x['ligne'] for x in ls).encode()).hexdigest()
        if emp != c['empreinte']:
            raise ValueError('Empreinte de seed incohérente')
    return document


def marqueur_git_actif(repertoire):
    """Fichier worktree ou métadonnées présents ; un dossier vide n'est pas un dépôt.

    Certains environnements posent un .git vide en lecture seule à leur racine.
    Ne pas contourner un dépôt réel, un lien symbolique ou un marqueur illisible.
    """
    marqueur = Path(repertoire) / '.git'
    if marqueur.is_symlink() or marqueur.is_file():
        return True
    if marqueur.is_dir():
        try:
            return next(marqueur.iterdir(), None) is not None
        except OSError:
            return True
    return False


def materialiser(document, destination):
    d = valider(document)
    destination = Path(destination).resolve()
    if any(marqueur_git_actif(p) for p in (destination,*destination.parents)):
        raise ValueError('Exports privés interdits dans un dépôt ou worktree Git')
    # Aucun export reçu n'est retouché ni écrasé. Les fichiers partiels ne sont
    # pas une livraison valide : le chargeur requiert les quatre catégories.
    destination.mkdir(mode=0o700, parents=True, exist_ok=False)
    canon = destination/'canoniques';canon.mkdir(mode=0o700)
    fichiers = {canon/(n+'.json'):{n:d[n]} for n in rendre.EXPORTS_ATTENDUS}
    fichiers.update({destination/'controle_global.json':[{'controle_global':d['controle_global']}],
                     destination/'registre.json':d['registre'],
                     destination/'referentiels_controle.json':d['referentiels_controle'],
                     destination/'seeds.json':{'export_seeds':d['export_seeds'],'seeds_controle':d['seeds_controle']},
                     destination/'provenance.json':{k:d[k] for k in ['format','snapshot','releve_utc']}})
    for p,valeur in fichiers.items():
        fd=os.open(p,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
        with os.fdopen(fd,'w') as f:json.dump(valeur,f,ensure_ascii=False)
    return len(fichiers)


def main():
    a = argparse.ArgumentParser(description=__doc__)
    g = a.add_mutually_exclusive_group(required=True)
    g.add_argument('--sql', action='store_true')
    g.add_argument('--verifier', type=Path)
    a.add_argument('--sortie-privee',type=Path,help='Seulement avec --verifier ; dossier neuf hors de tout dépôt Git')
    o = a.parse_args()
    if o.sql and o.sortie_privee:a.error('--sortie-privee requiert --verifier')
    if o.sql:
        print(requete(), end='')
    else:
        d = valider(json.loads(o.verifier.read_text()))
        if o.sortie_privee:materialiser(d,o.sortie_privee)
        print(json.dumps({'valide':True,'tables_seeds':len(d['seeds_controle']), 'versions':len(d['registre']),
                          'limite':'Validation de transport ; reconstruction et revue du contenu toujours requises.'}))

if __name__ == '__main__':
    main()
