-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927170406
-- Nom original      : socle_pnj_registre_des_fonctions_gamma
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-27 17:04:06 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : eac14e85445233b16ad5c6fcdcce9227
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
-- CHECKPOINT C — REGISTRE DES FONCTIONS, ET CLASSE DES PNJ DU DECOR
--
-- CE QUE CE REGISTRE N'EST PAS. Ce n'est pas une copie des PNJ du decor. Ceux-la vivent dans
-- data.js -- BUILDINGS[batiment].rooms[piece].persons -- qui EST le monde commun, statique et
-- identique pour tous. Les recopier ligne par ligne dans pnj_membres creerait exactement la « copie
-- parallele uniquement pour l'affichage » que la regle de presence interdit. Le socle n'a donc pas
-- besoin de les porter : il a besoin de SAVOIR CE QUI EST UNIVERSEL a leur sujet, c'est-a-dire leur
-- classe et leur nature. C'est ce que fait cette table.
--
-- POURQUOI DEUX COLONNES DE CLASSE, ET NON UNE. Parce qu'un meme mot de fonction couvre deux
-- natures. `douanier` designe la fonction de Prosper Tampon, Gamma fixe au passage en douane, ET le
-- metier des quatre effectifs Beta du service. Une table qui donnerait « douanier -> une classe »
-- serait fausse dans un cas sur deux. On declare donc separement :
--   * classe_decor    : la classe des PNJ POSES DANS LE DECOR qui portent cette fonction ;
--   * metier_beta     : existe-t-il, par ailleurs, un metier Beta portant ce nom ?
--   * recrutable      : un joueur peut-il recruter un PNJ du DECOR portant cette fonction ?
-- Les trois sont independantes, et c'est le coeur de la separation classe / fonction.
--
-- « REFERENT » N'EST PAS UNE CLASSE. C'est une propriete fonctionnelle : un PNJ consultable qui
-- peut, en plus, renseigner sur son domaine. La colonne `role_fonctionnel` la porte a ce titre,
-- au meme rang que « acces » ou « institutionnel » -- aucune quatrieme classe n'est creee.
CREATE TABLE IF NOT EXISTS public.pnj_fonctions (
  fonction         text PRIMARY KEY,
  classe_decor     text NOT NULL CHECK (classe_decor IN ('alpha','beta','gamma')),
  metier_beta      boolean NOT NULL DEFAULT false,
  recrutable       boolean NOT NULL DEFAULT false,
  role_fonctionnel text NOT NULL CHECK (role_fonctionnel IN
                     ('decor','dialogue','acces','referent','institutionnel','mecanique')),
  note             text);

ALTER TABLE public.pnj_fonctions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.pnj_fonctions FROM anon, authenticated, PUBLIC;

COMMENT ON TABLE public.pnj_fonctions IS
  'Nature des PNJ du decor, fonction par fonction. Ne contient AUCUN PNJ : le decor lui-meme vit '
  'dans data.js, qui est le monde commun. Regle par defaut : un PNJ pose dans le decor est GAMMA '
  'sauf preuve explicite qu''il releve deja d''Alpha ou de Beta.';
COMMENT ON COLUMN public.pnj_fonctions.metier_beta IS
  'true quand un metier Beta porte le meme nom que cette fonction du decor. Ne rend PAS le PNJ du '
  'decor recrutable : cf. douanier, fonction Gamma de Prosper Tampon et metier Beta des effectifs.';
COMMENT ON COLUMN public.pnj_fonctions.recrutable IS
  'true seulement si un joueur peut recruter un PNJ DU DECOR portant cette fonction. Une seule '
  'fonction est dans ce cas : escort. Toutes les autres sont Gamma et ne s''emploient pas.';

INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES
  -- LA SEULE FONCTION DU DECOR QUI MENE A UN RECRUTEMENT BETA.
  ('escort', 'gamma', true, true, 'mecanique',
   'Les deux escortes posees au bar de l''Hotel La Republica sont du decor, mais elles ont un vrai '
   || 'chemin Beta : bouton dedie, 800 FR, profil fixe, actions propres. Seule fonction recrutable.'),
  -- FONCTIONS GAMMA CITEES COMME EXEMPLES VALIDES.
  ('garde', 'gamma', false, false, 'acces',
   'Gamma fixe. Controle l''acces a certains lieux (palais, assemblee).'),
  ('portier', 'gamma', false, false, 'acces',
   'Gamma fixe. Controle l''acces a la loge maconnique.'),
  ('douanier', 'gamma', true, false, 'mecanique',
   'Prosper Tampon : Gamma FIXE, fonction douanier au passage en douane, notamment dans le parcours '
   || 'permettant de prendre l''avion. A ne pas confondre avec le METIER douanier des quatre '
   || 'effectifs Beta du service -- meme mot, nature differente. C''est le cas demonstratif.'),
  ('lobbyiste', 'gamma', false, false, 'referent',
   'Gamma fixe, consultable comme tous les PNJ. Sa fonction lui donne un domaine de reference. '
   || 'L''existence d''une RPC dediee (assemblee_consulter_lobbyiste) ne change pas sa classe.'),
  ('grand_pretre', 'gamma', false, false, 'institutionnel',
   'Gamma fixe dans le monde, mais sa FONCTION peut etre reprise par un PJ. Reprise de fonction '
   || 'n''est pas disparition : il reste present, il cesse d''en etre le titulaire.'),
  ('commissaire', 'gamma', false, false, 'institutionnel',
   'Gamma fixe, fonction remplacable par un PJ. Le Commissaire Touffaud RESTE physiquement dans le '
   || 'jeu si le maire nomme un Commissaire PJ : existence et titularite sont deux choses.'),
  ('juge', 'gamma', false, false, 'institutionnel',
   'Gamma fixe, fonction remplacable par un PJ. Meme principe que le Commissaire.'),
  ('depute', 'gamma', false, false, 'institutionnel',
   'Gamma a PRESENCE CONDITIONNELLE, regle metier propre aux deputes : present tant qu''aucun PJ '
   || 'n''occupe son siege. Voir pnj_deputes_presence. Ne pas generaliser aux autres Gamma.'),
  ('titulaire_poste', 'gamma', false, false, 'institutionnel',
   'Occupe fonctionnellement un poste en l''absence d''un PJ. N''EST PAS une autorite : un poste '
   || 'tenu par un PNJ laisse l''autorite humaine vacante.'),
  -- LES AUTRES FONCTIONS DU DECOR. Classe gamma par defaut ; role releve de l'audit, pas suppose.
  ('serveur',      'gamma', false, false, 'dialogue', 'Decor de salle.'),
  ('hotelier',     'gamma', false, false, 'dialogue', 'Decor d''accueil.'),
  ('barman',       'gamma', false, false, 'referent',
   'Marin Dulac, au Bar des Pecheurs, est la source de l''ecoute de rumeurs.'),
  ('inspecteur',   'gamma', false, false, 'dialogue', 'Decor.'),
  ('militaire',    'gamma', false, false, 'decor',
   'Decor de caserne. AUCUN lien avec les 96 soldats Alpha, qui vivent au socle.'),
  ('soldat',       'gamma', false, true,  'decor',
   'Decor de caserne. La fonction `soldat` existe aussi comme famille ALPHA (96 hommes), recrutee '
   || 'par la filiere militaire et non comme employe. Le PNJ du decor n''est pas recrutable.'),
  ('general',      'gamma', false, false, 'dialogue', 'Decor.'),
  ('journaliste',  'gamma', false, false, 'dialogue', 'Decor de redaction et d''accreditation.'),
  ('redacteur',    'gamma', false, false, 'dialogue', 'Decor de redaction.'),
  ('medecin',      'gamma', false, false, 'dialogue', 'Decor de soin.'),
  ('infirmier',    'gamma', false, false, 'dialogue', 'Decor de soin.'),
  ('avocat',       'gamma', false, false, 'decor',    'AUCUN PNJ ne porte cette fonction.'),
  ('banquier',     'gamma', false, false, 'dialogue', 'Decor bancaire.'),
  ('commercant',   'gamma', false, false, 'dialogue',
   'La fonction la plus repandue du decor (16 PNJ). Un PJ proprietaire de commerces pourra un jour '
   || 'recruter des Beta et leur donner ce role : cela ne rendra pas ces Gamma-ci employables.'),
  ('marchande',    'gamma', false, false, 'dialogue', 'Decor de vente.'),
  ('professeur',   'gamma', false, false, 'dialogue', 'Decor.'),
  ('syndicaliste', 'gamma', false, false, 'dialogue', 'Decor syndical.'),
  ('loge',         'gamma', false, false, 'decor',    'AUCUN PNJ ne porte cette fonction.'),
  ('venerable',    'gamma', false, false, 'dialogue', 'Decor de loge.'),
  ('docker',       'gamma', false, false, 'dialogue', 'Decor portuaire, un par port.'),
  ('secretaire',   'gamma', false, false, 'dialogue', 'Decor administratif.'),
  ('hotesse',      'gamma', false, false, 'dialogue',
   'Decor d''accueil. DISTINCTE de hotesse_objets_trouves, autre fonction, qui porte le bouton '
   || '« Demander des confidences ».'),
  ('hotesse_objets_trouves', 'gamma', false, false, 'referent',
   'Gamma referente : interrogeable sur les objets trouves.'),
  ('policier',     'gamma', true,  false, 'mecanique',
   'Le Brigadier Local est du decor. Le METIER policier Beta, lui, est recrute par un Commissaire '
   || 'dans les effectifs de police : meme mot, autre nature.'),
  ('detenu',       'gamma', false, false, 'dialogue',
   'Detenus poses en prison. NE PAS confondre avec le metier codetenu, prevu mais jamais active : '
   || 'aucun PNJ du jeu ne porte job=codetenu, et il ne faut pas transformer un detenu en codetenu.'),
  ('informateur',  'gamma', true,  false, 'mecanique',
   'AUCUN PNJ du decor ne porte cette fonction -- Rene Seigne, decrit « Habitue du bar — '
   || 'Informateur », a job:null. Le metier Beta informateur se recrute par un ORDRE de salle, pas '
   || 'sur une fiche PNJ.'),
  ('codetenu',     'gamma', true,  false, 'decor',
   'METIER PREVU, JAMAIS ACTIVE. Aucun PNJ du jeu ne porte cette fonction : le bouton « Faire '
   || 'alliance » existe mais n''est rendu sur aucune fiche. Profil conserve, chemin non ouvert.'),
  ('default',      'gamma', false, false, 'decor',
   'Repli de tout PNJ sans fonction declaree, et fonction de quatre inconnus du decor.')
