#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Rend la baseline COMPLETE a partir des quatre exports d'introspection.

Entree  : un repertoire contenant les sorties JSON deviees par execute_sql.
          Les quatre exports sont reconnus a leur cle discriminante :
          export_structure, export_fonctions, export_logique, export_droits.
Sortie  : baseline/domaines/<domaine>/<phase>_<categorie>.sql
          + MANIFESTE.json par domaine
          + baseline/INVENTAIRE.json, recapitulatif global

PRINCIPES
  - Le domaine d'une TABLE vient de baseline/classification-donnees.csv (2C).
  - Le domaine d'une FONCTION vient des regles ordonnees de domaines.json.
    Une fonction qui n'entre dans aucune regle FAIT ECHOUER le rendu : elle ne
    disparait jamais en silence.
  - Les objets dependants (contraintes, index, policies, declencheurs, droits,
    commentaires, RLS) suivent le domaine de leur table.
  - Les tables classees `hors_baseline` en 2C ne sont PAS rendues, et la liste
    des objets ecartes avec elles est rapportee explicitement.
  - Tri deterministe partout : COLLATE "C" cote SQL, sort() cote Python.

Usage :
    python3 outils/baseline/rendre.py <repertoire_des_exports>
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
CONF = os.path.join(ICI, "domaines.json")
CLASSIF = os.path.join(RACINE, "baseline", "classification-donnees.csv")
CIBLE = os.path.join(RACINE, "baseline", "domaines")

# Les vues ne figurent pas dans la classification 2C (qui porte sur les 252
# tables). Leur domaine est declare ici, explicitement.
DOMAINE_DES_VUES = {
    "personnages": "personnage et presence",
    "catalogue_generiques_raccordes": "economie",
}

SERIALS = {"bigint": "bigserial", "integer": "serial", "smallint": "smallserial"}

# Les codes de pg_default_acl.defaclobjtype, traduits dans la syntaxe d'ALTER DEFAULT
# PRIVILEGES. Ils ne coincident PAS avec ceux d'acldefault() -- 'S' contre 's', 'T' contre
# 't' -- et la requete d'extraction fait la conversion de son cote.
TYPES_DEFAUT = {"r": "TABLES", "S": "SEQUENCES", "f": "FUNCTIONS",
                "T": "TYPES", "n": "SCHEMAS"}
TAILLE_MAX_FICHIER = 150_000      # au-dela, un fichier de phase est subdivise

ENTETE = """-- {titre}
-- ============================================================================
-- BASELINE Human Gambit -- domaine {domaine} -- phase {phase} : {categorie}
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

"""


# ----------------------------------------------------------------- chargement
def charger_exports(rep):
    """Lit les sorties deviees et les fusionne. Chaque fichier est reconnu a sa
    cle discriminante, jamais a son nom."""
    cles = {"export_structure", "export_fonctions", "export_logique", "export_droits"}
    exp, vus = {}, []
    for f in sorted(glob.glob(os.path.join(rep, "*.txt"))):
        brut = open(f, encoding="utf-8").read()
        try:
            externe = json.loads(brut)["result"]
        except Exception:
            continue
        m = re.search(r"<untrusted-data-[0-9a-f-]+>\n(.*)\n</untrusted-data-", externe, re.S)
        if not m:
            continue
        try:
            lignes = json.loads(m.group(1))
        except Exception:
            continue
        if not lignes or not isinstance(lignes[0], dict):
            continue
        cle = next((k for k in lignes[0] if k in cles), None)
        if not cle:
            continue
        exp.update(lignes[0][cle] or {})
        vus.append((os.path.basename(f), cle, len(brut)))
    return exp, vus


def charger_classification():
    tbl_dom, tbl_strat, tbl_cat = {}, {}, {}
    for l in csv.DictReader(open(CLASSIF, encoding="utf-8"), delimiter=";"):
        tbl_dom[l["table"]] = l["domaine"]
        tbl_strat[l["table"]] = l["strategie"]
        tbl_cat[l["table"]] = l["categorie"]
    return tbl_dom, tbl_strat, tbl_cat


def domaine_fonction(proname, conf):
    s = conf["_regles_fonctions"]["surcharges"].get(proname)
    if s:
        return s[0]
    for dom, rx in conf["_regles_fonctions"]["regles"]:
        if re.match(rx, proname):
            return dom
    return None


# -------------------------------------------------------------------- rendus
def rendre_colonne(col, seq_par_col):
    nom, typ, defaut = col["attname"], col["type"], col.get("defaut")
    bouts = [nom]
    if defaut and defaut.startswith("nextval(") and (col["tbl"], nom) in seq_par_col and typ in SERIALS:
        bouts.append(SERIALS[typ])
    else:
        bouts.append(typ)
        if col.get("identity") == "a":
            bouts.append("GENERATED ALWAYS AS IDENTITY")
        elif col.get("identity") == "d":
            bouts.append("GENERATED BY DEFAULT AS IDENTITY")
        elif defaut:
            bouts.append("DEFAULT " + defaut)
    if col.get("collation"):
        bouts.insert(2, 'COLLATE "%s"' % col["collation"])
    if col.get("non_nul"):
        bouts.append("NOT NULL")
    return " ".join(bouts)


