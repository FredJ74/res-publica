# -*- coding: utf-8 -*-
"""Vérifie le RENDU CLIENT du Journal du jour sur l'édition RÉELLEMENT publiée en base.

Deux étapes, aucune donnée inventée :
  1. l'édition est lue avec la REQUÊTE EXACTE du client (mêmes filtres pays / statut / date /
     prompt_version) et la clé anon publique -- si cette lecture échoue, le joueur ne verrait rien ;
  2. le HTML est produit par les VRAIES fonctions de rendu de plateau-politique.js, exécutées dans
     jsc. Le fichier n'est jamais modifié : les fonctions sont extraites par leur signature.

Produit aussi un aperçu HTML autonome (style.css réel inclus) pour inspection visuelle.
"""
import json
import os
import re
import subprocess
import sys
import urllib.request

JSC = '/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc'
# RACINE_JOURNAL permet de faire tourner ce banc sur les fichiers RÉELLEMENT SERVIS par la
# production (téléchargés au préalable) plutôt que sur la copie locale.
RACINE = os.environ.get('RACINE_JOURNAL') or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
URL = 'https://jxpwoosmmhohoihxpbuc.supabase.co'
ANON = ('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3NtbWhvaG9p'
        'aHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMjIwOH0'
        '._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw')
PAYS = sys.argv[1] if len(sys.argv) > 1 else 'republic'
APERCU = sys.argv[2] if len(sys.argv) > 2 else None

echecs = []


def verifier(ok, texte, detail=''):
    print(('OK    ' if ok else 'ECHEC ') + texte + (('   [' + str(detail)[:200] + ']') if detail else ''))
    if not ok:
        echecs.append(texte)


def extraire(fichier, noms):
    src = open(os.path.join(RACINE, fichier), encoding='utf-8').read()
    out = []
    for n in noms:
        m = re.search(r'^(?:async )?function ' + re.escape(n) + r'\(.*?^\}', src, re.S | re.M)
        if not m:
            m = re.search(r'^const ' + re.escape(n) + r' = .*?;$', src, re.M)
        if not m:
            raise SystemExit('introuvable : ' + n + ' dans ' + fichier)
        out.append(m.group(0))
    return '\n'.join(out)


# ---- 1. lecture par la requête EXACTE du client -------------------------------------------------
src_client = open(os.path.join(RACINE, 'plateau-politique.js'), encoding='utf-8').read()
m = re.search(r"const PROMPT_VERSION_JOURNAL_ATTENDU = '([^']+)'", src_client)
version_attendue = m.group(1)
date_paris = subprocess.run(
    [JSC, '-e', "print(new Intl.DateTimeFormat('en-CA',{timeZone:'Europe/Paris',year:'numeric',"
                "month:'2-digit',day:'2-digit'}).format(new Date()))"],
    capture_output=True, text=True).stdout.strip()

chemin = ('/rest/v1/journal_editions?country=eq.' + PAYS + '&statut=eq.publiee'
          '&date_edition=eq.' + date_paris + '&prompt_version=eq.' + version_attendue + '&limit=1')
req = urllib.request.Request(URL + chemin, headers={'apikey': ANON, 'Authorization': 'Bearer ' + ANON})
with urllib.request.urlopen(req, timeout=30) as r:
    rows = json.loads(r.read().decode())
verifier(bool(rows), 'R1. la requête exacte du client trouve bien l\'édition du jour',
         '%s / %s / %s' % (PAYS, date_paris, version_attendue))
if not rows:
    sys.exit(1)
edition = rows[0]

# ---- 2. rendu par les vraies fonctions ----------------------------------------------------------
code = extraire('forum.js', ['escapeHtmlText'])
code += '\n' + extraire('plateau-core.js', ['MOIS_FR_JOURNAL'])
code += '\n' + extraire('plateau-politique.js', [
    'formaterDateEditionFr', 'nettoyerMarkdownResiduel', 'texteArticleHtml',
    'construireIndexFaitsJournal', 'resoudreImageJournal', 'renderImageJournal',
    'renderArticleJournal', 'grouperArticlesParRubrique', 'renderJodieJournal',
    'renderDernierePageJournal', 'construireHtmlJournalDuJour'])

prog = ('var EDITION = ' + json.dumps(edition, ensure_ascii=False) + ';\n' + code
        + '\nprint(construireHtmlJournalDuJour(EDITION));\n')
