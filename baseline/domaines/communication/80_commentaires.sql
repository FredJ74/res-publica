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
COMMENT ON FUNCTION public.mail_systeme_envoyer(text,text,text,text,text) IS 'Porte RESEAU des courriers systeme : verifie l''identite de l''appelant puis sa liste blanche
d''expediteurs (mail_expediteur_autorise_strict), et delegue l''ecriture a
mail_systeme_poser_interne. Un appel serveur traverse les deux controles. Verdicts :
acteur_non_authentifie, parametres_invalides, expediteur_non_autorise, envoi_impossible, puis ok
avec l''identifiant du courrier.';
COMMENT ON FUNCTION public.mail_systeme_poser_interne(text,text,text,text,text) IS 'UNIQUE ECRIVAIN de public.mails cote serveur. Ne leve JAMAIS : tout echec est consigne dans
mails_envois_systeme avec son SQLSTATE et rendu en ok=false, pour qu''un courrier impossible
n''annule pas l''acte metier qui l''a declenche. N''a AUCUN controle d''expediteur -- c''est le
role de ses appelants, qui ont deja verifie leur propre autorite. Non appelable depuis le reseau :
les fonctions qui l''atteignent sont SECURITY DEFINER et s''executent sous son proprietaire.';
COMMENT ON TABLE public.mails_envois_systeme IS 'INCIDENTS D''ENVOI SYSTEME. Deux familles, distinguees par la colonne `echec` :
  . `echec` NULL  -> tentative REFUSEE par l''autorite : un client a demande a mail_systeme_envoyer
    d''ecrire sous un expediteur qui ne lui est pas autorise. La ligne nomme l''auteur reel.
  . `echec` renseigne -> envoi ACCEPTE mais IMPOSSIBLE : l''INSERT dans mails a leve, et la
    doctrine du 9 octobre 2026 veut que cela n''annule pas l''acte metier de l''appelant. La
    ligne porte le SQLSTATE et le message, pour que le courrier perdu reste nommable.
Dans les deux cas : aucune perte silencieuse. C''est la raison d''etre de cette table.';
