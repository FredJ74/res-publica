#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SONDE — « Prendre l'avion » sans reaction (Centre multimodal de Luthecia, 14 septembre 2026).

Execute le VRAI doOrder sur l'ordre prendre_avion, avec le vrai data.js, et compare pas a pas
avec prendre_train (qui, lui, fonctionne). Toute exception est capturee et affichee : c'est
precisement ce que le navigateur avale en silence quand un handler casse.

Aucune base touchee, aucun reseau.
"""
import os, re, subprocess, sys, tempfile

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JSC = '/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc'


def lire(f):
    with open(os.path.join(RACINE, f), encoding='utf-8') as fh:
        return fh.read()


def extraire(src, nom, genre='function'):
    m = re.search((r'^(async )?function ' if genre == 'function' else r'^const ')
                  + re.escape(nom) + (r'\(' if genre == 'function' else r'\s*='), src, re.M)
    if not m:
        raise SystemExit('introuvable : ' + nom)
    suite = re.compile(r'^(async function |function |const |let |var |// =====|export )', re.M).search(src, m.end())
    return src[m.start(): suite.start() if suite else len(src)].rstrip() + '\n'


def en_expression(code):
    return re.sub(r'^(async )?function (\w+)\(',
                  lambda m: 'var %s = %sfunction %s(' % (m.group(2), m.group(1) or '', m.group(2)),
                  code, flags=re.M)


R = lire('plateau-router.js')
N = lire('plateau-navigation.js')

SOURCES = ''.join(en_expression(x) for x in [
    extraire(N, 'TRANSPORT_CONFIG', 'const'),
    extraire(N, 'VILLES_PAR_EMPIRE', 'const'),
    extraire(N, 'EMPIRES_CONFIG', 'const'),
    extraire(N, 'ouvrirModalTransport'),
    extraire(N, 'doAllerDouanesAeroport'),
    extraire(R, 'doOrder'),
]).replace('const ', 'var ')

BANC = r"""
var journal = { toasts: [], modalsOuvertes: [], html: {}, deplacements: [] };

function fauxElement(id) {
  return { id: id,
    style: {},
    classList: { add: function (c) { if (c === 'open') journal.modalsOuvertes.push(id); },
                 remove: function () {}, contains: function () { return false; } },
    set innerHTML(v) { journal.html[this.id] = v; }, get innerHTML() { return journal.html[this.id] || ''; },
    set textContent(v) { journal.html[this.id + ':texte'] = v; }, get textContent() { return ''; },
    addEventListener: function(){}, removeEventListener: function(){} };
}
var _els = {};
var document = { getElementById: function (id) { if (!_els[id]) _els[id] = fauxElement(id); return _els[id]; },
                 querySelectorAll: function () { return []; }, querySelector: function () { return null; } };
var window = this;
function showToast(t, m, ok) { journal.toasts.push(t + ' | ' + m); }
function addJournalEntry(){} function updateUI(){} function closePnjModal(){}

%DATA%

var COUNTRIES_REF = COUNTRIES;

// Tout ce que doOrder appelle et qui n'est pas dans notre perimetre devient un bouchon muet,
// SAUF ouvrirModalTransport : c'est lui qu'on teste.
var BANC_NOMS = ['journal','document','window','showToast','addJournalEntry','updateUI','state',
                 'TRANSPORT_CONFIG','VILLES_PAR_EMPIRE','EMPIRES_CONFIG','ouvrirModalTransport',
                 'doOrder','COUNTRIES','BUILDINGS','WORLD','ORDER_EFFECTS','Math','JSON','Object',
                 'String','Number','Array','Promise','setTimeout','print','fauxElement','_els',
                 'COUNTRIES_REF','BANC_NOMS','bac','essai','state','TEST_MODE','resultats'];
var bac = new Proxy(this, {
  has: function (t, k) { return typeof k === 'string' && BANC_NOMS.indexOf(k) === -1 && !(k in globalThis) ? true : (k in t); },
  get: function (t, k) {
    if (k in t) return t[k];
    return function () { return undefined; };   // bouchon muet
  }
});

var TEST_MODE = false;
var state = null;

