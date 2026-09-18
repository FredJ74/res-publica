# -*- coding: utf-8 -*-
"""Produit une VRAIE édition v2 à partir des données réelles de production, sans aucun appel IA.

Ni maquette, ni données de démonstration : le paquet factuel est construit par la VRAIE fonction
construirePaquetFactuel du dépôt, et la mise en page par la VRAIE fonction
construireEditionDeterministe. Seul le transport réseau est adapté : jsc n'a pas de `fetch`, donc
les requêtes du module sont d'abord ENREGISTRÉES, exécutées pour de vrai en Python avec la clé anon
(les lectures sont publiques), puis rejouées. On itère jusqu'à ce qu'aucune requête nouvelle
n'apparaisse, car certaines dépendent des réponses précédentes.

N'ÉCRIT RIEN. Le résultat est imprimé en JSON ; l'écriture en base se fait séparément, par le
workflow de migration MCP (seule voie disposant du droit d'écriture sur journal_editions).

Usage : python3 .scratch/generer_edition_reelle.py <pays> [fichier_sortie.json]
"""
import json
import os
import re
import subprocess
import sys
import urllib.parse
import urllib.request

JSC = '/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc'
RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
URL = 'https://jxpwoosmmhohoihxpbuc.supabase.co'
ANON = ('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3NtbWhvaG9p'
        'aHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMjIwOH0'
        '._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw')
PAYS = sys.argv[1] if len(sys.argv) > 1 else 'republic'
SORTIE = sys.argv[2] if len(sys.argv) > 2 else None


def charger_module(nom, alias):
    src = open(os.path.join(RACINE, 'api', nom), encoding='utf-8').read()
    src = re.sub(r"import\s*\{[^}]*\}\s*from\s*'[^']*';", '', src)
    m = re.search(r"export\s*\{([^}]*)\};?\s*$", src.rstrip())
    noms = [n.strip() for n in re.sub(r'//[^\n]*', '', m.group(1)).split(',') if n.strip()]
    src = src[:m.start()]
    retour = ', '.join('%s: %s' % (n, n) for n in noms)
    js = 'var %s = (function(){\n%s\nreturn { %s };\n})();\n' % (alias, src, retour)
    js += ''.join('var %s = %s.%s;\n' % (n, alias, n) for n in noms)
    return js


def prelude(reponses):
    return """
var process = { env: {} };
var console = { error: function(){}, warn: function(){}, log: function(){} };
function setTimeout(fn, ms){ return 0; }
function clearTimeout(id){}
function AbortController(){ this.signal = {}; this.abort = function(){}; }

var REPONSES = %s;
var DEMANDEES = [];
// Les bornes de période et d'expiration contiennent l'instant courant : la même requête change
// donc d'URL à chaque exécution. On normalise l'horodatage pour que la clé de cache soit stable,
// tout en exécutant la requête RÉELLE telle que le module l'a formée.
function normaliser(cle) {
  return cle.replace(/\d{4}-\d{2}-\d{2}T[^&]*?Z/g, 'TS');
}
function fetch(url, opts) {
  var brut = String(url).replace('%s', '');
  var cle = normaliser(brut);
  DEMANDEES.push(brut);
  var rows = Object.prototype.hasOwnProperty.call(REPONSES, cle) ? REPONSES[cle] : [];
  return Promise.resolve({ ok: true, status: 200,
    json: function(){ return Promise.resolve(rows); },
    text: function(){ return Promise.resolve(JSON.stringify(rows)); } });
}
""" % (json.dumps(reponses, ensure_ascii=False), URL)


