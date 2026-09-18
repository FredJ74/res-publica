#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Preuve STATIQUE de l'independance des deux detections (acheteur / vendeur), §35 et §38 --
contrat du 11 septembre 2026 : les deux detections sont SERVEUR (assemblee_detecter_partie), un
jet par partie, et un circuit legal refuse la vente au lieu de la tracer.

Complement des tests reels (4 combinaisons de jets et mesure d'independance sur 1000 tirages).
"""

import os
import re
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
resultats = []


def controle(titre, ok, detail=''):
    resultats.append(ok)
    print("%s %-62s %s" % ("OK  " if ok else "ECHEC", titre, detail))


def lire(nom):
    with open(os.path.join(RACINE, nom), encoding='utf-8', errors='replace') as fh:
        return fh.read()


def sans_commentaires(src):
    return '\n'.join(l for l in src.split('\n') if not l.lstrip().startswith('//'))


def corps_sql(src, nom):
    m = re.search(r'FUNCTION public\.' + nom + r'\(.*?\$\$(.*?)\$\$;', src, re.S)
    return m.group(1) if m else ''


ILLEGALES = lire('plateau-actions-illegales-rumeurs.js')
ASSEMBLEE = lire('plateau-assemblee.js')
SQL = lire('migration_assemblee_interdictions_ventes.sql')
CLIENT = {n: sans_commentaires(lire(n)) for n in sorted(os.listdir(RACINE))
          if n.endswith('.js') and (n.startswith('plateau') or n in ('supabase.js', 'forum.js', 'data.js'))}

DETECTER = corps_sql(SQL, 'assemblee_detecter_partie')
MOTEUR = corps_sql(SQL, 'assemblee_transaction_interdite_interne')
ACHAT_ILLEGAL = corps_sql(SQL, 'assemblee_achat_illegal')
TRACER = corps_sql(SQL, 'assemblee_tracer_vente_interdite')
LOI = corps_sql(SQL, 'assemblee_loi_en_vigueur')

# 1. Un commerce est un circuit LEGAL : refus AVANT le debit, aucune trace
cmd = sans_commentaires(ILLEGALES[ILLEGALES.find('async function commanderProduitCommerce'):])
cmd = cmd[:cmd.find('\nasync function ', 10)]
i_ctrl, i_debit = cmd.find('assembleeControlerVenteLegale('), cmd.find('debiterFondsOrdinaires(')
controle("1. commerce : refus avant tout debit, aucune trace creee", 0 <= i_ctrl < i_debit and 'Tracer' not in cmd,
         'controle a %d, debit a %d' % (i_ctrl, i_debit))

# 2. Aucun code client n'invoque la trace vendeur ni le moteur a deux parties
invocations = [n for n, src in CLIENT.items() if re.search(
    r"sbAssembleeTracerVenteInterdite\(|sbRpc\(\s*'assemblee_(tracer_vente_interdite|transaction_interdite_interne|detecter_partie)'", src)]
controle("2. aucun code client n'invoque trace vendeur / moteur interne", not invocations, str(invocations or ''))

# 3. Le vendeur est resolu par le serveur depuis 'entreprises'
controle("3. trace vendeur : vendeur resolu depuis entreprises", "FROM public.entreprises" in TRACER and "->> 'proprietaire'" in TRACER)

# 4. Deux detections, deux appels distincts, un tirage chacun, aucune variable partagee
appels = re.findall(r"assemblee_detecter_partie\((\w+|v_vendeur|p_acheteur), '(achat|vente)'", MOTEUR)
controle("4. moteur : deux appels distincts (achat, vente), resultats separes",
         sorted(r for _, r in appels) == ['achat', 'vente'] and 'v_a :=' in MOTEUR and 'v_v :=' in MOTEUR,
         str(appels))
controle("4 bis. un seul jet par detection, sur la discretion de la partie",
         DETECTER.count('floor(random() * 100)') == 1 and "WHERE name = p_nom FOR UPDATE" in DETECTER)
controle("4 ter. plus aucun jet ni trace de transaction calcules cote client",
         not any('assembleeTracerTransactionIllegale' in s or 'creerConvocationTransactionInterdite' in s for s in CLIENT.values()))

# 5. L'acheteur ne recoit jamais le resultat du vendeur
controle("5. l'acheteur ne recoit jamais le resultat vendeur", "'vendeur'" not in ACHAT_ILLEGAL.split('RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(')[-1])
controle("5 bis. l'acheteur ne peut incriminer que lui-meme (vendeur NULL)",
         "assemblee_transaction_interdite_interne(v_country, p_nom, NULL," in ACHAT_ILLEGAL)

# 6. Base 50 % modulee par la discretion
controle("6. base 50 % modulee par la discretion", 'GREATEST(5, 50 - floor(v_dis / 10)::integer)' in DETECTER)

# 7. Une seule convocation ouverte par motif
controle("7. garde anti-doublon de convocation", "c.value ->> 'motif' = 'transaction_interdite'" in DETECTER
         and "COALESCE((c.value ->> 'traitee')::boolean, false) = false" in DETECTER)

# 8. Jamais d'arrestation immediate
controle("8. aucune arrestation immediate", 'est_emprisonne' not in DETECTER and 'est_emprisonne' not in MOTEUR)

# 9. Un vendeur PNJ n'engage personne
controle("9. un vendeur PNJ n'engage aucune responsabilite", "NULLIF(NULLIF(btrim(COALESCE(p_vendeur, '')), ''), 'PNJ')" in MOTEUR
         and "NULLIF(e.data ->> 'proprietaire', 'PNJ')" in TRACER)

# 10. Loi revalidee a l'instant de la transaction, avec l'entree en vigueur reelle
controle("10. loi en vigueur : adoptee ET adoptee_ts <= instant", "p.statut = 'adoptee'" in LOI and 'p.adoptee_ts <= p_instant' in LOI
         and 'assemblee_loi_en_vigueur(p_country, p_objet, now())' in MOTEUR and 'p.adoptee_ts <= now()' in TRACER)

# 11. Verrous : lignes des deux parties dans l'ordre des noms
controle("11. verrous des deux parties dans l'ordre des noms", 'ORDER BY name FOR UPDATE' in MOTEUR)

# 12. Trace vendeur et moteur reserves au service_role
anon_interne = re.search(r"GRANT EXECUTE ON FUNCTION public\.assemblee_(tracer_vente_interdite|transaction_interdite_interne|detecter_partie)\([^)]*\)\s+TO [^;]*\banon\b", SQL)
controle("12. trace vendeur, moteur et detection reserves au service_role", not anon_interne)

print("")
echecs = sum(1 for r in resultats if not r)
print("%d controle(s), %d echec(s)" % (len(resultats), echecs))
sys.exit(1 if echecs else 0)
