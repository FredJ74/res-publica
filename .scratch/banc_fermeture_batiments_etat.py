#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BANC DE FERMETURE DE batiments_etat — CHANTIER C, PHASE 2, PASSE FINALE.

Avant ce lot, RLS n'etait meme pas activee sur batiments_etat et anon detenait
INSERT/UPDATE/DELETE : n'importe quel navigateur pouvait PATCHer le blob complet d'un
batiment et s'ecrire une caisse, un stock ou un prix. C'est le verrou 5 du harnais Auth/RLS.

Ce banc verifie les quatre proprietes demandees :
  A. plus aucune ecriture directe du blob depuis le navigateur (la lecture reste ouverte) ;
  B. la RPC restante refuse toute sous-cle economique ;
  C. aucune mutation economique ne peut se cacher DANS un des 7 chemins non economiques
     conserves (blocus, effectifsPolice, effectifsDouane, candidatures, parCaisse,
     controles, offres) -- une tentative par chemin ;
  D. l'autorite reelle est verifiee cote serveur, pas le nom transmis ;
  E. les fonctionnalites conservees fonctionnent encore (sinon la fermeture ne vaut rien).

DONNEES : tout ce qui est ECRIT l'est sur des identifiants zztest. Le blob reel du port
est lu au debut et relu a la fin : son CONTENU doit etre identique (jsonb renormalise
l'ordre des cles a chaque ecriture, ce qui est sans effet cote client, qui lit avec JSON.parse).
Les lignes zztest creees sont listees en sortie pour suppression (anon n'a plus de DELETE).
"""
import hashlib, json, sys, time, urllib.request, urllib.error

URL = "https://jxpwoosmmhohoihxpbuc.supabase.co"
ANON = ("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3"
        "NtbWhvaG9paHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMj"
        "IwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw")

SUF = str(int(time.time()))
QUIDAM, COMMIS, DOUANE = "zztest-q-" + SUF, "zztest-cms-" + SUF, "zztest-dou-" + SUF
VILLE_ZZ, BAT_ZZ = "zztest-ville", "zztest-batiment"
ID_PORT = "republic_ville_a_port-sainte-marie"
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
    resultats.append({"nom": nom, "ok": bool(ok), "detail": str(detail)[:130]})


def creer(nom, jeton, poste=None):
    corps = {"name": nom, "country": "republic", "arg": 1000, "liquide": 1000, "pa": 20,
             "hp": 100, "moral": 75, "day": 10, "current_city": "capitale",
             "stats": {}, "resources": {"pop": 50}, "inventory": []}
    if poste:
        corps["poste"] = poste
    return http("POST", "/rest/v1/personnages", corps, jeton=jeton)


def ecrire(jeton, sous_cle, valeur, pays="republic", ville=VILLE_ZZ, bat=BAT_ZZ):
    c, r = http("POST", "/rest/v1/rpc/batiment_etat_sous_cle_ecrire",
                {"p_pays": pays, "p_ville": ville, "p_batiment": bat,
                 "p_sous_cle": sous_cle, "p_valeur": valeur}, jeton=jeton)
    v = r[0] if isinstance(r, list) else r
    return c, (v if isinstance(v, dict) else {"brut": v})


def blob(id_ligne):
    c, r = http("GET", "/rest/v1/batiments_etat?select=data&id=eq." + id_ligne)
    return (r[0]["data"] if r else None)


def empreinte(x):
    """Empreinte du CONTENU, pas des octets : toute ecriture passe desormais par jsonb, qui
    renormalise l'ordre des cles de tout le blob. Le client lit avec JSON.parse, l'ordre lui
    est indifferent -- comparer les octets bruts ferait echouer un test pourtant vert."""
    try:
        v = json.loads(x) if isinstance(x, str) else x
    except Exception:
        v = x
    return hashlib.sha256(json.dumps(v, sort_keys=True,
                                     separators=(",", ":")).encode()).hexdigest()[:16]


def main():
    tq, tc, td = session(), session(), session()
    for nom, jeton, poste in (
            (QUIDAM, tq, None),
            (COMMIS, tc, {"id": "commissaire", "name": "Commissaire", "city": VILLE_ZZ}),
            (DOUANE, td, {"id": "chef_douanes", "name": "Chef des Douanes"})):
        code, rep = creer(nom, jeton, poste)
        if code not in (200, 201):
            print("PREPARATION IMPOSSIBLE (%s) : %s %s" % (nom, code, str(rep)[:140]))
            return 2

    port_avant = blob(ID_PORT)
    if not port_avant:
        print("PREPARATION IMPOSSIBLE : ligne du port introuvable")
        return 2

    # === A. L'ECRITURE DIRECTE DU BLOB EST FERMEE ============================
    c, r = http("PATCH", "/rest/v1/batiments_etat?id=eq." + ID_PORT,
                {"data": json.dumps({"port": {"caisse": 999999}})}, jeton=tq,
                prefer="return=representation")
    verifier("A1 PATCH direct du blob du port : refuse",
             c in (401, 403, 404) or (isinstance(r, dict) and r.get("code") == "42501"),
             "HTTP %s %s" % (c, str(r)[:70]))

    c, r = http("POST", "/rest/v1/batiments_etat",
                {"id": "republic_" + VILLE_ZZ + "_pirate", "country": "republic",
                 "city": VILLE_ZZ, "building_id": "pirate",
                 "data": json.dumps({"entrepot": {"caisse": 10 ** 9}})}, jeton=tq)
    verifier("A2 INSERT direct d'une ligne : refuse",
             c in (401, 403, 404) or (isinstance(r, dict) and r.get("code") == "42501"),
             "HTTP %s %s" % (c, str(r)[:70]))

    c, r = http("DELETE", "/rest/v1/batiments_etat?id=eq." + ID_PORT, jeton=tq)
    verifier("A3 DELETE direct de la ligne du port : refuse",
             c in (401, 403, 404) or (isinstance(r, dict) and r.get("code") == "42501"),
             "HTTP %s %s" % (c, str(r)[:70]))

    verifier("A4 la lecture reste ouverte (81 sites de lecture clients)",
             blob(ID_PORT) is not None, "ok")

    # === B. SOUS-CLES ECONOMIQUES REFUSEES A LA PORTE ========================
    for sc in ("entrepot", "usine", "port", "sante", "imprimerie", "criee", "caisse",
               "stock", "prixManuel", "repartition"):
        c, v = ecrire(tq, sc, {"caisse": 10 ** 9})
        verifier("B sous-cle economique '%s' : refusee" % sc,
                 v.get("ok") is False and v.get("raison") == "sous_cle_non_autorisee",
                 str(v)[:80])

    # === C. UNE ATTAQUE PAR CHEMIN NON ECONOMIQUE CONSERVE ===================
    # Chacune cache une mutation economique DANS une valeur autorisee. Toutes doivent echouer.
    attaques = [
        ("blocus", {"syndicatId": "s1", "intensite": 40, "caisse": 10 ** 9}),
        ("blocus", {"syndicatId": "s1", "intensite": 40,
                    "revendication": {"stockBois": 10 ** 6}}),
        ("effectifsPolice", {"policiers": [{"matricule": "X", "type": "standard",
                                            "caisse": 10 ** 9}]}),
        ("effectifsDouane", {"douaniers": [{"matricule": "X", "stats": {"PER": 12},
                                            "stock": {"ble": 9999}}]}),
        ("candidatures", {"p1": {"posteId": "juge", "city": "capitale",
                                 "prixManuel": {"ble": 1}}}),
        ("parCaisse", {"c1": {"caisse": 10 ** 9}}),
        ("controles", {"c1": {"resultat": "positif", "prix": 10 ** 9}}),
        ("offres", {"o1": [{"pjNom": QUIDAM, "statut": "actif", "salaire": 10 ** 9}]}),
    ]
    for sc, val in attaques:
        # Menees par le CHEF DES DOUANES : le compte le plus dote en autorite parmi les trois,
        # pour qu'aucun refus ne puisse s'expliquer par un simple manque de poste.
        c, v = ecrire(td, sc, val, ville="ville_a", bat="port-sainte-marie") \
            if sc == "effectifsDouane" else ecrire(td, sc, val)
        verifier("C mutation economique cachee dans '%s' : refusee" % sc,
                 v.get("ok") is False, str(v)[:95])

    # Meme chose sur les emplacements REELS partages, ou la sous-cle est legitime.
    for sc, val, ville, bat in (
            ("controles", {"c1": {"resultat": "positif", "caisse": 10 ** 9}},
             "national", "dissimulation-fret"),
            ("parCaisse", {"c1": {"caisse": 1}}, "national", "dissimulation-fret"),
            ("offres", {"o1": [{"pjNom": QUIDAM, "statut": "actif", "prix": 1}]},
             "national", "bne"),
            ("candidatures", {"p1": {"posteId": "juge", "caisse": 1}},
             "national", "candidatures_postes")):
        pays = "global" if bat == "dissimulation-fret" else "republic"
        c, v = ecrire(td, sc, val, pays=pays, ville=ville, bat=bat)
        verifier("C' attaque sur l'emplacement reel '%s' : refusee" % bat,
                 v.get("ok") is False, str(v)[:95])

    # === D. AUTORITE REELLE, PAS LE NOM TRANSMIS =============================
    effectifs_ok = {"policiers": [{"matricule": "POL-zz", "type": "standard",
                                   "stats": {"PER": 12, "VOL": 12}, "buildingId": None,
                                   "roomId": None, "rueNoeudId": None,
                                   "recruteLe": 1789000000000}]}
    c, v = ecrire(tq, "effectifsPolice", effectifs_ok,
                  ville=VILLE_ZZ, bat="commissariat-local")
    verifier("D1 effectifsPolice par un PJ sans poste : refuse",
             v.get("ok") is False and v.get("raison") == "autorite_insuffisante", str(v)[:80])

    c, v = ecrire(tc, "effectifsPolice", effectifs_ok,
                  ville="capitale", bat="commissariat")
    verifier("D2 commissaire ecrivant hors de SA ville : refuse",
             v.get("ok") is False and v.get("raison") == "autorite_insuffisante", str(v)[:80])

    c, v = ecrire(tq, "effectifsDouane", {"douaniers": []},
                  ville="ville_a", bat="port-sainte-marie")
    verifier("D3 effectifsDouane par un PJ sans poste : refuse",
             v.get("ok") is False and v.get("raison") == "autorite_insuffisante", str(v)[:80])

    c, v = ecrire(tq, "controles", {"c1": {"resultat": "positif"}},
                  pays="global", ville="national", bat="dissimulation-fret")
    verifier("D4 controle douanier par un PJ sans poste : refuse",
             v.get("ok") is False and v.get("raison") == "autorite_insuffisante", str(v)[:80])

    c, v = ecrire(None, "blocus", {"syndicatId": "s1", "intensite": 40})
    # Sans session, l'EXECUTE n'est meme pas accorde (convention du chantier B, comme
    # payer_ordre) : PostgREST repond alors 404/PGRST202, pas un refus applicatif.
    verifier("D5 ecriture SANS session : refusee",
             c in (401, 403, 404) or v.get("ok") is False
             or v.get("code") in ("42501", "42883", "PGRST202"),
             "HTTP %s %s" % (c, str(v)[:70]))

    c, r = http("POST", "/rest/v1/rpc/fixer_repartition_port",
                {"p_cle": "ble", "p_capitale": 100, "p_ville_a": 0, "p_ville_b": 0}, jeton=tq)
    verifier("D6 repartition portuaire sans le poste de capitaine : refusee",
             (r or {}).get("code") == "42501", str(r)[:90])

    c, r = http("POST", "/rest/v1/rpc/fixer_repartition_port",
                {"p_cle": "ble", "p_capitale": 90, "p_ville_a": 5, "p_ville_b": 90}, jeton=tq)
    verifier("D7 repartition dont la somme n'est pas 100 : refusee",
             (r or {}).get("code") == "42501" or (isinstance(r, dict) and r.get("ok") is False),
             str(r)[:90])

    # === E. LES FONCTIONNALITES CONSERVEES MARCHENT ENCORE ===================
    c, v = ecrire(tq, "blocus", {"syndicatId": "zz-synd", "syndicatNom": "Syndicat zztest",
                                 "revendication": "test", "nbMilitants": 12, "intensite": 40,
                                 "leaderActuel": COMMIS,  # nom d'autrui : doit etre ignore
                                 "lanceLe": 1789000000000,
                                 "dernierRenouvellementTimestamp": 1789000000000})
    verifier("E1 blocus pose par un joueur : accepte", v.get("ok") is True, str(v)[:80])

    c, r = http("GET", "/rest/v1/batiments_etat?select=data&id=eq.republic_%s_%s"
                % (VILLE_ZZ, BAT_ZZ))
    pose = json.loads(r[0]["data"]) if r else {}
    verifier("E2 le meneur enregistre est l'appelant REEL, pas le nom transmis",
             (pose.get("blocus") or {}).get("leaderActuel") == QUIDAM,
             (pose.get("blocus") or {}).get("leaderActuel"))

    c, v = ecrire(tq, "blocus", None)
    verifier("E3 levee du blocus : acceptee", v.get("ok") is True, str(v)[:80])

    c, v = ecrire(tc, "effectifsPolice", effectifs_ok, ville=VILLE_ZZ, bat="commissariat-local")
    verifier("E4 le commissaire gere SES effectifs : accepte", v.get("ok") is True, str(v)[:80])

    # Forme reelle des douaniers PNJ historiques : aucun champ 'type', date en texte.
    c, v = ecrire(td, "effectifsDouane",
                  {"douaniers": [{"stats": {"PER": 12, "VOL": 12}, "roomId": "douanes",
                                  "matricule": "DOU-zztest", "recruteLe": 1787635789231,
                                  "buildingId": "port-sainte-marie"}],
                   "dernierPaiementJour": "2026-09-12"},
                  ville="ville_a", bat="port-sainte-marie")
    verifier("E5 forme reelle des douaniers PNJ (sans 'type') : acceptee",
             v.get("ok") is True, str(v)[:95])

    c, v = ecrire(tc, "effectifsPolice",
                  {"policiers": [{"matricule": "X", "type": "standard",
                                  "stats": {"PER": 9999, "VOL": 12}}]},
                  ville=VILLE_ZZ, bat="commissariat-local")
    verifier("E6 stat de policier hors bornes : refusee",
             v.get("ok") is False and v.get("raison") == "stat_hors_bornes", str(v)[:80])

    # === RESTAURATION ET CONSTAT ============================================
    # E5 a ecrit sur la ligne REELLE du port : on remet l'effectif d'origine bit pour bit.
    origine = json.loads(port_avant)
    c, v = ecrire(td, "effectifsDouane", origine["effectifsDouane"],
                  ville="ville_a", bat="port-sainte-marie")
    port_apres = blob(ID_PORT)
    verifier("R le contenu du blob du port est restaure a l'identique",
             empreinte(port_apres) == empreinte(port_avant),
             "%s -> %s" % (empreinte(port_avant), empreinte(port_apres)))

    for x in resultats:
        if not x["ok"]:
            print("  KO   %-62s %s" % (x["nom"], x["detail"]))
    ko = sum(1 for x in resultats if not x["ok"])
    print("\n%d controles, %d en echec." % (len(resultats), ko))

    for nom, jeton in ((QUIDAM, tq), (COMMIS, tc), (DOUANE, td)):
        http("DELETE", "/rest/v1/personnages?name=eq." + nom, jeton=jeton)
    print("Lignes zztest a supprimer en SQL (anon n'a plus de DELETE) : "
          "republic_%s_%s, republic_%s_commissariat-local" % (VILLE_ZZ, BAT_ZZ, VILLE_ZZ))
    return 1 if ko else 0


if __name__ == "__main__":
    sys.exit(main())
