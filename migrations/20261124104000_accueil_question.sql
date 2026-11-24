-- APPLIQUÉE en production le 24/11/2026 (contrôlée en lecture, mission Purge).
-- Purge, bloc A, point A.5 (Fred, 24/11/2026) : contenu de l'interview d'accueil. La journaliste demande au nouveau ce
-- qu'il veut être, et précise que s'il ne le sait pas encore, c'est normal : il a le temps de se décider. Les six chemins
-- existants restent proposés (accueil_chemins inchangé). Une interview fermée sans réponse reste dans « Mes objectifs »
-- (« Reprendre l'interview » : état a_faire, déjà en place depuis 20261123140000). NON APPLIQUÉE. Rejouable.
-- La question est une donnée de jeu (accueil_journalistes.question) : elle est remise à jour ici, après la migration
-- d'origine (qui ne doit plus être rejouée seule : elle remettrait l'ancienne phrase).
UPDATE public.accueil_journalistes SET question =
  'Bienvenue parmi nous ! Un nouveau visage, ça ne m''échappe jamais longtemps. Alors, dites-moi : que voulez-vous être, ici ? Si vous ne le savez pas encore, c''est normal : vous avez tout le temps de vous décider.'
 WHERE pays = 'republic';
UPDATE public.accueil_journalistes SET question =
  'Bienvenue, camarade. Le Parti aime connaître ses nouveaux citoyens. Dites aux lecteurs de La Voix de Sovarka ce que vous voulez être au service de la Patrie. Si vous ne le savez pas encore, c''est normal : vous avez tout le temps de vous décider.'
 WHERE pays = 'soviet';