def lancer(script, reponses):
    prog = prelude(reponses) + charger_module('_journal-collecte.js', 'MC') + '\n' \
        + charger_module('_journal-generation.js', 'MG') + '\n' + script
    # Le paquet réel (photos en base64 comprises) dépasse la taille d'un argument de ligne de
    # commande : on passe par un fichier temporaire, jamais par -e.
    tmp = os.path.join(os.environ.get('TMPDIR', '/tmp'), 'journal_edition_tmp.js')
    with open(tmp, 'w', encoding='utf-8') as f:
        f.write(prog)
    r = subprocess.run([JSC, tmp], capture_output=True, text=True)
    if r.returncode != 0 or r.stderr.strip():
        sys.stderr.write((r.stderr or '')[:3000] + '\n')
        sys.exit(2)
    return r.stdout


def normaliser(cle):
    """Même normalisation que côté jsc : neutralise l'instant courant dans les bornes."""
    return re.sub(r'\d{4}-\d{2}-\d{2}T[^&]*?Z', 'TS', cle)


def lire_reel(chemin):
    req = urllib.request.Request(URL + chemin,
                                 headers={'apikey': ANON, 'Authorization': 'Bearer ' + ANON})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read().decode() or '[]')
    except Exception as e:
        sys.stderr.write('lecture impossible %s : %s\n' % (chemin, e))
        return []


SCRIPT_COLLECTE = """
calculerPeriode('%(pays)s').then(function(periode){
  return construirePaquetFactuel('%(pays)s', periode).then(function(paquet){
    print(JSON.stringify({ demandees: DEMANDEES, paquet: paquet }));
  });
}).catch(function(e){ print(JSON.stringify({ demandees: DEMANDEES, erreur: String(e && e.message || e) })); });
""" % {'pays': PAYS}

# --- convergence des requêtes ---
reponses = {}
paquet = None
for passe in range(1, 6):
    res = json.loads(lancer(SCRIPT_COLLECTE, reponses))
    if res.get('erreur'):
        sys.stderr.write('erreur module : ' + res['erreur'] + '\n')
        sys.exit(2)
    nouvelles = []
    for c in res['demandees']:
        if normaliser(c) not in reponses:
            nouvelles.append(c)
    sys.stderr.write('passe %d : %d requête(s), %d nouvelle(s)\n'
                     % (passe, len(res['demandees']), len(nouvelles)))
    if not nouvelles:
        paquet = res['paquet']
        break
    for c in nouvelles:
        reponses[normaliser(c)] = lire_reel(c)
if paquet is None:
    sys.stderr.write('les requêtes ne convergent pas\n')
    sys.exit(2)

# --- mise en page déterministe, par la vraie fonction ---
SCRIPT_EDITION = """
var PAQUET = %s;
var dateEdition = dateEditionPourPays('%s', new Date());
var ed = construireEditionDeterministe(PAQUET, '%s', dateEdition);
var derniere_page = assemblerDernierePage(PAQUET, ed.une, ed.articles);
print(JSON.stringify({
  date_edition: dateEdition,
  une: Object.assign({}, ed.une, { redaction: 'deterministe' }),
  double_page_centrale: { articles: ed.articles },
  page_economie_societe: { avant_derniere_page: { interviews: [] }, derniere_page: derniere_page },
  reports: ed.sujets_differes,
  faits_sources: PAQUET
}));
""" % (json.dumps(paquet, ensure_ascii=False), PAYS, PAYS)

edition = json.loads(lancer(SCRIPT_EDITION, reponses))

resume = {
    'pays': PAYS,
    'date_edition': edition['date_edition'],
    'faits_collectes': len(paquet.get('FACTS') or []),
    'sujets_une': len(edition['une']['sujets']),
    'appels_une': len(edition['une']['appels']),
    'articles': len(edition['double_page_centrale']['articles']),
    'reports': len(edition['reports']),
    'derniere_page': {k: len(v) for k, v in edition['page_economie_societe']['derniere_page'].items()}
}
sys.stderr.write(json.dumps(resume, ensure_ascii=False, indent=2) + '\n')

if SORTIE:
    with open(SORTIE, 'w', encoding='utf-8') as f:
        json.dump(edition, f, ensure_ascii=False)
    sys.stderr.write('écrit dans ' + SORTIE + '\n')
else:
    print(json.dumps(edition, ensure_ascii=False))
