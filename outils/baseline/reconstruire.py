#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""RECONSTRUCTION d'un monde neuf a partir du baseline (chantier 2F).

Assemble le baseline dans l'ordre d'application, puis le soumet a deux epreuves
que l'on peut passer SANS creer de base :

  1. GRAMMAIRE REELLE DE POSTGRESQL. Chaque ordre est analyse par l'analyseur
     syntaxique de PostgreSQL lui-meme, via pglast -- qui embarque libpg_query,
     c'est-a-dire le parser de PostgreSQL 17.7. La base de production tourne en
     17.6 : la grammaire qui accepte ou refuse ici est celle qui l'appliquera.
     Ce n'est donc pas une approximation par expression reguliere.

  2. SIMULATION DU CATALOGUE. Les ordres sont parcourus DANS L'ORDRE, en tenant
     un catalogue de ce qui existe deja. Chaque ordre doit trouver, au moment ou
     il passe, tout ce dont il depend : la table avant sa cle etrangere, la
     fonction avant son declencheur, la sequence avant le defaut qui l'appelle,
     la table avant sa policy. Un ordre qui arrive trop tot est signale avec son
     rang exact.

CE QUE CET OUTIL NE FAIT PAS, ET C'EST A SAVOIR : il n'execute rien. Aucun
moteur PostgreSQL n'est joignable depuis cette machine -- ni local, ni conteneur,
ni second projet -- et la base de production est interdite en ecriture. Une
reconstruction REELLE reste donc a faire le jour ou un projet jetable sera
disponible. Les deux epreuves ci-dessus couvrent la syntaxe et l'ordre des
dependances, pas le comportement du moteur a l'execution.

Usage :
    python3 outils/baseline/reconstruire.py            # assemble, valide, simule
    python3 outils/baseline/reconstruire.py --ecrire <fichier.sql>

Cet outil n'accede pas a la base et n'ecrit que le fichier qu'on lui demande.
"""

import glob
import json
import os
import re
import sys

from pglast import parse_sql
from pglast import parser as pglast_parser
from pglast.visitors import Visitor

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(os.path.dirname(ICI))
BASE = os.path.join(RACINE, "baseline")
DOM = os.path.join(BASE, "domaines")
SEEDS = os.path.join(BASE, "seeds")

PHASES = ["10_tables", "20_fonctions", "30_contraintes", "35_index", "40_vues",
          "50_triggers", "60_rls-policies", "70_droits", "80_commentaires"]
LOTS_SEEDS = ["90_socle", "91_empire", "92_mixte"]

# Objets que le baseline ne cree pas et suppose presents : ils sont fournis par
# Supabase. Declares, jamais absorbes.
EXTERNES = {"auth.uid", "auth.users", "auth.jwt", "auth.role"}
SCHEMAS_EXTERNES = {"auth", "extensions", "storage", "pg_catalog", "information_schema",
                    "realtime", "vault", "graphql", "cron", "net", "supabase_migrations"}


# ---------------------------------------------------------------- assemblage
def assembler():
    """Rend la liste ordonnee des (origine, sql) a appliquer.

    L'ordre est celui du baseline : par PHASE croissante, TOUS DOMAINES
    CONFONDUS -- jamais un domaine entier d'un coup. C'est ce qui permet qu'une
    cle etrangere d'un domaine pointe vers un objet d'un autre. L'ordre des
    morceaux d'un fichier decoupe est lu dans MANIFESTE.json, jamais deduit du
    tri des noms.
    """
    mans = {}
    for chemin in sorted(glob.glob(os.path.join(DOM, "*", "MANIFESTE.json"))):
        d = os.path.basename(os.path.dirname(chemin))
        mans[d] = (json.load(open(chemin, encoding="utf-8")), os.path.dirname(chemin))

    morceaux = []
    for phase in PHASES:
        for d in sorted(mans):
            man, rep = mans[d]
            for nom in man["ordre"]:
                if nom.startswith(phase):
                    chemin = os.path.join(rep, nom)
                    morceaux.append(("%s/%s" % (d, nom), open(chemin, encoding="utf-8").read()))
    for lot in LOTS_SEEDS:
        for chemin in sorted(glob.glob(os.path.join(SEEDS, lot, "*.sql"))):
            morceaux.append(("seeds/%s/%s" % (lot, os.path.basename(chemin)),
                             open(chemin, encoding="utf-8").read()))
    return morceaux, mans


def decouper(sql):
    """Decoupe un fichier en ordres, en s'appuyant sur les positions que
    l'analyseur de PostgreSQL rend lui-meme. Aucun decoupage sur « ; » : un
    point-virgule vit aussi dans un corps de fonction et dans une chaine."""
    ordres = []
    arbre = parse_sql(sql)
    bornes = [n.stmt_location for n in arbre] + [len(sql)]
    for i, n in enumerate(arbre):
        texte = sql[bornes[i]:bornes[i + 1]].strip()
        if texte:
            ordres.append((n.stmt, texte))
    return ordres


# ------------------------------------------------- extraction des dependances
def nom_relation(rv):
    return (rv.relname or "").lower()


def noms_appeles(noeud):
    """Fonctions appelees dans un sous-arbre, et schema s'il est qualifie."""
    trouves = set()

    class V(Visitor):
        def visit_FuncCall(self, ancestors, node):
            parties = [str(f.sval) for f in (node.funcname or ()) if hasattr(f, "sval")]
            if len(parties) >= 2:
                trouves.add((parties[-2], parties[-1]))
            elif parties:
                trouves.add((None, parties[-1]))
    V()(noeud)
    return trouves


