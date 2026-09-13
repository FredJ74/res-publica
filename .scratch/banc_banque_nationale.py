#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BANC DE LA BANQUE NATIONALE (chantier C, 14 septembre 2026).

C'etait le dernier compte du jeu encore pilote par une ecriture cliente. Le navigateur
deplacait l'argent entre liquide et compte national dans son propre etat, puis persistait les
deux cotes SEPAREMENT : le personnage d'un cote, le compte de l'autre, en fire-and-forget.
Un echec du second appel creait ou detruisait de l'argent. Et sbMajCompteBancaire ecrivait un
SOLDE ABSOLU sans le moindre controle d'identite.

Ce banc verifie la fermeture de la table, le depot, le retrait, l'invariant de fortune, la
creation du compte initial et les attaques. Donnees zztest uniquement.
"""
import json, sys, time, urllib.request, urllib.error

URL = "https://jxpwoosmmhohoihxpbuc.supabase.co"
ANON = ("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3"
        "NtbWhvaG9paHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMj"
        "IwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw")

SUF = str(int(time.time()))
TITULAIRE, INTRUS = "zztest-banque-" + SUF, "zztest-banque-intrus-" + SUF
resultats = []


def http(methode, chemin, corps=None, jeton=None, prefer=None):
    req = urllib.request.Request(URL + chemin, method=methode)
    req.add_header("apikey", ANON)
    req.add_header("Authorization", "Bearer " + (jeton or ANON))
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


def session():
    req = urllib.request.Request(URL + "/auth/v1/signup", method="POST")
    req.add_header("apikey", ANON)
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, b"{}", timeout=30) as r:
        return json.loads(r.read().decode())["access_token"]


def verifier(nom, ok, detail=""):
    resultats.append({"nom": nom, "ok": bool(ok), "detail": str(detail)[:140]})


def rpc(nom, corps, jeton=None):
    c, r = http("POST", "/rest/v1/rpc/" + nom, corps, jeton=jeton)
    v = r[0] if isinstance(r, list) else r
    return c, (v if isinstance(v, dict) else {"brut": v})


def poches(nom, jeton):
    c, r = http("GET", "/rest/v1/personnages?select=arg,liquide&name=eq." + nom, jeton=jeton)
    p = (r[0] if r else {})
    # Un solde bancaire est PRIVE (verrou du chantier B) : il faut la session de son titulaire.
    c, r2 = http("GET", "/rest/v1/comptes_bancaires?select=id,solde&personnage=eq." + nom
                 + "&banque=eq.nationale", jeton=jeton)
    compte = (r2[0] if r2 else {})
    return {"arg": p.get("arg"), "liquide": p.get("liquide"),
            "solde": compte.get("solde"), "id": compte.get("id")}


def main():
    tt, ti = session(), session()
    try:
        return deroulement(tt, ti)
    finally:
        for nom, jeton in ((TITULAIRE, tt), (INTRUS, ti)):
            http("DELETE", "/rest/v1/personnages?name=eq." + nom, jeton=jeton)


def deroulement(tt, ti):
    for nom, jeton in ((TITULAIRE, tt), (INTRUS, ti)):
        code, rep = http("POST", "/rest/v1/personnages", {
            "name": nom, "country": "republic", "arg": 10000, "liquide": 1500, "pa": 20,
            "hp": 100, "moral": 75, "day": 10, "current_city": "capitale",
            "stats": {}, "resources": {}, "inventory": []}, jeton=jeton)
        if code not in (200, 201):
            print("PREPARATION IMPOSSIBLE (%s) : %s %s" % (nom, code, str(rep)[:140]))
            return 2

    # === A. CREATION DU COMPTE INITIAL =====================================
    c, v = rpc("compte_bancaire_initial", {"p_acteur": TITULAIRE}, jeton=tt)
    verifier("A1 compte initial cree", v.get("ok") is True, str(v)[:100])
    verifier("A2 son solde est la part NON liquide, deduite du personnage",
             float(v.get("solde")) == 8500.0, "solde=%s (arg 10000, liquide 1500)" % v.get("solde"))

    c, v = rpc("compte_bancaire_initial", {"p_acteur": TITULAIRE}, jeton=tt)
    verifier("A3 seconde creation : sans effet, pas de doublon",
             v.get("ok") is True and v.get("deja_cree") is True, str(v)[:100])

    c, v = rpc("compte_bancaire_initial", {"p_acteur": INTRUS}, jeton=tt)
    verifier("A4 creer le compte d'un autre : refuse",
             v.get("code") == "42501" or v.get("ok") is False, str(v)[:100])

    # === B. LA TABLE EST FERMEE EN ECRITURE ================================
    etat = poches(TITULAIRE, tt)
    c, r = http("PATCH", "/rest/v1/comptes_bancaires?id=eq." + etat["id"],
                {"solde": 10 ** 9}, jeton=tt, prefer="return=representation")
    verifier("B1 PATCH direct de SON PROPRE solde : refuse",
             c in (401, 403, 404) or (isinstance(r, dict) and r.get("code") == "42501"),
             "HTTP %s %s" % (c, str(r)[:70]))

    c, r = http("POST", "/rest/v1/comptes_bancaires",
                {"id": "zztest-compte-pirate-" + SUF, "personnage": TITULAIRE,
                 "pays": "republic", "banque": "helvetia", "solde": 10 ** 9}, jeton=tt)
    verifier("B2 INSERT direct d'un compte au solde choisi : refuse",
             c in (401, 403, 404) or (isinstance(r, dict) and r.get("code") == "42501"),
             "HTTP %s %s" % (c, str(r)[:70]))

    c, r = http("DELETE", "/rest/v1/comptes_bancaires?id=eq." + etat["id"], jeton=tt)
    verifier("B3 DELETE direct : refuse",
             c in (401, 403, 404) or (isinstance(r, dict) and r.get("code") == "42501"),
             "HTTP %s %s" % (c, str(r)[:70]))
    verifier("B4 le solde est intact apres les trois tentatives",
             float(poches(TITULAIRE, tt)["solde"]) == 8500.0, poches(TITULAIRE, tt)["solde"])

    # === C. DEPOT ET RETRAIT ===============================================
    avant = poches(TITULAIRE, tt)
    c, v = rpc("banque_nationale_mouvement",
               {"p_acteur": TITULAIRE, "p_sens": "depot", "p_montant": 1000}, jeton=tt)
    verifier("C1 depot de 1000 : accepte", v.get("ok") is True, str(v)[:100])
    apres = poches(TITULAIRE, tt)
    verifier("C2 le liquide baisse de 1000 et le solde monte de 1000",
             float(avant["liquide"]) - float(apres["liquide"]) == 1000.0
             and float(apres["solde"]) - float(avant["solde"]) == 1000.0,
             "liquide %s->%s solde %s->%s" % (avant["liquide"], apres["liquide"],
                                              avant["solde"], apres["solde"]))
    verifier("C3 la fortune totale ne bouge pas (ni creation ni destruction)",
             float(apres["arg"]) == float(avant["arg"]),
             "arg %s -> %s" % (avant["arg"], apres["arg"]))

    avant = poches(TITULAIRE, tt)
    c, v = rpc("banque_nationale_mouvement",
               {"p_acteur": TITULAIRE, "p_sens": "retrait", "p_montant": 2500}, jeton=tt)
    verifier("C4 retrait de 2500 : accepte", v.get("ok") is True, str(v)[:100])
    apres = poches(TITULAIRE, tt)
    verifier("C5 le solde baisse de 2500 et le liquide monte de 2500",
             float(avant["solde"]) - float(apres["solde"]) == 2500.0
             and float(apres["liquide"]) - float(avant["liquide"]) == 2500.0,
             "solde %s->%s liquide %s->%s" % (avant["solde"], apres["solde"],
                                              avant["liquide"], apres["liquide"]))
    verifier("C6 la fortune totale ne bouge toujours pas",
             float(apres["arg"]) == float(avant["arg"]), apres["arg"])

    # === D. BORNES ET ATTAQUES =============================================
    etat = poches(TITULAIRE, tt)
    c, v = rpc("banque_nationale_mouvement",
               {"p_acteur": TITULAIRE, "p_sens": "depot", "p_montant": 10 ** 8}, jeton=tt)
    verifier("D1 deposer plus que son liquide : refuse",
             v.get("ok") is False and v.get("raison") == "liquide_insuffisant", str(v)[:100])

    c, v = rpc("banque_nationale_mouvement",
               {"p_acteur": TITULAIRE, "p_sens": "retrait", "p_montant": 10 ** 8}, jeton=tt)
    verifier("D2 retirer plus que son solde : refuse",
             v.get("ok") is False and v.get("raison") == "solde_insuffisant", str(v)[:100])

    for montant, libelle in ((-100, "montant negatif"), (0, "montant nul"),
                             (12.5, "montant non entier")):
        c, v = rpc("banque_nationale_mouvement",
                   {"p_acteur": TITULAIRE, "p_sens": "depot", "p_montant": montant}, jeton=tt)
        verifier("D3 %s : refuse" % libelle,
                 v.get("ok") is False and v.get("raison") == "montant_invalide", str(v)[:90])

    c, v = rpc("banque_nationale_mouvement",
               {"p_acteur": TITULAIRE, "p_sens": "virement_magique", "p_montant": 10}, jeton=tt)
    verifier("D4 sens invente : refuse",
             v.get("ok") is False and v.get("raison") == "sens_invalide", str(v)[:90])

    c, v = rpc("banque_nationale_mouvement",
               {"p_acteur": TITULAIRE, "p_sens": "retrait", "p_montant": 100}, jeton=ti)
    verifier("D5 retirer sur le compte d'un autre : refuse",
             v.get("code") == "42501" or v.get("ok") is False, str(v)[:100])

    c, v = rpc("banque_nationale_mouvement",
               {"p_acteur": TITULAIRE, "p_sens": "depot", "p_montant": 100})
    verifier("D6 sans session : refuse",
             c in (401, 403, 404) or v.get("ok") is False
             or v.get("code") in ("42501", "42883", "PGRST202"), "HTTP %s %s" % (c, str(v)[:70]))

    apres = poches(TITULAIRE, tt)
    verifier("D7 aucune mutation apres toutes les tentatives",
             apres == etat, "%s vs %s" % (json.dumps(etat), json.dumps(apres)))

    # === E. CONFIDENTIALITE (verrou du chantier B) =========================
    c, r = http("GET", "/rest/v1/comptes_bancaires?select=solde&personnage=eq." + TITULAIRE,
                jeton=ti)
    verifier("E1 le solde d'autrui n'est pas lisible",
             isinstance(r, list) and len(r) == 0, str(r)[:80])
    c, r = http("GET", "/rest/v1/comptes_bancaires?select=solde&personnage=eq." + TITULAIRE)
    verifier("E2 ni sans session", isinstance(r, list) and len(r) == 0, str(r)[:80])
    c, r = http("GET", "/rest/v1/comptes_bancaires?select=solde&personnage=eq." + TITULAIRE,
                jeton=tt)
    verifier("E3 mais son titulaire le lit toujours",
             isinstance(r, list) and len(r) == 1, str(r)[:80])

    for x in resultats:
        if not x["ok"]:
            print("  KO   %-62s %s" % (x["nom"], x["detail"]))
    ko = sum(1 for x in resultats if not x["ok"])
    print("\n%d controles, %d en echec." % (len(resultats), ko))
    return 1 if ko else 0


if __name__ == "__main__":
    sys.exit(main())
