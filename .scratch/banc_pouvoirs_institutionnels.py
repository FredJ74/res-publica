#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BANC DES POUVOIRS INSTITUTIONNELS — CHANTIER B (derniere passe).

Verifie que les deux pouvoirs rendus inoperants par la fermeture RLS fonctionnent
de nouveau -- mais UNIQUEMENT pour qui detient reellement le poste :
  * prolongation de peine   -> poste 'juge'      (regle existante : data.js, requiresPost)
  * grace presidentielle    -> poste 'president' (regle existante : exigerPoste)

Quatre acteurs, quatre vraies sessions anonymes Supabase : un juge, un president,
un quidam sans poste, et un detenu. Plus les appels sans aucune session.

Donnees zztest uniquement, nettoyage verifie en sortie.
"""
import json, sys, urllib.request, urllib.error

URL = "https://jxpwoosmmhohoihxpbuc.supabase.co"
ANON = ("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3"
        "NtbWhvaG9paHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMj"
        "IwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw")

JUGE, PRESIDENT, QUIDAM, DETENU = ("zztest-juge", "zztest-president",
                                   "zztest-quidam", "zztest-detenu")
# Id UNIQUE par execution : le registre judiciaire n'a volontairement aucune policy
# DELETE -- une detention ne s'efface pas, meme de test. Reutiliser le meme id ferait
# echouer l'insertion au deuxieme passage et le banc mesurerait la ligne d'hier.
DETENTION = "zztest-det-pouvoirs-" + str(int(__import__("time").time()))
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


def creer(nom, jeton, poste=None):
    corps = {"name": nom, "country": "republic", "arg": 1000, "liquide": 1000,
             "pa": 10, "hp": 100, "moral": 75, "day": 10, "current_city": "capitale",
             "stats": {}, "resources": {"pop": 50}, "inventory": []}
    if poste:
        corps["poste"] = {"id": poste, "name": poste}
    return http("POST", "/rest/v1/personnages", corps, jeton=jeton)


def main():
    tj, tp, tq, td = session(), session(), session(), session()

    for nom, jeton, poste in ((JUGE, tj, "juge"), (PRESIDENT, tp, "president"),
                              (QUIDAM, tq, None), (DETENU, td, None)):
        code, rep = creer(nom, jeton, poste)
        if code not in (200, 201):
            print("PREPARATION IMPOSSIBLE (%s) : %s %s" % (nom, code, str(rep)[:120]))
            return 2

    # Le detenu s'auto-enregistre : c'est ce que fait un flagrant delit.
    http("POST", "/rest/v1/detentions", {
        "id": DETENTION, "country": "republic", "city": "capitale", "nom": DETENU,
        "raison": "zztest", "jour_debut": 10, "jour_fin": 12, "qhs": False,
        "motifs": [{"type": "Vol", "jours": 2}]}, jeton=td)
    http("PATCH", "/rest/v1/personnages?name=eq." + DETENU, {
        "est_emprisonne": {"jours": 2, "jourFin": 12, "raison": "Vol",
                           "detentionId": DETENTION, "debutTs": 1789000000000}}, jeton=td)

    def peine():
        c, r = http("GET", "/rest/v1/detentions?select=jour_fin,motifs,qhs&id=eq." + DETENTION)
        return r[0] if r else {}

    avant = peine()

    # --- PROLONGATION -------------------------------------------------------
    motifs = [{"type": "Recel", "jours": 3, "source": "jugement"}]

    c, r = http("POST", "/rest/v1/rpc/justice_prolonger_peine",
                {"p_cible": DETENU, "p_motifs": motifs, "p_forcer_qhs": False}, jeton=tq)
    verifier("prolongation par un PJ SANS poste : refusee",
             (r or {}).get("code") == "42501", str(r)[:90])

    c, r = http("POST", "/rest/v1/rpc/justice_prolonger_peine",
                {"p_cible": DETENU, "p_motifs": motifs, "p_forcer_qhs": False})
    verifier("prolongation SANS session : refusee",
             c in (401, 403) or (r or {}).get("code") in ("42501", "42883"), "HTTP %s" % c)

    c, r = http("POST", "/rest/v1/rpc/justice_prolonger_peine",
                {"p_cible": DETENU, "p_motifs": motifs, "p_forcer_qhs": False}, jeton=td)
    verifier("le detenu ne prolonge pas sa propre peine",
             (r or {}).get("code") == "42501", str(r)[:90])

    apres_tentatives = peine()
    verifier("peine intacte apres les tentatives illegitimes",
             apres_tentatives.get("jour_fin") == avant.get("jour_fin"),
             "jour_fin %s -> %s" % (avant.get("jour_fin"), apres_tentatives.get("jour_fin")))

    c, r = http("POST", "/rest/v1/rpc/justice_prolonger_peine",
                {"p_cible": DETENU, "p_motifs": motifs, "p_forcer_qhs": True}, jeton=tj)
    v = r[0] if isinstance(r, list) else r
    verifier("prolongation par le JUGE : acceptee", (v or {}).get("ok") is True, str(v)[:110])

    ap = peine()
    verifier("jour_fin augmente de 3", ap.get("jour_fin") == (avant.get("jour_fin") or 0) + 3,
             "%s -> %s" % (avant.get("jour_fin"), ap.get("jour_fin")))
    verifier("motifs concatenes, jamais remplaces", len(ap.get("motifs") or []) == 2,
             "%s motif(s)" % len(ap.get("motifs") or []))
    verifier("bascule QHS appliquee", ap.get("qhs") is True, ap.get("qhs"))

    c, r = http("GET", "/rest/v1/personnages?select=est_emprisonne&name=eq." + DETENU)
    miroir = (r[0]["est_emprisonne"] if r else {}) or {}
    verifier("miroir est_emprisonne du condamne mis a jour",
             miroir.get("jourFin") == (avant.get("jour_fin") or 0) + 3 and miroir.get("qhs") is True,
             json.dumps(miroir)[:110])

    # --- GRACE --------------------------------------------------------------
    c, r = http("POST", "/rest/v1/rpc/presidence_gracier",
                {"p_condamne": DETENU, "p_jour": 15}, jeton=tq)
    verifier("grace par un PJ sans poste : refusee",
             (r or {}).get("code") == "42501", str(r)[:90])

    c, r = http("POST", "/rest/v1/rpc/presidence_gracier",
                {"p_condamne": DETENU, "p_jour": 15}, jeton=tj)
    verifier("grace par le JUGE : refusee (mauvais poste)",
             (r or {}).get("code") == "42501", str(r)[:90])

    c, r = http("POST", "/rest/v1/rpc/presidence_gracier", {"p_condamne": DETENU, "p_jour": 15})
    verifier("grace SANS session : refusee",
             c in (401, 403) or (r or {}).get("code") in ("42501", "42883"), "HTTP %s" % c)

    c, r = http("GET", "/rest/v1/personnages?select=est_emprisonne&name=eq." + DETENU)
    verifier("toujours detenu apres les graces illegitimes",
             bool(r and r[0]["est_emprisonne"]), "ok")

    c, r = http("POST", "/rest/v1/rpc/presidence_gracier",
                {"p_condamne": DETENU, "p_jour": 15}, jeton=tp)
    v = r[0] if isinstance(r, list) else r
    verifier("grace par le PRESIDENT : acceptee",
             (v or {}).get("ok") is True and (v or {}).get("libere") is True, str(v)[:110])

    c, r = http("GET", "/rest/v1/personnages?select=est_emprisonne&name=eq." + DETENU)
    verifier("le condamne est reellement libere",
             bool(r) and r[0]["est_emprisonne"] is None, str(r)[:90])

    fin = peine()
    verifier("registre clos en grace_presidentielle",
             (fin or {}).get("jour_fin") is not None, "mode_fin verifie ci-dessous")
    c, r = http("GET", "/rest/v1/detentions?select=mode_fin,jour_fin_effective&id=eq." + DETENTION)
    verifier("mode_fin = grace_presidentielle",
             bool(r) and r[0]["mode_fin"] == "grace_presidentielle", str(r)[:90])

    # --- POPULARITE : acteur desormais obligatoire ---------------------------
    c, r = http("POST", "/rest/v1/rpc/personnage_ajuster_pop_inf",
                {"p_acteur": JUGE, "p_cible": QUIDAM, "p_pop": -5, "p_inf": None}, jeton=tq)
    verifier("ajuster la POP en se faisant passer pour un autre : refuse",
             (r or {}).get("code") == "42501", str(r)[:90])

    c, r = http("POST", "/rest/v1/rpc/personnage_ajuster_pop_inf",
                {"p_cible": QUIDAM, "p_pop": -50, "p_inf": None})
    verifier("ancienne signature sans acteur : fermee",
             c in (401, 403, 404) or (r or {}).get("code") in ("42501", "42883", "PGRST202"),
             "HTTP %s %s" % (c, str(r)[:70]))

    c, r = http("POST", "/rest/v1/rpc/personnage_ajuster_pop_inf",
                {"p_acteur": QUIDAM, "p_cible": DETENU, "p_pop": -5, "p_inf": None}, jeton=tq)
    v = r[0] if isinstance(r, list) else r
    verifier("ajuster la POP en son propre nom : accepte", (v or {}).get("ok") is True, str(v)[:90])

    # --- Nettoyage ----------------------------------------------------------
    for nom, jeton in ((JUGE, tj), (PRESIDENT, tp), (QUIDAM, tq), (DETENU, td)):
        http("DELETE", "/rest/v1/personnages?name=eq." + nom, jeton=jeton)
    reste = []
    for nom in (JUGE, PRESIDENT, QUIDAM, DETENU):
        c, r = http("GET", "/rest/v1/personnages?select=name&name=eq." + nom)
        if r:
            reste.append(nom)

    for x in resultats:
        if not x["ok"]:
            print("  KO   %-58s %s" % (x["nom"], x["detail"]))
    ko = sum(1 for x in resultats if not x["ok"])
    print("\n%d controles, %d en echec." % (len(resultats), ko))
    if reste:
        print("RESIDU : %s" % reste)
    else:
        print("Nettoyage verifie (la ligne de detention zztest reste par conception :"
              " un registre judiciaire n'a pas de policy DELETE).")
    return 1 if ko else 0


if __name__ == "__main__":
    sys.exit(main())
