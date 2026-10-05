-- RENSEIGNEMENT : LE RAPPORT PORTE SUR LA JOURNEE ECOULEE COMPLETE (26 septembre 2026)
-- APPLIQUE EN PRODUCTION ET RECETTE. Feu vert explicite du concepteur.
--
-- LE DEFAUT, demontre. Le cron est planifie "0 23 * * *", soit 23:00 UTC. Paris etant
-- UTC+1 en hiver et UTC+2 en ete, la passe tombe TOUJOURS APRES minuit a Paris (00:00 ou
-- 01:00 du jour suivant). Or la chaine calculait
--     v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
-- c'est-a-dire LE JOUR QUI VIENT DE COMMENCER. Les observateurs ne balayaient donc que la
-- premiere heure de la nuit, et le rapport portait la date du jour a venir.
--
-- PREUVE EMPIRIQUE (passages au centre multimodal de Luthecia, par jour Paris) :
--   13/09 : 510 passages, 0 dans la fenetre 00h-02h  -> aucun fait
--   21/09 :   1 passage a 20:55, hors fenetre        -> aucun fait
--   23/09 :   1 passage a 16:05, hors fenetre        -> aucun fait
--   24/09 :   2 passages a 00:17 et 00:19, DANS la fenetre -> LE SEUL FAIT JAMAIS CONSIGNE
--
-- LA REGLE APPLIQUEE : la journee mondiale ecoulee complete, soit la date Paris de la veille
-- de l'instant d'execution. Aucun bricolage du type now() - X heures : on retire un JOUR a
-- une DATE, jamais des heures a un instant. Insensible a l'heure d'ete, a l'heure d'hiver et
-- au changement d'heure -- la seule hypothese est que la passe tombe apres minuit a Paris,
-- ce que 23:00 UTC garantit dans les deux regimes (+1 -> 00:00, +2 -> 01:00).
--
-- LE PIEGE EVITE. Le generateur agregeait les faits sur
--     (r.created_at AT TIME ZONE 'Europe/Paris')::date = v_jour
-- or les faits sont crees par la passe elle-meme, quelques millisecondes plus tot : leur
-- created_at porte le jour COURANT, pas le jour observe. Decaler v_jour sans rien d'autre
-- aurait donc vide TOUS les rapports. On separe les deux notions :
--   created_at   = quand le fait a ete CONSIGNE (inchange, technique)
--   jour_observe = le jour SUR LEQUEL il porte  (nouveau, metier)
-- La colonne prend sa valeur par DEFAULT, ce qui evite de reecrire les fonctions
-- d'observation : leur INSERT ne mentionne pas la colonne, le defaut s'applique, et il vaut
-- exactement la journee que la passe vient de balayer.
--
-- PERIMETRE EXACT DES FONCTIONS TOUCHEES -- verifie, pas suppose :
--   agent_conseillere_observer      : v_jour date, fenetre Paris    -> RECALEE
--   agent_coordinateur_multimodal   : v_jour date, fenetre Paris    -> RECALEE
--   agent_coordinateur_port         : v_jour date, fenetre Paris    -> RECALEE
--   cellules_rapports_generer       : v_jour date, libelle + agregat-> RECALEE
--   agent_traducteur_ecouter        : v_jour INTEGER = jour_de_jeu_pays(), utilise pour
--                                     at.jour_expiration >= v_jour. AUCUNE fenetre de date
--                                     Paris -> NON CONCERNEE, laissee intacte.
--   agent_garde_observer            : aucun v_jour, lit les compagnies presentes sans
--                                     fenetre de jour -> NON CONCERNEE.
--
-- Note assumee : les faits inseres hors de la passe nocturne (contre_espionnage_memoriser,
-- faits d'action personnelle d'un joueur) recevront un jour_observe decale d'un jour. Sans
-- effet : le generateur n'agrege que les lignes dont titulaire = 'cellule:<id>'.
--
-- RECETTE PASSEE (banc jetable zzbanc-*, production restauree a l'identique ensuite) :
--   4 passages d'une cible jetable au centre multimodal, heures PARIS :
--     J-1 00:03 / J-1 13:40 / J-1 23:52  (journee ecoulee)  +  J 09:15 (jour courant)
--   -> fait consigne : « 3 passages ... entre 00:03 et 23:52 »
--      debut, milieu ET fin de la journee ecoulee vus ; evenement du jour courant EXCLU
--   -> fait_objectif_ref porte 2026-09-25 ; jour_observe = 2026-09-25 alors que la
--      consignation a eu lieu le 2026-09-26 : les deux notions sont bien separees
--   -> seconde passe de l'observateur : aucun fait ajoute (dedup fait_objectif_ref)
--   -> deux passes du generateur : une seule ligne (idempotence (cellule_id, jour))
--   -> la cellule REELLE a ete correctement SAUTEE (son rapport du jour existait deja)
--   -> algebre de fenetre verifiee sur 5 dates dont la nuit du changement d'heure
--      (25/26 octobre 2026) : jours rapportes 24, 25, 26 -> consecutifs, chacun une fois,
--      aucun trou, aucun recouvrement, passe toujours apres minuit Paris.
--
-- ARTEFACT DE TRANSITION, A CONNAITRE : l'ancien code a pre-cree des rapports etiquetes avec
-- le jour A VENIR. Il existe donc deja une ligne (cel-1790081772650-f25d21, 2026-09-26) vide.
-- L'idempotence (cellule_id, jour) fera donc SAUTER la cellule reelle a la passe de cette
-- nuit : elle n'aura pas de rapport rempli pour le 26/09. Le fonctionnement est correct a
-- partir du 27/09. Aucune donnee n'a ete supprimee pour corriger cela -- la consigne est de
-- ne rien supprimer. Un DELETE de cette seule ligne vide suffirait a la faire regenerer.

ALTER TABLE public.renseignements_connus
  ADD COLUMN IF NOT EXISTS jour_observe date
    DEFAULT ((now() AT TIME ZONE 'Europe/Paris')::date - 1);

COMMENT ON COLUMN public.renseignements_connus.jour_observe IS
  'Journee mondiale (date Paris) SUR LAQUELLE porte le fait. A ne jamais confondre avec '
  'created_at, qui dit seulement quand le fait a ete consigne : la passe nocturne tourne '
  'apres minuit et consigne donc, le jour J, des faits qui portent sur J-1. Renseignee par '
  'DEFAULT pour que les fonctions d''observation n''aient pas a la citer.';

-- PREPARATION DE LA STRUCTURATION DU LIEU HISTORIQUE (section 10 du brief).
-- Colonnes creees, NULLABLES et NON remplies : les alimenter demande de reecrire les
-- fonctions d'observation, hors perimetre de cette passe. AUCUN backfill : le lieu des faits
-- existants n'est pas prouvable autrement que par le texte libre.
ALTER TABLE public.renseignements_connus
  ADD COLUMN IF NOT EXISTS pays        text,
  ADD COLUMN IF NOT EXISTS ville       text,
  ADD COLUMN IF NOT EXISTS building_id text,
  ADD COLUMN IF NOT EXISTS room_id     text;

COMMENT ON COLUMN public.renseignements_connus.pays IS
  'Lieu REEL de l''observation, fige au moment des faits. Rien a voir avec la couverture de '
  'la cellule : une cellule de couverture soviet peut observer un fait a Luthecia. NULL sur '
  'les faits anterieurs au 26 septembre 2026, dont le lieu n''est pas prouvable.';

-- On ne retranscrit PAS les corps a la main : chaque fonction est recreee depuis sa propre
-- definition en production, en ne substituant que l'initialisation de v_jour. La
-- transformation est exacte par construction, et le DO leve si un motif attendu manque --
-- c'est ainsi qu'a ete decouvert que agent_traducteur_ecouter n'etait pas concernee.
DO $mig$
DECLARE
  f record; d text; d2 text; v_n integer := 0;
  c_ancien  text := 'v_jour date := (now() AT TIME ZONE ''Europe/Paris'')::date;';
  c_nouveau text := 'v_jour date := ((now() AT TIME ZONE ''Europe/Paris'')::date - 1);';
BEGIN
  FOR f IN SELECT p.oid, p.proname FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = 'public'
             AND p.proname IN ('agent_conseillere_observer','agent_coordinateur_multimodal',
                               'agent_coordinateur_port','cellules_rapports_generer')
  LOOP
    d := pg_get_functiondef(f.oid);
    IF position(c_ancien in d) = 0 THEN
      RAISE EXCEPTION 'motif v_jour absent de %, transformation abandonnee', f.proname;
    END IF;
    d2 := replace(d, c_ancien, c_nouveau);

    IF f.proname = 'cellules_rapports_generer' THEN
      IF position('AND (r.created_at AT TIME ZONE ''Europe/Paris'')::date = v_jour' in d2) = 0 THEN
        RAISE EXCEPTION 'motif d''agregation absent de cellules_rapports_generer';
      END IF;
      d2 := replace(d2,
        'AND (r.created_at AT TIME ZONE ''Europe/Paris'')::date = v_jour',
        'AND r.jour_observe = v_jour');
    END IF;

    EXECUTE d2;
    v_n := v_n + 1;
  END LOOP;
  IF v_n <> 4 THEN
    RAISE EXCEPTION 'attendu 4 fonctions recalees, obtenu %', v_n;
  END IF;
END $mig$;

-- DETTE DE VERSIONNAGE RESTANTE, consignee : les corps complets des cinq fonctions
-- d'observation (agent_garde_observer, agent_traducteur_ecouter, agent_conseillere_observer,
-- agent_coordinateur_multimodal, agent_coordinateur_port), de cellule_renseignement_creer,
-- detention_ouvrir_interne et cellule_alerter_ministre n'existent dans AUCUN fichier du
-- depot -- le snapshot du 24/09 ne couvre que militaire_*/cellule*/mutinerie_*. Ce fichier-ci
-- ne les recopie pas : il les TRANSFORME depuis la production. Les dumper integralement est
-- un lot a part, a faire avant toute reconstruction a neuf de la base.
