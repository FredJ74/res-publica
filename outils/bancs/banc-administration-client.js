// Banc STRUCTUREL du socle d'administration et de la fin de la procedure simplifiee
// (12 octobre 2026). -- SOURCES: aucune -- ce banc lit les fichiers de production par readFile.
//
// POURQUOI STRUCTUREL, ET CE QU'IL NE PRETEND PAS PROUVER. Le comportement des portes est
// eprouve EN BASE par outils/bancs/banc-administration-tribunal.sql (25 epreuves, transaction
// annulee) et outils/bancs/banc-defense-simplifiee.sql (22 epreuves). Ici on mesure ce qu'aucun
// banc SQL ne peut voir : que le navigateur ne porte aucune autorite, que les deux sessions ne se
// melangent pas, qu'aucune provenance administrative n'existe dans le code servi aux joueurs ni
// dans celui qui parle aux IA, et que le rafraichissement est discret.
//
// LE PIEGE DU COMMENTAIRE QUI NOMME CE QU'IL INTERDIT : toute mesure d'ABSENCE porte sur le code
// seul, commentaires retires. C'est la quatrieme fois en trois jours que ce piege se referme.
var RACINE = '/Users/fredericjasseron/ResPublica/';
function lire(f) { return readFile(RACINE + f); }

var pageAdmin  = lire('admin.html');
var authAdmin  = lire('admin-auth.js');
var panneau    = lire('admin-tribunal.js');
var justice    = lire('plateau-justice-economie.js');
var vercel     = lire('vercel.json');
var authJoueur = lire('auth.js');
var chat       = lire('api/chat.js');
var cron       = lire('api/cron-minuit.js');

