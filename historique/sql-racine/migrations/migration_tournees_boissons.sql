-- Migration requise avant l'implementation de la "tournee" (offrir un verre a plusieurs cibles
-- simultanement, PJ et/ou PNJ), qui remplace le mecanisme mono-cible boire_verre actuel.
--
-- Contexte : le flux existant (invitations_diner tel qu'utilise aujourd'hui par
-- envoyerInvitationSociale/repondreInvitationSociale, plateau-pnj.js) ne cible qu'UNE seule
-- personne a la fois et ne porte aucun etat partage entre plusieurs invitations nees d'un meme
-- geste de l'offreur. Une tournee a plusieurs invites doit au contraire : survivre a un
-- rafraichissement/reconnexion de l'offreur ; ne jamais laisser une invitation orpheline si
-- l'offreur quitte la piece ; ne jamais rester bloquee indefiniment par un invite qui ne repond
-- pas ; disposer d'une expiration et d'une reprise apres crash sans double-debit ni double-credit.
-- Aucune de ces garanties n'est atteignable avec un etat uniquement local (state._tourneeEnCours).
--
-- Architecture validee (etudiee et confirmee sur plusieurs tours d'audit, aucune ligne de code
-- applicatif ecrite avant cette migration) :
--
-- 1) tournees : une ligne par tournee, portant l'etat PARTAGE entre tous les invites (boisson,
--    prix de reference, montant deja debite ou non, etat de la resolution). "statut" suit le
--    meme principe que logements_demandes/journal_editions/terrains_etat (colonne texte + CHECK,
--    jamais un enum Postgres dedie). Machine a etats a 5 valeurs :
--      en_attente   -> tournee ouverte, les invites peuvent encore repondre
--      en_resolution -> claim transitoire pose par le client qui tente de resoudre (voir
--                        resolution_started_at ci-dessous) ; un ancien "en_resolution" reclamable
--                        passe ce delai signale un crash cote client, pas un etat normal durable
--      resolue      -> resolution terminee (financierement executee ou no-op si personne n'a
--                        accepte), etat final
--      expiree      -> jamais reclamee avant expires_at, balayee par un nettoyage ulterieur
--      annulee      -> retrait volontaire de l'offreur avant resolution
--    Le passage en_attente -> en_resolution s'obtient par un PATCH PostgREST conditionnel
--    (?id=eq.X&statut=eq.en_attente) : le verrouillage ligne de Postgres garantit qu'un seul
--    client concurrent peut reussir ce claim (le code appelant doit verifier que la ligne
--    retournee par Prefer: return=representation n'est pas vide avant de continuer -- discipline
--    cote application, aucune primitive Supabase supplementaire requise).
--    "pa_debite" n'est JAMAIS un verrou pose avant verification : il ne passe a true qu'apres
--    l'appel reussi a deduireCoutOrdre(), uniquement comme trace factuelle permettant une reprise
--    idempotente (un client qui reprend une resolution "en_resolution" perimee saute le re-debit
--    du PA si pa_debite=true, et va directement a la boucle de credit des acceptants).
--    "resolution_started_at" est l'horodatage du claim ; un autre client peut re-reclamer une
--    tournee restee "en_resolution" au-dela de 30 secondes (crash presume du claimant precedent),
--    via le meme motif de PATCH conditionnel mais teste sur l'ancien statut "en_resolution" au
--    lieu de "en_attente".
--    "expires_at" est calcule explicitement a la creation (now() + 5 minutes) plutot que derive
--    de created_at + une duree constante relue ailleurs, pour rester stable si cette duree est
--    un jour modifiee. Passe ce delai, les invitations encore "attente" comptent comme des refus
--    silencieux et ne bloquent plus la resolution.
--    "pnj_resultats" fige le tirage (acceptation/refus) des cibles PNJ de la tournee au moment de
--    la creation, pour que la resolution n'ait pas besoin de retirer au hasard une seconde fois.
--
-- 2) invitations_diner.tournee_id (nullable) : rattache une invitation existante a sa tournee
--    quand elle en fait partie. NULL pour les invitations du flux mono-cible existant
--    (diner_affaires, inchange). Reutilise la table telle quelle (colonnes inviteur/invite/
--    country/city/building_id/room_id/statut/cout/type/message/reponse deja en place) plutot que
--    de dupliquer un mecanisme d'invitation parallele.
--
-- Aucun index secondaire ajoute : verification faite sur les 6 migrations existantes portant sur
-- des tables ordinaires (etat_civil_ville, forum_organisation, journal_editions,
-- logements_sociaux_montrouge, mail_organisation, origin_school_freepts), AUCUNE ne cree
-- d'index au-dela de celui, implicite, de la cle primaire -- y compris pour des tables deja
-- interrogees par egalite sur une colonne "statut" (logements_demandes, terrains_etat) ou par
-- egalite sur une colonne de rattachement a un joueur (mails.invite, invitations_diner.invite).
-- Reproduire ce meme modele ici (aucun CREATE INDEX) est donc la convention reellement en usage
-- dans ce projet, pas une invention.
--
-- Aucune politique RLS/GRANT ajoutee non plus : sur les 7 migrations existantes, seule
-- migration_org_avatars_storage.sql en definit -- et exclusivement pour un bucket Supabase
-- Storage (storage.objects), pas pour une table relationnelle ordinaire ; ce fichier documente
-- meme explicitement le rejet d'une politique d'ecriture sur la cle anon au profit d'un endpoint
-- serveur en service_role. Les 6 autres migrations, qui portent comme celle-ci sur de simples
-- tables Postgres, n'activent aucune RLS et ne definissent aucune policy -- coherent avec le
-- reste du projet, ou le client interroge directement toutes les tables via la cle anon
-- (supabase.js, sbGet/sbInsert/sbUpdate/sbDelete). "tournees" et invitations_diner.tournee_id
-- suivent donc ce meme modele : aucune RLS, aucune policy.
--
-- La cle anon (utilisee par le client via l'API REST) n'a pas les privileges DDL necessaires pour
-- executer ceci elle-meme -- comme pour toutes les migrations precedentes de ce projet, toujours
-- executees manuellement par Fred dans l'editeur SQL Supabase.
--
-- Sans cette migration : aucune fonctionnalite existante n'est affectee (boire_verre et
-- diner_affaires continuent de fonctionner sur le flux mono-cible actuel jusqu'a ce que le code
-- applicatif de la tournee soit ecrit et bascule boire_verre dessus).

CREATE TABLE IF NOT EXISTS tournees (
  id text PRIMARY KEY,
  country text NOT NULL,
  ville text NOT NULL,
  offreur text NOT NULL,
  building_id text NOT NULL,
  room_id text,
  commerce_type text NOT NULL,
  recette_id text NOT NULL,
  prix_unitaire_reference numeric NOT NULL,
  pnj_resultats jsonb,
  statut text NOT NULL DEFAULT 'en_attente'
    CHECK (statut IN ('en_attente', 'en_resolution', 'resolue', 'expiree', 'annulee')),
  pa_debite boolean NOT NULL DEFAULT false,
  resolution_started_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL
);


ALTER TABLE invitations_diner
  ADD COLUMN IF NOT EXISTS tournee_id text;
