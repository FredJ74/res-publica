#!/usr/bin/env python3
"""Musée Novomirsk : 4 illustrations, deux nouvelles salles, sans toucher à l'énigme serveur."""
from pathlib import Path
from PIL import Image
import unicodedata

ROOT=Path(__file__).resolve().parents[2]
DIR=ROOT/"images/Sovarka/Novomirsk"
def norm(name):
 return "".join(c for c in unicodedata.normalize("NFKD",name.lower()) if not unicodedata.combining(c))
TARGETS={
 "personnalites":"Novomirsk_musee_personnalites_discretes.webp",
 "origines":"Novomirsk_musee_salle_origines.webp",
 "bataille":"Novomirsk_musee_bataille_fleuve.webp",
 "incendie":"Novomirsk_musee_grand_incendie.webp"
}
files={}
for source in DIR.glob("*.png"):
 n=norm(source.stem)
 if not n.startswith("novomirsk"): continue
 key=("personnalites" if "personnalite" in n else
      "origines" if "origines" in n else
      "bataille" if "bataille" in n else
      "incendie" if "incendie" in n else None)
 if key:
  assert key not in files,(key,source)
  files[key]=source
assert set(files)==set(TARGETS),(files,TARGETS)
for key,source in files.items():
 target=DIR/TARGETS[key]
 assert not target.exists(),target
 with Image.open(source) as src:
  src.convert("RGB").save(target,"WEBP",quality=85,method=6)
 with Image.open(target) as check:
  assert check.format=="WEBP" and check.width>=1000 and check.height>=600
 print(source.name,"=>",target.name,target.stat().st_size)
 source.unlink()

file=ROOT/"data.js"
text=file.read_text(encoding="utf-8")
intro="  'musee-novomirsk': {"
begin=text.index(intro,300000)
end=text.index("\n  },",begin)
block=text[begin:end]
orig="      salle_origines: {\n        name: \"Salle des Origines\","
pers="      salle_personnalites_discretes: {\n        name: \"Salle des Personnalités discrètes\","
assert block.count(orig)==1 and block.count(pers)==1
block=block.replace(orig,orig+"\n        imageUrl: \"images/Sovarka/Novomirsk/"+TARGETS["origines"]+"\",")
block=block.replace(pers,pers+"\n        imageUrl: \"images/Sovarka/Novomirsk/"+TARGETS["personnalites"]+"\",")
anchor="      salle_criminels: {"
assert block.count(anchor)==1
new_rooms="""      // Deux épisodes spécifiquement novomirskois, validés par Fred le 12/11.
      // Ilia reste uniquement dans la colonne des PNJ : il n'apparaît pas dans les décors.
      salle_bataille_fleuve: {
        name: "Salle de la Bataille du Fleuve",
        imageUrl: "images/Sovarka/Novomirsk/Novomirsk_musee_bataille_fleuve.webp",
        imageBg: "linear-gradient(135deg,#16120c,#201a10)",
        desc: "En 1742, le prince Mikhaïl Dragounov descendit la Sovarka avec vingt-sept embarcations et près de huit cents hommes pour prendre le port de Novomirsk. Les pêcheurs menés par Piotr Karassov déplacèrent les balises et plantèrent des pieux sous l'eau. Les bateaux ennemis s'échouèrent et se percutèrent ; la ville fut sauvée. « Ils avaient huit cents soldats. Nous avions le fleuve. » Une barque attribuée à Karassov est exposée ; son authenticité est contestée par les historiens, mais pas par ses descendants.",
        persons: [ {name:'Vétéran Ilia Krioukov (PNJ)', role:'PNJ - Guide bénévole du musée', rel:'neutral', job:'guide', photoUrl:'images/Sovarka/Novomirsk/Novo_ilia_medailine_portrait.webp'} ],
        orders: []
      },
      salle_grand_incendie: {
        name: "Salle du Grand Incendie",
        imageUrl: "images/Sovarka/Novomirsk/Novomirsk_musee_grand_incendie.webp",
        imageBg: "linear-gradient(135deg,#1c100c,#24160e)",
        desc: "En 1887, un four oublié dans la boulangerie de Grigori Pirogov déclencha un incendie qui ravagea pendant trois jours le quartier marchand de Novomirsk. Le vent poussa les flammes des maisons en bois aux entrepôts du port. Un tiers de la vieille ville fut détruit. La reconstruction en pierre et en brique transforma la capitale. Casques, pompe à bras, plans et photographies des ruines entourent une miche de pain calcinée, retrouvée dans l'ancienne boulangerie.",
        persons: [ {name:'Vétéran Ilia Krioukov (PNJ)', role:'PNJ - Guide bénévole du musée', rel:'neutral', job:'guide', photoUrl:'images/Sovarka/Novomirsk/Novo_ilia_medailine_portrait.webp'} ],
        orders: []
      },
"""
block=block.replace(anchor,new_rooms+anchor)
text=text[:begin]+block+text[end:]
# La ville de Krasnov réutilise le même socle : exclure explicitement les deux salles supplémentaires.
old="musee.roomsExclues = (musee.roomsExclues || []).concat(['salle_origines', 'salle_personnalites_discretes']);"
new="musee.roomsExclues = (musee.roomsExclues || []).concat(['salle_origines', 'salle_personnalites_discretes', 'salle_bataille_fleuve', 'salle_grand_incendie']);"
assert text.count(old)==1
text=text.replace(old,new)
file.write_text(text,encoding="utf-8")

# Les noms de salles participent au catalogue multilingue existant.
names=ROOT/"i18n/sovarka-pieces-resources.js"
s=names.read_text(encoding="utf-8")
key='  ["Salle des Personnalités discrètes",'
i=s.index(key)
j=s.index("\n",i)
assert 'Salle de la Bataille du Fleuve' not in s
s=s[:j]+""",
  ["Salle de la Bataille du Fleuve", "Battle of the River Hall", "Sala de la Batalla del Río", "河流戰役廳", "Зал битвы на реке", "강 전투 전시실", "قاعة معركة النهر", "Sala da Batalha do Rio", "Saal der Flussschlacht"],
  ["Salle du Grand Incendie", "Great Fire Hall", "Sala del Gran Incendio", "大火災廳", "Зал Великого пожара", "대화재 전시실", "قاعة الحريق الكبير", "Sala do Grande Incêndio", "Saal des großen Brandes"]"""+s[j:]
names.write_text(s,encoding="utf-8")
# Le test d'origine doit tenir compte des deux nouvelles salles.
test=ROOT/"outils/bancs/test-musee-novomirsk-tresor-tsars-20261112.mjs"
s=test.read_text(encoding="utf-8")
old="['hall', 'salle_origines', 'salle_personnalites_discretes']);"
new="['hall', 'salle_origines', 'salle_personnalites_discretes', 'salle_bataille_fleuve', 'salle_grand_incendie']);"
assert s.count(old)==1
s=s.replace(old,new)
test.write_text(s,encoding="utf-8")
print("data.js, catalogue des noms et banc d'origine mis à jour.")
