#!/usr/bin/env python3
"""Fix misassigned Starovka office images; convert one uploaded PNG.
Image assignment verified against Fred's report:
 old open_space => grand bureau
 old grand bureau => petit bureau
 old petit bureau => four-desk open-space overview
 newly uploaded PNG => one rentable workstation in open space.
"""
from pathlib import Path
from PIL import Image,ImageOps
import unicodedata
root=Path("images/Sovarka/Starovka")
n=lambda name:unicodedata.normalize("NFC",name)
files={n(p.name):p for p in root.iterdir() if p.is_file()}
source_name="Bureau vintage face aux montagnes enneigées.png"
source=files.get(n(source_name))
assert source and source.exists(), f"New PNG not found: {source_name}"
paths={k:root/("Starovka_centre_affaires_"+k+".webp") for k in ("grand_bureau","petit_bureau","open_space")}
assert all(p.exists() for p in paths.values()),paths
post=root/"Starovka_centre_affaires_poste.webp"
assert not post.exists(),f"Unexpected target existing: {post}"
with Image.open(source) as im:
 assert im.width>=900 and im.height>=650, f"New source dimensions: {im.size}"
 im=ImageOps.fit(im.convert("RGB"),(1448,1086),method=Image.Resampling.LANCZOS,centering=(.5,.5))
 im.save(post,"WEBP",quality=85,method=6)
with Image.open(post) as im:
 assert im.format=="WEBP" and im.size==(1448,1086)
# Rotate existing approved images (bytes unchanged), no data loss.
original={k:p.read_bytes() for k,p in paths.items()}
for k,blob in original.items():
 with Image.open(paths[k]) as im:
  assert im.format=="WEBP" and im.size==(1448,1086), (k,im.size)
paths["grand_bureau"].write_bytes(original["open_space"])
paths["petit_bureau"].write_bytes(original["grand_bureau"])
paths["open_space"].write_bytes(original["petit_bureau"])
source.unlink()
assert not source.exists()
assert paths["grand_bureau"].read_bytes()==original["open_space"]
assert paths["petit_bureau"].read_bytes()==original["grand_bureau"]
assert paths["open_space"].read_bytes()==original["petit_bureau"]
for p in [*paths.values(),post]:
 with Image.open(p) as im:
  assert im.format=="WEBP" and im.size==(1448,1086)
print("OK: PNG deleted, individual workstation WebP 1448x1086, three historical images reassigned without altering their bytes")