// Gardes que doOrder consulte AVANT de router : on les rend explicitement permissives, pour
// que la sonde atteigne reellement la ligne de routage du transport. Ce ne sont pas elles
// qu'on teste ici.
var estOrdreMedicalReserveAuPatient = function () { return false; };
var verdictRoleOrdre = function () { return { bloque: false, message: '' }; };
var definitionOrdreDansPiece = function () { return null; };
var refuserSiGele = function () { return false; };
var refuserSiSurcharge = function () { return false; };
var getFondsDisponiblesOrdinaires = function () { return (state && state.liquide) || 0; };
var ORDRES_BUDGET_INSTITUTION = [];
var queteAccueilNotifierOrdre = function () {};
// Espion sur le seul effet de doAllerDouanesAeroport : le changement de piece.
var enterRoom = function (b, r) { journal.deplacements.push(b + '/' + r); };
BANC_NOMS = BANC_NOMS.concat(['estOrdreMedicalReserveAuPatient','verdictRoleOrdre',
  'definitionOrdreDansPiece','refuserSiGele','refuserSiSurcharge','getFondsDisponiblesOrdinaires',
  'ORDRES_BUDGET_INSTITUTION','queteAccueilNotifierOrdre','enterRoom','doAllerDouanesAeroport']);

with (bac) {
%SOURCES%

function essai(fn, pa, cost, libelle, etat) {
  journal = { toasts: [], modalsOuvertes: [], html: {}, deplacements: [] };
  state = etat;
  var erreur = null;
  try { doOrder(fn, pa, cost, libelle, '', 100); }
  catch (e) { erreur = (e && e.message) ? e.message : String(e); }
  return { ordre: fn, erreur: erreur, toasts: journal.toasts, deplacements: journal.deplacements,
           modals: journal.modalsOuvertes,
           corps: (journal.html['postes-body'] || '').slice(0, 260),
           titre: journal.html['postes-modal-title:texte'] || '' };
}

function joueur(o) {
  o = o || {};
  return { char: { name: 'zztest', country: 'republic' },
           country: 'republic', currentCity: 'capitale',
           currentBuilding: 'centre-multinodal-luthecia', currentRoom: o.piece || 'zone_embarquement',
           pa: o.pa === undefined ? 10 : o.pa,
           liquide: o.liquide === undefined ? 5000 : o.liquide,
           banque: 0, arg: o.liquide === undefined ? 5000 : o.liquide,
           comptesBancaires: {}, inventory: [], douanePassee: true };
}

var resultats = [];
resultats.push(essai('aller_douanes_aeroport', 0, 0, "Prendre l'avion (hall)", joueur({ piece: 'hall_gare' })));
resultats.push(essai('prendre_train', 2, 75,  'Prendre le train', joueur()));
resultats.push(essai('prendre_bus_taxi', 1, 150, 'Prendre le bus',  joueur()));
resultats.push(essai('prendre_avion', 2, 300, "Prendre l'avion",   joueur()));
resultats.push(essai('prendre_bateau', 5, 100, 'Prendre le bateau', joueur()));
resultats.push(essai('prendre_avion', 2, 300, "Prendre l'avion (0 PA)",   joueur({ pa: 0 })));
resultats.push(essai('prendre_avion', 2, 300, "Prendre l'avion (sans fonds)", joueur({ liquide: 10 })));

print(JSON.stringify(resultats, null, 1));
}
"""


def main():
    if not os.path.exists(JSC):
        print("JavaScriptCore introuvable", file=sys.stderr)
        return 2
    js = BANC.replace('%DATA%', lire('data.js')).replace('%SOURCES%', SOURCES)
    with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False, encoding='utf-8') as fh:
        fh.write(js)
        chemin = fh.name
    p = subprocess.run([JSC, chemin], capture_output=True, text=True, timeout=120)
    os.unlink(chemin)
    if p.returncode != 0 or not p.stdout.strip():
        print("EXECUTION IMPOSSIBLE :\n%s\n%s" % (p.stdout[-3000:], p.stderr[-3000:]))
        return 2
    print(p.stdout)
    return 0


if __name__ == "__main__":
    sys.exit(main())
