// =====================================================================
// METTRE EN RELATION, SANS RIEN SAVOIR (1er octobre 2026)
// =====================================================================
// CE QUE FAIT UN PASSEUR. Il envoie un message a quelqu'un, et s'arrete la. Il ne
// recrute personne, ne negocie rien, ne transmet aucun detail. Pat Hounette est
// le premier, et il n'en existe qu'un : la regle de socle interdit de le preter a
// un autre empire, qui aura son propre intermediaire.
//
// LE TEXTE DU JOUEUR NE VA NULLE PART, ET CE FICHIER LE PROUVE. Le passeur demande
// « C'est quoi ton projet ? T'as besoin de quoi ? ». Le joueur ecrit. Puis
// contactOrgaEnvoyer() appelle le serveur SANS JAMAIS RELIRE LE CHAMP -- et la RPC
// n'a de toute facon aucun parametre pour le recevoir. Ce n'est pas une regle
// qu'on pourrait oublier d'appliquer : il n'y a pas de chemin par lequel ce texte
// pourrait partir. Si quelqu'un ajoute un jour un document.getElementById() sur ce
// champ dans cette fonction, le banc .scratch/banc_contact_organisation.py echoue.
//
// POURQUOI L'ETAT EST CONSULTE AVANT LA PREMIERE QUESTION. Le game design veut que
// le passeur refuse TOUT DE SUITE pendant les trois jours (« Je t'ai dit trois
// jours... t'es sourd ou quoi ? »), et non apres avoir demande au joueur ce qu'il
// voulait. D'ou deux RPC : une lecture au clic, une action a la fin. La lecture
// n'autorise rien -- le serveur retranche le delai une seconde fois pour de vrai.
//
// AUCUN LIEN AVEC LES MECANIQUES CRIMINELLES. Ce module ne connait ni DUP, ni
// reputation, ni grade, ni quete. Il ne lit qu'une organisation et une boite aux
// lettres, et il resterait vrai si le crime n'existait pas dans ce jeu.

// Les repliques appartiennent au PERSONNAGE, pas a la mecanique : un autre passeur,
// un jour, aura les siennes. Celles de Pat sont reprises mot pour mot du game
// design -- aucune reformulation.
const CONTACT_ORGA_PASSEURS = {
  pat_hounette: {
    nom: 'Pat Hounette',
    type: 'criminelle',
    libelleAction: 'Entrer en contact avec une organisation criminelle',
    question: 'Tu veux entrer en contact avec une organisation criminelle ?',
    projet: "C'est quoi ton projet ? T'as besoin de quoi ?",
    conclusion: "Ok... j'connais peut-être quelqu'un. J'envoie un message. "
              + "Si t'as rien dans trois jours, tu reviens me voir.",
    refusDelai: "Je t'ai dit trois jours... t'es sourd ou quoi ?",
    // SEULE REPLIQUE QUI N'EST PAS ARBITREE, et elle est signalee comme telle.
    // Le game design ne couvre pas le cas ou il n'y a personne a solliciter --
    // aujourd'hui aucune organisation criminelle n'existe en production, et ce
    // cas sera donc le PREMIER rencontre. Elle est volontairement seche et ne
    // promet rien : le passeur ne peut pas annoncer un message qu'il n'enverra
    // pas. A remplacer par la replique arbitree des qu'elle existera.
    personne: "Hmm... j'ai personne pour toi en ce moment. Repasse."
  }
};

function contactOrgaTexte(cle,fr,vars){
 const tr=window.RPContactOrganizationI18n?.text;
 return typeof tr==='function'?tr(cle,fr,vars):String(fr).replace(/\{([a-z]+)\}/g,(m,k)=>Object.hasOwn(vars||{},k)?String(vars[k]):m);
}
function contactOrgaLibelleAction(passeur){
 return passeur?.nom==='Pat Hounette'?contactOrgaTexte('action',passeur.libelleAction):passeur?.libelleAction||'';
}
function contactOrgaReplique(passeur,champ){
 const cle={question:'question',projet:'project',conclusion:'conclusion',refusDelai:'wait',personne:'nobody'}[champ];
 return cle&&passeur?.nom==='Pat Hounette'?contactOrgaTexte(cle,passeur[champ]):passeur?.[champ]||'';
}
function contactOrgaPasseur(passeurId) {
  return CONTACT_ORGA_PASSEURS[passeurId] || null;
}

