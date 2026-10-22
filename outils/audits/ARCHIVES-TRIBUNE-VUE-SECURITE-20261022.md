# Archives de presse — contrôle de la vue

Constat en lecture seule sur Supabase : la vue `public.archives_tribune_index` ne lit que `public.journal_editions`, filtrée aux éditions publiées de l'Autruche Entravée. Sa table source dispose de RLS et de droits SELECT pour les rôles anon et authenticated.

Proposition : modifier uniquement l'option de sécurité de la vue pour que ses requêtes respectent les privilèges du demandeur (`security_invoker=true`). Conserver sa définition, ses colonnes, ses titres, les archives utiles à l'énigme du musée et les droits de consultation déjà accordés.

Avant déploiement : créer une migration via Supabase CLI, vérifier le catalogue vivant, tester sur base isolée les lectures anon/authenticated et le refus des autres éditions ; recontrôler l'alerte Supabase Advisor. Ne pas traiter la vue `personnages` dans ce lot.

Aucune migration exécutée ; aucun changement de données.