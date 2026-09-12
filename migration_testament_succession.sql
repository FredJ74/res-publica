-- Migration requise avant que le chantier Testament & Succession (architecture v4, 21 aout
-- 2026) ne fonctionne effectivement en production. Deux tables, ni l'une ni l'autre n'existe
-- aujourd'hui (verifie : aucune reference "CREATE TABLE testaments/successions" dans les
-- migrations deja executees de ce projet) -- a executer manuellement par Fred dans l'editeur
-- SQL Supabase, comme toutes les migrations precedentes de ce projet (la cle anon utilisee par
-- le client n'a pas les privileges DDL necessaires).
--
-- Revision du 21 aout 2026 (verification d'idempotence demandee par Fred, avant toute execution)
-- par rapport a la premiere version de cette migration : ajout de l'index unique partiel sur
-- successions(defunt) et des colonnes part_etat_reglee/part_notaire_reglee -- voir les deux notes
-- dediees plus bas. Rien d'autre n'a change.
--
-- Tant que cette migration n'est pas appliquee :
--   - "Rédiger / modifier son testament" echoue proprement (sbSaveTestament retourne null,
--     message "La persistance du testament n'est pas encore active" / "Le testament n'a pas pu
--     être enregistré", aucun etat local corrompu) ;
--   - "Détruire définitivement" (destruction volontaire de personnage) echoue de la meme facon
--     fail-closed : ouvrirSuccession() renvoie {ok:false, raison:'primitive_succession_indisponible'
--     ou 'echec_creation_succession'}, confirmerDestructionPersonnage() n'appelle JAMAIS
--     sbDeletePersonnage() dans ce cas -- le personnage n'est PAS supprime ;
--   - "Réclamer un héritage" reste accessible mais ne trouve jamais aucun dossier (liste vide) ;
--   - le cron (resoudreSuccessionsExpirees, api/cron-minuit.js) ne trouve jamais aucune ligne et
--     ne fait rien (aucune erreur bloquante, boucle vide sur une table inexistante -> sbGet
--     renvoie null, return anticipe).
--
-- =====================
-- TESTAMENTS
-- =====================
-- Une ligne = un testament redige a un instant donne. L'historique complet est conserve (jamais
-- de DELETE/UPDATE destructif du contenu) : un nouveau testament passe l'ancien en statut
-- 'remplace' (remplace_id le referencant) ; une revocation explicite sans nouveau testament passe
-- statut 'revoque' ; l'ouverture reelle d'une succession consomme le testament actif en le
-- passant 'execute'. contenu (jsonb) = { biens: [{id, beneficiaire, remplacant}], argent:
-- [{beneficiaire, pourcentage, remplacant}] } -- objet transmis tel quel par le client (jsonb
-- natif, jamais JSON.stringify avant insert, meme convention que entreprises.data).
CREATE TABLE IF NOT EXISTS testaments (
  id text PRIMARY KEY,
  testateur text NOT NULL,
  country text NOT NULL,
  contenu jsonb NOT NULL DEFAULT '{}'::jsonb,
  statut text NOT NULL DEFAULT 'actif' CHECK (statut IN ('actif', 'remplace', 'revoque', 'execute')),
  remplace_id text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_testaments_testateur ON testaments (testateur);

-- =====================
-- SUCCESSIONS
-- =====================
-- Une ligne = un dossier successoral complet, de son ouverture ('en_attente' : convocations en
-- cours, actifs geles) a son reglement final ('resolue' : transferts effectues, degel, archive
-- notariale publique). Pas de deuxieme table pour l'archive : une succession 'resolue' EST
-- l'archive (voir plateau-enigme-portrait.js, chargerSuccessionsReelles, qui filtre
-- explicitement statut='resolue' pour ne jamais exposer un dossier encore en cours aux Archives
-- Notariales publiques).
--
-- conjoint (text, simple snapshot du nom au moment de l'ouverture) = droit d'information GLOBAL
-- du conjoint survivant : consultation de l'integralite du testament/des dispositions a tout
-- moment, sans echeance, sans decision associee. A NE JAMAIS CONFONDRE avec une eventuelle etape
-- dispositions[].chaine[].role = 'legal_conjoint', qui est la decision successorale REELLE
-- (accepter/renoncer) sur UNE disposition precise, ajoutee dynamiquement seulement quand cette
-- disposition atteint effectivement le conjoint (principal et remplacant epuises). Les deux
-- mecanismes sont independants : le conjoint peut consulter des l'ouverture meme si aucune
-- disposition ne l'a encore atteint en tant qu'heritier potentiel.
--
-- Fiscalite (argent_brut_total/droits_total/part_etat/part_notaire/argent_net_total) : calculee
-- UNE SEULE FOIS a l'ouverture sur la masse totale (jamais recalculee par disposition, pour
-- eviter toute divergence d'arrondi), figee definitivement dans ces colonnes. droits_total =
-- floor(argent_brut_total * 0.33) ; part_etat = floor(droits_total * 0.90) ; part_notaire =
-- droits_total - part_etat (garantit une somme exacte, aucun FR perdu a l'arrondi) ;
-- argent_net_total = argent_brut_total - droits_total, ensuite reparti entre les dispositions de
-- type 'argent'. Creditee inconditionnellement au reglement final, meme si toutes les
-- dispositions finissent en devolution a l'Etat (le notaire et l'Etat sont remuneres pour le
-- traitement du dossier, independamment de qui herite au final).
--
-- dispositions (jsonb, tableau) = SEULE source de verite pour les convocations et leur avancee.
-- Chaque element : { id, type: 'terrain'|'entreprise'|'argent', libelle (terrain/entreprise) ou
-- part_nette (argent), remplacant_prevu (nom ou null, conserve pour la cascade si le principal
-- renonce APRES l'ouverture), chaine: [{role: 'principal'|'remplacant'|'legal_conjoint',
-- beneficiaire, convoque_le, expires_at, reponse: null|'accepte'|'renonce', repondu_le}], etat,
-- resultat: null tant qu'en attente, sinon {beneficiaire, statut} une fois la disposition
-- tranchee, regle: false|true -- MARQUEUR DE REGLEMENT (distinct de resultat) : passe a true par
-- le cron (reglerSuccession, api/cron-minuit.js) UNIQUEMENT une fois que le transfert/credit reel
-- de CETTE disposition a reellement reussi. C'est ce marqueur, pas resultat ni statut='resolue',
-- qui protege contre un double transfert/credit si le cron est interrompu en cours de reglement
-- et repasse le lendemain (voir le long commentaire de reglerSuccession pour le detail). Chaque
-- etape de chaine porte sa PROPRE echeance reelle (10 jours) -- jamais un expires_at global
-- unique sur la succession.
CREATE TABLE IF NOT EXISTS successions (
  id text PRIMARY KEY,
  defunt text NOT NULL,
  country text NOT NULL,
  testament_id text,
  statut text NOT NULL DEFAULT 'en_attente' CHECK (statut IN ('en_attente', 'resolue')),
  conjoint text,
  argent_brut_total integer NOT NULL DEFAULT 0,
  droits_total integer NOT NULL DEFAULT 0,
  part_etat integer NOT NULL DEFAULT 0,
  part_notaire integer NOT NULL DEFAULT 0,
  argent_net_total integer NOT NULL DEFAULT 0,
  -- Marqueurs de reglement de la fiscalite globale, INDEPENDANTS l'un de l'autre : le credit
  -- Etat et le credit notaire sont deux ecritures Supabase separees (tables budgets_nationaux et
  -- caisses_batiments) ; si l'une reussit et que l'autre echoue, seul le marqueur de celle qui a
  -- reellement reussi passe a true, et le cron ne retente au jour suivant que celle qui manque
  -- encore -- jamais un double credit sur celle deja effectuee (voir reglerSuccession).
  part_etat_reglee boolean NOT NULL DEFAULT false,
  part_notaire_reglee boolean NOT NULL DEFAULT false,
  dispositions jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_successions_country_statut ON successions (country, statut);
CREATE INDEX IF NOT EXISTS idx_successions_defunt ON successions (defunt);
CREATE INDEX IF NOT EXISTS idx_successions_conjoint ON successions (conjoint);

-- Defense en profondeur (verification d'idempotence du 21 aout 2026) : ouvrirSuccession()
-- (plateau-personnage.js) verifie deja cote client qu'aucune succession 'en_attente' n'existe
-- pour ce defunt avant d'en creer une nouvelle (reprise d'une ouverture partielle au lieu d'une
-- recreation). Cet index unique PARTIEL est le filet de securite cote base : il rend impossible,
-- au niveau du SGBD lui-meme, l'existence simultanee de deux lignes 'en_attente' pour le meme
-- defunt -- y compris en cas de course (ex. double-clic tres rapide sur "Détruire définitivement",
-- deux onglets ouverts sur le meme personnage). Partiel (WHERE statut='en_attente') et non total
-- sur (defunt) seul : un meme nom peut tout a fait avoir PLUSIEURS successions 'resolue' au fil
-- du temps si le systeme de personnages permet un jour la reutilisation d'un nom apres suppression
-- -- seule l'unicite du dossier ACTIF est requise.
CREATE UNIQUE INDEX IF NOT EXISTS idx_successions_defunt_en_attente
  ON successions (defunt) WHERE statut = 'en_attente';

-- NOTE (aucune ALTER TABLE requise, pour memoire) :
--   - terrains_etat.data / entreprises.data portent deja le champ libre "succession_gel" (id de
--     la succession gelante, ou absent/null) directement DANS le blob JSON existant -- terrains_etat
--     via JSON.stringify (colonne text/jsonb generique), entreprises via jsonb natif. Aucune
--     colonne dediee necessaire sur l'une ou l'autre table.
--   - prets.statut recoit desormais aussi la valeur libre 'succession' (dette eteinte par
--     ouverture de succession) en plus des valeurs deja en usage ('en_cours', 'remboursé',
--     'saisi') -- colonne text sans contrainte CHECK identifiee dans ce projet, aucune migration
--     necessaire pour l'autoriser.
