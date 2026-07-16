#!/usr/bin/env python3
"""
Validates consistency between:
  - resources/foods/foods.json        (picture field)
  - resources/drawables/drawables.xml (bitmap id)
  - source/DrawableRegistry.mc        (dictionary keys)
  - resources/drawables/brands/*.png  (physical files)

Exit 0 if consistent, exit 1 with details otherwise.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

FOODS_JSON    = os.path.join(ROOT, "resources/foods/foods.json")
DRAWABLES_XML = os.path.join(ROOT, "resources/drawables/drawables.xml")
REGISTRY_MC   = os.path.join(ROOT, "source/DrawableRegistry.mc")
BRANDS_DIR    = os.path.join(ROOT, "resources/drawables/brands")


def load_food_pictures():
    with open(FOODS_JSON) as f:
        foods = json.load(f)
    return {item["picture"] for item in foods if "picture" in item}


def load_xml_brand_ids():
    with open(DRAWABLES_XML) as f:
        xml = f.read()
    # Only brand bitmaps (filename starts with "brands/")
    return set(re.findall(r'<bitmap\s+id="([^"]+)"\s+filename="brands/[^"]+"', xml))


def load_registry_keys():
    with open(REGISTRY_MC) as f:
        mc = f.read()
    return set(re.findall(r'"([^"]+)"\s*=>\s*Rez\.Drawables\.', mc))


def load_png_stems():
    return {
        os.path.splitext(f)[0]
        for f in os.listdir(BRANDS_DIR)
        if f.endswith(".png")
    }


def main():
    pictures = load_food_pictures()
    xml_ids  = load_xml_brand_ids()
    mc_keys  = load_registry_keys()
    pngs     = load_png_stems()

    errors = []

    for p in sorted(pictures):
        if p not in xml_ids:
            errors.append(f"  '{p}' dans foods.json mais absent de drawables.xml")
        if p not in mc_keys:
            errors.append(f"  '{p}' dans foods.json mais absent de DrawableRegistry.mc")
        if p not in pngs:
            errors.append(f"  '{p}' dans foods.json mais PNG manquant dans brands/")

    for p in sorted(xml_ids - pictures):
        errors.append(f"  '{p}' dans drawables.xml mais absent de foods.json")

    for p in sorted(mc_keys - pictures):
        errors.append(f"  '{p}' dans DrawableRegistry.mc mais absent de foods.json")

    for p in sorted(pngs - pictures):
        errors.append(f"  '{p}.png' présent dans brands/ mais absent de foods.json")

    if errors:
        print("ERREUR : incohérence dans le catalogue d'aliments :")
        for e in errors:
            print(e)
        sys.exit(1)

    print(f"OK : {len(pictures)} aliments cohérents entre foods.json, drawables.xml, DrawableRegistry.mc et brands/")
    sys.exit(0)


if __name__ == "__main__":
    main()