def ingredient_colonnes(cols):
    """Empreinte des faits du catalogue pour une table, formule identique a celle
    de CONTROLE_GLOBAL dans requetes.py. `non_nul` doit etre rendu comme
    PostgreSQL rend un booleen en texte : 'true' / 'false', en minuscules."""
    bouts = []
    for c in sorted(cols, key=lambda x: x["attnum"]):
        bouts.append("%d:%s:%s:%s:%s:%s" % (
            c["attnum"], c["attname"], c["type"],
            "true" if c["non_nul"] else "false",
            c.get("identity") or "", c.get("defaut") or ""))
    return hashlib.md5("|".join(bouts).encode("utf-8")).hexdigest()


def phase_tables(objets, man, exp):
    seq_par_col = {(s["tbl"], s["colonne"]): s["sequence"]
                   for s in (exp.get("sequences") or []) if s.get("lien") == "a" and s.get("tbl")}
    par_table = {}
    for c in objets["colonnes"]:
        par_table.setdefault(c["tbl"], []).append(c)
    out = []
    for tbl in sorted(par_table):
        cols = sorted(par_table[tbl], key=lambda c: c["attnum"])
        corps = ",\n  ".join(rendre_colonne(c, seq_par_col) for c in cols)
        out.append("CREATE TABLE public.%s (\n  %s\n);" % (tbl, corps))
        man["tables"].append({
            "nom": tbl, "colonnes": len(cols),
            # Empreinte des FAITS du catalogue, meme formule que CONTROLE_GLOBAL.
            # C'est ce qui permet de recomposer l'empreinte globale des colonnes
            # sans reparser le CREATE TABLE -- dont le texte, lui, differe du
            # catalogue a cause de la regle du bigserial.
            "empreinte_catalogue": ingredient_colonnes(cols),
            # Empreinte du TEXTE ecrit, pour detecter une retouche manuelle du
            # corps de la table sans toucher au reste du fichier.
            "empreinte_texte": hashlib.md5(corps.encode("utf-8")).hexdigest(),
        })
    # Toutes les sequences du domaine sont declarees au manifeste, possedees
    # comprises : une sequence possedee n'apparait dans aucun CREATE SEQUENCE
    # (elle naît du type serial), et serait donc invisible au controle.
    for s in sorted(objets.get("sequences", []), key=lambda x: x["sequence"]):
        man["sequences"].append({"nom": s["sequence"], "tbl": s.get("tbl"),
                                 "possedee": s.get("lien") == "a"})
    auto = [s for s in objets.get("sequences", []) if s.get("lien") != "a"]
    if auto:
        out.append("\n-- Sequences autonomes (non possedees par une colonne)")
        for s in sorted(auto, key=lambda x: x["sequence"]):
            out.append("CREATE SEQUENCE public.%s;" % s["sequence"])
            man["sequences_autonomes"].append(s["sequence"])
    return out


def phase_fonctions(objets, man, exp):
    out = []
    for f in sorted(objets["fonctions"], key=lambda x: x["signature"]):
        entete = ("-- %s -> %s | %s | %s%s"
                  % (f["signature"], f["retour"], f["langage"],
                     "SECURITY DEFINER" if f["security_definer"] else "SECURITY INVOKER",
                     (" | " + ", ".join(f["configuration"])) if f.get("configuration") else ""))
        # Un bloc = une fonction entiere, commentaire inclus. C'est ce qui rend
        # la decoupe d'un gros fichier inoffensive.
        #
        # LE POINT-VIRGULE FINAL EST AJOUTE ICI, ET IL N'EST PAS DECORATIF.
        # pg_get_functiondef() ne termine PAS par un point-virgule : aucune des
        # 641 definitions de ce schema n'en porte. Sans lui, deux definitions
        # consecutives se collent et PostgreSQL lit « $function$ CREATE OR
        # REPLACE FUNCTION » comme un seul ordre malforme -- « syntax error at
        # or near CREATE ». Le fichier serait fidele et inapplicable. Defaut
        # trouve au chantier 2F, par l'analyseur de PostgreSQL lui-meme.
        out.append(entete + "\n" + f["definition"].rstrip() + ";")
        man["fonctions"].append({"signature": f["signature"], "empreinte": f["empreinte"],
                                 "security_definer": f["security_definer"]})
    return out


