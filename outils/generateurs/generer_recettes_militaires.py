#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""GENERATEUR DU MIROIR SQL DES RECETTES MILITAIRES (chantier 4D, 6 octobre 2026).

POURQUOI CE MIROIR EXISTE. Jusqu'ici, le serveur n'avait aucune idee de ce qu'est
une recette militaire. La commande du Ministre de la Defense partait en INSERT
PostgREST direct, et la seule garde etait une policy `acteur_identifie()` : tout
joueur authentifie pouvait commander n'importe quel produit, pour n'importe quel
pays, en n'importe quelle quantite -- y compris un `produit` qui n'existe pas.
Le poste `min_def` n'etait verifie QUE dans le navigateur, trois fois, ce qui ne
vaut rien.

Pour fermer cette porte, le serveur doit pouvoir repondre a une question :
« ce produit appartient-il au catalogue ? ». Il lui faut donc le catalogue --
mais le recopier a la main en SQL aurait cree une TROISIEME copie, apres celle
du navigateur et celle du cron. C'est exactement ce que les chantiers 4B et 4C
ont passe leur temps a defaire.

Ce miroir est donc GENERE depuis la source canonique, comme les huit autres :
    plateau-effort-guerre.js, RECETTES_MILITAIRES  ->  public.recettes_militaires
et surveille par une empreinte, comme les quatre autres miroirs.

CE QU'IL PORTE, ET CE QU'IL NE PORTE PAS. Les neuf colonnes couvrent ce dont le
serveur peut avoir besoin pour decider : le produit, son libelle, ses matieres,
son cout en PA, sa taille de lot, et la forme de l'objet produit (type, sous-type,
prix PNJ, capacite). Il ne porte ni `desc`, ni `icon`, ni `imageUrl` : ce sont des
elements d'interface, et le serveur n'a pas a en connaitre.

