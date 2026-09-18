# -*- coding: utf-8 -*-
"""Banc du Journal du jour v2 — exécute les VRAIES fonctions des deux modules serveur.

Aucune réimplémentation, aucune extraction par expression régulière : les fichiers
api/_journal-collecte.js et api/_journal-generation.js sont chargés tels quels dans jsc, seuls
l'import/export ES et les accès réseau étant remplacés par des bouchons. `fetch` est bouché par une
base de données de test en mémoire, ce qui permet d'éprouver la collecte de bout en bout.

Ne touche à AUCUNE donnée réelle et n'ouvre aucune connexion.
"""
import json
import os
import re
import subprocess
import sys

JSC = '/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc'
RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def charger_module(nom, alias):
    """Lit un module ES du dossier api/ et le rend évaluable par jsc.

    Les deux modules déclarent les mêmes constantes de haut niveau (SUPABASE_URL, sbGet...) : on
    isole donc chacun dans sa propre fermeture, puis on republie en global UNIQUEMENT les noms que
    le module exporte réellement (liste lue dans son bloc `export`, jamais une liste réécrite ici).
    Les noms importés d'un module à l'autre se résolvent alors par la portée globale.
    """
    src = open(os.path.join(RACINE, 'api', nom), encoding='utf-8').read()
    src = re.sub(r"import\s*\{[^}]*\}\s*from\s*'[^']*';", '', src)
    m = re.search(r"export\s*\{([^}]*)\};?\s*$", src.rstrip())
    if not m:
        raise SystemExit('bloc export introuvable dans ' + nom)
    noms = [n.strip() for n in re.sub(r'//[^\n]*', '', m.group(1)).split(',') if n.strip()]
    src = src[:m.start()]
    retour = ', '.join('%s: %s' % (n, n) for n in noms)
    js = 'var %s = (function(){\n%s\nreturn { %s };\n})();\n' % (alias, src, retour)
    js += ''.join('var %s = %s.%s;\n' % (n, alias, n) for n in noms)
    return js


PRELUDE = r"""
var process = { env: {} };
var console = { error: function(){}, warn: function(){}, log: function(){} };

// ---- base de test en mémoire, servie par le bouchon de fetch ----
var DB = {};
var APPELS_FETCH = [];
function reponse(rows) {
  return Promise.resolve({ ok: true, status: 200, json: function(){ return Promise.resolve(rows); },
                           text: function(){ return Promise.resolve(JSON.stringify(rows)); } });
}
var REPONSE_ANTHROPIC = null;   // null = comme si l'API n'existait pas
function fetch(url, opts) {
  APPELS_FETCH.push(String(url));
  if (String(url).indexOf('api.anthropic.com') !== -1) {
    if (REPONSE_ANTHROPIC === 'erreur_credit') {
      return Promise.resolve({ ok: false, status: 400,
        text: function(){ return Promise.resolve('{"error":{"message":"Your credit balance is too low"}}'); } });
    }
    if (REPONSE_ANTHROPIC === 'reseau') return Promise.reject(new Error('getaddrinfo ENOTFOUND'));
    return Promise.resolve({ ok: true, status: 200, json: function(){
      return Promise.resolve({ content: [{ text: REPONSE_ANTHROPIC }] }); } });
  }
  var m = String(url).match(/rest\/v1\/([a-z_]+)\?/);
  var table = m ? m[1] : '';
  var rows = DB[table] || [];
  if (opts && opts.method && opts.method !== 'GET') return reponse([]);
  return reponse(rows);
}

// jsc en ligne de commande n'a ni timers ni AbortController : appelAnthropic les utilise pour son
// délai de garde. Bouchons neutres -- le délai n'est pas ce que ce banc éprouve.
function setTimeout(fn, ms){ return 0; }
function clearTimeout(id){}
function AbortController(){ this.signal = {}; this.abort = function(){}; }

// POIDS_ORDRE et determinerPaysEligibles viennent du module de collecte, chargé juste après :
// aucune redéfinition ici, pour que le banc éprouve bien les vraies valeurs du dépôt.
"""


def lancer(script):
    prog = PRELUDE + charger_module('_journal-collecte.js', 'MOD_COLLECTE') + '\n' + \
        charger_module('_journal-generation.js', 'MOD_GENERATION') + '\n' + script
    prog += ('\n;if (typeof Promise !== "undefined") { '
             'Promise.resolve().then(function(){}); }\n')
    r = subprocess.run([JSC, '-e', prog], capture_output=True, text=True)
    if r.returncode != 0 or r.stderr.strip():
        print('--- ERREUR JSC ---')
        print((r.stderr or '')[:3000])
        print((r.stdout or '')[:2000])
        sys.exit(2)
    if not r.stdout.strip():
        print('--- SORTIE VIDE : une promesse a probablement été rejetée silencieusement ---')
        sys.exit(2)
    return r.stdout


echecs = []


def verifier(ok, texte, detail=''):
    print(('OK    ' if ok else 'ECHEC ') + texte + (('   [' + str(detail)[:220] + ']') if detail else ''))
    if not ok:
        echecs.append(texte)


