#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Controle de completude et de fidelite du baseline COMPLET (chantier 2E).

Confronte trois sources, et les trois doivent concorder :

  baseline/CONTROLE-GLOBAL.json   ce que la BASE dit, pour tout le schema
  baseline/domaines/*/MANIFESTE.json  ce qui a ete RENDU, domaine par domaine
  baseline/domaines/*/*.sql       ce qui est SUR DISQUE

QUATRE FAMILLES DE CONTROLE, QUI ECHOUENT INDEPENDAMMENT. Un baseline peut etre
structurellement parfait et fonctionnellement ouvert ; melanger les familles
permettrait a une regression de securite de passer derriere un total juste.

  1. STRUCTURE        tables, colonnes, contraintes, index, sequences, vues
  2. LOGIQUE SERVEUR  fonctions, vues, declencheurs
  3. SECURITE         SECURITY DEFINER, RLS, policies, droits
  4. SEEDS            application de la classification 2C

AUCUNE DIFFERENCE N'EST MASQUEE. Chaque total du catalogue doit se decomposer
exactement en « rendu » + « ecarte deliberement et nomme ». Un objet qui n'est
ni rendu ni nomme fait echouer le controle.

Usage :
    python3 outils/baseline/verifier-baseline.py
Code de sortie 0 si tout concorde, 1 sinon.