REJOUER apres toute modification de RECETTES_MILITAIRES (ajout d'un produit,
changement d'une recette, d'un PA ou d'un prix PNJ).

Usage :
    python3 outils/generateurs/generer_recettes_militaires.py
    python3 outils/generateurs/generer_recettes_militaires.py --sql
    python3 outils/generateurs/generer_recettes_militaires.py --empreinte
"""
import hashlib, json, os, subprocess, sys, tempfile

JSC = "/System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Helpers/jsc"


def _racine():
    """La racine du depot, trouvee en REMONTANT jusqu'a data.js. Meme note que
    les huit autres generateurs : compter des niveaux de repertoire les a tous
    casses au chantier 2H."""
    d = os.path.dirname(os.path.abspath(__file__))
    while d != os.path.dirname(d):
        if os.path.exists(os.path.join(d, "data.js")):
            return d
        d = os.path.dirname(d)
    raise SystemExit("racine du depot introuvable : aucun data.js en remontant")


RACINE = _racine()

EXTRACTEUR = """
load('%s/plateau-effort-guerre.js');
var sortie = [];
Object.keys(RECETTES_MILITAIRES).forEach(function (id) {
  var r = RECETTES_MILITAIRES[id];
  sortie.push({
    produit: id,
    label: r.label || id,
    materiaux: r.materiaux || {},
    // `pa` est ABSENT sur arme_de_poing et mitraillette, des deux cotes depuis
    // toujours : elles retombent sur le forfait PA_PRODUCTION_ARMURERIE. On emet
    // NULL plutot qu'une valeur inventee -- c'est l'absence qui porte le sens.
    pa: (r.pa === undefined || r.pa === null) ? null : r.pa,
    produit_par_lot: r.produitParLot || 1,
    type_objet: r.typeObjet || null,
    sous_type: r.sousType || null,
    prix_pnj: (r.prixPnj === undefined || r.prixPnj === null) ? null : r.prixPnj,
    capacite: (r.capacite === undefined || r.capacite === null) ? null : r.capacite
  });
});
sortie.sort(function (a, b) { return a.produit < b.produit ? -1 : 1; });
print(JSON.stringify(sortie));
""" % RACINE


def extraire():
    f = tempfile.NamedTemporaryFile('w', suffix='.js', delete=False, encoding='utf-8')
    f.write(EXTRACTEUR)
    f.close()
    try:
        p = subprocess.run([JSC, f.name], capture_output=True, text=True, timeout=120)
    finally:
        os.unlink(f.name)
    if p.returncode != 0:
        print('ECHEC DE CHARGEMENT DE plateau-effort-guerre.js :')
        print((p.stdout + p.stderr)[-2000:])
        sys.exit(1)
    return json.loads(p.stdout.strip().splitlines()[-1])


def texte(v):
    """NULL se rend par la chaine vide dans l'empreinte, jamais par « None ».
    Meme convention que coalesce(colonne, '') cote SQL : c'est ce qui permet aux
    deux formules de donner le meme hachage."""
    return '' if v is None else str(v)


def materiaux_json(m):
    """Le litteral jsonb du seed. Trie par cle pour que deux generations du meme
    contenu produisent le meme texte."""
    return json.dumps(m, sort_keys=True, separators=(',', ':'), ensure_ascii=False)


def materiaux_plat(m):
    """La forme hachee : « bois:1,metal:2 », triee par point de code.

    SURTOUT PAS jsonb::text DES DEUX COTES. PostgreSQL ordonne les cles d'un
    jsonb par LONGUEUR puis par octets, et intercale des espaces : les matieres
    de la tenue de camouflage sortent « charbon, textile, fruits_legumes » cote
    base contre « charbon, fruits_legumes, textile » cote Python. Les deux
    empreintes auraient diverge sur un contenu rigoureusement identique, et le
    controle aurait signale une derive qui n'existe pas. On hache donc une forme
    PLATE, construite a l'identique des deux cotes."""
    return ','.join('%s:%s' % (k, m[k]) for k in sorted(m))


def empreinte(recettes):
    """Porte sur les NEUF colonnes. Le pendant SQL est
    recettes_militaires_empreinte_reelle(), ecrite sur la meme chaine, la meme
    forme PLATE des matieres (voir materiaux_plat) et le meme tri
    (produit COLLATE "C")."""
    corpus = '\n'.join('%s|%s|%s|%s|%s|%s|%s|%s|%s' % (
        r['produit'], texte(r['label']), materiaux_plat(r['materiaux']),
        texte(r['pa']), texte(r['produit_par_lot']), texte(r['type_objet']),
        texte(r['sous_type']), texte(r['prix_pnj']), texte(r['capacite']))
        for r in sorted(recettes, key=lambda r: r['produit']))
    return hashlib.md5(corpus.encode('utf-8')).hexdigest()[:16]


def sql(recettes):
    def q(v):
        return 'NULL' if v is None else "'" + str(v).replace("'", "''") + "'"

    def n(v):
        return 'NULL' if v is None else str(int(v))

    lignes = ["  (%s, %s, %s::jsonb, %s, %s, %s, %s, %s, %s)" % (
        q(r['produit']), q(r['label']), q(materiaux_json(r['materiaux'])),
        n(r['pa']), n(r['produit_par_lot']), q(r['type_objet']),
        q(r['sous_type']), n(r['prix_pnj']), n(r['capacite']))
        for r in recettes]
    return ',\n'.join(lignes)


if __name__ == '__main__':
    recettes = extraire()
    if '--sql' in sys.argv:
        print(sql(recettes))
    elif '--empreinte' in sys.argv:
        print(empreinte(recettes))
    else:
        print('recettes militaires lues : %d' % len(recettes))
        for r in recettes:
            print('  %-20s %-24s %-34s pa=%-4s lot=%s'
                  % (r['produit'], r['label'], materiaux_json(r['materiaux']),
                     texte(r['pa']) or '-', r['produit_par_lot']))
        print('empreinte : %s' % empreinte(recettes))
