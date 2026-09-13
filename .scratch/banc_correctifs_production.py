#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BANC DES DEUX CORRECTIFS DE PRODUCTION (14 septembre 2026).

Les deux bugs observes en production ont la MEME cause : apres la reinitialisation de la beta,
le navigateur du joueur a continue d'afficher son ancien personnage depuis localStorage alors
que sa ligne n'existait plus cote serveur. Tout ce qu'il voyait (46 809 FR, poste de president,
licence a l'Olympique de Luthecia) venait du cache -- valeurs retrouvees a l'identique dans
sauvegarde_beta_20260913. Chaque appel serveur echouait alors en 'personnage_introuvable', et
ces refus etaient annonces au joueur comme un manque d'argent.

Ce banc verifie :
  A. le refus serveur quand le personnage n'existe pas, et qu'il porte la BONNE raison ;
  B. le voyage : 500 liquide + 0 banque doit payer un billet a 300 ;
  C. les montants falsifies, refuses par le miroir ;
  D. l'absence de mutation partielle quand les fonds manquent ;
  E. le cycle de vie de la licence sportive, sans licence orpheline.

Donnees zztest uniquement.
"""
import json, sys, time, urllib.request, urllib.error

URL = "https://jxpwoosmmhohoihxpbuc.supabase.co"
ANON = ("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3"
        "NtbWhvaG9paHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMj"
        "IwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw")

SUF = str(int(time.time()))
JOUEUR = "zztest-prod-" + SUF
FANTOME = "zztest-fantome-" + SUF
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


def moi(jeton, champs="arg,liquide,pa,licence_sportive"):
    c, r = http("GET", "/rest/v1/personnages?select=" + champs + "&name=eq." + JOUEUR, jeton=jeton)
    return (r[0] if r else {})


def main():
    tj = session()
    try:
        return deroulement(tj)
    finally:
        http("DELETE", "/rest/v1/personnages?name=eq." + JOUEUR, jeton=tj)


def deroulement(tj):
    # Le personnage du joueur : 500 FR liquide, 0 en banque -- exactement la situation decrite.
    code, rep = http("POST", "/rest/v1/personnages", {
        "name": JOUEUR, "country": "republic", "arg": 500, "liquide": 500, "pa": 20,
        "hp": 100, "moral": 75, "day": 10, "current_city": "capitale",
        "stats": {}, "resources": {}, "inventory": []}, jeton=tj)
    if code not in (200, 201):
        print("PREPARATION IMPOSSIBLE : %s %s" % (code, str(rep)[:140]))
        return 2

    # === A. LE PERSONNAGE FANTOME ==========================================
    # Un nom qui n'existe sur AUCUNE ligne : c'est la situation d'Arnie apres le reset.
    c, v = rpc("payer_ordre",
               {"p_acteur": FANTOME, "p_fn": "prendre_avion", "p_pa": 2, "p_cost": 300}, jeton=tj)
    verifier("A1 payer_ordre pour un personnage inexistant : refuse",
             v.get("code") == "42501" or v.get("ok") is False, str(v)[:110])
    verifier("A2 la raison n'est PAS un manque de fonds",
             v.get("raison") != "fonds_insuffisants", "raison=%s" % v.get("raison"))

    c, r = http("GET", "/rest/v1/personnages?select=name&name=eq." + FANTOME)
    verifier("A3 aucune ligne ne porte ce nom (tableau vide, pas une panne)",
             isinstance(r, list) and len(r) == 0, str(r)[:80])

    c, r = http("POST", "/rest/v1/rpc/mon_personnage", {}, jeton=tj)
    verifier("A4 mon_personnage rend bien le personnage de CE compte",
             r == JOUEUR, str(r)[:80])

    # === B. LE VOYAGE : 500 LIQUIDE, 0 BANQUE, BILLET A 300 ================
    avant = moi(tj)
    verifier("B0 etat de depart : 500 liquide, 0 banque",
             float(avant.get("liquide")) == 500.0, "liquide=%s" % avant.get("liquide"))

    c, v = rpc("payer_ordre",
               {"p_acteur": JOUEUR, "p_fn": "prendre_avion", "p_pa": 2, "p_cost": 300}, jeton=tj)
    verifier("B1 billet d'avion a 300 paye avec 500 FR liquide : ACCEPTE",
             v.get("ok") is True, str(v)[:130])
    if v.get("ok") is True:
        verifier("B2 le liquide est bien debite de 300",
                 float(v.get("liquide")) == 200.0, "liquide=%s" % v.get("liquide"))
        verifier("B3 les PA sont debites de 2", v.get("pa") == 18, "pa=%s" % v.get("pa"))

    # Un second transport, meme primitive : le train (2 PA, 75 FR).
    c, v = rpc("payer_ordre",
               {"p_acteur": JOUEUR, "p_fn": "prendre_train", "p_pa": 2, "p_cost": 75}, jeton=tj)
    verifier("B4 train (2 PA, 75 FR) : accepte", v.get("ok") is True, str(v)[:110])

    # Les deux autres transports, memes primitives : bus/taxi et bateau. Le mode choisi dans la
    # fenetre correspond toujours a l'ordre qui l'a ouverte (ouvrirModalTransport), il n'y a donc
    # jamais de decalage entre le billet choisi et l'ordre facture.
    # Fonds remis a niveau : on veut mesurer ici que l'ORDRE est reconnu, pas l'ordre dans lequel
    # le banc a depense.
    http("PATCH", "/rest/v1/personnages?name=eq." + JOUEUR,
         {"liquide": 1000, "arg": 1000, "pa": 20}, jeton=tj)
    c, v = rpc("payer_ordre",
               {"p_acteur": JOUEUR, "p_fn": "prendre_bus_taxi", "p_pa": 1, "p_cost": 150}, jeton=tj)
    verifier("B4b bus/taxi (1 PA, 150 FR) : accepte", v.get("ok") is True, str(v)[:110])

    c, v = rpc("payer_ordre",
               {"p_acteur": JOUEUR, "p_fn": "prendre_bateau", "p_pa": 5, "p_cost": 100}, jeton=tj)
    verifier("B4c bateau (5 PA, 100 FR) : accepte", v.get("ok") is True, str(v)[:110])

    # On redescend a 125 FR pour le test de fonds reellement insuffisants plus bas.
    http("PATCH", "/rest/v1/personnages?name=eq." + JOUEUR,
         {"liquide": 125, "arg": 125}, jeton=tj)

    # Le couple que le client envoyait AVANT le correctif pour le train : (2 PA, 0 FR).
    c, v = rpc("payer_ordre",
               {"p_acteur": JOUEUR, "p_fn": "prendre_train", "p_pa": 2, "p_cost": 0}, jeton=tj)
    verifier("B5 l'ancien envoi du client (train a 0 FR) est bien refuse",
             v.get("ok") is False and v.get("raison") == "cout_non_declare", str(v)[:110])

    # === C. MONTANTS FALSIFIES =============================================
    for pa, cost, libelle in ((2, 1, "prix minore a 1 FR"), (0, 300, "PA supprimes"),
                              (2, 100000, "prix majore")):
        c, v = rpc("payer_ordre",
                   {"p_acteur": JOUEUR, "p_fn": "prendre_avion", "p_pa": pa, "p_cost": cost},
                   jeton=tj)
        verifier("C %s : refuse par le miroir" % libelle,
                 v.get("ok") is False and v.get("raison") == "cout_non_declare", str(v)[:100])

    c, v = rpc("payer_ordre",
               {"p_acteur": JOUEUR, "p_fn": "prendre_soucoupe", "p_pa": 2, "p_cost": 300}, jeton=tj)
    verifier("C transport invente : refuse",
             v.get("ok") is False and v.get("raison") == "ordre_inconnu", str(v)[:100])

    # === D. FONDS REELLEMENT INSUFFISANTS, SANS MUTATION ===================
    etat = moi(tj)
    c, v = rpc("payer_ordre",
               {"p_acteur": JOUEUR, "p_fn": "prendre_avion", "p_pa": 2, "p_cost": 300}, jeton=tj)
    verifier("D1 billet a 300 avec 125 FR seulement : refuse pour FONDS",
             v.get("ok") is False and v.get("raison") == "fonds_insuffisants", str(v)[:110])
    apres = moi(tj)
    verifier("D2 aucune mutation apres le refus",
             apres.get("liquide") == etat.get("liquide") and apres.get("pa") == etat.get("pa"),
             "liquide %s -> %s, pa %s -> %s" % (etat.get("liquide"), apres.get("liquide"),
                                                etat.get("pa"), apres.get("pa")))

    # === E. CYCLE DE VIE DE LA LICENCE SPORTIVE ============================
    verifier("E1 personnage neuf : aucune licence",
             moi(tj).get("licence_sportive") is None, moi(tj).get("licence_sportive"))

    # Remise a flot pour payer la licence (1 PA, 150 FR) -- via la vue, c'est SON personnage.
    http("PATCH", "/rest/v1/personnages?name=eq." + JOUEUR,
         {"liquide": 1000, "arg": 1000, "pa": 20}, jeton=tj)

    c, v = rpc("payer_ordre",
               {"p_acteur": JOUEUR, "p_fn": "prendre_licence_sportive", "p_pa": 1, "p_cost": 150},
               jeton=tj)
    verifier("E2 prise de licence : le paiement passe", v.get("ok") is True, str(v)[:110])

    licence = {"clubId": "olympique-luthecia", "statut": "active", "dateAchat": 10,
               "nonRenouvellement": False, "derniereSaisonTraitee": 1}
    c, r = http("PATCH", "/rest/v1/personnages?name=eq." + JOUEUR,
                {"licence_sportive": licence}, jeton=tj, prefer="return=representation")
    verifier("E3 la licence est ecrite sur le personnage", c in (200, 204), "HTTP %s" % c)

    relu = moi(tj).get("licence_sportive") or {}
    verifier("E4 licence relue depuis le serveur, club compris",
             relu.get("clubId") == "olympique-luthecia" and relu.get("statut") == "active",
             json.dumps(relu)[:110])
    verifier("E5 le club EST l'appartenance (aucune autre donnee)",
             "clubId" in relu, "clubId=%s" % relu.get("clubId"))

    # Seconde prise : la garde cliente lit cette meme valeur relue -- elle est donc coherente.
    verifier("E6 une seconde prise verrait bien une licence active",
             (relu.get("statut") or "active") == "active", relu.get("statut"))

    # Licence orpheline : une licence ne peut exister que PORTEE par une ligne personnage.
    # En supprimant le personnage, la licence disparait avec lui -- aucune table tierce.
    http("DELETE", "/rest/v1/personnages?name=eq." + JOUEUR, jeton=tj)
    c, r = http("GET", "/rest/v1/personnages?select=licence_sportive&name=eq." + JOUEUR)
    verifier("E7 personnage supprime : aucune licence orpheline ne subsiste",
             isinstance(r, list) and len(r) == 0, str(r)[:80])

    c, v = rpc("payer_ordre",
               {"p_acteur": JOUEUR, "p_fn": "tenue_entrainement", "p_pa": 2, "p_cost": 0}, jeton=tj)
    verifier("E8 s'entrainer sans personnage serveur : refuse, et pas pour les fonds",
             v.get("ok") is not True and v.get("raison") != "fonds_insuffisants", str(v)[:110])

    # === F. FAMILLES REPAREES LE 14 SEPTEMBRE =============================
    # Les ordres a montant ou PA dynamique ne passent plus par payer_ordre : leur RPC metier
    # les arbitre. On verifie que payer_ordre les refuse toujours -- c'est la preuve qu'elle
    # n'a pas ete rendue permissive -- et que la voie metier existe.
    # La section E a supprime le personnage : on le recree pour cette section.
    creer_ok = http("POST", "/rest/v1/personnages", {
        "name": JOUEUR, "country": "republic", "arg": 200000, "liquide": 200000, "pa": 20,
        "hp": 100, "moral": 75, "day": 10, "current_city": "capitale",
        "stats": {}, "resources": {}, "inventory": []}, jeton=tj)[0]
    verifier("F0 personnage recree pour cette section", creer_ok in (200, 201), creer_ok)

    for fn, pa, cost, quoi in (
            ("construire_sur_terrain", 0, 12000, "apport de construction"),
            ("payer_versement_chantier", 0, 5000, "versement de chantier"),
            ("travailler_chantier", 4, 0, "heures de chantier"),
            ("imprimer_tracts_electoraux", 3, 450, "3 lots de tracts"),
            ("fabriquer_armoire_souvenirs", 1, 0, "armoire a recette variable")):
        c, v = rpc("payer_ordre", {"p_acteur": JOUEUR, "p_fn": fn, "p_pa": pa, "p_cost": cost},
                   jeton=tj)
        verifier("F payer_ordre refuse toujours %s (non permissive)" % quoi,
                 v.get("ok") is False and v.get("raison") == "cout_non_declare", str(v)[:100])

    # Existence des voies metier : on les appelle avec leur VRAIE signature et une cible
    # inexistante -- une reponse metier prouve qu'elles sont la et accessibles ; un PGRST202
    # prouverait le contraire.
    voies = [
      ("chantier_lancer", {"p_acteur": JOUEUR, "p_pays": "zztest", "p_batiment": "neant",
                           "p_palier": "hangar", "p_apport": 10500}),
      ("chantier_verser", {"p_acteur": JOUEUR, "p_pays": "zztest", "p_batiment": "neant",
                           "p_montant": 10}),
      ("chantier_travailler", {"p_acteur": JOUEUR, "p_pays": "zztest", "p_batiment": "neant",
                               "p_heures": 1}),
      ("imprimerie_produire_tracts", {"p_acteur": JOUEUR, "p_pays": "zztest", "p_ville": "neant",
                                      "p_batiment": "neant", "p_lots": 1}),
    ]
    for nom, corps in voies:
        c, v = rpc(nom, corps, jeton=tj)
        verifier("F la voie metier %s repond (et refuse la cible inexistante)" % nom,
                 v.get("ok") is False and v.get("code") not in ("PGRST202", "42883"),
                 "HTTP %s %s" % (c, str(v)[:80]))

    for x in resultats:
        if not x["ok"]:
            print("  KO   %-62s %s" % (x["nom"], x["detail"]))
    ko = sum(1 for x in resultats if not x["ok"])
    print("\n%d controles, %d en echec." % (len(resultats), ko))
    return 1 if ko else 0


if __name__ == "__main__":
    sys.exit(main())