def phase_contraintes(objets, man, exp):
    ordre = {"p": 1, "u": 2, "c": 3, "f": 4}
    libel = {"p": "CLES PRIMAIRES", "u": "CONTRAINTES D'UNICITE",
             "c": "CONTRAINTES DE VALIDATION", "f": "CLES ETRANGERES"}
    out, courant = [], None
    for k in sorted(objets["contraintes"], key=lambda x: (ordre.get(x["genre"], 9), x["tbl"], x["nom"])):
        if k["genre"] != courant:
            out.append("\n-- " + libel.get(k["genre"], k["genre"]))
            courant = k["genre"]
        out.append("ALTER TABLE public.%s ADD CONSTRAINT %s %s;" % (k["tbl"], k["nom"], k["definition"]))
        man["contraintes"].append({"tbl": k["tbl"], "nom": k["nom"], "genre": k["genre"],
                                   "empreinte": k["empreinte"]})
    return out


def phase_index(objets, man, exp):
    portes = sorted([i for i in objets["index"] if i.get("contrainte")], key=lambda x: x["nom"])
    auto = sorted([i for i in objets["index"] if not i.get("contrainte")], key=lambda x: x["nom"])
    out = ["-- %d index sont portes par une contrainte et NE SONT PAS recrees ici." % len(portes)]
    for i in portes:
        out.append("--   %s  (contrainte %s)" % (i["nom"], i["contrainte"]))
        man["index_portes"].append(i["nom"])
    out.append("")
    if auto:
        out.append("-- Index autonomes :")
        for i in auto:
            out.append(i["definition"] + ";")
            man["index_autonomes"].append({"nom": i["nom"], "empreinte": i["empreinte"]})
    else:
        out.append("-- Aucun index autonome dans ce domaine.")
    return out


def phase_vues(objets, man, exp):
    if not objets["vues"]:
        return []
    out = []
    for v in sorted(objets["vues"], key=lambda x: x["vue"]):
        opts = v.get("reloptions")
        out.append("-- Vue %s | reloptions = %s"
                   % (v["vue"], ", ".join(opts) if opts else "AUCUNE"))
        if not opts:
            # CE COMMENTAIRE DISAIT UNE CHOSE FAUSSE, et il la disait sur TOUTES les vues.
            #
            # Il affirmait « ne JAMAIS ajouter security_invoker : son absence est ce qui fait
            # tenir le masquage des colonnes privees ». Emis sans condition pour chaque vue sans
            # reloptions, il etait :
            #   . FAUX pour catalogue_generiques_raccordes, un simple COUNT sans masquage, sans
            #     auth.uid(), dont les deux tables sont deja lisibles par anon et authenticated ;
            #   . INEXACT pour personnages, dont le masquage repose sur auth.uid() et
            #     est_appel_serveur() -- que security_invoker ne deplace pas. Ce qui tiendrait
            #     reellement a security_invoker, c'est la LECTURE : personnages_donnees a fait
            #     l'objet d'un REVOKE ALL delibere pour anon et authenticated, et la vue est ce
            #     qui leur donne acces. En invoker, chaque lecture cliente leverait un 42501.
            #
            # Un generateur ne peut pas savoir pourquoi une vue donnee est en SECURITY DEFINER.
            # Il enonce donc le FAIT, et renvoie a la ou l'intention est consignee. Enoncer un
            # motif qu'on ne connait pas, c'est fabriquer une preuve.
            out.append("-- SECURITY DEFINER (par defaut : reloptions vide). Cette vue s'execute donc")
            out.append("-- avec les droits de son PROPRIETAIRE, et les policies RLS des tables")
            out.append("-- sous-jacentes sont evaluees pour lui, pas pour l'appelant.")
            out.append("-- Intentionnel ou vestigial ? La reponse est dans")
            out.append("-- baseline/DIFFERENCES-DELIBEREES.json, cle vues_security_definer.")
        out.append("CREATE OR REPLACE VIEW public.%s AS\n%s" % (v["vue"], v["definition"].rstrip()))
        if opts:
            # LE COMMENTAIRE NE SUFFIT PAS : IL FAUT L'INSTRUCTION (corrige le 9 octobre 2026).
            #
            # `CREATE OR REPLACE VIEW` ne pose AUCUNE reloption. Jusqu'ici le rendu se contentait
            # de les annoncer en commentaire -- ce qui etait sans consequence tant qu'aucune vue
            # n'en portait. Des que `catalogue_generiques_raccordes` est passee en
            # `security_invoker = true`, le baseline s'est mis a DIRE une chose qu'il ne savait
            # pas REFAIRE : rejoue, il aurait reconstruit la vue en SECURITY DEFINER, c'est-a-dire
            # exactement l'alerte qu'on venait de fermer. Un baseline doit pouvoir rejouer ce
            # qu'il decrit, sinon il n'est qu'une description.
            out.append("ALTER VIEW public.%s SET (%s);" % (v["vue"], ", ".join(opts)))
        out.append("")
        man["vues"].append({"nom": v["vue"], "empreinte": v["empreinte"], "reloptions": opts})
    return out


