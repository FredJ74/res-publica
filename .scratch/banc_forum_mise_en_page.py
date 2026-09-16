# BANC — MISE EN PAGE DU FORUM ET RETOUR APRES PUBLICATION (16 septembre 2026).
#
# Deux defauts constates en production sur le parcours de candidature, tous deux GENERIQUES au
# forum -- ils n'ont rien de propre aux elections :
#   1. apres « Publier », le message ne s'affichait pas : il fallait quitter et revenir ;
#   2. les images perdaient leurs dimensions et leur centrage.
#
# Le banc charge les VRAIS modules et inspecte le HTML REELLEMENT rendu, pas la presence de
# boutons. Il joue aussi la publication de bout en bout, avec un serveur bouchonne qui repond
# comme le vrai.

import json, os, re, subprocess, sys, tempfile

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JSC = '/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc'
resultats = []

HARNAIS = r"""
var _els = {};
function _el(id) {
  if (!_els[id]) _els[id] = { id: id, innerHTML: '', value: '', offsetWidth: 0, style: {},
    children: [],
    addEventListener: function () {}, removeEventListener: function () {},
    appendChild: function (n) { this.children.push(n); n.parentNode = this; return n; },
    removeChild: function (n) { var i = this.children.indexOf(n); if (i >= 0) this.children.splice(i, 1); },
    querySelector: function () { return null; },
    querySelectorAll: function () { return []; }, getBoundingClientRect: function () {
      return { left: 0, top: 0, width: this.offsetWidth || 0, height: 0 }; },
    classList: { _c: {}, add: function (c) { this._c[c] = 1; }, remove: function (c) { delete this._c[c]; },
                 toggle: function (c, o) { if (o) this._c[c] = 1; else delete this._c[c]; },
                 contains: function (c) { return !!this._c[c]; } } };
  return _els[id];
}
var ELEMENTS_DE_LA_PAGE = ['postes-body','postes-modal-title','modal-postes','modal-forum',
                           'forum-body','modal-forum-title','compose-canvas-title','rp-compose-canvas'];
function _elStrict(id) {
  if (!_els[id] && ELEMENTS_DE_LA_PAGE.indexOf(id) === -1) return null;
  return _el(id);
}
function _brancherCreationParHtml(id) {
  var el = _el(id), _h = '';
  Object.defineProperty(el, 'innerHTML', {
    get: function () { return _h; },
    set: function (v) { _h = String(v || ''); var re = /id="([a-zA-Z0-9_-]+)"/g, m;
                        while ((m = re.exec(_h)) !== null) _el(m[1]); }
  });
}
['forum-body', 'postes-body'].forEach(_brancherCreationParHtml);
var document = { getElementById: _elStrict, querySelector: function(){return null;},
  querySelectorAll: function(){return [];}, addEventListener: function(){},
  body: { appendChild: function(){} },
  createElement: function (tag) {
    var noeud = { tagName: String(tag || 'div').toUpperCase(), style: {}, children: [],
      className: '', innerHTML: '', textContent: '', contentEditable: '', dataset: {},
      classList: { _c: {}, add: function (c) { this._c[c] = 1; },
                   remove: function (c) { delete this._c[c]; },
                   toggle: function (c, o) { if (o) this._c[c] = 1; else delete this._c[c]; },
                   contains: function (c) { return !!this._c[c]; } },
      appendChild: function (n) { this.children.push(n); n.parentNode = this; return n; },
      removeChild: function (n) { var i = this.children.indexOf(n); if (i >= 0) this.children.splice(i, 1); },
      addEventListener: function () {}, removeEventListener: function () {},
      querySelector: function () { return null; }, querySelectorAll: function () { return []; },
      getBoundingClientRect: function () { return { left:0, top:0, width:0, height:0 }; },
      setAttribute: function () {}, focus: function () {} };
    return noeud;
  } };
var TIPTAP_INSTANCES = [];
function FauxEditeur(opts) {
  this.opts = opts; this._html = (opts && opts.content) || '<p></p>'; this.focusAppele = 0;
  var self = this;
  this.commands = { focus: function () { self.focusAppele++; return true; } };
  this.getHTML = function () { return self._html; };
  this.setHTML = function (h) { self._html = h; };
  this.chain = function () { var c = { focus: function(){return c;}, run: function(){return true;} };
                             return c; };
  this.on = function () {}; this.destroy = function () {};
  this.isActive = function () { return false; };
  this.state = { selection: {} };
  TIPTAP_INSTANCES.push(this);
}
var window = { addEventListener: function(){}, location: { search: '' },
               RP_TIPTAP_EDITOR: FauxEditeur, RP_TIPTAP_STARTER_KIT: { configure: function(){ return {}; } } };
var localStorage = { getItem: function(){return null;}, setItem: function(){}, removeItem: function(){} };
var navigator = { language: 'fr' };
var TOASTS = [];
function showToast(a, b) { TOASTS.push(a + ' | ' + b); }
function addJournalEntry() {} function addExternalEvent() {}
// updateUI touche une trentaine d'elements du bandeau de jeu, absents de ce banc : on la
// remplace apres chargement (les modules la redefinissent), voir plus bas.
function updateUI() {}
function setTimeout(f) { try { f(); } catch (e) {} }
function sanitizeRichHtml(h) { return h || ''; }
var RPC_APPELS = [];
function sbRpc(fn, params) {
  RPC_APPELS.push(fn);
  if (fn === 'candidature_publier') {
    return Promise.resolve([{ ok: true, id: 'republic_maire_ville_b_Testeur',
                              topic_id: 'topic-programme-republic_maire_ville_b_Testeur',
                              forum: 'local', pa: 10 }]);
  }
  return Promise.resolve(null);
}
function sbGet() { return Promise.resolve([]); }
function sbInsert() { return Promise.resolve(null); }
function sbUpdate() { return Promise.resolve(null); }
function sbIncrementViews() {}
function rafraichirCachePhotosJoueurs() { return Promise.resolve(); }
// Fonctions de rendu vivant dans des modules que ce banc ne charge pas : bouchonnees pour que le
// rendu du forum aille au bout sans les tirer toutes.
function renderEmployesPanel() { return ''; }
function renderMailList() { return ''; }
function renderMailCompose() { return ''; }
function marquerForumRubriqueVisitee() {}
function forumADeLActiviteNonVue() { return false; }
function htmlPointRougeActivite() { return ''; }

load('%(racine)s/forum-canvas.js');
load('%(racine)s/forum.js');
load('%(racine)s/data.js');
load('%(racine)s/plateau-core.js');
load('%(racine)s/plateau-politique.js');
showToast = function (a, b) { TOASTS.push(a + ' | ' + b); };
updateUI = function () {};          // le bandeau de jeu n'existe pas dans ce banc
addJournalEntry = function () {};   // le journal ecrit dans le DOM de la page
addExternalEvent = function () {};
syncCyclesDepuisSupabase = function () { return Promise.resolve(); };

var s = {};

// ============ 1. RENDU D'UNE IMAGE : DIMENSION ET CENTRAGE ============
// Une image de 300 px placee au milieu d'un canvas de 500 px : marges egales de 100 px.
function mesurer(canvasWidth) {
  var html = renderComposedPost({ canvas_width: canvasWidth, elements: [
    { type: 'image', src: 'https://exemple.test/i.png', alt: '', caption: '',
      layout: { x: 100, y: 20, width: 300, height: 200, z: 1 } }], reading_order: [0] });
  function ex(re) { var m = html.match(re); return m ? Number(m[1]) : null; }
  var lc = ex(/rp-composed-canvas" style="position:relative;width:(\d+)px/);
  var lg = ex(/rp-composed-image" style="position:absolute;left:(\d+)px/);
  var li = ex(/rp-composed-image" style="position:absolute;left:\d+px;top:\d+px;width:(\d+)px/);
  return { largeurCanvas: lc, gauche: lg, largeurImage: li,
           margeDroite: (lc !== null && lg !== null && li !== null) ? (lc - lg - li) : null,
           scrollable: html.indexOf('overflow-x:auto') >= 0,
           imagePleineLargeur: html.indexOf('width:100%;height:auto;display:block') >= 0 };
}
s.rendu = mesurer(500);
// Le defaut d'origine : la largeur d'edition etait ignoree au profit d'un 680 code en dur.
s.renduAvecLargeurFausse = mesurer(680);

// ============ 2. LA SERIALISATION MESURE LE CANVAS ============
_el('rp-compose-canvas').offsetWidth = 500;
if (typeof rpComposeElements !== 'undefined') rpComposeElements.length = 0;
var ser = (typeof rpCanvasSerializeCompose === 'function') ? rpCanvasSerializeCompose() : null;
s.largeurSerialisee = ser ? ser.canvas_width : null;
_el('rp-compose-canvas').offsetWidth = 0;   // canvas absent du DOM : repli attendu
var ser2 = (typeof rpCanvasSerializeCompose === 'function') ? rpCanvasSerializeCompose() : null;
s.largeurRepli = ser2 ? ser2.canvas_width : null;

// ============ 3. PUBLIER MONTRE CE QU'ON VIENT D'ECRIRE ============
state.char = { name: 'Testeur' }; state.country = 'republic'; state.currentCity = 'ville_b';
state.pa = 12; state.inf = 50; state.domicile = { country: 'republic', city: 'ville_b' };
CYCLES_ELECTORAUX['republic'] = CYCLES_ELECTORAUX['republic'] || {};
CYCLES_ELECTORAUX['republic']['maire_ville_b'] = {
  phase: 'candidatures', resultatsTraites: false,
  dateDebutCandidatures: Date.now() - 1000, dateDebutCampagne: Date.now() + 86400000,
  candidats: [], votes: {}, tour: 1 };
ouvrirRedactionProgramme({ dataset: { poste: 'maire', country: 'republic', city: 'ville_b' } });
s.editeurOuvert = (typeof forumView !== 'undefined') ? forumView : null;

s.redactionAvantPublication = (typeof _candidatureEnRedaction !== 'undefined' && _candidatureEnRedaction) ? 'posee' : 'absente';
s.currentTopicIdAvant = (typeof currentTopicId !== 'undefined') ? currentTopicId : 'indefini';
s.zonesCreees = (typeof rpComposeElements !== 'undefined') ? rpComposeElements.length : -1;
s.toolbarSelectionnee = (typeof rpComposeElements !== 'undefined' && rpComposeElements[0] && rpComposeElements[0].el)
  ? rpComposeElements[0].el.classList.contains('selected') : null;
s.focusDemande = (typeof TIPTAP_INSTANCES !== 'undefined' && TIPTAP_INSTANCES[0]) ? TIPTAP_INSTANCES[0].focusAppele : -1;
// La serialisation parcourt le DOM reel du canvas ; elle est eprouvee separement plus haut
// (largeur mesuree). Ici on teste la NAVIGATION apres publication : on la bouchonne pour que le
// harnais n'ait pas a simuler tout ProseMirror.
rpCanvasSerializeCompose = function () { return { canvas_width: 500, elements: [], reading_order: [] }; };
rpCanvasBuildFallbackContent = function () { return 'Mon programme.'; };
_el('compose-canvas-title').value = 'Programme de Testeur';
TOASTS = []; RPC_APPELS = [];
s.publication = { exception: null };
var fini = false;
submitComposeCanvas().then(function () { fini = true; }).catch(function (e) {
  s.publication.exception = String(e); fini = true;
});
// JSC resout les promesses deja pretes au drainage de la micro-file : on force le drainage.
drainMicrotasks();
s.publication.vue = (typeof forumView !== 'undefined') ? forumView : null;
s.publication.topicOuvert = (typeof currentTopicId !== 'undefined') ? currentTopicId : null;
s.publication.rpc = RPC_APPELS.slice();
s.publication.toasts = TOASTS.slice();
s.publication.paRecopie = state.pa;
print(JSON.stringify(s));
"""


