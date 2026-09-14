#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BANC DE REPRISE DE LA QUETE D'ACCUEIL (audit du 14 septembre 2026).

Le principe de game design est arrete : la quete d'accueil doit etre REPRENABLE apres
interruption. Ce banc ne juge pas ce principe, il mesure ce que le code fait REELLEMENT.

Il charge le vrai plateau-quete-accueil.js dans JavaScriptCore, bouchonne le DOM et la
sauvegarde, puis rejoue les sept scenarios d'interruption demandes :

  A. interrompre tres tot (avant meme de rencontrer Jeremy)
  B. interrompre apres une premiere etape validee
  C. interrompre au milieu d'un echange avec Jeremy
  D. quitter le lieu puis revenir
  E. recharger la page
  F. revenir avec une nouvelle session
  G. reprendre apres plusieurs etapes terminees

Pour chacun : etat avant, etat persiste, comportement au retour, etape reellement proposee.

Aucune ecriture reelle, aucune base touchee.
"""
import json, os, re, subprocess, sys, tempfile

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JSC = '/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc'


def lire(f):
    with open(os.path.join(RACINE, f), encoding='utf-8') as fh:
        return fh.read()


# Le fichier de quete est charge ENTIER : c'est lui qu'on teste, on ne veut surtout pas en
# extraire des morceaux choisis. Seul le bloc final d'injection de style touche au DOM reel,
# il est neutralise par le bouchon document plus bas.
QUETE = lire('plateau-quete-accueil.js')

# La regex de declenchement du rappel vit dans plateau-pnj.js : on l'extrait telle quelle
# plutot que de la recopier, pour que le banc suive automatiquement toute modification.
PNJ = lire('plateau-pnj.js')
m = re.search(r"action !== 'bonjour' && (/[^/]+/i)\.test\(action\)", PNJ)
if not m:
    print("Regex de rappel introuvable dans plateau-pnj.js -- le banc doit etre mis a jour.")
    sys.exit(2)
REGEX_RAPPEL = m.group(1)

BANC = r"""
// ---- Bouchons minimaux : DOM, stockage, sauvegarde ----------------------------
var journal = { popups: [], surbrillances: [], sauvegardes: 0 };
var elements = {};
function fauxElement(id) {
  return { id: id, style: {}, classList: { add: function(){}, remove: function(){}, contains: function(){ return false; } },
           addEventListener: function(){}, removeEventListener: function(){},
           set innerHTML(v) { this._h = v; }, get innerHTML() { return this._h || ''; },
           set textContent(v) { this._t = v; }, get textContent() { return this._t || ''; },
           onclick: null, src: '', forEach: function(){} };
}
var document = {
  getElementById: function (id) { if (!elements[id]) elements[id] = fauxElement(id); return elements[id]; },
  querySelectorAll: function (sel) { journal.surbrillances.push(sel); return []; },
  querySelector: function () { return null; },
  createElement: function () { return fauxElement('style'); },
  head: { appendChild: function () {} }
};
var window = this;
var localStorage = { getItem: function(){ return null; }, setItem: function(){} };
function setTimeout(fn, ms) { return 0; }   // aucun minuteur ne se declenche dans le banc
function showToast(){} function updateUI(){} function addJournalEntry(){}
function rejoindreJeremy(){} function afficherGuidageBatiments(){} function afficherGuidageUnBatiment(s,b,t){ journal.popups.push({titre:'guidage', texte:t}); }
function afficherDecouverteStade(){ journal.popups.push({titre:'Jérémy', texte:'(decouverte du stade)'}); }
function queteAccueilProposerPresentationForum(){}
function queteAccueilVerifierDepartJeremy(){}
function sbSavePersonnage(){ journal.sauvegardes++; return Promise.resolve(); }

var state = null;

%QUETE%

// afficherPopupQueteAccueil du vrai fichier ecrit dans le DOM bouchonne ; on l'observe en
// reimplementant seulement la capture, apres coup, pour ne pas alterer la logique testee.
var _vraiAffichage = afficherPopupQueteAccueil;
afficherPopupQueteAccueil = function (opts) {
  journal.popups.push({ titre: opts.titre || '', texte: (opts.texte || '').replace(/<br>/g, ' ') });
  if (typeof opts.suivant === 'function') opts.suivant();   // le joueur ferme la popup
};

var REGEX_RAPPEL = %REGEX%;

// ---- Utilitaires de scenario --------------------------------------------------
function joueur(etape) {
  state = { char: { name: 'zztest', queteAccueil: { etape: etape } },
            country: 'republic', currentCity: 'capitale',
            currentBuilding: null, currentRoom: null, day: 1 };
}
// Ce que la base contient reellement : supabase.js ne persiste QUE char.queteAccueil.
function persiste() { return JSON.parse(JSON.stringify(state.char.queteAccueil)); }
// Rechargement : on repart d'un state neuf reconstruit depuis la seule valeur persistee.
function recharger(persistee, batiment, piece) {
  state = { char: { name: 'zztest', queteAccueil: JSON.parse(JSON.stringify(persistee)) },
            country: 'republic', currentCity: 'capitale',
            currentBuilding: batiment || null, currentRoom: piece || null, day: 1 };
}
function razJournal() { journal = { popups: [], surbrillances: [], sauvegardes: 0 }; }

