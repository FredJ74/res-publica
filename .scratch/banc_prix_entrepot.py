#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BANC DU PRIX D'ENTREPOT ET DE L'ACHAT PJ (14 septembre 2026).

Deux verifications liees au lot « libelle + recette d'export » :
  1. le prix fixe par le directeur est bien le prix auquel l'entrepot VEND (c'est ce que
     acheter_a_entrepot facture au joueur, et c'est la caisse de l'entrepot qui l'encaisse) ;
  2. aucune fourchette n'est imposee au directeur -- il peut brader comme surmarger, seules les
     valeurs techniquement invalides sont refusees (arbitrage du 14 septembre 2026).

Le banc utilise l'entrepot REEL de la capitale, car fixer_prix_entrepot resout le batiment depuis
le poste du directeur et la table entrepots_par_ville : on ne peut pas lui substituer un batiment
zztest. Son etat est donc SAUVEGARDE avant, RESTAURE apres, et l'identite verifiee.

Le personnage de test est un zztest, supprime a la fin.
"""
import json, sys, time, urllib.request, urllib.error

URL = "https://jxpwoosmmhohoihxpbuc.supabase.co"
ANON = ("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3"
        "NtbWhvaG9paHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMj"
        "IwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw")

SUF = str(int(time.time()))
JOUEUR = "zztest-entrepot-" + SUF
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
    resultats.append({"nom": nom, "ok": bool(ok), "detail": str(detail)[:160]})


def rpc(nom, corps, jeton=None):
    c, r = http("POST", "/rest/v1/rpc/" + nom, corps, jeton=jeton)
    v = r[0] if isinstance(r, list) else r
    return c, (v if isinstance(v, dict) else {"brut": v})


def main():
    tj = session()
    try:
        return deroulement(tj)
    finally:
        http("DELETE", "/rest/v1/personnages?name=eq." + JOUEUR, jeton=tj)


def deroulement(tj):
    # Le personnage est DIRECTEUR de l'entrepot de la capitale, et s'y trouve.
    code, rep = http("POST", "/rest/v1/personnages", {
        "name": JOUEUR, "country": "republic", "arg": 50000, "liquide": 50000, "pa": 20,
        "hp": 100, "moral": 75, "day": 10, "current_city": "capitale",
        "current_building": "entrepot-logistique-luthecia", "current_room": "quai",
        "poste": {"id": "directeur_entrepot", "city": "capitale"},
        "stats": {}, "resources": {}, "inventory": []}, jeton=tj)
    if code not in (200, 201):
        print("PREPARATION IMPOSSIBLE : %s %s" % (code, str(rep)[:200]))
        return 2

    # === A. LE PRIX FIXE EST BIEN UN PRIX DE VENTE ========================
    # On fixe un prix volontairement tres bas, puis on achete : si c'est bien le prix de VENTE,
    # le joueur paie ce montant-la et la caisse de l'entrepot l'encaisse.
    c, v = rpc("fixer_prix_entrepot",
               {"p_acteur": JOUEUR, "p_pays": "republic", "p_prix": {"bois": 0.5}}, jeton=tj)
    verifier("A1 le directeur peut fixer un prix", v.get("ok") is True, str(v)[:120])
    verifier("A2 le prix retenu est bien celui demande",
             float((v.get("prixManuel") or {}).get("bois", -1)) == 0.5, str(v.get("prixManuel"))[:80])

    c, av = rpc("acheter_a_entrepot",
                {"p_acteur": JOUEUR, "p_pays": "republic", "p_ville": "capitale",
                 "p_batiment": "entrepot-logistique-luthecia", "p_achats": {"bois": 10}}, jeton=tj)
    verifier("A3 l'achat par le joueur aboutit", av.get("ok") is True, str(av)[:130])
    verifier("A4 LE JOUEUR PAIE LE PRIX FIXE PAR LE DIRECTEUR (10 x 0,5 = 5 FR)",
             float(av.get("paye", -1)) == 5.0,
             "paye=" + str(av.get("paye")) + " (attendu 5.0 — c'est donc un prix de VENTE)")

    # === B. AUCUNE FOURCHETTE IMPOSEE =====================================
    # prix_base du bois = 5 FR. ±40% donnerait [3 ; 7]. On verifie que 0,5 et 500 passent tous
    # les deux : le directeur est libre de brader comme de surmarger.
    c, v = rpc("fixer_prix_entrepot",
               {"p_acteur": JOUEUR, "p_pays": "republic", "p_prix": {"bois": 0.01}}, jeton=tj)
    verifier("B1 brader tres en dessous du prix de base : accepte", v.get("ok") is True, str(v)[:110])
    c, v = rpc("fixer_prix_entrepot",
               {"p_acteur": JOUEUR, "p_pays": "republic", "p_prix": {"bois": 500}}, jeton=tj)
    verifier("B2 surmarger tres au-dessus : accepte", v.get("ok") is True, str(v)[:110])

    # === C. VALIDATIONS TECHNIQUES CONSERVEES =============================
    for valeur, libelle in ((0, "prix nul"), (-5, "prix negatif")):
        c, v = rpc("fixer_prix_entrepot",
                   {"p_acteur": JOUEUR, "p_pays": "republic", "p_prix": {"bois": valeur}}, jeton=tj)
        verifier("C %s : refuse" % libelle,
                 v.get("ok") is False and v.get("raison") == "prix_invalide", str(v)[:110])
    c, v = rpc("fixer_prix_entrepot",
               {"p_acteur": JOUEUR, "p_pays": "republic", "p_prix": {"zz_ressource_inventee": 3}},
               jeton=tj)
    verifier("C ressource inconnue : refusee",
             v.get("ok") is False and v.get("raison") == "ressource_inconnue", str(v)[:110])

    # === D. LIBERATION DU PRIX MANUEL =====================================
    # Un envoi vide remet la table a zero : on revient au prix automatique.
    c, v = rpc("fixer_prix_entrepot",
               {"p_acteur": JOUEUR, "p_pays": "republic", "p_prix": {}}, jeton=tj)
    verifier("D1 liberer tous les prix manuels : accepte",
             v.get("ok") is True and v.get("prixManuel") == {}, str(v)[:110])

    c, av2 = rpc("acheter_a_entrepot",
                 {"p_acteur": JOUEUR, "p_pays": "republic", "p_ville": "capitale",
                  "p_batiment": "entrepot-logistique-luthecia", "p_achats": {"bois": 10}}, jeton=tj)
    verifier("D2 sans prix manuel, l'achat repasse au prix automatique",
             av2.get("ok") is True and float(av2.get("paye", 0)) != 5.0,
             "paye=" + str(av2.get("paye")))

    # === E. POSTE EXIGE ===================================================
    http("PATCH", "/rest/v1/personnages?name=eq." + JOUEUR, {"poste": None}, jeton=tj)
    c, v = rpc("fixer_prix_entrepot",
               {"p_acteur": JOUEUR, "p_pays": "republic", "p_prix": {"bois": 9}}, jeton=tj)
    verifier("E sans le poste de directeur : refuse",
             v.get("ok") is False and v.get("raison") == "poste_non_detenu", str(v)[:110])

    for x in resultats:
        if not x["ok"]:
            print("  KO   %-62s %s" % (x["nom"], x["detail"]))
    ko = sum(1 for x in resultats if not x["ok"])
    print("\n%d controles, %d en echec." % (len(resultats), ko))
    return 1 if ko else 0


if __name__ == "__main__":
    sys.exit(main())