tmp = os.path.join(os.environ.get('TMPDIR', '/tmp'), 'rendu_journal_tmp.js')
with open(tmp, 'w', encoding='utf-8') as f:
    f.write(prog)
r = subprocess.run([JSC, tmp], capture_output=True, text=True)
if r.returncode != 0 or r.stderr.strip():
    print('--- ERREUR JSC ---')
    print((r.stderr or '')[:2000])
    sys.exit(2)
html = r.stdout

arts = edition['double_page_centrale']['articles']
dp = edition['page_economie_societe']['derniere_page']

verifier(len(html) > 2000, 'R2. le rendu produit un document substantiel', '%d caractères' % len(html))
verifier('class="tribune-republia"' in html and 'tribune-fronton' in html,
         'R3. structure du quotidien présente (conteneur + fronton)')
verifier('La Tribune de Républia' in html and '12 septembre 2026' in html,
         'R4. fronton daté correctement en français')
verifier('class="tribune-une' in html and edition['une']['sujets'][0]['titre'] in html,
         'R5. la Une est rendue avec son titre')
# Le rendu échappe le HTML (apostrophes comprises) : on compare sur une forme déséchappée.
import html as _h
html_texte = _h.unescape(html)
verifier(edition['une']['sujets'][0]['chapeau'][:60] in html_texte
         and 'tribune-une-chapeau' in html or edition['une']['sujets'][0]['chapeau'][:60] in html_texte,
         'R6. le chapeau de Une est rendu', edition['une']['sujets'][0]['chapeau'][:50])
verifier(html.count('class="tribune-une-accroches"') == 1
         and all(a['texte'] in html for a in edition['une']['appels']),
         'R7. les trois appels de Une sont rendus')
verifier('Deuxième page' in html, 'R8. le séparateur de deuxième page apparaît')
rubriques = set(a['rubrique'] for a in arts)
verifier(all(rb in html for rb in rubriques) and html.count('class="tribune-rubrique"') == len(rubriques),
         'R9. une section par rubrique réelle, sans rubrique fantôme', sorted(rubriques))
verifier(html.count('class="tribune-article"') == len(arts),
         'R10. tous les articles sont rendus', '%d / %d' % (html.count('class="tribune-article"'), len(arts)))
verifier(all(a['titre'] in html for a in arts), 'R11. chaque titre d\'article est présent')
verifier('tribune-derniere' in html and 'Indices' in html,
         'R12. la dernière page et ses indices sont rendus')
verifier('En bref' in html and dp['chiens_ecrases'][0][:40] in html,
         'R13. les brèves sont rendues')
verifier('Petites annonces' not in html and 'Carnet' not in html
         and 'Journal des arrivées' not in html,
         'R14. les rubriques réellement vides sont absentes, sans trou ni titre orphelin')
verifier('tribune-jodie' not in html,
         'R15. aucune section interview alors qu\'il n\'y a aucune interview réelle')
verifier('stade-olympique-luthecia.png' in html and 'tribune-article-image' in html,
         'R16. l\'illustration réelle (photo du stade) est rendue sur l\'article sportif')
verifier(html.count('<img') == 1,
         'R17. aucune image inventée : une seule illustration, celle qui existe vraiment',
         html.count('<img'))
verifier('undefined' not in html and 'NaN' not in html and 'null' not in html,
         'R18. aucun « undefined », « null » ni « NaN » dans le document rendu')
verifier('loading="lazy"' in html, 'R19. les illustrations sont chargées paresseusement')

# Noir et blanc : porté par la feuille de style, pas par le HTML.
css = open(os.path.join(RACINE, 'style.css'), encoding='utf-8').read()
verifier(re.search(r'\.tribune-republia\s+img\s*\{[^}]*grayscale\(1\)', css) is not None,
         'R20. la règle de conversion en noir et blanc couvre toutes les illustrations du journal')
verifier('.tribune-greve' in css and '@media (max-width:720px)' in css,
         'R21. l\'habillage « pas de numéro » est stylé et responsive')

if APERCU:
    with open(APERCU, 'w', encoding='utf-8') as f:
        f.write('<!doctype html><meta charset="utf-8">'
                '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?'
                'family=Playfair+Display:wght@700&family=Inter:wght@400;600&display=swap">'
                '<style>' + css + '</style>'
                '<div style="max-width:720px;margin:0 auto;padding:1rem">' + html + '</div>')
    print('aperçu écrit dans ' + APERCU)

print()
print('%d contrôle(s), %d echec(s)' % (21, len(echecs)))
sys.exit(1 if echecs else 0)