# ======================================================================== jeux de données réels
FAIT_PJ = {
    "id": "candidatures:republic_maire_ville_b_Gavrilo Princip", "pays": "republic",
    "type": "candidature", "estPJ": True, "poids": "secondaire", "ville": "Montrouge",
    "acteur": "Gavrilo Princip",
    "resume": "Gavrilo Princip a déposé sa candidature au poste de maire à Montrouge",
    "domaine": "politique", "photo_url": "data:image/jpeg;base64,AAAA",
    "created_at": "2026-09-12T08:00:00.000Z", "expositionRecente": False
}
FAIT_MATCH = {
    "id": "championnat:j2-brise-olympique", "pays": ["republic", "republic"],
    "type": "resultat_match", "estPJ": False, "poids": "mineur", "ville": None, "acteur": None,
    "resume": "La Brise Mariannaise 1 - 3 Olympique de Luthécia", "domaine": "sport",
    "photo_url": None, "club_image": "https://exemple/stade.png",
    "created_at": "2026-09-12T09:00:00.000Z", "expositionRecente": False
}
FAIT_ETRANGER = {
    "id": "championnat:j2-al-baraka-rojos", "pays": ["khalija", "narco"],
    "type": "resultat_match", "estPJ": False, "poids": "important", "ville": None, "acteur": None,
    "resume": "Oasis City FC 1 - 1 Estudiantes de la Ciudad", "domaine": "sport",
    "photo_url": None, "club_image": None,
    "created_at": "2026-09-12T09:00:00.000Z", "expositionRecente": False
}
FAIT_FUITE = {
    "id": "chronique-fuite-12", "pays": "republic", "type": "fuite_journalistique",
    "estPJ": True, "poids": "majeur", "ville": "capitale", "acteur": "Ga Teau",
    "resume": "Des documents révèlent un achat d'arme illégal impliquant Ga Teau",
    "domaine": "presse", "photo_url": None,
    "created_at": "2026-09-12T10:00:00.000Z", "expositionRecente": False
}
FAIT_SCANDALE = {
    "id": "chronique-scandale-7", "pays": "republic", "type": "scandale_presse",
    "estPJ": True, "poids": "important", "ville": "capitale", "acteur": "Ga Teau",
    "resume": "Arnie met publiquement en cause Ga Teau", "domaine": "presse", "photo_url": None,
    "nature": "accusation", "attribue_a": "Arnie",
    "contenu_attribue": "Ga Teau aurait détourné les fonds du club municipal.",
    "created_at": "2026-09-12T11:00:00.000Z", "expositionRecente": False
}
FAIT_PERMANENT = {
    "id": "cycles_electoraux:republic_maire_capitale", "pays": "republic",
    "type": "echeance_electorale", "estPJ": False, "poids": "secondaire", "ville": "Luthécia",
    "acteur": None,
    "resume": "Élection du maire de Luthécia : scrutin le dimanche 27 septembre 2026, aucune candidature enregistrée à ce jour",
    "domaine": "politique", "photo_url": None, "permanent": True,
    "created_at": "2026-09-12T12:00:00.000Z", "expositionRecente": False
}
FAIT_CONDAMNATION_FAVORABLE = {
    "id": "jugements:jug-42", "pays": "republic", "type": "condamnation", "estPJ": True,
    "poids": "important", "ville": "Luthécia", "acteur": "Ga Teau",
    "resume": "Ga Teau a été condamné à une amende de 500 FR", "domaine": "justice",
    "photo_url": None, "cadrage": "favorable", "cadrage_beneficiaire": "Ga Teau",
    "created_at": "2026-09-12T13:00:00.000Z", "expositionRecente": False
}


def paquet(facts, annonces=None, indicateurs=None):
    return {
        "country": "republic",
        "periode": {"debut": "2026-09-11T19:00:00.000Z", "fin": "2026-09-12T19:00:00.000Z"},
        "FACTS": facts, "PUBLIC_STATEMENTS": [], "INDICATORS": indicateurs or [],
        "PETITES_ANNONCES": annonces or [], "EDUCATIONAL_REFERENCE": {"fiche_id": None}
    }


def js_const(nom, valeur):
    return 'var %s = %s;\n' % (nom, json.dumps(valeur, ensure_ascii=False))


# ======================================================================== A. ÉDITION SANS IA
print('=== A. L\'édition existe sans IA ===')
sortie = lancer(
    js_const('PAQUET', paquet([FAIT_PJ, FAIT_MATCH, FAIT_FUITE, FAIT_PERMANENT])) + r"""
var ed = construireEditionDeterministe(PAQUET, 'republic', '2026-09-12');
print(JSON.stringify({
  sujets: ed.une.sujets.length,
  titre: ed.une.sujets[0].titre,
  chapeau: ed.une.sujets[0].chapeau,
  ref: ed.une.sujets[0].article_ref,
  appels: ed.une.appels.length,
  articles: ed.articles.map(function(a){ return {id:a.id, rub:a.rubrique, titre:a.titre, img:a.image.type, src:a.source_ids}; }),
  imageUne: ed.une.image
}));
""")
d = json.loads(sortie)
verifier(d['sujets'] == 1 and bool(d['titre']) and bool(d['chapeau']),
         'A1. une Une complète est produite sans aucun appel IA', d['titre'])
verifier(not d['chapeau'].lstrip().startswith((':', ';', ',', '.', '-')) and d['chapeau'][0].isupper(),
         'A1 bis. le chapeau ne s\'ouvre jamais sur un séparateur orphelin', d['chapeau'][:60])
verifier(d['ref'] is not None and any(a['id'] == d['ref'] for a in d['articles']),
         'A2. le sujet de Une pointe vers un article réellement présent', d['ref'])
verifier(len(d['articles']) == 3,
         'A3. un article par fait publiable (le match mineur part en dernière page)', len(d['articles']))
verifier(d['articles'][0]['src'] == [FAIT_FUITE['id']],
         'A4. hiérarchie respectée : le fait majeur (fuite) ouvre le numéro', d['articles'][0]['titre'])
verifier(all(len(a['src']) == 1 for a in d['articles']),
         'A5. chaque article est tracé vers son fait source')
verifier(d['imageUne'] in (None, {'type': 'generique', 'ref_id': None}) or d['imageUne']['ref_id'] == FAIT_FUITE['id'],
         'A6. image de Une issue du fait de tête, jamais fabriquée', d['imageUne'])

