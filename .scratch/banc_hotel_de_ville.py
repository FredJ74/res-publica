# BANC — HOTEL DE VILLE : parcours de candidature et regroupements (16 septembre 2026).
#
# Charge les VRAIS modules dans JavaScriptCore et verifie que les ordres, les regroupements et le
# parcours de candidature sont coherents DANS LES TROIS VILLES -- aucune mecanique municipale ne
# doit etre propre a Luthecia.

import json, os, subprocess, sys, tempfile

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JSC = '/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc'
resultats = []

HARNAIS = r"""
var _els = {};
function _el(id) {
  if (!_els[id]) _els[id] = { id: id, textContent: '', innerHTML: '', value: '', style: {},
                              classList: { _c: {}, add: function (c) { this._c[c] = 1; },
                                           remove: function (c) { delete this._c[c]; },
                                           contains: function (c) { return !!this._c[c]; } } };
  return _els[id];
}
var document = { getElementById: _el, querySelector: function () { return null; },
                 querySelectorAll: function () { return []; }, addEventListener: function () {},
                 body: { appendChild: function () {} },
                 createElement: function () { return { style: {}, classList: { add: function(){}, remove: function(){} },
                                                       addEventListener: function(){}, appendChild: function(){} }; } };
var window = { addEventListener: function () {}, location: { search: '' } };
var localStorage = { getItem: function () { return null; }, setItem: function () {}, removeItem: function () {} };
var navigator = { language: 'fr' };
function showToast() {} function addJournalEntry() {} function updateUI() {}
function sbRpc() { return Promise.resolve(null); }
function sbGet() { return Promise.resolve([]); }

load('%(racine)s/data.js');
load('%(racine)s/plateau-core.js');
load('%(racine)s/plateau-politique.js');
load('%(racine)s/plateau-router.js');

function ordresDe(b, r) {
  var p = (BUILDINGS[b] && BUILDINGS[b].rooms[r]) || {};
  return (p.orders || []).map(function (o) { return o.fn; });
}
// Les salles de vote des trois villes, la ou vivait « Se porter candidat ».
function toutesLesSallesDeVote() {
  var out = [];
  Object.keys(BUILDINGS).forEach(function (b) {
    Object.keys(BUILDINGS[b].rooms || {}).forEach(function (r) {
      if (r.indexOf('election') >= 0 || r.indexOf('vote') >= 0) out.push(b + '/' + r);
    });
  });
  return out;
}
function tousLesOrdres() {
  var out = [];
  Object.keys(BUILDINGS).forEach(function (b) {
    Object.keys(BUILDINGS[b].rooms || {}).forEach(function (r) {
      ((BUILDINGS[b].rooms[r] || {}).orders || []).forEach(function (o) { out.push(o.fn); });
    });
  });
  return out;
}

var s = {};
s.tous = tousLesOrdres();
s.sallesDeVote = toutesLesSallesDeVote();
s.mairieCapitale = { maire: ordresDe('mairie-capitale', 'bureau_maire'),
                     adjoint: ordresDe('mairie-capitale', 'bureau_maire_adjoint'),
                     hall: ordresDe('mairie-capitale', 'hall_mairie') };
// Le batiment partage des autres villes nomme son bureau du maire 'bureau_maire_local'.
s.mairieGenerique = { maire: ordresDe('mairie', 'bureau_maire_local'),
                      adjoint: ordresDe('mairie', 'bureau_maire_adjoint') };
// Les salles de vote de Montrouge et Port-Sainte-Marie vivent dans roomsExtra, fusionne a
// l'entree dans la ville : on les lit donc a la source plutot que dans BUILDINGS.rooms.
// Les pieces supplementaires des villes vivent dans WORLD[pays][ville].batiments[].roomsExtra.
s.ordresRoomsExtra = [];
s.villesAvecSalleElections = [];
Object.keys(WORLD || {}).forEach(function (pays) {
  Object.keys(WORLD[pays] || {}).forEach(function (ville) {
    var v = WORLD[pays][ville];
    var ctx = (v && v.buildingContext) || {};
    Object.keys(ctx).forEach(function (batId) {
      var extra = (ctx[batId] && ctx[batId].roomsExtra) || {};
      Object.keys(extra).forEach(function (r) {
        if (r === 'salle_elections') s.villesAvecSalleElections.push(pays + '/' + ville);
        ((extra[r] || {}).orders || []).forEach(function (o) { s.ordresRoomsExtra.push(o.fn); });
      });
    });
  });
});
s.fonctions = {
  gestionPoste: typeof ouvrirGestionPosteNomme === 'function',
  redaction: typeof ouvrirRedactionProgramme === 'function',
  publier: typeof publierProgrammeCandidature === 'function',
  voirProgramme: typeof ouvrirProgrammeCandidat === 'function',
  actions: (typeof ACTIONS_POSTE_NOMME !== 'undefined') ? ACTIONS_POSTE_NOMME : null
};
// L'ordre de depot garde son cout : c'est lui que le serveur facture.
s.coutDepot = (typeof ORDRE_DEPOT_CANDIDATURE !== 'undefined') ? ORDRE_DEPOT_CANDIDATURE : null;
print(JSON.stringify(s));
"""