def phase_triggers(objets, man, exp):
    out = []
    for t in sorted(objets["triggers"], key=lambda x: (x["tbl"], x["nom"])):
        out.append(t["definition"] + ";")
        if t.get("actif") != "O":
            out.append("ALTER TABLE public.%s DISABLE TRIGGER %s;" % (t["tbl"], t["nom"]))
        man["triggers"].append({"tbl": t["tbl"], "nom": t["nom"], "fonction": t["fonction"],
                                "empreinte": t["empreinte"]})
    return out


def phase_rls(objets, man, exp):
    out = ["-- Activation de la RLS. Une table dont la RLS est active SANS policy est",
           "-- fermee a tout role soumis a la RLS : c'est un etat VOULU, pas un oubli.", ""]
    for r in sorted(objets["rls"], key=lambda x: x["tbl"]):
        if r["active"]:
            out.append("ALTER TABLE public.%s ENABLE ROW LEVEL SECURITY;" % r["tbl"])
        if r.get("forcee"):
            out.append("ALTER TABLE public.%s FORCE ROW LEVEL SECURITY;" % r["tbl"])
        man["rls"].append({"tbl": r["tbl"], "active": r["active"], "forcee": r.get("forcee")})
    courant = None
    for p in sorted(objets["policies"], key=lambda x: (x["tbl"], x["nom"])):
        if p["tbl"] != courant:
            out.append("\n-- %s" % p["tbl"])
            courant = p["tbl"]
        out.append(p["definition"])
        man["policies"].append({
            "tbl": p["tbl"], "nom": p["nom"], "empreinte": p["empreinte"],
            # L'empreinte 2B ignore le role vise par le TO : un « TO anon »
            # devenu « TO authenticated » y passerait inapercu. Celle-ci porte
            # sur l'ordre complet.
            "empreinte_avec_roles": hashlib.md5(p["definition"].encode("utf-8")).hexdigest()})
    return out


def phase_droits(objets, man, exp):
    out, courant = [], None
    for d in sorted(objets["droits"], key=lambda x: (x["genre"], x["objet"], x["beneficiaire"])):
        if d["genre"] != courant:
            out.append("\n-- DROITS SUR LES %sS" % d["genre"])
            courant = d["genre"]
        out.append("GRANT %s ON %s public.%s TO %s;"
                   % (d["privileges"], d["genre"], d["objet"], d["beneficiaire"]))
        man["droits"].append({"genre": d["genre"], "objet": d["objet"],
                              "beneficiaire": d["beneficiaire"], "privileges": d["privileges"]})
    for d in sorted(objets["droits_colonnes"], key=lambda x: (x["tbl"], x["colonne"], x["beneficiaire"])):
        out.append("-- DROIT AU NIVEAU COLONNE : invisible dans relacl, a ne jamais oublier")
        out.append("GRANT %s (%s) ON TABLE public.%s TO %s;"
                   % (d["privileges"], d["colonne"], d["tbl"], d["beneficiaire"]))
        man["droits_colonnes"].append(d)
    return out


