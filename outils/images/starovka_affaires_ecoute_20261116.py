from pathlib import Path
from PIL import Image,ImageOps
import unicodedata
root=Path("images/Sovarka/Starovka")
names={
"Accueil du centre d’affaires soviétique.png":"Starovka_centre_affaires_accueil.webp",
"Bureau d’affaires soviétique sous la neige.png":"Starovka_centre_affaires_petit_bureau.webp",
"Bureau soviétique sous la neige.png":"Starovka_centre_affaires_grand_bureau.webp",
"Bureau rétro au sol carrelé.png":"Starovka_centre_affaires_open_space.webp",
"Poste d’écoute soviétique en hiver.png":"Starovka_centre_ecoute_salle.webp"}
existing={unicodedata.normalize("NFC",p.name):p for p in root.glob("*.png")}
assert len(existing)==5,existing.keys()
for name,out in names.items():
 p=existing[unicodedata.normalize("NFC",name)]
 assert not (root/out).exists(),out
 with Image.open(p) as im:
  im=ImageOps.fit(im.convert("RGB"),(1448,1086),method=Image.Resampling.LANCZOS)
  im.save(root/out,"WEBP",quality=85,method=6)
 with Image.open(root/out) as im:
  assert im.format=="WEBP" and im.size==(1448,1086)
 p.unlink()
print("Cinq conversions WebP OK")
p=Path("data.js");s=p.read_text()
anchor='''      buildingContext: {
        'centre-multinodal-montrouge': {
          name: "Gare de Starovka",'''
assert s.count(anchor)==1
replacement='''      buildingContext: {
        // Starovka uniquement. Quatre postes, deux bureaux et un accueil.
        'centre-affaires': {
          name: "Centre d'affaires de Starovka",
          roomOverrides: {
            hall: {
              name: "Accueil",
              imageUrl: "images/Sovarka/Starovka/Starovka_centre_affaires_accueil.webp",
              persons: [{ name: "Secrétaire du centre d'affaires de Starovka (PNJ)",
                role: "Secrétaire d'accueil", rel:"neutral", job:"hotesse",
                photoUrl:"images/Sovarka/Starovka/Starovka_centre_affaires_accueil.webp", photoPos:"35% 46%" }]
            },
            bureau_prestige: { name:"Grand bureau — Local à louer",
              imageUrl:"images/Sovarka/Starovka/Starovka_centre_affaires_grand_bureau.webp" },
            bureau_standard: { name:"Petit bureau — Local à louer",
              imageUrl:"images/Sovarka/Starovka/Starovka_centre_affaires_petit_bureau.webp" },
            open_space: { name:"Open Space", imageUrl:"images/Sovarka/Starovka/Starovka_centre_affaires_open_space.webp",
              desc:"Quatre postes de travail individuels face au centre d'écoute militaire.",
              excludeOrders:['commerce_pj','louer_local','gerer_local','installer_equipements'] }
          },
          roomsExtra: Object.fromEntries(Object.entries(bureauxOpenSpaceCentreAffaires()).map(([id,room])=>[id,{
            ...room, imageUrl:"images/Sovarka/Starovka/Starovka_centre_affaires_open_space.webp",
            sortieVers:{buildingId:'centre-affaires',roomId:'open_space',city:'ville_a'},
            orders:(room.orders||[]).map(o=>({...o,label:typeof o.label==='string'?o.label.replace(' FR/jour',' PSK/jour'):o.label}))
          }])),
          roomsExclues:['tribune_republia'],
          roomsMasquees:['open_space_a','open_space_b','open_space_c','open_space_d']
        },
        'centre-multinodal-montrouge': {
          name: "Gare de Starovka",'''
s=s.replace(anchor,replacement)
anchor2="  centre('station-radar-krasnov', 'Station radar de Krasnov'"
assert s.count(anchor2)==1
s=s.replace(anchor2,"  BUILDINGS['poste-vigilance-glaciale'].rooms.salle_ecoute.imageUrl = 'images/Sovarka/Starovka/Starovka_centre_ecoute_salle.webp';\n  BUILDINGS['poste-vigilance-glaciale'].imagesAVenir = false;\n"+anchor2)
p.write_text(s)
p=Path("RELAIS.md");s=p.read_text();assert s.count("## En cours\n")==1
s=s.replace("## En cours\n","## En cours\n### Centre d'affaires / écoute Starovka — ChatGPT, 16/11\nBranche chatgpt/starovka-affaires-ecoute-20261116 : cinq WebP 1448×1086, PNG retirés ; accueil, deux bureaux, quatre postes et salle d'écoute raccordés. Ordres et prix hérités inchangés ; recette PJ connecté à faire.\n\n")
p.write_text(s)