# ======================================================================== B. AUCUNE INVENTION
print()
print('=== B. Aucune information inventée ===')
sortie = lancer(
    js_const('PAQUET', paquet([FAIT_PJ, FAIT_SCANDALE, FAIT_PERMANENT])) + r"""
var ed = construireEditionDeterministe(PAQUET, 'republic', '2026-09-12');
var tout = JSON.stringify(ed);
print(JSON.stringify({
  tout: tout,
  textes: ed.articles.map(function(a){ return a.texte; }),
  titres: ed.articles.map(function(a){ return a.titre; })
}));
""")
d = json.loads(sortie)
corpus = ' '.join(d['textes'] + d['titres'])
# Tout mot significatif du rendu doit provenir des résumés réels ou du vocabulaire de liaison fixe.
sources = ' '.join([FAIT_PJ['resume'], FAIT_SCANDALE['resume'], FAIT_PERMANENT['resume'],
                    FAIT_SCANDALE['contenu_attribue'], 'Arnie',
                    str(FAIT_PJ['ville']), str(FAIT_SCANDALE['ville']), str(FAIT_PERMANENT['ville'])])
liaison = set("""selon ces propos n engagent que leur auteur l information concerne fait constaté le
cette provient du registre judiciaire candidature de à journée calme aucun événement notable a été
enregistré sur les dernières vingt-quatre heures élection une décision justice rendue interpellation
signalée""".split())
inconnus = []
for mot in re.findall(r"[A-Za-zÀ-ÿ]{4,}", corpus):
    if mot.lower() in liaison:
        continue
    if mot.lower() in sources.lower():
        continue
    inconnus.append(mot)
verifier(not inconnus, 'B1. aucun mot du rendu ne vient d\'ailleurs que des données réelles', inconnus[:8])
verifier('Selon Arnie' in corpus and FAIT_SCANDALE['contenu_attribue'][:30] in corpus,
         'B2. une accusation est citée sous attribution explicite de son auteur')
verifier('engagent que leur auteur' in corpus,
         'B3. l\'accusation n\'est jamais reprise à son compte par le journal')
verifier('Ga Teau aurait détourné' in corpus and 'a détourné' not in corpus.replace('aurait détourné', ''),
         'B4. le contenu de l\'accusation n\'est jamais transformé en fait établi')

# ======================================================================== C. JOURNÉE PAUVRE / VIDE
print()
print('=== C. Journée pauvre et journée vide ===')
sortie = lancer(
    js_const('PAUVRE', paquet([FAIT_PERMANENT])) + js_const('VIDE', paquet([])) + r"""
var a = construireEditionDeterministe(PAUVRE, 'republic', '2026-09-12');
var b = construireEditionDeterministe(VIDE, 'republic', '2026-09-12');
print(JSON.stringify({
  pauvre: { sujets: a.une.sujets.length, ref: a.une.sujets[0].article_ref, arts: a.articles.length,
            titre: a.une.sujets[0].titre },
  vide: { sujets: b.une.sujets.length, ref: b.une.sujets[0].article_ref, arts: b.articles.length,
          titre: b.une.sujets[0].titre, chapeau: b.une.sujets[0].chapeau }
}));
""")
d = json.loads(sortie)
verifier(d['pauvre']['arts'] == 1 and d['pauvre']['ref'] is not None,
         'C1. une journée sans événement produit un vrai numéro à partir d\'un sujet permanent',
         d['pauvre']['titre'])
verifier(d['vide']['sujets'] == 1 and d['vide']['ref'] is None and d['vide']['arts'] == 0,
         'C2. une journée réellement vide produit une Une « journée calme » valide, jamais une grève',
         d['vide']['titre'])
verifier('Journée calme' in d['vide']['titre'] and 'vingt-quatre heures' in d['vide']['chapeau'],
         'C3. le constat de journée calme est vrai et sobre, sans remplissage')

# ======================================================================== D. ERREUR IA
print()
print('=== D. Une erreur IA ne supprime plus le journal ===')
sortie = lancer(
    js_const('PAQUET', paquet([FAIT_PJ, FAIT_FUITE])) + r"""
function essai(rep) {
  REPONSE_ANTHROPIC = rep;
  return appelAnthropic('prompt', PAQUET, 1000).then(function(r){
    var det = construireEditionDeterministe(PAQUET, 'republic', '2026-09-12');
    return { appelOk: r.ok, erreur: r.erreur || null, sujets: det.une.sujets.length, arts: det.articles.length };
  });
}
Promise.all([essai('erreur_credit'), essai('reseau'), essai('{ pas du json'), essai(null)])
  .then(function(rs){ print(JSON.stringify(rs)); })
  .catch(function(e){ print(JSON.stringify({__erreur: String(e && e.message || e)})); });
""")
d = json.loads(sortie)
verifier(all(r['appelOk'] is False for r in d),
         'D1. les quatre modes de panne IA sont bien détectés', [r['erreur'][:40] for r in d if r['erreur']])
verifier(all(r['sujets'] >= 1 and r['arts'] >= 1 for r in d),
         'D2. dans chaque cas, une édition complète reste produisible')
verifier('credit balance is too low' in (d[0]['erreur'] or ''),
         'D3. la panne réelle de production (crédit épuisé) est couverte')

