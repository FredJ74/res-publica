-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927174556
-- Nom original      : socle_pnj_renseignement_identites_reelles_au_socle
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-27 17:45:56 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 5091437c84a8ab96126f6004a04a7da3
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CONVERGENCE RENSEIGNEMENT, ETAPES 1 A 4 — LES QUATRE IDENTITES REELLES ENTRENT AU SOCLE
--
-- LE MODELE. Il n'y a pas douze agents : il y a QUATRE identites reelles permanentes, une par role
-- (la table renseignement_identites_reelles a `role` pour cle primaire), et plusieurs missions
-- successives. Les douze lignes de `agents_renseignement` sont 4 identites x 3 cellules : ce sont
-- des OCCURRENCES DE MISSION, conservees comme historique. Le socle porte l'identite, le metier
-- garde la mission.
--
-- CE QUI EST FAIT ICI, et rien de plus :
--   1. une institution `renseignement`, avec son resolveur d'autorite ;
--   2. les 4 identites reelles inscrites dans pnj_membres, classe BETA ;
--   3. le profil fixe unique 13/12/12/13/13/10 ;
--   4. le lien `pnj_id` des occurrences de mission vers leur identite, historique compris ;
--   5. un comparateur.
--
-- CE QUI N'EST PAS FAIT, ET POURQUOI. La position et le leader NE SONT PAS BASCULES. Mesure faite
-- avant d'ecrire : `cellule_renseignement_creer` ne porte AUCUNE garde sur le nombre de cellules
-- actives, et le pool compte 6 couvertures par sexe et par pays cible tandis qu'une cellule en
-- consomme 3 H + 1 F. Deux cellules simultanees sont donc possibles par pays cible, et quatre pays
-- cibles existent : jusqu'a HUIT cellules actives en meme temps. Les douze lignes historiques le
-- montrent d'ailleurs -- deux cellules ont coexiste treize heures les 21 et 22 septembre, et Gladys
-- Crete y etait engagee DEUX FOIS, sous deux couvertures et a deux positions.
-- Or une identite reelle unique au socle ne peut avoir qu'UNE position. Basculer la position
-- exigerait donc soit d'interdire les missions simultanees -- ce qui retire au Ministre la capacite
-- d'espionner deux pays a la fois --, soit de laisser la position au metier. C'est un arbitrage de
-- game design, pas une migration : il est pose, pas tranche.
--
-- LES PA. classe beta : 12 PA presents, jamais consommes. Conforme au fait qu'aucune action de
-- renseignement ne coute de PA a l'agent (les 3 PA de la convocation sont ceux du MINISTRE).
CREATE OR REPLACE FUNCTION public.renseignement_autorite_de_perimetre(
  p_pays text, p_perimetre text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  -- Le perimetre d'une identite de renseignement est son PAYS. L'autorite est le PJ portant le
  -- poste min_def de ce pays -- c'est exactement la garde que cellule_renseignement_creer applique
  -- deja pour convoquer une cellule. Aucune autorite n'est inventee, et « personne » reste un etat
  -- valide : un poste tenu par un titulaire PNJ ne rend pas ce PNJ autorite.
  SELECT pa.titulaire FROM public.postes_attribues pa
   WHERE pa.poste_id = 'min_def' AND pa.country = COALESCE(p_perimetre, p_pays)
     AND pa.titulaire IS NOT NULL
   LIMIT 1;
$$;

INSERT INTO public.pnj_institutions (institution, resolveur, note) VALUES
  ('renseignement', 'renseignement_autorite_de_perimetre',
   'Perimetre = le PAYS. Autorite : le PJ portant le poste min_def de ce pays, meme garde que '
   || 'cellule_renseignement_creer. Les quatre identites reelles appartiennent au service, pas au '
   || 'ministre : un ministre passe, l''agent reste.')
ON CONFLICT (institution) DO UPDATE SET resolveur = EXCLUDED.resolveur, note = EXCLUDED.note;

-- PROFIL UNIQUE. La variation de DUP par role (garde 10, coordinateur 12, conseiller 13,
-- traducteur 15) cesse d'etre autoritaire : les quatre partagent 13. CONSEQUENCE ASSUMEE, et c'est
-- la seule que ce lot produise sur le jeu : le risque de trace, `max(5, 30 - DUP)`, devient
-- UNIFORME a 17 % au lieu de 15 a 20 % selon le role, et le modificateur de contre-espionnage
-- cesse de dependre du role. Les FORMULES sont inchangees, seule leur entree est unifiee -- ce que
-- l'arbitrage demande explicitement en supprimant la variation par role.
INSERT INTO public.pnj_metiers_profils
  (metier, car_int, car_cha, car_vol, car_per, car_dup, car_ent,
   pa_initial, cout_initial, cout_jour, note, quota_note)
VALUES ('agent', 13, 12, 12, 13, 13, 10, 0, 0, NULL,
  'Metier de la famille agent, classe beta. Profil UNIQUE pour les quatre identites reelles : le '
  || 'role est une specialisation de CAPACITES, pas un profil de caracteristiques. Seule DUP est '
  || 'mecaniquement lue (risque de trace, contre-espionnage) ; INT, CHA, VOL, PER et ENT sont '
  || 'presentes sans mecanique -- aucun effet ne leur est cree.',
  'Quatre identites, une par role. Convoquees par quatre par le Ministre de la Defense : 3 PA du '
  || 'MINISTRE et 500 FR sur la caisse min_def, jamais un cout de l''agent.')
ON CONFLICT (metier) DO UPDATE SET
  car_int = EXCLUDED.car_int, car_cha = EXCLUDED.car_cha, car_vol = EXCLUDED.car_vol,
  car_per = EXCLUDED.car_per, car_dup = EXCLUDED.car_dup, car_ent = EXCLUDED.car_ent,
  pa_initial = EXCLUDED.pa_initial, cout_initial = EXCLUDED.cout_initial,
  cout_jour = EXCLUDED.cout_jour, note = EXCLUDED.note, quota_note = EXCLUDED.quota_note;

-- Identifiant stable d'une identite reelle : son ROLE, qui est sa cle primaire cote metier.
CREATE OR REPLACE FUNCTION public.renseignement_pnj_id(p_role text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$ SELECT 'agent-' || p_role; $$;

-- LES QUATRE IDENTITES. Position et leader laisses NULS : ils restent au metier tant que
-- l'arbitrage sur les missions simultanees n'est pas rendu. Un beta doit avoir un proprietaire,
-- et c'est l'INSTITUTION, avec le pays pour perimetre.
INSERT INTO public.pnj_membres (id, famille, classe, nom, pays,
    proprietaire_institution, proprietaire_perimetre, pa, statut,
    car_int, car_cha, car_vol, car_per, car_dup, car_ent)
SELECT public.renseignement_pnj_id(i.role), 'agent', 'beta', i.vrai_nom, 'republic',
       'renseignement', 'republic', 12, 'actif',
       p.car_int, p.car_cha, p.car_vol, p.car_per, p.car_dup, p.car_ent
  FROM public.renseignement_identites_reelles i, public.pnj_metiers_profils p
 WHERE p.metier = 'agent'
ON CONFLICT (id) DO UPDATE SET
    nom = EXCLUDED.nom, classe = EXCLUDED.classe,
    proprietaire_institution = EXCLUDED.proprietaire_institution,
    proprietaire_perimetre = EXCLUDED.proprietaire_perimetre,
    car_int = EXCLUDED.car_int, car_cha = EXCLUDED.car_cha, car_vol = EXCLUDED.car_vol,
    car_per = EXCLUDED.car_per, car_dup = EXCLUDED.car_dup, car_ent = EXCLUDED.car_ent,
    maj_le = now();

-- LIEN MISSION -> IDENTITE. Additif : aucune colonne existante n'est touchee, aucune ligne
-- historique n'est supprimee. Les douze occurrences pointent vers leur identite reelle, y compris
-- celles des deux cellules terminees -- c'est precisement l'historique des missions.
ALTER TABLE public.agents_renseignement
  ADD COLUMN IF NOT EXISTS pnj_id text REFERENCES public.pnj_membres(id);

COMMENT ON COLUMN public.agents_renseignement.pnj_id IS
  'Identite REELLE permanente de cet agent au socle (4 en tout, une par role). Cette table porte '
  'les OCCURRENCES DE MISSION : plusieurs lignes peuvent viser le meme pnj_id, une par cellule. '
  'Une cellule terminee ne detruit pas l''identite, elle termine l''incarnation.';

UPDATE public.agents_renseignement a
   SET pnj_id = public.renseignement_pnj_id(a.role)
 WHERE a.pnj_id IS NULL
   AND EXISTS (SELECT 1 FROM public.pnj_membres m
                WHERE m.id = public.renseignement_pnj_id(a.role));

-- Le referentiel metier cesse d'etre la source de la DUP : il pointe vers le socle. La colonne
-- reste en place, car cellule_renseignement_creer la lit encore -- on ne retire pas une colonne
-- dont un ecrivain vivant depend.
COMMENT ON COLUMN public.renseignement_identites_reelles.dup IS
  'PERIME comme source depuis le 27/09/2026 : la DUP autoritaire est pnj_membres.car_dup des '
  'quatre identites (13 pour toutes). Colonne conservee parce que cellule_renseignement_creer la '
  'lit encore ; a declasser quand cet ecrivain aura bascule.';