Cet outil n'accede pas a la base et n'ecrit rien.
"""

import csv
import glob
import hashlib
import json
import os
import re
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(os.path.dirname(ICI))
BASE = os.path.join(RACINE, "baseline")
DOM = os.path.join(BASE, "domaines")


def empreinte_liste(ingredients):
    """Recompose une empreinte globale a la maniere de PostgreSQL : tri par point
    de code -- ce qui est exactement ce que fait COLLATE "C" -- puis md5."""
    return hashlib.md5("|".join(sorted(ingredients)).encode("utf-8")).hexdigest()


def md5_fichier(chemin):
    with open(chemin, encoding="utf-8", newline="") as fh:
        return hashlib.md5(fh.read().encode("utf-8")).hexdigest()


def lire(chemin):
    with open(chemin, encoding="utf-8", newline="") as fh:
        return fh.read()


class Rapport:
    def __init__(self):
        self.pbs = {}

    def famille(self, nom):
        self.courante = nom
        self.pbs.setdefault(nom, [])
        print("\n%s" % nom)
        print("  " + "-" * 72)

    def verif(self, libelle, obtenu, attendu):
        ok = obtenu == attendu
        print("  %-42s %12s / %-12s %s" % (libelle, obtenu, attendu, "OK " if ok else "NON"))
        if not ok:
            self.pbs[self.courante].append("%s : baseline %s, base %s" % (libelle, obtenu, attendu))

    def emp(self, libelle, obtenu, attendu):
        ok = obtenu == attendu
        print("  %-42s %s %s" % (libelle, obtenu, "OK " if ok else "NON"))
        if not ok:
            print("  %-42s %s  (base)" % ("", attendu))
            self.pbs[self.courante].append("empreinte %s non conforme" % libelle)

    def note(self, texte):
        print("  %s" % texte)

    def anomalie(self, texte):
        self.pbs[self.courante].append(texte)


def famille_seeds(r, rendues):
    """4. SEEDS -- application de la classification 2C.

    Famille isolee dans sa propre fonction : elle peut renoncer tot (seeds pas
    encore produits) sans faire sauter les controles qui la suivent.
    """
    r.famille("4. SEEDS -- application de la classification 2C")
    chemin_csv = os.path.join(BASE, "classification-donnees.csv")
    lignes = list(csv.DictReader(open(chemin_csv, encoding="utf-8"), delimiter=";"))
    par_strat = {}
    for l in lignes:
        par_strat.setdefault(l["strategie"], []).append(l["table"])

    for strat in sorted(par_strat):
        tables = sorted(par_strat[strat])
        if strat == "hors_baseline":
            dedans = [t for t in tables if t in rendues]
            print("  %-26s %3d tables  | %d recreee(s) a tort %s"
                  % (strat, len(tables), len(dedans), "OK " if not dedans else "NON"))
            for t in dedans:
                r.anomalie("table hors_baseline recreee : " + t)
            continue
        absentes = [t for t in tables if t not in rendues]
        print("  %-26s %3d tables  | %d structure(s) manquante(s) %s"
              % (strat, len(tables), len(absentes), "OK " if not absentes else "NON"))
        for t in absentes:
            r.anomalie("table %s (%s) absente de la structure du baseline" % (t, strat))

    rep_seeds = os.path.join(BASE, "seeds")
    if not os.path.isdir(rep_seeds):
        r.note("")
        r.note("aucun repertoire baseline/seeds/ : les seeds ne sont pas encore produits.")
        r.anomalie("baseline/seeds/ absent : le contenu initial n'est pas constitue")
        return

    diffs = json.load(open(os.path.join(BASE, "DIFFERENCES-DELIBEREES.json"), encoding="utf-8"))
    inv = json.load(open(os.path.join(rep_seeds, "INVENTAIRE.json"), encoding="utf-8"))
    par_table = {}
    for chemin in sorted(glob.glob(os.path.join(rep_seeds, "*", "*.sql"))):
        tbl = os.path.basename(chemin)[:-4]
        rep = os.path.basename(os.path.dirname(chemin))
        inserts = sum(1 for l in lire(chemin).splitlines() if l.startswith("INSERT INTO "))
        par_table[tbl] = (rep, inserts, chemin)

    r.note("")
    attendues = {l["table"]: l for l in lignes
                 if l["strategie"] in ("seed_complet", "seed_filtre", "reconstruction_explicite")}
    r.verif("tables de la surface de seed couvertes", len(par_table), len(attendues))
    for t in sorted(attendues):
        if t not in par_table:
            r.anomalie("aucun fichier pour %s (%s)" % (t, attendues[t]["strategie"]))

    # Une table hors de la surface de seed ne doit porter AUCUN fichier : un
    # seed sur une table d'etat vivant ferait naitre un monde avec de la bêta.
    hors_surface = sorted(t for t in par_table if t not in attendues)
    r.verif("seeds sur une table hors surface", len(hors_surface), 0)
    for t in hors_surface:
        r.anomalie("seed present pour %s, classee %s"
                   % (t, next((l["strategie"] for l in lignes if l["table"] == t), "?")))

    # Les fichiers « a construire » et « a regenerer » ne doivent porter aucune
    # donnee : c'est tout leur propos.
    fautifs = [t for t, (rep, n, _) in par_table.items()
               if rep in ("95_a-regenerer", "99_a-construire") and n > 0]
    r.verif("fichiers TODO contenant des donnees", len(fautifs), 0)
    for t in fautifs:
        r.anomalie("le fichier TODO de %s contient des INSERT" % t)

    # Le nombre de lignes seedees doit correspondre au nombre de lignes de la
    # base, moins les exclusions DECLAREES. Une ligne qui disparait sans etre
    # declaree fait echouer le controle.
    exclusions = {t: v["ecartees"] for t, v in
                  diffs["lignes_exclues_des_seeds"].items() if not t.startswith("_")}
    ecarts = []
    for t, (rep, n, _) in sorted(par_table.items()):
        if rep in ("95_a-regenerer", "99_a-construire"):
            continue
        attendu = int(attendues[t]["lignes_actuelles"]) - exclusions.get(t, 0)
        if n != attendu:
            ecarts.append("%s : %d lignes seedees, %d attendues (base %s, exclusions declarees %d)"
                          % (t, n, attendu, attendues[t]["lignes_actuelles"], exclusions.get(t, 0)))
    r.verif("tables dont le nombre de lignes diverge", len(ecarts), 0)
    for e in ecarts:
        r.anomalie(e)

    print()
    for rep in sorted({v[0] for v in par_table.values()}):
        lot = {t: v for t, v in par_table.items() if v[0] == rep}
        print("  %-20s %2d tables %5d lignes d'INSERT"
              % (rep, len(lot), sum(v[1] for v in lot.values())))

    alteres = [c for c, h in sorted(inv["fichiers"].items())
               if not os.path.exists(os.path.join(rep_seeds, c))
               or md5_fichier(os.path.join(rep_seeds, c)) != h]
    r.note("")
    r.verif("fichiers de seed conformes a leur empreinte",
            len(inv["fichiers"]) - len(alteres), len(inv["fichiers"]))
    for a in alteres:
        r.anomalie("fichier de seed altere depuis le rendu : " + a)



def main():
    ctl = json.load(open(os.path.join(BASE, "CONTROLE-GLOBAL.json"), encoding="utf-8"))
    att = ctl["attendu_dans_le_baseline"]
    tot, eca, emp = ctl["totaux"], ctl["ecartes"], ctl["empreintes"]

    mans, fichiers_par_dom = {}, {}
    for chemin in sorted(glob.glob(os.path.join(DOM, "*", "MANIFESTE.json"))):
        d = os.path.basename(os.path.dirname(chemin))
        mans[d] = json.load(open(chemin, encoding="utf-8"))
        fichiers_par_dom[d] = os.path.dirname(chemin)
    if not mans:
        print("ECHEC : aucun domaine rendu dans baseline/domaines/")
        return 1

    def tous(cle):
        for d in sorted(mans):
            for o in mans[d].get(cle, []):
                yield d, o

    def nb(cle):
        return sum(len(mans[d].get(cle, [])) for d in mans)

    r = Rapport()
    print("BASELINE COMPLET -- CONTROLE DE COMPLETUDE ET DE FIDELITE")
    print("base relevee le %s   |   %d domaines rendus" % (ctl["releve_le"], len(mans)))

    # ------------------------------------------------------------ 1. STRUCTURE
    r.famille("1. STRUCTURE                                    baseline / base")
    r.verif("tables", nb("tables"), att["tables"])
    r.verif("colonnes", sum(t["colonnes"] for _, t in tous("tables")), att["colonnes"])
    r.verif("contraintes", nb("contraintes"), att["contraintes"])
    r.verif("index autonomes", nb("index_autonomes"), att["index_autonomes"])
    r.verif("index portes par une contrainte", nb("index_portes"), att["index_portes"])
    r.verif("sequences (possedees + autonomes)", nb("sequences"), tot["sequences"])
    r.verif("  dont autonomes, creees explicitement", nb("sequences_autonomes"),
            sum(1 for _, s in tous("sequences") if not s["possedee"]))

    # Reconciliation : rien ne disparait. Chaque total du catalogue doit se
    # retrouver soit dans le baseline, soit dans la liste nommee des ecartes.
    r.note("")
    r.note("reconciliation catalogue = baseline + ecarte deliberement :")
    for cle, cat, bas in (("tables", "tables", "tables"),
                          ("contraintes", "contraintes", "contraintes"),
                          ("commentaires", "commentaires", "commentaires")):
        somme = att[bas] + eca[cat]
        ok = somme == tot[cle]
        print("    %-24s %5d rendus + %3d ecartes = %5d / %-5d %s"
              % (cle, att[bas], eca[cat], somme, tot[cle], "OK " if ok else "NON"))
        if not ok:
            r.anomalie("reconciliation %s : %d + %d != %d" % (cle, att[bas], eca[cat], tot[cle]))
    somme = att["colonnes"] + eca["colonnes"] + tot["colonnes_de_vues"]
    ok = somme == tot["colonnes"]
    print("    %-24s %5d rendues + %3d ecartees + %d de vues = %5d / %-5d %s"
          % ("colonnes", att["colonnes"], eca["colonnes"], tot["colonnes_de_vues"],
             somme, tot["colonnes"], "OK " if ok else "NON"))
    if not ok:
        r.anomalie("reconciliation colonnes impossible")

    r.note("")
    emp_col = empreinte_liste(t["nom"] + ":" + t["empreinte_catalogue"] for _, t in tous("tables"))
    r.emp("empreinte des colonnes", emp_col, emp["colonnes"])
    emp_kon = empreinte_liste(k["tbl"] + ":" + k["nom"] + ":" + k["empreinte"]
                              for _, k in tous("contraintes"))
    r.emp("empreinte des contraintes", emp_kon, emp["contraintes"])
    emp_idx = empreinte_liste(i["nom"] + ":" + i["empreinte"] for _, i in tous("index_autonomes"))
    r.emp("empreinte des index autonomes", emp_idx, emp["index"])

    # ------------------------------------------------------ 2. LOGIQUE SERVEUR
    r.famille("2. LOGIQUE SERVEUR                              baseline / base")
    r.verif("fonctions", nb("fonctions"), att["fonctions"])
    r.verif("vues", nb("vues"), att["vues"])
    r.verif("declencheurs", nb("triggers"), att["triggers"])

    doublons = {}
    for d, f in tous("fonctions"):
        doublons.setdefault(f["signature"], []).append(d)
    multi = {s: ds for s, ds in doublons.items() if len(ds) > 1}
    print("  %-42s %12d / %-12d %s" % ("fonctions presentes dans 2 domaines",
                                        len(multi), 0, "OK " if not multi else "NON"))
    for s, ds in sorted(multi.items())[:10]:
        r.anomalie("fonction dupliquee entre domaines : %s -> %s" % (s, ", ".join(ds)))

    r.note("")
    emp_fn = empreinte_liste(f["signature"] + ":" + f["empreinte"] for _, f in tous("fonctions"))
    r.emp("empreinte des fonctions", emp_fn, emp["fonctions"])
    emp_vue = empreinte_liste(v["nom"] + ":" + v["empreinte"] for _, v in tous("vues"))
    r.emp("empreinte des vues", emp_vue, emp["vues"])
    emp_trg = empreinte_liste(t["tbl"] + ":" + t["nom"] + ":" + t["empreinte"]
                              for _, t in tous("triggers"))
    r.emp("empreinte des declencheurs", emp_trg, emp["triggers"])

    # Controle le plus fort : le TEXTE ecrit dans les .sql est re-hache et
    # confronte a l'empreinte que la base a calculee sur pg_get_functiondef.
    # C'est lui qui attrape une retouche manuelle d'un fichier.
    r.note("")
    attendues = {f["signature"]: f["empreinte"] for _, f in tous("fonctions")}
    trouvees, faux = 0, []
    for d in sorted(mans):
        # L'ordre des morceaux est celui DECLARE au manifeste, pas celui du tri
        # des noms : « -10 » se trierait avant « -2 ».
        morceaux = [os.path.join(fichiers_par_dom[d], n) for n in mans[d]["ordre"]
                    if n.startswith("20_fonctions")]
        for chemin in morceaux:
            texte = lire(chemin)
            blocs = re.split(r"(?m)^-- (\S+\(.*?\)) -> ", texte)
            for i in range(1, len(blocs), 2):
                sig, corps = blocs[i], blocs[i + 1]
                defi = corps.split("\n", 1)[1]
                if sig not in attendues:
                    faux.append("%s : absente des manifestes" % sig)
                    continue
                reel = hashlib.md5((defi.rstrip("\n") + "\n").encode("utf-8")).hexdigest()
                if reel == attendues[sig]:
                    trouvees += 1
                else:
                    faux.append("%s : fichier %s, base %s" % (sig, reel, attendues[sig]))
    r.verif("definitions relues depuis les fichiers", trouvees, att["fonctions"])
    for f in faux[:10]:
        r.anomalie("definition non conforme -- " + f)

    # Les corps de table sont relus de la meme facon.
    retouches = 0
    for d in sorted(mans):
        texte = "".join(lire(os.path.join(fichiers_par_dom[d], n))
                        for n in mans[d]["ordre"] if n.startswith("10_tables"))
        for nom, corps in re.findall(r"CREATE TABLE public\.(\w+) \(\n  (.*?)\n\);", texte, re.S):
            ref = next((t["empreinte_texte"] for t in mans[d]["tables"] if t["nom"] == nom), None)
            if ref is None:
                r.anomalie("table presente dans le .sql mais absente du manifeste : " + nom)
            elif hashlib.md5(corps.encode("utf-8")).hexdigest() != ref:
                r.anomalie("corps de table retouche depuis le rendu : " + nom)
            else:
                retouches += 1
    r.verif("corps de table relus depuis les fichiers", retouches, att["tables"])

    # ------------------------------------------------------------- 3. SECURITE
    r.famille("3. SECURITE                                     baseline / base")
    sec = ctl["securite"]
    secdef = sum(1 for _, f in tous("fonctions") if f["security_definer"])
    r.verif("fonctions SECURITY DEFINER", secdef, sec["fonctions_security_definer"])
    r.verif("fonctions SECURITY INVOKER", att["fonctions"] - secdef,
            sec["fonctions_security_invoker"])
    r.verif("tables avec RLS active",
            sum(1 for _, x in tous("rls") if x["active"]), att["rls_actives"])
    r.verif("policies", nb("policies"), att["policies"])
    r.verif("lignes de droits", nb("droits"), att["droits"])
    r.verif("droits au niveau colonne", nb("droits_colonnes"), att["droits_colonnes"])

    avec_policy = {p["tbl"] for _, p in tous("policies")}
    actives = {x["tbl"] for _, x in tous("rls") if x["active"]}
    fermees = actives - avec_policy
    sans_rls = {x["tbl"] for _, x in tous("rls") if not x["active"]}
    r.verif("tables RLS active sans policy", len(fermees), sec["tables_rls_active_sans_policy"])
    r.verif("tables sans aucune RLS", len(sans_rls), sec["tables_sans_rls"])

    r.note("")
    emp_pol = empreinte_liste(p["tbl"] + ":" + p["nom"] + ":" + p["empreinte"]
                              for _, p in tous("policies"))
    r.emp("empreinte des policies", emp_pol, emp["policies"])
    emp_polr = empreinte_liste(p["tbl"] + ":" + p["nom"] + ":" + p["empreinte_avec_roles"]
                               for _, p in tous("policies"))
    r.emp("empreinte des policies avec roles", emp_polr, emp["policies_avec_roles"])

    ing = []
    for _, d_ in tous("droits"):
        if d_["genre"] == "FUNCTION":
            ing.append("FUNCTION:%s:%s:%s" % (d_["objet"], d_["beneficiaire"], d_["privileges"]))
        else:
            ing.append("%s:%s:%s:%s" % (d_["genre"], d_["objet"], d_["beneficiaire"], d_["privileges"]))
    for _, c in tous("droits_colonnes"):
        ing.append("COLUMN:%s.%s:%s:%s" % (c["tbl"], c["colonne"], c["beneficiaire"], c["privileges"]))
    r.emp("empreinte des droits", empreinte_liste(ing), emp["droits"])

    emp_com = empreinte_liste("%s:%s:%s:%s" % (c["genre"], c["objet"], c["sous"], c["empreinte"])
                              for _, c in tous("commentaires"))
    r.emp("empreinte des commentaires", emp_com, emp["commentaires"])

    # ---------------------------------------------------------------- 4. SEEDS
    famille_seeds(r, {t["nom"] for _, t in tous("tables")})

    # -------------------------------------------------- INTEGRITE DES FICHIERS
    r.famille("INTEGRITE DES FICHIERS")
    alteres, total = [], 0
    for d in sorted(mans):
        for nom, attendue in sorted(mans[d]["fichiers"].items()):
            chemin = os.path.join(fichiers_par_dom[d], nom)
            total += 1
            if not os.path.exists(chemin):
                alteres.append("%s/%s : absent" % (d, nom))
            elif md5_fichier(chemin) != attendue:
                alteres.append("%s/%s : altere depuis le rendu" % (d, nom))
    r.verif("fichiers conformes a leur empreinte", total - len(alteres), total)
    for a in alteres:
        r.anomalie(a)

    orphelins = []
    for d in sorted(mans):
        connus = set(mans[d]["fichiers"]) | {"MANIFESTE.json", "CONTROLE.json"}
        for f in os.listdir(fichiers_par_dom[d]):
            if f not in connus:
                orphelins.append("%s/%s" % (d, f))
    r.verif("fichiers non declares au manifeste", len(orphelins), 0)
    for o in orphelins:
        r.anomalie("fichier present mais non declare : " + o)

    # ----------------------------------------------------------------- verdict
    print("\n" + "=" * 76)
    total_pbs = sum(len(v) for v in r.pbs.values())
    for fam in r.pbs:
        n = len(r.pbs[fam])
        print("  %-52s %s" % (fam.split("  ")[0], "CONFORME" if not n else "ECHEC (%d)" % n))
    if total_pbs:
        print("\nECHEC : %d anomalie(s)" % total_pbs)
        for fam, liste in r.pbs.items():
            for p in liste:
                print("  - [%s] %s" % (fam.split(".")[0], p))
        return 1
    print("\nCONFORME : le baseline couvre exactement le catalogue du point de coupe,")
    print("           sans objet oublie et sans difference masquee.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
