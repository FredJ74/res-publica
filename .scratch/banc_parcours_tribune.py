# -*- coding: utf-8 -*-
"""Parcours utilisateur complet de La Tribune, sur le code SERVI PAR LA PRODUCTION.

Ne vérifie pas seulement que l'édition existe en base : exécute `afficherJournalDuJour()` elle-même,
avec un DOM bouché qui enregistre ce qui est réellement écrit à l'écran, et une lecture Supabase
RÉELLE (réponse pré-téléchargée avec la clé anon, par la requête exacte du client). Prouve donc que
le joueur voit le numéro, et pas seulement qu'une API le renvoie.

RACINE_JOURNAL=<dossier des fichiers servis> pour cibler la production.
"""
import json
import os
import re
import subprocess
import sys
import urllib.request

JSC = '/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc'
RACINE = os.environ.get('RACINE_JOURNAL') or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
URL = 'https://jxpwoosmmhohoihxpbuc.supabase.co'
ANON = ('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3NtbWhvaG9p'
        'aHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMjIwOH0'
        '._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw')
PAYS = sys.argv[1] if len(sys.argv) > 1 else 'republic'
echecs = []


def verifier(ok, texte, detail=''):
    print(('OK    ' if ok else 'ECHEC ') + texte + (('   [' + str(detail)[:200] + ']') if detail else ''))
    if not ok:
        echecs.append(texte)


def lire(f):
    return open(os.path.join(RACINE, f), encoding='utf-8').read()


def extraire(fichier, noms):
    src = lire(fichier)
    out = []
    for n in noms:
        m = re.search(r'^(?:async )?function ' + re.escape(n) + r'\(.*?^\}', src, re.S | re.M)
        if not m:
            m = re.search(r'^(?:const|let|var) ' + re.escape(n) + r'\b.*?;$', src, re.M)
        if not m:
            raise SystemExit('introuvable : ' + n + ' dans ' + fichier)
        out.append(m.group(0))
    return '\n'.join(out)


# --------------------------------------------------------------- conteneurs DOM réellement servis
html_jeu = lire('plateau.html')
for ident in ['modal-postes', 'postes-modal-title', 'postes-body']:
    verifier(('id="' + ident + '"') in html_jeu, 'D1.%s conteneur « %s » présent dans le jeu servi' % (ident[0], ident))
verifier('modal-close' in html_jeu and 'modal-header' in html_jeu,
         'D2. en-tête et fermeture de modale présents')

# --------------------------------------------------------------- lecture RÉELLE, requête du client
pol = lire('plateau-politique.js')
version = re.search(r"const PROMPT_VERSION_JOURNAL_ATTENDU = '([^']+)'", pol).group(1)
date_paris = subprocess.run(
    [JSC, '-e', "print(new Intl.DateTimeFormat('en-CA',{timeZone:'Europe/Paris',year:'numeric',"
                "month:'2-digit',day:'2-digit'}).format(new Date()))"],
    capture_output=True, text=True).stdout.strip()
chemin = ('/rest/v1/journal_editions?country=eq.' + PAYS + '&statut=eq.publiee'
          '&date_edition=eq.' + date_paris + '&prompt_version=eq.' + version + '&limit=1')
req = urllib.request.Request(URL + chemin, headers={'apikey': ANON, 'Authorization': 'Bearer ' + ANON})
with urllib.request.urlopen(req, timeout=30) as r:
    rows = json.loads(r.read().decode())
verifier(bool(rows), 'P1. la production renvoie bien une édition pour la requête du client',
         '%s / %s / %s' % (PAYS, date_paris, version))

# --------------------------------------------------------------- exécution du vrai parcours client
code = extraire('forum.js', ['escapeHtmlText'])
code += '\n' + extraire('plateau-core.js', ['MOIS_FR_JOURNAL'])
code += '\n' + extraire('plateau-politique.js', [
    'PROMPT_VERSION_JOURNAL_ATTENDU', '_journalDragCleanup', 'dateEditionAujourdhui', 'formaterDateEditionFr',
    'nettoyerMarkdownResiduel', 'texteArticleHtml', 'construireIndexFaitsJournal',
    'resoudreImageJournal', 'renderImageJournal', 'renderArticleJournal',
    'grouperArticlesParRubrique', 'renderJodieJournal', 'renderDernierePageJournal',
    'htmlRedactionEnGreve', 'construireHtmlJournalDuJour', 'activerDragJournal',
    'desactiverDragJournal', 'afficherJournalDuJour'])

