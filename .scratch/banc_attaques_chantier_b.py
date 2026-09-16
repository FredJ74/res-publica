#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
HARNAIS DE TESTS D'ATTAQUE — CHANTIER B (authentification / autorite serveur).

DOCTRINE
--------
Ce banc ne verifie pas que "le jeu marche encore" : il verifie que des actions
ILLEGITIMES sont REFUSEES. Il tape sur la vraie base de production, avec la vraie
cle anon publique -- exactement ce dont dispose n'importe quel visiteur.

SECURITE DES DONNEES
--------------------
- Toutes les lignes creees portent le prefixe 'zztest-' ; aucune donnee de joueur
  reel n'est jamais modifiee. Les attaques destructrices ne visent QUE ces lignes.
- Le banc nettoie derriere lui, et verifie son propre nettoyage en sortie.
- Les seules lectures portant sur des joueurs reels sont des SELECT, jamais suivis
  d'ecriture.

LECTURE DU RESULTAT
-------------------
Chaque test dit ce qu'il ATTEND une fois le chantier B termine. Avant fermeture,
les tests d'attaque sont normalement en ECHEC : c'est la mesure de la surface
d'attaque actuelle, et c'est le point de depart. Ils doivent tous virer au vert
a la fin du chantier.
"""
import json, sys, urllib.request, urllib.error

URL = "https://jxpwoosmmhohoihxpbuc.supabase.co"
ANON = ("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3"
        "NtbWhvaG9paHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMj"
        "IwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw")

VICTIME = "zztest-victime-chantier-b"
ATTAQUANT = "zztest-attaquant-chantier-b"

resultats = []


def http(methode, chemin, corps=None, jeton=None, prefer=None):
    """Requete PostgREST brute. Rend (code, corps decode)."""
    req = urllib.request.Request(URL + chemin, method=methode)
    cle = jeton or ANON
    req.add_header("apikey", ANON)
    req.add_header("Authorization", "Bearer " + cle)
    req.add_header("Content-Type", "application/json")
    if prefer:
        req.add_header("Prefer", prefer)
    data = json.dumps(corps).encode() if corps is not None else None
    try:
        with urllib.request.urlopen(req, data, timeout=30) as r:
            brut = r.read().decode()
            return r.status, (json.loads(brut) if brut.strip() else None)
    except urllib.error.HTTPError as e:
        brut = e.read().decode()
        try:
            return e.code, json.loads(brut)
        except Exception:
            return e.code, brut
    except Exception as e:
        return 0, str(e)


def verifier(num, nom, obtenu, attendu_apres_chantier, detail=""):
    resultats.append({
        "num": num, "nom": nom, "ok": bool(obtenu),
        "attendu": attendu_apres_chantier, "detail": str(detail)[:200]
    })


def refus(code):
    """Un refus PostgREST : 401/403 (RLS), ou 0 ligne touchee sur un PATCH."""
    return code in (401, 403)


# =========================================================================
JETON_VICTIME = None
JETON_ATTAQUANT = None


def ouvrir_session():
    """Ouvre une vraie session anonyme Supabase, exactement comme le fait auth.js."""
    req = urllib.request.Request(URL + "/auth/v1/signup", method="POST")
    req.add_header("apikey", ANON)
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, b"{}", timeout=30) as r:
            d = json.loads(r.read().decode())
            return d.get("access_token")
    except Exception as e:
        print("  session anonyme impossible :", e)
        return None


def preparer():
    """DEUX VRAIS JOUEURS AUTHENTIFIES, chacun avec sa propre session.
    C'est la seule facon de mesurer honnetement ce que peut faire un joueur
    CONTRE UN AUTRE : un attaquant sans identite ne prouverait pas grand-chose."""
    global JETON_VICTIME, JETON_ATTAQUANT
    JETON_VICTIME = ouvrir_session()
    JETON_ATTAQUANT = ouvrir_session()
    if not JETON_VICTIME or not JETON_ATTAQUANT:
        print("PREPARATION IMPOSSIBLE : la connexion anonyme ne repond pas.")
        return False
    for nom, arg, jeton in ((VICTIME, 5000, JETON_VICTIME), (ATTAQUANT, 100, JETON_ATTAQUANT)):
        http("DELETE", "/rest/v1/personnages?name=eq." + nom, jeton=jeton)
        code, rep = http("POST", "/rest/v1/personnages", {
            "name": nom, "country": "republic", "arg": arg, "liquide": arg,
            "pa": 10, "hp": 100, "moral": 75, "day": 1,
            "stats": {"FOR": 8, "PER": 8}, "resources": {"pop": 50, "inf": 50, "dis": 50},
            "inventory": [], "current_city": "capitale"
        }, jeton=jeton, prefer="return=representation")
        if code not in (200, 201):
            print("PREPARATION IMPOSSIBLE (%s) : %s %s" % (nom, code, str(rep)[:120]))
            return False
    return True


CREATIONS = [
    ("personnages", "name=eq." + VICTIME),
    ("personnages", "name=eq." + ATTAQUANT),
    ("detentions", "id=eq.zztest-detention-fabriquee"),
    ("batiments_etat", "id=eq.zztest_global_caisse-institutionnelle"),
    ("cycles_electoraux", "id=eq.zztest_president"),
]


def nettoyer():
    """Supprime tout ce que le banc a cree, puis VERIFIE que plus rien ne reste.
    Le banc ne modifie aucune ligne de production : chaque attaque porte sur une
    ligne zztest qu'il a lui-meme creee."""
    reste = []
    for table, filtre in CREATIONS:
        http("DELETE", "/rest/v1/%s?%s" % (table, filtre), jeton=JETON_VICTIME)
        http("DELETE", "/rest/v1/%s?%s" % (table, filtre), jeton=JETON_ATTAQUANT)
    for table, filtre in CREATIONS:
        c, r = http("GET", "/rest/v1/%s?select=*&%s" % (table, filtre))
        if r:
            reste.append(table + " " + filtre)
    return reste


