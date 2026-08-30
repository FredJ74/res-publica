// =====================
// RES PUBLICA — RESSOURCES DE TRADUCTION (I18N LOT 1 + LOT 2)
// Le francais reste la langue source/canonique du projet. Cles semantiques stables (home.*,
// creation.*) -- jamais le texte francais lui-meme comme cle technique. Aucun namespace multiple
// pour l'instant (inutile a ce stade, un seul namespace 'translation', celui par defaut d'i18next).
//
// LOT 1 (perimetre : accueil, ecran #intro) : home.subtitle/tagline/createCharacter/
// findCharacter/findCharacterPlaceholder/loadCharacter -- inchanges par le Lot 2.
//
// LOT 2 (perimetre : parcours complet de creation #s1-#s9 + sous-flux "retrouver mon
// personnage") :
// - home.findCharacter* (nouvelles cles, messages dynamiques du sous-flux "retrouver mon
//   personnage" -- regroupees avec les cles Lot 1 deja existantes du meme sous-flux, jamais un
//   second namespace pour la meme fonctionnalite).
// - creation.* (nouveau namespace) : steps.* (titres/sous-titres/aides statiques de chaque
//   ecran), nav.* (boutons de navigation partages), countries.*/origins.*/schools.*/
//   archetypes.*/careers.*/stats.* (traductions des libelles AFFICHES pour chaque entree de
//   data.js, indexees par le MEME id technique que data.js -- data.js n'est jamais modifie,
//   seul un id sert de cle de recherche ici), city.*/career.*/identity.*/review.*/success.*
//   (textes des ecrans dynamiques restants).
//
// PRINCIPE ABSOLU (rappel) : les valeurs ci-dessous ne sont JAMAIS persistees. Seuls les id
// (COUNTRIES/ORIGINS/SCHOOLS/ARCHETYPES/CAREERS/STAT_DEFS de data.js, cles WORLD capitale/
// ville_a/ville_b) restent la verite technique, strictement inchangee par ce lot.
//
// Noms propres jamais traduits (restent lus directement depuis data.js, jamais dans ce
// fichier) : COUNTRIES[].n (Republia, El Estado, Sovarka, Al-Khalija), WORLD[pays][ville].name
// (Luthecia, Montrouge, Port-Sainte-Marie...).
// =====================
window.RP_I18N_RESOURCES = {
  fr: {
    translation: {
      home: {
        subtitle: "Le Grand Jeu du Pouvoir",
        tagline: "Parodie politique multijoueur · 4 empires · Zero scrupule",
        createCharacter: "Creer mon personnage",
        findCharacter: "Retrouver mon personnage",
        findCharacterPlaceholder: "Votre nom de personnage...",
        loadCharacter: "Charger ce personnage",
        // Messages dynamiques du sous-flux "retrouver mon personnage" (Lot 2) -- jamais marques
        // via data-i18n (contenu genere par JS, pas present dans le DOM au chargement), appeles
        // directement via i18next.t() depuis creation.js.
        findCharacterEnterName: "Entrez votre nom de personnage.",
        findCharacterSearching: "Recherche en cours...",
        findCharacterUnavailable: "Connexion Supabase non disponible.",
        findCharacterNotFound: "Personnage introuvable. Verifiez l'orthographe.",
        findCharacterFound: "Personnage \"{{name}}\" trouve ! Redirection...",
        findCharacterConnectionError: "Erreur de connexion. Reessayez."
      },
      creation: {
        steps: {
          country: {
            step: "Etape 1 / 7",
            title: "Choisissez votre empire",
            subtitle: "Chaque empire a ses regles, ses codes, sa facon particuliere de corrompre."
          },
          origin: {
            step: "Etape 2 / 7",
            title: "Origine sociale",
            subtitle: "Le milieu dans lequel vous etes ne determine votre capital de depart."
          },
          school: {
            step: "Etape 3 / 7",
            title: "Parcours scolaire",
            subtitle: "L'education forge les competences et ouvre ou ferme des portes.",
            info: "Certaines carrieres sont reservees aux diplomes. D'autres sont inaccessibles pour qui a trop etudie."
          },
          archetype: {
            step: "Etape 4 / 7",
            title: "Nature profonde",
            subtitle: "Qui etes-vous vraiment, independamment de votre parcours ?",
            info: "L'archetype definit votre personnalite fondamentale, pas votre metier."
          },
          career: {
            step: "Etape 5 / 7",
            title: "Carriere",
            subtitle: "Votre parcours professionnel avant d'entrer dans le grand jeu."
          },
          stats: {
            step: "Etape 6 / 7",
            title: "Caracteristiques",
            subtitle: "Distribuez vos points libres. Les bonus acquis sont deja integres.",
            pointsLabel: "Points a distribuer",
            info: "Au-dela de 12, chaque point coute 2. Plafond : 16 a la creation. Les niveaux 17-20 se debloquent en jeu.",
            warning_one: "Il vous reste {{count}} point non distribue. Vous pourrez le repartir plus tard depuis votre fiche de personnage.",
            warning_other: "Il vous reste {{count}} points non distribues. Vous pourrez les repartir plus tard depuis votre fiche de personnage."
          },
          identity: {
            step: "Etape 7 / 7",
            title: "Identite du personnage",
            subtitle: "Donnez un visage, un nom et une histoire a votre alter ego.",
            photoLabel: "Photo de profil",
            photoHint: "Telechargez une image · Parodie de personnage reel bienvenue",
            nameLabel: "Nom du personnage",
            namePlaceholder: "Ex: Arnold Governator, Jean-Marie Dupont-Moreau...",
            bioLabel: "Biographie",
            bioPlaceholder: "L'histoire de votre personnage, son passe, ses motivations...",
            mottoLabel: "Devise personnelle",
            mottoOptional: "(optionnel)",
            mottoPlaceholder: "Ex: Le pouvoir ne se prend pas, il se merite... ou pas."
          },
          review: {
            step: "Recapitulatif",
            title: "Votre fiche de personnage"
          }
        },
        nav: {
          back: "Retour",
          next: "Suivant",
          seeSheet: "Voir ma fiche",
          edit: "Modifier",
          validate: "Valider et entrer dans le jeu",
          enter: "Entrer dans le jeu"
        },
        city: {
          modalTitle: "Choisissez votre ville de domiciliation",
          capitalBadge: "(Capitale)"
        },
        common: {
          capitalLabel: "Capital",
          traitLabel: "Trait",
          bonusSuffix: "bonus",
          malusSuffix: "malus"
        },
        career: {
          info: "Carrieres disponibles selon votre niveau d'etudes ({{school}}).",
          locked: "Non disponible avec votre niveau d'etudes"
        },
        review: {
          lifePath: "Parcours de vie",
          characteristics: "Caracteristiques",
          startingResources: "Ressources de depart",
          biography: "Biographie",
          money: "Argent",
          influence: "Influence",
          popularity: "Popularite",
          discretion: "Discretion",
          tier: "Palier {{tier}}",
          maxInGame: "Max 100 en jeu",
          wealthTier1: "1 - Denuement",
          wealthTier2: "2 - Modeste",
          wealthTier3: "3 - Aise",
          wealthTier4: "4 - Riche",
          wealthTier5: "5 - Oligarque"
        },
        success: {
          title: "Bienvenue dans le Grand Jeu",
          ready: "Votre personnage est pret.",
          text: "{{name}} entre dans l'arene de {{country}}. Le Grand Jeu commence. Alliances, trahisons, corruption, kompromat - que le plus impitoyable gagne.",
          fallbackCountry: "ce monde"
        },
        countries: {
          republic: { description: "Democratie fatiguee, elites consanguines, scandale mediatique comme sport national.", tags: ["Democratie", "Satirique"] },
          narco: { description: "Democratie de facade, cartels, elections achetees. La violence est une langue politique.", tags: ["Violent", "Corruption"] },
          soviet: { description: "Parti unique en tension interne. Reformistes contre conservateurs.", tags: ["Parti unique", "Factions"] },
          khalija: { description: "Monarchie absolue, famille royale tentaculaire. La Grace Royale est la seule monnaie.", tags: ["Monarchie", "Theocratie"] }
        },
        // Villes (WORLD, data.js) : cles = pays puis cle technique de ville (capitale/ville_a/
        // ville_b), jamais le nom propre de la ville (toujours lu directement depuis data.js,
        // jamais traduit). Seule la description est traduite ici.
        cities: {
          republic: {
            capitale: { description: "Capitale de Republia. Centre du pouvoir politique, judiciaire et mediatique." },
            ville_a: { description: "Ville portuaire a l'ouest. Commerce, contrebande et politique locale." },
            ville_b: { description: "Ville industrielle au nord. Syndicats puissants, usines et tensions sociales." }
          },
          narco: {
            capitale: { description: "Capitale d'El Estado. Chaleur etouffante, corruption omnipresente, Generalissimo Gordito regne sans partage." },
            ville_a: { description: "Poste-frontiere perche dans les montagnes. Contrebande, douaniers corruptibles et sentiers connus des seuls inities." },
            ville_b: { description: "Ville de la jungle. Les laboratoires s'etendent a perte de vue." }
          },
          soviet: {
            capitale: { description: "Capitale de Sovarka. Gris acier, blocs sovietiques, surveillance permanente. Le Parti voit tout." },
            ville_a: { description: "Ville miniere glaciale aux confins de l'empire. Le froid mord, le charbon manque rarement." },
            ville_b: { description: "Le kolkhoze collectif numero 7. Production agricole pour la gloire du Parti." }
          },
          khalija: {
            capitale: { description: "Capitale d'Al-Khalija. Or, turquoise et sable. Le Palais Royal domine tout. Le protocole est une religion." },
            ville_a: { description: "Oasis caravaniere au coeur du desert. Les marchands s'y arretent depuis des siecles, les secrets aussi." },
            ville_b: { description: "Port petrolier d'Al-Khalija. Les tankers et les dhows se croisent." }
          }
        },
        origins: {
          poor: { name: "Milieu defavorise", trait: "Resilience brute, rien a perdre" },
          worker: { name: "Classe ouvriere", trait: "Sens du collectif, mains calleuses, trop honnete pour bien mentir" },
          bourgeois: { name: "Petite bourgeoisie", trait: "Vernis social, ambitions mesurees, pas encore le bon carnet d'adresses" },
          elite: { name: "Haute societe", trait: "Carnet d'adresses ancestral, mais n'a jamais connu la difficulte reelle" }
        },
        schools: {
          none: { name: "Pas d'ecole", blockLabel: "Bloque : justice, affaires, professions intellectuelles" },
          basic: { name: "Ecole basique", blockLabel: "Bloque : justice, affaires" },
          higher: { name: "Etudes superieures", blockLabel: "Bloque : professions intellectuelles (reservees aux hautes ecoles)" },
          elite: { name: "Hautes ecoles", blockLabel: "Toutes carrieres accessibles + bonus de reseau" }
        },
        archetypes: {
          politician: { name: "Ambitieux", description: "Seduction et persuasion. Le pouvoir est votre oxygene." },
          authoritarian: { name: "Ordre et discipline", description: "La hierarchie et la force. L'ordre est la seule vraie valeur." },
          oligarch: { name: "Capitaliste", description: "L'argent est la mesure de toutes choses." },
          informer: { name: "Diffuseur d'informations", description: "L'information est votre arme et votre raison d'etre." },
          legalist: { name: "Legaliste", description: "Les regles, les textes, les procedures. Vous savez comment les plier." },
          believer: { name: "Homme de foi", description: "Une conviction profonde vous anime. Elle mobilise les foules." },
          shadow: { name: "Homme de l'ombre", description: "Infiltration, manipulation, double jeu. Vous n'existez pas officiellement." },
          anticapitalist: { name: "Anti-capitaliste", description: "Vous combattez le systeme. La justice sociale est votre etendard." },
          criminal: { name: "Criminel", description: "En dehors des lois. Vos propres regles, bien plus efficaces." }
        },
        careers: {
          officer: { name: "Armee — Officier superieur / Mercenaire", comp: "Commandement, Intimidation" },
          business: { name: "Affaires — Homme d'affaires / Lobbyiste", comp: "Lobbying, Blanchiment, Negociation" },
          magistrat: { name: "Justice — Magistrat / Avocat", comp: "Droit, Procedure judiciaire, Negociation" },
          press: { name: "Medias & Communication — Grand journaliste / Influenceur", comp: "Kompromat, Propagande, Reseaux sociaux" },
          clergy: { name: "Religion — Chef de culte", comp: "Rhetorique, Mobilisation" },
          doctor: { name: "Professions intellectuelles — Medecin / Universitaire", comp: "Reseau civil, Discretion, Rhetorique" },
          worker: { name: "Monde ouvrier — Ouvrier / Syndicaliste", comp: "Force, Solidarite, Mobilisation" },
          intel: { name: "Renseignement — Agent des services", comp: "Surveillance, Infiltration" },
          criminal_c: { name: "Crime organise — Criminel organise", comp: "Milices, Blanchiment" },
          escort: { name: "Prostitution — Prostitue(e)", comp: "Seduction, Kompromat" }
        },
        stats: {
          INT: { name: "Intelligence", description: "Comprendre, analyser, anticiper : utile pour l'enquete, la finance, et dejouer les pieges les plus subtils." },
          CHA: { name: "Charisme", description: "Convaincre, seduire, apaiser : la cle de toute negociation, plaidoirie ou discours." },
          VOL: { name: "Volonte", description: "Tenir bon : resister a la pression, a l'arrestation, a la torture -- et se battre quand il n'y a plus le choix." },
          PER: { name: "Perception", description: "Reperer ce qui vous echappe : detecter un mensonge, filer une cible, ne jamais etre surpris." },
          DUP: { name: "Duplicite", description: "Mentir, dissimuler, corrompre : la specialite de tous ceux qui vivent dans l'illegalite." },
          ENT: { name: "Entregent", description: "Construire et entretenir un reseau : peu spectaculaire dans l'instant, decisif sur la duree." }
        }
      }
    }
  },
  en: {
    translation: {
      home: {
        subtitle: "The Great Game of Power",
        tagline: "A multiplayer political satire · 4 empires · No scruples",
        createCharacter: "Create My Character",
        findCharacter: "Find My Character",
        findCharacterPlaceholder: "Your character's name...",
        loadCharacter: "Load This Character",
        findCharacterEnterName: "Enter your character's name.",
        findCharacterSearching: "Searching...",
        findCharacterUnavailable: "Supabase connection unavailable.",
        findCharacterNotFound: "Character not found. Check the spelling.",
        findCharacterFound: "Character \"{{name}}\" found! Redirecting...",
        findCharacterConnectionError: "Connection error. Please try again."
      },
      creation: {
        steps: {
          country: {
            step: "Step 1 / 7",
            title: "Choose your empire",
            subtitle: "Each empire has its own rules, its own codes, its own particular way of being corrupt."
          },
          origin: {
            step: "Step 2 / 7",
            title: "Social background",
            subtitle: "The background you come from determines your starting capital."
          },
          school: {
            step: "Step 3 / 7",
            title: "Education",
            subtitle: "Education shapes your skills and opens or closes doors.",
            info: "Some careers are reserved for graduates. Others are off-limits to those who studied too much."
          },
          archetype: {
            step: "Step 4 / 7",
            title: "True Nature",
            subtitle: "Who are you really, regardless of your background?",
            info: "Your archetype defines your fundamental personality, not your job."
          },
          career: {
            step: "Step 5 / 7",
            title: "Career",
            subtitle: "Your professional path before entering the great game."
          },
          stats: {
            step: "Step 6 / 7",
            title: "Attributes",
            subtitle: "Distribute your free points. Acquired bonuses are already factored in.",
            pointsLabel: "Points to distribute",
            info: "Past 12, each point costs 2. Cap: 16 at creation. Levels 17-20 unlock in-game.",
            warning_one: "You have {{count}} point left to distribute. You can allocate it later from your character sheet.",
            warning_other: "You have {{count}} points left to distribute. You can allocate them later from your character sheet."
          },
          identity: {
            step: "Step 7 / 7",
            title: "Character Identity",
            subtitle: "Give your alter ego a face, a name and a story.",
            photoLabel: "Profile picture",
            photoHint: "Upload an image · Parodies of real people are welcome",
            nameLabel: "Character name",
            namePlaceholder: "E.g.: Arnold Governator, Jean-Marie Dupont-Moreau...",
            bioLabel: "Biography",
            bioPlaceholder: "Your character's story, their past, their motivations...",
            mottoLabel: "Personal motto",
            mottoOptional: "(optional)",
            mottoPlaceholder: "E.g.: Power isn't taken, it's earned... or not."
          },
          review: {
            step: "Summary",
            title: "Your character sheet"
          }
        },
        nav: {
          back: "Back",
          next: "Next",
          seeSheet: "See My Sheet",
          edit: "Edit",
          validate: "Confirm and enter the game",
          enter: "Enter the game"
        },
        city: {
          modalTitle: "Choose your home city",
          capitalBadge: "(Capital)"
        },
        common: {
          capitalLabel: "Capital",
          traitLabel: "Trait",
          bonusSuffix: "bonus",
          malusSuffix: "penalty"
        },
        career: {
          info: "Careers available based on your education level ({{school}}).",
          locked: "Not available with your education level"
        },
        review: {
          lifePath: "Life Path",
          characteristics: "Attributes",
          startingResources: "Starting Resources",
          biography: "Biography",
          money: "Money",
          influence: "Influence",
          popularity: "Popularity",
          discretion: "Discretion",
          tier: "Tier {{tier}}",
          maxInGame: "Max 100 in-game",
          wealthTier1: "1 - Destitute",
          wealthTier2: "2 - Modest",
          wealthTier3: "3 - Comfortable",
          wealthTier4: "4 - Wealthy",
          wealthTier5: "5 - Oligarch"
        },
        success: {
          title: "Welcome to the Great Game",
          ready: "Your character is ready.",
          text: "{{name}} steps into the arena of {{country}}. The Great Game begins. Alliances, betrayals, corruption, kompromat — let the most ruthless win.",
          fallbackCountry: "this world"
        },
        countries: {
          republic: { description: "A weary democracy, inbred elites, media scandal as a national sport.", tags: ["Democracy", "Satirical"] },
          narco: { description: "A facade of democracy, cartels, bought elections. Violence is a political language.", tags: ["Violent", "Corruption"] },
          soviet: { description: "A single party under internal strain. Reformists against hardliners.", tags: ["Single Party", "Factions"] },
          khalija: { description: "An absolute monarchy, a sprawling royal family. Royal Favor is the only currency that matters.", tags: ["Monarchy", "Theocracy"] }
        },
        cities: {
          republic: {
            capitale: { description: "Capital of Republia. The center of political, judicial and media power." },
            ville_a: { description: "A port city to the west. Trade, smuggling and local politics." },
            ville_b: { description: "An industrial city to the north. Powerful unions, factories and social tension." }
          },
          narco: {
            capitale: { description: "Capital of El Estado. Stifling heat, pervasive corruption, Generalissimo Gordito rules unchallenged." },
            ville_a: { description: "A border post perched in the mountains. Smuggling, corruptible customs officers and trails known only to insiders." },
            ville_b: { description: "A jungle city. The labs stretch as far as the eye can see." }
          },
          soviet: {
            capitale: { description: "Capital of Sovarka. Steel-grey, Soviet blocks, constant surveillance. The Party sees everything." },
            ville_a: { description: "A frozen mining town at the empire's edge. The cold bites, coal rarely runs short." },
            ville_b: { description: "Collective kolkhoz number 7. Agricultural production for the glory of the Party." }
          },
          khalija: {
            capitale: { description: "Capital of Al-Khalija. Gold, turquoise and sand. The Royal Palace dominates everything. Protocol is a religion." },
            ville_a: { description: "A caravan oasis in the heart of the desert. Merchants have stopped here for centuries — so have secrets." },
            ville_b: { description: "Al-Khalija's oil port. Tankers and dhows cross paths." }
          }
        },
        origins: {
          poor: { name: "Underprivileged Background", trait: "Raw resilience, nothing left to lose" },
          worker: { name: "Working Class", trait: "A sense of solidarity, calloused hands, too honest to lie well" },
          bourgeois: { name: "Lower Middle Class", trait: "A social veneer, modest ambitions, not quite the right address book yet" },
          elite: { name: "High Society", trait: "An ancestral address book, but never known real hardship" }
        },
        schools: {
          none: { name: "No Schooling", blockLabel: "Blocked: law, business, intellectual professions" },
          basic: { name: "Basic Schooling", blockLabel: "Blocked: law, business" },
          higher: { name: "Higher Education", blockLabel: "Blocked: intellectual professions (reserved for elite schools)" },
          elite: { name: "Elite Schools", blockLabel: "All careers accessible + networking bonus" }
        },
        archetypes: {
          politician: { name: "Ambitious", description: "Charm and persuasion. Power is your oxygen." },
          authoritarian: { name: "Law and Order", description: "Hierarchy and force. Order is the only real value." },
          oligarch: { name: "Capitalist", description: "Money is the measure of all things." },
          informer: { name: "Information Broker", description: "Information is your weapon and your reason for being." },
          legalist: { name: "Legalist", description: "Rules, texts, procedures. You know exactly how to bend them." },
          believer: { name: "Person of Faith", description: "A deep conviction drives you. It moves crowds." },
          shadow: { name: "Shadow Operator", description: "Infiltration, manipulation, double-dealing. Officially, you don't exist." },
          anticapitalist: { name: "Anti-Capitalist", description: "You fight the system. Social justice is your banner." },
          criminal: { name: "Criminal", description: "Outside the law. Your own rules, far more effective." }
        },
        careers: {
          officer: { name: "Army — Senior Officer / Mercenary", comp: "Command, Intimidation" },
          business: { name: "Business — Businessman / Lobbyist", comp: "Lobbying, Money Laundering, Negotiation" },
          magistrat: { name: "Justice — Magistrate / Lawyer", comp: "Law, Judicial Procedure, Negotiation" },
          press: { name: "Media & Communication — Star Journalist / Influencer", comp: "Kompromat, Propaganda, Social Media" },
          clergy: { name: "Religion — Cult Leader", comp: "Rhetoric, Mobilization" },
          doctor: { name: "Intellectual Professions — Doctor / Academic", comp: "Civilian Network, Discretion, Rhetoric" },
          worker: { name: "Working World — Worker / Union Organizer", comp: "Strength, Solidarity, Mobilization" },
          intel: { name: "Intelligence — Agency Operative", comp: "Surveillance, Infiltration" },
          criminal_c: { name: "Organized Crime — Organized Criminal", comp: "Militias, Money Laundering" },
          escort: { name: "Sex Work — Escort", comp: "Seduction, Kompromat" }
        },
        stats: {
          INT: { name: "Intelligence", description: "Understand, analyze, anticipate: useful for investigation, finance, and outsmarting the subtlest traps." },
          CHA: { name: "Charisma", description: "Convince, charm, soothe: the key to any negotiation, plea, or speech." },
          VOL: { name: "Willpower", description: "Hold your ground: resist pressure, arrest, torture — and fight when there's no other choice left." },
          PER: { name: "Perception", description: "Notice what escapes others: spot a lie, tail a target, never be caught off guard." },
          DUP: { name: "Duplicity", description: "Lie, conceal, corrupt: the specialty of everyone living outside the law." },
          ENT: { name: "Connections", description: "Build and maintain a network: unspectacular in the moment, decisive over time." }
        }
      }
    }
  }
};
