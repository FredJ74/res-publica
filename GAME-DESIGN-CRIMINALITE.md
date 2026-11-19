# Criminalité — règles du game designer

Décisions de Fred, 18-19 novembre 2026, session claude.ai. **Codage lancé le 19/11/2026.**

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
  - **Rébellion réussie** : effets actuels (DIS +6, PV −10, +1 jour) et **elle abîme les grilles** (4 à 10 points). **Rébellion matée** : les gardiens interviennent avant, **aucun dégât aux grilles** ; PV −25, DIS −15, **+4 jours d'office, plus de QHS automatique de 30 jours** (le placement au QHS reste une décision de l'autorité supérieure). (envoi au QHS : voir section 16)
  - **Grilles abîmées = bonus d'évasion pour tous les détenus de la cellule**, égal aux dégâts cumulés, **plafond +25 %**.
  - **Réparation par les gardiens** : chaque jour, 1/3 des dégâts (réparation complète en 3 jours), **100 FR par jour** (300 FR au total) pris sur la caisse du commissariat ; **pas d'argent, pas de réparation**.

## 15. Carrière criminelle (décisions du 19/11, nuit)

- La carrière `criminal_c` (« Crime organisé ») reste choisissable à la création.
- **Seconde carrière** (socle « Suivre une formation » de l'université, règles du 13/10 : seconde carrière sans effacer la première, une seule fois dans la vie, deux mois, gratuit) : un cursus universitaire **« Droit pénal »** donne en réalité la **carrière criminelle** (satire assumée : on apprend la loi pour mieux la contourner). **Stages chez Pat Hounette ou dans une organisation criminelle** (maître de stage PNJ garantissant la progression sans PJ, comme pour les autres cursus).
- **Effets : uniquement les bonus de réussite** décidés dans ce document (+15 neutraliser, voler, crocheter, empoisonner, explosifs, incendie ; +10 effraction ; rien sur la corruption). Pas d'avantage supplémentaire (marché noir, receleur, réflexes…).
- Le **+15 au vol** reste aussi accordé aux carrières **renseignement** et **escort**.

## 16. Envoi au QHS (décisions du 19/11, nuit)

- **Esprit** : le QHS est réservé aux détenus très dangereux (meneurs de rébellion qui risquent de provoquer des émeutes, multirécidivistes qui risquent de recruter en prison, détenus à éloigner de leur réseau). Il n'y a pas de verrou de critères : l'abus de pouvoir est possible, mais il se paie.
- **Qui décide** : le Ministre de la Justice envoie un détenu au QHS. Un juge peut proposer l'envoi lors d'un procès, et le Ministre valide. Le Ministre a trois réponses : valider directement, soumettre au référendum ou refuser (le détenu reste alors dans sa cellule ordinaire).
- **Suppléance** : si le poste de Ministre de la Justice est vacant ou tenu par un PNJ, le Premier ministre décide, avec les mêmes règles. Sans Premier ministre, toute demande est refusée automatiquement, par prudence.
- **Envoi direct** : tout envoi au QHS sans consultation est ressenti comme un abus de pouvoir. −5 POP pour chaque membre du gouvernement (Premier ministre et ministres), −10 POP pour le Ministre de la Justice (ou pour le Premier ministre s'il le supplée), et une rumeur sur le modèle de celle de la torture.
- **Référendum** : lui seul peut le lancer, au titre de Ministre de la Justice (ou le Premier ministre qui le supplée). C'est un acte de consultation, qui ne coûte rien quelle que soit l'issue. Si le oui l'emporte, l'envoi se fait sans pénalité. Si le non l'emporte, le détenu reste en cellule ordinaire ; si le gouvernement l'envoie quand même, la pénalité est doublée (−10 par membre du gouvernement, −20 au Ministre).
- **Électeurs** : toutes les personnes domiciliées dans le pays, quelle que soit leur nationalité. Un Républien domicilié à l'étranger ne vote pas, un Sovarkien domicilié en Républia vote. Une voix par PJ. Vote de 24 heures. Chaque domicilié reçoit un courrier à l'ouverture du référendum.
- **Vote des PNJ** : ils représentent l'état du pays et comptent comme un bloc fixe de 10 voix, réparties entre oui et non. Part de oui : 50 % ; +1 point pour chaque 2 points de Sécurité du pays sous 50 (−1 au-dessus) ; +1 point pour chaque 4 points de Moral du pays sous 50 (−1 au-dessus) ; −1 point pour chaque 2 points de POP du détenu au-dessus de 50 (+1 en dessous) ; bornes 10-90 %. Indices du pays ; à défaut d'indice national, moyenne des villes du pays.
- **Égalité** : le non l'emporte, parce que le doute profite au détenu.
- **Durée** : le QHS est un régime, pas une peine supplémentaire. Le détenu y purge le reste de sa peine et sort libre à la fin. Pour allonger la peine, il y a la fourchette de ±50 % du juge (section 14).
- **Sovarka** : le goulag est le QHS de Sovarka. Pas de pénalité et pas de référendum ; ses règles d'envoi existantes restent inchangées.

## Plus tard

- Le moral pourrait influencer tous les ordres à jet aléatoire (à étudier).
- Tous les volets sont tranchés : le document est prêt pour le prompt complet « Criminalité ».

## Audit de l'existant (19/11)

Relevé en production (`pg_proc` du projet `jxpwoosmmhohoihxpbuc`, lecture seule), avant le lot 1. Quand le dépôt diverge, c'est la production qui est décrite.

### Briques communes
- **Détection** : `crime_detecter_interne(nom, acte, selon_checkdetection, acte_recherche)`. Taux = `actes_illegaux.detect_rate`, ou `max(5, taux − DIS/10)` (président immunisé, ministres pour les délits mineurs) ; **+ `securite_malus_lieu_interne`** (dissuasion #135, plafond 100). Détecté : `crime_rechercher_interne` (recherché) et −10 DIS. **Ne connaît ni caché ni masqué.**
- **Dissuasion #135** : `securite_malus_lieu_interne(acteur)` = `min(40, 10 + hommes armés présents)` (agents privés et soldats via `securite_agents_prives_presents_interne`, gardes républicains). Ajoutée **au jet de l'acte et à la détection** : comptée deux fois pour les actes qui ont un jet propre.
- **Peines** : `crime_peine_interne(acte, demasque)` (découverte nocturne : `peine_jours`, sinon catégorie 2/4/8/30, doublée si démasqué seulement quand `peine_jours` existe) ; `peine_acte_interne(acte, pays)` (barème propre en Républia, sinon catégorie) ; `infraction_peine_bornes` (juge ±50 % **par infraction**, min 1).
- **Cachette** : `caches_pj` n'était lue que par `se_cacher` et `crime_empoisonner` (exigée puis consommée).

### Par acte (fonction serveur, formule réelle, écart au document)

| Acte | Fonction(s) en production | Réussite / échec / détection actuels | Écart principal |
|---|---|---|---|
| Se cacher (§ 1) | `se_cacher()` | `max(5, 70 + DIS/10 − malus ISN + 15)`, pas de plafond ni d'échec critique ; l'échec effaçait la cachette | **Refait au lot 1** |
| Fouiller (§ 1) | `fouiller_lieux()` (2 PA : caméras, trésor des Tsars) | 15 % + PER − 10 (75 % avec Couinator) ; ne cherche personne | **Lot 1** : `crim_fouiller_cachettes()` à part (1 PA), même résolution du lieu |
| Gilet (§§ 2, 5) | `militaire_gilet_absorber` (combat) ; achat `objet_acheter('acheter_gilet','gilet',…)` | Seul le gilet **militaire** comptait, porté ou non ; gilet civil sans effet ; prix écran 600 FR et 1 PA partout | **Lot 1** : compte seulement revêtu, gilet civil compris ; 380 FR / 60 PSK |
| Neutraliser (§ 2) | `crime_neutraliser` renvoie `combat_universel_requis` ; l'écran ouvre `combat_ouvrir` → `combat_ouvrir_interne` → `combat_agression_preparer_interne` / `combat_finaliser_interne` | **Aucun jet** : combat systématique ; victoire : trace + détection `agression`/`meurtre` (25) ; défaite : recherché (`tentative_assassinat`). Taux écran `neutraliserTaux` inutilisé hors députés (`assemblee_neutraliser_depute`, `assemblee_taux_neutralisation`) | Tout le § 2 (jet, +10 caché, gilet −20/−5, échec critique, combat 10 % des échecs) |
| Voler (§ 7) | `crime_voler(cible, genre, benediction, per_pnj, int_pnj)` ; `crime_voler_materiaux` ; `voler_materiel` | 50 + PER + CHA − (PER + INT victime) ± 25, carrière +15/−10, − ISN/3 − #135 ; butin 50-199 FR ; échec : amende d'empire ; pas de détection | Formule, butin 10-30 %, objet précis, PNJ, détection 30, échec critique, combat |
| Cambriolage (§ 8) | Aucun ordre. Serrures : `serrures`, `serrure_poser`, `serrure_basculer` ; `acces_forcer_passage` (accès gardés seulement) | — | Tout le § 8 (objets en vente depuis le lot 1) |
| Empoisonner (§ 9) | `crime_empoisonner(cible)` | `max(5, 35 + pays + 15 carrière − ISN)` sans plafond ; cachette exigée ; pas de PA prélevé au serveur ; échec total = recherché | Cachette **plus consommée** depuis le lot 1 ; reste du § 9 |
| Explosifs (§ 10) | `crime_explosifs(batiment)` | `max(5, 35 + 15 − ISN − 30 officiel)` ; détection 65 fixe ; tout échec = recherché | § 10 |
| Incendie (§ 11) | `crime_incendier(batiment)` | `max(5, 30 + 15 − ISN − 30 officiel)` ; détection 70 à chaque tentative | § 11 (le −30 officiel n'est pas au § 11) |
| Corruption (§ 12) | `crime_corrompre(fn, pa, cost)` (`corrompre_fonct`, `corrompre_gardien`, `corrompre_police`) ; `crime_corrompre_douanier(pa, cost, requete)` | 65 − ISN ; aucun effet de jeu ; détection 30/35 ; douanier 55 + DUP/10 + INF/10 + 20 inconditionnel | § 12 |
| Rumeur (§ 13) | `rumeur_lancer(type, cible, texte, cible_trace, pa, cost)` | 75 % fixe ; détection 35 − DIS/10 à chaque tentative | § 13 |
| Plainte contre X, enquête (§ 3) | `plainte_deposer` (cible vide = X, `plaintes_en_cours`) ; `commissaire_enquete_mener(cible, benediction)` | Enquête sur un suspect **nommé** (35 + 2×ΔPER …, 10-90) ; garde à vue 2 j en dur | § 3 (plafonds 5/15 %, indices, « sur vos traces ») |
| État d'urgence (§ 14) | `etat_urgence_decider(activer)`, table `etats_urgence` | N'expire jamais ; ne lève pas la fourchette du juge | § 14 |
| Rébellion (§ 14) | `detention_se_rebeller` | Grilles abîmées même matée ; matée = QHS 30 j ; grilles sans effet sur l'évasion | § 14 |
| Carrière (§ 15) | +15 `criminal_c` en dur dans voler, empoisonner, explosifs, incendie, député, achats au marché noir | `suivre_formation` désactivé | § 15 |

### Barèmes
- `actes_illegaux` et `infractions` coexistent avec des **doublons divergents** : `assassinat`/`tentative_assassinat`/`meurtre` 2 j contre `assassiner_mains|arme|feu` (catégorie crime, **8 j**) ; `corruption_fonctionnaire` 1 j contre `corrompre_fonct` 2 j ; `achat_arme_illegal` 1 j contre `acheter_arme_illegale` 2 j. Absents de `infractions` : agression, meurtre, manifestation_spontanee, contrebande_poissonniere, poser_camera, pirater, forcer_passage, voler_archives_ecoute.
- Catégories génériques encore actives : crime 8 j / 5 000, crime d'État 30 j, délit grave 4 j / 1 500, délit mineur 2 j / 500.

### Écarts majeurs à traiter par les lots suivants
1. La neutralisation de droit commun n'a plus de jet de réussite (§ 2 à reconstruire autour de `combat_ouvrir`, moteur inchangé).
2. Le cadre visage découvert / caché / masqué n'existait nulle part : helpers posés au lot 1 (`crim_mode_action_interne`…), à brancher dans la résolution commune.
3. Dissuasion #135 comptée deux fois (jet + détection).
4. Cambriolage et enquête sur plainte contre X inexistants.
5. Barèmes en double (voir ci-dessus).
6. Lecture publique de la vue `personnages` (position et inventaire de chacun, y compris `porte_par`) : un joueur outillé peut encore deviner qui est caché ou masqué. **À fermer** (hors lot 1 ; la table `presences` et la liste des présents sont, elles, filtrées).

## Lot 1 — ce qui est en place (19/11)

- Migration `20261119130000_crim_lot1_equipement_dissimulation` (appliquée après essai annulé).
- **Helpers serveur communs** : `crim_objet_categorie_interne(item)` (gilet, masque, tenue_ninja, ou clé `revetable`), `crim_porte_ligne_interne(item, nom)`, `crim_objet_porte_interne(nom, categorie)`, `crim_cache_interne(nom)`, `crim_masque_interne(nom)`, `crim_mode_action_interne(nom)` → `decouvert` / `cache` / `masque` / `cache_masque`, `crim_force_ordre_interne(nom)`, `crim_debusquer_interne(nom)`, `crim_vetements_retirer_interne(nom, categorie)`, `crim_jeton_resoudre_interne(jeton)` (cible d'un individu masqué), `crim_evenement_interne(nom, type, donnees)` + `crim_evenements_lire()`, `crim_param_interne(cle)` (table `crim_parametres`), `crim_stat_interne(nom, cle, defaut)`, `crim_prix_interne(cle, pays)`.
- **RPC** : `crim_revetir(index, signature)`, `crim_retirer(index, signature)`, `se_cacher()`, `crim_fouiller_cachettes()`, `crim_presents()`, `boutique_discretion_etat()`, `boutique_discretion_acheter(requete, cle)`.
- Tables : `crim_parametres`, `crim_boutiques`, `crim_traces_achat` (achats de kit et de pied-de-biche, pour l'enquête), `crim_evenements`, `crim_jetons_masque`.
- Écran : `plateau-criminalite.js` (boutique, Revêtir / Retirer, fouille des cachettes dans « Fouiller ou voler », animation « Bas les masques ! » en CSS, sans image).

### Valeurs provisoires (choisies par l'agent, à valider par Fred)
- **Points de vente** : tenue ninja et masque sur les **marchés** (Luthécia, Montrouge, PSM, Novomirsk, Starovka, Krasnov) faute de boutique de déguisements ; tenue ninja aussi chez les **armuriers** (sous-type militaire) ; kit, pied-de-biche et gilet chez les armuriers de Républia **et** de Sovarka (Novomirsk, Chasse et Pêche de Starovka), puisque des prix en PSK sont fixés. — *valeur provisoire choisie par l'agent, à valider par Fred*
- **Familles de commerce PJ** : les objets portent `famille` / `sousTypes` (habillement civil et militaire, bazar/outil, armement/protection individuelle) pour qu'un futur commerce PJ d'habillement les vende ; aucun commerce PJ d'habillement n'existe encore. — *valeur provisoire choisie par l'agent, à valider par Fred*
- **Autres empires** : prix de Républia (El Estado, Al-Khalija). — *valeur provisoire choisie par l'agent, à valider par Fred*
- **Gilets déjà détenus** : le premier gilet de chaque personnage a été marqué revêtu à la migration (personne ne perd sa protection) ; le **gilet civil** compte désormais en combat comme le gilet militaire (il n'avait aucun effet). Un seul objet porté par catégorie. — *valeur provisoire choisie par l'agent, à valider par Fred*
- **Se cacher** : le malus ISN de la ville et le +15 fixe de l'ancienne formule disparaissent (le document ne les prévoit pas) ; on ne peut pas se cacher si l'on est déjà caché (PA épargné). — *valeur provisoire choisie par l'agent, à valider par Fred*
- **Fouiller** : ordre distinct de « Fouiller les lieux » (caméras, 2 PA) ; un jet par PJ caché dans la pièce ; le débusqué est prévenu (nom du fouilleur, sauf s'il est masqué) ; un PJ policier = poste `commissaire*` ou `policier*` (aucun PJ agent de sécurité n'existe). — *valeur provisoire choisie par l'agent, à valider par Fred*
- **Démasquage** : l'animation est montrée au PJ arrêté seulement ; elle se déclenche à l'entrée en détention (`est_emprisonne`) ; hôpital et QHS rendent les vêtements sans animation. — *valeur provisoire choisie par l'agent, à valider par Fred*
- **Masqués numérotés** : numéro stable tant que la composition de la pièce ne change pas (ordre d'empreinte du nom). — *valeur provisoire choisie par l'agent, à valider par Fred*

## Lot 2 — ce qui est en place (19/11)

- Migration `20261119160000_crim_lot2_resolution_commune_neutraliser` (appliquée après essai annulé).
- **Résolution commune** `crim_resoudre_interne(acte, auteur, cible, params jsonb) → jsonb`, une seule fonction pour tous les actes :
  jet de réussite (taux fourni par l'acte, **dissuasion #135 retranchée une seule fois ici**, bornes `min`/`max`), réussite critique optionnelle
  (`critique_reussite_part`, `critique_sans_detection`), échec critique (`critique_echec_part`, 2 % des échecs : −15 moral, identifié sans masque),
  passage au combat (`combat: true` ; 10 % +2/PER > 10 +15 garde −10 caché, 2-40), victime qui remarque l'échec (`remarque_echec`, 100 % par défaut),
  **visage découvert = identifié dès que la victime s'aperçoit de l'acte** (§§ 1, 3), détection après réussite (`detection_base`, −20 caché,
  −10 masqué, `detection_min` ; sans masque identifie, avec masque trace sans nom), message à la victime selon le mode (`{Auteur}` = nom /
  « Quelqu'un » / « Un individu masqué », `{auteur}` = nom / « un inconnu » / « un individu masqué »), employeur d'un PNJ alerté et plainte
  déposée (`plaintes_en_cours`, origine `crim_affaire`), **affaire** enregistrée dans `crim_affaires` (mode, issue, trace, identifié, plafond
  d'identification 5 / 15 %, indices : genre, arme) pour l'enquête du lot 6, peine d'office si identifié (avis de recherche, barème).
  Suite d'un combat : `crim_resoudre_suite_interne(affaire, 'vainqueur' | 'vaincu' | 'sans_combat')`, appelée par `combat_finaliser_interne`.
- Briques : `crim_cible_resoudre_interne(auteur, cible)` (nom de PJ, **jeton d'un individu masqué**, PNJ référencé ; un PJ caché ou masqué
  n'est pas désignable par son nom), `crim_combat_taux_interne`, `crim_detection_taux_interne`, `crim_peine_jours_interne(acte, pays)`,
  `crim_designation_interne`, `crim_message_interne`, `crim_garde_cible_interne`, `crim_identifier_interne`, `crim_detection_interne`,
  `crim_affaire_notifier_interne`, `crim_neutraliser_taux_interne`.
- **Neutraliser** : `crime_neutraliser(cible, mode, requete)` (idempotent) ; jet serveur rétabli avec la formule historique (base 15 / 25 / 35
  + 2 × FOR / DUP / PER, 8 par défaut, +15 carrière criminelle, − PER de la cible / 2, plafonds 65 / 75 / 85, PA 2 / 2 / 3, −20 DIS à l'arme à
  feu), +10 depuis la cachette, gilet revêtu −20 / −5. Réussite : la victime tombe à 0 PA (hospitalisation existante), un PNJ est hors service
  jusqu'au lendemain. Combat (moteur inchangé) seulement par le passage au combat d'un échec : l'assassin perd sa cachette (garde son masque),
  vaincu = identifié, vainqueur = réussite (détection). Échec sans combat : cachette gardée, on peut retenter. L'ancienne signature
  `crime_neutraliser(text, text, integer)` répond `requete_requise`.
- **Peines** : `peine_jours_<acte>_<empire>` dans `crim_parametres` (Républia : assassinat et tentative 2 j) ; `peine_acte_interne` (barème des
  arrestations) lit la même valeur : **les autres empires reprennent Républia** (2 j au lieu de la catégorie « crime » 8 j) tant qu'ils n'ont pas
  leurs valeurs.
- Combat : un affrontement « civil » contre une personne ne s'ouvre plus directement par `combat_ouvrir` (`neutraliser_requis`) ; squatteurs,
  faune et gardes d'accès inchangés.
- Écran : Neutraliser (PJ, individu masqué par jeton, PNJ) passe par `crime_neutraliser` (`plateau-criminalite.js`, aucun taux calculé) ;
  bouton Neutraliser rétabli sur la fiche d'un joueur ; « Individu masqué n°X » visé par son jeton.

### Valeurs provisoires du lot 2 (choisies par l'agent, à valider par Fred)
- **Échec critique et passage au combat** : un seul jet ; l'échec critique est la part haute des échecs (2 % de l'intervalle d'échec), la réussite
  critique la part basse des réussites. Le jet de combat s'applique à **tous** les échecs, critiques compris (le document ne le précise que pour
  le masque). — *valeur provisoire choisie par l'agent, à valider par Fred*
- **Victime d'une neutralisation réussie** : PA à 0 (hôpital par la règle existante), PV inchangés. — *valeur provisoire choisie par l'agent, à valider par Fred*
- **PER de la cible PJ** : sa vraie PER (10 si absente) au lieu du 10 fixe de l'ancien écran. — *valeur provisoire choisie par l'agent, à valider par Fred*
- **Détection qui identifie** : −10 DIS à l'auteur (règle existante de `crime_detecter_interne` conservée). — *valeur provisoire choisie par l'agent, à valider par Fred*
- **Garde du corps ou agence** : agents de sécurité / maîtres-chiens employés par la victime (ou par l'employeur du PNJ visé), ou soldats qu'elle
  mène, présents au même endroit. — *valeur provisoire choisie par l'agent, à valider par Fred*
- **Peine d'office** : l'identification pose un avis de recherche (`assassinat` après réussite, `tentative_assassinat` après échec) ; les 2 jours
  s'appliquent à l'arrestation par le barème. — *valeur provisoire choisie par l'agent, à valider par Fred*
- **Combat qui ne peut pas s'ouvrir** (groupe dispersé, PNJ sans profil de combat…) : échec ordinaire. — *valeur provisoire choisie par l'agent, à valider par Fred*
- **PNJ visables** : seulement les PNJ référencés (`pnj_membres`, classes alpha et beta) ; « hors service » = PA du PNJ à 0, rechargés par le cycle
  quotidien existant ; plainte de l'employeur déposée aussi après un échec remarqué. — *valeur provisoire choisie par l'agent, à valider par Fred*
- **Messages** : courrier système « Événement » à la victime ou à l'employeur. — *valeur provisoire choisie par l'agent, à valider par Fred*

### Points relevés pour les lots suivants
- `minuit_decouverte_crimes` découvre encore chaque nuit, au hasard, les crimes tracés dans `historique_crimes` (assassinat, meurtre, agression…),
  ce qui contredit « pas d'enquête automatique » (§ 3). La neutralisation n'écrit plus dans `historique_crimes` ; les actes anciens si. Lot 6.
- Pendant un combat, les rapports de combat montrent les noms des participants : un assassin masqué passé au combat y est nommé. À traiter
  côté affichage du combat (le moteur ne change pas).
- `crime_detecter_interne` ajoute toujours la dissuasion #135 pour les actes non encore passés à la résolution commune (voler, empoisonner,
  explosifs, incendie…) : le double compte disparaît acte par acte (lots 3 à 5).
- La fiche d'un individu masqué propose encore « Parler », « Rejoindre », « Envoyer un mail » (sans effet utile sous un pseudonyme).

## Lot 3 — ce qui est en place (19/11)

- Migration `20261119190000_crim_lot3_voler` (appliquée après essai annulé ; seul le scénario a été rejoué après application).
- **Voler** : `crime_voler(cible, butin, type, requete)` (idempotent), une seule fonction serveur de vol sur une personne : PJ, individu
  masqué (jeton) ou PNJ référencé (caractéristiques réelles, sinon PER 8 ; liquide de `pnj_membres`, objets de `pnj_possessions`).
  Butin `argent` (liquide seulement) / `hasard` / `precis` + `type` (arme, cle, medicament, nourriture, vetement, graisse) ; 2 / 2 / 3 PA.
  Résolu par **la résolution commune** `crim_resoudre_interne` (aucune copie de jet, de détection ni de combat) : taux
  `crim_voler_taux_interne`, bornes 5-85 après la dissuasion #135 (une fois), réussite critique 5 % des réussites sans détection,
  échec critique 2 % des échecs, remarque de l'échec `crim_voler_remarque_interne`, combat (formule de la neutralisation, PER propre de la
  victime), détection 30 (−20 caché, −10 masqué, min 5), messages selon le mode, plainte de l'employeur d'un PNJ, affaire `crim_affaires`.
- **Butin** : `crim_voler_part_interne` (tirage 10-30 % ± modificateurs, borné 10-30), `crim_voler_montant_interne` (plafond 2 000) ;
  objets : `crim_vol_categorie_interne` (volable ? quel type ?), `crim_vol_objet_choisir_interne` (tirage parmi les volables), une unité par
  pile ; livraison `crim_voler_livrer_interne` (même transaction ; aussi après un combat gagné, raccord `crim_vol_combat_v1` dans
  `crim_resoudre_suite_interne`). Rien à prendre (ou type absent) : échec sans autre risque, PA dépensés, pas d'affaire.
- **PER de groupe** : `crim_per_groupe_interne` (règle #135 : moyenne des membres présents + effectif − 1 ; seul : sa PER).
- **Réussite critique** : la victime (ou l'employeur d'un PNJ) reçoit « En vous réveillant, vous constatez qu'on vous a dérobé … » à son
  prochain « Dormir » (`crim_vols_differes`, `crim_vols_reveil_interne`, raccord `crim_vol_reveil_v1` dans `pa_repos_nocturne`).
- **Peine** : `peine_jours_vol_republic` = 1 (les autres empires reprennent Républia) ; identifié = avis de recherche `vol` (délit mineur).
- **Combat commun** : `crim_combat_ouvrir_interne(auteur, r, ci, mode, requete)` ouvre le combat (moteur inchangé) pour Voler **et**
  Neutraliser (raccord `crim_combat_commun_v1` : le bloc de `crime_neutraliser` est remplacé par l'appel commun).
- **Ancienne route** `crime_voler(text, text, boolean, integer, integer)` (jet à paliers, butin 50-199 FR, amende d'empire) : répond
  `ordre_remplace`. Les amendes d'échec par empire (narco, soviet, khalija, républia) disparaissent avec elle.
- **Écran** (`plateau-criminalite.js`) : fiche d'une personne → « Voler » (trois butins, choix du type) ; menu « Fouiller ou voler » →
  « Voler quelqu'un » (présents de la pièce, masqués par jeton) ; aucun calcul ni estimation affichée. Coût 3 PA déclaré dans le module
  (`ORDRES_VOL`) pour le miroir `ordres_couts` (plans 97 / 219 et seeds régénérés).

### Valeurs provisoires du lot 3 (choisies par l'agent, à valider par Fred)
- **Liquide nul** : voler de l'argent à quelqu'un qui n'a pas de liquide = échec sans autre risque (comme l'objet absent). — *valeur provisoire choisie par l'agent, à valider par Fred*
- **Objets volables** : tout objet non revêtu de l'inventaire, matières premières comprises (catégorie « autre », visée seulement par
  l'objet au hasard) ; non volables : objets revêtus (`porte_par`), documents / actes / titres / récépissés / tracts, objets de quête
  (calepin, colis de Pat), dotation militaire (`origineMilitaire` = lié au poste). Une serrure n'est pas une clé. Aucune arme n'est
  « portée » tant qu'aucun ordre ne permet de la porter. — *valeur provisoire choisie par l'agent, à valider par Fred*
- **Types nommables** : arme, clé, médicament (soins, médicaments, trousses), nourriture (aliments comestibles, céréales, produits
  exotiques), vêtement (habillement, masque, tenue ninja, gilet non revêtu), bocal de graisse (castor, ours, renne). — *valeur provisoire choisie par l'agent, à valider par Fred*
- **Modificateurs « au-dessus » seulement pour la remarque de l'échec** : le document ne donne pas le sens inverse (+3/PER au-dessus de 8,
  −1/3 DIS au-dessus de 50). Les tranches de DIS sont tronquées vers zéro (DIS 49 : 0 ; DIS 47 : −1). — *valeur provisoire choisie par l'agent, à valider par Fred*
- **Réussite critique** : part basse des réussites (convention du lot 2), et non « au-delà de 95 sur le jet ». — *valeur provisoire choisie par l'agent, à valider par Fred*
- **PER** : PJ sans PER = 8 ; combat : PER propre de la victime (comme Neutraliser), PER de groupe pour la réussite, le butin et la remarque. — *valeur provisoire choisie par l'agent, à valider par Fred*
- **Combat** : le voleur se bat à mains nues ; s'il gagne, le vol réussit (butin livré, détection, messages) ; il perd sa cachette, garde son masque. — *valeur provisoire choisie par l'agent, à valider par Fred*
- **PNJ hors service** (PA 0) : on ne peut pas le voler (« il garde la marchandise »). Réussite critique sur un PNJ : l'employeur l'apprend à son réveil, sans plainte automatique. — *valeur provisoire choisie par l'agent, à valider par Fred*
- **Devise du message** : FR, ou PSK si le voleur est en Sovarka. — *valeur provisoire choisie par l'agent, à valider par Fred*
- **Rumeurs** : un vol réussi laisse la trace de rumeur existante (`crime_trace_rumeur_interne`), utile à l'enquête (lot 6). — *valeur provisoire choisie par l'agent, à valider par Fred*

### Points relevés pour les lots suivants
- Doublement de la peine si démasqué plus tard : lot 6 (la valeur simple 1 j est en place).
- `crime_voler_materiaux` et `voler_materiel` (matériaux et matériel installé) restent hors de ce lot : à rattacher au cambriolage (lot 4) s'il y a lieu.
- `crime_detecter_interne` n'est plus appelé par le vol : le double compte de la dissuasion disparaît pour cet acte.

## Lot 4 — ce qui est en place (19/11)

- Migration `20261119220000_crim_lot4_cambriolage` (appliquée ; scénario rejoué en essai annulé après application).
- **Crocheter** : `crim_crocheter(batiment, piece, requete)` (idempotent), sur une serrure posée et fermée (porte d'un local, depuis le
  bâtiment ; entrée d'un bâtiment, depuis la rue devant l'une de ses sorties) dont on n'a pas la clé. 3 PA, kit dans l'inventaire (le plus usé
  d'abord). Taux `crim_crocheter_taux_interne`, résolu par `crim_resoudre_interne` (dissuasion #135 une fois, bornes 5-80, échec critique 2 %
  des échecs, sans détection ni combat). Réussite : un usage de moins (kit détruit à zéro), passage personnel dans `crim_intrusions`, lu par
  `serrure_porte_fermee_interne` / `serrure_batiment_ferme_interne` (raccord `crim_passage_v1`) ; la serrure reste fermée pour les autres.
  Échec critique : kit cassé, courrier « Tentative de crochetage » sans nom au propriétaire, pas de moral perdu (raccord `crim_critique_moral_v1`
  de la résolution commune : paramètre `critique_moral`).
- **Forcer la porte** : `crim_forcer_porte(batiment, piece, requete)` (idempotent), 2 PA, pied-de-biche pris s'il est dans l'inventaire.
  Taux `crim_forcer_taux_interne`, bornes 10-95, pas d'échec critique ni de combat. Le propriétaire est la cible prévenue : réussite
  « Votre porte a été forcée … La serrure n° X est détruite. », échec « Quelqu'un a tenté de forcer votre porte … La serrure a tenu. » ;
  détection 60 avec le mode corrigé `crim_forcer_mode_detection_interne` (caché ne compte pas, masqué −10). Réussite : serrure `detruite`
  (motif `effraction`), jamais récupérable, ses clés n'ouvrent plus rien.
- **Intérieur** : `crim_cambriolage_lire()` (matériel installé d'autrui, piles du stock, présence d'une caisse ; rien sur les présents ni sur
  le montant) et `crim_cambrioler(cible, ref, requete)` (`materiel` | `stock` | `caisse`), 2 PA. Lieu vide : `reussite_auto` + détection 30.
  Personne présente (`crim_temoin_interne` : PJ — même caché —, PNJ référencé en service, ou employé au comptoir d'un commerce ouvert) : règles
  du vol sur une personne (`crim_voler_taux_interne` argent pour la caisse / hasard sinon, PER de groupe, remarque, réussite critique 5 %,
  combat par `crim_combat_ouvrir_interne`, butin livré au combat gagné : raccord `crim_cambriolage_combat_v1`). Livraison
  `crim_cambrioler_livrer_interne` ; constat différé `crim_constats` livré au prochain passage du propriétaire dans le lieu (raccord
  `crim_constat_passage_v1` de `navigation_interieure_personnage_interne`) ou à son prochain point de caisse (raccords `crim_constat_caisse_v1`
  de `retirer_caisse_fonds` / `alimenter_caisse_fonds`).
- **Objets déposés** : `objet_abandonne_ramasser` inchangé pour tous ; après une effraction ou un crochetage (intrusion active), une affaire
  `ramasser` est enregistrée au nom du propriétaire et un constat lui dit qu'il peut porter plainte pour vol (raccord `crim_ramasser_v1`).
- **Anciennes fonctions** : `voler_materiel(uuid)` (3 PA, jet de duplicité, arrestation en flagrant délit) est redirigée vers la règle du
  cambriolage (même RPC, réponse compatible). `crime_voler_materiaux` (matériaux d'un **chantier en plein air**) n'est pas un cambriolage
  (pas de porte ni de lieu fermé) : inchangée, avec sa formule et son double compte de la dissuasion, à reprendre si Fred le souhaite.
- **Peines** : `peine_jours_effraction_republic` = 1 (crochetage ou effraction identifiés) ; vol à l'intérieur : `vol` (1 j) ; les autres
  empires reprennent Républia.
- **Écran** : fenêtre « Fermé à clé » (`serrurePopupFermee(genre, batiment, piece)`) → « Crocheter — 3 PA », « Forcer la porte — 2 PA »
  (`crimBoutonsPorte`, `crimPorteAgir`) ; après réussite, entrée par la navigation ordinaire (le serveur revérifie). Menu « Fouiller ou voler »
  → « Emporter ce qu'il y a ici (2 PA) » (`crimOuvrirCambriolage`), qui remplace « Voler du matériel installé (3 PA) ». Coûts déclarés dans
  `ORDRES_CAMBRIOLAGE` pour le miroir `ordres_couts` (plans 97 / 219 et seeds régénérés).

### Valeurs provisoires du lot 4 (choisies par l'agent, à valider par Fred)
- **Modificateurs « au-dessus » seulement** : rien en dessous de 50 de DIS (crochetage) ni de 8 de FOR (effraction), le document ne donnant
  pas le sens inverse (même convention que la remarque du vol au lot 3). — *valeur provisoire choisie par l'agent, à valider par Fred*
- **Échec critique du crochetage** : pas de −15 de moral (le § 8 ne cite que le kit cassé et la trace) ; l'auteur n'est jamais identifié par
  cet échec. — *valeur provisoire choisie par l'agent, à valider par Fred*
- **Passage du crocheteur** : personnel (ni le groupe ni les autres), valable **2 heures** (`intrusion_minutes`), sans limite de passages. —
  *valeur provisoire choisie par l'agent, à valider par Fred*
- **Pied-de-biche** : utilisé d'office s'il est dans l'inventaire (pas de choix à l'écran). Pas d'échec critique à l'effraction (le § 8 n'en
  prévoit pas). — *valeur provisoire choisie par l'agent, à valider par Fred*
- **Propriétaire d'une porte** : le PJ qui a posé la serrure (`serrures.poseur`). — *valeur provisoire choisie par l'agent, à valider par Fred*
- **Peine de l'effraction / du crochetage identifiés** : 1 jour (barème « délit », comme le vol). — *valeur provisoire choisie par l'agent, à valider par Fred*
- **Matériel installé** : « sans jet » compris comme sans jet de réussite ; la détection par vol du lieu vide s'applique ; l'armoire à souvenirs
  reste hors du matériel emportable. — *valeur provisoire choisie par l'agent, à valider par Fred*
- **Stock** : au moins une unité par ordre (10-20 % d'une petite pile donnerait 0) ; la marchandise arrive comme objet empilable générique
  « marchandise » (nom du produit), sans les effets du produit vendu. Tirages de part sans modificateur de DIS ni de PER. — *valeur provisoire choisie par l'agent, à valider par Fred*
- **Témoin** : la personne présente la plus perceptive ; un **commerce ouvert au public** (sans serrure fermée ni intrusion en cours) a
  toujours un « employé au comptoir » (PER 8, sans profil de combat : un combat impossible vaut échec ordinaire), dont l'employeur PJ est
  alerté. Caisse = vol d'argent (base 55), matériel et stock = objet au hasard (base 45). — *valeur provisoire choisie par l'agent, à valider par Fred*
- **Constats** : seulement pour un propriétaire PJ (une organisation ou un PNJ n'en reçoit pas) ; pas de constat quand le propriétaire a été
  lui-même le témoin prévenu. « Point de caisse » = retrait ou apport de fonds du propriétaire. — *valeur provisoire choisie par l'agent, à valider par Fred*
- **Objets déposés** : affaire `ramasser` seulement pour l'auteur d'une intrusion active dans ce lieu (pas pour qui entre ensuite par la
  porte forcée). — *valeur provisoire choisie par l'agent, à valider par Fred*

### Points relevés pour les lots suivants
- Le contenu de l'armoire à souvenirs n'est pas codé : « souvenirs de l'armoire » n'a rien à ramasser ; crocheter / forcer ne visent que les
  portes (local, bâtiment), pas l'armoire.
- Les serrures de véhicules ne sont pas concernées.
- L'enquête (lot 6) dispose des affaires `crocheter`, `forcer_porte`, `cambrioler`, `ramasser` (cible = propriétaire) et de `crim_intrusions`.

## Tableau de correspondance (règle → statut → fonction serveur)

Statuts : **décidé** (dans le document), **implémenté** (en production), **testé** (essai en production annulé + bancs `outils/bancs/test-crim-lot1-equipement.cjs`, `outils/bancs/test-crim-lot2-resolution.cjs`, `outils/bancs/test-crim-lot3-voler.cjs`, `outils/bancs/test-crim-lot4-cambriolage.cjs`).

| § | Règle | Statut | Lot | Fonction serveur |
|---|---|---|---|---|
| 1 | Trois modes : visage découvert / caché / masqué, cumul | implémenté, testé (helpers) | 1 | `crim_mode_action_interne`, `crim_cache_interne`, `crim_masque_interne` |
| 1 | Caché absent de la liste des présents | implémenté, testé | 1 | `crim_presents`, RLS `presences_lecture_publique` |
| 1 | Masqué = « Individu masqué n°X », sans portrait | implémenté, testé | 1 | `crim_presents` |
| 1 | Se cacher : 1 PA, 70 + 5/20 DIS + 15 ninja, plafond 98 | implémenté, testé | 1 | `se_cacher`, `crim_cacher_taux_interne` |
| 1 | Échec critique (jet 99-100) : −15 moral | implémenté, testé | 1 | `se_cacher` |
| 1 | Cachette jusqu'à la sortie de la pièce, conservée après une tentative | implémenté, testé | 1 | déclencheur `crim_personnage_etat`, raccord `crime_empoisonner` |
| 1 | Fouiller : 1 PA, 40 + 2 PER − DIS/10 − 15 ninja + 20 police/sécurité, 10-90 | implémenté, testé | 1 | `crim_fouiller_cachettes`, `crim_fouiller_taux_interne` |
| 1 | Débusqué : perd la cachette, garde le masque | implémenté, testé | 1 | `crim_debusquer_interne` |
| 2 | Neutraliser ouvert à tous, +15 carrière, PA 2/2/3, formule actuelle | implémenté, testé | 2 | `crime_neutraliser(text,text,uuid)`, `crim_neutraliser_taux_interne` |
| 2 | +10 depuis la cachette ; masque sans bonus | implémenté, testé | 2 | `crim_neutraliser_taux_interne`, `crim_cache_interne` |
| 2 | Gilet revêtu : −20 arme à feu, −5 mains nues / arme blanche | implémenté, testé | 2 | `crim_neutraliser_taux_interne`, `crim_objet_porte_interne(cible,'gilet')` |
| 2 | Réussite : hôpital ; message selon le mode ; détection 30/40/60 −20 caché −10 masqué, min 5 ; masque = trace sans nom | implémenté, testé | 2 | `crim_resoudre_interne`, `crim_detection_interne`, `crim_affaire_notifier_interne` |
| 2 | Échec critique 2 % des échecs (avec / sans masque) | implémenté, testé | 2 | `crim_resoudre_interne` |
| 2 | Combat 10 % des échecs (+2/PER > 10, +15 garde, −10 caché, 2-40) | implémenté, testé | 2 | `crim_combat_taux_interne`, `crim_garde_cible_interne` |
| 2 | Échec sans combat : cachette gardée, message selon le mode | implémenté, testé | 2 | `crim_resoudre_interne`, `crim_affaire_notifier_interne` |
| 2 | Combat : vaincu identifié ; vainqueur = réussite, perd la cachette, garde le masque | implémenté, testé (ouverture et suite ; issue réelle d'un combat non jouée) | 2 | `crim_resoudre_suite_interne`, raccord `combat_finaliser_interne`, `crim_debusquer_interne` |
| 3 | Pas d'enquête automatique ; identifié = recherché + 2 j d'office ; dommages et intérêts | identifié → recherché + 2 j : implémenté, testé ; `minuit_decouverte_crimes` à retirer (lot 6) ; dommages et intérêts : décidé | 2 | `crim_identifier_interne`, `crim_peine_jours_interne`, raccord `peine_acte_interne` |
| 3 | Affaire enregistrée à chaque crime (trace, plafond 5 / 15 %, indices) ; plainte de l'employeur d'un PNJ | implémenté, testé | 2 | `crim_affaires`, `crim_affaire_notifier_interne` |
| 3 | Plainte contre X : commissaire de la ville, « Enquêter » 2 PA, 1/jour/plainte, plafonds 5/15 %, bonus (trace, rumeurs, informateur, traces d'achat) | décidé | 6 | (`crim_traces_achat` alimentée dès le lot 1) |
| 3 | Première enquête ratée : message, −20 DIS, −15 moral | décidé | 6 | — |
| 4 | Rumeurs à indices partiels (genre, arme) ; fausse piste | décidé | — | — |
| 5 | Revêtir / Retirer 0 PA ; retiré = sans effet | implémenté, testé | 1 | `crim_revetir`, `crim_retirer`, `crim_porte_ligne_interne` |
| 5 | Arrestation : masque retiré + « Bas les masques ! » | implémenté, testé (serveur) | 1 | déclencheur `crim_personnage_etat`, `crim_evenements_lire` |
| 5 | Hôpital, détention : vêtements rendus à l'inventaire | implémenté, testé | 1 | déclencheur `crim_personnage_etat`, `crim_vetements_retirer_interne` |
| 5 | Tenue ninja 240 FR / 30 PSK, habillement civil + militaire | implémenté, testé | 1 | `crim_objet_interne`, `boutique_discretion_acheter` |
| 5 | Masque de carnaval 50 FR / 8 PSK, habillement civil | implémenté, testé | 1 | idem |
| 5 | Gilet 380 FR / 60 PSK | implémenté, testé | 1 | `crim_prix_interne` |
| 6 | Cadre des trois modes pour tous les crimes en pièce | implémenté dans la résolution commune ; branché sur Neutraliser | 2 | `crim_resoudre_interne`, `crim_designation_interne` |
| 6 | Neutraliser et voler un PNJ (employeur alerté, hors service jusqu'au lendemain) | implémenté (essais sur PJ ; aucun PNJ référencé dans la pièce d'essai) | 2, 3 | `crim_cible_resoudre_interne`, `crim_affaire_notifier_interne`, `pnj_pa_fixer`, `crime_voler` |
| 6 | Dissuasion #135 conservée pour tous les crimes (une seule fois) | implémenté dans la résolution commune (vol, crochetage, effraction branchés ; actes anciens : double compte jusqu'à leur lot) | 2, 3, 4 | `crim_resoudre_interne`, `securite_malus_lieu_interne` |
| 6 | Peines automatiques par empire (Républia : 2 j / 1 j) | implémenté, testé (assassin 2 j, voleur 1 j, effraction 1 j) | 2, 3, 4 | `crim_peine_jours_interne`, `crim_parametres.peine_jours_<acte>_<empire>` |
| 7 | Voler un PJ ou un PNJ présent : argent liquide / objet au hasard / objet précis (type), 2 / 2 / 3 PA | implémenté, testé | 3 | `crime_voler(text,text,text,uuid)` ; ancienne route `ordre_remplace` |
| 7 | Réussite 55 / 45 / 25 ± DIS/3, −3/PER (de groupe) > 8, +15 criminelle / renseignement / escort, 5-85 ; caché sans effet ; dissuasion #135 | implémenté, testé | 3 | `crim_voler_taux_interne`, `crim_per_groupe_interne`, `crim_resoudre_interne` |
| 7 | Butin 10-30 % du liquide (±DIS/10, −PER, +5 criminelle), plafond 2 000 ; jamais la banque | implémenté, testé | 3 | `crim_voler_part_interne`, `crim_voler_montant_interne`, `crim_voler_livrer_interne` |
| 7 | Objets volables (non porté ; ni titres, ni biens, ni objets du poste) ; une unité par pile ; aucun / type absent → échec sans risque | implémenté, testé | 3 | `crim_vol_categorie_interne`, `crim_vol_objet_choisir_interne` |
| 7 | Réussite : victime prévenue, auteur selon le mode ; détection 30 −20 −10 min 5 | implémenté, testé | 3 | `crim_resoudre_interne`, `crim_affaire_notifier_interne` |
| 7 | Réussite critique 5 % : découverte au prochain réveil, sans détection | implémenté, testé | 3 | `crim_vols_differes`, `crim_vols_reveil_interne`, raccord `pa_repos_nocturne` |
| 7 | Échec remarqué 50 +3/PER > 8 −1/3 DIS > 50 (10-90) ; cachette gardée ; échec critique 2 % ; combat 10 % (2-40) | implémenté, testé (combat ouvert ; issue réelle non jouée) | 3 | `crim_voler_remarque_interne`, `crim_combat_ouvrir_interne`, raccord `crim_resoudre_suite_interne` |
| 7 | Voleur pris : 1 j d'office (Républia, par empire) ; doublé si démasqué plus tard | 1 j : implémenté, testé ; doublement : lot 6 | 3 | `crim_parametres.peine_jours_vol_republic` |
| 8 | Crochetage 3 PA, kit, 30 % +1/2 DIS > 50, +15, 5-80 ; kit cassé ; 5 usages ; réussite sans trace, serrure refermée | implémenté, testé | 4 | `crim_crocheter`, `crim_crocheter_taux_interne`, `crim_intrusions`, raccord `crim_passage_v1` |
| 8 | Effraction 2 PA, 40 % +3/FOR > 8, +25 pied-de-biche, +10, 10-95 ; serrure détruite ; propriétaire prévenu ; détection 60 (−10 masqué, caché sans effet) | implémenté, testé | 4 | `crim_forcer_porte`, `crim_forcer_taux_interne`, `crim_forcer_mode_detection_interne` |
| 8 | Achat de kit / pied-de-biche tracé | implémenté, testé | 1 | `crim_traces_achat` |
| 8 | Objets déposés : se ramassent ; affaire au nom du propriétaire, plainte possible | implémenté, testé | 4 | raccord `crim_ramasser_v1`, `crim_ramasser_constater_interne` |
| 8 | Matériel installé 2 PA sans jet ; stock 10-20 % d'une pile ; caisse 10-30 % ≤ 3 000 | implémenté, testé | 4 | `crim_cambriolage_lire`, `crim_cambrioler`, `crim_cambrioler_livrer_interne` ; `voler_materiel` redirigée |
| 8 | Lieu vide : détection par vol 30 (−20 −10, min 5), constat au prochain passage / point de caisse | implémenté, testé | 4 | `crim_resoudre_interne` (`reussite_auto`), `crim_constats`, raccords `crim_constat_passage_v1` / `crim_constat_caisse_v1` |
| 8 | Personnes présentes : règles du vol sur une personne (réussite, remarqué, combat) | implémenté, testé (combat ouvert ; issue réelle non jouée) | 4 | `crim_temoin_interne`, `crim_voler_taux_interne`, `crim_combat_ouvrir_interne`, raccord `crim_cambriolage_combat_v1` |
| 8 | Écran : boutons sur la porte fermée, menu « Emporter ce qu'il y a ici », sans calcul | implémenté, testé (VM) | 4 | `plateau-criminalite.js`, `serrurePopupFermee` |
| 9 | Empoisonnement : cachette ni exigée ni consommée ; formule ; règle commune | consommation retirée (lot 1), reste décidé | — | `crime_empoisonner` |
| 10 | Explosifs : formule, échec critique 10 % (explosion prématurée), détection 65 min 30 | décidé | — | — |
| 11 | Incendie : formule (bidon, orage, canicule), détection après réussite 70 min 20 | décidé | — | — |
| 12 | Corruption de PNJ seulement ; règle commune ; QHS directeur / gardien ; suppressions | décidé | — | — |
| 13 | Rumeur : formule, échec critique 10 %, détection 15 %, bouche-à-oreille ; tracts ; scandale ; fuite | décidé | — | — |
| 14 | Doublement démasqué ; fin des catégories lourdes ; seuil du procès 4 j ; juge ±50 % (liberté sous état d'urgence) ; état d'urgence 7 j ; correctifs de nomenclature | décidé | — | — |
| 14 | Rébellion réussie / matée, grilles, réparation | décidé | — | — |
| 15 | Carrière criminelle, cursus « Droit pénal », bonus seulement | décidé | — | — |
| 16 | QHS réservé aux détenus très dangereux ; pas de verrou de critères | décidé | 10 | — |
| 16 | Décision : Ministre de la Justice (valider, référendum, refuser) ; proposition du juge | décidé | 10 | — |
| 16 | Suppléance par le Premier ministre ; sans PM, refus automatique | décidé | 10 | — |
| 16 | Envoi direct : −5 POP par membre du gouvernement, −10 au Ministre, rumeur | décidé | 10 | — |
| 16 | Référendum gratuit ; non puis envoi = pénalité doublée | décidé | 10 | — |
| 16 | Électeurs domiciliés, 1 voix par PJ, 24 h, courrier | décidé | 10 | — |
| 16 | Bloc PNJ de 10 voix (Sécurité, Moral, POP du détenu ; 10-90 %) ; égalité = non | décidé | 10 | — |
| 16 | QHS = régime (reste de la peine) ; Sovarka : goulag, règles inchangées | décidé | 10 | — |