def phase_defauts(objets, man, exp):
    """Les PRIVILEGES PAR DEFAUT : ce que recevra un objet qui n'existe pas encore.

    POURQUOI UNE PHASE A PART, ET POURQUOI LA DERNIERE. Un default privilege ne touche
    AUCUN objet existant : il ne vaut que pour ce qui sera cree APRES lui. Le poser en
    tete de reconstruction serait donc un contresens doublement dangereux -- les 664
    fonctions et les 254 tables naitraient avec ces droits, puis la phase 70 ajouterait
    leurs GRANT exacts SANS retirer les surnumeraires, et la base reconstruite serait
    PLUS PERMISSIVE que la vraie. Place en fin, ce bloc ne change rien a ce qui vient
    d'etre reconstruit et regle seulement le comportement FUTUR -- ce qui est
    exactement sa semantique.

    POURQUOI DEUX NIVEAUX QU'IL NE FAUT PAS APLATIR. PostgreSQL distingue l'entree
    GLOBALE (`FOR ROLE x`, sans IN SCHEMA) de l'entree PAR SCHEMA (`IN SCHEMA s`), et
    les deux se COMBINENT. Mesure du 9 octobre 2026 : le `PUBLIC EXECUTE` que PostgreSQL
    donne nativement a toute fonction ne se retire QUE par l'entree globale -- un
    `REVOKE ... IN SCHEMA public ... FROM PUBLIC` est purement inoperant, il ne modifie
    meme pas la ligne stockee. Confondre les deux niveaux, c'est donc produire un rendu
    qui a l'air juste et qui ne ferme rien.

    POURQUOI LES REVOCATIONS SONT DERIVEES. Une ACL stockee n'exprime que des GRANT :
    elle ne dit jamais « PUBLIC n'a rien », elle se contente de ne pas le mentionner. La
    requete d'extraction compare donc l'ACL stockee a `acldefault()` et rend dans
    `revoque_du_natif` ce que le natif accorde et que l'ACL ne contient pas. Sans cela,
    un rendu fidele aux seuls GRANT recreerait une base ou PUBLIC garde son EXECUTE.

    POURQUOI postgres ET service_role RESTENT ECRITS. Si l'on revoquait tout jusqu'a ne
    laisser que le proprietaire, PostgreSQL SUPPRIMERAIT la ligne de pg_default_acl, et
    l'ACL d'un objet neuf repasserait a `proacl = NULL` -- c'est-a-dire au defaut natif,
    PUBLIC compris. Garder un beneficiaire non proprietaire est ce qui maintient
    l'entree en vie : fermer trop rouvre.
    """
    # Les privileges par defaut ne vivent que dans UN domaine -- le socle. Pour les
    # dix-sept autres, la phase ne produit rien et la boucle de production la saute :
    # un fichier « aucun privilege par defaut ici » par domaine metier serait du bruit,
    # puisque ce n'est pas une notion de domaine. Et l'ABSENCE d'entree n'est surtout
    # pas un etat neutre a signaler en commentaire : c'est au CONTROLE de lever, parce
    # que sans entree PostgreSQL applique son defaut natif, PUBLIC compris.
    if not objets["droits_par_defaut"]:
        return []
    out = []
    retenus = [d for d in objets["droits_par_defaut"]
               if d["administrable"] and (d["portee"] is None or d["portee"] == "public")]
    ecartes = [d for d in objets["droits_par_defaut"]
               if not (d["administrable"] and (d["portee"] is None or d["portee"] == "public"))]
    # L'ENSEMBLE DES ROLES A REVOQUER, derive de l'etat capture et non invente : tous les
    # beneficiaires observes dans pg_default_acl, proprietaires confondus, plus PUBLIC.
    # Borne, deterministe, et il s'elargit tout seul si la plateforme introduit un role.
    roles = {"PUBLIC"}
    for d in objets["droits_par_defaut"]:
        for g in (d.get("accorde") or []):
            roles.add(g["beneficiaire"])
        for g in (d.get("revoque_du_natif") or []):
            roles.add(g["beneficiaire"])

    for d in sorted(retenus, key=lambda x: (x["proprietaire"], x["portee"] or "",
                                            TYPES_DEFAUT.get(x["type_objet"], x["type_objet"]))):
        genre = TYPES_DEFAUT.get(d["type_objet"], d["type_objet"])
        cible = ("FOR ROLE %s IN SCHEMA %s" % (d["proprietaire"], d["portee"])) if d["portee"] \
                else ("FOR ROLE %s" % d["proprietaire"])
        out.append("\n-- %s / %s%s"
                   % (d["proprietaire"], genre,
                      " / schema %s" % d["portee"] if d["portee"] else " / NIVEAU GLOBAL (sans IN SCHEMA)"))
        # ON REVOQUE TOUT, PUIS ON ACCORDE L'ETAT CANONIQUE. Un rendu qui se contenterait
        # des GRANT ne serait pas CONVERGENT : applique sur une base dont le defaut est
        # deja ouvert -- et c'est le cas d'une base Supabase NEUVE, qui porte
        # `authenticated` dans ce meme reglage -- il ne retirerait rien et ne fermerait
        # rien. Eprouve au banc : parti d'un etat ouvert a PUBLIC, anon ET authenticated,
        # ce rendu aboutit exactement a {postgres, service_role}.
        for ro in sorted(roles):
            out.append("ALTER DEFAULT PRIVILEGES %s REVOKE ALL ON %s FROM %s;"
                       % (cible, genre, ro))
        for g in sorted(d["accorde"], key=lambda x: x["beneficiaire"]):
            out.append("ALTER DEFAULT PRIVILEGES %s GRANT %s ON %s TO %s;"
                       % (cible, g["privileges"], genre, g["beneficiaire"]))
        man["droits_par_defaut"].append(dict(d, rendu=True))
    # LES ENTREES ADMINISTRABLES NON RENDUES SONT INVENTORIEES QUAND MEME, avec rendu=False :
    # le manifeste doit compter la meme unite que le controle global -- l'ENTREE de
    # pg_default_acl administrable par notre role -- sinon les deux chiffres ne sont pas
    # comparables et le controle ne controle rien. Celles des autres roles n'y figurent pas :
    # elles ne sont pas a nous, et les compter ferait rougir le baseline au rythme de la
    # plateforme.
    for d in ecartes:
        if d["administrable"]:
            man["droits_par_defaut"].append(dict(d, rendu=False))
    if ecartes:
        out.append("\n-- ECARTES DU RENDU, ET NOMMES PLUTOT QUE TUS :")
        for d in sorted(ecartes, key=lambda x: (x["proprietaire"], x["portee"] or "", x["type_objet"])):
            raison = ("appartient a %s, que notre role de reconstruction n'administre pas"
                      % d["proprietaire"]) if not d["administrable"] \
                     else ("schema %s, hors du perimetre reconstruit par ce baseline" % d["portee"])
            out.append("--   %s / %s / %s -- %s"
                       % (d["proprietaire"], d["portee"] or "(global)",
                          TYPES_DEFAUT.get(d["type_objet"], d["type_objet"]), raison))
        out.append("--")
        out.append("-- DEUX SORTS DIFFERENTS, et il ne faut pas les confondre. Les entrees")
        out.append("-- ADMINISTRABLES mais hors perimetre -- celles de storage -- sont inventoriees")
        out.append("-- dans MANIFESTE.json avec rendu=false, et comptees au controle global : le")
        out.append("-- baseline en repond. Celles des AUTRES ROLES ne sont ni au manifeste ni au")
        out.append("-- compte, et c'est voulu : elles ne sont pas a nous, elles changent au rythme")
        out.append("-- de la plateforme, et les compter ferait rougir le controle pour une cause")
        out.append("-- sur laquelle nous n'avons aucune prise. Elles sont nommees ICI, et nulle")
        out.append("-- part ailleurs -- observees, jamais rejouees.")
    return out


