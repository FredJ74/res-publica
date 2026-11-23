# Mission « Novomirsk, PNJ, interface et suites des rapports » — décisions de Fred (23/11/2026)

Ce document consigne **à la source** chaque décision de la mission du 23/11/2026. Les documents de game design
thématiques renvoient ici (NOVOMIRSK, HOSPITALISATION, SANTE, CRIMINALITE, INFORMATEURS, INTERFACE-ACCUEIL).
Chaque point porte un banc qui l'empêche de revenir (liste dans RELAIS.md).

## Règles générales de la mission

- **R4 — Suppressions** : rien n'est supprimé (onglet, bouton, ordre de pièce, PNJ) sans avoir cherché dans tout le dépôt
  ce qui l'appelle (fonctions, fenêtres, « Mes objectifs », chemins d'accueil, aide, i18n, bancs, énigmes). Chaque appel
  est redirigé, et un banc échoue si un élément renvoie vers quelque chose qui n'existe plus.
- **R6 — Le PNJ suit l'image** : quand un portrait est attribué, le sexe, l'âge et l'apparence du PNJ s'alignent sur
  l'image (nom, accords, textes, fiche DeepSeek).
- **R7** : deux PNJ de villes différentes peuvent porter le même nom de famille.
- **R8 — Interface « comme pour un enfant »** : chaque fenêtre se comprend au premier coup d'œil, deux fenêtres ne se
  chevauchent jamais, aucun texte n'est plus petit que le texte courant.
- **R9** : victime d'un crime et conséquences de la nuit → **journal des événements**, jamais de courrier.
- **R11** : le goulag reste verrouillé (`sovarka_goulag_ouvert() = false`).

## Bloc 1 — pannes et suites des rapports

1. **Une seule fiche d'objet.** L'onglet Inventaire de « Mon personnage » (`ouvrirDetailObjet`) et l'Inventaire du
   panneau de gauche (`ouvrirDetailObjetInventaire`) ouvrent la **même** fiche, qui réunit toutes les actions : écrire,
   envoyer et lire une carte postale, donner, montrer, lire le guide des baies, serrures, se soigner (médicament,
   trousse), empoisonner, jumelles, explosifs, ration de combat, etc.
