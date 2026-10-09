-- Commentaires d'objets
-- ============================================================================
-- BASELINE Human Gambit -- domaine communication -- phase 80 : commentaires
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

COMMENT ON COLUMN public.mails_envois_systeme.echec IS 'SQLSTATE et message de l''erreur qui a empeche l''ecriture du courrier, quand il y en a une.
NULL quand la ligne consigne un refus d''autorite et non un echec technique.';
COMMENT ON TABLE public.mails_envois_systeme IS 'INCIDENTS D''ENVOI SYSTEME. Deux familles, distinguees par la colonne `echec` :
  . `echec` NULL  -> tentative REFUSEE par l''autorite : un client a demande a mail_systeme_envoyer
    d''ecrire sous un expediteur qui ne lui est pas autorise. La ligne nomme l''auteur reel.
  . `echec` renseigne -> envoi ACCEPTE mais IMPOSSIBLE : l''INSERT dans mails a leve, et la
    doctrine du 9 octobre 2026 veut que cela n''annule pas l''acte metier de l''appelant. La
    ligne porte le SQLSTATE et le message, pour que le courrier perdu reste nommable.
Dans les deux cas : aucune perte silencieuse. C''est la raison d''etre de cette table.';