def phase_commentaires(objets, man, exp):
    if not objets["commentaires"]:
        # Un fichier qui dit « rien ici » vaut mieux qu'un fichier absent : sans
        # lui, un relecteur ne peut pas distinguer « aucun commentaire » de
        # « extraction oubliee ».
        return ["-- Aucun commentaire d'objet dans ce domaine."]
    out = []
    for c in sorted(objets["commentaires"], key=lambda x: (x["genre"], x["objet"], x.get("colonne") or "")):
        texte = (c["texte"] or "").replace("'", "''")
        if c["genre"] == "TABLE":
            cible = "TABLE public." + c["objet"]
        elif c["genre"] == "COLUMN":
            cible = "COLUMN public.%s.%s" % (c["objet"], c["colonne"])
        elif c["genre"] == "FUNCTION":
            cible = "FUNCTION public." + c["objet"]
        else:
            cible = "CONSTRAINT %s ON public.%s" % (c["colonne"], c["objet"])
        out.append("COMMENT ON %s IS '%s';" % (cible, texte))
        man["commentaires"].append({
            "genre": c["genre"], "objet": c["objet"], "sous": c.get("colonne") or "",
            "empreinte": hashlib.md5((c["texte"] or "").encode("utf-8")).hexdigest()})
    return out


# Chaque phase : numero, categorie, titre, fonction de rendu, separateur entre
# blocs. Les deux phases dont les blocs sont de gros objets (une table, une
# fonction) sont aerees d'une ligne vide ; les autres, qui alignent des ordres
# d'une ligne, restent compactes.
PHASES = [
    (10, "tables", "Tables, colonnes, defauts et identites", phase_tables, "\n\n"),
    (20, "fonctions", "Fonctions et procedures stockees", phase_fonctions, "\n\n"),
    (30, "contraintes", "Cles primaires, unicite, validation, cles etrangeres",
     phase_contraintes, "\n"),
    (35, "index", "Index autonomes", phase_index, "\n"),
    (40, "vues", "Vues", phase_vues, "\n"),
    (50, "triggers", "Declencheurs", phase_triggers, "\n"),
    (60, "rls-policies", "Activation RLS et policies", phase_rls, "\n"),
    (70, "droits", "GRANT sur tables, colonnes et fonctions", phase_droits, "\n"),
    (80, "commentaires", "Commentaires d'objets", phase_commentaires, "\n"),
    (85, "default-privileges", "Privileges par defaut des objets a venir",
     phase_defauts, "\n"),
]

VIDE = {"colonnes": [], "fonctions": [], "contraintes": [], "index": [], "vues": [],
        "triggers": [], "rls": [], "policies": [], "droits": [], "droits_colonnes": [],
        "commentaires": [], "sequences": [], "droits_par_defaut": []}