2. **Onglet Organisations : toutes les organisations du joueur**, chacune avec une étiquette de pays (Arnie en Sovarka
   voit le S.E.V. de Républia). Les actions sur place restent contrôlées par le serveur. Message « aucune organisation »
   accentué ; en Sovarka il ne renvoie plus à « Gérer mon local » (il faut d'abord demander un local à la mairie).
3. **Fiche Identité : le pays du PJ** (celui de son personnage), pas le pays où il se trouve. Accents partout
   (« Ministre de la Défense », « Républia »).
4. **À vérifier** : en navigation privée (Tom Tom), bandeau « RES PUBLICA » au lieu de « HUMAN GAMBIT » et jauges Santé
   et Moral absentes du panneau.
5. **« Taxi vers le QHS »** (hall principal de la gare de Novomirsk) mène au goulag : masqué dans toute la Sovarka tant
   que le goulag est verrouillé.
6. **Tous les paiements du jeu se font en liquide** (règle du 22/11). Exception : les **prélèvements automatiques**
   (`taxe_fonciere_prelever`, `cotisation_renouveler`) gardent l'ordre « liquide, puis banque ».
7. Le **reversement de l'excédent des entrepôts** est branché sur la tâche de minuit.
8. **Usines pharmaceutiques** (Républia et Novomirsk) : dotation initiale de plantes, sur le modèle de la dotation des
   entrepôts de province du 07/11.
9. **Les PNJ des usines ne sont pas payés.** Seuls les PNJ des chantiers de construction consomment l'argent de la caisse.
10. **« Inspecter la pièce » : ouvrir la fenêtre coûte 0 PA**, à l'écran comme sur le serveur. Seules les options
    choisies à l'intérieur coûtent des PA, chacune avec son tarif sur son bouton.
11. **« Voler » reste proposé en face du matériel d'autrui, même chez soi** : le matériel d'un colocataire ne lui
    appartient pas, c'est un vol avec sa trace.
12. **La rébellion (acte d'un PJ) coûte 1 PA ; la répression (ordre d'un PJ) coûte 1 PA**, écran et serveur.
13. La ligne `desinstaller_materiel` est retirée de `ordres_couts`.
14. La migration de Codex `20261122210046_correction_chemins_images_non_appliquee.sql` est appliquée, puis l'audit des
    images est relancé.
15. **Portrait de Vera Pravdina** : `images/Sovarka/Novomirsk/Novo_vera_pravdina_portrait.webp`, à la place de la
    pastille « V » dans l'interview d'accueil.

## Bloc 2 — interface

16. **Panneau de gauche, de haut en bas** : portrait, nom, poste, six caractéristiques ; ligne PA / Santé / Moral ;
    deuxième ligne Influence / Popularité / Discrétion (mêmes petites jauges) ; Argent ; Mes objectifs ; Mes employés ;
    Inventaire. Bouton « Mes statistiques » **supprimé**.
17. **Clic sur « Argent »** : fenêtre du patrimoine (liquide, banque par banque, placements avec montant et échéance,
    prêts avec capital restant dû, échéance et banque prêteuse).
18. **Clic sur « Inventaire »** (panneau de gauche) : fenêtre reprenant la présentation de l'onglet Inventaire de la
    fiche (icônes, Déposer, Détruire, clic → fiche unique du point 1). L'onglet « Inventaire » de « Mon personnage »
    est **supprimé**.
19. **« Mon personnage »** : onglet « Statistiques » **supprimé**. Le profil (Calculateur…) reste dans « Identité »,
    sans les six caractéristiques.
20. Texte jamais inférieur au texte courant (fiche Identité, onglet Organisations en particulier).
21. **Journal des événements** : bouton « Rapports de combat » **supprimé** (les combats restent dans le fil) ; croix de
    fermeture plus grande, contrastée, vrai bouton ; plus d'entrées ni de sorties de bâtiments.
22. **Boutons ronds du journal et du chat** : en bas à droite, l'un au-dessus de l'autre (essai).
23. **Flèches des rues**, dans toutes les rues : « avancer » (↑) en bas de l'image, légèrement à gauche ; flèche
    latérale (›) tout en bas à droite de l'image.

## Bloc 3 — PNJ

24. **Acheter une information** se fait en cliquant sur le PNJ informateur, pour tous les informateurs du jeu. L'ordre
    de pièce « Acheter une information » disparaît.
25. **L'habitué du Bar Sever (Krasnov)** : PNJ social visible (homme à la casquette, table de droite de
    `Krasnov_bar_sever_salle.webp`). Il ouvre la discussion et offre un verre une fois par jour et par PJ (le verre
    compte dans la Santé) ; ensuite il accueille le PJ en se souvenant de lui. Il conclut : « Ce verre m'a donné soif !
    Et je ne dis pas ça pour que tu m'en offres un en retour, mais je ne te dirais pas non si tu le fais. » Bouton
    « Lui offrir un verre » (7 à 20 PSK, barème existant) → information. L'ordre « Offrir un verre à l'habitué » est
    **supprimé**.
26. **Fiches de dialogue DeepSeek** :
    - **Grigori Zaitsev**, patron du Bar Sever : la cinquantaine, bourru mais pas méchant, essuie toujours le même
      verre, phrases courtes ; vodka, papirossy, journaux du Parti, match à la radio ; renvoie à l'habitué (« Lui, il
      sait. Offrez-lui un verre. ») ; fier de Krasnov et de l'ours, méfiant envers Novomirsk, récite la ligne du Parti
      avec un sérieux comique.
    - **Musée de Krasnov** : l'hôtesse **Zoïa Biletova** (à la caisse) et le guide **Arkadi Pamiatnikov** (âgé, mince,
      dégarni, costume usé, pull à carreaux sur col roulé), recadrés dans l'image de l'accueil.
    - **EHPAD de Krasnov** : un résident, PNJ social, recadré dans l'image de la salle : **Matriona Starikova** (ou
      **Matveï Starikov** si la personne la plus visible est un homme). Plus de 80 ans, ancienne du kolkhoze, esprit
      vif ; raconte la ville d'avant (fondation, légende de l'ours, grandes coupes, radar, héros du Travail), mélange
      les époques, se plaint de la soupe, glisse des indices sur les mystères de Krasnov, se souvient des visiteurs.
    - **Habitants des petites maisons, tous PNJ sociaux** (attachement), fiches tirées de leur histoire existante ;
      « trinquer » inchangé. Krasnov : Antonina Merkoulova, Matveï Rybakov, Praskovia Pakhomova, Kouzma Lapchine
      (batiouchka, un peu sourd, parle fort), Ignat Lykov (fonctionnaire à la retraite), Stepan Kouznetsov. Starovka :
      Dolgor Tsybikova.
    - **Infirmière de l'hôpital de Krasnov** : **Nadejda Oukolova** remplace « Infirmiere » générique.
    - Tous les PNJ de Sovarka sans fiche de dialogue sont relevés et raccordés.
