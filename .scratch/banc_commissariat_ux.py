# BANC — COMMISSARIAT, PRESENTATION (16 septembre 2026).
#
# Deux changements d'UX se verifient sur le code REEL, charge dans JavaScriptCore :
#   - « Consulter la caisse » et « Accepter le transfert a la caserne » ne sont plus des ordres ;
#   - le transfert est propose par une fenetre contextuelle, une fois par jour de jeu, et ses
#     conditions sont exactement celles du handler d'origine.
#
# Ce banc ne touche a aucune donnee : il n'inspecte que les structures et le comportement de
# peutEtreIncorpore / proposerTransfertCaserne, avec un DOM minimal bouchonne.

import json, os, subprocess, sys, tempfile

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JSC = '/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc'
resultats = []

HARNAIS = r"""
// --- DOM minimal : de quoi laisser la fenetre s'ouvrir sans navigateur ---
var _els = {};
function _el(id) {
  if (!_els[id]) _els[id] = { id: id, textContent: '', innerHTML: '', style: {},
                              classList: { _c: {}, add: function (c) { this._c[c] = 1; },
                                           remove: function (c) { delete this._c[c]; },
                                           contains: function (c) { return !!this._c[c]; } } };
  return _els[id];
}
var document = { getElementById: _el, querySelector: function () { return null; },
                 querySelectorAll: function () { return []; },
                 addEventListener: function () {}, body: { appendChild: function () {} },
                 createElement: function () { return { style: {}, classList: { add: function(){}, remove: function(){} },
                                                       addEventListener: function(){}, appendChild: function(){} }; } };
var window = { addEventListener: function () {}, location: { search: '' } };
var localStorage = { getItem: function () { return null; }, setItem: function () {}, removeItem: function () {} };
var navigator = { language: 'fr' };
var sauvegardes = 0;
function sbSavePersonnage() { sauvegardes++; return Promise.resolve(); }
function showToast() {} function addJournalEntry() {} function updateUI() {}
function addMailNotification() {} function addExternalEvent() {}
function sbUpdate() { return Promise.resolve(); }
function enterBuilding() {} function enterRoom() {}
function deduireCoutOrdre() { return Promise.resolve({ ok: true }); }
function signalerRefusCout() {}
// `state` n'est PAS declare ici : plateau-core.js le declare lui-meme (let state = ...), et une
// seconde declaration globale ferait echouer le chargement. On l'assigne apres le load.

load('%(racine)s/data.js');
load('%(racine)s/plateau-core.js');
load('%(racine)s/plateau-navigation.js');
load('%(racine)s/plateau-politique.js');

// Les modules redefinissent ces fonctions : on rebouchonne APRES le chargement, sinon les vraies
// (addJournalEntry ecrit dans le DOM du journal, sbSavePersonnage appelle le reseau) s'executent.
addJournalEntry = function () {};
showToast = function () {};
updateUI = function () {};
addExternalEvent = function () {};
addMailNotification = function () {};
sbSavePersonnage = function () { sauvegardes++; return Promise.resolve(); };
sbUpdate = function () { return Promise.resolve(); };
enterBuilding = function () {};
enterRoom = function () {};

// ------------------------------------------------------------------ mesures
function ordresDe(buildingId, roomId) {
  var r = (BUILDINGS[buildingId] && BUILDINGS[buildingId].rooms[roomId]) || {};
  return (r.orders || []).map(function (o) { return o.fn; });
}

var sortie = { ordres: {}, popup: {} };
sortie.ordres.commissariat_accueil = ordresDe('commissariat', 'accueil_police');
sortie.ordres.commissariat_prison  = ordresDe('commissariat', 'prison');
sortie.ordres.local_accueil        = ordresDe('commissariat-local', 'accueil_loc');
sortie.ordres.local_geoles         = ordresDe('commissariat-local', 'geoles');
sortie.ordres.bureau_min_int       = ordresDe('palais-gouvernement', 'bureau_min_int');

// --- conditions d'eligibilite, reprises telles quelles ---
function essai(etat) {
  state = Object.assign({ char: {}, day: 5 }, etat);
  return peutEtreIncorpore();
}
sortie.popup.libre        = essai({ estEmprisonne: null, char: { requisition: { statut: 'deserteur' } }, mobilisationNationaleCache: true });
sortie.popup.pas_deserteur = essai({ estEmprisonne: { jours: 2 }, char: { requisition: { statut: 'incorpore' } }, mobilisationNationaleCache: true });
sortie.popup.sans_mobilisation = essai({ estEmprisonne: { jours: 2 }, char: { requisition: { statut: 'deserteur' } }, mobilisationNationaleCache: false });
sortie.popup.eligible     = essai({ estEmprisonne: { jours: 2 }, char: { requisition: { statut: 'deserteur' } }, mobilisationNationaleCache: true });

// --- une seule fois par jour de jeu, memorisee SUR LE PERSONNAGE ---
state = { estEmprisonne: { jours: 2 }, day: 5, mobilisationNationaleCache: true,
          char: { requisition: { statut: 'deserteur' } } };
_el('modal-postes').classList._c = {};
proposerTransfertCaserne();
sortie.popup.ouverte_1 = _el('modal-postes').classList.contains('open');
sortie.popup.jour_memorise = state.char.transfertCaserneProposeJour;
sortie.popup.sauvegardee = sauvegardes > 0;

_el('modal-postes').classList.remove('open');
proposerTransfertCaserne();
sortie.popup.ouverte_2_meme_jour = _el('modal-postes').classList.contains('open');

state.day = 6;
_el('modal-postes').classList.remove('open');
proposerTransfertCaserne();
sortie.popup.ouverte_jour_suivant = _el('modal-postes').classList.contains('open');

// refus : ferme, et ne revient pas le meme jour
refuserTransfertCaserne();
sortie.popup.fermee_apres_refus = !_el('modal-postes').classList.contains('open');
proposerTransfertCaserne();
sortie.popup.revient_apres_refus = _el('modal-postes').classList.contains('open');

// plus eligible : plus rien
state.day = 7; state.estEmprisonne = null;
_el('modal-postes').classList.remove('open');
proposerTransfertCaserne();
sortie.popup.ouverte_non_eligible = _el('modal-postes').classList.contains('open');

sortie.popup.boutons = (_el('postes-body').innerHTML.indexOf('accepterTransfertCaserne') >= 0)
                    && (_el('postes-body').innerHTML.indexOf('refuserTransfertCaserne') >= 0);
print(JSON.stringify(sortie));
"""


