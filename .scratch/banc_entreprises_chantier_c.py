#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BANC DES ENTREPRISES — CHANTIER C, PHASE 3.

`entreprises` est dans l'etat ou etait `batiments_etat` avant la phase 2 : RLS desactivee,
anon detenant INSERT/UPDATE/DELETE, et 23 sites clients qui reecrivent le blob COMPLET.
Ce banc suit la migration famille par famille.

Familles couvertes ici :
  1. existence et dotation   -> entreprise_assurer_existence
  2. prix et parametres      -> commerce_fixer_parametres
  3. achat de matiere        -> commerce_acheter_matiere

FIXTURE : une entreprise 'zztest-commerce-p3' et son proprietaire 'zztest-p3-proprio' sont
rearmes par le workflow de migration (SQL) avant chaque execution -- le client n'a pas a
pouvoir fabriquer une entreprise, c'est precisement ce que la phase 3 ferme.
"""
import json, sys, time, urllib.request, urllib.error

URL = "https://jxpwoosmmhohoihxpbuc.supabase.co"
ANON = ("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3"
        "NtbWhvaG9paHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMj"
        "IwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw")

# Ville UNIQUE par execution : la ligne creee par le test de creation n'est plus
# supprimable depuis le client une fois la table fermee, et reutiliser la meme ville
# ferait mesurer la ligne de l'execution precedente au lieu d'une vraie creation.
VILLE_NEUVE = "zzville-" + str(int(time.time()))
ENT = "zztest-commerce-p3"
PROPRIO, QUIDAM = "zztest-p3-proprio", "zztest-p3-quidam"
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


def creer(nom, jeton, arg=5000, inventaire=None):
    return http("POST", "/rest/v1/personnages", {
        "name": nom, "country": "republic", "arg": arg, "liquide": arg, "pa": 20, "hp": 100,
        "moral": 75, "day": 10, "current_city": "capitale", "stats": {}, "resources": {},
        "inventory": inventaire or []}, jeton=jeton)


def entreprise():
    c, r = http("GET", "/rest/v1/entreprises?select=data&id=eq." + ENT)
    return (r[0]["data"] if r else None)


def perso(nom, jeton=None):
    # 'arg' et 'inventory' sont des colonnes MASQUEES depuis le chantier B : les lire sans la
    # session de leur proprietaire renvoie NULL. Le banc doit donc presenter le bon jeton.
    c, r = http("GET", "/rest/v1/personnages?select=arg,inventory&name=eq." + nom, jeton=jeton)
    return (r[0] if r else {})


def main():
    tp, tq = session(), session()
    try:
        return deroulement(tp, tq)
    finally:
        for nom, jeton in ((PROPRIO, tp), (QUIDAM, tq)):
            http("DELETE", "/rest/v1/personnages?name=eq." + nom, jeton=jeton)


def deroulement(tp, tq):
    # La carte du commerce de test (cafe_boisson + vin) accepte produits_exotiques et
    # fruits_legumes. 'metal' sert justement de matiere NON acceptee.
    lots = [{"stackable": True, "stackKey": "produits_exotiques", "qty": 10, "name": "Produits exotiques"},
            {"stackable": True, "stackKey": "metal", "qty": 5, "name": "Métal"}]
    for nom, jeton, inv in ((PROPRIO, tp, lots), (QUIDAM, tq, list(lots))):
        code, rep = creer(nom, jeton, 5000, inv)
        if code not in (200, 201):
            print("PREPARATION IMPOSSIBLE (%s) : %s %s" % (nom, code, str(rep)[:150]))
            return 2

    # La fixture DERIVE a chaque execution (la vente y ajoute du stock et en retire de la
    # caisse) et le client ne peut plus la remettre a zero : elle est rearmee par le workflow
    # de migration. On refuse de mesurer un etat derive plutot que de rendre un faux vert.
    depart = entreprise()
    attendu = {"proprietaire": PROPRIO, "caisse": 2000}
    derive = (not depart
              or depart.get("proprietaire") != attendu["proprietaire"]
              or float(depart.get("caisse", -1)) != float(attendu["caisse"])
              or (depart.get("stockMatieres") or {}).get("produits_exotiques") != 10)
    if derive:
        print("FIXTURE ABSENTE OU DERIVEE (%s).\nRearmer par migration SQL : proprietaire=%s, "
              "caisse=2000, stockMatieres produits_exotiques=10/fruits_legumes=10/cereales=2, "
              "carte [cafe_boisson, vin]."
              % (json.dumps({k: depart.get(k) for k in ("proprietaire", "caisse", "stockMatieres")}
                            if depart else None)[:160], PROPRIO))
        return 2

    # === FAMILLE 1 : EXISTENCE ET DOTATION ==================================
    c, v = rpc("entreprise_assurer_existence",
               {"p_id": "armurerie-republic-capitale", "p_type": "armurerie",
                "p_pays": "republic", "p_ville": "capitale",
                "p_batiment": "armurerie", "p_room": None}, jeton=tq)
    verifier("F1 armurerie existante : rendue sans recreation",
             v.get("ok") is True and v.get("cree") is False, str(v)[:90])

    c, v = rpc("entreprise_assurer_existence",
               {"p_id": "armurerie-republic-inventee", "p_type": "armurerie",
                "p_pays": "republic", "p_ville": "capitale",
                "p_batiment": "armurerie", "p_room": None}, jeton=tq)
    verifier("F1 identifiant d'armurerie non conforme : refuse",
             v.get("ok") is False and v.get("raison") == "identifiant_non_conforme", str(v)[:90])

    c, v = rpc("entreprise_assurer_existence",
               {"p_id": "cafe-republic-capitale-batiment-invente", "p_type": "cafe",
                "p_pays": "republic", "p_ville": "capitale",
                "p_batiment": "batiment-invente", "p_room": None}, jeton=tq)
    verifier("F1 batiment sans commerce declare : refuse",
             v.get("ok") is False and v.get("raison") == "batiment_sans_commerce", str(v)[:90])

    c, v = rpc("entreprise_assurer_existence",
               {"p_id": "armurerie-republic-" + VILLE_NEUVE, "p_type": "armurerie",
                "p_pays": "republic", "p_ville": VILLE_NEUVE,
                "p_batiment": "armurerie", "p_room": None}, jeton=tq)
    cree = v.get("ok") is True and v.get("cree") is True
    verifier("F1 armurerie legitime creee par le SERVEUR", cree, str(v)[:90])
    if cree:
        verifier("F1 sa caisse vient du miroir, pas du navigateur",
                 (v.get("data") or {}).get("caisse") == 20000, (v.get("data") or {}).get("caisse"))

    # Le controle de type ne porte que sur la CREATION : une ligne deja existante est simplement
    # relue. On vise donc une ville ou le commerce n'existe pas encore.
    c, v = rpc("entreprise_assurer_existence",
               {"p_id": "cafe-republic-" + VILLE_NEUVE + "-hotel-republica", "p_type": "cafe",
                "p_pays": "republic", "p_ville": VILLE_NEUVE,
                "p_batiment": "hotel-republica", "p_room": None}, jeton=tq)
    verifier("F1 type annonce different du miroir : refuse",
             v.get("ok") is False and v.get("raison") == "type_non_conforme", str(v)[:90])

    c, v = rpc("entreprise_assurer_existence",
               {"p_id": "armurerie-republic-" + VILLE_NEUVE + "-bis", "p_type": "armurerie",
                "p_pays": "republic", "p_ville": VILLE_NEUVE + "-bis",
                "p_batiment": "armurerie", "p_room": None})
    verifier("F1 sans session : refuse",
             c in (401, 403, 404) or v.get("ok") is False
             or v.get("code") in ("42501", "42883", "PGRST202"), "HTTP %s %s" % (c, str(v)[:70]))

    # === FAMILLE 2 : PRIX ET PARAMETRES =====================================
    c, v = rpc("commerce_fixer_parametres",
               {"p_acteur": QUIDAM, "p_entreprise": ENT, "p_prix_vente": {"cafe_boisson": 12},
                "p_prix_achat_matiere": {}, "p_stock_max": {}}, jeton=tq)
    verifier("F2 fixer un prix sans etre proprietaire : refuse",
             v.get("ok") is False and v.get("raison") == "reserve_proprietaire", str(v)[:90])

    c, v = rpc("commerce_fixer_parametres",
               {"p_acteur": PROPRIO, "p_entreprise": ENT, "p_prix_vente": {"cafe_boisson": 12},
                "p_prix_achat_matiere": {}, "p_stock_max": {}}, jeton=tq)
    verifier("F2 usurpation d'acteur : refusee",
             v.get("code") == "42501" or v.get("ok") is False, str(v)[:90])

    c, v = rpc("commerce_fixer_parametres",
               {"p_acteur": PROPRIO, "p_entreprise": ENT, "p_prix_vente": {"cafe_boisson": 99999},
                "p_prix_achat_matiere": {}, "p_stock_max": {}}, jeton=tp)
    verifier("F2 prix de vente hors fourchette : refuse",
             v.get("ok") is False and v.get("raison") == "prix_hors_fourchette", str(v)[:110])
    borne_min, borne_max = v.get("min"), v.get("max")

    c, v = rpc("commerce_fixer_parametres",
               {"p_acteur": PROPRIO, "p_entreprise": ENT, "p_prix_vente": {"boeuf_bourguignon": 20},
                "p_prix_achat_matiere": {}, "p_stock_max": {}}, jeton=tp)
    verifier("F2 recette hors carte : refusee",
             v.get("ok") is False and v.get("raison") == "hors_carte", str(v)[:90])

    c, v = rpc("commerce_fixer_parametres",
               {"p_acteur": PROPRIO, "p_entreprise": ENT, "p_prix_vente": {},
                "p_prix_achat_matiere": {}, "p_stock_max": {"cafe_boisson": 999}}, jeton=tp)
    verifier("F2 relever le plafond de stock d'un commerce : refuse",
             v.get("ok") is False and v.get("raison") == "stock_max_non_modifiable", str(v)[:90])

    if borne_max is not None:
        c, v = rpc("commerce_fixer_parametres",
                   {"p_acteur": PROPRIO, "p_entreprise": ENT,
                    "p_prix_vente": {"cafe_boisson": float(borne_max)},
                    "p_prix_achat_matiere": {}, "p_stock_max": {}}, jeton=tp)
        verifier("F2 prix au maximum de la fourchette : accepte", v.get("ok") is True, str(v)[:90])
        e = entreprise()
        verifier("F2 le prix est bien celui arrete par le serveur",
                 float((e.get("parametres") or {}).get("prixVente", {}).get("cafe_boisson", 0))
                 == float(borne_max),
                 (e.get("parametres") or {}).get("prixVente"))
        verifier("F2 la caisse et le stock n'ont pas bouge",
                 e.get("caisse") == depart.get("caisse")
                 and e.get("stockMatieres") == depart.get("stockMatieres"),
                 "caisse %s -> %s" % (depart.get("caisse"), e.get("caisse")))

    c, v = rpc("commerce_fixer_parametres",
               {"p_acteur": PROPRIO, "p_entreprise": ENT, "p_prix_vente": {},
                "p_prix_achat_matiere": {"metal": 5}, "p_stock_max": {}}, jeton=tp)
    verifier("F2 matiere absente de la carte : refusee",
             v.get("ok") is False and v.get("raison") == "matiere_non_acceptee", str(v)[:90])

    c, v = rpc("commerce_fixer_parametres",
               {"p_acteur": PROPRIO, "p_entreprise": ENT, "p_prix_vente": {},
                "p_prix_achat_matiere": {"produits_exotiques": 9999}, "p_stock_max": {}}, jeton=tp)
    verifier("F2 prix d'achat de matiere hors fourchette : refuse",
             v.get("ok") is False and v.get("raison") == "prix_hors_fourchette", str(v)[:110])

    # === FAMILLE 3 : LE COMMERCE ACHETE UNE MATIERE =========================
    avant_e, avant_p = entreprise(), perso(QUIDAM, tq)

    c, v = rpc("commerce_acheter_matiere",
               {"p_acteur": QUIDAM, "p_entreprise": ENT, "p_matiere": "metal", "p_qte": 1}, jeton=tq)
    verifier("F3 matiere non acceptee par la carte : refusee",
             v.get("ok") is False and v.get("raison") == "matiere_non_acceptee", str(v)[:90])

    c, v = rpc("commerce_acheter_matiere",
               {"p_acteur": QUIDAM, "p_entreprise": ENT, "p_matiere": "produits_exotiques", "p_qte": 9999},
               jeton=tq)
    verifier("F3 quantite non detenue : refusee",
             v.get("ok") is False and v.get("raison") in ("stock_personnel_insuffisant", "stock_plein"),
             str(v)[:90])

    c, v = rpc("commerce_acheter_matiere",
               {"p_acteur": PROPRIO, "p_entreprise": ENT, "p_matiere": "produits_exotiques", "p_qte": 1},
               jeton=tq)
    verifier("F3 vendre au nom d'un autre joueur : refuse",
             v.get("code") == "42501" or v.get("ok") is False, str(v)[:90])

    verifier("F3 apres les refus : entreprise et joueur intacts",
             entreprise() == avant_e and perso(QUIDAM, tq).get("arg") == avant_p.get("arg"), "ok")

    c, v = rpc("commerce_acheter_matiere",
               {"p_acteur": QUIDAM, "p_entreprise": ENT, "p_matiere": "produits_exotiques", "p_qte": 4},
               jeton=tq)
    verifier("F3 vente legitime : acceptee", v.get("ok") is True, str(v)[:110])
    if v.get("ok") is True:
        total, pu = v.get("total"), v.get("prixUnitaire")
        e, pj = entreprise(), perso(QUIDAM, tq)
        # Regle reelle (prixAchatMatiereCommerce) : le prix MANUEL du commerce s'il existe,
        # sinon le tarif fournisseur du miroir ressources_economie -- jamais le cout moyen,
        # et jamais une valeur transmise par le navigateur.
        manuel = (avant_e.get("parametres") or {}).get("prixAchatMatiere", {}).get("produits_exotiques")
        c2, r2 = http("GET", "/rest/v1/ressources_economie?select=prix_achat_fournisseur"
                             "&cle=eq.produits_exotiques")
        tarif = (r2[0]["prix_achat_fournisseur"] if r2 else None)
        attendu = manuel if manuel is not None else tarif
        verifier("F3 le prix vient du commerce ou du miroir, pas du navigateur",
                 attendu is not None and float(pu) == float(attendu),
                 "prixUnitaire=%s attendu=%s (manuel=%s tarif=%s)" % (pu, attendu, manuel, tarif))
        verifier("F3 stock du commerce credite de la quantite",
                 (e.get("stockMatieres") or {}).get("produits_exotiques", 0)
                 == (avant_e.get("stockMatieres") or {}).get("produits_exotiques", 0) + 4,
                 e.get("stockMatieres"))
        verifier("F3 caisse du commerce debitee du total exact",
                 float(e.get("caisse")) == float(avant_e.get("caisse")) - float(total),
                 "%s -> %s (total %s)" % (avant_e.get("caisse"), e.get("caisse"), total))
        verifier("F3 le joueur est credite du meme total",
                 float(pj.get("arg")) == float(avant_p.get("arg")) + float(total),
                 "%s -> %s" % (avant_p.get("arg"), pj.get("arg")))
        reste = sum(i.get("qty", 0) for i in (pj.get("inventory") or [])
                    if i.get("stackKey") == "produits_exotiques")
        verifier("F3 l'inventaire du vendeur est reellement ampute", reste == 6, "reste=%s" % reste)
        verifier("F3 le cout moyen pondere est recalcule",
                 (e.get("coutMoyenMatieres") or {}).get("produits_exotiques") is not None,
                 (e.get("coutMoyenMatieres") or {}).get("produits_exotiques"))
        verifier("F3 le journal de caisse est alimente",
                 len(e.get("historique") or []) == len(avant_e.get("historique") or []) + 1,
                 "%d lignes" % len(e.get("historique") or []))

    for x in resultats:
        if not x["ok"]:
            print("  KO   %-62s %s" % (x["nom"], x["detail"]))
    ko = sum(1 for x in resultats if not x["ok"])
    print("\n%d controles, %d en echec." % (len(resultats), ko))
    print("Ligne zztest a supprimer en SQL : armurerie-republic-%s" % VILLE_NEUVE)
    return 1 if ko else 0


if __name__ == "__main__":
    sys.exit(main())
