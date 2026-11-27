#!/bin/zsh
# 皮影小样出图：用 ChatGPT 桌面版自带的 codex，按 <角色>/prompts.json 出拆件图，存到 <角色>/source/<种类>-<序号>.png。
#
#   prototype/cutout/gen.sh hero parts            # 出 N 张光身拆件图备选（默认 3 张）
#   prototype/cutout/gen.sh hero armor-leather    # 在选定的 source/parts.png 上加护甲
#
# 拆件图里每个部件分开摆、互不相碰，之后由 cut.py 按连通块切开。

set -u
HERE=${0:A:h}
CODEX=${CODEX:-/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex}
WHO=$HERE/$1
KIND=$2
OUT=$WHO/source
WORK=${TMPDIR:-/tmp}/gen-cutout/$1
N=${N:-3}
mkdir -p $OUT $WORK

field() { python3 -c "import json,sys;d=json.load(open('$WHO/prompts.json'));print(d[sys.argv[1]]['ref'] if sys.argv[2]=='ref' else d[sys.argv[1]]['prompt']+'\n'+d['style'])" $KIND $1; }
REF=$WHO/$(field ref)
PROMPT=$(field prompt)

one() {
  local out=$1
  local dir=$WORK/$out
  rm -rf $dir && mkdir -p $dir
  $CODEX exec --skip-git-repo-check -C $dir -s workspace-write -c model_reasoning_effort='"low"' -i $REF -- \
    "Use your built-in image generation tool to create exactly one image from the prompt below (landscape 1536x1024). The attached image is the reference the prompt talks about; pass it to the image tool as a reference image. Then copy the resulting PNG file into the current working directory as $out.png. Do not do anything else and do not edit any other files.

PROMPT:
$PROMPT" < /dev/null > $dir/codex.log 2>&1
  if [[ -f $dir/$out.png ]]; then mv $dir/$out.png $OUT/$out.png && echo "已出图 $out"; else echo "失败 $out（日志 $dir/codex.log）"; fi
}

for i in $(seq $N); do one $KIND-$i & done
wait