PRELUDE = """
// --- DOM bouché : enregistre EXACTEMENT ce qui est écrit à l'écran ---
var ECRAN = { titre: null, corps: null, classes: [], modaleOuverte: false, entreesJournal: [] };
function faireClassList(cible) {
  return { add: function(c){ ECRAN.classes.push(cible + '+' + c); if (cible === 'modal') ECRAN.modaleOuverte = true; },
           remove: function(c){ ECRAN.classes.push(cible + '-' + c); },
           toggle: function(c, v){ ECRAN.classes.push(cible + (v ? '+' : '-') + c); },
           contains: function(){ return false; } };
}
var NOEUDS = {
  'postes-modal-title': { set textContent(v){ ECRAN.titre = v; }, get textContent(){ return ECRAN.titre; } },
  'postes-body': { set innerHTML(v){ ECRAN.corps = v; }, get innerHTML(){ return ECRAN.corps; } },
  'modal-postes': { classList: faireClassList('modal') }
};
var BOITE = { classList: faireClassList('box'), style: {}, getBoundingClientRect: function(){ return { width: 600, height: 400, left: 0, top: 0 }; } };
var document = {
  getElementById: function(id){ return NOEUDS[id] || null; },
  querySelector: function(sel){
    if (sel.indexOf('modal-box') !== -1) return BOITE;
    if (sel.indexOf('modal-close') !== -1) return { click: function(){} };
    if (sel.indexOf('tribune-fronton') !== -1 || sel.indexOf('modal-header') !== -1) {
      return { addEventListener: function(){}, removeEventListener: function(){},
               classList: faireClassList('header'), style: {} };
    }
    return null;
  },
  addEventListener: function(){}, removeEventListener: function(){}
};
var window = { innerWidth: 1200, innerHeight: 800, addEventListener: function(){}, removeEventListener: function(){} };
var sessionStorage = { _d: {}, getItem: function(k){ return this._d[k] || null; }, setItem: function(k, v){ this._d[k] = v; } };
var state = { country: '%(pays)s', day: 42, char: { name: 'Testeur' } };
function addJournalEntry(texte, type){ ECRAN.entreesJournal.push(texte); }
function updateUI(){}
var console = { warn: function(){}, error: function(){}, log: function(){} };

// --- lecture Supabase : réponse RÉELLE de production, pré-téléchargée ---
var REPONSE_REELLE = %(reponse)s;
var REQUETES = [];
var MODE_VIDE = false;
function sbGet(table, filtres) {
  REQUETES.push(table + '?' + filtres);
  return Promise.resolve(MODE_VIDE ? [] : REPONSE_REELLE);
}
"""

prog = (PRELUDE % {'pays': PAYS, 'reponse': json.dumps(rows, ensure_ascii=False)}) + code + """
afficherJournalDuJour(true).then(function(){
  var r1 = { titre: ECRAN.titre, corps: ECRAN.corps, classes: ECRAN.classes.slice(),
             requetes: REQUETES.slice(), entrees: ECRAN.entreesJournal.slice(),
             modale: ECRAN.modaleOuverte };
  // Deuxième passage : aucune édition disponible -> habillage de grève.
  // Nouvelle session : sinon le verrou « une ouverture automatique par session » court-circuite
  // l'appel (comportement voulu, vérifié au passage par P13).
  MODE_VIDE = true; ECRAN.classes = []; ECRAN.entreesJournal = []; sessionStorage._d = {};
  return afficherJournalDuJour(false).then(function(){
    print(JSON.stringify({ avec: r1, sans: { corps: ECRAN.corps, classes: ECRAN.classes,
                                             entrees: ECRAN.entreesJournal } }));
  });
}).catch(function(e){ print(JSON.stringify({ __erreur: String(e && e.message || e), pile: String(e && e.stack || '') })); });
"""
tmp = os.path.join(os.environ.get('TMPDIR', '/tmp'), 'parcours_tribune.js')
with open(tmp, 'w', encoding='utf-8') as f:
    f.write(prog)
