#!/usr/bin/env python3
PATH = "plateau-pnj.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  // Quete d'accueil : reponse d'accueil scriptee de Jeremy a la toute premiere ouverture de sa"""

new = """  // Enigme du portrait disparu : temoignages scriptes des 3 pensionnaires de l'EHPAD.
  // Ne se declenchent que si l'enigme est active (evite un texte hors-sujet sinon).
  const nomCourtEhpad = (pnj.name || '').replace(' (PNJ)', '').trim();
  if (typeof enigme1EtapeActive === 'function' && enigme1EtapeActive()) {
    if (nomCourtEhpad === 'Jeanine Dubois') {
      speech.textContent = "Ah, mes années à l'école... j'en ai vu passer, des enfants ! Thibault... Thibault... Attendez, laissez-moi réfléchir. Oui ! Une petite fille très sage, toujours au premier rang, qui écrivait d'une belle main. Élise, je crois bien qu'elle s'appelait.\\nSes parents étaient agriculteurs. Il y a eu un drame dans la famille, et la petite Élise a dû partir travailler dans une maison. Pauvre gamine.\\nMais si vous cherchez des informations sur elle, pourquoi vous n'allez pas consulter l'état-civil à la mairie ? Ils ont tout là-bas.";
      if (typeof enigme1DossierCocherCase === 'function') enigme1DossierCocherCase('ehpad_dubois');
      return;
    }
    if (nomCourtEhpad === 'Louis Chevillard') {
      speech.textContent = "Caillon... oh que oui ce nom me dit quelque chose, forcément, j'ai fait trente ans dans la police. Une drôle d'affaire, à l'époque, l'assassinat d'un conseiller municipal, je me souviens qu'on en parlait beaucoup au commissariat. Un crime à Luthécia, c'est pas si courant quand même.\\nOn l'a arrêté, ça j'en suis sûr, et puis... remis en liberté plus tard, je crois. Un acquittement, je ne sais plus exactement. Pourtant, c'était une vraie crapule ce type. Il était impliqué dans toute sorte de trafics. À la fin, il avait été embauché comme gardien sur l'usine de Moulin. On n'a jamais trop cru au fait qu'il s'était rangé des affaires...\\nÀ mon âge, la mémoire flanche un peu, mais le commissariat, lui, n'oublie jamais rien. Le dossier doit toujours être dans les archives.";
      if (typeof enigme1DossierCocherCase === 'function') enigme1DossierCocherCase('ehpad_chevillard');
      return;
    }
    if (nomCourtEhpad === 'Noël Chauchay') {
      speech.textContent = "Thibault ? Ah oui, le père Thibault ! Bien sûr que je m'en souviens, on se croisait tout le temps au marché, avant. Une belle terre qu'il avait, avec des patates comme j'en ai jamais revu depuis — le meilleur producteur du coin à l'époque, croyez-moi.\\nEt puis... un jour, plus rien. On lui a pris sa terre. Fini les patates, fini le marché, on ne l'a plus revu du tout jusqu'à ce qu'on apprenne qu'il s'était pendu dans sa grange.\\nQuel malheur, cet homme-là. On disait des choses, à l'époque, mais on ne devrait peut-être pas trop répéter les ragots d'un vieux comme moi.";
      if (typeof enigme1DossierCocherCase === 'function') enigme1DossierCocherCase('ehpad_chauchay');
      return;
    }
  }

  // Quete d'accueil : reponse d'accueil scriptee de Jeremy a la toute premiere ouverture de sa"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Témoignages scriptés des 3 pensionnaires de l'EHPAD ajoutés.")
