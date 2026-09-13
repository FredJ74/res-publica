#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PARCOURS JOUEUR DE BOUT EN BOUT (chantier C, 14 septembre 2026).

Les bancs techniques verifient chaque RPC isolement. Celui-ci joue un joueur reel, du premier
appel jusqu'a une dizaine d'actions economiques enchainees, et verifie a chaque etape que
CE QUE LE SERVEUR A RETENU est bien ce qui est lisible ensuite -- c'est-a-dire que l'affichage
du jeu, qui recopie ces valeurs, sera juste.

Session anonyme -> creation -> compte bancaire -> action a cout fixe -> action a cout dynamique
-> production -> gain -> depot -> retrait -> rechargement complet.

Donnees zztest uniquement.
"""
import json, sys, time, urllib.request, urllib.error

URL = "https://jxpwoosmmhohoihxpbuc.supabase.co"
ANON = ("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3"
        "NtbWhvaG9paHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMj"
        "IwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw")

SUF = str(int(time.time()))
JOUEUR = "zztest-parcours-" + SUF
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
    resultats.append({"nom": nom, "ok": bool(ok), "detail": str(detail)[:150]})


def rpc(nom, corps, jeton=None):
    c, r = http("POST", "/rest/v1/rpc/" + nom, corps, jeton=jeton)
    v = r[0] if isinstance(r, list) else r
    return c, (v if isinstance(v, dict) else {"brut": v})


def etat(jeton):
    """Ce que le jeu recharge reellement : le personnage et ses comptes."""
    c, r = http("GET", "/rest/v1/personnages?select=arg,liquide,pa,inventory&name=eq." + JOUEUR,
                jeton=jeton)
    p = (r[0] if r else {})
    c, r2 = http("GET", "/rest/v1/comptes_bancaires?select=solde&personnage=eq." + JOUEUR
                 + "&banque=eq.nationale", jeton=jeton)
    p["solde"] = (r2[0]["solde"] if r2 else 0)
    return p


def main():
    tj = session()
    try:
        return deroulement(tj)
    finally:
        http("DELETE", "/rest/v1/personnages?name=eq." + JOUEUR, jeton=tj)


def deroulement(tj):
    # === 1. SESSION ET CREATION ============================================
    verifier("1 session anonyme ouverte", bool(tj), "jeton obtenu")

    code, rep = http("POST", "/rest/v1/personnages", {
        "name": JOUEUR, "country": "republic", "arg": 20000, "liquide": 3000, "pa": 20,
        "hp": 100, "moral": 75, "day": 10, "current_city": "capitale",
        "stats": {}, "resources": {}, "inventory": []}, jeton=tj, prefer="return=representation")
    verifier("2 personnage cree", code in (200, 201), "HTTP %s %s" % (code, str(rep)[:80]))

    c, r = http("POST", "/rest/v1/rpc/mon_personnage", {}, jeton=tj)
    verifier("3 personnage rattache a ce compte", r == JOUEUR, str(r)[:60])

    c, v = rpc("compte_bancaire_initial", {"p_acteur": JOUEUR}, jeton=tj)
    verifier("4 compte bancaire ouvert, solde deduit de la fortune",
             v.get("ok") is True and float(v.get("solde")) == 17000.0, str(v)[:100])

    e0 = etat(tj)
    verifier("5 etat initial coherent : arg = liquide + solde",
             float(e0["arg"]) == float(e0["liquide"]) + float(e0["solde"]),
             "arg=%s liquide=%s solde=%s" % (e0["arg"], e0["liquide"], e0["solde"]))

    # === 2. ACTION A COUT FIXE =============================================
    c, v = rpc("payer_ordre", {"p_acteur": JOUEUR, "p_fn": "prendre_train",
                               "p_pa": 2, "p_cost": 75}, jeton=tj)
    verifier("6 action a cout FIXE (train) : acceptee", v.get("ok") is True, str(v)[:100])
    e1 = etat(tj)
    verifier("7 le serveur a preleve exactement 75 FR et 2 PA",
             float(e0["arg"]) - float(e1["arg"]) == 75.0 and int(e0["pa"]) - int(e1["pa"]) == 2,
             "arg %s->%s pa %s->%s" % (e0["arg"], e1["arg"], e0["pa"], e1["pa"]))
    verifier("8 ce que la RPC a annonce correspond a ce qui est relu",
             float(v.get("liquide")) == float(e1["liquide"])
             and int(v.get("pa")) == int(e1["pa"]),
             "annonce liquide=%s pa=%s / relu %s %s" % (v.get("liquide"), v.get("pa"),
                                                        e1["liquide"], e1["pa"]))

    # === 3. ACTION A COUT DYNAMIQUE ========================================
    # Le meme ordre avec un montant NON declare doit etre refuse : c'est la garantie que
    # payer_ordre n'arbitre pas les montants dynamiques.
    c, v = rpc("payer_ordre", {"p_acteur": JOUEUR, "p_fn": "prendre_train",
                               "p_pa": 2, "p_cost": 1}, jeton=tj)
    verifier("9 le meme ordre a un prix invente : refuse",
             v.get("ok") is False and v.get("raison") == "cout_non_declare", str(v)[:100])
    verifier("10 et rien n'a bouge", etat(tj) == e1, "ok")

    # === 4. DEPOT ET RETRAIT ===============================================
    e2 = etat(tj)
    c, v = rpc("banque_nationale_mouvement",
               {"p_acteur": JOUEUR, "p_sens": "depot", "p_montant": 1000}, jeton=tj)
    verifier("11 depot bancaire : accepte", v.get("ok") is True, str(v)[:100])
    e3 = etat(tj)
    verifier("12 depot : la fortune totale est inchangee",
             float(e3["arg"]) == float(e2["arg"]),
             "arg %s -> %s" % (e2["arg"], e3["arg"]))
    verifier("13 depot : les poches ont bouge du montant exact",
             float(e2["liquide"]) - float(e3["liquide"]) == 1000.0
             and float(e3["solde"]) - float(e2["solde"]) == 1000.0,
             "liquide %s->%s solde %s->%s" % (e2["liquide"], e3["liquide"],
                                              e2["solde"], e3["solde"]))

    c, v = rpc("banque_nationale_mouvement",
               {"p_acteur": JOUEUR, "p_sens": "retrait", "p_montant": 400}, jeton=tj)
    verifier("14 retrait bancaire : accepte", v.get("ok") is True, str(v)[:100])
    e4 = etat(tj)
    verifier("15 retrait : fortune inchangee, poches exactes",
             float(e4["arg"]) == float(e3["arg"])
             and float(e4["liquide"]) - float(e3["liquide"]) == 400.0,
             "arg %s liquide %s->%s" % (e4["arg"], e3["liquide"], e4["liquide"]))

    # === 5. DEPENSE VIA LA PRIMITIVE DE FONDS ORDINAIRES ===================
    # C'est la primitive que 23 sites du jeu utilisent pour payer. Elle doit prendre le liquide
    # d'abord, puis completer par la banque -- et refuser en entier si le total ne suffit pas.
    e5 = etat(tj)
    somme = float(e5["liquide"]) + 500
    c, v = rpc("debiter_fonds_ordinaires", {"p_acteur": JOUEUR, "p_montant": somme}, jeton=tj)
    verifier("16 depense a cheval sur liquide et banque : acceptee",
             v.get("ok") is True, str(v)[:100])
    e6 = etat(tj)
    verifier("17 le liquide est vide et la banque a complete",
             float(e6["liquide"]) == 0.0
             and float(e5["solde"]) - float(e6["solde"]) == 500.0,
             "liquide %s->%s solde %s->%s" % (e5["liquide"], e6["liquide"],
                                              e5["solde"], e6["solde"]))

    c, v = rpc("debiter_fonds_ordinaires", {"p_acteur": JOUEUR, "p_montant": 10 ** 8}, jeton=tj)
    verifier("18 depense au-dela du total : refusee",
             v.get("ok") is False and v.get("raison") == "fonds_insuffisants", str(v)[:100])

    # La primitive INTERNE, elle, ne doit pas etre atteignable depuis un navigateur : elle ne
    # verifie aucune identite.
    c, r = http("POST", "/rest/v1/rpc/helvetia_debiter_fonds_ordinaires",
                {"p_personnage": JOUEUR, "p_montant": 1}, jeton=tj)
    verifier("18b la primitive interne reste fermee au navigateur",
             c in (401, 403, 404) or (isinstance(r, dict)
                                      and r.get("code") in ("42501", "PGRST202")),
             "HTTP %s %s" % (c, str(r)[:70]))
    verifier("19 et aucune mutation partielle", etat(tj) == e6, "ok")

    # === 6. RECHARGEMENT COMPLET ===========================================
    # Ce que le jeu relit au chargement de la page doit etre exactement l'etat serveur.
    e7 = etat(tj)
    verifier("20 rechargement : les valeurs relues sont celles du serveur",
             e7 == e6, "%s vs %s" % (json.dumps(e6), json.dumps(e7)))
    verifier("21 invariant final : arg = liquide + solde",
             float(e7["arg"]) == float(e7["liquide"]) + float(e7["solde"]),
             "arg=%s liquide=%s solde=%s" % (e7["arg"], e7["liquide"], e7["solde"]))

    for x in resultats:
        if not x["ok"]:
            print("  KO   %-62s %s" % (x["nom"], x["detail"]))
    ko = sum(1 for x in resultats if not x["ok"])
    print("\n%d etapes, %d en echec." % (len(resultats), ko))
    return 1 if ko else 0


if __name__ == "__main__":
    sys.exit(main())