r = subprocess.run([JSC, tmp], capture_output=True, text=True)
if r.returncode != 0 or r.stderr.strip() or not r.stdout.strip():
    print('--- ERREUR JSC ---')
    print((r.stderr or '')[:2000])
    print((r.stdout or '')[:1500])
    sys.exit(2)
d = json.loads(r.stdout)
if d.get('__erreur'):
    verifier(False, 'P2. le parcours client s\'exécute sans exception', d['__erreur'])
    print(d.get('pile', '')[:800])
    sys.exit(1)

avec, sans = d['avec'], d['sans']
edition = rows[0]
arts = edition['double_page_centrale']['articles']

verifier(True, 'P2. le parcours client s\'exécute sans exception')
verifier(avec['requetes'] and avec['requetes'][0].startswith('journal_editions?')
         and 'statut=eq.publiee' in avec['requetes'][0]
         and ('date_edition=eq.' + date_paris) in avec['requetes'][0]
         and ('prompt_version=eq.' + version) in avec['requetes'][0],
         'P3. la fonction interroge bien journal_editions avec les quatre filtres attendus')
verifier(avec['titre'] == 'Journal du jour', 'P4. la modale s\'intitule « Journal du jour »', avec['titre'])
verifier(avec['modale'] is True and 'modal+open' in avec['classes'],
         'P5. la modale est réellement ouverte à l\'écran')
verifier('box+modal-wide' in avec['classes'] and 'box+journal-mode' in avec['classes'],
         'P6. mise en page large et mode journal appliqués (fronton unique)', avec['classes'])
verifier('tribune-republia' in (avec['corps'] or '') and 'tribune-greve' not in (avec['corps'] or ''),
         'P7. c\'est bien le QUOTIDIEN qui est écrit dans la page, pas un message de repli')
verifier(edition['une']['sujets'][0]['titre'] in avec['corps'],
         'P8. le titre de Une est présent à l\'écran', edition['une']['sujets'][0]['titre'])
verifier(all(a['titre'] in avec['corps'] for a in arts),
         'P9. les %d articles sont présents à l\'écran' % len(arts))
verifier('12 septembre 2026' in avec['corps'], 'P10. la date du numéro est affichée en français')
verifier('stade-olympique-luthecia.png' in avec['corps'],
         'P11. l\'illustration du stade est présente dans la page rendue')
verifier('undefined' not in avec['corps'] and 'NaN' not in avec['corps'] and 'null' not in avec['corps'],
         'P12. aucun « undefined », « null » ni « NaN » à l\'écran')
verifier(avec['entrees'] == [],
         'P13. une réouverture manuelle ne republie pas d\'entrée dans le journal d\'événements',
         avec['entrees'])

# --- second passage : aucune édition -> grève RP, et lien tout de même posé
verifier('tribune-greve' in (sans['corps'] or '') and 'La rédaction est en grève' in sans['corps'],
         'P14. sans édition, le joueur lit l\'habillage de grève, jamais une erreur')
technique = [m for m in ['Anthropic', 'HTTP', 'API', 'undefined', 'null', 'error'] if m in (sans['corps'] or '')]
verifier(not technique, 'P15. aucun terme technique dans ce repli', technique)
verifier('box+journal-mode' not in [c for c in sans['classes'] if c.startswith('box+journal-mode')]
         or 'box-journal-mode' in sans['classes'],
         'P16. le mode journal n\'est pas appliqué au repli (l\'en-tête reste utilisable)', sans['classes'])
verifier(len(sans['entrees']) == 1 and 'Passer au kiosque' in sans['entrees'][0],
         'P17. un lien de réouverture est tout de même posé : le joueur n\'est jamais bloqué',
         sans['entrees'])

print()
print('%d contrôle(s), %d echec(s)' % (21, len(echecs)))
sys.exit(1 if echecs else 0)
