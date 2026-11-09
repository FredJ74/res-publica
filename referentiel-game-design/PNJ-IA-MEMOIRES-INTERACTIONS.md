# PNJ, mémoire et prise de contact — fiche technique et game design

**Lecture croisée du 9 novembre 2026** : `plateau-social-pnj.js`, `api/chat.js`, `api/_pnj-profils.js` sur main `a8bd5e26`, et corps des trois RPC `pnj_social_*` **directement lus en production Supabase**, sans consulter les relations personnelles d'aucun joueur. Aucune conversation DeepSeek réelle n'a été lancée.

## La distinction fondamentale : le PNJ ne remplace pas le PJ
Les PNJ assurent la continuité des services et peuvent créer une entrée affective dans le monde ; le contrat de design reste l'interaction humaine. `api/chat.js` construit le prompt côté serveur depuis une table fermée de profils, vérifie le joueur authentifié, limite l'historique de messages transmis à six éléments et délègue la génération à DeepSeek. Le navigateur n'envoie pas son propre prompt système, et le contexte de relation est demandé sous le jeton de son personnage.

### Ce que mémorisent les deux PNJ sociaux actuels
| Dimension | Stockage / comportement vérifié dans le SQL | Effet dans le prompt |
|---|---|---|
| Rencontres | Compteur `rencontres`, incrémenté lors de `pnj_social_entrer` pour le joueur authentifié | Le PNJ sait combien de fois il a croisé ce joueur |
| Conversations | Compteur incrémenté par `pnj_social_noter(..., 'conversation')` | Le PNJ sait qu'il lui a déjà parlé |
| Familiarité | Compteur au maximum 5 ; incrément après conversation | Dès familiarité ≥ 2, instruction d'adapter le registre, sous réserve du caractère propre du PNJ |
| Confiance | Champ renvoyé par `pnj_social_contexte`, mais **aucun changement de confiance n'est présent dans les trois fonctions lues** | Non affirmé comme mécanique d'évolution active |
| Nom / genre | `pnj_social_entrer` enregistre les faits `nom` et `genre` s'ils existent dans `personnages_donnees` | Le bloc de relation utilise explicitement le **nom**, pas un résumé de dialogue |
| Jalons | `jalons` stocké en JSON, marqué **avant** l'affichage pour éviter un double déclenchement après refresh | Déclenchement d'une réplique contextuelle côté client |
| Contenu / résumé des conversations passées | **Pas écrit par ces trois RPC** ; `pnj_social_entrer` commente expressément que V1 ne mémorise pas les contenus, ni résumé ni extraction | L'endpoint reçoit un `historique` de six messages maximum pour l'échange courant, **pas la preuve d'une mémoire sémantique persistante** |

**Interprétation :** il existe une **mémoire relationnelle persistante avérée au niveau SQL** et un contexte transmis à l'IA ; une mémoire persistante du **contenu** des anciennes conversations n'a pas été trouvée dans ce socle précis. D'autres types de mémoire sont possibles pour d'autres profils et doivent être vérifiés séparément. Dire simplement « les PNJ n'ont pas de mémoire » serait faux ; dire qu'ils mémorisent tout ce que le joueur leur dit le serait aussi.

### Deux événements d'entrée effectivement configurés
- **Jean-Lou Demer**, bar des pêcheurs à Port-Sainte-Marie : `abordage_deuxieme_visite`, seuil 2 rencontres, aucune conversation préalable (valeur `max_conversations=0`). Il interpelle le PJ via une modale de dialogue réutilisée.
- **Marine Leroux**, restaurant Capitaine Sauvage : `accueil_premiere_visite`, seuil 1 rencontre. Le texte s'adapte à la civilité uniquement si l'information existe ; aucun genre deviné.

Le code `plateau-social-pnj.js` déclare précisément deux associations lieu/PNJ ; la table des règles SQL en contient deux. **Cela ne veut pas dire qu'il n'existe que deux PNJ intelligents**, mais seulement deux jalons de ce **moteur social spontané** dans le périmètre vérifié. La référence à sept autres PNJ possibles dans un commentaire décrit un potentiel, non un casting actif.

## Autres formes de contextualisation identifiées dans api/chat.js
La lecture du serveur distingue plusieurs canaux, à ne pas amalgamer à une mémoire sociale universelle :
- contexte public du joueur (identité et poste pour reconnaître l'interlocuteur) ;
- mémoire pédagogique des référents (continuité des explications, distincte de la familiarité) ;
- mémoire nationale des mandats d'une interlocutrice institutionnelle ;
- observations de l'Assemblée pour une employée spécifique ;
- étape personnelle de la quête d'accueil ;
- fonction municipale réelle et position courante, résolues sous authentification.

Chaque canal possède sa fonction RPC ou sa porte de lecture, et son intérêt narratif. **Il n'est pas prouvé que chaque PNJ a accès à chacun de ces canaux** ; le code les restreint par profil.

## Chaîne de déclenchement à certifier en jeu
`declencherEntreeZone` → `pnjSocialEntreeZone` (filtre ville, bâtiment, pièce) → `sbPnjSocialEntrer(pnjId)` → RPC `pnj_social_entrer` (identité, compteur, jalon) → contrôle que le PJ est encore dans la même pièce → modale de conversation ordinaire → `api/chat.js` (relation sous jeton, prompt serveur, DeepSeek).

**Lacunes probatoires :** nous n'avons pas observé l'entrée réelle d'un PJ, ni vérifié la présence de l'agent à l'écran, le rendu mobile, la réponse fournisseur, la continuité sur deux jours, les échecs réseau ni le compteur `conversation` après fermeture du dialogue.

## Effet possible sur expérience joueur et masse critique (hypothèses)
Un PNJ qui reconnaît un joueur à son retour peut créer de la familiarité même avant l'arrivée d'une communauté dense. Ce système peut servir de **pont vers une rencontre humaine**, mais sa valeur ne peut être inférée des seules RPC. Il faudrait observer si le joueur se souvient du PNJ, retourne volontairement au lieu, et découvre ensuite un autre PJ, une organisation, un échange ou un projet ; ce sont des hypothèses de rétention, pas des résultats.

## Questions de recette, sans arbitrage ni changement technique dans cet audit
1. Deuxième entrée de Jean-Lou sans avoir parlé : une seule interpellation ; actualisation immédiate ne la rejoue pas.
2. Dialoguer deux fois : registre change sans révéler les chiffres de familiarité, et aucune mémoire fictive de sujets non stockés ne doit être attribuée.
3. Changer de personnage authentifié : aucune relation d'un autre PJ ne doit être visible.
4. Prévenir la concurrence entre entrée de pièce et clic manuel, l'absence de réseau, le déplacement pendant l'attente.
5. Examiner séparément l'historique de la conversation courante, la mémoire des référents, celle des institutions et la continuité véritable en jours.

**Statuts : D (conception commentée), C/M (code et fonctions/config en production vérifiés), T (bancs disponibles, non rejoués ici), P (SHA de production vérifié), J (non testé sur PJ).** Aucune mécanique n'a été changée.