// Le PNJ affiche-t-il cette action ? La reponse ne vient pas de son metier --
// `job:'criminel'` est porte par cinq PNJ de decor qui ne mettent personne en
// relation -- mais d'un champ dedie pose sur la seule fiche concernee.
function contactOrgaDuPnj(pnj) {
  if (!pnj || !pnj.contactOrga) return null;
  return contactOrgaPasseur(pnj.contactOrga) ? pnj.contactOrga : null;
}

function contactOrgaEch(t) {
  return (typeof escapeHtmlText === 'function')
    ? escapeHtmlText(String(t == null ? '' : t))
    : String(t == null ? '' : t);
}

// Une replique du passeur, dans la fenetre generique deja utilisee partout
// ailleurs (#modal-postes) -- aucun nouveau modal, aucun nouveau style.
function contactOrgaDire(passeurId, replique, boutons, cleReplique) {
  const p = contactOrgaPasseur(passeurId);
  const titre = document.getElementById('postes-modal-title');
  const corps = document.getElementById('postes-body');
  const modale = document.getElementById('modal-postes');
  if (!p || !titre || !corps || !modale) return;
  titre.textContent = p.nom;
  corps.innerHTML =
    '<div data-contact-passeur="'+contactOrgaEch(passeurId)+'" style="padding:1rem 1.1rem">'
    + '<div data-contact-replique="'+contactOrgaEch(cleReplique||'')+'" style="font-family:Crimson Pro,serif;font-size:.95rem;color:#d8c8a8;'
    + 'line-height:1.7;font-style:italic">« ' + contactOrgaEch(replique) + ' »</div>'
    + (boutons || '')
    + '</div>';
  modale.classList.add('open');
}

function contactOrgaFermer() {
  document.getElementById('modal-postes')?.classList.remove('open');
}

// ---- 1. LE CLIC : le passeur accepte-t-il d'en reparler ? ----
async function contactOrgaDemarrer(passeurId) {
  const p = contactOrgaPasseur(passeurId);
  if (!p) return;
  document.getElementById('modal-pnj')?.classList.remove('open');
  contactOrgaDire(passeurId, '…');

  const r = await sbContactOrganisationEtat(passeurId, p.type);
  // UN APPEL QUI N'ABOUTIT PAS N'EST PAS UN REFUS DU PERSONNAGE. Lui faire dire
  // quelque chose ici inventerait une scene a partir d'une panne de reseau.
  if (!r) {
    contactOrgaFermer();
    if (typeof showToast === 'function') {
      showToast(contactOrgaTexte('impossible','Action impossible'),contactOrgaTexte('retry','Réessayez dans un instant.'), false);
    }
    return;
  }
  if (r.ok === false) {
    contactOrgaFermer();
    if (typeof showToast === 'function') {
      showToast(contactOrgaTexte('unavailable','Indisponible'),contactOrgaTexte('notHere','Cette mise en relation n\'est pas possible ici.'), false);
    }
    return;
  }

  if (r.peut_demander === false) {
    contactOrgaDire(passeurId, contactOrgaReplique(p,'refusDelai'),
      '<div style="margin-top:1rem"><button class="pnj-action-btn" '
      + 'onclick="contactOrgaFermer()"><span data-contact-label="later">'+contactOrgaEch(contactOrgaTexte('later','Je repasserai'))+'</span></button></div>', 'refusDelai');
    return;
  }

  contactOrgaDire(passeurId, contactOrgaReplique(p,'question'),
    '<div style="margin-top:1rem;display:flex;gap:.5rem;flex-wrap:wrap">'
    + '<button class="pnj-action-btn" onclick="contactOrgaConfirmer(\'' + passeurId + '\')">'
    + '<i class="ti ti-check" style="font-size:.85rem"></i> <span data-contact-label="yes">'+contactOrgaEch(contactOrgaTexte('yes','Oui'))+'</span></button>'
    + '<button class="pnj-action-btn" onclick="contactOrgaFermer()">'
    + '<i class="ti ti-x" style="font-size:.85rem"></i> <span data-contact-label="no">'+contactOrgaEch(contactOrgaTexte('no','Non, laisse tomber'))+'</span></button>'
    + '</div>', 'question');
}

