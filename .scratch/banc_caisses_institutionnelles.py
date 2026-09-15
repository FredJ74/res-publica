#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BANC DES CAISSES INSTITUTIONNELLES (chantier C, 14 septembre 2026).

149 caisses (ministeres, mairies, commissariats, stades, marches, hotels...) etaient ecrites
par le navigateur en SOLDE ABSOLU : lecture HTTP, calcul local, ecriture HTTP. 42 sites
d'appel en dependaient via trois primitives clientes -- credit, debit plafonne, debit
tout-ou-rien.

La primitive serveur atomique existait deja (caisse_institution_mouvement, 12 septembre) mais
aucun appelant du navigateur ne l'utilisait. Les trois primitives sont reroutees, une variante
plafonnee a ete ajoutee pour les versements partiels deliberes du jeu, et la table est fermee
en ecriture.

Ce banc verifie la fermeture, les deux primitives, et les attaques.
Donnees zztest uniquement : une caisse 'zztest_*' creee puis supprimee en SQL.
"""
import json, sys, time, urllib.request, urllib.error

URL = "https://jxpwoosmmhohoihxpbuc.supabase.co"
ANON = ("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3"
        "NtbWhvaG9paHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMj"
        "IwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw")

SUF = str(int(time.time()))
CAISSE = "zztest-caisse-" + SUF
JOUEUR = "zztest-caisse-pj-" + SUF
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


def solde():
    c, r = http("GET", "/rest/v1/caisses_batiments?select=data&id=eq." + CAISSE)
    if not r:
        return None
    return (r[0]["data"] or {}).get("solde")


def main():
    tj = session()
    try:
        return deroulement(tj)
    finally:
        http("DELETE", "/rest/v1/personnages?name=eq." + JOUEUR, jeton=tj)


def deroulement(tj):
    code, rep = http("POST", "/rest/v1/personnages", {
        "name": JOUEUR, "country": "republic", "arg": 1000, "liquide": 1000, "pa": 20,
        "hp": 100, "moral": 75, "day": 10, "current_city": "capitale",
        "stats": {}, "resources": {}, "inventory": []}, jeton=tj)
    if code not in (200, 201):
        print("PREPARATION IMPOSSIBLE : %s %s" % (code, str(rep)[:140]))
        return 2

    # === A. LA TABLE EST FERMEE EN ECRITURE ================================
    c, r = http("POST", "/rest/v1/caisses_batiments",
                {"id": CAISSE, "data": {"solde": 10 ** 9}}, jeton=tj)
    verifier("A1 INSERT direct d'une caisse : refuse",
             c in (401, 403, 404) or (isinstance(r, dict) and r.get("code") == "42501"),
             "HTTP %s %s" % (c, str(r)[:70]))

    # La caisse est creee par la PRIMITIVE, pas par le client : c'est tout l'objet du correctif.
    c, v = rpc("caisse_institution_mouvement",
               {"p_id": CAISSE, "p_delta": 1000, "p_exiger_existant": False}, jeton=tj)
    # Le solde n'est plus renvoye par la RPC depuis le 15 septembre 2026 : le retourner faisait
    # d'elle un oracle de lecture (un appel a delta nul lisait n'importe quelle caisse sans rien
    # ecrire). On verifie donc l'effet REEL, en relisant la table.
    verifier("A2 le credit cree la caisse et la dote", v.get("ok") is True and solde() == 1000,
             "%s / solde=%s" % (str(v)[:60], solde()))

    c, r = http("PATCH", "/rest/v1/caisses_batiments?id=eq." + CAISSE,
                {"data": {"solde": 10 ** 9}}, jeton=tj, prefer="return=representation")
    verifier("A3 PATCH direct du solde : refuse",
             c in (401, 403, 404) or (isinstance(r, dict) and r.get("code") == "42501"),
             "HTTP %s %s" % (c, str(r)[:70]))
    verifier("A4 le solde n'a pas bouge", solde() == 1000, solde())

    c, r = http("DELETE", "/rest/v1/caisses_batiments?id=eq." + CAISSE, jeton=tj)
    verifier("A5 DELETE direct : refuse",
             c in (401, 403, 404) or (isinstance(r, dict) and r.get("code") == "42501"),
             "HTTP %s %s" % (c, str(r)[:70]))
    verifier("A6 la lecture reste ouverte", solde() is not None, solde())

    c, v = rpc("caisse_institution_mouvement_plafonne", {"p_id": CAISSE, "p_montant": 0}, jeton=tj)
    verifier("A7 mouvement nul refuse : plus d'oracle de lecture",
             v.get("ok") is False and "solde" not in v, str(v)[:90])

    # === B. DEBIT TOUT-OU-RIEN =============================================
    c, v = rpc("caisse_institution_mouvement",
               {"p_id": CAISSE, "p_delta": -300, "p_exiger_existant": True}, jeton=tj)
    verifier("B1 debit de 300 sur 1000 : accepte", v.get("ok") is True and solde() == 700,
             "%s / solde=%s" % (str(v)[:60], solde()))

    c, v = rpc("caisse_institution_mouvement",
               {"p_id": CAISSE, "p_delta": -10000, "p_exiger_existant": True}, jeton=tj)
    verifier("B2 debit superieur au solde : refuse EN ENTIER",
             v.get("ok") is False and v.get("raison") == "solde_insuffisant", str(v)[:100])
    verifier("B3 et le solde est intact (aucun debit partiel)", solde() == 700, solde())

    c, v = rpc("caisse_institution_mouvement",
               {"p_id": "zztest-caisse-inexistante-" + SUF, "p_delta": -1, "p_exiger_existant": True},
               jeton=tj)
    verifier("B4 debit sur une caisse absente, existence exigee : refuse",
             v.get("ok") is False and v.get("raison") == "caisse_absente", str(v)[:100])

    # === C. DEBIT PLAFONNE (versement partiel delibere du jeu) =============
    c, v = rpc("caisse_institution_mouvement_plafonne",
               {"p_id": CAISSE, "p_montant": 200}, jeton=tj)
    verifier("C1 versement de 200 sur 700 : verse 200",
             v.get("ok") is True and float(v.get("verse")) == 200.0, str(v)[:100])

    c, v = rpc("caisse_institution_mouvement_plafonne",
               {"p_id": CAISSE, "p_montant": 99999}, jeton=tj)
    verifier("C2 versement demande au-dela du solde : verse EXACTEMENT le solde",
             v.get("ok") is True and float(v.get("verse")) == 500.0, str(v)[:100])
    verifier("C3 la caisse est a zero, jamais negative", solde() == 0, solde())

    c, v = rpc("caisse_institution_mouvement_plafonne",
               {"p_id": CAISSE, "p_montant": 100}, jeton=tj)
    verifier("C4 versement sur une caisse vide : verse 0, sans erreur",
             v.get("ok") is True and float(v.get("verse")) == 0.0, str(v)[:100])

    # === D. PARAMETRES FORGES ==============================================
    for montant, libelle in ((-50, "montant negatif"), (10 ** 9, "montant demesure")):
        c, v = rpc("caisse_institution_mouvement_plafonne",
                   {"p_id": CAISSE, "p_montant": montant}, jeton=tj)
        verifier("D %s : refuse" % libelle,
                 v.get("ok") is False and v.get("raison") == "parametres_invalides", str(v)[:90])

    c, v = rpc("caisse_institution_mouvement",
               {"p_id": CAISSE, "p_delta": 10 ** 9, "p_exiger_existant": False}, jeton=tj)
    verifier("D delta demesure : refuse",
             v.get("ok") is False and v.get("raison") == "parametres_invalides", str(v)[:90])

    c, v = rpc("caisse_institution_mouvement", {"p_id": "", "p_delta": 1, "p_exiger_existant": False},
               jeton=tj)
    verifier("D identifiant vide : refuse",
             v.get("ok") is False and v.get("raison") == "parametres_invalides", str(v)[:90])

    # === E. SANS SESSION ===================================================
    c, v = rpc("caisse_institution_mouvement",
               {"p_id": CAISSE, "p_delta": 10000, "p_exiger_existant": False})
    verifier("E sans session : refuse",
             c in (401, 403, 404) or v.get("ok") is False
             or v.get("code") in ("42501", "42883", "PGRST202"), "HTTP %s %s" % (c, str(v)[:70]))
    verifier("E le solde reste a zero apres les tentatives", solde() == 0, solde())

    for x in resultats:
        if not x["ok"]:
            print("  KO   %-62s %s" % (x["nom"], x["detail"]))
    ko = sum(1 for x in resultats if not x["ok"])
    print("\n%d controles, %d en echec." % (len(resultats), ko))
    print("Caisse zztest a supprimer en SQL : %s" % CAISSE)
    return 1 if ko else 0


if __name__ == "__main__":
    sys.exit(main())
