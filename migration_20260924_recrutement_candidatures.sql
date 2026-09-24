-- =============================================================================================
-- RECRUTEMENT MILITAIRE : LES CANDIDATURES (24 septembre 2026)
-- =============================================================================================
-- POURQUOI UNE TABLE NEUVE PLUTOT QUE L'EXISTANT. Le depot possede deja deux filieres, et elles
-- sont structurellement incompatibles avec ce qui est demande ici :
--   * militaire_candidater_soldat(p_compagnie_id, p_section_id) fait CHOISIR sa section au
--     candidat. Le modele voulu est l'inverse : le candidat ne choisit rien, sa candidature est
--     VUE par tous les recruteurs eligibles, et le premier qui accepte l'emporte.
--   * engagements_militaires porte un statut LINEAIRE a trois etats (attente_commandant ->
--     attente_capitaine -> affecte) : un seul decideur a la fois, pas de diffusion, pas de refus
--     individuel qui laisse la candidature vivante ailleurs.
-- Rien de tout cela ne se plie a « plusieurs candidatures simultanees, plusieurs recruteurs, un
-- refus individuel qui ne tue pas la candidature ». On ajoute donc une table dediee, SANS toucher
-- aux filieres existantes -- Vince et sa section continuent de vivre exactement comme avant.
--
-- LE CYCLE DE VIE, ET IL N'Y EN A QU'UN :
--   active     -- deposee, visible des recruteurs eligibles, 2 PA deja payes
--   acceptee   -- un recruteur l'a prise ; la place est RESERVEE, 48 h pour se presenter
--   finalisee  -- le candidat est venu a la caserne, le poste est pris
--   retiree    -- le candidat l'a retiree lui-meme
--   annulee    -- une AUTRE candidature du meme joueur a ete acceptee
--   expiree    -- les 48 h sont passees sans presentation
-- Un refus individuel n'est PAS un etat : il s'inscrit dans `refus`, et la candidature reste
-- `active` pour les autres. C'est ce qui permet a un candidat d'etre refuse par un Lieutenant et
-- pris par un autre sans jamais savoir que le premier l'a ecarte.
--
-- LA RESERVATION NE TOUCHE PAS LE BLOB DE LA COMPAGNIE. Une candidature acceptee porte sa
-- compagnie et sa section, et c'est TOUT : la compagnie n'est modifiee qu'a la finalisation.
-- La capacite se calcule donc partout comme « places reellement occupees + places reservees par
-- une acceptation encore valide ». Deux consequences heureuses : une acceptation expiree cesse
-- de reserver TOUTE SEULE, a la seconde pres, sans attendre le cron ; et une expiration ne laisse
-- jamais un blob a demi ecrit.
-- =============================================================================================

CREATE TABLE IF NOT EXISTS public.candidatures_militaires (
  id            text PRIMARY KEY,
  pays          text NOT NULL,
  candidat      text NOT NULL,
  -- TROIS GRADES, PAS QUATRE. Le Commandant de la Caserne n'est PAS ici, et c'est delibere :
  -- c'est un POSTE NOMME (data.js, POSTES_NOMMES_EXCLUSIFS), deja candidatable par l'ordre
  -- `postuler` du Palais du Gouvernement, deja facture 2 PA, deja arbitre par le Ministre de la
  -- Defense, et deja resolu par tirage au sort au bout de 48 h si le Ministre ne tranche pas
  -- (traiterCandidaturesPostesExpirees, api/cron-minuit.js). Ce maillon-la fonctionne : le
  -- registre postes_attribues porte aujourd'hui min_def = Arnie avec la source
  -- `candidature_autorite_pnj`. Lui ajouter une seconde porte par la caserne creerait deux
  -- chemins concurrents vers la meme fonction -- exactement le systeme parallele proscrit. La
  -- caserne se contente donc d'INDIQUER ce chemin ; elle ne le double pas.
  grade_vise    text NOT NULL CHECK (grade_vise IN ('capitaine','lieutenant','soldat')),
  statut        text NOT NULL DEFAULT 'active'
                  CHECK (statut IN ('active','acceptee','finalisee','retiree','annulee','expiree')),
  -- Noms des recruteurs qui ont ecarte CETTE candidature. Jamais montre au candidat.
  refus         jsonb NOT NULL DEFAULT '[]'::jsonb,
  cree_le       timestamptz NOT NULL DEFAULT now(),
  -- Relance de maintien : tous les 7 jours tant que la candidature vit.
  derniere_relance timestamptz,
  -- Renseignes a l'acceptation, et a ce moment-la seulement.
  accepte_par   text,
  accepte_le    timestamptz,
  echeance      timestamptz,
  compagnie_id  text,
  section_id    text,
  finalise_le   timestamptz
);

-- UNE SEULE CANDIDATURE VIVANTE PAR GRADE ET PAR PERSONNE. C'est ce qui rend le double-clic
-- inoffensif : la seconde insertion viole l'index, elle ne cree pas de doublon et ne debite pas
-- deux fois. Les candidatures a des grades DIFFERENTS restent evidemment permises -- c'est tout
-- l'interet des candidatures multiples.
CREATE UNIQUE INDEX IF NOT EXISTS candidatures_militaires_une_vivante_par_grade
  ON public.candidatures_militaires (candidat, grade_vise)
  WHERE statut IN ('active','acceptee');

CREATE INDEX IF NOT EXISTS candidatures_militaires_actives
  ON public.candidatures_militaires (pays, grade_vise) WHERE statut = 'active';

COMMENT ON TABLE public.candidatures_militaires IS
  'Candidatures a un grade militaire. Diffusees a tous les recruteurs eligibles ; le premier qui accepte l''emporte. Un refus individuel s''inscrit dans refus et laisse la candidature active.';

ALTER TABLE public.candidatures_militaires ENABLE ROW LEVEL SECURITY;

-- AUCUN ACCES DIRECT DU NAVIGATEUR, PAS MEME EN LECTURE -- ET C'EST LE POINT LE PLUS IMPORTANT
-- DE CE FICHIER. Cette table contient deux colonnes qu'un joueur ne doit JAMAIS pouvoir lire :
--   * `refus`, la liste nominative des recruteurs qui l'ont ecarte. La regle interdit de le lui
--     apprendre par courrier ; la lui laisser lire dans la table par une requete PostgREST
--     reviendrait exactement au meme, en pire, puisqu'il y lirait aussi les refus des autres.
--   * `accepte_par` et `compagnie_id`/`section_id`, qui sont toute la scene de decouverte. Les
--     exposer avant la presentation a la caserne viderait cette scene de son contenu.
-- Une policy SELECT « son propre pays » aurait donne les deux. Une lecture par colonnes aurait
-- pu marcher, mais elle se serait silencieusement rouverte au premier ALTER TABLE ... ADD COLUMN.
-- On ferme donc la table entierement : les deux cotes sont servis par des RPC qui projettent
-- exactement ce que chacun a le droit de voir -- militaire_mes_candidatures() pour le candidat,
-- militaire_candidatures_a_traiter() pour le recruteur. RLS reste activee sans aucune policy,
-- ce qui rend la fermeture doublement vraie : ni GRANT, ni policy.
REVOKE ALL ON public.candidatures_militaires FROM anon, authenticated, PUBLIC;
GRANT ALL ON public.candidatures_militaires TO service_role;
