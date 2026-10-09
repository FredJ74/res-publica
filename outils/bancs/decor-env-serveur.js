// DECOR DE BANC -- pose une identite serveur AVANT le chargement des modules de api/.
//
// POURQUOI UN FICHIER SEPARE. lancer-banc.py concatene le preambule, puis les sources, puis le
// banc. Or api/cron-minuit.js lit sa cle au CHARGEMENT :
//     const SUPABASE_SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE_KEY || null;
// Un banc qui poserait la variable depuis son propre corps arriverait trop tard : la constante
// est deja figee a null, et toutes les passes a identite serveur se rabattent alors sur leur
// repli fail-closed sans envoyer une seule requete.
//
// Ce decor doit donc etre la PREMIERE source de la ligne SOURCES: du banc.
//
// NE PAS CONFONDRE AVEC UNE SOURCE DU JEU : ce fichier ne part jamais en production, il
// n'appartient a aucun module, et sa seule raison d'etre est de rendre observable le chemin
// NOMINAL. Le chemin fail-closed, lui, s'eprouve en RETIRANT ce decor -- voir l'en-tete du
// banc concerne, qui le fait explicitement.
process.env.SUPABASE_URL = 'https://zz-banc.supabase.co';
process.env.SUPABASE_ANON_KEY = 'zz-cle-anon-de-banc';
process.env.SUPABASE_SERVICE_ROLE_KEY = 'zz-cle-service-de-banc';