def relations_lues(noeud):
    trouves = set()

    class V(Visitor):
        def visit_RangeVar(self, ancestors, node):
            trouves.add(nom_relation(node))
    V()(noeud)
    return trouves


# ------------------------------------------------------------- simulation
class Catalogue:
    def __init__(self):
        self.tables, self.vues, self.sequences = set(), set(), set()
        self.fonctions, self.index, self.policies, self.triggers = set(), set(), set(), set()
        self.contraintes = set()
        self.n_fonctions = 0      # signatures creees ; les noms, eux,
                                  # sont moins nombreux : 4 surcharges
        self.lignes = {}          # table -> nombre de lignes inserees

    def relation_existe(self, nom):
        return nom in self.tables or nom in self.vues


def simuler(morceaux):
    cat = Catalogue()
    pbs, ordres_vus, externes_vues = [], 0, {}
    builtins_ignorees = set()

    for origine, sql in morceaux:
        try:
            ordres = decouper(sql)
        except Exception as e:
            pbs.append((origine, 0, "GRAMMAIRE : " + str(e)[:160]))
            continue

        for rang, (stmt, texte) in enumerate(ordres, 1):
            ordres_vus += 1
            genre = type(stmt).__name__

            def manque(quoi):
                pbs.append((origine, rang, "%s : %s" % (genre, quoi)))

            if genre == "CreateStmt":
                t = nom_relation(stmt.relation)
                if t in cat.tables:
                    manque("table %s creee deux fois" % t)
                cat.tables.add(t)
                # un bigserial cree sa sequence implicitement
                for el in (stmt.tableElts or ()):
                    if type(el).__name__ == "ColumnDef" and el.typeName:
                        tn = ".".join(str(x.sval) for x in (el.typeName.names or ())
                                      if hasattr(x, "sval"))
                        if tn.endswith("serial") or tn.endswith("serial4") \
                           or tn.endswith("serial8"):
                            cat.sequences.add("%s_%s_seq" % (t, el.colname))
                for (sch, fn) in noms_appeles(stmt):
                    if sch in SCHEMAS_EXTERNES:
                        externes_vues.setdefault("%s.%s" % (sch, fn), set()).add(origine)
                    elif fn not in cat.fonctions:
                        builtins_ignorees.add(fn)
                for seq in re.findall(r"nextval\('(?:public\.)?\"?([\w-]+)\"?'", texte):
                    if seq not in cat.sequences:
                        manque("defaut nextval sur la sequence %s, absente" % seq)

            elif genre == "CreateSeqStmt":
                cat.sequences.add(nom_relation(stmt.sequence))

            elif genre == "CreateFunctionStmt":
                nom = [str(x.sval) for x in (stmt.funcname or ()) if hasattr(x, "sval")][-1]
                cat.fonctions.add(nom)
                cat.n_fonctions += 1

            elif genre == "AlterTableStmt":
                t = nom_relation(stmt.relation)
                if not cat.relation_existe(t):
                    manque("table %s absente" % t)
                for cmd in (stmt.cmds or ()):
                    d = getattr(cmd, "def_", None)
                    if d is None or type(d).__name__ != "Constraint":
                        continue
                    if d.conname:
                        if d.conname in cat.contraintes:
                            manque("contrainte %s declaree deux fois" % d.conname)
                        cat.contraintes.add(d.conname)
                    if d.pktable is not None:
                        schema = (d.pktable.schemaname or "").lower()
                        cible = nom_relation(d.pktable)
                        if schema in SCHEMAS_EXTERNES:
                            externes_vues.setdefault(
                                "%s.%s" % (schema, cible), set()).add(origine)
                        elif not cat.relation_existe(cible):
                            manque("cle etrangere vers %s, absente a ce rang" % cible)
                    for (sch, fn) in noms_appeles(d):
                        if sch in SCHEMAS_EXTERNES:
                            externes_vues.setdefault("%s.%s" % (sch, fn), set()).add(origine)
                        elif fn not in cat.fonctions:
                            builtins_ignorees.add(fn)

            elif genre == "IndexStmt":
                t = nom_relation(stmt.relation)
                if not cat.relation_existe(t):
                    manque("table %s absente" % t)
                if stmt.idxname:
                    cat.index.add(stmt.idxname)

            elif genre == "ViewStmt":
                v = nom_relation(stmt.view)
                for r in relations_lues(stmt.query):
                    if r and not cat.relation_existe(r) and r != v:
                        manque("vue : relation lue %s absente" % r)
                for (sch, fn) in noms_appeles(stmt.query):
                    if sch in SCHEMAS_EXTERNES:
                        externes_vues.setdefault("%s.%s" % (sch, fn), set()).add(origine)
                    elif fn not in cat.fonctions:
                        builtins_ignorees.add(fn)
                cat.vues.add(v)

            elif genre == "CreateTrigStmt":
                t = nom_relation(stmt.relation)
                if not cat.relation_existe(t):
                    manque("table %s absente" % t)
                fn = [str(x.sval) for x in (stmt.funcname or ()) if hasattr(x, "sval")][-1]
                if fn not in cat.fonctions:
                    manque("fonction de declencheur %s absente" % fn)
                cat.triggers.add(stmt.trigname)

            elif genre == "CreatePolicyStmt":
                t = nom_relation(stmt.table)
                if not cat.relation_existe(t):
                    manque("table %s absente" % t)
                for noeud in (stmt.qual, stmt.with_check):
                    if noeud is None:
                        continue
                    for (sch, fn) in noms_appeles(noeud):
                        if sch in SCHEMAS_EXTERNES:
                            externes_vues.setdefault("%s.%s" % (sch, fn), set()).add(origine)
                        elif fn in cat.fonctions:
                            pass
                        else:
                            builtins_ignorees.add(fn)
                    for r in relations_lues(noeud):
                        if r and not cat.relation_existe(r):
                            manque("policy : relation lue %s absente" % r)
                cat.policies.add((t, stmt.policy_name))

            elif genre == "GrantStmt":
                for o in (stmt.objects or ()):
                    if type(o).__name__ == "RangeVar":
                        n = nom_relation(o)
                        if not cat.relation_existe(n) and n not in cat.sequences:
                            manque("GRANT sur %s, absent" % n)
                    elif type(o).__name__ == "ObjectWithArgs":
                        n = [str(x.sval) for x in (o.objname or ()) if hasattr(x, "sval")][-1]
                        if n not in cat.fonctions:
                            manque("GRANT sur la fonction %s, absente" % n)

            elif genre == "CommentStmt":
                pass   # sans dependance bloquante : l'objet est verifie ailleurs

            elif genre == "InsertStmt":
                t = nom_relation(stmt.relation)
                if not cat.relation_existe(t):
                    manque("INSERT dans %s, table absente" % t)
                cat.lignes[t] = cat.lignes.get(t, 0) + 1

            elif genre in ("SelectStmt", "VariableSetStmt"):
                for seq in re.findall(r"setval\('(?:public\.)?\"?([\w-]+)\"?'", texte):
                    if seq not in cat.sequences:
                        manque("setval sur la sequence %s, absente" % seq)

            elif genre == "AlterSeqStmt":
                pass
            else:
                pbs.append((origine, rang, "ordre non simule : " + genre))

    return cat, pbs, ordres_vus, externes_vues, builtins_ignorees


