# Criminalité — règles du game designer

Décisions de Fred, 18 novembre 2026, session claude.ai. **Document en cours : la criminalité ne se limite pas à la neutralisation, d'autres volets restent à trancher. NE PAS CODER avant le prompt complet « Criminalité » de Fred.**

Remplace la note « Assassinats discrets » de `GAME-DESIGN-QUESTIONS-APRES-SOVARKA.md`.

## Esprit

- La criminalité est un moteur de jeu important : ni dissuadée, ni intouchable.
- L'identité de l'assassin doit rester inconnue dans la grande majorité des cas, pour entretenir la tension liée au risque d'être neutralisé.

## 1. Se dissimuler avant d'agir

Trois façons d'agir :

- **À visage découvert** : le PJ apparaît normalement. La victime connaît **toujours** son agresseur, quelle que soit l'issue.
- **Caché** (ordre « Se cacher ») : le PJ est dans la pièce et voit tout, mais n'apparaît pas dans la liste des présents.
- **Masqué** (masque de carnaval revêtu) : le PJ apparaît comme « Individu masqué », sans portrait ; plusieurs masqués dans la même pièce sont numérotés (« Individu masqué n°1 », « n°2 »).
- Caché et masqué se cumulent : débusqué, il n'apparaît que comme individu masqué.

### Se cacher

- 1 PA. Vaut pour la pièce courante ; **reste actif après une tentative de neutralisation**, jusqu'à la sortie de la pièce (même règle à appliquer à l'empoisonnement, qui consomme aujourd'hui la cachette).
- Réussite : **70 % + 5 % par tranche de 20 points de DIS** (95 % à 100 de DIS) **+ 15 % avec la tenue ninja**, **plafond 98 %**.
- **Échec critique** = les 2 derniers points du jet, quel que soit le taux (au plafond de 98 %, tout échec est critique) : **−15 de moral**, rien d'autre.
- Échec ordinaire : seul le PA est perdu, personne n'est prévenu, on peut réessayer.

### Fouiller