var resultats = [];
function verifier(nom, ok, detail) {
  resultats.push({ nom: nom, ok: !!ok, detail: String(detail === undefined ? '' : detail).slice(0, 150) });
}

// ---- SCENARIOS ----------------------------------------------------------------
var R = { scenarios: [] };

function scenario(cle, titre, etape, batiment, piece) {
  joueur(etape);
  var avant = persiste();
  razJournal();
  // Retour : le jeu rejoue enterRoom() sur la position restauree (plateau-core.js ->
  // restaurerPositionApresChargement), ce qui declenche le hook de quete.
  recharger(avant, batiment, piece);
  razJournal();
  // Tous ces scenarios sont des RETOURS (rechargement, nouvelle session), jamais un
  // deplacement volontaire : on reproduit donc le drapeau que pose plateau-core.js autour de
  // la restauration de position.
  if (typeof queteAccueilVerifierEtapeBatiment === 'function' && batiment) {
    window._restaurationPositionEnCours = true;
    queteAccueilVerifierEtapeBatiment(batiment, piece);
    window._restaurationPositionEnCours = false;
  }
  var popupsAuRetour = journal.popups.length;
  var objectif = queteAccueilObjectifActuel();
  // Le joueur demande de l'aide a Jeremy, avec une formulation naturelle.
  razJournal();
  var rappelJoue = (typeof queteAccueilRappel === 'function') ? queteAccueilRappel() : false;
  var popupRappel = journal.popups.length ? journal.popups[0].texte : '';

  R.scenarios.push({
    cle: cle, titre: titre, etape: etape,
    persiste: avant,
    popups_au_retour: popupsAuRetour,
    objectif: objectif,
    rappel_disponible: !!rappelJoue,
    rappel_texte: popupRappel
  });
  return R.scenarios[R.scenarios.length - 1];
}

// A. tres tot : le garde parle encore, Jeremy pas rencontre.
scenario('A', 'interruption tres tot (garde)', 'garde_en_cours', null, null);
// B. apres une premiere etape validee : le guidage vers l'Hotel de Ville.
scenario('B', 'apres une premiere etape validee', 'guide_hdv', null, null);
// C. au milieu d'un echange avec Jeremy (il vient de proposer la salle des elections).
scenario('C', 'au milieu d\'un echange avec Jeremy', 'guide_salle_elections', 'mairie-capitale', 'hall_mairie');
// D. quitter le lieu puis revenir : le joueur est deja au bar, etape en attente d'action.
scenario('D', 'quitter le lieu puis revenir', 'attente_offre_verre', 'hotel-republica', 'bar');
// E. rechargement de page au meme endroit.
scenario('E', 'rechargement de page', 'attente_fiche_personnage', 'hotel-republica', 'hall');
// F. nouvelle session, joueur revenu dans la rue (aucun batiment).
scenario('F', 'nouvelle session, dans la rue', 'attente_hotel', null, null);
// G. plusieurs etapes terminees, fin du tronc commun.
scenario('G', 'plusieurs etapes terminees', 'attente_depart_jeremy', 'stade-luthecia', 'tribunes');
// H. etape de presentation au forum (hors des sept demandes, reperee par la cartographie).
scenario('H', 'proposition de presentation au forum', 'presentation_en_cours', null, null);

// ---- Le rechargement est-il distingue d'un depart volontaire ? -----------------
// queteAccueilVerifierDepartJeremy() est appelee en TETE des deux hooks de navigation. Son
// role voulu : faire partir Jeremy au premier deplacement suivant la separation choisie.
// Or le jeu rejoue enterRoom() au chargement de la page (restaurerPositionApresChargement) :
// un simple F5 est donc indiscernable d'un deplacement volontaire.
// Cas 1 : RECHARGEMENT. plateau-core.js pose window._restaurationPositionEnCours autour des
// appels de restauration ; l'etape doit survivre.
joueur('attente_depart_jeremy');
var avantF5 = persiste();
recharger(avantF5, 'stade-luthecia', 'tribunes');
razJournal();
window._restaurationPositionEnCours = true;
queteAccueilVerifierEtapeBatiment('stade-luthecia', 'tribunes');   // ce que fait le chargement
window._restaurationPositionEnCours = false;
R.rechargement_depart = {
  etape_avant: avantF5.etape,
  etape_apres: state.char.queteAccueil.etape,
  sauvegardee: journal.sauvegardes > 0
};

// Cas 2 : DEPLACEMENT REEL. Le depart volontaire de Jeremy doit continuer de fonctionner --
// sans quoi le correctif du cas 1 casserait la fin normale du tronc commun.
joueur('attente_depart_jeremy');
queteAccueilVerifierEtapeBatiment('stade-luthecia', 'tribunes');
R.depart_volontaire = {
  etape_avant: 'attente_depart_jeremy',
  etape_apres: state.char.queteAccueil.etape
};

