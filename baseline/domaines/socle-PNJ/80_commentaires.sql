-- Commentaires d'objets
-- ============================================================================
-- BASELINE Human Gambit -- domaine socle PNJ -- phase 80 : commentaires
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

COMMENT ON COLUMN public.pnj_employes_metier.escort_id IS 'Identite du catalogue que cet emploi instancie, pour le metier escort. Nul pour les autres metiers. C''est ce qui relie un contrat a une personne, et permet a deux joueurs d''employer la meme sans collision.';
COMMENT ON COLUMN public.pnj_evenements.argent_du_defunt IS 'Liquide que portait le PNJ. En attente d''une mecanique d''argent au sol : inscrit ici pour que rien ne disparaisse sans trace, non credite a quiconque.';
COMMENT ON COLUMN public.pnj_evenements.objets_deposes IS 'Nombre d''objets effectivement deposes au sol a l''endroit de la mort.';
COMMENT ON COLUMN public.pnj_fonctions.metier_beta IS 'true quand un metier Beta porte le meme nom que cette fonction du decor. Ne rend PAS le PNJ du decor recrutable : cf. douanier, fonction Gamma de Prosper Tampon et metier Beta des effectifs.';
COMMENT ON COLUMN public.pnj_fonctions.recrutable IS 'true seulement si un joueur peut recruter un PNJ DU DECOR portant cette fonction. Une seule fonction est dans ce cas : escort. Toutes les autres sont Gamma et ne s''emploient pas.';
COMMENT ON COLUMN public.pnj_membres.car_cha IS 'Charisme — 0 a 100. Valeur de BASE.';
COMMENT ON COLUMN public.pnj_membres.car_dup IS 'Duplicite — 0 a 100. Valeur de BASE.';
COMMENT ON COLUMN public.pnj_membres.car_ent IS 'Entregent — 0 a 100. Valeur de BASE. Remplace l''ancienne colonne `car_for` : FOR ne fait pas partie du referentiel cible et n''existe chez aucun personnage joueur.';
COMMENT ON COLUMN public.pnj_membres.car_int IS 'Intelligence — 0 a 100. Valeur de BASE.';
COMMENT ON COLUMN public.pnj_membres.car_per IS 'Perception — 0 a 100. Valeur de BASE.';
COMMENT ON COLUMN public.pnj_membres.car_vol IS 'Volonte — 0 a 100. Valeur de BASE.';
COMMENT ON COLUMN public.pnj_membres.classe IS 'NATURE du PNJ : alpha (consomme ses PA), beta (employable, 12 PA jamais consommes), gamma (institutionnel, immuable, sans proprietaire). Portee par l''individu, car un meme metier peut exister dans plusieurs classes. NULL = on retombe sur le defaut de la famille.';
COMMENT ON COLUMN public.pnj_membres.famille IS 'FONCTION / METIER / JOB du PNJ -- ce que le monde voit de lui. N''implique AUCUNE classe : cf. Prosper Tampon (fonction douanier, classe gamma) face aux effectifs des Douanes (metier douanier, classe beta).';
COMMENT ON COLUMN public.pnj_membres.proprietaire_institution IS 'Cle OPAQUE de l''institution proprietaire, referencant pnj_institutions. Le socle ne l''interprete jamais.';
COMMENT ON COLUMN public.pnj_membres.proprietaire_perimetre IS 'Cle OPAQUE du perimetre au sein de l''institution, nommee par le metier (une section, une reserve, une ville...). C''est ce qui manquait : sans elle, tout titulaire du poste heritait de tous les PNJ de l''institution.';
COMMENT ON COLUMN public.pnj_metiers_profils.cout_jour IS 'Cout recurrent a la charge du proprietaire. NULL = pas de paye personnelle : soit le metier est gratuit, soit sa paye est institutionnelle (douane, police : cron de minuit sur la caisse).';
COMMENT ON COLUMN public.pnj_possessions.origine IS 'Provenance. ''socle'' : remis par un joueur, cessible a la main. ''blob_accessoires'' : delivre par le magasin militaire, non cessible a la main -- se reprend par l''ordre de section. Le nom est HISTORIQUE (il datait de la phase miroir) ; depuis la bascule de l''axe possessions le 27/09/2026, il ne designe plus une copie du blob mais l''origine reglementaire de l''objet.';
COMMENT ON COLUMN public.pnj_referents.pays IS 'Empire auquel ce referent appartient. Un personnage n''existe QUE dans son empire : Sovarka aura son propre referent economie, qui ne sera pas Marc Hantile. Doit rester aligne avec le champ `pays` de api/_pnj-referents.js -- le banc .scratch/banc_referents_personnalites.py le verifie.';
COMMENT ON COLUMN public.pnj_soldats_metier.compagnie_id IS 'Compagnie militaire du soldat, explicite. Remplace a terme la deduction par convention de nom (pnj_id LIKE compagnie || ''-%''). Donnee METIER : elle n''a pas d''equivalent dans le socle.';
COMMENT ON COLUMN public.pnj_soldats_metier.dernier_bivouac IS 'Miroir de sol->>''dernier_bivouac'' : un bivouac par jour.';
COMMENT ON COLUMN public.pnj_soldats_metier.dernier_ration IS 'Miroir de sol->>''dernier_ration'' : jour Paris de la derniere ration. Gardes anti-rejeu du metier militaire, sans equivalent generique.';
COMMENT ON COLUMN public.pnj_soldats_metier.dernier_sommeil IS 'Miroir de sol->>''dernier_sommeil'' : un DORMIR par jour.';
COMMENT ON COLUMN public.pnj_soldats_metier.mutin IS 'Camp d''un soldat revolte. NULL = loyal, et le camp effectif se lit alors coalesce(mutin, pays de la compagnie) -- convention reprise telle quelle du blob. Donnee purement militaire : elle n''a pas sa place dans pnj_membres.';
COMMENT ON COLUMN public.pnj_soldats_metier.nb_ration IS 'Miroir de sol->>''nb_ration''. NULL avec un marqueur du jour vaut 1 dans la regle metier : ne jamais fusionner ce champ avec son marqueur.';
COMMENT ON CONSTRAINT pnj_propriete_exclusive ON public.pnj_membres IS 'Alpha et Beta appartiennent a un PJ OU a une institution avec son perimetre, jamais aux deux. Gamma n''appartient a personne : ses trois champs de propriete doivent etre vides, et cela exige classe = gamma declaree explicitement sur la ligne.';
COMMENT ON FUNCTION public.pnj_social_contexte(text) IS 'Relation du joueur connecte a un PNJ social, pour injection dans le prompt serveur. Lecture seule, sous le jeton du joueur : un client ne peut ni la fournir ni la falsifier.';
COMMENT ON FUNCTION public.pnj_social_entrer(text) IS 'Note l''arrivee d''un joueur chez un PNJ social et rend le jalon a jouer, deja marque. Sans effet pour un PNJ qui n''a aucune regle de jalon : aucune ligne n''est creee.';
COMMENT ON FUNCTION public.pnj_social_noter(text,text) IS 'Enregistre une conversation reellement engagee avec un PNJ social. Est social un PNJ qui a une regle de jalon OU avec qui ce joueur a deja une relation -- c''est le second cas qui couvre les escorts, dont le lien nait d''une designation. Fait monter la familiarite par paliers bornes ; ne touche JAMAIS la confiance.';
COMMENT ON TABLE public.pnj_axes_autorite IS 'Ou vit la verite, axe par axe et famille par famille, pendant la migration vers le socle. La matrice est renseignee EN ENTIER : une case absente serait une ambiguite, pas un defaut.';
COMMENT ON TABLE public.pnj_familles_classes IS 'Classe PAR DEFAUT d''une famille, et non une verite : pnj_membres.classe la contredit quand l''individu le declare. Sert a ne pas repeter la classe sur chaque ligne du cas courant.';
COMMENT ON TABLE public.pnj_fonctions IS 'Nature des PNJ du decor, fonction par fonction. Ne contient AUCUN PNJ : le decor lui-meme vit dans data.js, qui est le monde commun. Regle par defaut : un PNJ pose dans le decor est GAMMA sauf preuve explicite qu''il releve deja d''Alpha ou de Beta.';
COMMENT ON TABLE public.pnj_institutions IS 'Registre des institutions proprietaires de PNJ. `resolveur` nomme une fonction metier de signature (p_pays text, p_perimetre text) RETURNS text qui rend le nom du PJ detenant actuellement l''autorite sur ce perimetre, ou NULL si personne. Le socle n''interprete ni l''institution ni le perimetre : il delegue. Une institution absente du registre, ou un resolveur rendant NULL, signifie « aucune autorite humaine aujourd''hui » -- etat valide.';
COMMENT ON TABLE public.pnj_metiers_profils IS 'Profils de caracteristiques FIXES par METIER (pas par famille, pas par classe). Source unique : aucun recrutement ne doit plus tirer de caracteristique au hasard.';
COMMENT ON TABLE public.pnj_referents IS 'Liste FERMEE des PNJ referents, cote serveur. Ne porte que des identifiants et un libelle de domaine : la personnalite vit dans api/_pnj-referents.js. Sert a refuser d''ouvrir une memoire pedagogique pour un PNJ qui n''en est pas un.';
COMMENT ON TABLE public.pnj_referents_pedagogie IS 'Memoire PEDAGOGIQUE d''un referent envers un joueur : combien de fois il lui a deja explique des choses. AUCUNE familiarite, AUCUNE confiance, AUCUN jalon -- ces notions appartiennent aux PNJ sociaux, et les melanger effacerait la difference de nature entre les deux. Une ligne par couple ; fermee au client, tout passe par les deux RPC.';
COMMENT ON TABLE public.pnj_referents_sujets_connus IS 'Vocabulaire FERME des sujets qu''un referent peut memoriser. Un sujet absent d''ici est refuse : le serveur ne devine jamais.';
COMMENT ON TABLE public.pnj_social_escort_choisi IS 'La confidente d''un joueur, une seule. `joueur` en cle primaire : la regle « une escort sociale par PJ » est structurelle, pas applicative. Changer de confidente remplace la ligne ; l''ancienne relation, elle, n''est jamais effacee.';
COMMENT ON TABLE public.pnj_social_jalons_regles IS 'Quand un PNJ social joue une intervention automatique. Le serveur decide du QUAND, le client sait le QUOI : seul l''identifiant du jalon remonte, jamais son texte.';
COMMENT ON TABLE public.pnj_social_relations IS 'Relation d''un PNJ social a un joueur : rencontres, conversations, familiarite, confiance, jalons deja joues et souvenirs. Une ligne par couple, aucune memoire partagee. Fermee au client : tout passe par les trois RPC.';