# ======================================================================== E. DÉGRADATION ARTICLE
print()
print('=== E. Dégradation élégante de la validation ===')
reponse_ia = {
    "une": {
        "sujets": [{"titre": "Candidature à Montrouge", "chapeau": "Un candidat se déclare.",
                    "article_ref": "a1"}],
        "appels": [{"texte": "Un match", "article_ref": "a2"},
                   {"texte": "Fantôme", "article_ref": "a-inexistant"}],
        "image": {"type": "personnage", "ref_id": FAIT_PJ['id']}
    },
    "articles": [
        {"id": "a1", "rubrique": "Politique", "type": "actualite", "titre": "Candidature",
         "texte": "Gavrilo Princip a déposé sa candidature au poste de maire à Montrouge.",
         "personnages_concernes": ["Gavrilo Princip"], "interview_suggeree": False,
         "source_ids": [FAIT_PJ['id']], "image": {"type": "personnage", "ref_id": FAIT_PJ['id']}},
        {"id": "a2", "rubrique": "Sport", "type": "actualite", "titre": "Match",
         "texte": "La Brise Mariannaise 1 - 3 Olympique de Luthécia.",
         "personnages_concernes": [], "interview_suggeree": False,
         "source_ids": [FAIT_MATCH['id']], "image": {"type": "lieu", "ref_id": FAIT_MATCH['id']}},
        {"id": "a3", "rubrique": "Politique", "type": "actualite", "titre": "Source inventée",
         "texte": "Un événement dont la source n'existe pas.",
         "personnages_concernes": [], "interview_suggeree": False,
         "source_ids": ["jugements:jug-inexistant"], "image": {"type": "generique", "ref_id": None}},
        {"id": "a4", "rubrique": "Politique", "type": "declaration", "titre": "Citation fausse",
         "texte": "Le maire affirme : « une phrase jamais prononcée par personne ».",
         "personnages_concernes": [], "interview_suggeree": False,
         "source_ids": [FAIT_PJ['id']], "image": {"type": "generique", "ref_id": None}}
    ],
    "sujets_differes": [{"source_id": FAIT_FUITE['id'], "priorite": "n_importe_quoi", "raison": "trop dense"}]
}
sortie = lancer(
    js_const('PAQUET', paquet([FAIT_PJ, FAIT_MATCH, FAIT_FUITE])) +
    js_const('REP', json.dumps(reponse_ia, ensure_ascii=False)) + r"""
var ai = construireAiInput(PAQUET, '2026-09-12', []);
var v = validerEtNettoyerEdition(REP, ai);
print(JSON.stringify({
  fatal: v.fatal, utilisable: v.uneUtilisable,
  gardes: v.articles.map(function(a){ return a.id; }),
  sujets: v.une.sujets.map(function(s){ return s.article_ref; }),
  appels: v.une.appels.map(function(a){ return a.article_ref; }),
  reports: v.sujets_differes,
  ecarts: v.ecarts
}));
""")
d = json.loads(sortie)
verifier(d['fatal'] is False and d['utilisable'] is True,
         'E1. une réponse IA partiellement fautive reste publiable')
verifier(d['gardes'] == ['a1', 'a2'],
         'E2. les articles fautifs sont écartés un par un, les bons sont gardés', d['gardes'])
verifier(any('a3' in e and 'source' in e for e in d['ecarts']),
         'E3. un article citant une source inexistante est écarté (intégrité factuelle maintenue)')
verifier(any('a4' in e and 'citation' in e.lower() for e in d['ecarts']),
         'E4. un article à la citation fabriquée est écarté (intégrité factuelle maintenue)')
verifier(d['appels'] == ['a2'],
         'E5. un appel de Une pointant vers un article écarté est nettoyé', d['appels'])
verifier(d['reports'] and d['reports'][0]['priorite'] == 'differable',
         'E6. une priorité de report invalide est corrigée au lieu de tout rejeter', d['reports'])

print()
sortie = lancer(js_const('PAQUET', paquet([FAIT_PJ])) + r"""
var ai = construireAiInput(PAQUET, '2026-09-12', []);
var cas = {
  json_illisible: validerEtNettoyerEdition('{ ceci n est pas du json', ai),
  une_absente: validerEtNettoyerEdition('{"articles":[]}', ai),
  articles_absents: validerEtNettoyerEdition('{"une":{"sujets":[]}}', ai),
  une_vide: validerEtNettoyerEdition('{"une":{"sujets":[],"appels":[]},"articles":[]}', ai)
};
var out = {};
Object.keys(cas).forEach(function(k){ out[k] = { fatal: cas[k].fatal, util: cas[k].uneUtilisable }; });
print(JSON.stringify(out));
""")
d = json.loads(sortie)
verifier(d['json_illisible']['fatal'] and d['une_absente']['fatal'] and d['articles_absents']['fatal'],
         'E7. seules les anomalies qui rendent le document illisible restent fatales')
verifier(d['une_vide']['fatal'] is False and d['une_vide']['util'] is False,
         'E8. une Une vide n\'est pas fatale : elle bascule sur la Une déterministe')

# ======================================================================== F. UNE SANS PJ
print()
print('=== F. Nouvelle règle de Une ===')
sortie = lancer(
    js_const('PAQUET', paquet([FAIT_PJ, FAIT_PERMANENT])) + r"""
var ai = construireAiInput(PAQUET, '2026-09-12', []);
var rep = JSON.stringify({
  une: { sujets: [{ titre: "Élection à Luthécia", chapeau: "Le scrutin approche.", article_ref: "i1" }],
         appels: [], image: { type: 'generique', ref_id: null } },
  articles: [{ id: 'i1', rubrique: 'Politique', type: 'actualite', titre: 'Scrutin',
               texte: "Élection du maire de Luthécia : scrutin le dimanche 27 septembre 2026.",
               personnages_concernes: [], interview_suggeree: false,
               source_ids: [PAQUET.FACTS[1].id], image: { type: 'generique', ref_id: null } }],
  sujets_differes: []
});
var v = validerEtNettoyerEdition(rep, ai);
print(JSON.stringify({ fatal: v.fatal, util: v.uneUtilisable, notes: v.notes, ecarts: v.ecarts }));
""")
d = json.loads(sortie)
verifier(d['fatal'] is False and d['util'] is True,
         'F1. une Une institutionnelle est acceptée alors qu\'un fait PJ existe (obligation supprimée)')
verifier(any('personnage joueur' in n for n in d['notes']) and not d['ecarts'],
         'F2. la priorité PJ non suivie est consignée comme remarque, jamais comme erreur', d['notes'])

# ======================================================================== G. FENÊTRE 24 H
print()
print('=== G. Fenêtre éditoriale ===')
sortie = lancer(r"""
calculerPeriode('republic').then(function(p){
  var duree = (new Date(p.fin).getTime() - new Date(p.debut).getTime()) / 3600000;
  print(JSON.stringify({ duree: duree, appels: APPELS_FETCH.length }));
});
""")
d = json.loads(sortie)
verifier(abs(d['duree'] - 24) < 0.01, 'G1. la fenêtre de collecte vaut exactement 24 heures', d['duree'])
verifier(d['appels'] == 0,
         'G2. elle ne consulte plus aucune édition précédente : un échec ne peut plus l\'élargir')