- Débusque un PJ caché. 1 PA, ouvert à tous (vérifier si l'ordre existant `fouiller_lieux` peut servir de base).
- Réussite : **40 %** de base, **+2 % par point de PER** du fouilleur, **−1 % par tranche de 10 de DIS** du PJ caché, **−15 %** s'il porte la tenue ninja, **+20 %** pour un policier ou un agent de sécurité privée. **Minimum 10 %, maximum 90 %.**
- Un PJ débusqué perd sa cachette mais garde son masque.

## 2. Neutraliser

- Ouvert à toutes les carrières ; +15 pour la carrière criminelle ; coûts en PA inchangés (2 / 2 / 3) ; formule de réussite actuelle conservée.
- **Frapper depuis sa cachette : +10 % de réussite.** Le masque seul ne donne aucun bonus.
- **Gilet pare-balles revêtu** par la cible : −20 % aux chances de la neutraliser à l'arme à feu, −5 % à mains nues ou à l'arme blanche.

### Réussite

- La victime tombe à 0 PA et part à l'hôpital (règle existante).
- La victime apprend : le nom de l'agresseur s'il était à visage découvert, sinon « un inconnu » (caché) ou « un individu masqué ».
- **Jet de détection** (30 / 40 / 60 % selon le mode) : **−20 si caché, −10 si masqué, minimum 5 %**. Une détection **sans masque** identifie l'assassin ; **avec masque**, elle ne donne pas de nom et laisse seulement une trace.

### Échec

- **Échec critique = 2 % des échecs** :
  - **sans masque** : identité révélée (assassin identifié) et −15 de moral ;
  - **avec masque** : identité non révélée, −15 de moral ; le passage au combat se décide ensuite par le jet normal.
- **Passage au combat** : **10 % des échecs** de base, **+2 % par point de PER de la victime au-dessus de 10**, **+15 %** si la victime a un garde du corps ou une agence de sécurité, **−10 %** si l'assassin était caché ; **minimum 2 %, maximum 40 %**.
- **Échec sans combat** : l'assassin garde sa cachette et peut retenter s'il a des PA. La victime reçoit : « X a tenté de vous neutraliser » (visage découvert), « Quelqu'un a tenté de vous neutraliser » (caché sans masque), « Un individu masqué a tenté de vous neutraliser » (masqué).

### Combat

- Le moteur de combat existant ne change pas.
- **Assassin vaincu** : identifié.
- **Assassin vainqueur** : compte comme une réussite (hôpital pour la victime, jet de détection) ; il perd sa cachette mais garde son masque.

## 3. Justice et enquête

- **Pas d'enquête automatique** : la police n'enquête que sur plainte.
- **Assassin identifié** (visage découvert, détection sans masque, échec critique sans masque, défaite au combat) : **recherché par la police et condamné d'office à 2 jours de prison**, sans plainte. La victime peut ensuite porter plainte contre lui pour des **dommages et intérêts** lors d'un procès.
- **Plainte contre X** : l'enquête revient au **commissaire de la ville où l'agression a eu lieu**. Ordre « Enquêter », 2 PA, une tentative par jour et par plainte.
  - Plafond d'identification : **5 %** après une neutralisation réussie, **15 %** après une tentative ratée sans identification.
  - Départ à la moitié du plafond ; bonus jusqu'au plafond : trace (détection), rumeurs vraies visant le coupable, informateur du commissaire dans la ville.
  - Réussite : coupable identifié (recherché, 2 jours de prison d'office ; dommages et intérêts possibles).
  - Première enquête ratée sur une plainte (**une seule fois par plainte**) : le criminel reçoit « Le commissaire X est sur vos traces. Vous n'êtes pas identifié pour l'instant, mais vous n'avez plus droit à l'erreur. » **−20 de DIS, −15 de moral.**

## 4. Rumeurs

- Pour un agresseur anonyme, les rumeurs donnent des **indices partiels**, façon « Qui est-ce ? » : **le genre** (« l'assassin semblait être une femme ») et **le type précis d'arme** (kalachnikov, revolver, carabine…). Pas l'origine, la carrière ni le domicile.
- Les **traits physiques** s'ajouteront quand le générateur 2D du personnage sera codé.
- Un criminel peut lancer une **fausse piste** avec une rumeur fausse (coût de l'ordre « Lancer une rumeur » actuel).

## 5. Équipement

- Vêtements rangés dans l'inventaire. Ordres **« Revêtir »** (générique : sert aussi au gilet pare-balles et à d'autres accessoires) et **« Retirer »**, **0 PA**. Un vêtement retiré n'a plus d'effet.
- Une **arrestation** retire le masque d'office, avec une **animation de démasquage** (« Bas les masques ! », scène et personnages originaux). À l'hôpital ou en détention, tous les vêtements portés sont retirés et reviennent dans l'inventaire.
- **Tenue ninja** : +15 % à « Se cacher », −15 % aux fouilles qui la visent. Famille Habillement, sous-types *civil* **et** *militaire* (boutique de farces et attrapes / déguisements). Coût de revient 120 FR, prix PNJ 240 FR ; 30 PSK en Sovarka.
- **Masque de carnaval** : anonymat. Famille Habillement, sous-type *civil*. Coût de revient 25 FR, prix PNJ 50 FR ; 8 PSK en Sovarka.
- **Gilet pare-balles** : 380 FR en Républia, **60 PSK en Sovarka** (aujourd'hui vendu au prix de Républia dans l'armurerie de Novomirsk et au Chasse et Pêche de Starovka).

## 6. Cadre commun à tous les crimes (décisions du 18/11, soir)

- Le cadre **visage découvert / caché / masqué** (ce que la victime apprend, malus de détection −20 caché / −10 masqué, trace sans nom avec masque, plainte contre X et enquête du commissaire) s'applique à **tous les crimes commis dans une pièce**.
- **Neutraliser et voler peuvent viser un PNJ** (ex. employé à qui l'on a confié de la marchandise) : caractéristiques réelles du PNJ, sinon PER 8 ; l'**employeur** reçoit l'alerte (auteur désigné selon le mode) et porte plainte ; un PNJ neutralisé est hors service jusqu'au lendemain et garde la marchandise ; il peut se défendre (même risque de combat, ses caractéristiques ou des valeurs moyennes).
- **Dissuasion des hommes armés** (#135, en production) : conservée pour tous les crimes, vol et cambriolage compris (sinon agents, policiers et soldats ne servent à rien).
- **Peines automatiques** : 2 jours (assassin identifié) et 1 jour (voleur pris) sont les valeurs de **Républia** ; chaque empire aura les siennes selon son historique et sa sévérité (à fixer empire par empire).

## 7. Vol sur une personne

- Ordre « Voler » sur un PJ ou un PNJ présent. Trois cibles : **argent liquide** (jamais le compte en banque), **objet tiré au hasard**, **objet précis** (le voleur nomme un **type** — arme, clé, médicament… — sans voir l'inventaire ; si la victime n'en a pas, échec sans autre risque, PA perdus).
- **Coût** : 2 PA (argent ou objet au hasard), 3 PA (objet précis).
- **Réussite** : base argent **55 %**, objet au hasard **45 %**, objet précis **25 %** ; **+1 % par tranche de 3 de DIS du voleur au-dessus de 50** (−1 % en dessous) ; **−3 % par point de PER de la victime au-dessus de 8** (+3 % en dessous), **PER de groupe** si la victime est groupée (règle existante) ; **+15 %** carrière criminelle ; **5-85 %**. Être caché ne change pas la réussite, seulement l'anonymat. Pas de malus propre aux gardes du corps (PER de groupe et risque de combat suffisent ; la dissuasion des hommes armés présents s'applique).
- **Butin en argent** : tirage **10 à 30 %** du liquide ; **+1 point par tranche de 10 de DIS au-dessus de 50** (−1 en dessous) ; **−1 point par point de PER (ou PER de groupe) au-dessus de 8** (+1 en dessous) ; **+5** carrière criminelle ; borné **10-30 %** et **2 000 FR** par vol.
- **Objets volables** : tout l'inventaire non porté (armes non portées, médicaments, nourriture, clés, vêtements non revêtus, graisses). **Non volables** : ce qui est revêtu ou porté, biens immobiliers et titres, objets liés au poste. Une pile : **une unité** par vol. Objet au hasard : tirage parmi les volables ; aucun → échec sans risque, PA dépensés.
- **Réussite** : la victime s'aperçoit du vol (« On vous a dérobé 340 FR / votre revolver »), auteur désigné selon le mode ; jet de détection **30 %** (−20 caché, −10 masqué, min 5 %).
- **Réussite critique** (5 % des réussites, au-delà de 95 sur le jet) : la victime ne découvre le vol qu'**au prochain réveil**, sans pouvoir le relier à une rencontre ; **pas de jet de détection**.
- **Échec ordinaire** : remarqué **50 %** de base, **+3 % par point de PER (ou PER de groupe) au-dessus de 8**, **−1 % par tranche de 3 de DIS au-dessus de 50** ; **10-90 %**. Remarqué : « X / Quelqu'un / Un individu masqué a tenté de vous voler ». Le voleur garde sa cachette et peut retenter.
- **Échec critique** : 2 % des échecs (identifié sans masque, −15 moral ; avec masque −15 moral seulement).
- **Combat** : 10 % des échecs, modificateurs de la neutralisation (+2 % par point de PER de la victime au-dessus de 10, +15 % garde du corps ou agence, −10 % caché ; 2-40 %).
- **Voleur pris et arrêté** : **1 jour de prison d'office** (valeur Républia).

## 8. Cambriolage

- **Crochetage** (« Crocheter ») : 3 PA, **kit de crochetage** dans l'inventaire. Réussite **30 %**, **+1 % par tranche de 2 de DIS au-dessus de 50**, **+15 %** carrière criminelle ; **5-80 %**. Échec ordinaire : rien, on peut réessayer. Échec critique (2 % des échecs) : le kit casse dans la serrure, trace de tentative sans nom pour le propriétaire. Réussite : porte ouverte sans trace, serrure intacte et refermée derrière.
- **Kit de crochetage** : quincaillerie (armureries et armureries-quincailleries qui vendent les serrures), vente libre mais **chaque achat laisse une trace** utilisable par l'enquête ; **80 FR / 15 PSK** ; détruit après **5 crochetages réussis**.
- **Effraction** (« Forcer la porte ») : 2 PA, à mains nues ou au **pied-de-biche** (quincaillerie, achat tracé, **40 FR / 8 PSK**). Réussite **40 %**, **+3 % par point de FOR au-dessus de 8**, **+25 %** pied-de-biche, **+10 %** carrière criminelle ; **10-95 %**. Réussite : **serrure détruite** (règle existante : jamais récupérable), lieu ouvert, propriétaire prévenu aussitôt (« Votre porte a été forcée ») ; détection **60 %** (−10 masqué ; caché ne compte pas, le bruit trahit). Échec : la serrure tient, le propriétaire est alerté sans nom ; on peut réessayer.
- **À l'intérieur** :
  - **Objets déposés et souvenirs de l'armoire** : ils **se ramassent**, ce n'est pas un vol ; l'acte illégal est l'effraction (porte ou armoire). **Le propriétaire peut quand même porter plainte pour vol.**
  - **Matériel installé** (ordinateur, box) : 2 PA pour le désinstaller et l'emporter, sans jet ; découvert au retour du propriétaire.
  - **Stock d'un commerce** : vol, 2 PA, une pile par ordre, **10-20 % de la pile**, renouvelable.
  - **Caisse d'un commerce** : vol, 2 PA, **10-30 % du contenu, 3 000 FR max**.
  - Lieu vide : pas de jet de réussite, mais **jet de détection par vol** (30 %, −20 caché, −10 masqué, min 5 %) ; constat au prochain passage ou au prochain point de caisse. Personnes présentes (employé PNJ, gérant, client) : règles du vol sur une personne (réussite, remarqué, combat).
- Idée pour plus tard : un **mot de passe** sur certains objets pour qu'un voleur ne puisse pas s'en servir.

## 9. Empoisonnement (aligné sur la neutralisation)

- L'**anonymat par nature** est conservé : même à visage découvert, la victime ne sait pas qui l'a empoisonnée (message mystérieux et annonce publique inchangés). Quatre poisons et quatre paliers conservés.
- **La cachette n'est plus exigée ni consommée** : c'est un bonus.
- **Réussite** : base **35 %** ; **+1 % par tranche de 3 de DIS au-dessus de 50** ; **−3 % par point de PER (ou PER de groupe) de la victime au-dessus de 8** (+3 % en dessous) ; **+10 %** caché ; **+15 %** carrière criminelle ; poison : **parapluie +5 %**, **GHB +10 % si la victime a bu dans la journée, −10 % sinon**, **polonium −10 %**, **vipère 0** ; pays conservés (Narco +20 %, Sovarka −10 %) ; dissuasion des hommes armés ; **5-85 %**.
- **L'échec total ne rend plus recherché d'office** : règle commune (échec critique 2 % des échecs : identifié sans masque, −15 moral) et jet de détection habituel après réussite.

## 10. Explosifs (risque plus élevé)

- **Réussite** : base **35 %** ; **+1 % par tranche de 3 de DIS au-dessus de 50** ; **+2 % par point d'INT au-dessus de 8** (−2 % en dessous) ; **+10 %** caché ; **+15 %** carrière criminelle ; **−30 %** bâtiment officiel (existant) ; dissuasion des hommes armés ; **5-75 %**.
- **Échec critique : 10 % des échecs** = **explosion prématurée** : le poseur tombe à 15 de santé comme les présents, identifié sans masque, −15 moral. Les autres échecs ne révèlent rien (fin du « recherché d'office » à chaque échec).
- **Détection après réussite** : **65 %**, −10 masqué, −20 caché, **min 30 %**.
- Inchangé : fermeture 5 jours, présents à 15 de santé.

## 11. Incendie

- **Réussite** : base **30 %** ; **+1 % par tranche de 3 de DIS au-dessus de 50** ; **+10 %** caché ; **+15 %** carrière criminelle ; **+15 %** avec un **bidon d'essence** ; **−15 %** pendant un **orage** dans la ville ; **+15 %** pendant une **canicule** ; dissuasion des hommes armés ; **5-80 %**.
- Règle commune : échec critique 2 % des échecs ; **détection après réussite seulement** (fin du jet à chaque tentative) : **70 %**, −10 masqué, −20 caché, **min 20 %**. Fermeture 1 à 3 jours selon le jet, inchangée.

## 12. Corruption (décisions du 18/11, 22 h)

- **Principe** : on ne code que la corruption de **PNJ**. Corrompre un poste tenu par un joueur (commissaire, policier, juge…) se joue entre joueurs, sans ordre (même règle que les ambassades, 25/10). La corruption se fait **face à face** : le cadre caché / masqué ne s'y applique pas.
- **Règle commune à toutes les corruptions de PNJ** (directeur et gardien du QHS, douanier, greffier, journaliste, armurier, gardien du goulag) :
  - **Réussite** : −5 DIS et rumeur de corruption (existante), **plus de jet de détection** (le PNJ acheté a intérêt à se taire).
  - **Échec critique = 2 % des échecs : dénonciation** — corrupteur identifié, recherché, **1 jour de prison d'office** (valeur Républia, à revoir par empire), −15 moral.
  - **Pas de bonus de carrière criminelle** sur la corruption (charme et influence, pas métier) : retirer aussi le +15 envisagé pour le gardien.
- **Directeur du QHS** (« Corrompre le directeur », 3 PA, 1 500 FR) : il ne peut pas renvoyer le détenu en geôle (le placement au QHS relève de l'autorité supérieure), mais **divise par deux la peine restante**, une seule réussite par détention. Échec : **+1 jour de peine**, les **1 500 FR confisqués** (caisse du QHS, sinon ministère), **plus aucune tentative** auprès du directeur jusqu'à la fin de la détention. Taux : **même formule que le gardien** ci-dessous.
- **Gardien de couloir du QHS** (« Corrompre un gardien », 2 PA, 800 FR) : trois services au choix —
  - **évasion facilitée** : **+25 %** à la prochaine tentative d'évasion (une seule tentative) ;
  - **message ou objet passé** : courrier à un joueur extérieur, ou remise d'un objet confié au gardien ;
  - **protection** : **pas de torture jusqu'au prochain ordre « Dormir »**.
  - Réussite : **30 % + 2 par point de CHA au-dessus de 8, −(ISN − 45)/3, bornes 5-75 %**.
  - Échec : les **800 FR confisqués** (caisse du QHS), **une tentative par jour**, retenter dès le lendemain.
- **« Falsifier un procès-verbal »** (salle d'interrogatoire du QHS) : **supprimé**.
- **Route `corrompre_police`** (orpheline, aucune pièce) : **supprimée**.
- **Douanier** : le +20 « zone transport » ne vaut plus que dans une zone de transport (correctif technique). Échec : les **300 FR confisqués au profit des douanes**, retenter dès le lendemain.
- **Le temps ne s'achète pas** dans les empires actuels : **suppression** de « Corrompre un fonctionnaire (accélérer) » (permis), « Accélérer le rendez-vous (corruption) » (notaire) et du bouton mort « Accélérer le chantier (corruption) ». Le temps s'achètera dans les futurs empires P2W.
- **Inchangés** (hors règle commune ci-dessus) : journaliste, greffier, armurier, gardien du goulag.

## 13. Délits d'information (décisions du 19/11, nuit)

- **Rumeur** (« Lancer une rumeur », 1 PA, gratuit) : anonyme par défaut, mais l'auteur doit être **plus facile à démasquer** que pour les autres crimes.
  - Réussite : **60 % + 1 par tranche de 3 de DIS au-dessus de 50 + 2 par point de CHA au-dessus de 8**, bornes **10-90 %** (remplace le 75 % fixe). Effets sur la cible inchangés.
  - **Échec critique : 10 % des échecs** — auteur identifié, la cible apprend son nom, la rumeur se retourne contre lui (« X a tenté de répandre des calomnies »), perte de POP pour l'auteur.
  - **Détection même après réussite** : **15 %, −1 par tranche de 10 de DIS, minimum 5 %** (remplace le jet actuel à chaque tentative).
  - **Bouche-à-oreille** : quand un joueur écoute les rumeurs (barman, tables, serveuse…), **10 %** de chances d'apprendre l'origine d'une rumeur récente (« On dit que c'est X qui fait courir ce bruit sur Y »).
  - **Plainte contre X** possible, enquête du commissaire (cadre commun).
  - Valeurs à ajuster après la bêta.
- **Tracts calomnieux** : inchangés (échec critique 10 % des échecs, flagrant délit ou mandat), **plus le bouche-à-oreille** : 10 % de chances, en écoutant les rumeurs, d'apprendre qui distribue des tracts contre qui.
- **Fabriquer un scandale** : inchangé (auteur public ; la victime réplique par une plainte en diffamation, jugée par un juge joueur).
- **Produire une fuite** : inchangée (fait réel uniquement, commanditaire secret, légal).

## 14. Mise en ordre des peines (décisions du 19/11, nuit)

- **Doublement « démasqué » conservé** : la peine d'office est **simple** quand le coupable est identifié sur le moment (visage découvert, échec critique, détection immédiate, défaite au combat), **doublée** quand il est démasqué plus tard par une enquête (celui qui a donné du fil à retordre à la police paie plus cher). Ex. assassin : 2 j sur le moment, 4 j démasqué ; voleur ou corrupteur : 1 j, 2 j démasqué.
- **Fin des catégories génériques lourdes** (délit grave 4 j, crime 8 j, crime d'État 30 j, héritées des débuts) : trop dissuasives, contraires à l'esprit du jeu. L'échelle de Républia est celle des barèmes propres (1 j délit, 2 j crime), doublement compris.
- **Seuil du procès : 4 jours.** Une peine automatique va jusqu'à 4 jours. Au-delà (cumul, cas lourds), le coupable fait **4 jours d'office**, puis un **procès** décide d'un éventuel complément.
- **Peine du juge** : en régime normal, **fourchette de ±50 %** autour de la somme des peines de référence, contrôlée par le serveur (il refuse ce qui en sort). **Sous l'état d'urgence : liberté totale du juge.**
- **État d'urgence limité à 7 jours**, renouvelable par le Président (chaque renouvellement : 3 PA et la perte de POP habituelle). Aujourd'hui il n'expire jamais : à corriger.
- **Correctifs techniques** (sans décision de game design) : une seule nomenclature par infraction (`assassinat` / `assassiner_*`, `corruption_fonctionnaire` / `corrompre_fonct`, `achat_arme_illegal` / `acheter_arme_illegale`…), rattacher les 11 barèmes jamais détectables à leurs actes, supprimer les durées en dur qui contournent le barème (garde à vue 2 j, évasion 2 j, rébellion 1 j) au profit de la résolution unique.
- **Rébellion en cellule** (« Se rebeller », geôles des commissariats ; réussite min(60, 3 VOL + FOR du codétenu / 2), inchangée) :
  - **Rébellion réussie** : effets actuels (DIS +6, PV −10, +1 jour) et **elle abîme les grilles** (4 à 10 points). **Rébellion matée** : les gardiens interviennent avant, **aucun dégât aux grilles** ; PV −25, DIS −15, **+4 jours d'office, plus de QHS automatique de 30 jours** (le placement au QHS reste une décision de l'autorité supérieure).
  - **Grilles abîmées = bonus d'évasion pour tous les détenus de la cellule**, égal aux dégâts cumulés, **plafond +25 %**.
  - **Réparation par les gardiens** : chaque jour, 1/3 des dégâts (réparation complète en 3 jours), **100 FR par jour** (300 FR au total) pris sur la caisse du commissariat ; **pas d'argent, pas de réparation**.

## 15. Carrière criminelle (décisions du 19/11, nuit)

- La carrière `criminal_c` (« Crime organisé ») reste choisissable à la création.
- **Seconde carrière** (socle « Suivre une formation » de l'université, règles du 13/10 : seconde carrière sans effacer la première, une seule fois dans la vie, deux mois, gratuit) : un cursus universitaire **« Droit pénal »** donne en réalité la **carrière criminelle** (satire assumée : on apprend la loi pour mieux la contourner). **Stages chez Pat Hounette ou dans une organisation criminelle** (maître de stage PNJ garantissant la progression sans PJ, comme pour les autres cursus).
- **Effets : uniquement les bonus de réussite** décidés dans ce document (+15 neutraliser, voler, crocheter, empoisonner, explosifs, incendie ; +10 effraction ; rien sur la corruption). Pas d'avantage supplémentaire (marché noir, receleur, réflexes…).
- Le **+15 au vol** reste aussi accordé aux carrières **renseignement** et **escort**.

## Plus tard

- Le moral pourrait influencer tous les ordres à jet aléatoire (à étudier).
- Tous les volets sont tranchés : le document est prêt pour le prompt complet « Criminalité ».
