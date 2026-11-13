#!/usr/bin/env bash
# KayKit (Kay Lousberg, www.kaylousberg.com) bepul CC0 3D modellarini yuklab olib,
# o'yinga kerakli fayllarni assets/kaykit/ papkasiga ko'chiradi. GitHub Actions'da avtomatik ishlaydi.
# Litsenziya: CC0 — shaxsiy va tijoriy loyihalarda bepul.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$PROJECT_DIR/assets/kaykit"
TMP="${RUNNER_TEMP:-/tmp}/kaykit_src"
mkdir -p "$TMP" "$DEST/characters" "$DEST/medieval"

clone() {
  if [ ! -d "$TMP/$1" ]; then
    git clone --depth 1 "https://github.com/KayKit-Game-Assets/$1" "$TMP/$1"
  fi
}
clone KayKit-Character-Pack-Adventures-1.0
clone KayKit-Character-Pack-Skeletons-1.0
clone KayKit-Medieval-Hexagon-Pack-1.0
clone KayKit-Halloween-Bits-1.0

ADV="$TMP/KayKit-Character-Pack-Adventures-1.0/addons/kaykit_character_pack_adventures/Characters/gltf"
SKEL="$TMP/KayKit-Character-Pack-Skeletons-1.0/addons/kaykit_character_pack_skeletons/Characters/gltf"
HEX="$TMP/KayKit-Medieval-Hexagon-Pack-1.0/addons/kaykit_medieval_hexagon_pack/Assets/gltf"

for f in Knight Rogue Rogue_Hooded Barbarian Mage; do cp "$ADV/$f.glb" "$DEST/characters/"; done
for f in Skeleton_Warrior Skeleton_Mage Skeleton_Minion Skeleton_Rogue; do cp "$SKEL/$f.glb" "$DEST/characters/"; done

copy_gltf() {  # $1 = papka, $2 = nom
  cp "$HEX/$1/$2.gltf" "$HEX/$1/$2.bin" "$DEST/medieval/"
}
for b in castle home_A home_B barracks archeryrange tower_A tower_B mine tavern blacksmith church lumbermill watermill market tower_catapult windmill well; do copy_gltf buildings/blue "building_${b}_blue"; done
for b in mine barracks tower_catapult castle archeryrange windmill lumbermill tower_A tower_B well home_B tavern blacksmith church market; do copy_gltf buildings/green "building_${b}_green"; done
for b in mine barracks tower_catapult castle tavern blacksmith tower_B home_B; do copy_gltf buildings/red "building_${b}_red"; done
for b in mine market tavern; do copy_gltf buildings/yellow "building_${b}_yellow"; done
for n in building_scaffolding building_destroyed projectile_catapult wall_straight; do copy_gltf buildings/neutral "$n"; done
for n in tree_single_A tree_single_B trees_A_small trees_B_small rock_single_A rock_single_B rock_single_C mountain_A mountain_B mountain_C mountain_A_grass_trees hill_single_A; do copy_gltf decoration/nature "$n"; done
for n in tent barrel crate_A_big resource_lumber flag_blue flag_green target weaponrack; do copy_gltf decoration/props "$n"; done
cp "$HEX/buildings/blue/hexagons_medieval.png" "$DEST/medieval/"

# Halloween to'plami (Yalmog'iz va Kashsheylar saltanati uchun)
HAL="$TMP/KayKit-Halloween-Bits-1.0/addons/kaykit_halloween_bits/Assets/gltf"
mkdir -p "$DEST/halloween"
for n in crypt shrine shrine_candles coffin_decorated grave_A gravestone pillar arch_gate tree_dead_large tree_dead_large_decorated tree_dead_medium post_lantern lantern_standing skull ribcage tree_pine_yellow_large tree_pine_orange_large; do
  cp "$HAL/$n.gltf" "$HAL/$n.bin" "$DEST/halloween/"
done
cp "$HAL/halloweenbits_texture.png" "$DEST/halloween/"
cp "$TMP/KayKit-Character-Pack-Adventures-1.0/LICENSE.txt" "$DEST/LICENSE_KayKit.txt"

echo "KayKit modellari tayyor:"
du -sh "$DEST"
ls "$DEST/characters" "$DEST/medieval" | head -80
