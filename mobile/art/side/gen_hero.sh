#!/bin/zsh
# 用 ChatGPT 桌面版自带的 codex 按 hero-prompts.json 出人物原画，存到 source/hero/<名>.png。
#
#   art/side/gen_hero.sh                          # 全部出一遍
#   art/side/gen_hero.sh frames-male portrait-female   # 只出这几张（已有的会被覆盖）
#   N=2 art/side/gen_hero.sh frames-female        # 每张出 N 个备选：<名>-1.png、<名>-2.png……
#
# turnaround-* 是正、侧、背、四分之三的四面设定图，只做参考；portrait-* 跑 pack_portraits.py 进游戏；
# frames-* 挑一张拷成 source/frames-<性别>.png，再按 pack_frames.py 的说明重标关节、重出图集。
# 标了 ref 的图会把那张图附给 codex 当画风样板（女角对齐男角的画风）。
# 出图工具有时不给透明底，用之前先看一眼 alpha。

set -u
HERE=${0:A:h}
CODEX=${CODEX:-/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex}
OUT=$HERE/source/hero
WORK=${TMPDIR:-/tmp}/gen-hero
N=${N:-1}
mkdir -p $OUT $WORK

if (( $# )); then names=($@); else
  names=($(python3 -c "import json;print(' '.join(k[:-4] for k in json.load(open('$HERE/hero-prompts.json'))['assets']))"))
fi

one() {
  local name=$1 tag=$2
  local spec=($(python3 -c "import json,sys;print(json.load(open('$HERE/hero-prompts.json'))['assets'][sys.argv[1]+'.png']['size'])" $name))
  local prompt=$(python3 -c "import json,sys;print(json.load(open('$HERE/hero-prompts.json'))['assets'][sys.argv[1]+'.png']['prompt'])" $name)
  local refs=($(python3 -c "import json,sys;r=json.load(open('$HERE/hero-prompts.json'))['assets'][sys.argv[1]+'.png'].get('ref',[]);print(' '.join([r] if isinstance(r,str) else r))" $name))
  local ref=${refs[*]}
  local attach=()
  for r in $refs; do attach+=(-i $HERE/$r); done
  local out=$name$tag
  local dir=$WORK/$out
  rm -rf $dir && mkdir -p $dir
  $CODEX exec --skip-git-repo-check -C $dir -s workspace-write -c model_reasoning_effort='"low"' $attach -- \
    "Use your built-in image generation tool to create exactly one image from the prompt below (${spec[1]} ${spec[2]}).${ref:+ The attached image(s) are the references the prompt talks about; pass them to the image tool as reference images.} Then copy the resulting PNG file into the current working directory as $out.png. Do not do anything else and do not edit any other files.

PROMPT:
$prompt" < /dev/null > $dir/codex.log 2>&1
  if [[ -f $dir/$out.png ]]; then mv $dir/$out.png $OUT/$out.png && echo "已出图 $out"; else echo "失败 $out（日志 $dir/codex.log）"; fi
}

for name in $names; do
  for i in $(seq $N); do
    tag=""; (( N > 1 )) && tag="-$i"
    one $name "$tag" &
    while (( $(jobs -r | wc -l) >= 6 )); do sleep 2; done
  done
done
wait