# =========================================================================
def lancer():
    # --- 1. anon modifie personnages.arg ---------------------------------
    code, _ = http("PATCH", "/rest/v1/personnages?name=eq." + VICTIME, {"arg": 999999999})
    c2, apres = http("GET", "/rest/v1/personnages?select=arg&name=eq." + VICTIME)
    vole = apres and apres[0]["arg"] == 999999999
    verifier(1, "anon ne peut pas modifier personnages.arg", not vole,
             "REFUS", "HTTP %s, arg=%s" % (code, apres[0]["arg"] if apres else "?"))
    http("PATCH", "/rest/v1/personnages?name=eq." + VICTIME, {"arg": 5000}, jeton=JETON_VICTIME)

    # --- 2. le joueur A modifie le personnage B --------------------------
    code, _ = http("PATCH", "/rest/v1/personnages?name=eq." + VICTIME,
                   {"poste": {"id": "president", "name": "President usurpe"}}, jeton=JETON_ATTAQUANT)
    c2, apres = http("GET", "/rest/v1/personnages?select=poste&name=eq." + VICTIME)
    usurpe = apres and apres[0]["poste"] is not None
    verifier(2, "un joueur ne peut pas modifier le personnage d'un autre", not usurpe,
             "REFUS", "HTTP %s, poste=%s" % (code, apres[0]["poste"] if apres else "?"))
    http("PATCH", "/rest/v1/personnages?name=eq." + VICTIME, {"poste": None}, jeton=JETON_VICTIME)

    # --- 3. ecriture legitime sur ses propres donnees ---------------------
    code, _ = http("PATCH", "/rest/v1/personnages?name=eq." + ATTAQUANT, {"moral": 80}, jeton=JETON_ATTAQUANT)
    c2, apres = http("GET", "/rest/v1/personnages?select=moral&name=eq." + ATTAQUANT)
    verifier(3, "un joueur modifie legitimement SES donnees", bool(apres and apres[0]["moral"] == 80),
             "SUCCES", "HTTP %s" % code)

    # --- 4. toucher a l'inventaire d'AUTRUI --------------------------------
    # PERIMETRE. La premiere version visait l'inventaire de l'attaquant lui-meme : elle mesurait
    # donc l'AUTO-TRICHE, que le chantier B ne traite pas et ne pretend pas traiter (un joueur
    # proprietaire de sa ligne peut encore falsifier son arg, son inventaire et son solde depuis
    # son client -- probleme structurel distinct, suivi a part). Ce que le chantier doit
    # interdire, c'est de toucher a l'inventaire d'UN AUTRE joueur : vider le sien, ou s'offrir
    # un objet en l'ecrivant chez lui. C'est ce que ce test mesure desormais.
    code, _ = http("PATCH", "/rest/v1/personnages?name=eq." + VICTIME,
                   {"inventory": [{"id": "zz-lingot", "name": "Lingot d'or", "qte": 99}]}, jeton=JETON_ATTAQUANT)
    c2, apres = http("GET", "/rest/v1/personnages?select=inventory&name=eq." + VICTIME)
    force = apres and len(apres[0].get("inventory") or []) > 0
    verifier(4, "un joueur ne peut pas ecrire dans l'inventaire d'un autre", not force,
             "REFUS", "HTTP %s, inventaire cible=%s" % (code, len(apres[0].get("inventory") or []) if apres else "?"))

    # --- 5. modifier un stock institutionnel ------------------------------
    # JAMAIS SUR UNE LIGNE REELLE. Une premiere version de ce test visait le
    # premier batiment venu et pretendait le restaurer -- sans avoir lu la valeur
    # d'origine, qu'elle ecrasait donc par une date inventee. On cree desormais
    # notre propre ligne institutionnelle zztest : l'attaque est aussi probante,
    # et aucune donnee de production n'est touchee.
    cible = "zztest_global_caisse-institutionnelle"
    http("DELETE", "/rest/v1/batiments_etat?id=eq." + cible, jeton=JETON_ATTAQUANT)
    c0, _ = http("POST", "/rest/v1/batiments_etat", {
        "id": cible, "country": "zztest", "city": "global", "building_id": "caisse-zz",
        "data": json.dumps({"entrepot": {"caisse": 1000, "stock": {"metal": 50}}})})
    code, _ = http("PATCH", "/rest/v1/batiments_etat?id=eq." + cible,
                   {"data": json.dumps({"entrepot": {"caisse": 999999, "stock": {"metal": 99999}}})})
    c2, apres = http("GET", "/rest/v1/batiments_etat?select=data&id=eq." + cible)
    pille = apres and '999999' in str(apres[0]["data"])
    verifier(5, "un joueur ne peut pas modifier un stock institutionnel", not pille,
             "REFUS", "HTTP %s" % code)

    # --- 6. fabriquer ou modifier une detention ---------------------------
    # NE LAISSE AUCUN RESIDU, par construction : les deux ecritures testees sont
    # REFUSEES, donc rien n'est cree. C'est aussi plus fidele a la menace reelle --
    # faire incarcerer quelqu'un est un pouvoir plus grave que le liberer.
    # (Le registre judiciaire n'a volontairement aucune policy DELETE : une
    # detention ne s'efface pas, meme par son detenu.)
    code, rep = http("POST", "/rest/v1/detentions", {
        "id": "zztest-detention-fabriquee", "country": "republic", "city": "capitale",
        "nom": VICTIME, "raison": "incarceration fabriquee", "jour_debut": 1,
        "jour_fin": 30, "qhs": False}, jeton=JETON_ATTAQUANT)
    c2, cree = http("GET", "/rest/v1/detentions?select=id&id=eq.zztest-detention-fabriquee")
    fabriquee = bool(cree)
    verifier(6, "un joueur ne peut pas fabriquer la detention d'un autre", not fabriquee,
             "REFUS", "HTTP %s" % code)

    # --- 7. modifier une election -----------------------------------------
    # Meme precaution qu'au test 5 : cycle de test, jamais un scrutin reel.
    cyc_id = "zztest_president"
    http("DELETE", "/rest/v1/cycles_electoraux?id=eq." + cyc_id)
    http("POST", "/rest/v1/cycles_electoraux", {
        "id": cyc_id, "country": "zztest", "poste_id": "president", "city": None,
        "data": json.dumps({"phase": "vote", "candidats": [{"nom": VICTIME, "voix": 3}]})})
    code, _ = http("PATCH", "/rest/v1/cycles_electoraux?id=eq." + cyc_id,
                   {"data": json.dumps({"phase": "vote", "candidats": [{"nom": ATTAQUANT, "voix": 9999}]})})
    c2, apres = http("GET", "/rest/v1/cycles_electoraux?select=data&id=eq." + cyc_id)
    bourre = apres and '9999' in str(apres[0]["data"])
    verifier(7, "un joueur ne peut pas modifier une election hors du chemin prevu", not bourre,
             "REFUS", "HTTP %s" % code)

    # --- 8. usurper une identite : aucun pouvoir supplementaire ------------
    code, rep = http("POST", "/rest/v1/rpc/est_mon_personnage", {"p_nom": VICTIME})
    verifier(8, "se declarer un autre nom ne donne aucun pouvoir", rep is False,
             "REFUS", "est_mon_personnage -> %s" % rep)

    # 8 bis : l'identite est-elle encore un simple parametre de RPC ?
    code, rep = http("POST", "/rest/v1/rpc/assemblee_peut_deposer",
                     {"p_nom": VICTIME, "p_country": "republic"})
    verifier("8b", "une RPC ne repond plus sur un nom qu'on ne possede pas",
             code in (401, 403) or rep is None,
             "REFUS", "HTTP %s -> %s" % (code, str(rep)[:60]))

    # 8 ter : creer un homonyme n'ecrase plus un personnage existant
    c0, avant = http("GET", "/rest/v1/personnages?select=arg&name=eq." + VICTIME)
    code, _ = http("PATCH", "/rest/v1/personnages?name=eq." + VICTIME,
                   {"arg": 1, "bio": "ecrase par un homonyme"}, jeton=JETON_ATTAQUANT)
    c2, apres = http("GET", "/rest/v1/personnages?select=arg&name=eq." + VICTIME)
    ecrase = apres and avant and apres[0]["arg"] != avant[0]["arg"]
    verifier("8c", "creer un homonyme n'ecrase pas le personnage existant", not ecrase,
             "REFUS", "arg %s -> %s" % (avant[0]["arg"] if avant else "?", apres[0]["arg"] if apres else "?"))
    http("PATCH", "/rest/v1/personnages?name=eq." + VICTIME, {"arg": 5000, "bio": None}, jeton=JETON_VICTIME)

    # --- 9. service_role conserve tous ses droits --------------------------
    #     (verifie hors banc : le cron tourne sous service_role et ses 78
    #      assertions restent vertes. Ici on controle seulement que la voie
    #      serveur est distinguee de la voie joueur.)
    code, rep = http("POST", "/rest/v1/rpc/est_appel_serveur", {})
    verifier(9, "un client n'est jamais pris pour le serveur", rep is False,
             "REFUS", "est_appel_serveur -> %s" % rep)

    # --- 10. RPC serveur legitime ------------------------------------------
    code, rep = http("POST", "/rest/v1/rpc/assemblee_reveil_minuit", {"p_country": "republic"})
    verifier(10, "une RPC systeme reste fermee au client", code in (401, 403, 404),
             "REFUS", "HTTP %s" % code)

    # --- 11. lecture publique necessaire au gameplay -----------------------
    code, rep = http("GET", "/rest/v1/personnages?select=name,country,current_city,poste&limit=3")
    verifier(11, "les donnees publiques restent lisibles", code == 200 and isinstance(rep, list),
             "SUCCES", "HTTP %s, %s lignes" % (code, len(rep) if isinstance(rep, list) else 0))

    code, rep = http("GET", "/rest/v1/journal_editions?select=id&limit=1")
    verifier("11b", "le Journal reste lisible", code == 200, "SUCCES", "HTTP %s" % code)

    # --- 12. donnees privees d'un autre PJ ---------------------------------
    # On mesure les VALEURS, pas la presence des cles : PostgREST renvoie toujours les colonnes
    # demandees. Le masquage consiste a les rendre nulles pour qui n'est pas le proprietaire.
    code, rep = http("GET", "/rest/v1/personnages?select=name,inventory,arg,liquide,banque&name=eq." + VICTIME,
                     jeton=JETON_ATTAQUANT)
    prives = ["arg", "liquide", "banque", "inventory"]
    fuite = [c for c in prives if rep and rep[0].get(c) is not None]
    lisible = bool(rep and rep[0].get("name"))   # la ligne reste visible : le repertoire en depend
    verifier(12, "les donnees privees d'un autre PJ ne sont pas lisibles", (not fuite) and lisible,
             "REFUS", "fuites=%s, ligne visible=%s" % (fuite or "aucune", lisible))

    # Et le proprietaire, lui, doit toujours voir les siennes.
    code, rep = http("GET", "/rest/v1/personnages?select=arg,liquide,banque,inventory&name=eq." + VICTIME,
                     jeton=JETON_VICTIME)
    vu = bool(rep and rep[0].get("arg") is not None)
    verifier("12c", "le proprietaire voit toujours SES donnees privees", vu,
             "SUCCES", "arg=%s" % (rep[0].get("arg") if rep else "?"))

    code, rep = http("GET", "/rest/v1/comptes_bancaires?select=*&limit=1")
    verifier("12b", "les comptes bancaires d'autrui ne sont pas lisibles",
             code in (401, 403) or rep == [],
             "REFUS", "HTTP %s, %s lignes" % (code, len(rep) if isinstance(rep, list) else "?"))

    # --- 13. AUTORITE DES POSTES (chantier du 15 septembre 2026) -----------
    # personnages.poste servait de PREUVE d'autorite a dix-sept prerogatives serveur, alors que
    # le joueur l'ecrivait lui-meme sur sa propre ligne. Un trigger n'accepte plus qu'un poste
    # ATTESTE (cycles_electoraux pour les elus, compagnies_militaires pour les militaires,
    # postes_attribues pour les postes nommes). Le banc dedie banc_postes_autorite.py couvre les
    # chemins legitimes ; on verifie ici les trois usurpations les plus lourdes.
    for poste in ("president", "juge", "commissaire"):
        http("PATCH", "/rest/v1/personnages?name=eq." + ATTAQUANT,
             {"poste": {"id": poste, "name": poste, "city": "capitale"}}, jeton=JETON_ATTAQUANT)
        code, rep = http("GET", "/rest/v1/personnages?select=poste&name=eq." + ATTAQUANT,
                         jeton=JETON_ATTAQUANT)
        obtenu = rep[0].get("poste") if rep else "?"
        verifier("13" + poste[0], "s'auto-declarer %s ne prend pas" % poste, obtenu is None,
                 "REFUS", "poste=%s" % obtenu)

    # Et la prerogative correspondante reste fermee apres la tentative.
    code, rep = http("POST", "/rest/v1/rpc/presidence_gracier",
                     {"p_condamne": VICTIME, "p_jour": 1}, jeton=JETON_ATTAQUANT)
    ok_grace = code in (400, 401, 403) or not (isinstance(rep, dict) and rep.get("ok") is True)
    verifier("13d", "un faux President ne peut pas gracier", ok_grace,
             "REFUS", "HTTP %s %s" % (code, str(rep)[:60]))

    code, rep = http("POST", "/rest/v1/rpc/arrestation_urgence",
                     {"p_cible": VICTIME, "p_motif": "usurpation"}, jeton=JETON_ATTAQUANT)
    r0 = rep[0] if isinstance(rep, list) and rep else rep
    verifier("13e", "un faux commissaire ne peut pas ordonner d'arrestation",
             not (isinstance(r0, dict) and r0.get("ok") is True),
             "REFUS", "HTTP %s %s" % (code, str(r0)[:60]))

    # --- 14. LES PA NE S'ECRIVENT PLUS DEPUIS LE NAVIGATEUR ---------------
    # Meme nature de faille que le poste : une colonne de pouvoir que le client publiait.
    http("PATCH", "/rest/v1/personnages?name=eq." + ATTAQUANT, {"pa": 10}, jeton=JETON_ATTAQUANT)
    code, _ = http("PATCH", "/rest/v1/personnages?name=eq." + ATTAQUANT, {"pa": 999},
                   jeton=JETON_ATTAQUANT)
    c2, rep = http("GET", "/rest/v1/personnages?select=pa&name=eq." + ATTAQUANT, jeton=JETON_ATTAQUANT)
    obtenu = rep[0]["pa"] if rep else "?"
    verifier("14a", "un joueur ne peut pas s'attribuer des PA", obtenu == 10,
             "REFUS", "HTTP %s, pa=%s" % (code, obtenu))

    # Meme un seul PA de plus : le critere de fermeture est litteral.
    http("PATCH", "/rest/v1/personnages?name=eq." + ATTAQUANT, {"pa": 11}, jeton=JETON_ATTAQUANT)
    c2, rep = http("GET", "/rest/v1/personnages?select=pa&name=eq." + ATTAQUANT, jeton=JETON_ATTAQUANT)
    obtenu = rep[0]["pa"] if rep else "?"
    verifier("14b", "pas meme un seul PA supplementaire", obtenu == 10, "REFUS", "pa=%s" % obtenu)

    # Et il ne peut pas davantage recharger un autre joueur (ni se faire recharger par complice).
    code, _ = http("PATCH", "/rest/v1/personnages?name=eq." + VICTIME, {"pa": 30}, jeton=JETON_ATTAQUANT)
    c2, rep = http("GET", "/rest/v1/personnages?select=pa&name=eq." + VICTIME)
    obtenu = rep[0]["pa"] if rep else "?"
    verifier("14c", "un joueur ne peut pas recharger les PA d'un autre", obtenu == 10,
             "REFUS", "HTTP %s, pa=%s" % (code, obtenu))

    # Les RPC de gain refusent de crediter un personnage qu'on ne possede pas.
    code, rep = http("POST", "/rest/v1/rpc/pa_repos_nocturne", {"p_acteur": VICTIME},
                     jeton=JETON_ATTAQUANT)
    r0 = rep[0] if isinstance(rep, list) and rep else rep
    c2, apres = http("GET", "/rest/v1/personnages?select=pa&name=eq." + VICTIME)
    verifier("14d", "on ne repose pas le personnage d'un autre",
             not (isinstance(r0, dict) and r0.get("ok") is True) and apres and apres[0]["pa"] == 10,
             "REFUS", "HTTP %s %s" % (code, str(r0)[:60]))

    # Les colonnes d'autorite des PA ne sont meme pas exposees par la vue.
    for colonne in ("bonus_pa_differe", "pa_repos_le"):
        code, rep = http("GET", "/rest/v1/personnages?select=%s&name=eq.%s" % (colonne, ATTAQUANT),
                         jeton=JETON_ATTAQUANT)
        verifier("14e" if colonne[0] == "b" else "14f",
                 "%s n'est pas exposee au client" % colonne, code >= 400,
                 "REFUS", "HTTP %s" % code)

    # Les registres d'autorite ne sont pas ecrivables par un client.
    for table, ligne in (("postes_attribues", {"id": "zztest-usurp", "country": "republic",
                                               "poste_id": "president", "city": None,
                                               "titulaire": ATTAQUANT, "source": "attaque"}),
                         ("titulaires_pnj", {"id": "zztest-usurp-pnj", "country": "republic",
                                             "poste_id": "juge", "city": None,
                                             "nom_pnj": ATTAQUANT})):
        code, rep = http("POST", "/rest/v1/" + table, ligne, jeton=JETON_ATTAQUANT)
        code2, apres = http("GET", "/rest/v1/" + table + "?select=id&id=like.zztest-usurp*")
        verifier("13" + table[0], "un client ne peut pas ecrire dans %s" % table,
                 apres == [], "REFUS", "HTTP %s" % code)


# =========================================================================
def main():
    print("HARNAIS D'ATTAQUE — CHANTIER B")
    print("Cible : base de production, cle anon publique (celle de tout visiteur).\n")
    if not preparer():
        return 2
    try:
        lancer()
    finally:
        reste = nettoyer()

    bloques = sum(1 for r in resultats if r["ok"])
    for r in resultats:
        marque = "BLOQUE " if r["ok"] else "OUVERT "
        print("  [%s] %-3s %-62s %s" % (marque, r["num"], r["nom"], r["detail"]))
    print("\n%d/%d verrous en place." % (bloques, len(resultats)))
    if reste:
        print("!! RESIDU DE TEST NON NETTOYE : %s" % reste)
        return 1
    print("Nettoyage verifie : aucune donnee de test restante.")
    return 0 if bloques == len(resultats) else 3


if __name__ == "__main__":
    sys.exit(main())
