#!/bin/zsh
# 把演示渲成 mp4 和 gif：prototype/cutout/render.sh <角色> <输出目录>
set -eu
HERE=${0:A:h}
WHO=$1
OUT=${2:A}
GODOT=${GODOT:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}
rm -rf $OUT/frames && mkdir -p $OUT/frames
$GODOT --path $HERE/../.. --fixed-fps 30 res://prototype/cutout/demo.tscn -- $WHO $OUT/frames > $OUT/godot.log 2>&1
ffmpeg -y -loglevel error -framerate 30 -pattern_type glob -i "$OUT/frames/*.png" -c:v libx264 -pix_fmt yuv420p -crf 18 $OUT/$WHO.mp4
ffmpeg -y -loglevel error -framerate 30 -pattern_type glob -i "$OUT/frames/*.png" \
  -vf "fps=20,scale=960:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" $OUT/$WHO.gif
echo "$(ls $OUT/frames | wc -l | tr -d ' ') 帧 → $OUT/$WHO.mp4, $OUT/$WHO.gif"