def verifier(nom, cond, detail=''):
    resultats.append((bool(cond), nom, str(detail)[:140]))


def main():
    f = tempfile.NamedTemporaryFile('w', suffix='.js', delete=False, encoding='utf-8')
    f.write(HARNAIS % {'racine': RACINE})
    f.close()
    try:
        p = subprocess.run([JSC, f.name], capture_output=True, text=True, timeout=120)
    finally:
        os.unlink(f.name)
    if p.returncode != 0:
        print('ECHEC DE CHARGEMENT :')
        print((p.stdout + p.stderr)[-2500:])
        return 1
    d = json.loads(p.stdout.strip().splitlines()[-1])
    o, pop = d['ordres'], d['popup']

    # ---- CAISSE : l'ordre a disparu des quatre salles de commissariat
    for salle in ('commissariat_accueil', 'local_accueil'):
        verifier('%s : plus d ordre « Consulter la caisse »' % salle,
                 'consulter_caisse_commissariat' not in o[salle], o[salle])
    verifier('le ministre de l Interieur garde son ecran de financement',
             'subvention_min_int' in o['bureau_min_int'], o['bureau_min_int'])

    # ---- TRANSFERT : l'ordre permanent a disparu des deux geoles
    for salle in ('commissariat_prison', 'local_geoles'):
        verifier('%s : plus d ordre « Accepter le transfert »' % salle,
                 'accepter_incorporation' not in o[salle], o[salle])
    verifier('les autres ordres des geoles sont intacts',
             'tentative_evasion' in o['commissariat_prison'] and 'requete_avocat' in o['commissariat_prison'],
             o['commissariat_prison'])

    # ---- CONDITIONS inchangees
    verifier('non detenu : pas de proposition', pop['libre'] is False, pop)
    verifier('detenu mais pas deserteur : pas de proposition', pop['pas_deserteur'] is False, pop)
    verifier('sans mobilisation : pas de proposition', pop['sans_mobilisation'] is False, pop)
    verifier('deserteur detenu pendant la mobilisation : eligible', pop['eligible'] is True, pop)

    # ---- UNE FOIS PAR JOUR
    verifier('la fenetre s ouvre quand les conditions sont reunies', pop['ouverte_1'] is True, pop)
    verifier('elle propose Accepter et Refuser', pop['boutons'] is True, pop)
    verifier('le jour est memorise sur le personnage', pop['jour_memorise'] == 5, pop)
    verifier('et sauvegarde avec la fiche (pas dans le navigateur)', pop['sauvegardee'] is True, pop)
    verifier('pas de seconde fenetre le meme jour', pop['ouverte_2_meme_jour'] is False, pop)
    verifier('elle revient le jour suivant si toujours eligible', pop['ouverte_jour_suivant'] is True, pop)
    verifier('refuser ferme la fenetre', pop['fermee_apres_refus'] is True, pop)
    verifier('refuser ne la fait pas revenir le meme jour', pop['revient_apres_refus'] is False, pop)
    verifier('plus eligible : plus aucune fenetre', pop['ouverte_non_eligible'] is False, pop)

    ko = [r for r in resultats if not r[0]]
    for ok, nom, detail in resultats:
        if not ok:
            print('  KO  %-58s %s' % (nom, detail))
    print('\n%d/%d' % (len(resultats) - len(ko), len(resultats)))
    return 1 if ko else 0


if __name__ == '__main__':
    sys.exit(main())