// Meme question pour le minuteur du stade : sa position de depart est-elle conservee ?
joueur('stade_libre_minuteur');
state.char.queteAccueil.minuteurDebut = Date.now() - 1000;
var avantMin = persiste();
recharger(avantMin, null, null);
R.minuteur = {
  minuteurDebut_persiste: state.char.queteAccueil.minuteurDebut !== undefined,
  champs_persistes: Object.keys(avantMin)
};

// ---- Le declencheur du rappel : quelles formulations passent ? -----------------
var formulations = [
  "où en étions-nous ?", "je suis perdu", "que dois-je faire ?",
  "ou en etions nous", "on fait quoi maintenant ?", "et ensuite ?",
  "je fais quoi ?", "quelle est la suite ?", "où on en est ?",
  "qu'est-ce que je dois faire ?", "je suis bloqué", "aide-moi",
  "je ne sais plus quoi faire", "rappelle-moi", "redis-moi", "on va où ?"
];
R.declencheur = formulations.map(function (f) {
  return { phrase: f, declenche_le_rappel: REGEX_RAPPEL.test(f) };
});

print(JSON.stringify(R));
"""


def main():
    if not os.path.exists(JSC):
        print("JavaScriptCore introuvable : %s" % JSC, file=sys.stderr)
        return 2
    js = BANC.replace('%QUETE%', QUETE).replace('%REGEX%', REGEX_RAPPEL)
    with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False, encoding='utf-8') as fh:
        fh.write(js)
        chemin = fh.name
    p = subprocess.run([JSC, chemin], capture_output=True, text=True, timeout=120)
    os.unlink(chemin)
    if p.returncode != 0 or not p.stdout.strip():
        print("EXECUTION IMPOSSIBLE :\n%s\n%s" % (p.stdout[-2500:], p.stderr[-2500:]))
        return 2
    R = json.loads(p.stdout.strip().split("\n")[-1])

    print("=" * 78)
    print("REPRISE APRES INTERRUPTION — ce que le joueur obtient reellement au retour")
    print("=" * 78)
    print("%-3s %-34s %-9s %-9s %-9s" % ("", "ETAPE PERSISTEE", "RELANCE", "OBJECTIF", "RAPPEL"))
    print("-" * 78)
    muets = 0
    for s in R["scenarios"]:
        relance = "oui" if s["popups_au_retour"] else "AUCUNE"
        objectif = "oui" if s["objectif"] else "AUCUN"
        rappel = "oui" if s["rappel_disponible"] else "AUCUN"
        if not s["popups_au_retour"] and not s["objectif"] and not s["rappel_disponible"]:
            muets += 1
        print("%-3s %-34s %-9s %-9s %-9s" % (s["cle"], s["etape"], relance, objectif, rappel))
        print("    %s" % s["titre"])
        if s["objectif"]:
            print("    objectif affiche : « %s »" % s["objectif"])
        if s["rappel_disponible"]:
            print("    rappel de Jeremy : « %s »" % s["rappel_texte"][:96])
        print()

    print("=" * 78)
    print("UN RECHARGEMENT EST-IL DISTINGUE D'UN DEPART VOLONTAIRE ?")
    print("=" * 78)
    rd = R["rechargement_depart"]
    perdu = rd["etape_avant"] != rd["etape_apres"]
    print("  etape avant le F5 : %s" % rd["etape_avant"])
    print("  etape apres le F5 : %s" % rd["etape_apres"])
    print("  ecrite en base    : %s" % ("oui" if rd["sauvegardee"] else "non"))
    if perdu:
        print("  >> NON. Le simple rechargement termine la quete : le joueur perd Jeremy et la")
        print("     question d'orientation de carriere qui cloture le tronc commun.")
    else:
        print("  >> OUI, l'etape survit au rechargement.")
    dv = R["depart_volontaire"]
    print()
    print("  Temoin — deplacement REEL (le depart volontaire doit toujours marcher) :")
    print("    %s -> %s  %s" % (dv["etape_avant"], dv["etape_apres"],
                                "OK" if dv["etape_apres"] == "quete_terminee_sans_aide"
                                else "CASSE : le depart volontaire ne fonctionne plus"))
    print()
    print("  champs persistes de queteAccueil : %s" % ", ".join(R["minuteur"]["champs_persistes"]))
    print()

    print("=" * 78)
    print("DECLENCHEUR DU RAPPEL — formulations du joueur")
    print("=" * 78)
    passent = [d for d in R["declencheur"] if d["declenche_le_rappel"]]
    echouent = [d for d in R["declencheur"] if not d["declenche_le_rappel"]]
    for d in R["declencheur"]:
        print("  %-10s %s" % ("RAPPEL" if d["declenche_le_rappel"] else "-> IA", d["phrase"]))
    print("\n%d formulations sur %d atteignent le rappel ; %d partent a l'IA."
          % (len(passent), len(R["declencheur"]), len(echouent)))
    print("%d scenario(s) sur %d ne proposent RIEN au retour (ni relance, ni objectif, ni rappel)."
          % (muets, len(R["scenarios"])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
