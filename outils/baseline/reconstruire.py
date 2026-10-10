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

# 85 vient APRES 80 et AVANT les seeds, et ce n'est pas un detail d'ordre : un
# privilege par defaut ne touche AUCUN objet existant, seulement ceux qui seront crees
# plus tard. Le poser en tete ferait naitre les 664 fonctions et les 254 tables avec ces
# droits, puis la phase 70 ajouterait leurs GRANT exacts SANS retirer les surnumeraires
# -- et la base reconstruite serait PLUS PERMISSIVE que la vraie. Place en fin, le bloc
# ne change rien au monde qu'on vient de reconstruire et regle son comportement FUTUR.
PHASES = ["10_tables", "20_fonctions", "30_contraintes", "35_index", "40_vues",
          "50_triggers", "60_rls-policies", "70_droits", "80_commentaires",
          "85_default-privileges"]
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


# ------------------------------------- jsonb : la FAMILLE D'ENCODAGE declaree, dans les deux sens
# DEUX FAMILLES COHABITENT. Une colonne jsonb peut porter un OBJET natif ou une CHAINE qui
# contient du JSON, et le code lecteur n'est pas interchangeable : se tromper de famille ne leve
# aucune erreur, la donnee est simplement perdue ou illisible.
#
#   . caisses_batiments porte un OBJET : tout le SQL fait `data->>'solde'`, qui rendrait NULL sur
#     une chaine -- et tous les soldes seraient lus a zero.
#   . batiments_etat porte une CHAINE : sbGetBatimentEtat fait `JSON.parse(rows[0].data)`, et
#     PostgREST rend un objet quand la colonne porte un objet -- JSON.parse leve, le catch rend
#     {}, et l'etat du batiment disparait en silence.
#
# CE CONTROLE N'INVENTE PAS LA CONVENTION, IL LA LIT. outils/baseline/encodage-blobs.json la
# declare table par table, avec la preuve qui l'etablit. Les tables non declarees ne sont pas
# controlees : l'absence de declaration est une lacune, pas une autorisation.
#
# POURQUOI IL EXISTE. Le 7 octobre 2026 j'ai pris le to_jsonb(texte) du seed de batiments_etat
# pour un double encodage accidentel et j'ai failli le remplacer par un cast. La convention etait
# juste ; ma lecture etait fausse. Un controle a UN SEUL SENS aurait valide la regression.

def _chaine_de(noeud):
    """Le texte d'un litteral chaine, a travers un eventuel cast. None sinon.

    DEUX FORMES DE A_Const selon la version de pglast : `.sval` directement, ou `.val`
    portant un noeud String. On accepte les deux plutot que de dependre d'une version --
    c'est ce qui a fait taire ce controle a son premier jet, et un controle muet est pire
    qu'un controle absent."""
    g = type(noeud).__name__
    if g == "TypeCast":
        return _chaine_de(noeud.arg)
    if g != "A_Const":
        return None
    for porteur in (getattr(noeud, "sval", None), getattr(noeud, "val", None)):
        if porteur is None:
            continue
        if type(porteur).__name__ == "String":
            txt = getattr(porteur, "sval", None)
            if txt is None:
                txt = getattr(porteur, "str", None)
            if txt is not None:
                return txt
    return None


def _nom_fonction(noeud):
    return ".".join(str(x.sval) for x in (noeud.funcname or ()) if hasattr(x, "sval")).lower()


def _est_json_structure(txt):
    if txt is None:
        return False
    try:
        return isinstance(json.loads(txt), (dict, list))
    except Exception:
        return False


def encodage_emis(noeud):
    """La famille d'encodage que ce noeud PRODUIT : 'chaine_json', 'objet_natif', ou None
    quand on ne peut pas conclure (une expression calculee, un NULL, un nombre)."""
    g = type(noeud).__name__
    if g == "FuncCall" and _nom_fonction(noeud).endswith("to_jsonb") \
       or g == "FuncCall" and _nom_fonction(noeud).endswith("to_json"):
        args = list(noeud.args or ())
        if len(args) == 1 and _est_json_structure(_chaine_de(args[0])):
            return "chaine_json"       # to_jsonb(<texte JSON>) encapsule, il ne parse pas
        return None
    if g == "TypeCast":
        cible = ".".join(str(x.sval) for x in (noeud.typeName.names or ())
                         if hasattr(x, "sval")).lower()
        if not (cible.endswith("jsonb") or cible.endswith("json")):
            return None
        txt = _chaine_de(noeud.arg)
        if txt is None:
            return None
        if _est_json_structure(txt):
            return "objet_natif"       # (<texte JSON>)::jsonb parse : c'est un objet
        try:
            dedans = json.loads(txt)
        except Exception:
            return None
        if isinstance(dedans, str) and _est_json_structure(dedans):
            return "chaine_json"       # un litteral deja doublement encode
        return None
    if g == "A_Const":
        # Un litteral nu vers une colonne jsonb : PostgreSQL le PARSE.
        return "objet_natif" if _est_json_structure(_chaine_de(noeud)) else None
    return None


