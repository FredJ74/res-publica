#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GENERATEUR DU MIROIR DES REGLES DE NOMINATION (chantier « autorite des postes », 15 sept. 2026).

Meme doctrine que les autres miroirs du depot : le serveur doit savoir QUI a le droit de nommer
QUOI, sinon il ne peut pas verifier une nomination -- et le navigateur reste libre de pretendre
qu'il en a le droit. On ne recopie pas POSTES_NOMMES_EXCLUSIFS a la main : on charge le VRAI
data.js dans JavaScriptCore et on capture la table telle que le jeu la lit.

Sorties :
  python3 outils/generateurs/generer_postes_nommes.py            -> resume
  python3 outils/generateurs/generer_postes_nommes.py --sql      -> les VALUES
  python3 outils/generateurs/generer_postes_nommes.py --empreinte

REJOUER apres toute modification de POSTES_NOMMES_EXCLUSIFS (ajout d'un poste, changement de
nommePar ou de scope).
"""
import hashlib, json, os, subprocess, sys, tempfile

JSC = "/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc"
def _racine():
    """La racine du depot, trouvee en REMONTANT jusqu'a data.js, et non en
    comptant des niveaux de repertoire. Le comptage a casse les HUIT generateurs
    au chantier 2H : ils vivaient dans .scratch/, ou deux dirname suffisaient ;
    passes dans outils/generateurs/, les deux memes dirname rendaient outils/, et
    chacun cherchait outils/data.js. Aucun ne pouvait plus charger le jeu --
    c'est pour cela que onze miroirs ont ete semes par copie de la base au
    chantier 2E au lieu d'etre regeneres. Un repere ne se decale pas."""
    d = os.path.dirname(os.path.abspath(__file__))
    while d != os.path.dirname(d):
        if os.path.exists(os.path.join(d, "data.js")):
            return d
        d = os.path.dirname(d)
    raise SystemExit("racine du depot introuvable : aucun data.js en remontant")


RACINE = _racine()

EXTRACTEUR = """
load('%s/data.js');
var sortie = [];
Object.keys(POSTES_NOMMES_EXCLUSIFS).forEach(function (id) {
  var r = POSTES_NOMMES_EXCLUSIFS[id];
  sortie.push({ poste_id: id, label: r.label || id, nomme_par: r.nommePar || null,
                scope: r.scope || 'pays',
                // autoriteScope n'etait PAS extrait, et la table a pourtant la
                // colonne. poste_autorite_de lit coalesce(autorite_scope, scope) :
                // regenerer le miroir mettait donc autorite_scope a NULL, le juge
                // retombait en scope='ville', et le ministre de la Justice (city
                // NULL) ne pouvait plus le nommer. Le juge est aujourd'hui le seul
                // poste a porter ce champ (data.js:7667). On emet NULL quand il est
                // absent, et surtout pas 'ville' : le coalesce ci-dessus fait deja
                // ce travail, et forcer une valeur changerait les seize autres.
                autorite_scope: r.autoriteScope || null });
});
sortie.sort(function (a, b) { return a.poste_id < b.poste_id ? -1 : 1; });
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
        print('ECHEC DE CHARGEMENT DE data.js :')
        print((p.stdout + p.stderr)[-2000:])
        sys.exit(1)
    return json.loads(p.stdout.strip().splitlines()[-1])


def texte(v):
    """NULL se rend par la chaine vide, jamais par « None ». Meme convention que
    coalesce(colonne, '') cote SQL -- c'est ce qui permet aux deux formules de
    donner le meme hachage."""
    return '' if v is None else str(v)


def empreinte(regles):
    """Porte sur les CINQ colonnes, et sur la valeur QUE LE MOTEUR LIT.

    Deux decisions, chacune payee par une mesure.

    1. CINQ colonnes, pas trois. L'ancienne formule ne couvrait que poste_id,
       nomme_par et scope : ni label, ni autorite_scope. Une empreinte qui
       ignore une colonne ne protege pas cette colonne, et c'est exactement
       comme cela que l'omission d'autorite_scope a pu vivre sans etre vue.

    2. autorite_scope est hache par sa valeur EFFECTIVE, `autorite_scope or
       scope`, parce que c'est ce que lit poste_autorite_de :
       coalesce(autorite_scope, scope). data.js ne declare autoriteScope que
       pour le juge ; la base, elle, porte les dix-sept valeurs. Hacher la
       valeur brute faisait donc diverger les deux cotes -- mesure du 6 octobre
       2026 : 2f2738f9a4e2ada6 contre 73985f702ae09796 -- pour une difference
       qui ne change RIEN au comportement, puisque les seize autres postes ont
       autorite_scope = scope (verifie ligne par ligne en base). Sur la valeur
       effective, les deux cotes rendent 73985f702ae09796.

       Une empreinte doit mesurer ce que le jeu lit. Sinon elle signale des
       ecarts qui n'existent pas, et on apprend a l'ignorer.

    Le pendant SQL est postes_nommes_regles_empreinte_reelle(), ecrite sur la
    meme chaine, la meme regle et le meme tri (poste_id COLLATE "C")."""
    corpus = '\n'.join('%s|%s|%s|%s|%s' % (r['poste_id'], texte(r['label']),
                                           texte(r['nomme_par']), texte(r['scope']),
                                           texte(r['autorite_scope'] or r['scope']))
                       for r in sorted(regles, key=lambda r: r['poste_id']))
    return hashlib.md5(corpus.encode('utf-8')).hexdigest()[:16]


def sql(regles):
    def q(v):
        return 'NULL' if v is None else "'" + str(v).replace("'", "''") + "'"
    lignes = ["  (%s, %s, %s, %s, %s)" % (q(r['poste_id']), q(r['label']), q(r['nomme_par']),
                                          q(r['scope']), q(r['autorite_scope']))
              for r in regles]
    return ',\n'.join(lignes)


if __name__ == '__main__':
    regles = extraire()
    if '--sql' in sys.argv:
        print(sql(regles))
    elif '--empreinte' in sys.argv:
        print(empreinte(regles))
    else:
        print('postes nommes lus : %d' % len(regles))
        for r in regles:
            print('  %-24s nomme par %-14s scope %s' % (r['poste_id'], r['nomme_par'], r['scope']))
        print('empreinte : %s' % empreinte(regles))
