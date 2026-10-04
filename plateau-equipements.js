/* ===========================================================================
   EQUIPEMENTS DE BUREAU — interface d'attente
   ===========================================================================

   CE FICHIER NE CONTIENT AUCUNE MECANIQUE, ET C'EST VOULU.

   Les bureaux du centre d'affaires pourront un jour etre amenages. L'entree du
   menu existe des maintenant, pour que le joueur sache ou cela se passera et
   que la place soit prise dans l'interface -- mais rien n'est installable, rien
   n'est stocke, rien n'est calcule.

   Ce fichier est le futur foyer de la fonctionnalite : quand elle sera
   developpee, elle s'ecrira ici, et l'ordre comme la modale sont deja a leur
   place. En attendant il n'y a, deliberement :

     - aucun equipement declare, pas meme a titre d'exemple ;
     - aucune table, aucune donnee persistee, aucun appel serveur ;
     - aucun nombre d'emplacements applique -- les deux chiffres affiches sont
       du TEXTE d'annonce, ils ne sont lus par rien ;
     - aucune regle de location, de bonus ou d'organisation touchee.

   L'ordre coute 0 PA et 0 FR, et son routeur rend la main avant tout debit :
   ouvrir cette fenetre ne consomme rien et ne previent pas le serveur.
   =========================================================================== */

/* Texte de la fenetre. Ecrit ici et nulle part ailleurs : le jour ou la
   fonctionnalite arrive, c'est ce bloc qui disparait, et rien d'autre. */
function ouvrirModalEquipements() {
  const titre = document.getElementById('postes-modal-title');
  const corps = document.getElementById('postes-body');
  const modale = document.getElementById('modal-postes');
  if (!titre || !corps || !modale) return;

  titre.textContent = 'Installer des équipements';
  corps.innerHTML =
    '<div style="padding:.2rem .1rem .4rem">' +

      '<p style="margin:0 0 .9rem;color:#c0b090;line-height:1.6">' +
        'Les bureaux pourront prochainement être aménagés avec des équipements ' +
        'professionnels.</p>' +

      '<p style="margin:0 0 1.2rem;color:#c0b090;line-height:1.6">' +
        'Ces équipements permettront de débloquer de nouvelles fonctionnalités ' +
        'selon votre activité.</p>' +

      '<div style="display:grid;grid-template-columns:1fr 1fr;gap:.8rem;margin-bottom:1.1rem">' +

        '<div style="border:1px solid #2a2010;background:#0f0e08;padding:.75rem .85rem">' +
          '<div style="font-family:\'Bebas Neue\',sans-serif;letter-spacing:.1em;' +
               'color:#8a8060;font-size:.84rem;margin-bottom:.45rem">VERSION FREEMIUM</div>' +
          '<div style="color:#b0a080;font-size:.86rem">· jusqu\'à 2 emplacements d\'équipements</div>' +
        '</div>' +

        '<div style="border:1px solid #3a2a10;background:#12100a;padding:.75rem .85rem">' +
          '<div style="font-family:\'Bebas Neue\',sans-serif;letter-spacing:.1em;' +
               'color:#C9A84C;font-size:.84rem;margin-bottom:.45rem">VERSION PREMIUM</div>' +
          '<div style="color:#d8c8a0;font-size:.86rem">· jusqu\'à 4 emplacements d\'équipements</div>' +
        '</div>' +

      '</div>' +

      '<p style="margin:0 0 .5rem;color:#c0b090;line-height:1.6">' +
        'Les équipements seront identiques dans les deux versions.</p>' +
      '<p style="margin:0 0 1.2rem;color:#c0b090;line-height:1.6">' +
        'La version Premium permettra simplement d\'en installer davantage.</p>' +

      '<div style="border-top:1px solid #2a2010;padding-top:.8rem;margin-bottom:1rem;' +
           'color:#8a8060;font-style:italic;font-size:.85rem">' +
        'Fonctionnalité actuellement en cours de développement.</div>' +

      '<button class="action-btn legal" style="width:100%" ' +
              'onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')">' +
        '<i class="ti ti-x" style="font-size:.82rem"></i> Fermer</button>' +

    '</div>';

  modale.classList.add('open');
}