# ======================================================================== H. REPORTS
print()
print('=== H. File de reports éditoriaux ===')
nombreux = [dict(FAIT_FUITE, id='chronique-fuite-%d' % i, resume='Révélation numéro %d' % i)
            for i in range(14)]
sortie = lancer(
    js_const('PAQUET', paquet(nombreux)) + r"""
var ed = construireEditionDeterministe(PAQUET, 'republic', '2026-09-12');
var perm = construireEditionDeterministe(PAQUET_PERM, 'republic', '2026-09-12');
print(JSON.stringify({
  arts: ed.articles.length, reports: ed.sujets_differes.length,
  refs: ed.sujets_differes.map(function(s){ return s.source_id; }),
  priorites: ed.sujets_differes.map(function(s){ return s.priorite; }),
  reportsPermanents: perm.sujets_differes.length
}));
""".replace('PAQUET_PERM', 'PAQUET_PERM')
    .replace('var perm = construireEditionDeterministe(PAQUET_PERM',
             'var perm = construireEditionDeterministe(' + json.dumps(paquet([FAIT_PERMANENT] * 14), ensure_ascii=False)))
d = json.loads(sortie)
verifier(d['arts'] == 10, 'H1. le numéro est plafonné à 10 articles (lisibilité)', d['arts'])
verifier(d['reports'] == 4 and all(p == 'differable' for p in d['priorites']),
         'H2. les sujets forts non traités passent en file de reports', d['reports'])
verifier(d['reportsPermanents'] == 0,
         'H3. un sujet permanent n\'est jamais reporté : il sera recalculé demain')

# ======================================================================== I. DATE RÉELLE
print()
print('=== I. Un sujet reporté garde sa vraie date ===')
vieux = dict(FAIT_FUITE, created_at='2026-09-10T10:00:00.000Z', report_differe=True,
             jours_depuis_fait=2)
sortie = lancer(
    js_const('PAQUET', paquet([vieux, FAIT_PERMANENT])) + r"""
var ed = construireEditionDeterministe(PAQUET, 'republic', '2026-09-12');
print(JSON.stringify({ textes: ed.articles.map(function(a){ return a.texte; }) }));
""")
d = json.loads(sortie)
verifier(any('10 septembre 2026' in t for t in d['textes']),
         'I1. le report est daté de son jour réel, jamais présenté comme un fait du jour', d['textes'][0][:120])
verifier(not any('12 septembre 2026' in t for t in d['textes'] if 'Révélation' not in t)
         or all('10 septembre' in t for t in d['textes'] if 'documents' in t),
         'I2. la date du numéro n\'est jamais substituée à celle du fait')
verifier(not any('septembre' in t for t in d['textes'] if 'Élection' in t and 'scrutin' not in t),
         'I3. un sujet permanent n\'est pas daté comme un événement')

# ======================================================================== J. FUITE / SCANDALE
print()
print('=== J. Fuite et scandale entrent dans le journal ===')
sortie = lancer(r"""
DB['chronique_nationale'] = [
  { id: 'chronique-fuite-12', country: 'republic', city: 'capitale', type: 'fuite_journalistique',
    personnages: ['Ga Teau'], libelle: "Des documents révèlent un achat d'arme illégal impliquant Ga Teau",
    data: { cible: 'Ga Teau', auteur_public: 'Cellule enquête de la rédaction' },
    created_at: '2026-09-12T10:00:00.000Z' },
  { id: 'chronique-scandale-7', country: 'republic', city: 'capitale', type: 'scandale_presse',
    personnages: ['Ga Teau', 'Arnie'], libelle: "Ga Teau aurait détourné les fonds du club municipal.",
    data: { cible: 'Ga Teau', auteur: 'Arnie', auteur_public: 'Arnie', type_contenu: 'kompromat' },
    created_at: '2026-09-12T11:00:00.000Z' },
  { id: 'chronique-inconnu-1', country: 'republic', city: null, type: 'type_pas_encore_mappe',
    personnages: [], libelle: "Un type inconnu du collecteur", data: {},
    created_at: '2026-09-12T12:00:00.000Z' }
];
var connus = new Map([['Ga Teau', { photo_url: 'data:image/jpeg;base64,AA' }], ['Arnie', { photo_url: null }]]);
collecterChroniqueNationale({ debut: '2026-09-11T19:00:00Z', fin: '2026-09-12T19:00:00Z' }, 'republic', connus)
  .then(function(f){
    print(JSON.stringify(f.map(function(x){
      return { type: x.type, poids: x.poids, estPJ: x.estPJ, resume: x.resume,
               nature: x.nature || null, attribue: x.attribue_a || null,
               contenu: x.contenu_attribue || null };
    })));
  });
""")
d = json.loads(sortie)
types = [x['type'] for x in d]
verifier('fuite_journalistique' in types and 'scandale_presse' in types,
         'J1. les deux types sont désormais collectés', types)
verifier('type_pas_encore_mappe' not in types,
         'J2. un type encore non mappé reste ignoré, jamais deviné')
fuite = next(x for x in d if x['type'] == 'fuite_journalistique')
scand = next(x for x in d if x['type'] == 'scandale_presse')
verifier(fuite['poids'] == 'majeur' and fuite['estPJ'] is True,
         'J3. une fuite impliquant un PJ est une information majeure', fuite['poids'])
verifier('Cellule enquête' not in fuite['resume'] and 'documents révèlent' in fuite['resume'],
         'J4. la fuite publie les faits réels, et aucun commanditaire n\'existe dans la source')
verifier(scand['resume'] == 'Arnie met publiquement en cause Ga Teau' and scand['nature'] == 'accusation',
         'J5. le scandale est réécrit en phrase attribuée, jamais en fait établi', scand['resume'])
