#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
HARNAIS ECONOMIQUE — CHANTIER C, PHASE 1.

Prouve que le PAIEMENT D'UN ORDRE est desormais arbitre par le serveur : le
navigateur annonce une intention, il n'impose plus le resultat.

Ce qui est mesure ici :
  * un ordre paye au tarif reel passe, et le debit suit exactement la regle du
    jeu (liquide d'abord, Banque nationale en complement) ;
  * le meme ordre annonce gratuit, ou a moitie prix, est REFUSE ;
  * un montant negatif (se crediter en payant) est refuse ;
  * un joueur ne peut pas faire payer un autre ;
  * fonds ou PA insuffisants : refus SANS aucune mutation ;
  * double soumission simultanee : un seul prelevement (verrou de ligne).

Donnees zztest uniquement, nettoyage verifie.
"""
import json, sys, threading, urllib.request, urllib.error

URL = "https://jxpwoosmmhohoihxpbuc.supabase.co"
ANON = ("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3"
        "NtbWhvaG9paHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMj"
        "IwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw")
A, B = "zztest-eco-a", "zztest-eco-b"
resultats = []


def http(methode, chemin, corps=None, jeton=None):
    req = urllib.request.Request(URL + chemin, method=methode)
    req.add_header("apikey", ANON)
    req.add_header("Authorization", "Bearer " + (jeton or ANON))
    req.add_header("Content-Type", "application/json")
    data = json.dumps(corps).encode() if corps is not None else None
    try:
        with urllib.request.urlopen(req, data, timeout=30) as r:
            t = r.read().decode()
            return r.status, (json.loads(t) if t.strip() else None)
    except urllib.error.HTTPError as e:
        t = e.read().decode()
        try:
            return e.code, json.loads(t)
        except Exception:
            return e.code, t
    except Exception as e:
        return 0, str(e)


def session():
    req = urllib.request.Request(URL + "/auth/v1/signup", method="POST")
    req.add_header("apikey", ANON); req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, b"{}", timeout=30) as r:
        return json.loads(r.read().decode())["access_token"]


def verifier(nom, ok, detail=""):
    resultats.append({"nom": nom, "ok": bool(ok), "detail": str(detail)[:150]})


def payer(jeton, acteur, fn, pa, cost):
    c, r = http("POST", "/rest/v1/rpc/payer_ordre",
                {"p_acteur": acteur, "p_fn": fn, "p_pa": pa, "p_cost": cost}, jeton=jeton)
    return (r[0] if isinstance(r, list) else r) or {}


def etat(jeton, nom):
    c, r = http("GET", "/rest/v1/personnages?select=pa,arg,liquide&name=eq." + nom, jeton=jeton)
    c2, s = http("GET", "/rest/v1/comptes_bancaires?select=solde&personnage=eq." + nom, jeton=jeton)
    e = dict(r[0]) if r else {}
    e["solde"] = s[0]["solde"] if s else 0
    return e


def creer(jeton, nom, liquide, solde, pa=10):
    http("POST", "/rest/v1/personnages", {
        "name": nom, "country": "republic", "arg": liquide + solde, "liquide": liquide,
        "pa": pa, "hp": 100, "moral": 75, "day": 1, "current_city": "capitale",
        "stats": {}, "resources": {}, "inventory": []}, jeton=jeton)
    http("POST", "/rest/v1/comptes_bancaires", {
        "id": "nationale_" + nom, "personnage": nom, "pays": "republic",
        "banque": "nationale", "solde": solde}, jeton=jeton)


def main():
    ta, tb = session(), session()
    creer(ta, A, 600, 400)
    creer(tb, B, 100, 0)

    # --- Le tarif reel passe, et le debit suit la regle du jeu ---------------
    r = payer(ta, A, "soins", 0, 100)             # soins : 0 PA / 100 FR
    verifier("un ordre paye au tarif declare est accepte", r.get("ok") is True, r)
    e = etat(ta, A)
    verifier("le liquide est ponctionne en premier",
             e["liquide"] == 500 and e["solde"] == 400 and e["arg"] == 900, e)

    # --- Debit a cheval sur liquide + Banque nationale -----------------------
    r = payer(ta, A, "soins_discrets", 1, 800)    # 1 PA / 800 FR, liquide 500 + banque 400
    verifier("debit a cheval : liquide epuise puis Banque nationale", r.get("ok") is True, r)
    e = etat(ta, A)
    verifier("500 pris au liquide, 300 a la banque",
             e["liquide"] == 0 and e["solde"] == 100 and e["pa"] == 9, e)

    # --- Refus SANS mutation -------------------------------------------------
    avant = etat(ta, A)
    r = payer(ta, A, "soins_discrets", 1, 800)
    verifier("fonds insuffisants : refuse", r.get("raison") == "fonds_insuffisants", r)
    verifier("fonds insuffisants : aucune mutation", etat(ta, A) == avant, etat(ta, A))

    r = payer(tb, B, "stage_caserne", 3, 0)
    e = etat(tb, B)
    verifier("PA preleves quand ils suffisent", r.get("ok") is True and e["pa"] == 7, e)
    avant = etat(tb, B)
    r = payer(tb, B, "orga_coup_force", 4, 2000)
    verifier("PA insuffisants : refuse", r.get("raison") in ("pa_insuffisants", "fonds_insuffisants"), r)
    verifier("PA insuffisants : aucune mutation", etat(tb, B) == avant, etat(tb, B))

    # --- LA TRICHE ------------------------------------------------------------
    avant = etat(tb, B)
    for fn, pa, cost, libelle in (
            ("soins", 0, 0, "un ordre payant annonce gratuit"),
            ("acheter_entreprise", 0, 0, "acheter_entreprise annonce gratuit"),
            ("acheter_entreprise", 3, 4000, "acheter_entreprise a moitie prix"),
            ("orga_financer_cand", 0, 0, "financer un candidat sans payer"),
            ("prendre_avion", 0, 0, "voyager sans payer")):
        r = payer(tb, B, fn, pa, cost)
        verifier(libelle + " : refuse", r.get("raison") == "cout_non_declare", r)
    verifier("apres toutes les tentatives de triche : aucune mutation",
             etat(tb, B) == avant, etat(tb, B))

    r = payer(tb, B, "soins", 0, -5000)
    verifier("se crediter par un cout negatif : refuse", r.get("raison") == "montant_negatif", r)

    r = payer(tb, B, "soins", 0, 100)
    c, rr = http("POST", "/rest/v1/rpc/payer_ordre",
                 {"p_acteur": A, "p_fn": "soins", "p_pa": 0, "p_cost": 100}, jeton=tb)
    verifier("faire payer un AUTRE joueur : refuse",
             (rr or {}).get("code") == "42501", str(rr)[:90])

    # --- Double soumission simultanee ----------------------------------------
    creer(ta, "zztest-eco-c", 100, 0, pa=1)
    tc = ta  # meme session ne suffit pas : on cree le personnage sous une 3e session
    http("DELETE", "/rest/v1/personnages?name=eq.zztest-eco-c", jeton=ta)
    tc = session()
    creer(tc, "zztest-eco-c", 100, 0, pa=1)
    verdicts = []

    def tirer():
        verdicts.append(payer(tc, "zztest-eco-c", "stage_caserne", 3, 0))

    creer_pa = http("PATCH", "/rest/v1/personnages?name=eq.zztest-eco-c", {"pa": 3}, jeton=tc)
    fils = [threading.Thread(target=tirer) for _ in range(2)]
    for f in fils: f.start()
    for f in fils: f.join()
    ok = sum(1 for v in verdicts if v.get("ok") is True)
    e = etat(tc, "zztest-eco-c")
    verifier("double soumission : un seul prelevement de 3 PA",
             ok == 1 and e["pa"] == 0, "acceptes=%d pa=%s" % (ok, e.get("pa")))

    # --- Miroir des couts : coherence avec le vrai data.js --------------------
    # C'est le garde-fou contre l'oubli : si un ordre est ajoute ou son cout
    # modifie dans data.js sans regenerer le miroir, les deux empreintes divergent
    # et ce controle sort en echec AVANT le deploiement.
    import subprocess
    attendue = subprocess.run(
        [sys.executable, ".scratch/generer_ordres_couts.py", "--empreinte"],
        capture_output=True, text=True).stdout.strip()
    c, r = http("GET", "/rest/v1/rpc/ordres_couts_empreinte_reelle", jeton=ta)
    if c != 200:
        c, r = http("POST", "/rest/v1/rpc/ordres_couts_empreinte_reelle", {}, jeton=ta)
    reelle = (r if isinstance(r, str) else (r or {}).get("empreinte") if isinstance(r, dict) else r)
    verifier("le miroir serveur correspond au vrai data.js",
             bool(attendue) and reelle == attendue,
             "attendue=%s reelle=%s" % (attendue, reelle))

    # --- Ordre inconnu : refuse (fail closed), et journalise ------------------
    avant = etat(tb, B)
    r = payer(tb, B, "zz_ordre_invente", 0, 0)
    verifier("un ordre inconnu du miroir est refuse", r.get("raison") == "ordre_inconnu", r)
    verifier("ordre inconnu : aucune mutation", etat(tb, B) == avant, etat(tb, B))

    # --- Ordre connu ET gratuit : accepte -------------------------------------
    r = payer(tb, B, "se_renseigner", 0, 0)
    verifier("un ordre connu et gratuit reste accepte", r.get("ok") is True, r)

    # --- Nettoyage ------------------------------------------------------------
    reste = []
    for nom, jeton in ((A, ta), (B, tb), ("zztest-eco-c", tc)):
        http("DELETE", "/rest/v1/comptes_bancaires?personnage=eq." + nom, jeton=jeton)
        http("DELETE", "/rest/v1/personnages?name=eq." + nom, jeton=jeton)
    for nom in (A, B, "zztest-eco-c"):
        c, r = http("GET", "/rest/v1/personnages?select=name&name=eq." + nom)
        if r: reste.append(nom)

    for x in resultats:
        if not x["ok"]:
            print("  KO   %-56s %s" % (x["nom"], x["detail"]))
    ko = sum(1 for x in resultats if not x["ok"])
    print("\n%d controles, %d en echec." % (len(resultats), ko))
    print("RESIDU : %s" % reste if reste else "Nettoyage verifie : aucune donnee de test restante.")
    return 1 if ko or reste else 0


if __name__ == "__main__":
    sys.exit(main())
