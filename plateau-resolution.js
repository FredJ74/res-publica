// =====================
// RESOLUTION SPECTACULAIRE (chantier "animations de resolution d'ordres", 26 aout 2026)
// Composant generique reutilisable : etat succes/echec, animation CSS/DOM courte (2-4s), titre
// fort, resultat mecanique REEL fourni par l'appelant (jamais invente/calcule ici), bouton
// Continuer. La logique metier produit le resultat AVANT l'appel a ce composant -- ce fichier ne
// fait JAMAIS de mutation d'etat de jeu ni de calcul de resultat, uniquement de la presentation.
// Premier lot : bombe (utiliser_explosifs) + arrestation. Concu pour etre reutilise plus tard sur
// d'autres evenements (evasion, assassinat, elections...) sans modification du coeur ci-dessous --
// seul un nouveau type doit etre ajoute a RESOLUTION_DUREES et _stageHtmlResolution.
//
// Son (§10) : point d'extension prevu mais non implemente -- un futur config.sons (ex.
// {debut, fin}) pourrait declencher un Audio() dans ouvrirResolutionSpectaculaire/
// fermerResolutionSpectaculaire sans rien changer a la structure actuelle.
// =====================

let _resolutionEnCours = false;
let _resolutionOnFerme = null;

// Durees totales par scenario, toutes dans la fourchette 2-4s demandee (§1).
const RESOLUTION_DUREES = {
  bombe_succes: 2700,
  bombe_echec: 2600,
  arrestation_succes: 2800
};

// Contenu de la phase d'animation, par type+issue. Volontairement isole dans sa propre fonction :
// remplacer un <i class="ti ..."> par une image/WebP plus tard ne touche qu'ici (§2). `titre` est
// le meme texte que celui affiche ensuite dans le panneau de resultat (config.titre) -- passe ici
// pour que la phase d'animation de l'arrestation reste correcte y compris a la 3e personne
// (chasse a l'homme/enquete : "CIBLE LOCALISÉE ET ARRÊTÉE", jamais "VOUS ETES..." pour quelqu'un
// d'autre que le joueur courant).
function _stageHtmlResolution(type, succes, titre) {
  if (type === 'bombe') {
    // Debut IDENTIQUE aux deux branches (correctif visuel "Bombe V3", 26 aout 2026) : bombe +
    // meche + etincelle sont toujours le meme markup/la meme animation de depart -- seuls les
    // elements ajoutes APRES (flash/onde de choc/debris en reussite, ou fizzle/pschhht/OUPS en
    // echec) different. Le resultat ne devient donc visible qu'a la toute fin, jamais des le debut.
    // Accessoire isole dans .res-bombe-scene : remplacer plus tard par une image/WebP ne touche
    // qu'a ce bloc (§2), jamais aux handlers metier (§8, inchanges dans ce lot).
    let html = '<div class="resolution-stage' + (succes ? ' res-shake' : '') + '">' +
        '<div class="res-bombe-scene' + (succes ? ' res-bombe-scene-succes' : '') + '">' +
          '<div class="res-bombe-shadow"></div>' +
          '<div class="res-bombe-body"><div class="res-bombe-reflet"></div></div>' +
          '<div class="res-bombe-cap"></div>' +
          '<div class="res-bombe-light"></div>' +
          '<div class="res-bombe-fuse' + (succes ? '' : ' res-bombe-fuse-droop') + '"></div>' +
          '<div class="res-bombe-spark' + (succes ? '' : ' res-bombe-spark-echec') + '"></div>';
    if (succes) {
      html +=
          '<div class="res-flash"></div>' +
          '<div class="res-shockwave"></div>' +
          '<div class="res-debris res-debris-1"></div>' +
          '<div class="res-debris res-debris-2"></div>' +
          '<div class="res-debris res-debris-3"></div>' +
          '<div class="res-debris res-debris-4"></div>' +
          '<div class="res-smoke"></div>';
    } else {
      html += '<div class="res-pschht">💨</div>';
    }
    html += '</div>'; // .res-bombe-scene
    if (!succes) html += '<div class="resolution-title-big res-oups">OUPS…</div>';
    html += '</div>'; // .resolution-stage
    return html;
  }
  if (type === 'arrestation') {
    // Arrestation V2 (correctif visuel, 26 aout 2026) : scene de rue stylisee, gyrophare,
    // silhouette policiere qui avance, personnage interpelle mains levees, badge, puis titre --
    // accessoire isole dans .res-arrest-scene (§ "remplacable plus tard par une image/WebP sans
    // toucher aux handlers"). Titre parametre (config.titre) inchange : reste correct a la 3e
    // personne pour la chasse a l'homme/l'enquete.
    return '<div class="resolution-stage res-arrest-shake">' +
        '<div class="res-arrest-scene">' +
          '<div class="res-arrest-street"></div>' +
          '<div class="res-police-flash"></div>' +
          '<div class="res-arrest-dim"></div>' +
          '<div class="res-cop"><div class="res-cop-head"></div><div class="res-cop-body"></div><div class="res-cop-arm"></div></div>' +
          '<div class="res-suspect"><div class="res-suspect-head"></div><div class="res-suspect-body"></div><div class="res-suspect-arm res-suspect-arm-l"></div><div class="res-suspect-arm res-suspect-arm-r"></div></div>' +
          '<div class="res-badge"><i class="ti ti-shield-check"></i></div>' +
        '</div>' +
        '<div class="resolution-title-big res-arrest-title">' + (titre || 'ARRESTATION') + '</div>' +
      '</div>';
  }
  return '<div class="resolution-stage"></div>';
}