def verifier(nom, cond, detail=''):
    resultats.append((bool(cond), nom, str(detail)[:160]))


def main():
    f = tempfile.NamedTemporaryFile('w', suffix='.js', delete=False, encoding='utf-8')
    f.write(HARNAIS % {'racine': RACINE}); f.close()
    try:
        p = subprocess.run([JSC, f.name], capture_output=True, text=True, timeout=120)
    finally:
        os.unlink(f.name)
    if p.returncode != 0:
        print('ECHEC DE CHARGEMENT :'); print((p.stdout + p.stderr)[-2000:]); return 1
    d = json.loads(p.stdout.strip().splitlines()[-1])

    # ---- L'ancien point d'entree a disparu, PARTOUT ----
    verifier('« Se porter candidat » ne figure plus dans aucun ordre du jeu',
             'se_porter_candidat' not in d['tous'], [o for o in d['tous'] if 'candidat' in o][:6])
    verifier('les salles de vote existent toujours', len(d['sallesDeVote']) >= 1, d['sallesDeVote'])
    verifier('« Se porter candidat » a disparu aussi des salles des autres villes',
             'se_porter_candidat' not in d['ordresRoomsExtra'],
             [o for o in d['ordresRoomsExtra'] if 'candidat' in o][:6])
    verifier('les autres villes gardent leurs ordres electoraux',
             'voter_election' in d['ordresRoomsExtra'] and 'consulter_elections' in d['ordresRoomsExtra'],
             d['ordresRoomsExtra'][:8])
    verifier('les trois villes de Republia ont bien leur salle des elections',
             len(d['villesAvecSalleElections']) >= 2, d['villesAvecSalleElections'])

    # ---- Les regroupements, dans les DEUX batiments (Luthecia et les autres villes) ----
    for etiquette, m in (('Luthecia', d['mairieCapitale']), ('mairie generique', d['mairieGenerique'])):
        verifier('%s : un seul bouton Entrepot' % etiquette,
                 'entrepot_direction' in m['adjoint']
                 and not any(f in m['adjoint'] for f in
                             ('gerer_candidature_directeur_entrepot', 'nommer_directeur_entrepot',
                              'revoquer_directeur_entrepot')), m['adjoint'])
        verifier('%s : un seul bouton Maire adjoint' % etiquette,
                 'maire_adjoint_gestion' in m['maire']
                 and not any(f in m['maire'] for f in
                             ('gerer_candidature_maire_adjoint', 'revoquer_maire_adjoint')), m['maire'])
        verifier('%s : un seul bouton Commissaire' % etiquette,
                 'commissaire_gestion' in m['maire']
                 and not any(f in m['maire'] for f in ('nommer_commissaire', 'revoquer_commissaire')),
                 m['maire'])

    verifier('le calendrier electoral reste a l accueil',
             'calendrier_elections' in d['mairieCapitale']['hall'], d['mairieCapitale']['hall'])

    # ---- Le nouveau parcours existe ----
    for cle, libelle in (('gestionPoste', 'ecran de gestion d un poste nomme'),
                         ('redaction', 'ouverture de la redaction du programme'),
                         ('publier', 'publication valant candidature'),
                         ('voirProgramme', 'acces au programme d un candidat')):
        verifier('fonction presente : %s' % libelle, d['fonctions'][cle], d['fonctions'][cle])

    # ---- Les couts d'origine sont conserves ----
    a = d['fonctions']['actions'] or {}
    verifier('Entrepot : les trois actions et leurs couts d origine',
             a.get('directeur_entrepot') == {'candidatures': 1, 'nommer': 3, 'revoquer': 1},
             a.get('directeur_entrepot'))
    verifier('Maire adjoint : candidatures et revocation, sans nomination directe',
             a.get('maire_adjoint') == {'candidatures': 1, 'nommer': None, 'revoquer': 1},
             a.get('maire_adjoint'))
    verifier('Commissaire : nomination et revocation, sans candidatures',
             a.get('commissaire') == {'candidatures': None, 'nommer': 3, 'revoquer': 1},
             a.get('commissaire'))
    verifier('le depot de candidature coute toujours 2 PA',
             d['coutDepot'] and d['coutDepot'].get('pa') == 2
             and d['coutDepot'].get('fn') == 'deposer_candidature', d['coutDepot'])

    ko = [r for r in resultats if not r[0]]
    for ok, nom, detail in resultats:
        if not ok:
            print('  KO  %-58s %s' % (nom, detail))
    print('\n%d/%d' % (len(resultats) - len(ko), len(resultats)))
    return 1 if ko else 0


if __name__ == '__main__':
    sys.exit(main())