def charger_encodages():
    chemin = os.path.join(BASE, "..", "outils", "baseline", "encodage-blobs.json")
    chemin = os.path.normpath(os.path.join(ICI, "encodage-blobs.json")) \
        if os.path.exists(os.path.join(ICI, "encodage-blobs.json")) else chemin
    if not os.path.exists(chemin):
        return {}
    d = json.load(open(chemin, encoding="utf-8"))
    return {t: (r["colonne"], r["encodage"]) for t, r in d.get("tables", {}).items()}


# ------------------------------------------------------------- simulation
class Catalogue:
    def __init__(self):
        self.tables, self.vues, self.sequences = set(), set(), set()
        self.fonctions, self.index, self.policies, self.triggers = set(), set(), set(), set()
        self.contraintes = set()
        self.n_fonctions = 0      # signatures creees ; les noms, eux,
                                  # sont moins nombreux : 4 surcharges
        self.lignes = {}          # table -> nombre de lignes inserees
        # LES COLONNES, table par table. Sans elles, un seed qui insere dans une colonne
        # disparue passait la simulation sans un mot : la table existe, donc l'INSERT etait
        # declare bon. C'est arrive le 7 octobre 2026, quand part_pourcent a cede la place a
        # part_numerateur / part_denominateur : le script du monde neuf aurait echoue a sa
        # premiere ligne de seed, et la reconstruction se disait VALIDEE.
        self.colonnes = {}        # table -> set des colonnes connues

    def relation_existe(self, nom):
        return nom in self.tables or nom in self.vues