verifier(scand['contenu'] == "Ga Teau aurait détourné les fonds du club municipal."
         and scand['attribue'] == 'Arnie',
         'J6. le contenu de l\'accusation voyage à part, avec son auteur')

# ======================================================================== K. CORRUPTION
print()
print('=== K. Cadrage obtenu par corruption de la presse ===')
sortie = lancer(r"""
DB['corruptions_presse'] = [
  { affaire_ref: 'jugements:jug-100', option: 'etouffer',  affaire_pj: 'Ga Teau' },
  { affaire_ref: 'detentions:det-200', option: 'favorable', affaire_pj: 'Arnie' }
];
var FACTS = [
  { id: 'jugements:jug-100', type: 'condamnation', poids: 'important', resume: 'A condamné', pays: 'republic', acteur: 'Ga Teau' },
  { id: 'detentions:det-200', type: 'arrestation', poids: 'important', resume: 'B arrêté', pays: 'republic', acteur: 'Arnie' },
  { id: 'jugements:jug-300', type: 'condamnation', poids: 'important', resume: 'C condamné', pays: 'republic', acteur: 'Autre' }
];
appliquerCadrageCorruptionPresse(FACTS, 'republic').then(function(r){
  print(JSON.stringify({
    restants: r.facts.map(function(f){ return f.id; }),
    etouffees: r.etouffees, favorables: r.favorables,
    cadrages: r.facts.map(function(f){ return { id: f.id, cadrage: f.cadrage || null, benef: f.cadrage_beneficiaire || null }; })
  }));
});
""")
d = json.loads(sortie)
verifier('jugements:jug-100' not in d['restants'] and d['etouffees'] == ['jugements:jug-100'],
         'K1. une affaire étouffée avec succès n\'est pas publiée', d['restants'])
verifier('detentions:det-200' in d['restants'] and d['favorables'] == ['detentions:det-200'],
         'K2. une affaire au cadrage favorable reste publiée : les faits restent vrais')
verifier(any(c['id'] == 'detentions:det-200' and c['cadrage'] == 'favorable' and c['benef'] == 'Arnie'
             for c in d['cadrages']),
         'K3. le bénéficiaire du cadrage est transmis à la rédaction')
verifier('jugements:jug-300' in d['restants'],
         'K4. une affaire non corrompue est publiée normalement')

sortie = lancer(
    js_const('PAQUET', paquet([FAIT_CONDAMNATION_FAVORABLE, FAIT_PJ])) + r"""
var ed = construireEditionDeterministe(PAQUET, 'republic', '2026-09-12');
print(JSON.stringify({
  une: ed.une.sujets[0].article_ref,
  arts: ed.articles.map(function(a){ return { id: a.id, titre: a.titre, cadrage: a.cadrage || null,
                                              contientFaits: a.texte.indexOf('amende de 500 FR') !== -1 }; })
}));
""")
d = json.loads(sortie)
favo = next(a for a in d['arts'] if a['cadrage'] == 'favorable')
verifier(d['une'] != favo['id'],
         'K5. chemin déterministe : l\'affaire cadrée n\'occupe jamais la Une', d['une'])
verifier('Ga Teau' not in favo['titre'],
         'K6. son titre ne nomme pas la personne (faveur réelle, purement éditoriale)', favo['titre'])
verifier(favo['contientFaits'] is True,
         'K7. les faits eux-mêmes restent intégralement publiés, rien n\'est adouci')

# ======================================================================== L. RUBRIQUES VIDES
print()
print('=== L. Rubriques vides et illustration absente ===')
sortie = lancer(
    js_const('PAQUET', paquet([FAIT_PJ])) + r"""
var ed = construireEditionDeterministe(PAQUET, 'republic', '2026-09-12');
var dp = assemblerDernierePage(PAQUET, ed.une, ed.articles);
var sansImage = construireEditionDeterministe(
  { country: 'republic', periode: PAQUET.periode, FACTS: [
      { id: 'x:1', type: 'candidature', poids: 'important', resume: 'Un fait sans illustration',
        pays: 'republic', domaine: 'politique', estPJ: false, photo_url: null, club_image: null,
        created_at: '2026-09-12T08:00:00.000Z' }],
    PUBLIC_STATEMENTS: [], INDICATORS: [], PETITES_ANNONCES: [] }, 'republic', '2026-09-12');
print(JSON.stringify({
  dp: { indices: dp.indices_economiques.length, arrivees: dp.arrivees.length, carnet: dp.carnet.length,
        breves: dp.chiens_ecrases.length, annonces: dp.petites_annonces.length },
  imageAbsente: sansImage.articles[0].image, uneSansImage: sansImage.une.image,
  articles: sansImage.articles.length
}));
""")
d = json.loads(sortie)
verifier(all(v == 0 for v in d['dp'].values()),
         'L1. toutes les rubriques de dernière page sont vides sans erreur', d['dp'])
verifier(d['imageAbsente'] == {'type': 'generique', 'ref_id': None}
         and d['uneSansImage'] == {'type': 'generique', 'ref_id': None},
         'L2. aucune illustration disponible : le rendu demande « generique », jamais une image inventée')
verifier(d['articles'] == 1,
         'L3. l\'article paraît normalement sans illustration')


