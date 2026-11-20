#!/bin/zsh
# 用 ChatGPT 桌面版自带的 codex（走 ChatGPT 登录，不用 API key）按 parts-prompts.json 给兵器零件出原画，
# 存到 source/parts/<零件名>.png，之后跑 pack_parts.py 就顶替脚本画的同名零件。
#
#   art/side/gen_parts.sh                 # 在 mobile 目录下运行：还没有原画的零件都出一张
#   art/side/gen_parts.sh liuye guitou    # 只出这几件（已有的会被覆盖）
#
# 每件大约一分钟，四件一起跑。标了 skip 的零件（比如要按五行发光的宝珠）不出。

set -u
HERE=${0:A:h}
CODEX=${CODEX:-/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex}
OUT=$HERE/source/parts
WORK=${TMPDIR:-/tmp}/gen-parts
mkdir -p $OUT $WORK

if (( $# )); then
  names=($@)
else
  names=($(python3 -c "
import json, os
d = json.load(open('$HERE/parts-prompts.json'))
print(' '.join(k[6:-4] for k, v in d['assets'].items()
    if 'skip' not in v and not os.path.exists('$OUT/' + k[6:]) ))"))
fi

one() {
  local name=$1
  local prompt=$(python3 -c "import json,sys;print(json.load(open('$HERE/parts-prompts.json'))['assets']['parts/'+sys.argv[1]+'.png']['prompt'])" $name)
  local dir=$WORK/$name
  rm -rf $dir && mkdir -p $dir
  $CODEX exec --skip-git-repo-check -C $dir -s workspace-write -c model_reasoning_effort='"low"' \
    "Use your built-in image generation tool to create exactly one image from the prompt below (transparent background, portrait 1024x1536). Then copy the resulting PNG file into the current working directory as $name.png. Do not do anything else and do not edit any other files.

PROMPT:
$prompt" > $dir/codex.log 2>&1
  if [[ -f $dir/$name.png ]]; then
    mv $dir/$name.png $OUT/$name.png && echo "已出图 $name"
  else
    echo "失败 $name（日志 $dir/codex.log）"
  fi
}

for name in $names; do
  one $name &
  while (( $(jobs -r | wc -l) >= 4 )); do sleep 2; done
done
wait