27. **Ignat Lykov est fonctionnaire à la retraite, jamais trappeur.** **Kouzma Lapchine est le batiouchka** (depuis le
    15/11), plus « ancien sonneur de cloches ».
28. **Matveï Rybakov** est le référent chasse et bûcheronnage de Krasnov, frère aîné de **Prokhor Rybakov** (douanes de
    Novomirsk), dont il parle avec ironie : « mon frère, il fouille des valises toute la journée ».

## Bloc 4 — lieux de Krasnov

29. **Musée** : le directeur est **supprimé** ; le guide Arkadi Pamiatnikov reprend l'énigme (le joueur lui donne
    l'ingrédient effacé dans la conversation, le guide juge). L'ordre « Soumettre la solution de l'énigme au
    directeur » est **supprimé** ; le carnet dit « Soumettez votre solution au guide du musée. » « Acheter le guide des
    baies sauvages » reste un ordre de pièce. Les cinq salles reçoivent une description et l'ordre « Écouter le
    guide », sur le modèle de Novomirsk (Ilia Krioukov), présentées par Arkadi.
30. **Hôpital** : salle d'attente = visiteurs (centre antipoison, soin standard, fournir des ressources médicales,
    inspecter, se cacher) ; chambre = hospitalisés (dormir, repas, transfert en clinique privée, sortir). Transfert à
    0 PA, tarif du pays affiché et prélevé dans la chambre (Sovarka : 400 PSK). « Salle bondée. Patience requise. »
    **supprimé**.
31. **Locaux libres de Sovarka** : encadré « Ce local est libre. En Sovarka, les commerces appartiennent à l'État. Pour
    exploiter ce local, adressez une demande à la mairie de [ville]. Le maire examine les demandes deux fois par mois.
    Si la vôtre est acceptée, vous recevrez un courrier et signerez l'attribution chez le notaire. » + bouton « Demander
    ce local à la mairie — 1 PA ». « Gérer mon local » et « Équipements et serrure » masqués aux non-exploitants ;
    « Ce commerce » supprimé. Local attribué : « Ce local est exploité par [nom] » ; pour l'exploitant, « Gérer mon
    local » mis en avant.
32. **Centre d'affaires de Krasnov** : 4 bureaux (2 côté maison bleue, 2 côté hôpital) dans `sovarka_locaux`, plafond
    40 PSK/jour ; demande à la mairie au lieu de « Louer ce bureau (500 PSK/jour) » ; les 3 locaux fantômes du gabarit
    sont retirés.
33. **« Chanter l'hymne au Tracteur »**, commun à toutes les églises de la Sainte-Moisson-Commune : karaoké de 5 à
    6 secondes (tracteur rouge qui cahote en bas de l'écran avec une fumée noire en rythme, étoile dorée qui saute de mot
    en mot, cierges, bouton « Passer »), puis exclamation du religieux du lieu (Krasnov, Kouzma : « PLUS FORT, MON
    ENFANT ! LE TRACTEUR N'ENTEND PAS ! » ; Novomirsk, Camarade Pontife Tractorenko : « Le Tracteur vous a entendus, mes
    enfants. Il ronronne de satisfaction. ») et résultat de l'ordre. Paroles : « Ô Tracteur, roue de lumière, / Tu
    laboures nos prières. / Gloire au Plan et à ton moteur, / Que la moisson remplisse nos cœurs ! » ; dans les 9 langues,
    une **adaptation rimée** au ton de cantique pompeux ; en arabe, l'étoile va de droite à gauche.
34. **Groupe électrogène** : la station-service de Krasnov ouvre la boutique « Équipements contre les intempéries ».