var ko = 0, attendus = 0;
function att(n, c, detail) {
  attendus++;
  if (c) print('  ok  ' + n);
  else { print('  *** ' + n); if (detail !== undefined) print('        ' + detail); ko++; }
}
// LE PIEGE S'EST REFERME SUR CE BANC LUI-MEME, A SA PREMIERE EXECUTION. Un filtre ligne a ligne
// ne retire PAS un commentaire de bloc : les en-tetes de admin-auth.js et admin-tribunal.js
// expliquent precisement ce qu'ils interdisent -- ils citent `respublica_auth_session`,
// `rpAuthJeton`, « Saad », « Cozetoujours » -- et quatre mesures d'ABSENCE sont tombees sur ces
// phrases. On retire donc les blocs /* ... */ et <!-- ... --> AVANT de retirer les lignes //.
function codeSeul(t) {
  var sansBlocs = t.replace(/\/\*[\s\S]*?\*\//g, ' ').replace(/<!--[\s\S]*?-->/g, ' ');
  return sansBlocs.split('\n').filter(function (l) { return !/^\s*\/\//.test(l); }).join('\n');
}
function bloc(t, debut, fin) {
  var i = t.indexOf(debut); if (i < 0) return '';
  var j = t.indexOf(fin, i); return j < 0 ? t.slice(i) : t.slice(i, j);
}

print('BANC ADMINISTRATION -- COTE NAVIGATEUR');
print('');

print('1. DEUX SESSIONS QUI NE SE MELANGENT PAS');
att('la page d administration existe et charge ses deux modules',
    pageAdmin.indexOf('admin-auth.js') >= 0 && pageAdmin.indexOf('admin-tribunal.js') >= 0);
att('et elle ne charge NI auth.js NI supabase.js -- les deux modules du joueur',
    codeSeul(pageAdmin).indexOf('src="auth.js') < 0
    && codeSeul(pageAdmin).indexOf('src="supabase.js') < 0);
att('la cle de stockage est distincte de celle du joueur',
    authAdmin.indexOf("'respublica_admin_session'") >= 0
    && authJoueur.indexOf("'respublica_auth_session'") >= 0
    && codeSeul(authAdmin).indexOf('respublica_auth_session') < 0);
att('le module d administration ne lit jamais le jeton du joueur',
    codeSeul(authAdmin).indexOf('rpAuthJeton') < 0
    && codeSeul(authAdmin).indexOf('rpAuthSession') < 0
    && codeSeul(authAdmin).indexOf('sbEnTetes') < 0);
att('et le plateau ne lit jamais le jeton d administration',
    codeSeul(lire('supabase.js')).indexOf('rpAdminJeton') < 0
    && codeSeul(authJoueur).indexOf('rpAdminJeton') < 0);
att('l adresse /admin est routee, elle n est pas un secret',
    vercel.indexOf('"/admin"') >= 0 && vercel.indexOf('/admin.html') >= 0);
att('la page n est pas indexee -- ce qui n est pas une securite, et ne pretend pas l etre',
    pageAdmin.indexOf('noindex') >= 0);

print('');
print('2. AUCUNE AUTORITE DANS CE NAVIGATEUR');
att('le panneau n appelle QUE les deux portes d administration',
    codeSeul(panneau).indexOf("rpAdminRpc('admin_tribunal_dossiers'") >= 0
    && codeSeul(panneau).indexOf("rpAdminRpc('admin_incarner'") >= 0);
att('et il n appelle aucune porte metier directement -- il incarne, il ne contourne pas',
    codeSeul(panneau).indexOf('parquet_') < 0 && codeSeul(panneau).indexOf('justice_relaxer') < 0
    && codeSeul(panneau).indexOf('justice_rendre_sentence') < 0);
att('aucune ecriture de table, aucun SQL, aucun super-bouton',
    codeSeul(panneau).indexOf('/rest/v1/') < 0 && codeSeul(panneau).toLowerCase().indexOf('update ') < 0
    && codeSeul(panneau).toLowerCase().indexOf('forcer') < 0);
att('le module d appel ne retombe JAMAIS sur la cle anon pour agir',
    bloc(authAdmin, 'async function rpAdminRpc(', 'if (Array.isArray(d))')
      .indexOf("'Authorization': 'Bearer ' + jeton") >= 0
    && bloc(authAdmin, 'async function rpAdminRpc(', 'if (Array.isArray(d))')
      .indexOf("Bearer ' + RP_ADMIN_ANON") < 0);
att('et un refus serveur est rendu comme un refus, pas avale',
    authAdmin.indexOf('refus_serveur: true') >= 0);
att('le panneau ne decide d aucun pouvoir depuis localStorage',
    codeSeul(panneau).indexOf('localStorage') < 0);
att('les actions proposees viennent du SERVEUR, pas d une liste ecrite ici',
    codeSeul(panneau).indexOf('ADMIN_ETAT.actions') >= 0
    && codeSeul(panneau).indexOf("a.poste === poste") >= 0);

print('');
print('3. L INTERVENTION EST INVISIBLE AUX JOUEURS');
var fichiersJoueur = ['plateau-core.js', 'plateau-justice-economie.js', 'plateau-politique.js',
                      'plateau-pnj.js', 'plateau-multijoueur.js', 'plateau-personnage.js',
                      'plateau-router.js', 'supabase.js', 'auth.js', 'data.js', 'plateau.html'];
var fuite = [];
fichiersJoueur.forEach(function (f) {
  var t = codeSeul(lire(f));
  ['admin_journal', 'admin_incarner', 'administrateurs', 'admin_tribunal_dossiers',
   'rp.incarnation', 'incarnation_courante'].forEach(function (mot) {
    if (t.indexOf(mot) >= 0) fuite.push(f + ' -> ' + mot);
  });
});
att('aucun fichier du plateau ne nomme le socle d administration',
    fuite.length === 0, fuite.join(' | '));
att('aucune route api/ ne le nomme non plus -- ni le cron, ni le dialogue des PNJ',
    codeSeul(chat).indexOf('admin_') < 0 && codeSeul(chat).indexOf('incarnation') < 0
    && codeSeul(cron).indexOf('admin_') < 0 && codeSeul(cron).indexOf('incarnation') < 0);
att('le contexte envoye aux IA ne peut donc porter aucune provenance',
    codeSeul(chat).indexOf('administrateur') < 0);
att('CRON_SECRET n est pas detourne en identite administrateur',
    codeSeul(authAdmin).indexOf('CRON_SECRET') < 0 && codeSeul(panneau).indexOf('CRON_SECRET') < 0
    && codeSeul(pageAdmin).indexOf('CRON_SECRET') < 0);
att('aucun mot de passe, aucun secret en clair dans le depot',
    codeSeul(authAdmin).indexOf('password:') < 0 || authAdmin.indexOf('password: motDePasse') >= 0);

print('');
print('4. LE RAFRAICHISSEMENT EST DISCRET, ET MUET');
att('le panneau relit periodiquement',
    panneau.indexOf('ADMIN_PERIODE_MS') >= 0 && panneau.indexOf('setInterval(') >= 0);
att('et il se tait quand l onglet n est pas visible',
    bloc(panneau, 'ADMIN_MINUTEUR = setInterval(', '}, ADMIN_PERIODE_MS);')
      .indexOf('document.hidden') >= 0);
att('un compteur sobre, pas une alerte',
    panneau.indexOf("admEl('adm-compteur')") >= 0 && panneau.indexOf('en attente') >= 0);
att('AUCUN SON, et aucune notification intrusive',
    codeSeul(panneau).indexOf('Audio') < 0 && codeSeul(panneau).indexOf('Notification') < 0
    && codeSeul(pageAdmin).indexOf('<audio') < 0 && codeSeul(panneau).indexOf('alert(') < 0);

print('');
print('5. LE PERIMETRE NE S ELARGIT PAS');
att('deux postes, et deux seulement, dans l ecran',
    codeSeul(panneau).indexOf("'procureur'") >= 0 && codeSeul(panneau).indexOf("'juge'") >= 0
    && codeSeul(panneau).indexOf("'president'") < 0 && codeSeul(panneau).indexOf("'maire'") < 0
    && codeSeul(panneau).indexOf("'commissaire'") < 0 && codeSeul(panneau).indexOf("'depute'") < 0);
att('aucun PNJ n est nomme en dur : le titulaire vient du serveur',
    codeSeul(panneau).indexOf('Saad') < 0 && codeSeul(panneau).indexOf('Cozetoujours') < 0);
att('et la declaration du premier compte est la seule porte d entree de l autorite',
    codeSeul(panneau).indexOf("rpAdminRpc('admin_se_declarer'") >= 0
    && codeSeul(panneau).indexOf('bootstrap_ouvert') >= 0);

print('');
print('6. SE DEFENDRE : LE DOMAINE NE BOUGE PAS, LE JET A CHANGE DE COTE');
var bDef = bloc(justice, 'async function doDefense(', 'const cur =');
att('le double critere du filtre est inchange -- 2 jours ET categorie hors crime',
    bDef.indexOf('ref.jours > 2') >= 0 && bDef.indexOf("cat !== 'crime'") >= 0
    && bDef.indexOf('!!cat &&') >= 0);
att('et il reste un simple filtre d ergonomie : la decision est nommee serveur',
    justice.indexOf('plainte_defendre(p_affaire_id)') >= 0);
var bTout = bloc(justice, 'async function doDefense(', '\nasync function doCorruption(');
att('les refus neufs de la porte sont nommes au joueur',
    bTout.indexOf("'pas_d_avocat_commis_d_office'") >= 0
    && bTout.indexOf("'pas_de_tribunal'") >= 0);
att('les trois issues affichees sont celles du serveur : relaxe, peine reduite, condamnation',
    bTout.indexOf("'Relaxe'") >= 0 && bTout.indexOf("'Peine réduite'") >= 0
    && bTout.indexOf("'Condamnation'") >= 0);
att('la peine n est jamais recomposee ici : la fiche est RELUE quand une detention s ouvre',
    bTout.indexOf('vDef.detention_id') >= 0 && bTout.indexOf('chargerPersonnage()') >= 0
    && codeSeul(bTout).indexOf('est_emprisonne =') < 0);
att('et l ecran annonce que la procedure simplifiee ne souffre aucun appel',
    bTout.indexOf('aucun appel') >= 0);

print('');
if (ko === 0) print('LES ' + attendus + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + ko + ' epreuve(s) sur ' + attendus + ' en defaut.');
