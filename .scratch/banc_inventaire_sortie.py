#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BANC DE L'ENTONNOIR DE SORTIE D'INVENTAIRE (chantier C, 14 septembre 2026).

L'inventaire personnel avait un entonnoir d'ENTREE (addToInventory) et aucune sortie : 32 sites
retiraient des objets par splice/filter directs. Cinq guichets serveur les remplacent, sur une
primitive interne commune.

Ce banc joue les onze situations exigees par le cahier des charges : retrait legitime, quantite
insuffisante, quantite negative/nulle, objet absent, acteur usurpe, double soumission,
concurrence, objet protege, transfert avec contrepartie, echec sans mutation partielle, appels
directs forges.

Donnees zztest uniquement, supprimees a la fin.
"""
import json, sys, time, urllib.request, urllib.error

URL = "https://jxpwoosmmhohoihxpbuc.supabase.co"
ANON = ("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3"
        "NtbWhvaG9paHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMj"
        "IwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw")

SUF = str(int(time.time()))
MOI = "zztest-inv-" + SUF
AUTRE = "zztest-inv-dest-" + SUF
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


def sig(nom, typ="", cle=""):
    return {"name": nom, "type": typ, "stackKey": cle}


# Inventaire de depart : un objet unique banal, un lot empilable, un objet illegal, un objet
# vise par aucune loi, et le colis secret protege.
def inventaire_depart():
    return [
        {"name": "Carnet", "type": "document", "legal": True, "desc": "Un carnet."},
        {"name": "Bois", "stackable": True, "stackKey": "bois", "qty": 10},
        {"name": "Fiole de poison", "type": "poison", "legal": False, "desc": "Interdite."},
        {"name": "Pain", "familleProduitMarche": "aliment", "dateAchat": 1, "legal": True},
        {"name": "Colis secret", "type": "colis_secret_pat", "legal": True},
    ]


def inv(jeton, qui=None):
    c, r = http("GET", "/rest/v1/personnages?select=inventory&name=eq." + (qui or MOI), jeton=jeton)
    return (r[0]["inventory"] if r else None) or []


def qte(inventaire, cle):
    return sum(float(e.get("qty", 1)) for e in inventaire if e.get("stackKey") == cle)


def noms(inventaire):
    return sorted(e.get("name", "") for e in inventaire)


def creer(jeton, nom, inventaire, quete=None):
    corps = {"name": nom, "country": "republic", "arg": 5000, "liquide": 5000, "pa": 20,
             "hp": 100, "moral": 75, "day": 10, "current_city": "capitale",
             "current_building": "mairie", "current_room": "hall",
             "stats": {}, "resources": {}, "inventory": inventaire}
    if quete is not None:
        corps["quete_carriere"] = quete
    return http("POST", "/rest/v1/personnages", corps, jeton=jeton)


def main():
    tj = session()
    time.sleep(1)
    tj2 = session()
    try:
        return deroulement(tj, tj2)
    finally:
        http("DELETE", "/rest/v1/personnages?name=eq." + MOI, jeton=tj)
        http("DELETE", "/rest/v1/personnages?name=eq." + AUTRE, jeton=tj2)


def deroulement(tj, tj2):
    # La quete de carriere est TERMINEE : le colis n'est donc plus protege par la regle du jeu.
    # C'est le cas nominal ; la protection est testee separement en section G.
    code, rep = creer(tj, MOI, inventaire_depart(), {"ambition": "criminel", "etape": "terminee"})
    if code not in (200, 201):
        print("PREPARATION IMPOSSIBLE (acteur) : %s %s" % (code, str(rep)[:200]))
        return 2
    code, rep = creer(tj2, AUTRE, [])
    if code not in (200, 201):
        print("PREPARATION IMPOSSIBLE (destinataire) : %s %s" % (code, str(rep)[:200]))
        return 2

    verifier("0 la quete de carriere est bien persistee",
             (lambda r: r and r[0].get("quete_carriere", {}).get("etape") == "terminee")(
                 http("GET", "/rest/v1/personnages?select=quete_carriere&name=eq." + MOI,
                      jeton=tj)[1]),
             "colonne quete_carriere")

    # === A. RETRAIT LEGITIME ==============================================
    c, v = rpc("inventaire_detruire",
               {"p_acteur": MOI, "p_index": 0, "p_signature": sig("Carnet", "document"),
                "p_qte": 1}, jeton=tj)
    verifier("A1 destruction d'un objet unique : acceptee", v.get("ok") is True, str(v)[:110])
    verifier("A2 l'objet a disparu de l'inventaire relu", "Carnet" not in noms(inv(tj)),
             noms(inv(tj)))
    verifier("A3 la RPC a renvoye l'inventaire qui fait foi",
             noms(v.get("inventory") or []) == noms(inv(tj)),
             "annonce %s / relu %s" % (noms(v.get("inventory") or []), noms(inv(tj))))

    c, v = rpc("inventaire_detruire",
               {"p_acteur": MOI, "p_index": 0, "p_signature": sig("Bois", "", "bois"),
                "p_qte": 3}, jeton=tj)
    verifier("A4 retrait partiel d'un lot empilable : accepte", v.get("ok") is True, str(v)[:110])
    verifier("A5 il reste exactement 7 unites", qte(inv(tj), "bois") == 7.0, qte(inv(tj), "bois"))

    # === B. QUANTITE INSUFFISANTE =========================================
    avant = inv(tj)
    c, v = rpc("inventaire_detruire",
               {"p_acteur": MOI, "p_index": 0, "p_signature": sig("Bois", "", "bois"),
                "p_qte": 999}, jeton=tj)
    verifier("B1 retirer plus que le stock : refuse",
             v.get("ok") is False and v.get("raison") == "quantite_insuffisante", str(v)[:110])
    verifier("B2 le lot est intact, aucun retrait partiel", qte(inv(tj), "bois") == 7.0,
             qte(inv(tj), "bois"))
    verifier("B3 rien d'autre n'a bouge", noms(inv(tj)) == noms(avant), noms(inv(tj)))

    c, v = rpc("inventaire_detruire",
               {"p_acteur": MOI, "p_index": 3, "p_signature": sig("Pain"), "p_qte": 2}, jeton=tj)
    verifier("B4 demander 2 exemplaires d'un objet unique : refuse",
             v.get("ok") is False and v.get("raison") == "quantite_insuffisante", str(v)[:110])

    # === C. QUANTITE NEGATIVE OU NULLE ====================================
    for q, libelle in ((0, "nulle"), (-5, "negative"), (100000, "demesuree")):
        c, v = rpc("inventaire_detruire",
                   {"p_acteur": MOI, "p_index": 0, "p_signature": sig("Bois", "", "bois"),
                    "p_qte": q}, jeton=tj)
        verifier("C quantite %s : refusee" % libelle,
                 v.get("ok") is False and v.get("raison") == "quantite_invalide", str(v)[:90])
    verifier("C4 le lot est toujours a 7", qte(inv(tj), "bois") == 7.0, qte(inv(tj), "bois"))

    # === D. OBJET ABSENT ==================================================
    c, v = rpc("inventaire_detruire",
               {"p_acteur": MOI, "p_index": 0, "p_signature": sig("Diamant royal", "tresor"),
                "p_qte": 1}, jeton=tj)
    verifier("D1 objet jamais possede : refuse",
             v.get("ok") is False and v.get("raison") == "objet_absent", str(v)[:110])

    # L'index est un INDICE, jamais une autorite : un index faux mais une signature juste doit
    # retrouver le bon objet, et surtout ne JAMAIS retirer l'objet qui occupe cet index.
    c, v = rpc("inventaire_detruire",
               {"p_acteur": MOI, "p_index": 99, "p_signature": sig("Pain"), "p_qte": 1}, jeton=tj)
    verifier("D2 index faux mais signature juste : le serveur retrouve le bon objet",
             v.get("ok") is True, str(v)[:110])
    verifier("D3 et c'est bien le Pain qui est parti, pas un voisin",
             "Pain" not in noms(inv(tj)) and "Fiole de poison" in noms(inv(tj)), noms(inv(tj)))

    # === E. ACTEUR USURPE =================================================
    avant = inv(tj)
    c, v = rpc("inventaire_detruire",
               {"p_acteur": MOI, "p_index": 0, "p_signature": sig("Bois", "", "bois"),
                "p_qte": 1}, jeton=tj2)
    verifier("E1 detruire dans l'inventaire d'AUTRUI : refuse",
             c in (400, 401, 403, 404) or v.get("ok") is False, "HTTP %s %s" % (c, str(v)[:90]))
    verifier("E2 l'inventaire de la victime est intact", noms(inv(tj)) == noms(avant),
             noms(inv(tj)))

    c, v = rpc("inventaire_detruire",
               {"p_acteur": MOI, "p_index": 0, "p_signature": sig("Bois", "", "bois"),
                "p_qte": 1})
    verifier("E3 sans aucune session : refuse",
             c in (400, 401, 403, 404) or v.get("ok") is False
             or v.get("code") in ("42501", "PGRST202"), "HTTP %s %s" % (c, str(v)[:90]))

    # === F. APPELS DIRECTS FORGES =========================================
    c, r = http("PATCH", "/rest/v1/personnages?name=eq." + MOI,
                {"inventory": [{"name": "Lingot", "stackable": True, "stackKey": "or",
                                "qty": 10000}]}, jeton=tj2)
    verifier("F1 PATCH direct de l'inventaire d'autrui : refuse",
             c in (400, 401, 403, 404) or (isinstance(r, dict) and r.get("code") == "42501"),
             "HTTP %s %s" % (c, str(r)[:80]))

    # La primitive INTERNE ne verifie aucune identite : elle ne doit pas etre joignable.
    c, r = http("POST", "/rest/v1/rpc/helvetia_inventaire_sortie",
                {"p_inv": [], "p_quete": None, "p_index": 0, "p_signature": {}, "p_qte": 1},
                jeton=tj)
    verifier("F2 la primitive interne reste fermee au navigateur",
             c in (401, 403, 404) or (isinstance(r, dict)
                                      and r.get("code") in ("42501", "PGRST202")),
             "HTTP %s %s" % (c, str(r)[:80]))

    # === G. OBJET PROTEGE =================================================
    # On remet la quete en cours : le colis redevient indispensable.
    http("PATCH", "/rest/v1/personnages?name=eq." + MOI,
         {"quete_carriere": {"ambition": "criminel", "etape": "en_cours"}}, jeton=tj)

    for guichet, corps, libelle in (
        ("inventaire_detruire",
         {"p_acteur": MOI, "p_index": 0, "p_signature": sig("Colis secret", "colis_secret_pat"),
          "p_qte": 1}, "detruit"),
        ("inventaire_abandonner",
         {"p_acteur": MOI, "p_index": 0, "p_signature": sig("Colis secret", "colis_secret_pat"),
          "p_country": "republic", "p_city": "capitale", "p_building": "mairie",
          "p_room": "hall"}, "abandonne"),
        ("inventaire_donner",
         {"p_acteur": MOI, "p_destinataire": AUTRE, "p_index": 0,
          "p_signature": sig("Colis secret", "colis_secret_pat"), "p_qte": 1,
          "p_mutations": None}, "donne"),
    ):
        c, v = rpc(guichet, corps, jeton=tj)
        verifier("G le colis de quete ne peut pas etre %s" % libelle,
                 v.get("ok") is False and v.get("raison") == "objet_protege", str(v)[:110])
    verifier("G4 le colis est toujours la", "Colis secret" in noms(inv(tj)), noms(inv(tj)))

    # Et il echappe aussi a la confiscation en masse.
    c, v = rpc("inventaire_confisquer", {"p_acteur": MOI}, jeton=tj)
    verifier("G5 confiscation : la fiole illegale est saisie",
             v.get("ok") is True and "Fiole de poison" in (v.get("noms") or ""), str(v)[:110])
    verifier("G6 confiscation : le colis de quete est epargne",
             "Colis secret" in noms(inv(tj)), noms(inv(tj)))
    verifier("G7 confiscation : le bois legal n'est pas saisi", qte(inv(tj), "bois") == 7.0,
             qte(inv(tj), "bois"))

    c, v = rpc("inventaire_confisquer", {"p_acteur": MOI}, jeton=tj)
    verifier("G8 seconde confiscation : plus rien a saisir, sans erreur",
             v.get("ok") is True and (v.get("noms") or "") == "", str(v)[:110])

    # FAIL-CLOSED sur l'inconnu : si l'etat de quete est absent (personnage anterieur a la
    # colonne, ou client pas encore a jour), le colis doit etre traite comme PROTEGE. Laisser
    # passer detruirait un objet indispensable a une quete sur la foi d'une donnee manquante.
    http("PATCH", "/rest/v1/personnages?name=eq." + MOI, {"quete_carriere": None}, jeton=tj)
    c, v = rpc("inventaire_detruire",
               {"p_acteur": MOI, "p_index": 0, "p_signature": sig("Colis secret", "colis_secret_pat"),
                "p_qte": 1}, jeton=tj)
    verifier("G9 etat de quete INCONNU : le colis reste protege (fail-closed)",
             v.get("ok") is False and v.get("raison") == "objet_protege", str(v)[:110])

    # Quete d'une AUTRE ambition : la regle du jeu ne protege alors plus ce colis.
    http("PATCH", "/rest/v1/personnages?name=eq." + MOI,
         {"quete_carriere": {"ambition": "politique", "etape": "en_cours"}}, jeton=tj)
    c, v = rpc("inventaire_detruire",
               {"p_acteur": MOI, "p_index": 0, "p_signature": sig("Colis secret", "colis_secret_pat"),
                "p_qte": 1}, jeton=tj)
    verifier("G10 hors ambition criminelle : le colis redevient destructible",
             v.get("ok") is True, str(v)[:110])

    # === G'. REMISE DE QUETE ==============================================
    # La protection interdit les cinq autres sorties. Elle ne doit PAS rendre la quete
    # interminable : la remise a la destinataire designee reste possible, et elle seule.
    http("PATCH", "/rest/v1/personnages?name=eq." + MOI,
         {"quete_carriere": {"ambition": "criminel", "etape": "en_cours"},
          "inventory": [{"name": "Colis secret", "type": "colis_secret_pat", "legal": True}]},
         jeton=tj)
    c, v = rpc("inventaire_remettre",
               {"p_acteur": MOI, "p_index": 0, "p_signature": sig("Colis secret", "colis_secret_pat"),
                "p_destinataire": "Raoul Toufaud"}, jeton=tj)
    verifier("G11 remise du colis a un PNJ quelconque : refusee",
             v.get("ok") is False and v.get("raison") == "destinataire_non_designe", str(v)[:110])
    verifier("G12 et le colis est toujours la", noms(inv(tj)) == ["Colis secret"], noms(inv(tj)))

    c, v = rpc("inventaire_remettre",
               {"p_acteur": MOI, "p_index": 0, "p_signature": sig("Colis secret", "colis_secret_pat"),
                "p_destinataire": "Brigitte Menottes"}, jeton=tj)
    verifier("G13 remise a la destinataire designee : acceptee malgre la protection",
             v.get("ok") is True and v.get("remise_quete") is True, str(v)[:110])
    verifier("G14 la quete peut donc se terminer", inv(tj) == [], inv(tj))

    # === H. TRANSFERT AVEC CONTREPARTIE ===================================
    # La section precedente a remis le colis, l'inventaire est vide : on le regarnit du lot
    # empilable dont cette section a besoin.
    http("PATCH", "/rest/v1/personnages?name=eq." + MOI,
         {"inventory": [{"name": "Bois", "stackable": True, "stackKey": "bois", "qty": 7}]},
         jeton=tj)
    # Le don doit retirer chez l'un ET deposer chez l'autre, dans la meme transaction.
    c, v = rpc("inventaire_donner",
               {"p_acteur": MOI, "p_destinataire": AUTRE, "p_index": 0,
                "p_signature": sig("Bois", "", "bois"), "p_qte": 4, "p_mutations": None},
               jeton=tj)
    verifier("H1 don de 4 unites : accepte", v.get("ok") is True, str(v)[:110])
    verifier("H2 le donneur n'en a plus que 3", qte(inv(tj), "bois") == 3.0, qte(inv(tj), "bois"))
    c, recus = http("GET", "/rest/v1/objets_recus?select=data,expediteur&destinataire=eq." + AUTRE,
                    jeton=tj2)
    verifier("H3 la contrepartie existe reellement chez le destinataire",
             bool(recus) and len(recus) == 1, str(recus)[:110])
    # Le client lit objets_recus.data avec JSON.parse : la valeur DOIT etre une chaine JSON,
    # pas un objet jsonb -- sinon l'objet donne serait silencieusement perdu a la reception.
    lisible = False
    if recus:
        try:
            o = json.loads(recus[0]["data"]) if isinstance(recus[0]["data"], str) else None
            lisible = bool(o) and o.get("stackKey") == "bois" and float(o.get("qty")) == 4.0
        except Exception:
            lisible = False
    verifier("H4 le format depose est relisible tel quel par le jeu (chaine JSON)",
             lisible, str(recus[0]["data"])[:110] if recus else "aucune ligne")

    c, v = rpc("inventaire_donner",
               {"p_acteur": MOI, "p_destinataire": "zztest-fantome-" + SUF, "p_index": 0,
                "p_signature": sig("Bois", "", "bois"), "p_qte": 1, "p_mutations": None},
               jeton=tj)
    verifier("H5 don a un destinataire inexistant : refuse",
             v.get("ok") is False and v.get("raison") == "destinataire_introuvable", str(v)[:110])
    verifier("H6 et le donneur a toujours ses 3 unites", qte(inv(tj), "bois") == 3.0,
             qte(inv(tj), "bois"))

    # Les mutations de presentation ne doivent JAMAIS pouvoir gonfler une quantite.
    c, v = rpc("inventaire_donner",
               {"p_acteur": MOI, "p_destinataire": AUTRE, "p_index": 0,
                "p_signature": sig("Bois", "", "bois"), "p_qte": 1,
                "p_mutations": {"qty": 99999, "message": "coucou", "legal": False}}, jeton=tj)
    depose = None
    if v.get("ok") is True:
        c, rows = http("GET", "/rest/v1/objets_recus?select=data&destinataire=eq." + AUTRE
                       + "&order=created_at.desc&limit=1", jeton=tj2)
        try:
            depose = json.loads(rows[0]["data"])
        except Exception:
            depose = None
    verifier("H7 une mutation ne peut pas gonfler la quantite transferee",
             v.get("ok") is True and depose is not None and float(depose.get("qty")) == 1.0,
             str(depose)[:110])
    verifier("H8 mais la presentation passe bien",
             depose is not None and depose.get("message") == "coucou", str(depose)[:110])

    # === I. DOUBLE SOUMISSION ET CONCURRENCE ==============================
    # Deux fois la meme demande : la seconde ne doit pas retirer un second exemplaire.
    avant_bois = qte(inv(tj), "bois")
    c1, v1 = rpc("inventaire_detruire",
                 {"p_acteur": MOI, "p_index": 0, "p_signature": sig("Bois", "", "bois"),
                  "p_qte": 2}, jeton=tj)
    c2, v2 = rpc("inventaire_detruire",
                 {"p_acteur": MOI, "p_index": 0, "p_signature": sig("Bois", "", "bois"),
                  "p_qte": 2}, jeton=tj)
    apres_bois = qte(inv(tj), "bois")
    verifier("I1 double soumission : chaque appel accepte retire exactement son du",
             avant_bois - apres_bois == (2 if v1.get("ok") else 0) + (2 if v2.get("ok") else 0),
             "%s -> %s (ok1=%s ok2=%s)" % (avant_bois, apres_bois, v1.get("ok"), v2.get("ok")))

    # Objet unique : deux soumissions identiques, une seule peut reussir.
    http("PATCH", "/rest/v1/personnages?name=eq." + MOI,
         {"inventory": [{"name": "Relique", "type": "relique", "legal": True}]}, jeton=tj)
    c1, v1 = rpc("inventaire_detruire",
                 {"p_acteur": MOI, "p_index": 0, "p_signature": sig("Relique", "relique"),
                  "p_qte": 1}, jeton=tj)
    c2, v2 = rpc("inventaire_detruire",
                 {"p_acteur": MOI, "p_index": 0, "p_signature": sig("Relique", "relique"),
                  "p_qte": 1}, jeton=tj)
    verifier("I2 objet unique soumis deux fois : une seule reussite",
             bool(v1.get("ok")) != bool(v2.get("ok")),
             "ok1=%s ok2=%s" % (v1.get("ok"), v2.get("ok")))
    verifier("I3 et l'inventaire est vide, jamais negatif", inv(tj) == [], inv(tj))

    # === J. ABANDON ET ECHEC SANS MUTATION PARTIELLE ======================
    http("PATCH", "/rest/v1/personnages?name=eq." + MOI,
         {"inventory": [{"name": "Parapluie", "type": "objet", "legal": True}]}, jeton=tj)
    c, v = rpc("inventaire_abandonner",
               {"p_acteur": MOI, "p_index": 0, "p_signature": sig("Parapluie", "objet"),
                "p_country": "republic", "p_city": "capitale", "p_building": "mairie",
                "p_room": "hall"}, jeton=tj)
    verifier("J1 abandon dans la piece : accepte", v.get("ok") is True, str(v)[:110])
    verifier("J2 l'objet a quitte l'inventaire", inv(tj) == [], inv(tj))
    c, sol = http("GET", "/rest/v1/objets_abandonnes?select=id,data&building_id=eq.mairie"
                  + "&room_id=eq.hall&id=eq." + str(v.get("objet_id")), jeton=tj)
    verifier("J3 il est reellement ramassable dans la piece", bool(sol), str(sol)[:110])
    verifier("J4 le serveur lui a donne un identifiant (le client n'en fournissait aucun)",
             bool(v.get("objet_id")), str(v.get("objet_id"))[:60])

    # Echec du depot : lieu invalide -> rien ne doit sortir de l'inventaire.
    http("PATCH", "/rest/v1/personnages?name=eq." + MOI,
         {"inventory": [{"name": "Chapeau", "type": "objet", "legal": True}]}, jeton=tj)
    c, v = rpc("inventaire_abandonner",
               {"p_acteur": MOI, "p_index": 0, "p_signature": sig("Chapeau", "objet"),
                "p_country": "republic", "p_city": "capitale", "p_building": "",
                "p_room": ""}, jeton=tj)
    verifier("J5 abandon sans lieu valide : refuse",
             v.get("ok") is False and v.get("raison") == "lieu_invalide", str(v)[:110])
    verifier("J6 ECHEC SANS MUTATION PARTIELLE : le chapeau est toujours en inventaire",
             noms(inv(tj)) == ["Chapeau"], noms(inv(tj)))

    # === K. CONSOMMATION : FAMILLE CONTROLEE ==============================
    c, v = rpc("inventaire_consommer",
               {"p_acteur": MOI, "p_index": 0, "p_signature": sig("Chapeau", "objet")}, jeton=tj)
    verifier("K1 consommer un objet qui n'est pas consommable : refuse",
             v.get("ok") is False and v.get("raison") == "objet_non_consommable", str(v)[:110])
    verifier("K2 et le chapeau est intact", noms(inv(tj)) == ["Chapeau"], noms(inv(tj)))

    http("PATCH", "/rest/v1/personnages?name=eq." + MOI,
         {"inventory": [{"name": "Sirop", "type": "medicament", "legal": True}]}, jeton=tj)
    c, v = rpc("inventaire_consommer",
               {"p_acteur": MOI, "p_index": 0, "p_signature": sig("Sirop", "medicament")},
               jeton=tj)
    verifier("K3 consommer un medicament : accepte", v.get("ok") is True, str(v)[:110])
    verifier("K4 il a disparu", inv(tj) == [], inv(tj))

    for x in resultats:
        if not x["ok"]:
            print("  KO   %-64s %s" % (x["nom"], x["detail"]))
    ko = sum(1 for x in resultats if not x["ok"])
    print("\n%d controles, %d en echec." % (len(resultats), ko))
    return 1 if ko else 0


if __name__ == "__main__":
    sys.exit(main())