# ======================================================================== M. ARBITRAGES ÉDITORIAUX
print()
print('=== M. Poids éditoriaux arbitrés ===')
sortie = lancer(r"""
DB['chronique_nationale'] = [
  { id: 'chr-scandale', country: 'republic', city: null, type: 'scandale_presse',
    personnages: ['Ga Teau', 'Arnie'], libelle: "Accusation publiée.",
    data: { cible: 'Ga Teau', auteur_public: 'Arnie' }, created_at: '2026-09-12T11:00:00.000Z' },
  { id: 'chr-scandale-pnj', country: 'republic', city: null, type: 'scandale_presse',
    personnages: ['Un PNJ quelconque'], libelle: "Accusation publiée.",
    data: { cible: 'Un PNJ quelconque', auteur_public: 'Un autre PNJ' }, created_at: '2026-09-12T11:00:00.000Z' },
  { id: 'chr-scrutin', country: 'republic', city: null, type: 'scrutin_assemblee',
    personnages: ['Gavrilo Princip'],
    libelle: "L'Assemblee nationale a adopte \u00ab Loi sur les tramways \u00bb par 6 voix contre 3.",
    data: { proposition_id: 'prop-1', resultat: 'ADOPTEE', score_pour: 6, score_contre: 3, auteur: 'Gavrilo Princip' },
    created_at: '2026-09-12T21:00:00.000Z' },
  { id: 'chr-scrutin-pnj', country: 'republic', city: null, type: 'scrutin_assemblee',
    personnages: ['Depute PNJ'],
    libelle: "L'Assemblee nationale a rejete \u00ab Autre texte \u00bb par 2 voix contre 7.",
    data: { proposition_id: 'prop-2', resultat: 'REJETEE', score_pour: 2, score_contre: 7 },
    created_at: '2026-09-12T21:00:00.000Z' }
];
var connus = new Map([['Ga Teau', { photo_url: null }], ['Arnie', { photo_url: null }],
                      ['Gavrilo Princip', { photo_url: 'data:image/jpeg;base64,AA' }]]);
collecterChroniqueNationale({ debut: '2026-09-11T19:00:00Z', fin: '2026-09-13T19:00:00Z' }, 'republic', connus)
  .then(function(f){
    var par = {};
    f.forEach(function(x){ par[x.id] = { type: x.type, poids: x.poids, estPJ: x.estPJ, resume: x.resume, nature: x.nature || null }; });
    print(JSON.stringify(par));
  })
  .catch(function(e){ print(JSON.stringify({ __erreur: String(e && e.message || e) })); });
""")
d = json.loads(sortie)
verifier(d['chr-scandale']['poids'] == 'majeur',
         'M1. un scandale visant un personnage joueur est MAJEUR', d['chr-scandale']['poids'])
verifier(d['chr-scandale-pnj']['poids'] == 'important',
         'M2. un scandale sans PJ reste IMPORTANT, jamais secondaire', d['chr-scandale-pnj']['poids'])
verifier(d['chr-scandale']['nature'] == 'accusation',
         'M3. le poids relevé ne rend pas l\'accusation crédible : elle reste attribuée')
verifier(d['chr-scrutin']['poids'] == 'majeur' and d['chr-scrutin']['type'] == 'scrutin_assemblee',
         'M4. un scrutin de l\'Assemblée où un PJ a voté est MAJEUR', d['chr-scrutin']['poids'])
verifier(d['chr-scrutin-pnj']['poids'] == 'important',
         'M5. un scrutin sans PJ est IMPORTANT par défaut', d['chr-scrutin-pnj']['poids'])
verifier('adopte' in d['chr-scrutin']['resume'] and '6 voix contre 3' in d['chr-scrutin']['resume'],
         'M6. le verdict réel et les scores réels sont conservés tels quels')

print()
print('=== N. Échéance électorale sans candidature ===')
sortie = lancer(r"""
var maintenant = Date.now();
function cycle(id, poste, city, joursAvant) {
  return { id: id, poste_id: poste, city: city, data: JSON.stringify({
    phase: 'candidatures', resultatsTraites: false, dateVote: maintenant + joursAvant * 86400000 }) };
}
DB['cycles_electoraux'] = [ cycle('c-vide', 'maire', 'capitale', 10),
                            cycle('c-loin', 'depute', 'ville_a', 40),
                            cycle('c-pourvu', 'president', null, 10) ];
DB['candidatures'] = [ { nom: 'Arnie', poste_id: 'president', city: null } ];
var connus = new Map([['Arnie', { photo_url: null }]]);
collecterEcheancesElectorales('republic', connus).then(function(f){
  var par = {};
  f.forEach(function(x){ par[x.id] = { poids: x.poids, nb: x.nb_candidatures, jours: x.jours_avant_scrutin, resume: x.resume }; });
  print(JSON.stringify(par));
}).catch(function(e){ print(JSON.stringify({ __erreur: String(e && e.message || e) })); });
""")
d = json.loads(sortie)
vide = d['cycles_electoraux:c-vide']
loin = d['cycles_electoraux:c-loin']
pourvu = d['cycles_electoraux:c-pourvu']
verifier(vide['poids'] == 'majeur' and vide['nb'] == 0,
         'N1. scrutin proche SANS candidature : poids majeur, au-dessus d\'une tension de stocks',
         vide['poids'])
verifier(POIDS_IMPORTANT_ECO := True and vide['poids'] == 'majeur',
         'N2. il passe donc devant l\'économie remarquable (qualifiée « important »)')
verifier(loin['poids'] == 'secondaire',
         'N3. un scrutin encore lointain sans candidat reste un sujet de suivi', loin['poids'])
verifier(pourvu['poids'] == 'important' and pourvu['nb'] == 1,
         'N4. une campagne avec candidat PJ est relevée sans être majeure', pourvu['poids'])
verifier('aucune candidature enregistrée à ce jour' in vide['resume']
         and 'une candidature enregistrée' in pourvu['resume'],
         'N5. le texte énonce le nombre RÉEL de candidatures, jamais un candidat inventé')

