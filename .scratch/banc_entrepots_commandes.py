#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BANC DU SYSTEME DE COMMANDES DES ENTREPOTS (14 septembre 2026).

Eprouve les RPC serveur du nouveau systeme : desideratas, capacite 5 000, commandes directes
nationales / Port / etrangeres, fret, transit, embargo, concurrence, caisses, registre.

Fixtures zztest uniquement : deux entrepots 'entrepot-zztest-a' et '-b' dans deux villes
'zzville-a' / 'zzville-b'. Les trois entrepots reels de Republia ne sont JAMAIS touches.

Le cron n'est jamais appele.
"""
import json, sys, time, urllib.request, urllib.error

URL = "https://jxpwoosmmhohoihxpbuc.supabase.co"
ANON = ("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3"
        "NtbWhvaG9paHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMj"
        "IwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw")

SUF = str(int(time.time()))
DIR_A = "zztest-dir-a-" + SUF      # directeur de zzville-a (acheteur)
DIR_B = "zztest-dir-b-" + SUF      # directeur de zzville-b (fournisseur)
ENT_A = "republic_zzville-a_entrepot-zztest-a"
ENT_B = "republic_zzville-b_entrepot-zztest-b"
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
    resultats.append({"nom": nom, "ok": bool(ok), "detail": str(detail)[:170]})


def rpc(nom, corps, jeton=None):
    c, r = http("POST", "/rest/v1/rpc/" + nom, corps, jeton=jeton)
    v = r[0] if isinstance(r, list) else r
    return c, (v if isinstance(v, dict) else {"brut": v})


def entrepot(eid, jeton):
    c, r = http("GET", "/rest/v1/batiments_etat?select=data&id=eq." + eid, jeton=jeton)
    if not r:
        return {}
    d = r[0]["data"]
    try:
        return json.loads(d if isinstance(d, str) else json.dumps(d)).get("entrepot", {})
    except Exception:
        return {}


def transits(eid, jeton):
    c, r = http("GET", "/rest/v1/entrepot_transits?select=*&destination_id=eq." + eid, jeton=jeton)
    return r or []


def journal(eid, jeton):
    c, r = http("GET", "/rest/v1/entrepot_journal?select=*&entrepot_id=eq." + eid, jeton=jeton)
    return r or []


def creer(jeton, nom, ville):
    return http("POST", "/rest/v1/personnages", {
        "name": nom, "country": "republic", "arg": 5000, "liquide": 5000, "pa": 20,
        "hp": 100, "moral": 75, "day": 10, "current_city": ville,
        "poste": {"id": "directeur_entrepot", "city": ville},
        "stats": {}, "resources": {}, "inventory": []}, jeton=jeton)


def main():
    tA = session()
    time.sleep(1)
    tB = session()
    try:
        return deroulement(tA, tB)
    finally:
        http("DELETE", "/rest/v1/personnages?name=eq." + DIR_A, jeton=tA)
        http("DELETE", "/rest/v1/personnages?name=eq." + DIR_B, jeton=tB)


def deroulement(tA, tB):
    for jeton, nom, ville in ((tA, DIR_A, 'zzville-a'), (tB, DIR_B, 'zzville-b')):
        code, rep = creer(jeton, nom, ville)
        if code not in (200, 201):
            print("PREPARATION IMPOSSIBLE (%s) : %s %s" % (nom, code, str(rep)[:180]))
            return 2

    # === A. DESIDERATAS ===================================================
    c, v = rpc("entrepot_fixer_desiderata",
               {"p_acteur": DIR_A, "p_desiderata": {"cereales": 3500, "viande": 2000, "textile": 0}},
               jeton=tA)
    verifier("A1 le directeur pose ses stocks cibles", v.get("ok") is True, str(v)[:130])
    verifier("A2 les valeurs sont celles demandees",
             (v.get("desiderata") or {}).get("cereales") == 3500
             and (v.get("desiderata") or {}).get("textile") == 0, str(v.get("desiderata"))[:110])
    verifier("A3 fixer un desiderata ne coute aucun PA",
             (lambda r: r and int(r[0]["pa"]) == 20)(
                 http("GET", "/rest/v1/personnages?select=pa&name=eq." + DIR_A, jeton=tA)[1]),
             "PA inchanges")

    for val, libelle in ((5001, "au-dessus de 5 000"), (-1, "negatif"), (12.5, "non entier")):
        c, v = rpc("entrepot_fixer_desiderata",
                   {"p_acteur": DIR_A, "p_desiderata": {"cereales": val}}, jeton=tA)
        verifier("A desiderata %s : refuse" % libelle,
                 v.get("ok") is False and v.get("raison") == "desiderata_invalide", str(v)[:110])
    c, v = rpc("entrepot_fixer_desiderata",
               {"p_acteur": DIR_A, "p_desiderata": {"cereales": 5000}}, jeton=tA)
    verifier("A4 la borne haute 5 000 est acceptee", v.get("ok") is True, str(v)[:110])

    c, v = rpc("entrepot_fixer_desiderata",
               {"p_acteur": DIR_B, "p_desiderata": {"cereales": 100}}, jeton=tA)
    verifier("A5 poser les desideratas d'un autre entrepot : refuse",
             c in (400, 401, 403, 404) or v.get("ok") is False, "HTTP %s %s" % (c, str(v)[:90]))

    # === B. CAPACITE ======================================================
    c, v = rpc("entrepot_capacite_disponible",
               {"p_entrepot_id": ENT_B, "p_ressource": "cereales"}, jeton=tA)
    verifier("B1 capacite = 5000 - stock (2000) - transit (0) = 3000",
             v.get("brut") == 3000, str(v)[:90])

    # === C. COMMANDE NATIONALE ============================================
    avantA, avantB = entrepot(ENT_A, tA), entrepot(ENT_B, tB)
    c, v = rpc("entrepot_commander",
               {"p_acteur": DIR_A, "p_ressource": "cereales", "p_quantite": 500,
                "p_fournisseur_type": "entrepot", "p_fournisseur_id": ENT_B}, jeton=tA)
    verifier("C1 commande nationale acceptee", v.get("ok") is True, str(v)[:140])
    verifier("C2 prix = celui AFFICHE par le fournisseur (prixManuel 4 FR)",
             float(v.get("prix_unitaire", 0)) == 4.0, v.get("prix_unitaire"))
    verifier("C3 aucun fret sur une commande nationale",
             float(v.get("fret_unitaire", -1)) == 0.0, v.get("fret_unitaire"))
    verifier("C4 delai national J+1", v.get("delai_jours") == 1, v.get("delai_jours"))
    apresA, apresB = entrepot(ENT_A, tA), entrepot(ENT_B, tB)
    verifier("C5 la caisse ACHETEUR est debitee de 500 x 4 = 2000",
             float(avantA["caisse"]) - float(apresA["caisse"]) == 2000.0,
             "%s -> %s" % (avantA["caisse"], apresA["caisse"]))
    verifier("C6 la caisse VENDEUR est creditee du meme montant",
             float(apresB["caisse"]) - float(avantB["caisse"]) == 2000.0,
             "%s -> %s" % (avantB["caisse"], apresB["caisse"]))
    verifier("C7 le stock quitte IMMEDIATEMENT le fournisseur",
             float(apresB["stock"]["cereales"]) == 1500.0, apresB["stock"]["cereales"])
    verifier("C8 le stock n'est PAS encore chez l'acheteur (il est en transit)",
             float((apresA.get("stock") or {}).get("cereales", 0)) == 0.0,
             (apresA.get("stock") or {}).get("cereales"))
    tr = [t for t in transits(ENT_A, tA) if t["ressource"] == "cereales"]
    verifier("C9 le transit est enregistre et visible",
             len(tr) == 1 and tr[0]["quantite"] == 500, str(tr)[:130])
    verifier("C10 la capacite tient compte du transit",
             rpc("entrepot_capacite_disponible",
                 {"p_entrepot_id": ENT_A, "p_ressource": "cereales"}, jeton=tA)[1].get("brut") == 4500,
             "attendu 4500")

    # === D. COMMANDE ETRANGERE ET FRET ====================================
    avantA = entrepot(ENT_A, tA)
    c, v = rpc("entrepot_commander",
               {"p_acteur": DIR_A, "p_ressource": "petrole", "p_quantite": 100,
                "p_fournisseur_type": "etranger", "p_fournisseur_id": "khalija"}, jeton=tA)
    verifier("D1 commande etrangere acceptee", v.get("ok") is True, str(v)[:140])
    verifier("D2 fret international = 0,40 FR/unite",
             float(v.get("fret_unitaire", 0)) == 0.40, v.get("fret_unitaire"))
    verifier("D3 delai etranger J+2", v.get("delai_jours") == 2, v.get("delai_jours"))
    verifier("D4 Al-Khalija produit le petrole : prix fournisseur (4 FR), pas prix de base (8)",
             float(v.get("prix_unitaire", 0)) == 4.0, v.get("prix_unitaire"))
    apresA = entrepot(ENT_A, tA)
    verifier("D5 l'acheteur paie marchandise + fret : 100 x (4 + 0,40) = 440",
             float(avantA["caisse"]) - float(apresA["caisse"]) == 440.0,
             "%s -> %s" % (avantA["caisse"], apresA["caisse"]))
    verifier("D6 aucun droit de douane institutionnel n'est preleve",
             float(v.get("montant", 0)) == 440.0, v.get("montant"))

    # === E. CONTRAINTES ===================================================
    c, v = rpc("entrepot_commander",
               {"p_acteur": DIR_A, "p_ressource": "cereales", "p_quantite": 999999,
                "p_fournisseur_type": "entrepot", "p_fournisseur_id": ENT_B}, jeton=tA)
    verifier("E1 plus que le stock du fournisseur : refuse",
             v.get("ok") is False and v.get("raison") == "stock_fournisseur_insuffisant", str(v)[:120])

    c, v = rpc("entrepot_commander",
               {"p_acteur": DIR_A, "p_ressource": "cereales", "p_quantite": 4600,
                "p_fournisseur_type": "etranger", "p_fournisseur_id": "soviet"}, jeton=tA)
    verifier("E2 au-dela de la capacite restante (transit compris) : refuse",
             v.get("ok") is False and v.get("raison") == "capacite_insuffisante", str(v)[:130])

    c, v = rpc("entrepot_commander",
               {"p_acteur": DIR_B, "p_ressource": "metal", "p_quantite": 1000,
                "p_fournisseur_type": "etranger", "p_fournisseur_id": "narco"}, jeton=tB)
    verifier("E3 tresorerie insuffisante : refuse",
             v.get("ok") is False and v.get("raison") == "tresorerie_insuffisante", str(v)[:120])

    c, v = rpc("entrepot_commander",
               {"p_acteur": DIR_A, "p_ressource": "cereales", "p_quantite": 10,
                "p_fournisseur_type": "entrepot", "p_fournisseur_id": ENT_A}, jeton=tA)
    verifier("E4 se commander a soi-meme : refuse",
             v.get("ok") is False and v.get("raison") == "fournisseur_est_soi_meme", str(v)[:110])

    c, v = rpc("entrepot_commander",
               {"p_acteur": DIR_A, "p_ressource": "cereales", "p_quantite": 0,
                "p_fournisseur_type": "entrepot", "p_fournisseur_id": ENT_B}, jeton=tA)
    verifier("E5 quantite nulle : refusee",
             v.get("ok") is False and v.get("raison") == "quantite_invalide", str(v)[:110])

    # === F. AUCUN PA CONSOMME =============================================
    c, r = http("GET", "/rest/v1/personnages?select=pa&name=eq." + DIR_A, jeton=tA)
    verifier("F les commandes n'ont consomme aucun PA", r and int(r[0]["pa"]) == 20,
             str(r)[:60])

    # === G. CONCURRENCE ===================================================
    # Le stock de B vaut 1500 cereales. Deux commandes de 1000 : une seule peut passer.
    c1, v1 = rpc("entrepot_commander",
                 {"p_acteur": DIR_A, "p_ressource": "cereales", "p_quantite": 1000,
                  "p_fournisseur_type": "entrepot", "p_fournisseur_id": ENT_B}, jeton=tA)
    c2, v2 = rpc("entrepot_commander",
                 {"p_acteur": DIR_A, "p_ressource": "cereales", "p_quantite": 1000,
                  "p_fournisseur_type": "entrepot", "p_fournisseur_id": ENT_B}, jeton=tA)
    verifier("G1 le meme stock ne peut pas etre vendu deux fois",
             bool(v1.get("ok")) != bool(v2.get("ok")),
             "1:%s 2:%s" % (v1.get("ok") or v1.get("raison"), v2.get("ok") or v2.get("raison")))
    verifier("G2 le stock du fournisseur reste coherent, jamais negatif",
             float(entrepot(ENT_B, tB)["stock"]["cereales"]) == 500.0,
             entrepot(ENT_B, tB)["stock"]["cereales"])

    # === H. EMBARGO =======================================================
    # budgets_nationaux.republic porte l'etat budgetaire national REEL. Un PATCH sur sa colonne
    # jsonb REMPLACE tout le blob : il faut donc sauvegarder la valeur exacte, ne fusionner que
    # la cle 'sanctions', et restaurer a l'identique en fin de section. (Lecon apprise a mes
    # depens : la premiere version de ce banc a efface reserveJour, tauxNational et les
    # marqueurs de jour du cron.)
    trAvant = len(transits(ENT_A, tA))
    c, rb = http("GET", "/rest/v1/budgets_nationaux?select=data&id=eq.republic", jeton=tA)
    budgetOriginal = (rb[0]["data"] if rb else None)
    if budgetOriginal is None:
        print("ETAT BUDGETAIRE ILLISIBLE : section embargo non jouee, rien n'a ete modifie.")
        return 2
    avecEmbargo = dict(budgetOriginal)
    avecEmbargo["sanctions"] = {"soviet": {"mesures": ["embargo"]}}
    http("PATCH", "/rest/v1/budgets_nationaux?id=eq.republic", {"data": avecEmbargo}, jeton=tA)
    c, v = rpc("embargo_actif", {"p_pays_soi": "republic", "p_pays_cible": "soviet"}, jeton=tA)
    verifier("H1 l'embargo est lu par le serveur", v.get("brut") is True, str(v)[:90])
    c, v = rpc("entrepot_commander",
               {"p_acteur": DIR_A, "p_ressource": "textile", "p_quantite": 10,
                "p_fournisseur_type": "etranger", "p_fournisseur_id": "soviet"}, jeton=tA)
    verifier("H2 nouvelle commande vers un pays sous embargo : refusee",
             v.get("ok") is False and v.get("raison") == "embargo", str(v)[:110])
    c, v = rpc("entrepot_commander",
               {"p_acteur": DIR_A, "p_ressource": "textile", "p_quantite": 10,
                "p_fournisseur_type": "etranger", "p_fournisseur_id": "narco"}, jeton=tA)
    verifier("H3 les autres pays restent commandables", v.get("ok") is True, str(v)[:110])
    verifier("H4 AUCUN EFFET RETROACTIF : les transits anterieurs subsistent",
             len(transits(ENT_A, tA)) > trAvant, len(transits(ENT_A, tA)))

    # Restauration immediate et verification d'identite du blob budgetaire national.
    http("PATCH", "/rest/v1/budgets_nationaux?id=eq.republic", {"data": budgetOriginal}, jeton=tA)
    c, rb2 = http("GET", "/rest/v1/budgets_nationaux?select=data&id=eq.republic", jeton=tA)
    verifier("H5 l'etat budgetaire national est restaure a l'identique",
             rb2 and rb2[0]["data"] == budgetOriginal,
             json.dumps(rb2[0]["data"] if rb2 else None)[:140])

    # === I. REGISTRE ======================================================
    jA = journal(ENT_A, tA)
    jB = journal(ENT_B, tB)
    verifier("I1 l'acheteur a une trace de chaque commande",
             len([x for x in jA if x["operation"] == "commande_directe" and x["sens"] == "entree"]) >= 3,
             len(jA))
    verifier("I2 le vendeur a la trace de sa vente",
             any(x["operation"] == "commande_directe" and x["sens"] == "sortie" for x in jB),
             len(jB))
    une = next((x for x in jA if x["ressource"] == "petrole"), None)
    verifier("I3 le registre porte prix, fret, montant et ETA",
             une and float(une["prix_unitaire"]) == 4.0 and float(une["fret_unitaire"]) == 0.40
             and une["arrivee_le"] is not None and une["statut"] == "en_transit",
             str(une)[:150])

    # === J. LE REGISTRE APPARTIENT A L'ETABLISSEMENT ======================
    c, r = http("GET", "/rest/v1/entrepot_journal?select=id&entrepot_id=eq." + ENT_A)
    verifier("J le registre est lisible sans etre le directeur (il suit l'etablissement)",
             isinstance(r, list) and len(r) > 0, len(r) if isinstance(r, list) else r)

    # === K. ECRITURES DIRECTES INTERDITES =================================
    c, r = http("POST", "/rest/v1/entrepot_transits",
                {"destination_id": ENT_A, "ressource": "metal", "quantite": 9999,
                 "origine_type": "etranger", "origine_libelle": "triche", "prix_unitaire": 0,
                 "montant_total": 0, "arrivee_le": "2026-09-15"}, jeton=tA)
    verifier("K1 creer un transit a la main : refuse",
             c in (401, 403, 404) or (isinstance(r, dict) and r.get("code") == "42501"),
             "HTTP %s %s" % (c, str(r)[:80]))
    c, r = http("POST", "/rest/v1/entrepot_journal",
                {"entrepot_id": ENT_A, "operation": "triche", "sens": "entree"}, jeton=tA)
    verifier("K2 ecrire au registre a la main : refuse",
             c in (401, 403, 404) or (isinstance(r, dict) and r.get("code") == "42501"),
             "HTTP %s %s" % (c, str(r)[:80]))

    for x in resultats:
        if not x["ok"]:
            print("  KO   %-62s %s" % (x["nom"], x["detail"]))
    ko = sum(1 for x in resultats if not x["ok"])
    print("\n%d controles, %d en echec." % (len(resultats), ko))
    return 1 if ko else 0


if __name__ == "__main__":
    sys.exit(main())
