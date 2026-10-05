-- Migration requise avant que la memoire des renseignements connus (PJ/PNJ) ne soit
-- persistee. Phase 1 du chantier "systeme de renseignement" (22 aout 2026) : cree
-- uniquement la table de stockage generique. Aucun producteur ni consommateur cote code
-- n'est branche dans ce lot (audit de conception valide separement, aucune ligne de code
-- applicatif ecrite avant cette migration -- meme discipline que migration_tournees_
-- boissons.sql).
--
-- Contexte : aucune colonne existante ne convient, et personnages.data est explicitement
-- exclu -- doctrine deja documentee dans migration_etat_civil_ville.sql/migration_
-- logements_sociaux_montrouge.sql : "personnages" est relue et resauvegardee en integralite
-- (sbSavePersonnage) a CHAQUE action de CHAQUE joueur, y ajouter un champ de memoire
-- l'exposerait au meme risque d'ecrasement concurrentiel que toutes les autres donnees
-- inter-joueurs de ce projet, deja pour cela sorties dans des tables dediees. Contrainte
-- supplementaire propre a ce chantier : les PNJ (ex. escorts de l'agence Roxanne Velours)
-- n'ont AUCUNE ligne dans "personnages" -- seule une table independante, indexee par un
-- simple nom texte, peut representer indifferemment un detenteur PJ ou PNJ, exactement comme
-- actions_tracables/souvenirs_accueil le font deja pour leurs colonnes "auteur"/"pj_nom".
--
-- Table plate, sur le modele exact de souvenirs_accueil/actions_tracables : id text primary
-- key construit cote application (meme convention que tout le reste du projet), aucune
-- contrainte d'unicite additionnelle. "titulaire" est le detenteur du souvenir (PJ ou PNJ,
-- simple nom texte, SANS foreign key -- coherent avec le reste du projet, ou aucune table de
-- personnages/PNJ n'est referencee par cle etrangere depuis les tables de traces/tampons).
--
-- Provenance (regle de design validee) : un renseignement transmis reste une DECLARATION de
-- sa source, jamais une verite objective automatique. "source" porte donc le nom de qui a
-- transmis ce renseignement AU TITULAIRE (peut etre le titulaire lui-meme si acquisition
-- directe -- ex. Arnie qui achete son propre revolver). "fait_objectif_ref" est une
-- reference LEGERE et OPTIONNELLE (texte libre, ex. "actions_tracables:123") vers la trace
-- objective reelle quand elle existe -- jamais interpretee automatiquement comme une preuve
-- de verite par le code, jamais revelee au titulaire ni a l'IA au-dela de ce que le contenu
-- du renseignement dit deja. Une declaration fabriquee (desinformation volontaire, chantier
-- futur) est simplement une ligne dont fait_objectif_ref reste NULL -- aucun champ
-- "vrai/faux" dedie n'est necessaire.
--
-- Duree de memoire validee : ~90 jours REELS. state.day avance de 1 par jour reel
-- (increment a minuit, voir plateau-core.js/api/cron-minuit.js) -- jour_expiration = jour_
-- derniere_reactivation + 90 est donc la traduction directe de cette regle dans l'unite deja
-- utilisee par jour_expiration sur actions_tracables/souvenirs_accueil (entier, jamais un
-- type "date" SQL). Un souvenir reactive (reutilise/retransmis/reconfirme) avance jour_
-- derniere_reactivation et recalcule jour_expiration en consequence, cote application --
-- aucune colonne generee/triggee necessaire pour cela.
--
-- "categorie" reste une colonne texte SANS contrainte CHECK, volontairement -- en l'absence
-- de DDL connue pour actions_tracables (table anterieure aux migrations versionnees de ce
-- projet), le comportement observe cote code (de nombreuses valeurs de type_action ajoutees
-- au fil du temps -- vol, cambriolage_caisse, vol_materiel_chantier, nuit_escort, etc. --
-- sans migration associee) indique une colonne libre. "categorie" doit pouvoir accueillir de
-- nombreux futurs producteurs (achat_arme, escort_frequentation, recrutement_pnj,
-- achat_terrain, achat_commerce, gros_achat, acte_illegal, autre, et d'autres non encore
-- prevus) sans exiger une migration a chaque ajout -- une valeur par defaut neutre ('autre')
-- couvre un producteur qui oublierait de la renseigner.
--
-- "mode_acquisition" recoit au contraire un CHECK -- meme principe que "statut" sur
-- logements_demandes/journal_editions/successions (colonne texte + CHECK, jamais un enum
-- Postgres dedie) : c'est un petit ensemble ferme, structurellement au coeur du modele de
-- memoire lui-meme (regle de design validee, section 3 de l'audit), pas une taxonomie
-- ouverte destinee a grossir comme "categorie". "interrogatoire" est distinct de
-- "confidence" (deja tranche) : une confidence est spontanee (Faire l'amour), un
-- interrogatoire est obtenu sous l'autorite d'un enquete habilite (commissaire/juge en V1) --
-- deux provenances narrativement et mecaniquement differentes, meme si toutes deux
-- "arrachees" plutot que librement donnees. L'echange volontaire "secret contre secret"
-- n'a PAS de mode dedie : c'est une transmission directe dans les deux sens, deja couverte
-- par "transmission" -- la reciprocite est une propriete de l'interaction (deux lignes
-- inserees), pas de l'acquisition elle-meme.
--
-- Index : titulaire (lecture "quels renseignements ce PJ/PNJ detient-il encore") et jour_
-- expiration (filtrage des souvenirs perimes, meme motif que jour_expiration deja filtre par
-- souvenirs_accueil/actions_tracables) sont les deux seuls acces reellement prevus par la
-- conception validee -- un unique index compose (titulaire, jour_expiration) les couvre
-- ensemble (equite d'abord, plage ensuite -- meme ordre que idx_successions_country_statut).
-- "categorie" et "cible" ne recoivent AUCUN index dans ce lot : aucun producteur ni
-- consommateur n'est encore branche (Phase 1 create-and-read uniquement), et ajouter un
-- index sans requete reelle pour le justifier irait a l'encontre du principe deja applique
-- par migration_tournees_boissons.sql ("aucun index secondaire ajoute" faute d'usage
-- demontre, meme sur des colonnes filtrees par egalite). Un index sur "cible" pourra etre
-- ajoute plus tard, sans migration destructive, des que le premier consommateur qui filtre
-- reellement par cible sera ecrit.
--
-- RLS / policies : DECISION REVUE (22 aout 2026, apres audit de securite dedie) -- a la
-- difference des 6 migrations precedentes de ce projet (aucune RLS sur une table
-- relationnelle ordinaire), renseignements_connus active RLS et NE DEFINIT AUCUNE POLICY.
-- RLS active + zero policy = acces refuse par defaut a tout role soumis a RLS (dont anon) --
-- comportement natif Postgres/Supabase, aucune policy DENY explicite necessaire. Seul
-- service_role (qui contourne RLS par construction, jamais expose au client) pourra lire/
-- ecrire cette table, via un futur endpoint Vercel non cree dans ce lot -- meme patron deja
-- en production dans api/upload-org-avatar.js (SUPABASE_SERVICE_ROLE_KEY, variable
-- d'environnement serveur uniquement).
--
-- Raison de cette exception a la convention du projet : cette table memorise des secrets de
-- gameplay (confidences, provenance de renseignements), contrairement aux autres tables deja
-- ouvertes a anon (mails, jugements, actions_tracables) dont le contenu n'est pas cense
-- rester cache du joueur qui les lit legitimement depuis le client. Limite assumee et
-- documentee (audit dedie) : sans authentification reelle par personnage nulle part dans ce
-- projet, ce verrou empeche l'acces direct trivial (SELECT * via la cle anon publique
-- copiee du bundle JS), mais ne constitue PAS une garantie contre l'usurpation d'identite
-- aupres du futur endpoint service_role, qui devra continuer a faire confiance a un nom de
-- personnage declare par l'appelant -- comme le fait deja aujourd'hui la seule verification
-- similaire existante (orga.chef !== characterName, api/upload-org-avatar.js). Refonte
-- generale de l'authentification explicitement HORS PERIMETRE de ce lot -- decision prise en
-- connaissance de cette limite, pas par ignorance.
--
-- La cle anon (utilisee par le client via l'API REST) n'a pas les privileges DDL necessaires
-- pour executer ceci elle-meme -- comme pour toutes les migrations precedentes de ce projet,
-- a executer manuellement par Fred dans l'editeur SQL Supabase. Sans cette migration :
-- aucune fonctionnalite existante n'est affectee -- aucun code applicatif de ce chantier
-- n'est encore ecrit (Phase 1 SQL uniquement).

CREATE TABLE IF NOT EXISTS renseignements_connus (
  id text PRIMARY KEY,
  titulaire text NOT NULL,
  contenu text NOT NULL,
  cible text,
  categorie text NOT NULL DEFAULT 'autre',
  source text NOT NULL,
  mode_acquisition text NOT NULL
    CHECK (mode_acquisition IN (
      'action_personnelle', 'observation', 'document_consulte', 'confidence', 'transmission',
      'interrogatoire'
    )),
  fait_objectif_ref text,
  jour_acquisition integer NOT NULL,
  jour_derniere_reactivation integer NOT NULL,
  jour_expiration integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_renseignements_titulaire_expiration
  ON renseignements_connus (titulaire, jour_expiration);

-- RLS active, aucune policy definie : refuse tout acces (SELECT/INSERT/UPDATE/DELETE) au
-- role anon et a tout autre role soumis a RLS. Seul service_role (contourne RLS par nature)
-- pourra acceder a cette table, via un futur endpoint Vercel non cree dans ce lot.
ALTER TABLE renseignements_connus ENABLE ROW LEVEL SECURITY;
