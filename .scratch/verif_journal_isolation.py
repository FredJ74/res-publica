# -*- coding: utf-8 -*-
"""Contrôles statiques : isolation de la génération manuelle, et accès joueur au Journal.

Ce que ce banc prouve, et qu'aucun test dynamique ne peut prouver aussi sûrement : l'endpoint de
génération isolée ne PEUT PAS déclencher les autres tâches quotidiennes, parce qu'il n'importe
jamais le cron. Et que le joueur dispose d'un chemin d'accès normal au journal, sans console.
"""
import os
import re
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
echecs = []


def verifier(ok, texte, detail=''):
    print(('OK    ' if ok else 'ECHEC ') + texte + (('   [' + str(detail)[:200] + ']') if detail else ''))
    if not ok:
        echecs.append(texte)


def lire(f):
    return open(os.path.join(RACINE, f), encoding='utf-8').read()


# ------------------------------------------------------------------ isolation de l'endpoint
gen = lire('api/journal-generer.js')
cron = lire('api/cron-minuit.js')

imports = re.findall(r"from\s*'([^']+)'", gen)
verifier(sorted(imports) == ['./_journal-collecte.js', './_journal-generation.js'],
         'I1. l\'endpoint n\'importe QUE les deux modules du journal', imports)
# Les commentaires du fichier EXPLIQUENT pourquoi le cron n'est pas touché : on ne teste donc que
# le code exécutable, commentaires retirés.
gen_code = re.sub(r'/\*.*?\*/', '', re.sub(r'//[^\n]*', '', gen), flags=re.S)
verifier('cron-minuit' not in gen_code and 'cron-assemblee' not in gen_code,
         'I2. aucune référence au cron dans le code exécutable : les 16 autres tâches sont inatteignables')

# Les fonctions de tâches quotidiennes vivent dans cron-minuit.js. Aucune ne doit être nommée ici.
taches = re.findall(r'^async function ([a-zA-Z]+)\(', cron, re.M)
citees = [t for t in taches if re.search(r'\b' + t + r'\s*\(', gen)]
verifier(not citees, 'I3. aucune fonction de tâche quotidienne n\'est appelée', citees)
verifier(len(taches) > 20, 'I4. (référence) le cron contient bien des dizaines de tâches à ne pas rejouer',
         '%d fonctions' % len(taches))

appels = re.findall(r'await (genererEditionPays|genererToutesLesEditions)\(', gen)
verifier(sorted(set(appels)) == ['genererEditionPays', 'genererToutesLesEditions'],
         'I5. seules les deux fonctions de génération du journal sont appelées', sorted(set(appels)))

verifier("process.env.CRON_SECRET" in gen and "!process.env.CRON_SECRET ||" in gen
         and "status(401)" in gen,
         'I6. authentification fail-closed : sans CRON_SECRET configuré, tout est refusé')
verifier(gen.count('status(401)') == 1 and gen.index('status(401)') < gen.index('genererEditionPays('),
         'I7. le refus intervient AVANT toute génération')
verifier(not re.search(r'\b(sbInsert|sbUpdate|sbDelete)\b', gen),
         'I8. l\'endpoint n\'écrit rien lui-même : toute écriture reste dans le module de génération')

# L'idempotence est portée par la réservation, inchangée.
mod = lire('api/_journal-generation.js')
verifier("statut: 'en_cours'" in mod and 'dejaExistante = reservation.status === 409' in mod,
         'I9. idempotence inchangée : la réservation par INSERT précède tout appel IA')
verifier("existante.statut !== 'echec'" in mod and "'ignoree_deja_existante'" in mod,
         'I10. une édition déjà PUBLIÉE n\'est jamais remplacée ; seule une édition en échec est reprise')

# ------------------------------------------------------------------ chemin d'accès du joueur
pol = lire('plateau-politique.js')
core = lire('plateau-core.js')

verifier('afficherJournalDuJour()' in core and 'setTimeout' in core,
         'A1. le journal s\'ouvre automatiquement au chargement de la partie')
m = re.search(r'if \(!force\) addJournalEntry\(', pol)
verifier(m is not None, 'A2. le lien de réouverture est posé dans TOUS les cas, édition ou non')
bloc = pol[m.start():m.start() + 900] if m else ''
verifier('Lire le Journal du jour' in bloc and 'Passer au kiosque' in bloc,
         'A3. deux libellés : lire le numéro, ou se rendre au kiosque quand il n\'y en a pas')
verifier('afficherJournalDuJour(true)' in bloc,
         'A4. le lien rouvre le journal en contournant le verrou « une fois par session »')
verifier('htmlRedactionEnGreve()' in pol and 'function htmlRedactionEnGreve' in pol,
         'A5. l\'absence de numéro est habillée par la grève RP, jamais par un message technique')

greve = re.search(r'function htmlRedactionEnGreve\(\).*?\n\}', pol, re.S).group(0)
interdits = ['Anthropic', 'API', 'crédit', 'credit', 'HTTP', 'erreur', 'error', 'token', 'JSON']
fuites = [m for m in interdits if m in greve]
verifier(not fuites, 'A6. le texte de grève ne contient aucun terme technique', fuites)
verifier('grève' in greve and 'rotatives' in greve,
         'A7. le texte est bien diégétique (rédaction, rotatives)')

# Aucune manipulation technique demandée au joueur nulle part dans le chemin du journal.
verifier('console' not in bloc and 'console' not in greve,
         'A8. rien ne demande au joueur d\'ouvrir une console ou d\'appeler une API')

print()
print('%d contrôle(s), %d echec(s)' % (18, len(echecs)))
sys.exit(1 if echecs else 0)
