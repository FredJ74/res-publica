#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BANC DU PARCOURS DE CREATION D'UN PERSONNAGE (14 septembre 2026).

Bug de production : apres la reinitialisation, la creation d'un personnage repondait
« Ce nom est deja porte » -- pour N'IMPORTE QUEL nom, et alors que la base ne contenait
aucun personnage.

Cause reproduite ici : PostgREST rend HTTP 409 pour TROIS violations differentes sur cette
insertion, et le client les confondait toutes avec un nom deja pris :
  * 23505 / personnages_name_key       -> le nom est reellement porte ;
  * 23505 / personnages_user_id_unique -> ce COMPTE a deja un personnage ;
  * 23503 / personnages_user_id_fkey   -> le compte n'existe plus (jeton encore valide dans le
    temps, mais compte supprime cote base). C'est le cas reel : aucun nom ne peut passer.

Ce banc verifie le parcours complet d'un vrai nouveau joueur, puis chacun des trois conflits.
Le troisieme exige de supprimer un compte auth : il n'est joue que si l'operateur fournit un
jeton dont le compte a ete supprime (voir --jeton-perime), sinon il est signale comme non joue.

Donnees zztest uniquement.
"""
import json, sys, time, urllib.request, urllib.error

URL = "https://jxpwoosmmhohoihxpbuc.supabase.co"
ANON = ("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3"
        "NtbWhvaG9paHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMj"
        "IwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw")

SUF = str(int(time.time()))
resultats = []
a_supprimer = []


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
        return json.loads(r.read().decode())


def verifier(nom, ok, detail=""):
    resultats.append({"nom": nom, "ok": bool(ok), "detail": str(detail)[:150]})


def corps_personnage(nom):
    return {"name": nom, "country": "republic", "arg": 2000, "liquide": 300, "pa": 10,
            "hp": 100, "moral": 75, "day": 1, "current_city": "capitale",
            "stats": {}, "resources": {}, "inventory": []}


def raison(code_http, rep):
    """Reproduit exactement le classement fait par sbCreerPersonnageUnique."""
    if code_http in (200, 201):
        return "ok"
    code = rep.get("code") if isinstance(rep, dict) else None
    detail = ""
    if isinstance(rep, dict):
        detail = (rep.get("message") or "") + " " + (rep.get("details") or "")
    if code == "23503" and "personnages_user_id_fkey" in detail:
        return "session_perimee"
    if code == "23505" and "personnages_user_id_unique" in detail:
        return "compte_a_deja_un_personnage"
    if code == "23505" and "personnages_name_key" in detail:
        return "nom_deja_pris"
    if code == "23505":
        return "conflit_inconnu"
    return "erreur_serveur"


def main():
    jeton_perime = None
    for a in sys.argv[1:]:
        if a.startswith("--jeton-perime="):
            jeton_perime = a.split("=", 1)[1]

    # === 1. PARCOURS COMPLET D'UN VRAI NOUVEAU JOUEUR ======================
    s1 = session()
    t1, uid1 = s1["access_token"], s1["user"]["id"]
    verifier("1a session anonyme ouverte", bool(t1) and bool(uid1), uid1)

    nom1 = "zztest-neuf-" + SUF
    a_supprimer.append((nom1, t1))
    c, r = http("POST", "/rest/v1/personnages", corps_personnage(nom1), jeton=t1,
                prefer="return=representation")
    verifier("1b creation du personnage : acceptee", c in (200, 201),
             "HTTP %s %s" % (c, str(r)[:90]))

    c, r = http("POST", "/rest/v1/rpc/mon_personnage", {}, jeton=t1)
    verifier("1c le personnage est rattache a CE compte", r == nom1, str(r)[:80])

    c, r = http("GET", "/rest/v1/personnages?select=name,arg,liquide&name=eq." + nom1, jeton=t1)
    ligne = (r[0] if r else {})
    verifier("1d le personnage se recharge, colonnes privees comprises",
             ligne.get("name") == nom1 and ligne.get("arg") == 2000
             and ligne.get("liquide") == 300, json.dumps(ligne)[:100])

    c, v = http("POST", "/rest/v1/rpc/payer_ordre",
                {"p_acteur": nom1, "p_fn": "prendre_train", "p_pa": 2, "p_cost": 75}, jeton=t1)
    vv = v[0] if isinstance(v, list) else v
    verifier("1e il peut agir immediatement (un ordre reel passe)",
             isinstance(vv, dict) and vv.get("ok") is True, str(vv)[:100])

    # === 2. UN VRAI HOMONYME RESTE REFUSE ==================================
    s2 = session()
    t2 = s2["access_token"]
    c, r = http("POST", "/rest/v1/personnages", corps_personnage(nom1), jeton=t2)
    verifier("2a un homonyme reel : refuse", c == 409, "HTTP %s" % c)
    verifier("2b et classe comme 'nom_deja_pris'", raison(c, r) == "nom_deja_pris",
             raison(c, r) + " | " + str(r)[:90])

    # === 3. UN COMPTE NE PEUT AVOIR QU'UN PERSONNAGE =======================
    nom3 = "zztest-second-" + SUF
    c, r = http("POST", "/rest/v1/personnages", corps_personnage(nom3), jeton=t1)
    verifier("3a second personnage sur le MEME compte : refuse", c == 409, "HTTP %s" % c)
    verifier("3b et classe comme 'compte_a_deja_un_personnage' (PAS comme un nom pris)",
             raison(c, r) == "compte_a_deja_un_personnage", raison(c, r) + " | " + str(r)[:90])
    c, r = http("GET", "/rest/v1/personnages?select=name&name=eq." + nom3)
    verifier("3c aucune ligne parasite n'a ete creee",
             isinstance(r, list) and len(r) == 0, str(r)[:60])

    # === 4. LE CAS REEL : COMPTE SUPPRIME, JETON ENCORE VALIDE =============
    if jeton_perime:
        nom4 = "zztest-perime-" + SUF
        c, r = http("POST", "/rest/v1/personnages", corps_personnage(nom4), jeton=jeton_perime)
        verifier("4a creation avec un jeton dont le compte a disparu : refusee",
                 c == 409, "HTTP %s" % c)
        verifier("4b classee 'session_perimee', et surtout PAS 'nom_deja_pris'",
                 raison(c, r) == "session_perimee", raison(c, r) + " | " + str(r)[:100])
        nom4b = nom4 + "-autre"
        c, r = http("POST", "/rest/v1/personnages", corps_personnage(nom4b), jeton=jeton_perime)
        verifier("4c changer de nom ne change rien (c'est bien le compte, pas le nom)",
                 raison(c, r) == "session_perimee", raison(c, r))
        # Ce que fait desormais le client : rouvrir une session et rejouer une fois.
        s5 = session()
        t5 = s5["access_token"]
        a_supprimer.append((nom4, t5))
        c, r = http("POST", "/rest/v1/personnages", corps_personnage(nom4), jeton=t5,
                    prefer="return=representation")
        verifier("4d apres reouverture de session, la creation aboutit", c in (200, 201),
                 "HTTP %s %s" % (c, str(r)[:80]))
    else:
        verifier("4 cas du compte supprime : NON JOUE (fournir --jeton-perime=...)", True,
                 "test ignore volontairement")

    # === 5. UNE BASE SANS PERSONNAGE PERMET LA CREATION ====================
    # Deja prouve par 1b : la seule condition est un compte sans personnage.
    verifier("5 une base sans homonyme et un compte neuf suffisent a creer",
             any(x["nom"].startswith("1b") and x["ok"] for x in resultats), "voir 1b")

    for nom, jeton in a_supprimer:
        http("DELETE", "/rest/v1/personnages?name=eq." + nom, jeton=jeton)

    for x in resultats:
        if not x["ok"]:
            print("  KO   %-64s %s" % (x["nom"], x["detail"]))
    ko = sum(1 for x in resultats if not x["ok"])
    print("\n%d controles, %d en echec." % (len(resultats), ko))
    return 1 if ko else 0


if __name__ == "__main__":
    sys.exit(main())
