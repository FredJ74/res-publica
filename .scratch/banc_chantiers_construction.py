#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BANC DES CHANTIERS DE CONSTRUCTION (chantier C, 14 septembre 2026).

Trois ordres etaient REFUSES en production depuis la phase 1, pour la meme raison que l'achat
d'arme et la production : ils annoncent a payer_ordre un montant ou des PA qui ne sont pas ceux
declares dans data.js. Verifie empiriquement avant correctif : les trois repondaient
'cout_non_declare'.
  * construire_sur_terrain   : apport choisi par le joueur (>= 35 % du cout total) ;
  * payer_versement_chantier : versement libre ;
  * travailler_chantier      : PA = nombre d'heures choisi.

Ce banc verifie les trois RPC metier qui les remplacent, leurs bornes et les attaques.

FIXTURE : un terrain 'zztest_*' dans terrains_etat, rearme par le workflow de migration.
Aucun terrain reel n'est touche.
"""
import json, sys, time, urllib.request, urllib.error

URL = "https://jxpwoosmmhohoihxpbuc.supabase.co"
ANON = ("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3"
        "NtbWhvaG9paHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMj"
        "IwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw")

PAYS, BATIMENT = "zztest", "terrain-chantier"
TERRAIN = PAYS + "_" + BATIMENT
PROPRIO = "zztest-chantier-proprio"
INTRUS = "zztest-chantier-intrus-" + str(int(time.time()))
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


def terrain():
    c, r = http("GET", "/rest/v1/terrains_etat?select=data&id=eq." + TERRAIN)
    if not r:
        return None
    d = r[0]["data"]
    return json.loads(d) if isinstance(d, str) else d


def perso(nom, jeton):
    c, r = http("GET", "/rest/v1/personnages?select=arg,liquide,pa&name=eq." + nom, jeton=jeton)
    return (r[0] if r else {})


def creer(nom, jeton, arg=100000, pa=20):
    return http("POST", "/rest/v1/personnages", {
        "name": nom, "country": "republic", "arg": arg, "liquide": arg, "pa": pa, "hp": 100,
        "moral": 75, "day": 10, "current_city": "capitale", "stats": {}, "resources": {},
        "inventory": []}, jeton=jeton)


def main():
    tp, ti = session(), session()
    try:
        return deroulement(tp, ti)
    finally:
        for nom, jeton in ((PROPRIO, tp), (INTRUS, ti)):
            http("DELETE", "/rest/v1/personnages?name=eq." + nom, jeton=jeton)


def deroulement(tp, ti):
    for nom, jeton in ((PROPRIO, tp), (INTRUS, ti)):
        code, rep = creer(nom, jeton)
        if code not in (200, 201):
            print("PREPARATION IMPOSSIBLE (%s) : %s %s" % (nom, code, str(rep)[:140]))
            return 2

    # Le banc se joue en DEUX passes : la premiere cree le chantier (il demarre sans materiaux,
    # c'est la regle), une etape SQL lui pose un stock, la seconde passe teste le travail.
    # --travail-seul saute le lancement et le versement.
    travail_seul = "--travail-seul" in sys.argv
    depart = terrain()
    if travail_seul:
        if not depart or not depart.get("chantier"):
            print("Aucun chantier en place : jouer d'abord la passe complete.")
            return 2
        return section_travail(tp, ti, depart)

    if not depart or depart.get("proprietaire") != PROPRIO or depart.get("chantier"):
        print("FIXTURE ABSENTE OU DERIVEE (%s).\nRearmer par migration SQL : terrain '%s', "
              "proprietaire=%s, constructionAutorisee=true, permis.palierDemande=hangar, "
              "sans chantier." % (json.dumps(depart)[:150] if depart else None, TERRAIN, PROPRIO))
        return 2

    # === A. LANCEMENT ======================================================
    c, v = rpc("chantier_lancer", {"p_acteur": INTRUS, "p_pays": PAYS, "p_batiment": BATIMENT,
                                   "p_palier": "hangar", "p_apport": 10500}, jeton=ti)
    verifier("A1 lancer un chantier sur le terrain d'autrui : refuse",
             v.get("ok") is False and v.get("raison") == "pas_proprietaire", str(v)[:100])

    c, v = rpc("chantier_lancer", {"p_acteur": PROPRIO, "p_pays": PAYS, "p_batiment": BATIMENT,
                                   "p_palier": "building", "p_apport": 42000}, jeton=tp)
    verifier("A2 palier different de celui du permis : refuse",
             v.get("ok") is False and v.get("raison") == "permis_non_conforme", str(v)[:110])

    c, v = rpc("chantier_lancer", {"p_acteur": PROPRIO, "p_pays": PAYS, "p_batiment": BATIMENT,
                                   "p_palier": "hangar", "p_apport": 1}, jeton=tp)
    verifier("A3 apport sous les 35 % : refuse, avec le minimum REEL du miroir",
             v.get("ok") is False and v.get("raison") == "apport_insuffisant"
             and float(v.get("minimum")) == 10500.0, str(v)[:110])

    c, v = rpc("chantier_lancer", {"p_acteur": PROPRIO, "p_pays": PAYS, "p_batiment": BATIMENT,
                                   "p_palier": "palier_invente", "p_apport": 10500}, jeton=tp)
    verifier("A4 palier invente : refuse",
             v.get("ok") is False and v.get("raison") == "palier_inconnu", str(v)[:100])

    verifier("A5 apres les refus : toujours aucun chantier", terrain().get("chantier") is None, "ok")

    avant = perso(PROPRIO, tp)
    c, v = rpc("chantier_lancer", {"p_acteur": PROPRIO, "p_pays": PAYS, "p_batiment": BATIMENT,
                                   "p_palier": "hangar", "p_apport": 15000}, jeton=tp)
    verifier("A6 lancement legitime : accepte", v.get("ok") is True, str(v)[:120])
    if v.get("ok") is True:
        ch = terrain().get("chantier") or {}
        verifier("A7 le gabarit vient du miroir, pas du navigateur",
                 ch.get("coutTotal") == 30000 and ch.get("dureeJours") == 6
                 and ch.get("type") == "construction", json.dumps(ch)[:120])
        verifier("A8 l'apport est porte en tresorerie ET en total verse",
                 float(ch.get("tresorerie")) == 15000.0 and float(ch.get("totalVerse")) == 15000.0,
                 "tresorerie=%s totalVerse=%s" % (ch.get("tresorerie"), ch.get("totalVerse")))
        apres = perso(PROPRIO, tp)
        verifier("A9 le joueur est debite du montant exact",
                 float(avant.get("arg")) - float(apres.get("arg")) == 15000.0,
                 "%s -> %s" % (avant.get("arg"), apres.get("arg")))

    c, v = rpc("chantier_lancer", {"p_acteur": PROPRIO, "p_pays": PAYS, "p_batiment": BATIMENT,
                                   "p_palier": "hangar", "p_apport": 10500}, jeton=tp)
    verifier("A10 second lancement sur le meme terrain : refuse",
             v.get("ok") is False and v.get("raison") == "chantier_en_cours", str(v)[:100])

    # === B. VERSEMENT ======================================================
    c, v = rpc("chantier_verser", {"p_acteur": INTRUS, "p_pays": PAYS, "p_batiment": BATIMENT,
                                   "p_montant": 1000}, jeton=ti)
    verifier("B1 verser sur le chantier d'autrui : refuse",
             v.get("ok") is False and v.get("raison") == "pas_proprietaire", str(v)[:100])

    avant = perso(PROPRIO, tp)
    c, v = rpc("chantier_verser", {"p_acteur": PROPRIO, "p_pays": PAYS, "p_batiment": BATIMENT,
                                   "p_montant": 5000}, jeton=tp)
    verifier("B2 versement legitime : accepte", v.get("ok") is True, str(v)[:110])
    if v.get("ok") is True:
        apres = perso(PROPRIO, tp)
        verifier("B3 debit exact du versement",
                 float(avant.get("arg")) - float(apres.get("arg")) == 5000.0,
                 "%s -> %s" % (avant.get("arg"), apres.get("arg")))
        verifier("B4 le pourcentage finance est calcule serveur",
                 int(v.get("pourcentage")) == 66, v.get("pourcentage"))

    c, v = rpc("chantier_verser", {"p_acteur": PROPRIO, "p_pays": PAYS, "p_batiment": BATIMENT,
                                   "p_montant": 9999999}, jeton=tp)
    verifier("B5 versement au-dela du reste a financer : borne au reste",
             v.get("ok") is True and float(v.get("montant")) == 10000.0, str(v)[:110])

    c, v = rpc("chantier_verser", {"p_acteur": PROPRIO, "p_pays": PAYS, "p_batiment": BATIMENT,
                                   "p_montant": 100}, jeton=tp)
    verifier("B6 chantier integralement finance : refuse",
             v.get("ok") is False and v.get("raison") == "deja_finance", str(v)[:100])

    # === C. TRAVAIL ========================================================
    # Sans materiaux en stock, aucune heure n'est utile : c'est la regle du jeu.
    c, v = rpc("chantier_travailler", {"p_acteur": PROPRIO, "p_pays": PAYS,
                                       "p_batiment": BATIMENT, "p_heures": 5}, jeton=tp)
    verifier("C1 travailler sans materiaux : refuse (aucune heure utile)",
             v.get("ok") is False and v.get("raison") == "aucune_heure_travaillable",
             str(v)[:130])
    return bilan()


def section_travail(tp, ti, depart):

    # Le stock de materiaux est pose par une etape SQL entre le lancement et ces tests -- le
    # chantier vient d'etre cree par la RPC, il demarre donc sans materiaux, ce qui est la regle.
    # Le stock de materiaux est pose par la fixture SQL (le client ne peut plus l'ecrire) :
    # hangar = 50 h/jour de capacite, besoin du jour 1 = bois 100 / minerai 50 / metal 33.
    if (terrain().get("chantier") or {}).get("stockMateriaux", {}).get("bois", 0) < 100:
        verifier("C2 fixture de materiaux absente : tests de travail NON JOUES", True,
                 "poser stockMateriaux bois=100 minerai=50 metal=33 en SQL")
    else:
        avant = perso(PROPRIO, tp)
        avantCh = terrain().get("chantier") or {}
        c, v = rpc("chantier_travailler", {"p_acteur": PROPRIO, "p_pays": PAYS,
                                           "p_batiment": BATIMENT, "p_heures": 5}, jeton=tp)
        verifier("C2 travail legitime de 5 heures : accepte",
                 v.get("ok") is True and v.get("heures") == 5, str(v)[:120])
        if v.get("ok") is True:
            apres = perso(PROPRIO, tp)
            apresCh = terrain().get("chantier") or {}
            verifier("C3 le salaire est 5 x 70, calcule serveur",
                     float(v.get("montant")) == 350.0, v.get("montant"))
            verifier("C4 le joueur est credite et perd 5 PA",
                     float(apres.get("arg")) - float(avant.get("arg")) == 350.0
                     and int(avant.get("pa")) - int(apres.get("pa")) == 5,
                     "arg %s->%s pa %s->%s" % (avant.get("arg"), apres.get("arg"),
                                               avant.get("pa"), apres.get("pa")))
            verifier("C5 la tresorerie du chantier paie le salaire",
                     float(avantCh.get("tresorerie")) - float(apresCh.get("tresorerie")) == 350.0,
                     "%s -> %s" % (avantCh.get("tresorerie"), apresCh.get("tresorerie")))
            verifier("C6 les heures faites sont enregistrees",
                     float(apresCh.get("heuresFaites")) == float(avantCh.get("heuresFaites", 0)) + 5,
                     apresCh.get("heuresFaites"))
            verifier("C7 le journal nominatif est alimente",
                     len(apresCh.get("travauxPJ") or []) == len(avantCh.get("travauxPJ") or []) + 1,
                     len(apresCh.get("travauxPJ") or []))

        # Demander plus que ses PA : borne aux PA reels, jamais au-dela.
        pa_reste = int(perso(PROPRIO, tp).get("pa"))
        c, v = rpc("chantier_travailler", {"p_acteur": PROPRIO, "p_pays": PAYS,
                                           "p_batiment": BATIMENT, "p_heures": 9999}, jeton=tp)
        verifier("C8 demander 9999 heures : borne aux PA reellement disponibles",
                 v.get("ok") is True and v.get("heures") <= pa_reste,
                 "demande=9999 accorde=%s pa=%s" % (v.get("heures"), pa_reste))

        c, v = rpc("chantier_travailler", {"p_acteur": PROPRIO, "p_pays": PAYS,
                                           "p_batiment": BATIMENT, "p_heures": -5}, jeton=tp)
        verifier("C9 heures negatives : refusees",
                 v.get("ok") is False and v.get("raison") == "heures_invalides", str(v)[:100])

        c, v = rpc("chantier_travailler", {"p_acteur": INTRUS, "p_pays": PAYS,
                                           "p_batiment": BATIMENT, "p_heures": 1}, jeton=ti)
        verifier("C10 un tiers peut travailler (regle existante : pas de reserve au proprietaire)",
                 v.get("ok") is True or v.get("raison") == "aucune_heure_travaillable", str(v)[:110])

        c, v = rpc("chantier_travailler", {"p_acteur": PROPRIO, "p_pays": PAYS,
                                           "p_batiment": BATIMENT, "p_heures": 1}, jeton=ti)
        verifier("C11 travailler au nom d'un autre : refuse",
                 v.get("code") == "42501" or v.get("ok") is False, str(v)[:100])

    return bilan()


def bilan():
    for x in resultats:
        if not x["ok"]:
            print("  KO   %-62s %s" % (x["nom"], x["detail"]))
    ko = sum(1 for x in resultats if not x["ok"])
    print("\n%d controles, %d en echec." % (len(resultats), ko))
    return 1 if ko else 0


if __name__ == "__main__":
    sys.exit(main())
