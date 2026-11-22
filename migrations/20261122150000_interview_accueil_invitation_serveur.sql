-- Interview d'accueil des nouveaux personnages (Claude, 22/11/2026)
-- Décisions de Fred du 21/11/2026 : GAME-DESIGN-INTERVIEW-ACCUEIL-20261121.md, point 2.
--
-- « Une interview envoyée est toujours publiable, premier jour compris. » Le verrou « Portrait
-- disponible après le premier jour » (api/jodie-portrait.js) n'existait que parce que le
-- NAVIGATEUR écrivait lui-même l'invitation de Jodie Moitout : `mails_expediteurs_systeme` lui
-- donnait le droit `autorise_soi` (écrire à soi-même sous ce nom). N'importe quel joueur pouvait
-- donc se fabriquer une invitation ; le serveur se protégeait en exigeant un jour d'ancienneté.
--
-- Désormais l'invitation et le refus sont écrits par le serveur (/api/jodie-portrait, actions
-- 'inviter' et 'refuser', compte de service : aucune règle d'expéditeur ne s'applique à lui).
-- Cette migration retire au navigateur le droit d'écrire au nom de Jodie Moitout. Les autres
-- journalistes d'antenne (Annie Houininon, Arthur Lutte, Zoïa Glazounova, Saran Batbayar,
-- Anatoli Kolosov) ne sont pas déclarés et ne doivent pas l'être : seul le serveur écrit pour eux.
--
-- Deuxième point : le portrait d'accueil est désormais signé par le journaliste de l'antenne qui
-- a invité. Le déclencheur propre aux portraits, jodie_portrait_vers_journal() (appelé par le
-- seul trigger trg_jodie_portrait_vers_journal, aucune autre fonction ne l'appelle), ne reprenait
-- dans le journal que les portraits de Jodie Moitout : il reconnaît maintenant les six
-- journalistes d'antenne (même corps, même identifiant, même origine 'portrait_jodie' ; seule la
-- liste des auteurs change). Copie de la liste : api/_presse-antennes.js.
--
-- Aucune fonction commune modifiée, aucune table créée, aucune donnée de joueur touchée.
-- Sans danger avant ou après le déploiement du code : depuis ce code, le navigateur n'écrit plus
-- jamais au nom de Jodie Moitout (vérifié par outils/bancs/banc-interview-accueil-antennes-20261122.cjs).
-- Banc : outils/bancs/banc-interview-accueil-pglite-20261122.cjs (PGlite). Rejouable.
BEGIN;

UPDATE public.mails_expediteurs_systeme
   SET autorise_soi = false
 WHERE expediteur = 'Jodie Moitout' AND NOT est_prefixe AND autorise_soi;

CREATE OR REPLACE FUNCTION public.jodie_portrait_vers_journal()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_sujet public.forum_topics%ROWTYPE;
BEGIN
  SELECT * INTO v_sujet FROM public.forum_topics WHERE id=NEW.topic_id;
  -- Journalistes d'antenne (interview d'accueil, Fred 21/11/2026) : api/_presse-antennes.js.
  IF v_sujet.forum_id='presse'
     AND v_sujet.author IN ('Jodie Moitout','Annie Houininon','Arthur Lutte','Zoïa Glazounova','Saran Batbayar','Anatoli Kolosov')
     AND NEW.author=v_sujet.author
     AND v_sujet.title LIKE 'Un jour, un portrait : %'
     AND length(btrim(coalesce(NEW.content,'')))>=40
  THEN
    INSERT INTO public.journal_articles_en_attente
      (id,country,rubrique,titre,texte,origine,priorite,statut,dedup_key)
    VALUES ('jodie-portrait-'||NEW.topic_id,v_sujet.country,'Portraits',
      v_sujet.title,NEW.content,'portrait_jodie','importante','attente',
      'portrait-jodie-'||NEW.topic_id)
    ON CONFLICT (id) DO UPDATE SET texte=EXCLUDED.texte
      WHERE public.journal_articles_en_attente.integree_le IS NULL;
  END IF;
  RETURN NEW;
END; $$;

-- Preuve structurelle : Jodie Moitout reste déclarée (son nom n'est pas « inventé ») mais n'ouvre
-- plus aucun droit au navigateur ; aucun journaliste d'antenne n'est utilisable par le navigateur.
DO $$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.mails_expediteurs_systeme
   WHERE expediteur = 'Jodie Moitout' AND NOT est_prefixe
     AND NOT autorise_soi AND NOT libre AND NOT autorise_vers_titulaire
     AND NOT autorise_vers_conjoint AND NOT autorise_vers_destinataire_fret
     AND coalesce(array_length(postes, 1), 0) = 0;
  IF n <> 1 THEN RAISE EXCEPTION 'interview_accueil : Jodie Moitout garde un droit navigateur (% ligne conforme)', n; END IF;

  SELECT count(*) INTO n FROM public.mails_expediteurs_systeme m
   WHERE (m.autorise_soi OR m.libre OR coalesce(array_length(m.postes, 1), 0) > 0)
     AND EXISTS (SELECT 1 FROM unnest(ARRAY['Jodie Moitout','Annie Houininon','Arthur Lutte',
                   'Zoïa Glazounova','Saran Batbayar','Anatoli Kolosov']) j(nom)
                  WHERE (NOT m.est_prefixe AND m.expediteur = j.nom)
                     OR (m.est_prefixe AND j.nom LIKE m.expediteur || '%'));
  IF n <> 0 THEN RAISE EXCEPTION 'interview_accueil : % identite(s) de journaliste encore ouverte(s) au navigateur', n; END IF;
END $$;

COMMIT;