ENCODAGES = charger_encodages()


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
                cat.colonnes[t] = {el.colname for el in (stmt.tableElts or ())
                                   if type(el).__name__ == "ColumnDef" and el.colname}
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
                    # ADD COLUMN / DROP COLUMN : le baseline n'en contient pas aujourd'hui,
                    # mais une migration future assemblee ici en contiendrait, et le
                    # catalogue simule doit suivre.
                    sous = str(getattr(cmd, "subtype", ""))
                    d = getattr(cmd, "def_", None)
                    if sous.endswith("AT_AddColumn") and d is not None \
                       and type(d).__name__ == "ColumnDef" and d.colname:
                        cat.colonnes.setdefault(t, set()).add(d.colname)
                    elif sous.endswith("AT_DropColumn") and cmd.name:
                        cat.colonnes.setdefault(t, set()).discard(cmd.name)
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
                # CHAQUE COLONNE NOMMEE DOIT EXISTER. Un seed engendre avant un changement de
                # colonnes echouerait a l'application ; sans ce controle, la simulation le
                # laissait passer parce qu'elle ne regardait que le nom de la table.
                elif t in cat.colonnes:
                    inconnues = sorted({c.name for c in (stmt.cols or ())
                                        if getattr(c, "name", None)} - cat.colonnes[t])
                    if inconnues:
                        manque("INSERT dans %s : colonne(s) inexistante(s) %s -- le seed est "
                               "anterieur a un changement de colonnes et doit etre regenere"
                               % (t, ", ".join(inconnues)))
                # LA FAMILLE D'ENCODAGE DE LA COLONNE, dans les deux sens.
                if t in ENCODAGES and stmt.selectStmt is not None \
                   and type(stmt.selectStmt).__name__ == "SelectStmt":
                    col_attendue, attendu = ENCODAGES[t]
                    noms = [c.name for c in (stmt.cols or ()) if getattr(c, "name", None)]
                    if col_attendue in noms:
                        rang_col = noms.index(col_attendue)
                        for v in (stmt.selectStmt.valuesLists or ()):
                            if rang_col >= len(v):
                                continue
                            obtenu = encodage_emis(v[rang_col])
                            if obtenu is not None and obtenu != attendu:
                                manque("INSERT dans %s : la colonne %s est declaree « %s » dans "
                                       "outils/baseline/encodage-blobs.json, et ce seed emet "
                                       "« %s ». Se tromper de famille ne leve aucune erreur : la "
                                       "donnee sera perdue ou illisible."
                                       % (t, col_attendue, attendu, obtenu))
                cat.lignes[t] = cat.lignes.get(t, 0) + 1

            elif genre in ("SelectStmt", "VariableSetStmt"):
                for seq in re.findall(r"setval\('(?:public\.)?\"?([\w-]+)\"?'", texte):
                    if seq not in cat.sequences:
                        manque("setval sur la sequence %s, absente" % seq)

            elif genre == "AlterSeqStmt":
                pass

            elif genre == "AlterDefaultPrivilegesStmt":
                # UN PRIVILEGE PAR DEFAUT NE DEPEND D'AUCUN OBJET, et c'est tout son
                # interet : il regle ce que recevront les objets qui n'existent pas encore.
                # Il ne suppose que l'existence du ROLE et, le cas echeant, du SCHEMA --
                # deux choses que le baseline ne cree pas et qui sont declarees externes.
                # Rien a simuler, donc, mais il faut le dire EXPLICITEMENT : le simulateur
                # refuse par defaut tout ordre qu'il ne connait pas, et c'est cette
                # severite qui a fait apparaitre la phase 85 comme treize dependances
                # manquantes au lieu de la laisser passer en silence. Un simulateur qui
                # ignore ce qu'il ne comprend pas ne simule rien.
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

    # 253 depuis les migrations du 7 octobre 2026 : +2 pour le referentiel des villes
    # (villes, villes_empreinte, chantier 4E) et +2 pour la brique budgetaire generique
    # (repartitions_budgetaires, repartitions_versements, chantier 4F). Les 6 tables
    # hors_baseline ne sont jamais creees : 259 au catalogue, 253 ici.
    # 254 le 8 octobre 2026 : +1 pour recettes_municipales, le COMPTEUR des recettes du jour.
    # Ce n'est pas une tresorerie -- son CHECK montant > 0 l'interdit structurellement -- mais la
    # mesure que la cascade municipale prend pour base.
    # 256 le 9 octobre 2026 : +2 pour la brique d'idempotence nocturne -- actes_nocturnes, dont
    # la cle primaire (pays, mecanisme, sujet, jour) EST l'idempotence, et
    # actes_nocturnes_mecanismes, sa liste blanche. Un monde neuf nait avec le registre des
    # mecanismes SEME (sans sa ligne, la RPC leve) et le journal des actes VIDE.
    # 258 le 10 octobre 2026 : +2 pour la purge des chantiers 5 et 6 -- offres_emploi_bne, le
    # MIROIR des offres du Bureau national de l'emploi (registre 609 : la colonne `places` BORNE
    # une autorisation, elle ne pouvait plus venir du navigateur), et purges_residus_bancs,
    # l'archive qui rend une purge reversible (registre 623 : la ligne entiere y est copiee dans
    # la MEME transaction que sa suppression). Un monde neuf nait avec le miroir SEME -- il se
    # regenere -- et l'archive des purges VIDE : il n'a encore rien purge.
    # 260 le 10 octobre 2026 au soir : +2 pour les subventions municipales -- subventions_familles,
    # le REGISTRE d'eligibilite par famille d'organisation (categorie A, seme : sans ses lignes la
    # mecanique entiere est inerte), et subventions_municipales, les propositions et leur issue
    # (categorie C, etat vivant pur : un monde neuf nait sans aucun engagement municipal).
    # Les tables hors_baseline ne sont jamais creees. Elles etaient SIX ; la migration 20261010183124
    # (registre 633) a detruit zz_snap_cka_membres apres l'avoir archivee, il en reste CINQ :
    # 265 au catalogue, 260 ici. La ligne du CSV de classification reste a retirer.
    att("tables creees", len(cat.tables), 260)
    att("vues creees", len(cat.vues), 2)
    # 657 : +4 au chantier 4E (villes_empreinte_reelle, ville_est_reelle, caisse_territoire,
    # caisse_refus_autorite) et +5 au chantier 4F (budget_repartir, budget_cascade_quotidienne,
    # budget_repartition_fixer, budget_repartition_lire, budget_coherence).
    # 658 : +1 au chantier 4F, budget_part_totale -- la somme des parts d'une source en une seule
    # fraction exacte, seul endroit du systeme ou cette arithmetique vit.
    # 663 le 8 octobre 2026 : +5 au chantier municipal -- recette_municipale (le seul point
    # d'entree d'une recette communale), budget_municipal_cascade (la passe de minuit),
    # mairie_virement_batiment (le virement atomique du maire), entrepot_caisse_id (la SEULE
    # regle qui nomme la caisse d'un entrepot) et entrepot_caisse_mouvement (sa porte serveur).
    # 664 le 8 octobre 2026 au soir : +1 au chantier 4G -- personnage_pays_declare(), la garde
    # qui refuse un personnage dont le pays est absent, vide ou etranger au referentiel `villes`.
    # Les onze fonctions de l'Assemblee qui portaient `DEFAULT 'republic'` ont ete DETRUITES ET
    # RECREEES sans ce defaut : leur nombre ne bouge donc pas, seule la garde s'ajoute.
    # 666 le 9 octobre 2026 : +2 -- acte_nocturne_revendiquer() (la revendication atomique, que
    # son EXECUTE retire a tous les roles clients rend injoignable depuis le reseau) et
    # preemption_mensualite_prelever() (son premier consommateur).
    # 679 le 9 octobre 2026 au soir : +13 pour les QUINZE migrations du chantier justice et
    # notification (registre 569 a 583). Les nouvelles sont election_voter, les onze portes de
    # detention et de justice (detention_qhs_poser_interne, detention_prolonger_interne,
    # detention_prolonger_soi, detention_ouvrir_soi, detention_clore_purgee,
    # detention_transferer_qhs, detention_reduire_peine, detention_clore_evasion,
    # justice_prolonger_peine, justice_rendre_sentence, candidature_poste_tirage_appliquer),
    # compromis_expire_resoudre et mail_systeme_poser_interne ; detention_ouvrir_interne a vu sa
    # signature passer a 9 parametres, et une vingtaine de fonctions ont ete REMPLACEES sans que
    # leur nombre bouge. Mesure en base : select count(*), count(distinct proname) from pg_proc
    # join pg_namespace on ... where nspname='public' and prokind in ('f','p') -> 679 / 675.
    # 690 le 10 octobre 2026 : +11 pour les SEIZE migrations des chantiers 5 et 6 (registre 584
    # a 599). Les onze nouvelles, dans l'ordre d'application : detention_clore_interne et
    # detention_clore_motif_eteint (le moteur de cloture et la porte des motifs eteints par la
    # desertion), taxe_fonciere_prelever, vote_confiance_resoudre, election_resultats_consigner,
    # cotisation_renouveler, succession_regler, taux_imposition_fixer, tournee_cloturer,
    # terrain_proprietaire_muter et chantier_approvisionner. AUCUNE SURCHARGE AJOUTEE : +11
    # signatures pour +11 noms distincts, l'ecart de 4 reste celui des quatre surcharges
    # historiques. Quatre portes existantes ont ete REMPLACEES pour deleguer au moteur de cloture
    # (presidence_gracier, detention_clore_purgee, detention_clore_evasion,
    # detention_reduire_peine) et deux ont ete patchees en place (cotisation_renouveler elle-meme,
    # approvisionner_chantier n'a perdu qu'un droit) : leur nombre ne bouge pas.
    # Mesure en base : select count(*), count(distinct proname) from pg_proc join pg_namespace
    # on ... where nspname='public' and prokind in ('f','p') -> 690 / 686.
    # 710 / 706 le 10 octobre 2026, apres la purge des chantiers 5 et 6 : +20 signatures nettes.
    # Mesure en base : select count(*), count(distinct proname) from pg_proc join pg_namespace
    # on ... where nspname='public' and prokind in ('f','p') -> 710 / 706.
    # Les vingt : souvenir_accueil_tirer, achat_direct_manque_resoudre, recherche_inscrire,
    # recherche_retirer, candidature_deposer, assemblee_dissoudre, bne_agir, affaire_transmettre,
    # plainte_defendre, plainte_classer_ministere, titulaire_est_moi, les deux primitives internes
    # des terrains (terrain_etat_verrouiller_interne, terrain_etat_fusionner_interne), leurs
    # quatre portes a actes (compromis, permis, chantier, lots), terrain_reamenagement_poser et
    # les deux portes successorales. `assemblee_dissoudre_revoquer_deputes` a ete SUPPRIMEE le
    # meme jour (registre 611) : elle n'avait vecu que quelques minutes, et la supersession est
    # ecrite dans l'archive de la 608. L'ecart de 4 reste celui des quatre surcharges historiques.
    # 722 / 718 le 10 octobre 2026 au soir : +12 signatures et +12 noms pour les subventions
    # municipales (registre 624 a 632). Les douze : subvention_familles_resolues,
    # subventions_famille_a_son_resolveur (fonction de declencheur), subvention_entites,
    # subvention_gestionnaire, subvention_caisse_crediter, subvention_organisations_locales,
    # subvention_beneficiaire_verdict, subvention_proposer, subvention_repondre,
    # subventions_expirer, subvention_enveloppe_lire, subventions_recues_lire. Aucune surcharge
    # ajoutee : l'ecart de 4 reste celui des quatre surcharges historiques.
    # 725 / 721 le 10 octobre 2026 au soir, a la cloture de la caserne (registre 636) : +3
    # signatures et +3 noms. Les trois : caserne_reverser_au_ministere (le flux
    # Caserne -> Ministere, qui n'existait pas), militaire_compagnies_lisibles (la porte qui
    # PROJETTE l'ordre de bataille selon la place de l'appelant dans la chaine militaire, et qui
    # remplace le SELECT direct) et militaire_inspection_perimetre (le verdict serveur de
    # l'inspection des troupes, qui n'etait gardee qu'en JavaScript). Aucune surcharge ajoutee :
    # l'ecart de 4 reste celui des quatre surcharges historiques.
    att("signatures de fonction creees", cat.n_fonctions, 725)
    att("noms de fonction distincts", len(cat.fonctions), 721,
        "4 fonctions sont surchargees : moins de noms que de signatures")
    # 433 : +2 cles primaires et +1 CHECK (villes, villes_empreinte et son CHECK (seul)) au
    # chantier 4E, +2 cles primaires et +1 CHECK au 4F, puis +2 nets quand la part est devenue
    # une FRACTION -- trois CHECK (couple entier, denominateur positif, numerateur borne par le
    # denominateur) remplacent l'unique borne 0-100 de l'ancien pourcentage.
    # 438 le 8 octobre 2026 : +5 pour recettes_municipales -- sa cle primaire a quatre colonnes
    # (pays, ville, jour, canal) et ses quatre CHECK, dont `montant > 0` qui est ce qui garantit
    # qu'aucune fonction ne pourra jamais s'en servir comme d'une bourse.
    # 444 le 9 octobre 2026 : +6 pour la brique nocturne -- deux cles primaires (celle
    # d'actes_nocturnes porte quatre colonnes), une cle etrangere vers la liste blanche, et
    # trois CHECK (slug du mecanisme, pays et sujet non vides).
    # 446 le 10 octobre 2026 : +2 cles primaires, celles des deux tables neuves du cycle --
    # offres_emploi_bne (le miroir des offres du BNE, registre 609) et purges_residus_bancs
    # (l'archive qui rend la purge reversible, registre 623). Mesure en base :
    # offres_emploi_bne_pkey et purges_residus_bancs_pkey, contype = 'p'.
    # 454 le 10 octobre 2026 au soir : +8 pour les subventions municipales. DEUX sur
    # subventions_familles (sa cle primaire et le CHECK du slug de registre) et SIX sur
    # subventions_municipales -- cle primaire, cle etrangere vers le registre des familles
    # (c'est elle qui rend l'eligibilite fail-closed : on ne propose pas a une famille absente),
    # CHECK du montant, CHECK du statut, CHECK de coherence de cloture (une proposition close
    # porte sa date et son repondant, une proposition en attente n'en porte aucun) et CHECK du
    # delai de trois jours.
    att("contraintes posees", len(cat.contraintes), 454)
    # 149 le 10 octobre 2026 : +2 index UNIQUE, ceux du registre 601 --
    # compromis_historique_un_resultat_par_bien_et_par_jour et
    # chronique_nationale_une_proclamation_par_scrutin. Ce sont les deux contraintes que le §5 de
    # l'audit du chantier 6 reclamait pour rendre l'anti-rejeu STRUCTUREL et non disciplinaire.
    # 151 le 10 octobre 2026 au soir : +2 index UNIQUE partiels sur subventions_municipales --
    # subventions_enveloppe_en_attente et subventions_une_proposition_identique_en_attente. Ils
    # portent l'unicite de ce qui est ENCORE PROPOSE, et c'est la raison pour laquelle la reserve
    # n'est pas une colonne : elle se calcule, elle ne se duplique pas.
    att("index autonomes crees", len(cat.index), 151)
    # 41 le 8 octobre 2026 au soir : +1 au chantier 4G -- trg_personnage_pays_declare, pose
    # BEFORE INSERT OR UPDATE OF country sur la TABLE personnages_donnees et non sur la vue,
    # pour couvrir aussi service_role et les fonctions SECURITY DEFINER.
    # 42 le 10 octobre 2026 au soir : +1, subventions_familles_verrou_resolveur. Il refuse de
    # declarer eligible une famille que subvention_familles_resolues() ne sait pas traiter : on ne
    # peut pas declarer sans implementer.
    att("declencheurs crees", len(cat.triggers), 42)
    # 284 : +1 pour la lecture publique de villes_empreinte. repartitions_budgetaires,
    # repartitions_versements et villes ont la RLS active SANS AUCUNE POLICY -- fail closed :
    # elles ne sont lisibles que par le serveur et par les RPC attestees.
    # 285 le 8 octobre 2026 : +1 pour la lecture publique de recettes_municipales. Les recettes
    # d'une commune sont une donnee de finances publiques, comme le sont deja ses taux : c'est une
    # ouverture VOULUE, en lecture seule, et non une policy dormante oubliee en USING(true).
    # 286 le 10 octobre 2026 : +1, offres_emploi_bne_lecture. Le miroir des offres du Bureau
    # national de l'emploi est lisible par les clients -- c'est un CATALOGUE, pas un etat : les
    # offres sont deja dans data.js, cote navigateur. Ce qui ne peut PAS venir du navigateur, et
    # qui est la raison d'etre de ce miroir, c'est le nombre de PLACES : il borne une autorisation.
    # 287 le 10 octobre 2026 au soir : +1, subventions_archives_publiques. Lecture publique des
    # seules propositions CLOSES : ce qui est encore propose immobilise une reserve et ne se lit
    # que par RPC attestee. subventions_familles, elle, a la RLS active SANS AUCUNE POLICY --
    # fail closed : un navigateur ne lit pas le registre d'eligibilite, donc il ne l'invente pas.
    # 283 le meme soir, et c'est une BAISSE VOULUE : -4 au registre 634, quand le navigateur perd
    # l'ecriture sur les terrains et les plaintes. Les quatre policies d'ecriture tombent --
    # terrains_etat_ecriture_acteur, terrains_etat_maj_acteur, plaintes_insertion_affaires,
    # plaintes_maj_affaires -- en meme temps que le REVOKE INSERT, UPDATE a `authenticated` sur
    # les deux tables. Les deux policies de SELECT restent : la lecture n'a jamais ete le sujet.
    # Un compte de policies qui DESCEND n'est pas une regression ; une porte serveur qui remplace
    # une policy d'ecriture en retire une, c'est le signe attendu. S'il remontait a 287 sans
    # migration, ce serait l'ecriture cliente qui serait revenue.
    # 282 a la cloture de la caserne (registre 636), et c'est encore une BAISSE VOULUE :
    # compagnies_lecture_mon_pays est SUPPRIMEE. Elle ouvrait l'ordre de bataille complet en
    # SELECT a tout joueur authentifie du pays -- matricules, PA, armes, positions, missions,
    # reserve. La lecture passe desormais par militaire_compagnies_lisibles(), et le SELECT de
    # `authenticated` sur la table est revoque en meme temps : une policy retiree sans revocation
    # laisserait la table lisible le jour ou une policy permissive reviendrait.
    # compagnies_militaires rejoint donc les tables a RLS active SANS AUCUNE POLICY -- l'etat
    # cible, pas un oubli. S'il remontait a 283 sans migration, ce serait la fuite qui serait
    # revenue.
    att("policies creees", len(cat.policies), 282)
    # 32 le 10 octobre 2026 : +1, purges_residus_bancs_id_seq -- la cle bigserial de l'archive
    # des purges.
    att("sequences disponibles", len(cat.sequences), 32)

    att("indices de ville seedes", cat.lignes.get("indices_villes", 0), 3,
        "les 3 villes de Republia, 5 indices chacune")
    att("titulaires PNJ seedes", cat.lignes.get("titulaires_pnj", 0), 15,
        "15 titulaires, dont 3 juges municipaux distincts, sans le juge national")
    att("entrepots seedes", cat.lignes.get("batiments_etat", 0), 3,
        "les 3 entrepots logistiques, 17 matieres chacun -- leur tresorerie a quitte le blob "
        "le 8 octobre 2026 pour une vraie caisse, seedee avec les autres")
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
    # 44 le 8 octobre 2026 : +3 pour les caisses d'entrepot. La dotation de 5 000 FR ne change
    # pas -- elle etait deja arbitree le 5 octobre -- seule son ADRESSE change : elle vivait dans
    # batiments_etat.data.entrepot.caisse, elle vit maintenant dans caisses_batiments. Si ce
    # compte retombait a 41, ce serait le signe que la tresorerie est retournee dans le blob.
    att("caisses de batiment seedees", cat.lignes.get("caisses_batiments", 0), 44,
        "les 44 dotations financieres arbitrees, ecrites depuis le tableau")
    # LA CLE DE REPARTITION NAIT AVEC LE MONDE. Sans ces seize lignes, la cascade nocturne ne
    # verserait rien -- et c'est volontairement ce qui arrive aux trois autres empires, qui n'en
    # ont aucune. Dix lignes au niveau national, une Defense -> Caserne, deux pour l'Interieur
    # (Douanes et QHS), et trois Justice -> tribunaux a part NULLE.
    #
    # DEUX ETATS A NE PAS CONFONDRE, et ce compte les garde tous les deux. La ligne du QHS porte
    # une part de ZERO : le beneficiaire est reconnu, la regle existe et donne zero. Une part
    # NULLE, elle, n'est pas arbitree et budget_repartir l'ignore -- il n'en reste AUCUNE depuis
    # l'arbitrage de la Justice du 7 octobre 2026. Si un jour ce compte tombait a 15, ce serait le
    # signe qu'une part a zero a ete prise pour une absence de regle et effacee.
    #
    # LA PART EST UNE FRACTION, PAS UN POURCENTAGE. Les trois tribunaux portent 1/3 chacun : trois
    # parts rigoureusement egales, que 33,33 ne sait pas ecrire sans perdre 0,01 % ou privilegier
    # l'un des trois pour toujours.
    # 25 le 8 octobre 2026 : +9 pour le circuit MUNICIPAL -- trois villes x trois beneficiaires
    # (commissariat 40/100, entrepot 40/100, et la mairie elle-meme 20/100). La troisieme ligne
    # de chaque ville a pour beneficiaire SA PROPRE SOURCE : la part est journalisee mais jamais
    # transferee, exactement comme celle du Ministere de l'Economie. C'est ce qui empeche la
    # boucle, et c'est pourquoi la part conservee par la mairie n'a demande aucun mecanisme neuf.
    # 28 le 10 octobre 2026 au soir : +3 pour les subventions municipales -- une ligne par
    # commune (mairie-capitale -> subventions_capitale, et les deux autres villes), part a 0/100
    # PAR DEFAUT. Meme precedent que le QHS : la ligne existe et est editable, elle ne deplace
    # rien tant que le maire ne l'a pas decidee. Si ce compte retombait a 25, ce serait le signe
    # qu'une part a zero a de nouveau ete prise pour une absence de regle et effacee.
    att("lignes de repartition budgetaire seedees",
        cat.lignes.get("repartitions_budgetaires", 0), 28,
        "10 nationales (9/100 x 9 + Assemblee 19/100), Caserne 65/100, Douanes 35/100, "
        "QHS 0/100, 3 tribunaux a 1/3, 3 x 3 municipales a 40/40/20, et 3 subventions a 0/100")
    att("versements budgetaires seedes", cat.lignes.get("repartitions_versements", 0), 0,
        "journal des versements reels : un monde neuf nait sans historique, sinon le premier "
        "minuit croirait avoir deja verse")
    # MEME RAISON, MEME ZERO. Le compteur des recettes du jour est de l'etat vivant pur : un
    # monde neuf doit naitre sans aucune ligne, sinon sa premiere cascade municipale repartirait
    # des recettes qu'aucune commune n'a percues.
    att("compteur de recettes municipales seede",
        cat.lignes.get("recettes_municipales", 0), 0,
        "mesure du jour, jamais une tresorerie : un monde neuf nait sans recette percue")
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
