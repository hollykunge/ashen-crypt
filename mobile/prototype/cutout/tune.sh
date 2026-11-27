#!/bin/zsh
# 打开皮影调参面板：prototype/cutout/tune.sh [角色]，角色默认 piying
HERE=${0:A:h}
GODOT=${GODOT:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}
exec $GODOT --path $HERE/../.. res://prototype/cutout/tuner.tscn -- ${1:-piying}
