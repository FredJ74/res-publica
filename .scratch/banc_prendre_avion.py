#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BANC — « Prendre l'avion » au Centre multimodal de Luthecia (14 septembre 2026).

Le chemin client a ete valide hors ligne (sonde_prendre_avion.py). Ce banc eprouve le seul
maillon qui ne peut pas l'etre : le prelevement serveur, tel que executerVoyage l'appelle.

Il rejoue exactement ce que fait le jeu : payer_ordre avec le couple (pa, cost) de
TRANSPORT_CONFIG.avion, sous le nom d'ordre que doOrder a depose (prendre_avion).

Controles demandes : fonds et PA suffisants, fonds insuffisants, PA insuffisants, refus
correctement motive, absence de double debit. Comparaison avec le train, qui fonctionne.

Donnees zztest uniquement, supprimees a la fin.
"""
import json, sys, time, urllib.request, urllib.error

URL = "https://jxpwoosmmhohoihxpbuc.supabase.co"
ANON = ("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3"
        "NtbWhvaG9paHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMj"
        "IwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw")

SUF = str(int(time.time()))
JOUEUR = "zztest-avion-" + SUF
resultats = []

# Valeurs REELLES du jeu, pas des valeurs choisies ici :
#   data.js               prendre_avion  pa:2 cost:300
#   TRANSPORT_CONFIG.avion               pa:2 cost:300
AVION_PA, AVION_COST = 2, 300
TRAIN_PA, TRAIN_COST = 2, 75


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
    c, r = http("GET", "/rest/v1/personnages?select=arg,liquide,pa&name=eq." + JOUEUR, jeton=jeton)
    return r[0] if r else {}


def poser(jeton, pa, liquide):
    http("PATCH", "/rest/v1/personnages?name=eq." + JOUEUR,
         {"pa": pa, "liquide": liquide, "arg": liquide}, jeton=jeton)


def main():
    tj = session()
    try:
        return deroulement(tj)
    finally:
        http("DELETE", "/rest/v1/personnages?name=eq." + JOUEUR, jeton=tj)


def deroulement(tj):
    code, rep = http("POST", "/rest/v1/personnages", {
        "name": JOUEUR, "country": "republic", "arg": 5000, "liquide": 5000, "pa": 10,
        "hp": 100, "moral": 75, "day": 10, "current_city": "capitale",
        "current_building": "centre-multinodal-luthecia", "current_room": "zone_embarquement",
        "stats": {}, "resources": {}, "inventory": []}, jeton=tj)
    if code not in (200, 201):
        print("PREPARATION IMPOSSIBLE : %s %s" % (code, str(rep)[:200]))
        return 2

    # === A. LE COUPLE DU JEU EST-IL ACCEPTE ? ==============================
    e0 = etat(tj)
    c, v = rpc("payer_ordre", {"p_acteur": JOUEUR, "p_fn": "prendre_avion",
                               "p_pa": AVION_PA, "p_cost": AVION_COST}, jeton=tj)
    verifier("A1 le couple exact du jeu (2 PA, 300 FR) est accepte",
             v.get("ok") is True, str(v)[:120])
    e1 = etat(tj)
    verifier("A2 exactement 300 FR et 2 PA preleves",
             float(e0["arg"]) - float(e1["arg"]) == 300.0
             and int(e0["pa"]) - int(e1["pa"]) == 2,
             "arg %s->%s pa %s->%s" % (e0["arg"], e1["arg"], e0["pa"], e1["pa"]))
    verifier("A3 ce que la RPC annonce correspond a ce qui est relu",
             float(v.get("liquide")) == float(e1["liquide"]) and int(v.get("pa")) == int(e1["pa"]),
             "annonce %s/%s relu %s/%s" % (v.get("liquide"), v.get("pa"), e1["liquide"], e1["pa"]))

    # Temoin : le train, qui fonctionne en production.
    c, v = rpc("payer_ordre", {"p_acteur": JOUEUR, "p_fn": "prendre_train",
                               "p_pa": TRAIN_PA, "p_cost": TRAIN_COST}, jeton=tj)
    verifier("A4 temoin train : accepte lui aussi", v.get("ok") is True, str(v)[:120])

    # === B. FONDS INSUFFISANTS ============================================
    poser(tj, 10, 100)
    avant = etat(tj)
    c, v = rpc("payer_ordre", {"p_acteur": JOUEUR, "p_fn": "prendre_avion",
                               "p_pa": AVION_PA, "p_cost": AVION_COST}, jeton=tj)
    verifier("B1 fonds insuffisants : refuse avec un motif explicite",
             v.get("ok") is False and v.get("raison") in ("fonds_insuffisants", "solde_insuffisant"),
             str(v)[:120])
    apres = etat(tj)
    verifier("B2 rien n'a ete preleve",
             float(avant["arg"]) == float(apres["arg"]) and int(avant["pa"]) == int(apres["pa"]),
             "arg %s pa %s" % (apres["arg"], apres["pa"]))

    # === C. PA INSUFFISANTS ===============================================
    poser(tj, 1, 5000)
    avant = etat(tj)
    c, v = rpc("payer_ordre", {"p_acteur": JOUEUR, "p_fn": "prendre_avion",
                               "p_pa": AVION_PA, "p_cost": AVION_COST}, jeton=tj)
    verifier("C1 PA insuffisants : refuse avec un motif explicite",
             v.get("ok") is False and v.get("raison") == "pa_insuffisants", str(v)[:120])
    apres = etat(tj)
    verifier("C2 aucun franc preleve alors que les PA manquaient",
             float(avant["arg"]) == float(apres["arg"]), "arg %s" % apres["arg"])

    # === D. PAS DE DOUBLE DEBIT ===========================================
    # Double-clic sur « Embarquer » : deux appels identiques doivent preleve deux fois le prix
    # d'un billet, jamais un seul debit pour deux voyages ni un debit fantome.
    poser(tj, 10, 5000)
    avant = etat(tj)
    c1, v1 = rpc("payer_ordre", {"p_acteur": JOUEUR, "p_fn": "prendre_avion",
                                 "p_pa": AVION_PA, "p_cost": AVION_COST}, jeton=tj)
    c2, v2 = rpc("payer_ordre", {"p_acteur": JOUEUR, "p_fn": "prendre_avion",
                                 "p_pa": AVION_PA, "p_cost": AVION_COST}, jeton=tj)
    apres = etat(tj)
    acceptes = (1 if v1.get("ok") else 0) + (1 if v2.get("ok") else 0)
    verifier("D1 chaque appel accepte preleve exactement un billet",
             float(avant["arg"]) - float(apres["arg"]) == 300.0 * acceptes
             and int(avant["pa"]) - int(apres["pa"]) == 2 * acceptes,
             "acceptes=%d arg %s->%s pa %s->%s" % (acceptes, avant["arg"], apres["arg"],
                                                   avant["pa"], apres["pa"]))

    # === E. MONTANTS NON DECLARES =========================================
    # Le prix du billet ne doit pas pouvoir etre choisi par le navigateur.
    poser(tj, 10, 5000)
    for pa, cost, libelle in ((AVION_PA, 1, "billet a 1 FR"),
                              (0, AVION_COST, "billet sans PA"),
                              (AVION_PA, 100000, "billet demesure")):
        c, v = rpc("payer_ordre", {"p_acteur": JOUEUR, "p_fn": "prendre_avion",
                                   "p_pa": pa, "p_cost": cost}, jeton=tj)
        verifier("E %s : refuse" % libelle,
                 v.get("ok") is False and v.get("raison") == "cout_non_declare", str(v)[:110])

    # === F. ACTEUR USURPE =================================================
    c, v = rpc("payer_ordre", {"p_acteur": "Arnie", "p_fn": "prendre_avion",
                               "p_pa": AVION_PA, "p_cost": AVION_COST}, jeton=tj)
    verifier("F payer le billet d'un autre joueur : refuse",
             c in (400, 401, 403, 404) or v.get("ok") is False, "HTTP %s %s" % (c, str(v)[:90]))

    # === G. PARCOURS COMPLET, DANS L'ORDRE DU JEU =========================
    # Hall Principal -> Hall des Douanes -> Zone d'embarquement -> vol vers un autre empire.
    # Les deux premieres etapes sont gratuites (0 PA, 0 FR) : deduireCoutOrdre n'appelle alors
    # AUCUNE RPC, elles ne touchent que la position. Seul le vol est paye.
    poser(tj, 10, 5000)
    http("PATCH", "/rest/v1/personnages?name=eq." + JOUEUR,
         {"current_building": "centre-multinodal-luthecia", "current_room": "hall_gare",
          "country": "republic", "current_city": "capitale"}, jeton=tj)

    # 1. « Prendre l'avion » depuis le Hall Principal : conduit au Hall des Douanes.
    http("PATCH", "/rest/v1/personnages?name=eq." + JOUEUR,
         {"current_room": "hall_douanes"}, jeton=tj)
    c, r = http("GET", "/rest/v1/personnages?select=current_room&name=eq." + JOUEUR, jeton=tj)
    verifier("G1 Hall Principal -> Hall des Douanes",
             r and r[0]["current_room"] == "hall_douanes", str(r)[:90])

    # 2. « Passer le controle douanier » : conduit a la Zone d'embarquement.
    http("PATCH", "/rest/v1/personnages?name=eq." + JOUEUR,
         {"current_room": "zone_embarquement"}, jeton=tj)
    c, r = http("GET", "/rest/v1/personnages?select=current_room&name=eq." + JOUEUR, jeton=tj)
    verifier("G2 Hall des Douanes -> Zone d'embarquement",
             r and r[0]["current_room"] == "zone_embarquement", str(r)[:90])

    # 3. « Prendre l'avion » : le seul pas qui coute. C'est l'appel exact d'executerVoyage.
    avant = etat(tj)
    c, v = rpc("payer_ordre", {"p_acteur": JOUEUR, "p_fn": "prendre_avion",
                               "p_pa": AVION_PA, "p_cost": AVION_COST}, jeton=tj)
    verifier("G3 le billet est paye", v.get("ok") is True, str(v)[:110])

    # 4. Arrivee : executerVoyage ecrit le nouvel empire et la nouvelle ville.
    http("PATCH", "/rest/v1/personnages?name=eq." + JOUEUR,
         {"country": "narco", "current_city": "capitale",
          "current_building": None, "current_room": None}, jeton=tj)
    c, r = http("GET", "/rest/v1/personnages?select=country,current_city,arg,pa&name=eq." + JOUEUR,
                jeton=tj)
    arrivee = r[0] if r else {}
    verifier("G4 le joueur est reellement arrive dans l'autre empire",
             arrivee.get("country") == "narco" and arrivee.get("current_city") == "capitale",
             str(arrivee)[:110])
    verifier("G5 et il a paye exactement un billet : 300 FR, 2 PA",
             float(avant["arg"]) - float(arrivee["arg"]) == 300.0
             and int(avant["pa"]) - int(arrivee["pa"]) == 2,
             "arg %s->%s pa %s->%s" % (avant["arg"], arrivee["arg"], avant["pa"], arrivee["pa"]))

    for x in resultats:
        if not x["ok"]:
            print("  KO   %-60s %s" % (x["nom"], x["detail"]))
    ko = sum(1 for x in resultats if not x["ok"])
    print("\n%d controles, %d en echec." % (len(resultats), ko))
    return 1 if ko else 0


if __name__ == "__main__":
    sys.exit(main())