// ---- 2. LA QUESTION QUI NE SERT A RIEN, ET C'EST VOULU ----
// Le passeur demande au joueur ce qu'il veut. Le joueur repond. Personne ne lit
// cette reponse : elle n'alimente aucune mecanique, ne part sur aucun fil, n'est
// transmise a personne. Le champ existe pour que la scene ait lieu, pas pour que
// la donnee serve. C'est exactement ce que dit le game design -- Pat ne transmet
// aucun detail.
function contactOrgaConfirmer(passeurId) {
  const p = contactOrgaPasseur(passeurId);
  if (!p) return;
  contactOrgaDire(passeurId, contactOrgaReplique(p,'projet'),
    '<textarea id="contact-orga-projet" rows="4" placeholder="…" '
    + 'style="width:100%;margin-top:.9rem;padding:.5rem .6rem;background:#0a0a07;'
    + 'border:1px solid #3a2a10;color:#d8c8a8;font-family:Crimson Pro,serif;'
    + 'font-size:.88rem;resize:vertical"></textarea>'
    + '<div style="margin-top:.8rem;display:flex;gap:.5rem;flex-wrap:wrap">'
    + '<button class="pnj-action-btn" onclick="contactOrgaEnvoyer(\'' + passeurId + '\')">'
    + '<i class="ti ti-send" style="font-size:.85rem"></i> <span data-contact-label="explain">'+contactOrgaEch(contactOrgaTexte('explain','Lui expliquer'))+'</span></button>'
    + '<button class="pnj-action-btn" onclick="contactOrgaFermer()">'
    + '<i class="ti ti-x" style="font-size:.85rem"></i> <span data-contact-label="withdraw">'+contactOrgaEch(contactOrgaTexte('withdraw','Renoncer'))+'</span></button>'
    + '</div>', 'projet');
}

// ---- 3. LE MESSAGE PART ----
// NE RIEN AJOUTER ICI QUI LISE #contact-orga-projet. Ce que le joueur a ecrit
// reste dans son navigateur et disparait avec la fenetre : c'est la garantie
// centrale de ce chantier, et elle tient au fait que cette fonction ne regarde
// pas ce champ. Le banc le verifie.
async function contactOrgaEnvoyer(passeurId) {
  const p = contactOrgaPasseur(passeurId);
  if (!p) return;
  const r = await sbContactOrganisationDemander(passeurId, p.type);

  if (!r) {
    contactOrgaFermer();
    if (typeof showToast === 'function') {
      showToast(contactOrgaTexte('impossible','Action impossible'),contactOrgaTexte('retry','Réessayez dans un instant.'), false);
    }
    return;
  }

  const fermer = '<div style="margin-top:1rem"><button class="pnj-action-btn" '
               + 'onclick="contactOrgaFermer()"><span data-contact-label="understood">'+contactOrgaEch(contactOrgaTexte('understood','Entendu'))+'</span></button></div>';

  if (r.ok === true) {
    contactOrgaDire(passeurId, contactOrgaReplique(p,'conclusion'), fermer, 'conclusion');
    if (typeof addJournalEntry === 'function') {
      // Le journal ne nomme pas l'organisation : le joueur ne la connait pas, et
      // le passeur ne transmet aucun detail.
      addJournalEntry(contactOrgaTexte('journal','{name} a transmis un message pour vous.',{name:p.nom}), 'event-info');
    }
    return;
  }

  if (r.raison === 'delai_non_ecoule') { contactOrgaDire(passeurId, contactOrgaReplique(p,'refusDelai'), fermer, 'refusDelai'); return; }
  if (r.raison === 'aucune_organisation' || r.raison === 'toutes_contactees') {
    contactOrgaDire(passeurId, contactOrgaReplique(p,'personne'), fermer, 'personne');
    return;
  }
  contactOrgaFermer();
  if (typeof showToast === 'function') {
    showToast(contactOrgaTexte('unavailable','Indisponible'),contactOrgaTexte('notPossible','Cette mise en relation n\'est pas possible.'), false);
  }
}

// Mise à jour des seuls libellés d'une scène encore ouverte. Le projet saisi ne
// quitte jamais son textarea, et une bascule ne déclenche aucune lecture ni action.
if(typeof window.i18next?.on==='function')window.i18next.on('languageChanged',function(){
 const corps=document.getElementById('postes-body');
 const modal=document.getElementById('modal-postes');
 if(!modal?.classList.contains('open'))return;
 const root=corps?.querySelector?.('[data-contact-passeur]');
 const p=root?contactOrgaPasseur(root.getAttribute('data-contact-passeur')):null;
 if(!p)return;
 const parole=root.querySelector('[data-contact-replique]');
 const champ=parole?.getAttribute('data-contact-replique');
 if(champ)parole.textContent='« '+contactOrgaReplique(p,champ)+' »';
 const actions={later:'Je repasserai',yes:'Oui',no:'Non, laisse tomber',explain:'Lui expliquer',withdraw:'Renoncer',understood:'Entendu'};
 root.querySelectorAll('[data-contact-label]').forEach(function(label){
  const key=label.getAttribute('data-contact-label');
  if(Object.hasOwn(actions,key))label.textContent=contactOrgaTexte(key,actions[key]);
 });
});