def ecrire(chemin, contenu):
    with open(chemin, "w", encoding="utf-8", newline="") as fh:
        fh.write(contenu)
    return hashlib.md5(contenu.encode("utf-8")).hexdigest()


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    rep = sys.argv[1]
    conf = json.load(open(CONF, encoding="utf-8"))
    tbl_dom, tbl_strat, tbl_cat = charger_classification()
    exp, fichiers = charger_exports(rep)

    print("Exports lus :")
    for nom, cle, taille in fichiers:
        print("  %-52s %-18s %9d octets" % (nom, cle, taille))
    manquants = [k for k in ("colonnes", "fonctions", "contraintes", "index", "vues",
                             "triggers", "rls", "policies") if k not in exp]
    if manquants:
        raise SystemExit("export incomplet : " + ", ".join(manquants))
    exp["droits"] = (exp.get("droits_relations") or []) + (exp.get("droits_fonctions") or [])
    exp.setdefault("droits_colonnes", [])

    exclues = {t for t, s in tbl_strat.items() if s == "hors_baseline"}
    vues_noms = {v["vue"] for v in exp["vues"]}

    # ------------------------------------------------- repartition par domaine
    dom = {}
    ecartes = {"tables": sorted(exclues), "colonnes": 0, "contraintes": 0, "index": 0,
               "policies": 0, "triggers": 0, "droits": 0, "commentaires": 0, "rls": 0}
    inconnues = []

    def boite(d):
        if d not in dom:
            dom[d] = {k: list(v) for k, v in VIDE.items()}
        return dom[d]

    def dom_de_table(t):
        if t in vues_noms:
            return DOMAINE_DES_VUES.get(t)
        return tbl_dom.get(t)

    for c in exp["colonnes"]:
        if c["tbl"] in exclues:
            ecartes["colonnes"] += 1; continue
        if c.get("kind") == "v":
            continue                      # les vues sont rendues par pg_get_viewdef
        d = dom_de_table(c["tbl"])
        if not d:
            inconnues.append("table " + c["tbl"]); continue
        boite(d)["colonnes"].append(c)

    # Une sequence suit le domaine de la table qui la POSSEDE. Une sequence
    # autonome n'appartient a aucun domaine metier : elle va au socle.
    seq_dom, seq_exclues = {}, set()
    for s in (exp.get("sequences") or []):
        if s.get("tbl") in exclues:
            seq_exclues.add(s["sequence"]); continue
        d = dom_de_table(s.get("tbl")) if s.get("tbl") else None
        seq_dom[s["sequence"]] = d or "socle"
        boite(d or "socle")["sequences"].append(s)

    for cle in ("contraintes", "index", "triggers", "rls", "policies"):
        for o in exp[cle]:
            if o["tbl"] in exclues:
                ecartes[cle if cle in ecartes else "contraintes"] += 1; continue
            d = dom_de_table(o["tbl"])
            if not d:
                inconnues.append("%s de %s" % (cle, o["tbl"])); continue
            boite(d)[cle].append(o)

    for v in exp["vues"]:
        d = DOMAINE_DES_VUES.get(v["vue"])
        if not d:
            inconnues.append("vue " + v["vue"]); continue
        boite(d)["vues"].append(v)

    for f in exp["fonctions"]:
        d = domaine_fonction(f["proname"], conf)
        if not d:
            inconnues.append("fonction " + f["signature"]); continue
        boite(d)["fonctions"].append(f)

    sig_dom = {f["signature"]: domaine_fonction(f["proname"], conf) for f in exp["fonctions"]}
    for d in exp["droits"]:
        if d["genre"] == "TABLE":
            if d["objet"] in exclues:
                ecartes["droits"] += 1; continue
            dd = dom_de_table(d["objet"])
        elif d["genre"] == "SEQUENCE":
            # Sans les droits de sequence, une base reconstruite refuse tout
            # nextval() aux roles clients : aucun INSERT sur une cle serielle.
            if d["objet"] in seq_exclues:
                ecartes["droits"] += 1; continue
            dd = seq_dom.get(d["objet"], "socle")
        else:
            dd = sig_dom.get(d["objet"])
        if not dd:
            inconnues.append("droit sur " + d["objet"]); continue
        boite(dd)["droits"].append(d)
    for d in exp["droits_colonnes"]:
        if d["tbl"] in exclues:
            continue
        boite(dom_de_table(d["tbl"]) or "socle")["droits_colonnes"].append(d)
    # LES PRIVILEGES PAR DEFAUT NE SONT ATTACHES A AUCUN OBJET, donc a aucun domaine
    # metier : ce sont des reglages de schema. Ils vont au socle, en entier, et la phase
    # 90 tranche elle-meme ce qu'elle rejoue et ce qu'elle se contente d'inventorier.
    for d in exp.get("droits_par_defaut") or []:
        boite("socle")["droits_par_defaut"].append(d)

    for c in exp["commentaires"]:
        if c["genre"] == "FUNCTION":
            dd = sig_dom.get(c["objet"])
        else:
            if c["objet"] in exclues:
                ecartes["commentaires"] += 1; continue
            dd = dom_de_table(c["objet"])
        if not dd:
            inconnues.append("commentaire sur " + c["objet"]); continue
        boite(dd)["commentaires"].append(c)

    if inconnues:
        print("\nOBJETS SANS DOMAINE (%d) -- le rendu s'arrete :" % len(inconnues))
        for i in sorted(set(inconnues))[:40]:
            print("   ", i)
        raise SystemExit("affectation incomplete")

    # ------------------------------------------------------------- production
    os.makedirs(CIBLE, exist_ok=True)
    inventaire = {"domaines": {}, "ecartes_hors_baseline": ecartes, "fichiers": {}}
    print()
    for d in sorted(dom):
        rep_d = os.path.join(CIBLE, d.replace(" ", "-"))
        os.makedirs(rep_d, exist_ok=True)
        man = {"domaine": d, "tables": [], "fonctions": [], "contraintes": [],
               "index_autonomes": [], "index_portes": [], "vues": [], "triggers": [],
               "rls": [], "policies": [], "droits": [], "droits_colonnes": [],
               "commentaires": [], "sequences": [], "droits_par_defaut": [],
               "sequences_autonomes": [],
               "fichiers": {}, "ordre": []}
        total = 0
        for num, cat, lib, fonc, sep in PHASES:
            blocs = fonc(dom[d], man, exp)
            if not any(b.strip() for b in blocs):
                continue
            tete = ENTETE.format(titre=lib, domaine=d, phase=num, categorie=cat)
            # La decoupe se fait sur les BLOCS, jamais sur le texte : un fichier
            # ne peut donc pas etre coupe au milieu d'une fonction. Piege
            # rencontre au chantier 2E : deux fonctions avaient ete coupees en
            # deux, et c'est le controle global qui l'a vu (639 definitions
            # relues sur 641).
            paquets, cour, taille = [], [], 0
            for b in blocs:
                if taille and taille + len(b) > TAILLE_MAX_FICHIER:
                    paquets.append(cour); cour, taille = [], 0
                cour.append(b); taille += len(b) + len(sep)
            if cour:
                paquets.append(cour)
            for i, paquet in enumerate(paquets, 1):
                corps = sep.join(paquet).lstrip("\n")
                if not corps.endswith("\n"):
                    corps += "\n"
                nom = ("%02d_%s.sql" % (num, cat) if len(paquets) == 1
                       else "%02d_%s-%d.sql" % (num, cat, i))
                man["fichiers"][nom] = ecrire(os.path.join(rep_d, nom), tete + corps)
                # L'ORDRE est declare, pas deduit du nom. Un outil qui
                # reconcatenerait les morceaux en triant les noms se tromperait
                # des le dixieme morceau : « -10 » se trie avant « -2 ».
                man["ordre"].append(nom)
                total += len(corps)
        # LE GENERATEUR POSSEDE SON REPERTOIRE : tout .sql qu'il n'a pas ecrit cette fois-ci
        # est un vestige du rendu precedent, et il part.
        #
        # POURQUOI, ET CE QUE CA A COUTE DE NE PAS LE FAIRE. Le 9 octobre 2026, une fonction de
        # plus a fait franchir a `finances publiques` le seuil de TAILLE_MAX_FICHIER : le rendu
        # a donc produit `20_fonctions-1.sql` et `20_fonctions-2.sql` la ou il y avait
        # `20_fonctions.sql`. L'ancien fichier est reste sur le disque -- non declare au
        # manifeste, mais present, et portant une copie PERIMEE de toutes les fonctions du
        # domaine. Le controle d'integrite l'a vu (« fichier present mais non declare »), et il
        # avait raison : un repertoire annonce « GENERE, ne pas editer a la main » qui conserve
        # une version d'hier n'est plus une source de verite, c'est un piege. Le seuil se
        # franchit dans les deux sens -- une fonction supprimee referait l'inverse.
        for vestige in sorted(glob.glob(os.path.join(rep_d, "*.sql"))):
            if os.path.basename(vestige) not in man["fichiers"]:
                os.remove(vestige)
                print("  %-26s vestige du rendu precedent retire : %s"
                      % (d, os.path.basename(vestige)))
        with open(os.path.join(rep_d, "MANIFESTE.json"), "w", encoding="utf-8") as fh:
            json.dump(man, fh, indent=1, ensure_ascii=False, sort_keys=True)
        inventaire["domaines"][d] = {k: len(man[k]) for k in
            ("tables", "fonctions", "contraintes", "index_autonomes", "vues",
             "triggers", "policies", "droits", "commentaires", "droits_par_defaut")}
        inventaire["fichiers"].update({d + "/" + k: v for k, v in man["fichiers"].items()})
        print("  %-26s %2d fichiers %8d octets | %3d tables %3d fn %3d policies"
              % (d, len(man["fichiers"]), total, len(man["tables"]),
                 len(man["fonctions"]), len(man["policies"])))

    with open(os.path.join(RACINE, "baseline", "INVENTAIRE.json"), "w", encoding="utf-8") as fh:
        json.dump(inventaire, fh, indent=1, ensure_ascii=False, sort_keys=True)

    tot = {k: sum(v[k] for v in inventaire["domaines"].values()) for k in
           ("tables", "fonctions", "contraintes", "index_autonomes", "vues",
            "triggers", "policies", "droits", "commentaires", "droits_par_defaut")}
    print("\nTOTAL rendu : " + " | ".join("%s=%d" % (k, v) for k, v in sorted(tot.items())))
    print("Ecarte (hors_baseline) : %d tables, %d colonnes, %d policies, %d droits"
          % (len(ecartes["tables"]), ecartes["colonnes"], ecartes["policies"], ecartes["droits"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
