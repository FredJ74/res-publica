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
// =====================
// CONFIGURATION CENTRALE DES LANGUES (LOT 2.5, passage a N langues)
// =====================
// Source de verite UNIQUE de la liste des langues supportees -- i18n-init.js derive
// RP_I18N_LANGUES_SUPPORTEES de Object.keys() de cet objet, plutot que de dupliquer la liste.
// Ajouter une langue = ajouter une entree ici + son arbre dans RP_I18N_RESOURCES ci-dessous,
// rien d'autre a modifier ailleurs (detection navigateur, selecteur, mise en evidence du bouton
// actif sont tous generiques, voir i18n-init.js).
// nativeName : autonyme, toujours ecrit dans SA PROPRE langue, jamais traduit ni retraduit selon
// la langue actuellement affichee (Français reste "Français" meme quand l'anglais est actif).
// zh-TW (LOT 2.6) : code COMPOSE (langue-region), premier hors alphabet latin -- voir
// i18n/i18n-init.js, resoudreCodeLangueSupporte(), pour la resolution regionale associee
// (zh-Hant-TW accepte, zh-CN/zh-Hans-CN jamais confondus avec zh-TW). Autonyme complet avec
// mention explicite du territoire (evite toute ambiguite future avec Hong Kong si zh-HK est
// ajoute plus tard).
window.RP_I18N_LANGUAGES = {
  fr: { nativeName: 'Français' },
  en: { nativeName: 'English' },
  es: { nativeName: 'Español' },
  'zh-TW': { nativeName: '繁體中文（台灣）' }
};

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
  },
  es: {
    translation: {
      home: {
        subtitle: "El Gran Juego del Poder",
        tagline: "Sátira política multijugador · 4 imperios · Cero escrúpulos",
        createCharacter: "Crear mi personaje",
        findCharacter: "Recuperar mi personaje",
        findCharacterPlaceholder: "El nombre de tu personaje...",
        loadCharacter: "Cargar este personaje",
        findCharacterEnterName: "Introduce el nombre de tu personaje.",
        findCharacterSearching: "Buscando...",
        findCharacterUnavailable: "Conexión con Supabase no disponible.",
        findCharacterNotFound: "Personaje no encontrado. Comprueba la ortografía.",
        findCharacterFound: "¡Personaje \"{{name}}\" encontrado! Redirigiendo...",
        findCharacterConnectionError: "Error de conexión. Inténtalo de nuevo."
      },
      creation: {
        steps: {
          country: {
            step: "Paso 1 / 7",
            title: "Elige tu imperio",
            subtitle: "Cada imperio tiene sus propias reglas, sus códigos, su manera particular de ser corrupto."
          },
          origin: {
            step: "Paso 2 / 7",
            title: "Origen social",
            subtitle: "El entorno del que vienes determina tu capital inicial."
          },
          school: {
            step: "Paso 3 / 7",
            title: "Formación académica",
            subtitle: "La educación forja las competencias y abre o cierra puertas.",
            info: "Algunas carreras están reservadas a los titulados. Otras son inaccesibles para quien ha estudiado demasiado."
          },
          archetype: {
            step: "Paso 4 / 7",
            title: "Naturaleza profunda",
            subtitle: "¿Quién eres realmente, más allá de tu trayectoria?",
            info: "El arquetipo define tu personalidad fundamental, no tu profesión."
          },
          career: {
            step: "Paso 5 / 7",
            title: "Carrera",
            subtitle: "Tu trayectoria profesional antes de entrar en el gran juego."
          },
          stats: {
            step: "Paso 6 / 7",
            title: "Atributos",
            subtitle: "Reparte tus puntos libres. Las bonificaciones ya obtenidas están incluidas.",
            pointsLabel: "Puntos por repartir",
            info: "A partir de 12, cada punto cuesta 2. Límite: 16 en la creación. Los niveles 17-20 se desbloquean durante la partida.",
            warning_one: "Te queda {{count}} punto sin repartir. Podrás asignarlo más adelante desde tu ficha de personaje.",
            warning_other: "Te quedan {{count}} puntos sin repartir. Podrás asignarlos más adelante desde tu ficha de personaje."
          },
          identity: {
            step: "Paso 7 / 7",
            title: "Identidad del personaje",
            subtitle: "Dale un rostro, un nombre y una historia a tu álter ego.",
            photoLabel: "Foto de perfil",
            photoHint: "Sube una imagen · Las parodias de personajes reales son bienvenidas",
            nameLabel: "Nombre del personaje",
            namePlaceholder: "Ej.: Arnold Governator, Juan Domínguez-Pérez...",
            bioLabel: "Biografía",
            bioPlaceholder: "La historia de tu personaje, su pasado, sus motivaciones...",
            mottoLabel: "Lema personal",
            mottoOptional: "(opcional)",
            mottoPlaceholder: "Ej.: El poder no se toma, se merece... o no."
          },
          review: {
            step: "Resumen",
            title: "Tu ficha de personaje"
          }
        },
        nav: {
          back: "Atrás",
          next: "Siguiente",
          seeSheet: "Ver mi ficha",
          edit: "Modificar",
          validate: "Confirmar y entrar en el juego",
          enter: "Entrar en el juego"
        },
        city: {
          modalTitle: "Elige tu ciudad de residencia",
          capitalBadge: "(Capital)"
        },
        common: {
          capitalLabel: "Capital",
          traitLabel: "Rasgo",
          bonusSuffix: "bono",
          malusSuffix: "penalización"
        },
        career: {
          info: "Carreras disponibles según tu nivel de estudios ({{school}}).",
          locked: "No disponible con tu nivel de estudios"
        },
        review: {
          lifePath: "Trayectoria vital",
          characteristics: "Atributos",
          startingResources: "Recursos iniciales",
          biography: "Biografía",
          money: "Dinero",
          influence: "Influencia",
          popularity: "Popularidad",
          discretion: "Discreción",
          tier: "Nivel {{tier}}",
          maxInGame: "Máx. 100 en la partida",
          wealthTier1: "1 - Indigencia",
          wealthTier2: "2 - Modesto",
          wealthTier3: "3 - Acomodado",
          wealthTier4: "4 - Rico",
          wealthTier5: "5 - Oligarca"
        },
        success: {
          title: "Bienvenido al Gran Juego",
          ready: "Tu personaje está listo.",
          text: "{{name}} entra en la arena de {{country}}. Comienza el Gran Juego. Alianzas, traiciones, corrupción, kompromat: que gane el más despiadado.",
          fallbackCountry: "este mundo"
        },
        countries: {
          republic: { description: "Una democracia agotada, élites endogámicas, el escándalo mediático como deporte nacional.", tags: ["Democracia", "Satírico"] },
          narco: { description: "Una democracia de fachada, cárteles, elecciones compradas. La violencia es un idioma político.", tags: ["Violento", "Corrupción"] },
          soviet: { description: "Partido único en tensión interna. Reformistas contra conservadores.", tags: ["Partido único", "Facciones"] },
          khalija: { description: "Monarquía absoluta, una familia real omnipresente. El Favor Real es la única moneda que cuenta.", tags: ["Monarquía", "Teocracia"] }
        },
        cities: {
          republic: {
            capitale: { description: "Capital de Republia. Centro del poder político, judicial y mediático." },
            ville_a: { description: "Ciudad portuaria al oeste. Comercio, contrabando y política local." },
            ville_b: { description: "Ciudad industrial al norte. Sindicatos poderosos, fábricas y tensión social." }
          },
          narco: {
            capitale: { description: "Capital de El Estado. Calor sofocante, corrupción omnipresente; el Generalísimo Gordito gobierna sin oposición." },
            ville_a: { description: "Puesto fronterizo encaramado en las montañas. Contrabando, aduaneros corruptibles y senderos que solo conocen los iniciados." },
            ville_b: { description: "Ciudad de la jungla. Los laboratorios se extienden hasta donde alcanza la vista." }
          },
          soviet: {
            capitale: { description: "Capital de Sovarka. Gris acero, bloques soviéticos, vigilancia permanente. El Partido lo ve todo." },
            ville_a: { description: "Ciudad minera helada en los confines del imperio. El frío muerde, el carbón rara vez escasea." },
            ville_b: { description: "El koljós colectivo número 7. Producción agrícola para la gloria del Partido." }
          },
          khalija: {
            capitale: { description: "Capital de Al-Khalija. Oro, turquesa y arena. El Palacio Real lo domina todo. El protocolo es una religión." },
            ville_a: { description: "Oasis caravanero en pleno desierto. Los mercaderes llevan siglos deteniéndose aquí; los secretos también." },
            ville_b: { description: "Puerto petrolero de Al-Khalija. Petroleros y dhows se cruzan en sus aguas." }
          }
        },
        origins: {
          poor: { name: "Entorno desfavorecido", trait: "Resiliencia a prueba de todo, nada que perder" },
          worker: { name: "Clase obrera", trait: "Sentido colectivo, manos callosas, demasiado honesto para mentir bien" },
          bourgeois: { name: "Pequeña burguesía", trait: "Barniz social, ambiciones moderadas, todavía sin la agenda de contactos adecuada" },
          elite: { name: "Alta sociedad", trait: "Agenda de contactos ancestral, pero nunca ha conocido la verdadera dificultad" }
        },
        schools: {
          none: { name: "Sin estudios", blockLabel: "Bloqueado: justicia, negocios, profesiones intelectuales" },
          basic: { name: "Escuela básica", blockLabel: "Bloqueado: justicia, negocios" },
          higher: { name: "Estudios superiores", blockLabel: "Bloqueado: profesiones intelectuales (reservadas a las grandes escuelas)" },
          elite: { name: "Grandes escuelas", blockLabel: "Todas las carreras accesibles + bonificación de contactos" }
        },
        archetypes: {
          politician: { name: "Ambicioso", description: "Seducción y persuasión. El poder es tu oxígeno." },
          authoritarian: { name: "Orden y disciplina", description: "La jerarquía y la fuerza. El orden es el único valor verdadero." },
          oligarch: { name: "Capitalista", description: "El dinero es la medida de todas las cosas." },
          informer: { name: "Difusor de información", description: "La información es tu arma y tu razón de ser." },
          legalist: { name: "Legalista", description: "Las normas, los textos, los procedimientos. Sabes exactamente cómo doblegarlos." },
          believer: { name: "Hombre de fe", description: "Una convicción profunda te anima. Moviliza a las masas." },
          shadow: { name: "Hombre de las sombras", description: "Infiltración, manipulación, doble juego. Oficialmente, no existes." },
          anticapitalist: { name: "Anticapitalista", description: "Combates el sistema. La justicia social es tu bandera." },
          criminal: { name: "Criminal", description: "Al margen de la ley. Tus propias reglas, mucho más eficaces." }
        },
        careers: {
          officer: { name: "Ejército — Oficial superior / Mercenario", comp: "Mando, Intimidación" },
          business: { name: "Negocios — Empresario / Lobista", comp: "Lobby, Blanqueo, Negociación" },
          magistrat: { name: "Justicia — Magistrado / Abogado", comp: "Derecho, Procedimiento judicial, Negociación" },
          press: { name: "Medios y Comunicación — Gran periodista / Influencer", comp: "Kompromat, Propaganda, Redes sociales" },
          clergy: { name: "Religión — Líder de culto", comp: "Retórica, Movilización" },
          doctor: { name: "Profesiones intelectuales — Médico / Académico", comp: "Red civil, Discreción, Retórica" },
          worker: { name: "Mundo obrero — Obrero / Sindicalista", comp: "Fuerza, Solidaridad, Movilización" },
          intel: { name: "Inteligencia — Agente de los servicios secretos", comp: "Vigilancia, Infiltración" },
          criminal_c: { name: "Crimen organizado — Criminal organizado", comp: "Milicias, Blanqueo" },
          escort: { name: "Trabajo sexual — Trabajador(a) sexual", comp: "Seducción, Kompromat" }
        },
        stats: {
          INT: { name: "Inteligencia", description: "Comprender, analizar, anticipar: útil para la investigación, las finanzas y desbaratar las trampas más sutiles." },
          CHA: { name: "Carisma", description: "Convencer, seducir, apaciguar: la clave de toda negociación, alegato o discurso." },
          VOL: { name: "Voluntad", description: "Aguantar: resistir la presión, la detención, la tortura, y luchar cuando ya no queda otra opción." },
          PER: { name: "Percepción", description: "Detectar lo que se te escapa: descubrir una mentira, seguir a un objetivo, no dejarte sorprender nunca." },
          DUP: { name: "Duplicidad", description: "Mentir, disimular, corromper: la especialidad de todos los que viven al margen de la ley." },
          ENT: { name: "Contactos", description: "Construir y mantener una red de contactos: poco vistoso en el momento, decisivo a largo plazo." }
        }
      }
    }
  },
  // =====================
  // zh-TW (LOT 2.6) : localisation en chinois traditionnel destinee a Taiwan -- pas une
  // conversion mecanique d'un chinois simplifie, vocabulaire et formulations pensees pour Taiwan
  // (ex. "軟體"/"網路" plutot que les equivalents du chinois continental). Noms propres de
  // l'univers (Republia, El Estado, Sovarka, Al-Khalija, Luthecia...) volontairement conserves en
  // toutes lettres latines dans le texte chinois -- identiques, reversibles, jamais transcrits en
  // caracteres, memes IDs techniques inchanges que pour fr/en/es.
  // =====================
  'zh-TW': {
    translation: {
      home: {
        subtitle: "權力的大遊戲",
        tagline: "多人政治諷刺遊戲・4 個帝國・毫無底線",
        createCharacter: "創建我的角色",
        findCharacter: "找回我的角色",
        findCharacterPlaceholder: "輸入你的角色名稱...",
        loadCharacter: "載入此角色",
        findCharacterEnterName: "請輸入你的角色名稱。",
        findCharacterSearching: "搜尋中...",
        findCharacterUnavailable: "目前無法連線至 Supabase。",
        findCharacterNotFound: "找不到該角色，請確認拼寫是否正確。",
        findCharacterFound: "已找到角色「{{name}}」！正在轉向...",
        findCharacterConnectionError: "連線發生錯誤，請再試一次。"
      },
      creation: {
        steps: {
          country: {
            step: "第 1 / 7 步",
            title: "選擇你的帝國",
            subtitle: "每個帝國都有自己的規則、潛規則，以及獨特的腐敗方式。"
          },
          origin: {
            step: "第 2 / 7 步",
            title: "社會出身",
            subtitle: "你出身的環境決定了你的起始資金。"
          },
          school: {
            step: "第 3 / 7 步",
            title: "求學經歷",
            subtitle: "教育造就能力，也決定了機會之門的開闔。",
            info: "某些職業只保留給高學歷者，另一些職業則會拒絕書讀得太多的人。"
          },
          archetype: {
            step: "第 4 / 7 步",
            title: "內在本質",
            subtitle: "拋開你的背景，你真正的樣子是什麼？",
            info: "原型決定你的根本性格，而非你的職業。"
          },
          career: {
            step: "第 5 / 7 步",
            title: "職業",
            subtitle: "在踏入這場大遊戲之前，你的職業生涯。"
          },
          stats: {
            step: "第 6 / 7 步",
            title: "能力值",
            subtitle: "分配你的自由點數，已獲得的加成已經計入其中。",
            pointsLabel: "可分配點數",
            info: "超過 12 點後，每點需消耗 2 點數。創角上限為 16 點，17-20 級將在遊戲中解鎖。",
            // 中文的基數詞在 CLDR 中只有 "other" 一種分類 -- 不需要（也不應該）為了模仿法文/英文
            // 的單複數區分而人為製造「個(s)」之類的寫法，1 與 5 使用完全相同的句型。
            warning_other: "你還剩下 {{count}} 點能力點數尚未分配，稍後可以在角色卡中重新分配。"
          },
          identity: {
            step: "第 7 / 7 步",
            title: "角色身份",
            subtitle: "為你的另一個自己賦予一張臉、一個名字與一段故事。",
            photoLabel: "大頭照",
            photoHint: "上傳一張圖片・歡迎惡搞真實人物",
            nameLabel: "角色名稱",
            namePlaceholder: "例如：Arnold Governator、陳大文...",
            bioLabel: "個人簡介",
            bioPlaceholder: "你角色的故事、過去與動機...",
            mottoLabel: "座右銘",
            mottoOptional: "（選填）",
            mottoPlaceholder: "例如：權力不是搶來的，是掙來的……或者根本不需要理由。"
          },
          review: {
            step: "總覽",
            title: "你的角色卡"
          }
        },
        nav: {
          back: "上一步",
          next: "下一步",
          seeSheet: "查看我的角色卡",
          edit: "修改",
          validate: "確認並進入遊戲",
          enter: "進入遊戲"
        },
        city: {
          modalTitle: "選擇你的居住城市",
          capitalBadge: "（首都）"
        },
        common: {
          capitalLabel: "資金",
          traitLabel: "特質",
          bonusSuffix: "加成",
          malusSuffix: "減益"
        },
        career: {
          info: "可選職業取決於你的學歷（{{school}}）。",
          locked: "以你目前的學歷無法選擇"
        },
        review: {
          lifePath: "人生歷程",
          characteristics: "能力值",
          startingResources: "起始資源",
          biography: "個人簡介",
          money: "金錢",
          influence: "影響力",
          popularity: "聲望",
          discretion: "隱密度",
          tier: "等級 {{tier}}",
          maxInGame: "遊戲內上限 100",
          wealthTier1: "1 - 赤貧",
          wealthTier2: "2 - 小康",
          wealthTier3: "3 - 富裕",
          wealthTier4: "4 - 富豪",
          wealthTier5: "5 - 寡頭"
        },
        success: {
          title: "歡迎來到這場大遊戲",
          ready: "你的角色已經準備就緒。",
          text: "{{name}} 踏入了 {{country}} 的競技場。這場大遊戲正式展開：結盟、背叛、貪腐、把柄操控——讓最無情的人勝出。",
          fallbackCountry: "這個世界"
        },
        countries: {
          republic: { description: "Republia 是一個疲憊不堪的民主國家，權貴近親繁殖，把媒體醜聞當成全民運動。", tags: ["民主", "諷刺"] },
          narco: { description: "El Estado 徒具形式的民主，販毒集團橫行，選舉可以用錢買到。暴力就是一種政治語言。", tags: ["暴力", "貪腐"] },
          soviet: { description: "Sovarka 一黨專政，內部暗潮洶湧。改革派對抗保守派。", tags: ["一黨專政", "派系"] },
          khalija: { description: "Al-Khalija 是絕對君主制，王室勢力無孔不入。王恩，是唯一通行的貨幣。", tags: ["君主制", "神權政治"] }
        },
        cities: {
          republic: {
            capitale: { description: "Republia 的首都，政治、司法與媒體權力的中心。" },
            ville_a: { description: "西部的港口城市，貿易、走私與地方政治交織。" },
            ville_b: { description: "北部的工業城市，工會勢力龐大，工廠林立，社會關係緊張。" }
          },
          narco: {
            capitale: { description: "El Estado 的首都。悶熱難耐，貪腐無所不在，強人 Generalissimo Gordito 大權獨攬，無人能及。" },
            ville_a: { description: "座落山區的邊境哨站。走私猖獗，海關人員可以收買，山間小路只有內行人才知道。" },
            ville_b: { description: "叢林中的城市，實驗室一望無際，遍布四方。" }
          },
          soviet: {
            capitale: { description: "Sovarka 的首都。鋼灰色調，蘇式建築林立，監控無所不在。黨，看著一切。" },
            ville_a: { description: "帝國邊陲的酷寒礦業城市。寒風刺骨，煤炭卻鮮少匱乏。" },
            ville_b: { description: "第七號集體農莊，為了黨的榮耀而生產的農業重鎮。" }
          },
          khalija: {
            capitale: { description: "Al-Khalija 的首都。黃金、綠松石與黃沙交織。王宮凌駕一切，禮儀規範宛如信仰。" },
            ville_a: { description: "沙漠深處的商隊綠洲。商人們在此停駐已有數個世紀，秘密也是。" },
            ville_b: { description: "Al-Khalija 的石油港口，油輪與傳統帆船交錯往來。" }
          }
        },
        origins: {
          poor: { name: "弱勢家庭出身", trait: "堅韌到底，一無所有，也就無所畏懼" },
          worker: { name: "勞工階級", trait: "重視團結，滿手厚繭，老實到不擅說謊" },
          bourgeois: { name: "小資產階級", trait: "有點社會地位，野心恰到好處，只是人脈還不夠硬" },
          elite: { name: "上流社會", trait: "祖傳的人脈網絡，卻從未真正嘗過艱難的滋味" }
        },
        schools: {
          none: { name: "未受教育", blockLabel: "無法從事：司法、商業、知識專業" },
          basic: { name: "基礎教育", blockLabel: "無法從事：司法、商業" },
          higher: { name: "高等教育", blockLabel: "無法從事：知識專業（僅限頂尖名校）" },
          elite: { name: "頂尖名校", blockLabel: "所有職業皆可選擇，並附加人脈加成" }
        },
        archetypes: {
          politician: { name: "野心家", description: "魅力與說服力兼具，權力就是你的氧氣。" },
          authoritarian: { name: "秩序與紀律", description: "階級與武力至上，秩序是唯一真正的價值。" },
          oligarch: { name: "資本家", description: "金錢是衡量一切的標準。" },
          informer: { name: "情報散播者", description: "情報是你的武器，也是你存在的理由。" },
          legalist: { name: "法制派", description: "規則、條文、程序——你最清楚該怎麼鑽漏洞。" },
          believer: { name: "信仰之人", description: "堅定的信念驅動著你，也能號召群眾。" },
          shadow: { name: "幕後黑手", description: "滲透、操控、腳踏兩條船——你在檯面上根本不存在。" },
          anticapitalist: { name: "反資本主義者", description: "你與體制對抗，社會正義是你高舉的旗幟。" },
          criminal: { name: "罪犯", description: "逍遙法外，你自訂的規則反而更有效率。" }
        },
        careers: {
          officer: { name: "軍旅 — 高階軍官／傭兵", comp: "統御、威嚇" },
          business: { name: "商界 — 商人／說客", comp: "遊說、洗錢、談判" },
          magistrat: { name: "司法 — 法官／律師", comp: "法律、司法程序、談判" },
          press: { name: "媒體與傳播 — 資深記者／網路名人", comp: "把柄操作、宣傳、社群媒體" },
          clergy: { name: "宗教 — 教派領袖", comp: "口才、動員" },
          doctor: { name: "知識專業 — 醫師／學者", comp: "民間人脈、隱密行事、口才" },
          worker: { name: "勞工階層 — 工人／工會幹部", comp: "體力、團結、動員" },
          intel: { name: "情報 — 情報人員", comp: "監視、滲透" },
          criminal_c: { name: "組織犯罪 — 幫派份子", comp: "私人武裝、洗錢" },
          escort: { name: "性產業 — 陪侍人員", comp: "魅惑、把柄操作" }
        },
        stats: {
          INT: { name: "智力", description: "理解、分析、預判：有助於調查、理財，並識破最精密的陷阱。" },
          CHA: { name: "魅力", description: "說服、吸引、安撫：任何談判、辯護或演說的關鍵。" },
          VOL: { name: "意志力", description: "咬牙撐住：抵抗壓力、逮捕與拷問，並在別無選擇時挺身而戰。" },
          PER: { name: "洞察力", description: "察覺常人忽略之處：識破謊言、跟蹤目標，永遠不被出其不意。" },
          DUP: { name: "詭詐", description: "說謊、隱瞞、收買人心：所有遊走法律邊緣者的看家本領。" },
          ENT: { name: "人脈手腕", description: "建立並維繫人脈網絡：當下不起眼，長遠卻是決定性的關鍵。" }
        }
      }
    }
  }
};
