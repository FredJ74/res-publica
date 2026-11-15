#!/usr/bin/env python3
"""Installe les deux illustrations fournies pour les commerces de Starovka."""
from pathlib import Path
from PIL import Image, ImageOps
ROOT=Path(__file__).resolve().parents[2]
FOLDER=ROOT/'images/Sovarka/Starovka'
# Les fichiers déposés correspondent à l'ordre de génération : restaurant puis fourreur.
FILES={
    'Image ChatGPT 15 nov. 2026, 23_59_32-1.png':'Starovka_restaurant_entre_terre_mer_salle_principale.webp',
    'Image ChatGPT 15 nov. 2026, 23_59_33-2.png':'Starovka_fourreur_boutique_fourreur.webp',
}
for old,new in FILES.items():
    source=FOLDER/old; target=FOLDER/new
    if source.exists():
        with Image.open(source) as image:
            assert image.format=='PNG',source
            rgb=ImageOps.exif_transpose(image).convert('RGB')
            dims=rgb.size
            rgb.save(target,'WEBP',quality=85,method=6)
        with Image.open(target) as check:
            assert check.format=='WEBP' and check.size==dims
        contents=target.read_bytes()
        assert contents[:4]==b'RIFF' and contents[8:12]==b'WEBP'
        assert len(contents)<source.stat().st_size
        source.unlink()
        print(old,'=>',new,len(contents),'bytes')
    elif target.exists():
        contents=target.read_bytes()
        assert contents[:4]==b'RIFF' and contents[8:12]==b'WEBP'
    else:
        raise RuntimeError('Image non trouvée : '+old)

path=ROOT/'data.js'
data=path.read_text(encoding='utf-8')
anchor="  Object.assign(piece(contexte('ville_a', 'capitaine-sauvage'), 'salle_principale'), { persons: [pnj('Sesegma Badmaeva', 'Serveuse', 'serveur')] });"
if 'STAROVKA_COMMERCES_DEUX_WEBP_20261116' not in data:
    assert data.count(anchor)==1,'Ancrage salle restaurant introuvable'
    data=data.replace(anchor,anchor+"""
  // STAROVKA_COMMERCES_DEUX_WEBP_20261116 — les seules images des commerces de Starovka.
  Object.assign(piece(contexte('ville_a', 'capitaine-sauvage'), 'salle_principale'), {
    imageUrl: 'images/Sovarka/Starovka/Starovka_restaurant_entre_terre_mer_salle_principale.webp'
  });
""")
    anchor2="  local('fourreur-starovka', 'Fourreur « La Fourrure chaude »', 'Fourreur', 'ti-hanger',"
    assert data.count(anchor2)==1,'Ancrage fourreur introuvable'
    anchor3="  const cite = v => WORLD.soviet && WORLD.soviet[v];"
    pos=data.index(anchor3,data.index(anchor2))
    data=data[:pos]+"""  // Décor de la boutique du fourreur de Starovka, sans changer sa mécanique.
  const fourreurStarovka = BUILDINGS['fourreur-starovka'];
  if (!fourreurStarovka?.rooms?.boutique_fourreur) throw new Error('Salle fourreur de Starovka absente');
  fourreurStarovka.imagesAVenir = false;
  fourreurStarovka.rooms.boutique_fourreur.imageUrl = 'images/Sovarka/Starovka/Starovka_fourreur_boutique_fourreur.webp';

"""+data[pos:]
    path.write_text(data,encoding='utf8')
for target in FILES.values():
    assert (FOLDER/target).is_file()
print('Deux WebP validés, deux PNG supprimés, deux commerces raccordés.')
