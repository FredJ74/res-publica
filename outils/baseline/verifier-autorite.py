#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Controle de l'ARCHITECTURE D'AUTORITE (chantier 3, 6 octobre 2026).

Les huit autres controles verifient que le depot DIT LA VERITE sur la base.
Celui-ci verifie une chose differente, et qui ne s'en deduit pas : que cette
verite est TENABLE. Un baseline peut etre parfaitement fidele a une base ou
n'importe quel visiteur reecrit le budget national.

LA QUESTION POSEE : qui peut ecrire quoi depuis un navigateur ?

Trois sources, confrontees l'une a l'autre :

  1. LE CODE DU NAVIGATEUR   les 58 fichiers charges par index.html -- ce que
                             le client fait reellement
  2. LA DECLARATION          outils/baseline/autorite.json -- ce qu'on admet
                             qu'il fasse
  3. LE BASELINE             baseline/domaines/*/{60,70}_*.sql -- ce que la
                             base lui permet

Un ecart entre 1 et 2 est une mutation cliente introduite sans decision : c'est
le garde-fou. Un ecart entre 2 et 3 est un droit que personne n'utilise, ou une
barriere qui manque.

TREIZE INVARIANTS, en trois familles qui echouent independamment.

  FAMILLE 1 -- LE CODE                      (toujours bloquante)
    1. aucune mutation cliente hors de la surface declaree
    2. aucun acces PostgREST brut non recense
    3. toute identite de personnage passee a une RPC est verifiee au serveur

  FAMILLE 2 -- L'ETAT DE LA BASE, via le baseline
    4. aucun privilege de maintenance aux roles clients
    5. `anon` n'ecrit nulle part : ni table, ni vue, ni sequence
    6. aucun droit d'ecriture de `authenticated` hors surface declaree
    7. aucune policy d'ecriture totalement permissive
    8. aucune table sans RLS
    9. aucune fonction de declencheur appelable par un role client
   10. aucune fonction mutante client-appelable sans garde d'acteur
   11. aucune fonction mutante appelable par `anon`

  FAMILLE 3 -- LES PORTES SERVEUR            (toujours bloquante)
   12. tout objet nomme par une migration en attente existe dans le baseline
   13. toute RPC appelee par le navigateur existe, avec ces parametres-la

Le treizieme vient d'une panne deja vue : une RPC livree cote client dont la
migration n'avait pas ete appliquee. PostgREST repond 404, le jeu affiche
« Acces refuse », et on cherche une faille de droits la ou il n'y a qu'une
fonction absente. Fermer des acces directs sans ce controle, c'est deplacer le
risque : la porte serveur devient le seul chemin, et un seul parametre mal
nomme la ferme.

LES ECARTS EN ATTENTE D'UNE MIGRATION. Le principe 2G interdit d'avancer le
baseline sur la base : tant qu'une migration preparee n'est pas appliquee, les
invariants qu'elle ferme sont forcement en ecart. autorite.json les nomme dans
`en_attente_d_application`, avec le fichier de migration qui les ferme. Un
invariant qui y figure est rapporte sans faire echouer le controle.

Le controle refuse les DEUX incoherences possibles :
  . un invariant en ecart SANS etre declare en attente      -> ECHEC
  . un invariant declare en attente mais DEJA satisfait     -> ECHEC
La seconde est la plus importante : c'est elle qui empeche la liste d'attente de
pourrir apres l'application des migrations.

Usage :
    python3 outils/baseline/verifier-autorite.py
    python3 outils/baseline/verifier-autorite.py --detail
Code de sortie 0 si l'architecture d'autorite tient, 1 sinon.

Cet outil n'accede pas a la base et n'ecrit rien.
"""

import collections
import glob
import json
import os
import re
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(os.path.dirname(ICI))
BASELINE = os.path.join(RACINE, "baseline")
DOMAINES = os.path.join(BASELINE, "domaines")
DECLARATION = os.path.join(ICI, "autorite.json")
MIGRATIONS = os.path.join(RACINE, "migrations")

ROLES_CLIENTS = ("anon", "authenticated", "PUBLIC")
MAINTENANCE = ("MAINTAIN", "REFERENCES", "TRIGGER", "TRUNCATE")
ECRITURES = ("INSERT", "UPDATE", "DELETE")
CODE = {"INSERT": "I", "UPDATE": "U", "DELETE": "D"}

# Les briques qui disent QUI PARLE. Une fonction qui en cite une derive son
# acteur du serveur ; une fonction qui n'en cite aucune fait confiance a ses
# parametres. C'est toute la difference que ce chantier traque.
GARDES = re.compile(
    r"(exiger_acteur|est_mon_personnage|mon_personnage|mon_poste_est|mon_poste_est_dans"
    r"|acteur_poste_courant|poste_est_atteste|acteur_present_sur_site|acteur_identifie"
    r"|est_appel_serveur|auth\.uid)\s*\(")

# « cette fonction ecrit-elle ? » -- lu dans sa definition.
MUTE = re.compile(r"(?i)(insert\s+into|update\s+(public\.)?[a-z_]+\s+set|delete\s+from)")
REND_TRIGGER = re.compile(r"\)\s*\n\s*RETURNS trigger\b")

# Un parametre qui designe une personne. La liste vient du relevé des 249 RPC
# appelees par le navigateur ; elle n'a pas a etre exhaustive du possible, elle
# doit couvrir ce que le projet nomme.
PARAM_IDENTITE = re.compile(
    r"(?i)^p_?(nom|name|personnage|acteur|joueur|auteur|expediteur|demandeur"
    r"|proprietaire|titulaire|createur|membre|votant|testateur|offreur|inviteur|recruteur)$")


# ---------------------------------------------------------------------------
# LECTURE DU CODE DU NAVIGATEUR
# ---------------------------------------------------------------------------
def fichiers_du_navigateur():
    """Tout ce qu'un navigateur charge : les .js et .html de la racine, plus
    i18n/. api/ en est EXCLU -- ces 16 fichiers tournent cote serveur sous
    service_role, qui ignore droits clients et RLS. Les confondre ferait passer
    une porte serveur pour un acces direct."""
    return sorted(glob.glob(os.path.join(RACINE, "*.js"))
                  + glob.glob(os.path.join(RACINE, "*.html"))
                  + glob.glob(os.path.join(RACINE, "i18n", "*.js")))


def surface_du_navigateur():
    """Ce que le navigateur mute, verbe par verbe. DEUX detecteurs, et il faut
    les deux : les helpers sbInsert/sbUpdate/sbDelete, et les fetch PostgREST
    bruts -- c'est par un fetch brut que passe la CREATION de personnage, qu'un
    detecteur limite aux helpers ne verrait jamais."""
    par_table = collections.defaultdict(set)
    sites = collections.defaultdict(list)
    bruts = []
    helpers = (("sbInsert", "I"), ("sbUpdate", "U"), ("sbDelete", "D"))
    # `rest/v1/rpc/...` est un APPEL DE FONCTION, pas une table : l'exclure,
    # sinon le controle croit a une table nommee « rpc » mutee par le navigateur.
    motif_brut = re.compile(r"""rest/v1/(?!rpc\b)(?:\$\{[^}]*\}|)([a-z_0-9]+)""")
    for chemin in fichiers_du_navigateur():
        court = os.path.relpath(chemin, RACINE)
        texte = open(chemin, encoding="utf-8", errors="replace").read()
        for helper, verbe in helpers:
            for m in re.finditer(r"\b%s\(\s*['\"]([a-z_0-9]+)['\"]" % helper, texte):
                par_table[m.group(1)].add(verbe)
                sites[(m.group(1), verbe)].append(
                    "%s:%d" % (court, texte[:m.start()].count("\n") + 1))
        # fetch brut : on lit la table citee dans l'URL puis la methode HTTP
        # qui suit dans les ~400 caracteres de l'appel.
        for m in motif_brut.finditer(texte):
            table = m.group(1)
            if not table:
                continue
            fenetre = texte[m.end():m.end() + 400]
            meth = re.search(r"method:\s*'(POST|PATCH|PUT|DELETE)'", fenetre)
            if not meth:
                continue
            verbe = {"POST": "I", "PATCH": "U", "PUT": "U", "DELETE": "D"}[meth.group(1)]
            ligne = texte[:m.start()].count("\n") + 1
            par_table[table].add(verbe)
            sites[(table, verbe)].append("%s:%d" % (court, ligne))
            bruts.append({"fichier": court, "table": table, "methode": meth.group(1),
                          "ligne": ligne})
            # un upsert PostgREST est un INSERT ... ON CONFLICT DO UPDATE :
            # il exige UPDATE en plus d'INSERT. Sans cette ligne, le controle
            # reclamerait la revocation d'un droit indispensable.
            if verbe == "I" and "merge-duplicates" in fenetre:
                par_table[table].add("U")
                sites[(table, "U")].append("%s:%d (upsert)" % (court, ligne))
    return par_table, sites, bruts


def rpc_du_navigateur():
    """Les RPC appelees par le navigateur, FORME PAR FORME.

    Pas une union des parametres de tous les sites d'appel : une fonction a deux
    surcharges peut etre appelee sous ses deux formes, et l'union ne
    correspondrait alors a aucune des deux. On garde donc chaque jeu de
    parametres tel qu'il part, avec le site qui l'envoie."""
    formes = collections.defaultdict(lambda: collections.defaultdict(list))
    for chemin in fichiers_du_navigateur():
        court = os.path.relpath(chemin, RACINE)
        texte = open(chemin, encoding="utf-8", errors="replace").read()
        for m in re.finditer(r"sbRpc\(\s*['\"]([a-z_0-9]+)['\"]\s*,\s*\{", texte):
            i = m.end() - 1
            prof, j = 0, i
            while j < len(texte):
                if texte[j] == "{":
                    prof += 1
                elif texte[j] == "}":
                    prof -= 1
                    if prof == 0:
                        break
                j += 1
            passes = frozenset(
                re.findall(r"[{,]\s*([A-Za-z_][A-Za-z_0-9]*)\s*:", texte[i:j + 1]))
            formes[m.group(1)][passes].append(
                "%s:%d" % (court, texte[:m.start()].count("\n") + 1))
    return formes


# ---------------------------------------------------------------------------
# LECTURE DU BASELINE
# ---------------------------------------------------------------------------
def droits_du_baseline():
    """Les GRANT du baseline, separes par nature d'objet. Le baseline ecrit un
    GRANT par role et peut grouper plusieurs privileges : on deplie les deux."""
    relations = collections.defaultdict(lambda: collections.defaultdict(set))
    sequences = collections.defaultdict(lambda: collections.defaultdict(set))
    fonctions = collections.defaultdict(lambda: collections.defaultdict(set))
    motif = re.compile(
        r"^\s*GRANT\s+(.+?)\s+ON\s+(TABLE|SEQUENCE|FUNCTION)\s+public\.([a-z_0-9]+)"
        r"(\([^)]*\))?\s+TO\s+([^;]+);", re.I)
    for chemin in sorted(glob.glob(os.path.join(DOMAINES, "*", "*droits*.sql"))):
        for ligne in open(chemin, encoding="utf-8"):
            m = motif.match(ligne)
            if not m:
                continue
            privileges = [p.strip().upper().split("(")[0].strip()
                          for p in m.group(1).split(",")]
            cible = {"TABLE": relations, "SEQUENCE": sequences,
                     "FUNCTION": fonctions}[m.group(2).upper()]
            nom = m.group(3) + (m.group(4) or "")
            for role in (r.strip() for r in m.group(5).split(",")):
                cible[nom][role].update(privileges)
    return relations, sequences, fonctions


def policies_du_baseline():
    """Les policies du baseline et les tables dont la RLS est active.

    Decoupage par bloc plutot que par expression reguliere sur l'expression :
    une qualification peut tenir sur cinq lignes et contenir des parentheses.
    On ne cherche d'ailleurs pas a la comprendre -- seulement a savoir si elle
    est litteralement `true`, et le rendu la met alors seule sur sa ligne."""
    policies = []
    rls_active = set()
    tables_rendues = set()
    entete = re.compile(
        r"^(\"[^\"]+\"|[A-Za-z_0-9]+)\s+ON\s+public\.([a-z_0-9]+)\s+"
        r"(?:AS\s+(?:PERMISSIVE|RESTRICTIVE)\s+)?FOR\s+(ALL|SELECT|INSERT|UPDATE|DELETE)\s+TO\s+(.+)$")
    for chemin in sorted(glob.glob(os.path.join(DOMAINES, "*", "*rls-policies*.sql"))):
        texte = open(chemin, encoding="utf-8").read()
        for m in re.finditer(r"^ALTER TABLE public\.([a-z_0-9]+) ENABLE ROW LEVEL SECURITY",
                             texte, re.M):
            rls_active.add(m.group(1))
        for bloc in re.split(r"(?m)^CREATE POLICY ", texte)[1:]:
            lignes = bloc.split("\n")
            m = entete.match(lignes[0].strip())
            if not m:
                continue
            clauses = [l.strip().rstrip(";") for l in lignes[1:] if l.startswith("  ")]
            using = next((c for c in clauses if c.startswith("USING ")), None)
            check = next((c for c in clauses if c.startswith("WITH CHECK ")), None)
            policies.append({
                "nom": m.group(1).strip('"'), "table": m.group(2),
                "cmd": {"ALL": "*", "SELECT": "r", "INSERT": "a",
                        "UPDATE": "w", "DELETE": "d"}[m.group(3)],
                "roles": [r.strip() for r in m.group(4).split(",")],
                # absente = sans condition, exactement comme PostgreSQL l'entend
                "using_vrai": using is None or using == "USING (true)",
                "check_vrai": check is None or check == "WITH CHECK (true)",
            })
    for chemin in sorted(glob.glob(os.path.join(DOMAINES, "*", "1*_tables*.sql"))):
        texte = open(chemin, encoding="utf-8").read()
        for m in re.finditer(r"^CREATE TABLE public\.([a-z_0-9]+)", texte, re.M):
            tables_rendues.add(m.group(1))
    return policies, rls_active, tables_rendues


def fonctions_du_baseline():
    """nom -> texte de toutes ses definitions (les surcharges sont concatenees :
    on ne cherche pas a distinguer les signatures, seulement a savoir si une
    garde apparait quelque part)."""
    defs = collections.defaultdict(list)
    for chemin in sorted(glob.glob(os.path.join(DOMAINES, "*", "*fonctions*.sql"))):
        texte = open(chemin, encoding="utf-8").read()
        for morceau in re.split(r"(?m)^CREATE OR REPLACE FUNCTION public\.", texte)[1:]:
            nom = re.match(r"([a-z_0-9]+)", morceau)
            if nom:
                defs[nom.group(1)].append(morceau)
    return {nom: "\n".join(v) for nom, v in defs.items()}


def parametres_du_baseline():
    """nom de fonction -> liste des jeux de parametres, une entree par surcharge.
    Les surcharges comptent : le navigateur appelle parfois une forme courte
    d'une fonction qui en a deux."""
    formes = collections.defaultdict(list)
    for chemin in sorted(glob.glob(os.path.join(DOMAINES, "*", "*fonctions*.sql"))):
        texte = open(chemin, encoding="utf-8").read()
        for morceau in re.split(r"(?m)^CREATE OR REPLACE FUNCTION public\.", texte)[1:]:
            nom = re.match(r"([a-z_0-9]+)", morceau)
            sig = re.match(r"[a-z_0-9]+\((.*?)\)\s*\n\s*RETURNS", morceau, re.S)
            if not (nom and sig):
                continue
            noms = set()
            # decoupe sur les virgules de premier niveau : un type peut en
            # contenir (numeric(10,2)), et une valeur par defaut aussi.
            for arg in re.split(r",(?![^(]*\))", sig.group(1)):
                m = re.match(r"\s*([A-Za-z_][A-Za-z_0-9]*)\s", arg)
                if m:
                    noms.add(m.group(1))
            formes[nom.group(1)].append(noms)
    return formes


def garde_a_un_saut(nom, corps):
    """Une fonction verifie son acteur si elle cite une garde, ou si elle appelle
    DIRECTEMENT une fonction qui en cite une. Un saut suffit et il est
    necessaire : assemblee_deposer ne verifie rien elle-meme, elle delegue a
    assemblee_deposer_projet, qui appelle exiger_acteur en premiere ligne.
    Au-dela d'un saut, la cloture devient vide de sens -- presque toute fonction
    finit par toucher une lecture de personnage."""
    if GARDES.search(corps.get(nom, "")):
        return True
    appelees = set(re.findall(r"(?:public\.)?([a-z_][a-z_0-9]{3,})\s*\(", corps.get(nom, "")))
    return any(a != nom and GARDES.search(corps.get(a, "")) for a in appelees)


# ---------------------------------------------------------------------------
# RAPPORT
# ---------------------------------------------------------------------------
class Rapport(object):
    def __init__(self, attente):
        self.attente = attente          # numero d'invariant -> migration
        self.resultats = []             # (num, titre, [ecarts])
        self.famille_courante = None

    def famille(self, titre):
        self.famille_courante = titre
        print("\n%s" % titre)
        print("  " + "-" * 70)

    def invariant(self, num, titre, ecarts, detail=False):
        self.resultats.append((num, titre, list(ecarts)))
        en_attente = str(num) in self.attente
        if not ecarts:
            etat = "OK " if not en_attente else "DEJA FERME (a retirer de l'attente)"
        else:
            etat = "ATTENDU" if en_attente else "ECHEC"
        print("  %2d. %-52s %-7s %s"
              % (num, titre, "%d ecart%s" % (len(ecarts), "s" if len(ecarts) != 1 else ""), etat))
        if ecarts and en_attente:
            print("      ferme par migrations/%s" % self.attente[str(num)])
        garde = ecarts if detail else ecarts[:6]
        for e in garde:
            print("      - %s" % e)
        if not detail and len(ecarts) > len(garde):
            print("      ... et %d autre(s)" % (len(ecarts) - len(garde)))

    def verdict(self):
        echecs, perimes = [], []
        for num, titre, ecarts in self.resultats:
            en_attente = str(num) in self.attente
            if ecarts and not en_attente:
                echecs.append((num, titre, len(ecarts)))
            if not ecarts and en_attente:
                perimes.append((num, titre))
        print("\n" + "=" * 72)
        if echecs:
            print("ECHEC : %d invariant(s) en ecart sans migration declaree" % len(echecs))
            for num, titre, n in echecs:
                print("  - invariant %d : %s (%d ecarts)" % (num, titre, n))
        if perimes:
            print("ECHEC : %d invariant(s) declare(s) en attente mais DEJA satisfait(s)."
                  % len(perimes))
            print("        Retire-les de en_attente_d_application dans autorite.json :")
            for num, titre in perimes:
                print("  - invariant %d : %s" % (num, titre))
        if echecs or perimes:
            return 1
        attendus = [(n, t, len(e)) for n, t, e in self.resultats
                    if e and str(n) in self.attente]
        if attendus:
            print("CONFORME, MIGRATIONS EN ATTENTE.")
            print("L'architecture declaree tient, et les %d invariant(s) encore en ecart"
                  % len(attendus))
            print("sont exactement ceux que les migrations preparees ferment :")
            for num, titre, n in attendus:
                print("  . invariant %-2d  %-48s %3d ecarts  ->  %s"
                      % (num, titre, n, self.attente[str(num)]))
            print("\nLe baseline SUIT la base : il ne sera reextrait qu'APRES application.")
        else:
            print("CONFORME : les %d invariants d'autorite tiennent." % len(self.resultats))
            print("Aucune mutation cliente hors declaration, aucun privilege historique,")
            print("aucune policy permissive, aucune table sans RLS.")
        return 0


# ---------------------------------------------------------------------------
def main():
    detail = "--detail" in sys.argv
    decl = json.load(open(DECLARATION, encoding="utf-8"))
    surface_declaree = decl["surface_cliente"]
    attente = decl.get("en_attente_d_application", {})

    par_table, sites, bruts = surface_du_navigateur()
    appels_rpc = rpc_du_navigateur()
    relations, sequences, fonc_droits = droits_du_baseline()
    policies, rls_active, tables_rendues = policies_du_baseline()
    corps = fonctions_du_baseline()

    print("CONTROLE DE L'ARCHITECTURE D'AUTORITE")
    print("  %d fichiers de navigateur, %d tables mutees, %d acces PostgREST bruts"
          % (len(fichiers_du_navigateur()),
             len([t for t, v in par_table.items() if v]), len(bruts)))
    print("  %d relations et %d fonctions portant un droit, %d policies, %d definitions"
          % (len(relations), len(fonc_droits), len(policies), len(corps)))
    print("  declaration : %d tables, %d invariants en attente d'application"
          % (len(surface_declaree), len(attente)))

    r = Rapport(attente)

    # ----------------------------------------------------------- FAMILLE 1
    r.famille("FAMILLE 1 -- LE CODE DU NAVIGATEUR")

    ecarts = []
    for table in sorted(par_table):
        declare = set(surface_declaree.get(table, ""))
        for verbe in sorted(par_table[table]):
            if verbe not in declare:
                ecarts.append("%s / %s non declare — %s"
                              % (table, verbe, ", ".join(sites[(table, verbe)][:3])))
    r.invariant(1, "aucune mutation cliente hors surface declaree", ecarts, detail)

    recenses = {(a["fichier"], a["table"], a["methode"])
                for a in decl.get("acces_postgrest_bruts", [])}
    ecarts = ["%s %s dans %s:%d" % (a["methode"], a["table"], a["fichier"], a["ligne"])
              for a in bruts
              if (a["fichier"], a["table"], a["methode"]) not in recenses]
    r.invariant(2, "aucun acces PostgREST brut non recense", ecarts, detail)

    tolerees = decl.get("lectures_de_tiers_legitimes", {})
    ecarts = []
    for fn in sorted(appels_rpc):
        if fn in tolerees or fn not in corps:
            continue
        tous = {p for passes in appels_rpc[fn] for p in passes}
        identites = sorted(p for p in tous if PARAM_IDENTITE.match(p))
        if identites and not garde_a_un_saut(fn, corps):
            ecarts.append("%s recoit %s et ne verifie aucun acteur"
                          % (fn, ", ".join(identites)))
    r.invariant(3, "identite passee a une RPC toujours verifiee au serveur", ecarts, detail)

    # ----------------------------------------------------------- FAMILLE 2
    r.famille("FAMILLE 2 -- L'ETAT DE LA BASE, LU DANS LE BASELINE")

    ecarts = []
    for nom in sorted(relations):
        for role in ("anon", "authenticated", "PUBLIC"):
            for p in sorted(set(relations[nom].get(role, ())) & set(MAINTENANCE)):
                ecarts.append("%s : %s a %s" % (nom, p, role))
    r.invariant(4, "aucun privilege de maintenance aux roles clients", ecarts, detail)

    ecarts = []
    for nom in sorted(relations):
        for p in sorted(set(relations[nom].get("anon", ())) & set(ECRITURES + ("TRUNCATE",))):
            ecarts.append("table %s : %s a anon" % (nom, p))
    for nom in sorted(sequences):
        if "UPDATE" in sequences[nom].get("anon", ()):
            ecarts.append("sequence %s : UPDATE a anon (autorise setval)" % nom)
        if "UPDATE" in sequences[nom].get("authenticated", ()):
            ecarts.append("sequence %s : UPDATE a authenticated (autorise setval)" % nom)
    r.invariant(5, "anon n'ecrit nulle part, aucun setval pour un client", ecarts, detail)

    ecarts = []
    for nom in sorted(relations):
        declare = set(surface_declaree.get(nom, ""))
        for p in sorted(set(relations[nom].get("authenticated", ())) & set(ECRITURES)):
            if CODE[p] not in declare:
                ecarts.append("%s : %s accorde, jamais appele" % (nom, p))
    r.invariant(6, "aucun droit d'ecriture hors surface declaree", ecarts, detail)

    ecarts = ["%s sur %s (FOR %s TO %s)"
              % (p["nom"], p["table"],
                 {"*": "ALL", "a": "INSERT", "w": "UPDATE", "d": "DELETE"}[p["cmd"]],
                 ", ".join(p["roles"]))
              for p in policies
              if p["cmd"] != "r" and p["using_vrai"] and p["check_vrai"]]
    r.invariant(7, "aucune policy d'ecriture totalement permissive", ecarts, detail)

    ecarts = ["%s" % t for t in sorted(tables_rendues - rls_active)]
    r.invariant(8, "aucune table du baseline sans RLS", ecarts, detail)

    ecarts = []
    for nom in sorted(fonc_droits):
        court = nom.split("(")[0]
        if not REND_TRIGGER.search(corps.get(court, "")):
            continue
        roles = {r for role in fonc_droits[nom] for r in (role,)
                 if role in ROLES_CLIENTS and "EXECUTE" in fonc_droits[nom][role]}
        if roles:
            ecarts.append("%s : EXECUTE a %s" % (court, ", ".join(sorted(roles))))
    r.invariant(9, "aucune fonction de declencheur appelable par un client",
                sorted(set(ecarts)), detail)

    exceptions = decl.get("fonctions_mutantes_sans_acteur", {})
    ecarts, vus = [], set()
    for nom in sorted(fonc_droits):
        court = nom.split("(")[0]
        if court in vus or court in exceptions:
            continue
        texte = corps.get(court, "")
        if not texte or REND_TRIGGER.search(texte) or not MUTE.search(texte):
            continue
        clients = [role for role in fonc_droits[nom]
                   if role in ROLES_CLIENTS and "EXECUTE" in fonc_droits[nom][role]]
        if clients and not garde_a_un_saut(court, corps):
            vus.add(court)
            ecarts.append("%s : mutante, EXECUTE a %s, aucune garde"
                          % (court, ", ".join(sorted(clients))))
    r.invariant(10, "aucune fonction mutante client-appelable sans garde", ecarts, detail)

    ecarts, vus = [], set()
    for nom in sorted(fonc_droits):
        court = nom.split("(")[0]
        texte = corps.get(court, "")
        if not texte or REND_TRIGGER.search(texte) or not MUTE.search(texte):
            continue
        ouvert = [role for role in ("anon", "PUBLIC")
                  if "EXECUTE" in fonc_droits[nom].get(role, ())]
        if ouvert and court not in vus:
            vus.add(court)
            ecarts.append("%s : mutante, EXECUTE a %s" % (court, ", ".join(ouvert)))
    r.invariant(11, "aucune fonction mutante appelable par anon", ecarts, detail)

    # ----------------------------------------------------------- FAMILLE 3
    r.famille("FAMILLE 3 -- LES PORTES SERVEUR ET LES MIGRATIONS PREPAREES")

    # Invariant 12 -- LA DERNIERE EPREUVE QUE L'ON PEUT FAIRE HORS LIGNE.
    #
    # Une migration qui nomme une table inexistante echoue a l'application, et
    # l'application est le moment ou l'on a le moins envie de decouvrir une
    # faute de frappe. On ne peut pas la jouer ici -- aucun moteur PostgreSQL
    # n'est joignable, et la production est interdite en ecriture -- mais on
    # peut verifier que tout ce qu'elle designe existe dans le baseline, qui est
    # par construction fidele a la base (controle 3).
    ecarts = []
    tables_connues = set(relations) | tables_rendues
    signatures_connues = {re.sub(r"\s+", "", k) for k in fonc_droits}
    noms_policies = {(p["table"], p["nom"]) for p in policies}
    for chemin in sorted(glob.glob(os.path.join(MIGRATIONS, "*.sql"))):
        court = os.path.basename(chemin)
        texte = open(chemin, encoding="utf-8").read()
        # les tables declarees dans le tableau `surface` de la migration 2
        for m in re.finditer(r"\['([a-z_0-9]+)','[IUD]{1,3}'\]", texte):
            if m.group(1) not in tables_connues and m.group(1) not in set(re.findall(
                    r"CREATE TABLE (?:IF NOT EXISTS )?public\.([a-z_0-9]+)", texte)):
                ecarts.append("%s : table inconnue « %s » dans la surface declaree"
                              % (court, m.group(1)))
        # Les fonctions designees nommement (REVOKE, GRANT, COMMENT ON).
        #
        # Une fonction que la migration CREE elle-meme n'est pas inconnue : elle
        # n'existe pas encore en base, et c'est precisement le but du fichier.
        # Cette regle existait deja pour les policies, deux blocs plus bas, mais
        # pas pour les fonctions -- d'ou l'exception codee en dur « sauf
        # acteur_identifie » qui a vecu ici depuis le chantier 3. Une exception
        # qui nomme un objet est le symptome d'une regle manquante : on ecrit la
        # regle, et l'exception s'en va.
        creees = set(re.findall(r"CREATE OR REPLACE FUNCTION public\.([a-z_0-9]+)\(", texte))
        for m in re.finditer(r"ON FUNCTION public\.([a-z_0-9]+)\(([^)]*)\)", texte):
            # LES ESPACES NE FONT PAS LA SIGNATURE. Le catalogue rend
            # « ville_est_reelle(text,text) » ; un auteur de migration ecrit
            # naturellement « ville_est_reelle(text, text) ». Comparer les deux tels
            # quels rendait cet invariant DOUBLEMENT faux : il criait sur des fonctions
            # qui existent, et il serait reste muet sur une vraie inconnue ecrite sans
            # espace. Trouve le 7 octobre 2026, sur trois fonctions du chantier 4E.
            sig = "%s(%s)" % (m.group(1), re.sub(r"\s+", "", m.group(2)))
            if sig not in signatures_connues and m.group(1) not in creees:
                ecarts.append("%s : signature inconnue « %s »" % (court, sig))
        # les policies retirees nommement
        for m in re.finditer(r'DROP POLICY (?:IF EXISTS )?("[^"]+"|[A-Za-z_0-9]+) ON public\.([a-z_0-9]+)',
                             texte):
            nom = m.group(1).strip('"')
            # un DROP ... IF EXISTS sur une policy que la migration vient de
            # creer est l'idempotence, pas une erreur : on ne reclame que les
            # noms qui n'existent ni en base ni dans la migration.
            if (m.group(2), nom) not in noms_policies and ("CREATE POLICY %s " % nom) not in texte:
                ecarts.append("%s : policy inconnue « %s » sur %s"
                              % (court, nom, m.group(2)))
        # Les tables mises sous RLS.
        #
        # MEME REGLE QUE POUR LES FONCTIONS ET LES POLICIES : une table que la
        # migration CREE elle-meme n'est pas inconnue -- elle n'existe pas encore
        # en base, et c'est le but du fichier. L'invariant ne l'avait que pour les
        # deux autres familles, et refusait donc toute migration qui cree une table
        # et la met sous RLS dans le meme fichier : exactement ce qu'une migration
        # bien ecrite doit faire. Laisser le trou aurait pousse a mettre la RLS
        # dans un second fichier, c'est-a-dire a livrer une table un instant sans
        # protection.
        tables_creees = set(re.findall(
            r"CREATE TABLE (?:IF NOT EXISTS )?public\.([a-z_0-9]+)", texte))
        for m in re.finditer(r"ALTER TABLE public\.([a-z_0-9]+) ENABLE ROW LEVEL SECURITY", texte):
            if m.group(1) not in tables_connues and m.group(1) not in tables_creees:
                ecarts.append("%s : table inconnue « %s » mise sous RLS" % (court, m.group(1)))
    r.invariant(12, "les migrations en attente ne nomment rien d'inconnu", ecarts, detail)

    # Invariant 13 -- LA PORTE SERVEUR EXISTE-T-ELLE VRAIMENT ?
    #
    # Fermer un acces direct ne vaut que si la porte de remplacement s'ouvre.
    # Une RPC absente de la base repond 404, et le jeu traduit ca en « Acces
    # refuse » : on cherche alors un droit manquant la ou il manque une
    # fonction. Un parametre mal nomme donne le meme symptome, PostgREST
    # resolvant la surcharge par les NOMS des parametres, pas par leur ordre.
    formes_baseline = parametres_du_baseline()
    ecarts = []
    for fn in sorted(appels_rpc):
        if fn not in formes_baseline:
            sites = sorted({s for v in appels_rpc[fn].values() for s in v})[:2]
            ecarts.append("%s : aucune fonction de ce nom dans le baseline — %s"
                          % (fn, ", ".join(sites)))
            continue
        for passes, sites in sorted(appels_rpc[fn].items(), key=lambda kv: sorted(kv[0])):
            # <= et non == : un parametre a valeur par defaut peut etre omis.
            if not any(passes <= attendus for attendus in formes_baseline[fn]):
                ecarts.append("%s : parametres (%s) ne correspondent a aucune "
                              "surcharge — %s"
                              % (fn, ", ".join(sorted(passes)) or "aucun", sites[0]))
    r.invariant(13, "toute RPC appelee par le navigateur existe", ecarts, detail)

    return r.verdict()


if __name__ == "__main__":
    sys.exit(main())