# ------------------------------------------------------- controles du monde
def controles_du_monde(cat):
    """Verifie que le monde obtenu est celui qu'on attend -- pas seulement que
    le script passe. Chaque attente vient d'un arbitrage de game design ecrit."""
    r = []

    def att(libelle, obtenu, attendu, note=""):
        r.append((libelle, obtenu, attendu, obtenu == attendu, note))

    # 253 depuis les migrations du 8 octobre 2026 : +2 pour le referentiel des villes
    # (villes, villes_empreinte, chantier 4E) et +2 pour la brique budgetaire generique
    # (repartitions_budgetaires, repartitions_versements, chantier 4F). Les 6 tables
    # hors_baseline ne sont jamais creees : 259 au catalogue, 253 ici.
    att("tables creees", len(cat.tables), 253)
    att("vues creees", len(cat.vues), 2)
    # 657 : +4 au chantier 4E (villes_empreinte_reelle, ville_est_reelle, caisse_territoire,
    # caisse_refus_autorite) et +5 au chantier 4F (budget_repartir, budget_cascade_quotidienne,
    # budget_repartition_fixer, budget_repartition_lire, budget_coherence).
    att("signatures de fonction creees", cat.n_fonctions, 657)
    att("noms de fonction distincts", len(cat.fonctions), 653,
        "4 fonctions sont surchargees : moins de noms que de signatures")
    # 431 : +2 cles primaires et +1 CHECK (villes, villes_empreinte et son CHECK (seul)) au
    # chantier 4E, +2 cles primaires et +1 CHECK (la part bornee entre 0 et 100) au 4F.
    att("contraintes posees", len(cat.contraintes), 431)
    att("index autonomes crees", len(cat.index), 147)
    att("declencheurs crees", len(cat.triggers), 40)
    # 284 : +1 pour la lecture publique de villes_empreinte. repartitions_budgetaires,
    # repartitions_versements et villes ont la RLS active SANS AUCUNE POLICY -- fail closed :
    # elles ne sont lisibles que par le serveur et par les RPC attestees.
    att("policies creees", len(cat.policies), 284)
    att("sequences disponibles", len(cat.sequences), 31)

    att("indices de ville seedes", cat.lignes.get("indices_villes", 0), 3,
        "les 3 villes de Republia, 5 indices chacune")
    att("titulaires PNJ seedes", cat.lignes.get("titulaires_pnj", 0), 15,
        "15 titulaires, dont 3 juges municipaux distincts, sans le juge national")
    att("entrepots seedes", cat.lignes.get("batiments_etat", 0), 3,
        "les 3 entrepots logistiques, 17 matieres + 5 000 FR chacun")
    att("PNJ de socle seedes", cat.lignes.get("pnj_membres", 0), 0,
        "un monde neuf n'herite d'aucun PNJ : ils naissent des mecanismes")
    att("soldats seedes", cat.lignes.get("pnj_soldats_metier", 0), 0,
        "aucun soldat au premier jour")
    att("possessions de PNJ seedees", cat.lignes.get("pnj_possessions", 0), 0,
        "aucune possession heritee")
    att("compagnies militaires seedees", cat.lignes.get("compagnies_militaires", 0), 0,
        "0 compagnie et 0 section au premier jour -- arbitrage du 5 octobre 2026")
    att("organisations seedees", cat.lignes.get("organisations", 0), 0,
        "les loges attendent le mecanisme de rattachement du chef")
    att("lignes de rp_transitions", cat.lignes.get("rp_transitions", 0), 0,
        "table volontairement vide : rp_transition_active() rend FALSE sur cle absente")
    att("caisses de batiment seedees", cat.lignes.get("caisses_batiments", 0), 41,
        "les 41 dotations financieres arbitrees, 130 000 FR, ecrites depuis le tableau")
    # LA CLE DE REPARTITION NAIT AVEC LE MONDE. Sans ces quinze lignes, la cascade nocturne ne
    # verserait rien -- et c'est volontairement ce qui arrive aux trois autres empires, qui n'en
    # ont aucune. Dix lignes au niveau national, une Defense -> Caserne, une Interieur -> Douanes,
    # et trois Justice -> tribunaux a part NULLE : le mecanisme est la, le pourcentage attend un
    # arbitrage, et rien n'a ete invente a sa place.
    att("lignes de repartition budgetaire seedees",
        cat.lignes.get("repartitions_budgetaires", 0), 15,
        "10 nationales (9 x 9 % + Assemblee 19 %), Defense 65 %, Douanes 35 %, 3 tribunaux a NULL")
    att("versements budgetaires seedes", cat.lignes.get("repartitions_versements", 0), 0,
        "journal des versements reels : un monde neuf nait sans historique, sinon le premier "
        "minuit croirait avoir deja verse")
    return r