ON CONFLICT (fonction) DO UPDATE SET
  classe_decor = EXCLUDED.classe_decor, metier_beta = EXCLUDED.metier_beta,
  recrutable = EXCLUDED.recrutable, role_fonctionnel = EXCLUDED.role_fonctionnel,
  note = EXCLUDED.note;

-- Reponse unique a la question « ce PNJ du decor est-il employable ? ». FAIL-CLOSED : une fonction
-- inconnue n'est PAS recrutable. C'est l'inverse de l'ancien bouton generique, qui s'affichait des
-- qu'un PNJ portait un job quelconque.
CREATE OR REPLACE FUNCTION public.pnj_fonction_recrutable(p_fonction text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT COALESCE((SELECT f.recrutable FROM public.pnj_fonctions f WHERE f.fonction = p_fonction),
                  false);
$$;

-- Classe d'un PNJ du decor d'apres sa seule fonction. Par defaut gamma, conformement a la regle :
-- un PNJ pose dans le monde est Gamma sauf preuve qu'il releve d'Alpha ou de Beta.
CREATE OR REPLACE FUNCTION public.pnj_classe_decor(p_fonction text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT COALESCE((SELECT f.classe_decor FROM public.pnj_fonctions f WHERE f.fonction = p_fonction),
                  'gamma');
$$;

REVOKE ALL ON FUNCTION public.pnj_fonction_recrutable(text) FROM anon;
REVOKE ALL ON FUNCTION public.pnj_classe_decor(text)        FROM anon;