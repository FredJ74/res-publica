-- Commentaires d'objets
-- ============================================================================
-- BASELINE Human Gambit -- domaine socle -- phase 80 : commentaires
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

COMMENT ON FUNCTION public.acte_nocturne_revendiquer(text,text,text,jsonb) IS 'Revendique l''acte (pays, mecanisme, sujet, jour courant) : true s''il est ACQUIS, false s''il
etait deja pris aujourd''hui. LEVE si l''identite est incomplete ou le mecanisme non declare --
un refus metier et une erreur ne se disent pas de la meme facon.
PAS APPELABLE DEPUIS LE RESEAU, et c''est l''essentiel de l''architecture : EXECUTE retire a
anon, authenticated ET service_role. Seules les fonctions SECURITY DEFINER du serveur la
joignent, donc il est IMPOSSIBLE de revendiquer une journee hors de la transaction qui porte
l''effet.';
COMMENT ON FUNCTION public.acteur_identifie() IS 'Vrai si l''appel vient du serveur, ou d''un compte qui porte un personnage. Socle des policies d''ecriture du chantier 3 : ecrire dans le monde exige d''etre un acteur du monde. Ne dit RIEN du poste ni de la presence -- ces questions ont leurs propres briques (mon_poste_est_dans, acteur_present_sur_site).';
COMMENT ON FUNCTION public.acteur_present_sur_site(text,text,text,text,text) IS 'Presence physique d''un personnage sur un site du jeu, d''apres la position faisant autorite (personnages_donnees). Exige pays + ville + batiment ; la piece n''est comparee que si le site en declare une, ce qui couvre les commerces occupant un batiment entier. Ferme par defaut : un site sans lieu complet ne permet aucune presence. Regle de localisation UNIQUE du jeu -- fonds_acteur_present la relaie.';
COMMENT ON FUNCTION public.admin_incarner(text,text,text,jsonb) IS 'Porte unique de l''incarnation administrative. N''ecrit rien dans le judiciaire : elle appelle la fonction metier du titulaire, gardes intactes, et consigne a l''audit prive.';
COMMENT ON FUNCTION public.admin_moi() IS 'Ce que le panneau a le droit de savoir : suis-je administrateur, et ai-je MOI-MEME une invitation a consommer. Ne publie jamais l''etat de l''administration a un compte qui n''est pas concerne.';
COMMENT ON FUNCTION public.admin_pnj_titulaire(text,text,text) IS 'Nom du PNJ titulaire du poste, ou NULL si un PJ le porte. Seule definition de la titularite PNJ.';
COMMENT ON FUNCTION public.est_administrateur() IS 'Vrai si le compte authentifie porte une autorite administrateur active. Seule definition de cette autorite.';
COMMENT ON FUNCTION public.generique_de_objet(jsonb) IS 'Resolveur de referentiel. Lecture seule, aucun effet de bord. Honore d''abord une designation directe (generique_id pose par le serveur), puis les correspondances legacy par priorite. Rend 0 ligne lorsque aucun generique ne peut etre determine : un objet non resoluble doit rendre NULL, jamais une valeur devinee.';
COMMENT ON FUNCTION public.generique_recettes_systeme(text) IS 'Formes de fabrication qu''un joueur peut choisir pour une reference PJ. Rend le libelle de FORME (label_forme) quand il existe, sinon le libelle historique. Des qu''une recette du generique declare une forme, seules les recettes qui en declarent une sont proposees : plusieurs recettes historiques de meme fabrication ne produisent donc plus plusieurs choix identiques. Le moteur legacy ne lit jamais cette fonction et voit toujours les 9 cartes postales.';
COMMENT ON FUNCTION public.jsonb_ou_null(text) IS 'Cast tolerant texte -> jsonb : rend NULL au lieu de lever si le texte n''est pas du JSON. Pour lire un blob ecrit par un navigateur sans qu''une seule ligne malformee fasse tomber toute une mecanique.';
COMMENT ON FUNCTION public.objet_fiche_officielle(jsonb) IS 'Partie OFFICIELLE de la fiche d''un objet. Lecture seule. N''expose jamais les notes d''audit, les sources de code ni le motif de resolution. Rend {"resolu": false} pour un objet hors catalogue : aucun generique de repli n''est jamais attribue.';