def verifier(nom, cond, detail=''):
    resultats.append((bool(cond), nom, str(detail)[:160]))


def main():
    f = tempfile.NamedTemporaryFile('w', suffix='.js', delete=False, encoding='utf-8')
    f.write(HARNAIS.replace('%(racine)s', RACINE)); f.close()
    try:
        p = subprocess.run([JSC, f.name], capture_output=True, text=True, timeout=120)
    finally:
        os.unlink(f.name)
    if p.returncode != 0:
        print('ECHEC DE CHARGEMENT :'); print((p.stdout + p.stderr)[-2000:]); return 1
    d = json.loads(p.stdout.strip().splitlines()[-1])

    # ---- BUG 2 : dimensions et centrage ----
    r = d['rendu']
    verifier('le canvas rendu garde la largeur d edition', r['largeurCanvas'] == 500, r)
    verifier('l image garde la dimension choisie', r['largeurImage'] == 300, r)
    verifier('une image centree a l edition est rendue centree',
             r['gauche'] == r['margeDroite'] == 100, r)
    verifier('l image remplit son cadre sans le deformer', r['imagePleineLargeur'], r)
    verifier('la mise en page ne peut pas deborder sur le reste de la page', r['scrollable'], r)

    # La preuve du defaut : avec une largeur de canvas erronee, le centrage est faux.
    f2 = d['renduAvecLargeurFausse']
    verifier('DEMONSTRATION : une largeur de canvas fausse decentre l image',
             f2['gauche'] != f2['margeDroite'], f2)

    verifier('la serialisation enregistre la largeur REELLE du canvas',
             d['largeurSerialisee'] == 500, d['largeurSerialisee'])
    verifier('et se rabat sur 680 si le canvas n est pas mesurable',
             d['largeurRepli'] == 680, d['largeurRepli'])

    # ---- OUVERTURE DE L EDITEUR : les premieres secondes ----
    verifier('une zone de redaction est prete des l ouverture', d.get('zonesCreees') == 1,
             d.get('zonesCreees'))
    verifier('elle est selectionnee, donc la barre d outils est visible',
             d.get('toolbarSelectionnee') is True, d.get('toolbarSelectionnee'))
    verifier('le curseur y est place sans clic prealable', (d.get('focusDemande') or 0) >= 1,
             d.get('focusDemande'))
    verifier('DIAGNOSTIC : la redaction est bien memorisee avant publication',
             d.get('redactionAvantPublication') == 'posee', d.get('redactionAvantPublication'))
    verifier('DIAGNOSTIC : aucun sujet courant ne bloque la publication',
             d.get('currentTopicIdAvant') in (None, 'indefini'), d.get('currentTopicIdAvant'))

    # ---- BUG 1 : voir ce qu'on vient de publier ----
    pub = d['publication']
    verifier('publier ne leve aucune exception', not pub.get('exception'), pub.get('exception'))
    verifier('la publication appelle bien la transaction serveur',
             'candidature_publier' in (pub.get('rpc') or []), pub.get('rpc'))
    verifier('le forum bascule sur la vue d un sujet', pub.get('vue') == 'topic', pub.get('vue'))
    verifier('et c est LE sujet cree par le serveur qui est ouvert',
             pub.get('topicOuvert') == 'topic-programme-republic_maire_ville_b_Testeur',
             pub.get('topicOuvert'))
    verifier('le solde de PA arrete par le serveur est repris', pub.get('paRecopie') == 10,
             pub.get('paRecopie'))
    verifier('aucun message d erreur au candidat', not pub.get('toasts')
             or all('refus' not in t.lower() for t in pub.get('toasts')), pub.get('toasts'))

    ko = [x for x in resultats if not x[0]]
    for ok, nom, detail in resultats:
        if not ok:
            print('  KO  %-60s %s' % (nom, detail))
    print('\n%d/%d' % (len(resultats) - len(ko), len(resultats)))
    return 1 if ko else 0


if __name__ == '__main__':
    sys.exit(main())