def main():
    print("RECONSTRUCTION DU BASELINE -- chantier 2F")
    print("  analyseur : pglast %s, grammaire de PostgreSQL %s"
          % (__import__("pglast").__version__,
             ".".join(str(x) for x in pglast_parser.get_postgresql_version())))
    print("  production : PostgreSQL 17.6 -- meme version majeure")

    morceaux, mans = assembler()
    octets = sum(len(s) for _, s in morceaux)
    print("\n1. ASSEMBLAGE")
    print("  " + "-" * 70)
    print("  %d fichiers assembles, %d octets, %d domaines"
          % (len(morceaux), octets, len(mans)))
    print("  ordre : phases %s, puis les seeds %s"
          % (" > ".join(p.split("_")[0] for p in PHASES), " > ".join(LOTS_SEEDS)))

    if len(sys.argv) == 3 and sys.argv[1] == "--ecrire":
        with open(sys.argv[2], "w", encoding="utf-8", newline="") as fh:
            for origine, sql in morceaux:
                fh.write("\n-- ========== %s ==========\n" % origine)
                fh.write(sql)
        print("  script complet ecrit dans %s" % sys.argv[2])

    cat, pbs, n, externes, builtins = simuler(morceaux)

    grammaire = [p for p in pbs if p[2].startswith("GRAMMAIRE")]
    print("\n2. GRAMMAIRE REELLE DE POSTGRESQL")
    print("  " + "-" * 70)
    print("  ordres analyses                      : %d" % n)
    print("  refuses par l'analyseur              : %d  %s"
          % (len(grammaire), "OK " if not grammaire else "NON"))
    for p in grammaire[:10]:
        print("    - %s : %s" % (p[0], p[2]))

    dep = [p for p in pbs if not p[2].startswith("GRAMMAIRE")]
    print("\n3. SIMULATION DU CATALOGUE, DANS L'ORDRE D'APPLICATION")
    print("  " + "-" * 70)
    print("  dependances manquantes a leur rang   : %d  %s"
          % (len(dep), "OK " if not dep else "NON"))
    for p in dep[:25]:
        print("    - %s (ordre %d) : %s" % (p[0], p[1], p[2]))

    print("\n  dependances externes rencontrees : %d" % len(externes))
    for cle in sorted(externes):
        print("    %-22s utilisee par %d fichier(s)" % (cle, len(externes[cle])))

    print("\n4. LE MONDE OBTENU")
    print("  " + "-" * 70)
    res = controles_du_monde(cat)
    for libelle, obtenu, attendu, ok, note in res:
        print("  %-34s %6s / %-6s %s  %s"
              % (libelle, obtenu, attendu, "OK " if ok else "NON", note))

    total_lignes = sum(cat.lignes.values())
    print("\n  %d lignes seedees au total, dans %d tables"
          % (total_lignes, len(cat.lignes)))

    echecs = [r for r in res if not r[3]]
    print("\n" + "=" * 74)
    if grammaire or dep or echecs:
        print("ECHEC : %d refus de grammaire, %d dependance(s) manquante(s), "
              "%d attente(s) du monde non tenue(s)" % (len(grammaire), len(dep), len(echecs)))
        return 1
    print("RECONSTRUCTION VALIDEE sur les deux epreuves praticables ici :")
    print("  . les %d ordres du baseline sont acceptes par la grammaire de PostgreSQL 17 ;" % n)
    print("  . appliques dans l'ordre des phases, chacun trouve ses dependances ;")
    print("  . le monde obtenu est celui qu'attendent les arbitrages de game design.")
    print("\nRESTE A FAIRE, ET CE N'EST PAS COUVERT ICI : appliquer reellement ce")
    print("script sur un moteur PostgreSQL. Aucun n'est joignable depuis cette")
    print("machine, et la production est interdite en ecriture.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