// Point d'entree generique. config = {
//   type: 'bombe' | 'arrestation' (cle d'animation),
//   succes: bool,
//   titre: string (titre fort affiche avec le resultat, ex "EXPLOSION RÉUSSIE"),
//   resultatHtml: string (HTML du resultat mecanique REEL, construit par l'appelant a partir de
//     valeurs deja calculees par le handler -- jamais fabrique ici),
//   dureeMs: number optionnel (sinon deduit de type+succes, toujours 2-4s),
//   onFerme: fonction optionnelle, appelee au clic sur Continuer
// }
// IMPORTANT (§8) : n'appeler cette fonction qu'APRES que toute la logique metier (persistance,
// teleportation...) a deja ete executee normalement -- ce composant ne conditionne jamais la
// verite de l'action, il ne fait que la presenter a posteriori.
function ouvrirResolutionSpectaculaire(config) {
  if (_resolutionEnCours) return; // anti double-declenchement (§9)
  const modal = document.getElementById('modal-resolution');
  const stage = document.getElementById('resolution-stage');
  const resultat = document.getElementById('resolution-result');
  if (!modal || !stage || !resultat) { if (typeof config.onFerme === 'function') config.onFerme(); return; }
  _resolutionEnCours = true;

  const type = config.type;
  const succes = !!config.succes;
  const duree = config.dureeMs || RESOLUTION_DUREES[type + '_' + (succes ? 'succes' : 'echec')] || 2800;

  stage.innerHTML = _stageHtmlResolution(type, succes, config.titre);
  stage.style.display = '';
  resultat.style.display = 'none';
  resultat.innerHTML = '';
  modal.classList.add('open');

  setTimeout(() => {
    stage.style.display = 'none';
    resultat.innerHTML =
      '<div class="resolution-title-big" style="color:' + (succes ? 'var(--gold)' : '#cc4444') + '">' + (config.titre || '') + '</div>' +
      '<div style="font-size:.88rem;color:#c0b090;line-height:1.65;margin:.9rem 0">' + (config.resultatHtml || '') + '</div>' +
      '<button onclick="fermerResolutionSpectaculaire()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.6rem;border:1px solid var(--gold);background:transparent;color:var(--gold);cursor:pointer">Continuer</button>';
    resultat.style.display = '';
    _resolutionOnFerme = typeof config.onFerme === 'function' ? config.onFerme : null;
  }, duree);
}

function fermerResolutionSpectaculaire() {
  document.getElementById('modal-resolution')?.classList.remove('open');
  _resolutionEnCours = false;
  const cb = _resolutionOnFerme;
  _resolutionOnFerme = null;
  if (cb) cb();
}