## Bloc 5 — contenus

35. **Cartes postales** : Krasnov, la carte en vente (`carte_krasnov_place_ours`) utilise l'image « Краснов, столица
    медведя » et sa description d'automne (les cartes possédées gardent leur description). **Starovka** : le triptyque
    « Привет из Старовки! » est la carte postale de Starovka, vendue au magasin du kolkhoze (`magasin-kolkhoze-starovka`).
36. **Inventaire** : noms propres au lieu des clés brutes (laitages, cereales, medicaments, produits_exotiques…) ; les
    18 icônes de `icones-inventaire.zip` ; l'icône d'une carte postale est sa propre illustration.

## Bloc 6 — Novomirsk

37. **Gare** : « Camarade Horaire » devient **Vassili Sukhoï**, chef de gare, au hall principal (graphie « Sukhoï »
    **voulue**, clin d'œil à l'avion : ne pas « corriger » en Soukhoï). « Agente Nadejda » devient **Lioudmila
    Proverkina**, agente de contrôle, déplacée au hall des douanes. L'inspecteur **Prokhor Rybakov** reste aux douanes
    (douanier à la loupe et au bocal de cornichons), frère cadet de Matveï Rybakov, parti réussir dans l'administration ;
    il demande des nouvelles de son frère aux PJ venus de Krasnov. Images : hall des douanes = « Contrôle douanier sous
    la neige » ; zone d'embarquement = « Aéroport soviétique sous la neige ».
38. **Direction du Renseignement** : accueil, Sergent Viktor Muetov et Elena Diamentevia (nom gardé pour l'instant) ;
    salle des écoutes, nouvelle PNJ **Tamara Naouchnikova**, opératrice ; salle d'interrogatoire, **Colonel Oleg
    Doprossov** (officier en noir, politesse irréprochable, vouvoie, « Parlez, s'il vous plaît », n'élève jamais la
    voix, goût de la procédure) et **Fiodor Koulakov** (colosse au tablier, silencieux devant le Colonel, glisse aux
    détenus des conseils : « Le Colonel est de mauvaise humeur ce matin, faites attention, après c'est moi qui vais en
    pâtir. »). Comiques mais pas ridicules. Description de la salle réécrite d'après l'image (aucun miroir sans tain).
39. **Église (Kolkhoze spirituel, Grange Sainte)** : portraits du Camarade Pontife Tractorenko et de Frère Kolkhoze ;
    animation de l'hymne (point 33).

## Bloc 7 — portraits des PNJ

40. Banc transversal : liste de tous les PNJ sans portrait.
41. **Novomirsk, 34 portraits à recadrer** dans les images existantes. Arbitrages : EHPAD, les trois hommes visibles pour
    Matveï Tcherkassov, Nikolaï Zakharov et Evgueni Sudakov ; Palais des Ambassades, l'hôtesse en uniforme sombre (à
    gauche) et l'agent de gauche ; dortoir de la caserne, le soldat assis à droite pour Dimitri Loguinov ; salon de
    coiffure, la coiffeuse brune pour Ludmila Egorova.
42. **Le PNJ suit l'image** : « Tenancier de Buvette » (stade Dynamo) devient une tenancière ; le secrétaire municipal
    Arseni Krylov devient une femme ; Kirill Poliakov (archives de la mairie) devient une femme. Prénoms féminins
    proposés par Claude, **non appliqués** : en attendant, libellé de fonction.
43. **Six planches de portraits** (grille 3 × 3) : attribuées d'après la liste réelle des PNJ de Novomirsk encore sans
    portrait, pas d'après les intitulés supposés. Cases sans PNJ → `images/Sovarka/Novomirsk/reserve-portraits/`, non
    raccordées (dont 1-1 et 1-2).
44. Noms génériques : de vrais noms sovarkiens sont **proposés**, non appliqués (pas de noms français suivis de
    « -ov »/« -ova »).
45. Doublon « Le Maire » / « Le Maire de Novomirsk » : celui qui n'est pas utilisé est supprimé avec redirection.
46. Relevé seulement des images à remplacer (Cercle des Camarades, rédaction de La Voix de Sovarka, amphithéâtre).
47. Krasnov et Starovka : liste des PNJ sans portrait, recadrable ou absent.