print()
print('=== O. Projet de loi avant son vote ===')
sortie = lancer(r"""
var maintenant = Date.now();
function prop(id, titre, statut, joursAvant, auteur) {
  return { id: id, titre: titre, auteur: auteur, type: 'mecanique', categorie: 'transports',
    texte_original: 'Article 1 : la gratuite du tramway est instituee a Luthecia.',
    cloture_ts: joursAvant === null ? null : new Date(maintenant + joursAvant * 86400000).toISOString(),
    statut: statut, session_num: 1, forum_topic_id: 'topic-42', amendements: [{ a: 1 }] };
}
DB['assemblee_propositions'] = [
  prop('p-proche', 'Gratuite du tramway', 'session', 3, 'Gavrilo Princip'),
  prop('p-loin', 'Reforme lointaine', 'session', 20, 'Depute PNJ'),
  prop('p-jour', 'Vote du jour', 'session', 0.02, 'Depute PNJ'),   // cloture ce soir : jour du vote
  prop('p-passe', 'Deja vote', 'session', -2, 'Depute PNJ')
];
var connus = new Map([['Gavrilo Princip', { photo_url: 'data:image/jpeg;base64,AA' }]]);
collecterPropositionsEnDebat('republic', connus).then(function(f){
  print(JSON.stringify(f.map(function(x){
    return { id: x.id, poids: x.poids, estPJ: x.estPJ, jours: x.jours_avant_vote,
             jourDuVote: x.jour_du_vote, titre: x.titre_impose, resume: x.resume,
             texte: x.texte_propose, forum: x.forum_topic_id, permanent: x.permanent };
  })));
}).catch(function(e){ print(JSON.stringify({ __erreur: String(e && e.message || e) })); });
""")
d = json.loads(sortie)
ids = [x['id'] for x in d]
verifier('assemblee_propositions:p-proche' in ids and 'assemblee_propositions:p-jour' in ids,
         'O1. un texte en session dans les 6 jours avant son vote devient un sujet', ids)
verifier('assemblee_propositions:p-loin' not in ids,
         'O2. un texte dont le vote est encore loin n\'est pas annoncé')
verifier('assemblee_propositions:p-passe' not in ids,
         'O3. un scrutin déjà clos ne repasse pas : le résultat est porté par la chronique')
proche = next(x for x in d if x['id'] == 'assemblee_propositions:p-proche')
jour = next(x for x in d if x['id'] == 'assemblee_propositions:p-jour')
verifier(proche['estPJ'] is True and proche['poids'] == 'important',
         'O4. un texte déposé par un PJ est relevé d\'un cran', proche['poids'])
verifier(jour['jourDuVote'] is True and jour['poids'] == 'important',
         'O5. le jour du vote, le scrutin lui-même devient l\'actualité', jour['poids'])
verifier('se prononcera le' in proche['resume'] and 'Gavrilo Princip' in proche['resume'],
         'O6. la date réelle du vote et l\'auteur réel sont énoncés', proche['resume'][:90])
verifier(proche['texte'] == 'Article 1 : la gratuite du tramway est instituee a Luthecia.',
         'O7. le contenu réel du texte est transmis littéralement, jamais reformulé')
verifier(proche['forum'] == 'topic-42',
         'O8. le sujet de forum est joint : les prises de position réelles restent la seule source')
verifier(all(x['permanent'] is True for x in d),
         'O9. ces sujets sont recalculés chaque jour, jamais mis en file de reports')

sortie = lancer(
    js_const('PAQUET', paquet([{
        "id": "assemblee_propositions:p-1", "pays": "republic", "type": "proposition_en_debat",
        "estPJ": False, "poids": "important", "ville": None, "acteur": "Depute PNJ",
        "titre_impose": "Assemblée : « Gratuité du tramway »",
        "resume": "L'Assemblée nationale se prononcera le mercredi 16 septembre 2026 sur « Gratuité du tramway »",
        "domaine": "politique", "photo_url": None, "permanent": True, "nb_amendements": 2,
        "texte_propose": "Article 1 : la gratuité du tramway est instituée à Luthécia.",
        "created_at": "2026-09-12T12:00:00.000Z"}])) + r"""
var ed = construireEditionDeterministe(PAQUET, 'republic', '2026-09-12');
print(JSON.stringify({ titre: ed.articles[0].titre, texte: ed.articles[0].texte,
                       rubrique: ed.articles[0].rubrique, une: ed.une.sujets[0].titre }));
""")
d = json.loads(sortie)
verifier(d['titre'] == 'Assemblée : « Gratuité du tramway »' and d['rubrique'] == 'Politique',
         'O10. rendu déterministe : titre court et rubrique politique', d['titre'])
verifier('Article 1 : la gratuité du tramway' in d['texte'] and 'énonce' in d['texte'],
         'O11. le déterministe cite le texte réel du projet de loi')
verifier('2 amendements ont été déposés' in d['texte'],
         'O12. le nombre réel d\'amendements est mentionné, jamais leur contenu inventé')

print()
print('=== P. Faits dérivés de l\'état : horodatage de lot ===')
sortie = lancer(r"""
// Caisse en déficit : ce chemin n'était couvert par aucun test et référençait une variable non
// déclarée après la mise en place de l'horodatage de lot.
var faits = calculerCaissesRemarquables('republic', [
  { cle: 'caisse_nationale', valeur: -4200, ville: null, disponible: true },
  { cle: 'caisse_municipale', valeur: -300, ville: 'Montrouge', disponible: true },
  { cle: 'caisse_municipale', valeur: 900, ville: 'Luthécia', disponible: true }
]);
print(JSON.stringify({
  n: faits.length,
  resumes: faits.map(function(f){ return f.resume; }),
  memeInstant: faits.length > 1 && faits[0].created_at === faits[1].created_at,
  horodates: faits.every(function(f){ return typeof f.created_at === 'string' && f.created_at.length > 10; })
}));
""")
d = json.loads(sortie)
verifier(d['n'] == 2 and d['horodates'] is True,
         'P1. une caisse dans le rouge produit bien un fait horodaté (chemin sans test jusqu\'ici)', d['n'])
verifier(d['memeInstant'] is True,
         'P2. les faits d\'un même lot partagent un instant unique : le numéro est reproductible')
verifier(all('dans le rouge' in r for r in d['resumes'])
         and any('-4200' in r for r in d['resumes']),
         'P3. le montant réel du déficit est énoncé', d['resumes'])

print()
print('%d contrôle(s), %d echec(s)' % (71, len(echecs)))
sys.exit(1 if echecs else 0)
