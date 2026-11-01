-- Avis personnels jamais reçus : expéditeurs non déclarés (Claude, 31/10/2026, clôture Luthécia).
-- Compatible avec l'écran en ligne ; aucune donnée de joueur modifiée ; aucune règle de jeu changée.
--
-- addMailNotification() (plateau-communication.js) écrit dans `mails` un avis adressé AU JOUEUR
-- LUI-MÊME, signé d'une identité institutionnelle (« Gestionnaire immobilier », « Commissariat »…).
-- La politique `mails_envoi` n'accepte une identité institutionnelle que si elle figure dans
-- `mails_expediteurs_systeme` avec le droit voulu ; la tolérance de transition est close.
-- Neuf identités utilisées par l'écran pour ces avis n'y figuraient pas, ou n'avaient pas le droit
-- d'écrire au joueur lui-même : l'INSERT était refusé en silence (le badge local s'allumait, le
-- courrier n'arrivait jamais). Cas concrets : expulsion d'un local, libération de prison,
-- confirmation de candidature, plainte d'une escort, départ d'un employé, convocation douanière.
--
-- Correctif : déclarer ces identités avec `autorise_soi` SEULEMENT. Ce droit ne permet d'écrire
-- qu'à soi-même (mail_expediteur_autorise_strict, cas 1) : aucune de ces identités ne devient
-- utilisable vers un tiers. `Tribunal` et `Administration Portuaire`, déjà déclarées pour leurs
-- saisines, reçoivent le même droit à soi-même ; leurs autres droits sont inchangés.
-- Banc : outils/bancs/banc-avis-personnels-expediteurs.mjs (écran ↔ migration) ;
--        outils/bancs/banc-avis-personnels-expediteurs.sql (base, annulé).
BEGIN;

INSERT INTO public.mails_expediteurs_systeme
  (expediteur, note, est_prefixe, postes, autorise_soi, libre,
   autorise_vers_titulaire, autorise_vers_conjoint, autorise_vers_destinataire_fret)
VALUES
  ('Gestionnaire immobilier', 'avis à soi : expulsion d''un local loué', false, '{}', true, false, false, false, false),
  ('Commissariat',            'avis à soi : libération', false, '{}', true, false, false, false, false),
  ('Le Commissariat',         'avis à soi : convocation douanière (repli)', false, '{}', true, false, false, false, false),
  ('Raoul Toufaud',           'avis à soi : convocation douanière (Républia)', false, '{}', true, false, false, false, false),
  ('El Capitan Gordo',        'avis à soi : convocation douanière (Narco)', false, '{}', true, false, false, false, false),
  ('Camarade Borodine',       'avis à soi : convocation douanière (Soviet)', false, '{}', true, false, false, false, false),
  ('Chambellan Ibn Protocole','avis à soi : convocation douanière (Khalija)', false, '{}', true, false, false, false, false),
  ('Caserne',                 'avis à soi : poursuites éteintes', false, '{}', true, false, false, false, false),
  ('Etat-Major',              'avis à soi : déclaration de guerre', false, '{}', true, false, false, false, false),
  ('Commission Electorale',   'avis à soi : confirmation de candidature', false, '{}', true, false, false, false, false),
  ('Ressources Humaines',     'avis à soi : départ d''un employé', false, '{}', true, false, false, false, false)
ON CONFLICT (expediteur) DO UPDATE SET autorise_soi = true;

UPDATE public.mails_expediteurs_systeme SET autorise_soi = true
 WHERE expediteur IN ('Tribunal', 'Administration Portuaire') AND autorise_soi IS DISTINCT FROM true;

-- Preuve structurelle : chaque identité est déclarée et n'a gagné que le droit à soi-même.
DO $$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.mails_expediteurs_systeme
   WHERE expediteur IN ('Gestionnaire immobilier','Commissariat','Le Commissariat','Raoul Toufaud',
     'El Capitan Gordo','Camarade Borodine','Chambellan Ibn Protocole','Caserne','Etat-Major',
     'Commission Electorale','Ressources Humaines','Tribunal','Administration Portuaire')
     AND autorise_soi AND NOT est_prefixe;
  IF n <> 13 THEN RAISE EXCEPTION 'avis_personnels: % identites conformes sur 13', n; END IF;
  SELECT count(*) INTO n FROM public.mails_expediteurs_systeme
   WHERE expediteur IN ('Gestionnaire immobilier','Commissariat','Le Commissariat','Raoul Toufaud',
     'El Capitan Gordo','Camarade Borodine','Chambellan Ibn Protocole','Caserne','Etat-Major',
     'Commission Electorale','Ressources Humaines')
     AND (libre OR autorise_vers_titulaire OR autorise_vers_conjoint OR autorise_vers_destinataire_fret
          OR coalesce(array_length(postes, 1), 0) > 0);
  IF n <> 0 THEN RAISE EXCEPTION 'avis_personnels: % identite(s) ouvertes vers un tiers', n; END IF;
END $$;

COMMIT;
