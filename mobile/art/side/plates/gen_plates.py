"""逐幅调用本机 Codex 的 image_generation 出长卷底图。

python gen_plates.py prompts.json <幅目录> <地域,地域,...> <起始幅> <结束幅> [并行数]

出完再跑 tests/_stitch_plates.gd 把 <幅目录> 拼成长卷。

Codex 只负责出图：read-only 沙箱、不跑命令、不碰文件。它自己会把图存进
~/.codex/generated_images/<thread_id>/，我们按这次运行的 thread_id 去取，再拷成 <region>-<n>.png。
第 1 幅从零画，第 2 幅起把前一幅当参考图续画。同一地域内串行，不同地域之间并行。
"""
import json
import os
import re
import shutil
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

# Codex 可执行文件：先看环境变量 CODEX_EXE，再找 PATH 上的 codex。桌面版 Codex 的 codex.exe 在
# %LOCALAPPDATA%/OpenAI/Codex/bin/<一串哈希>/ 下，不在 PATH 上，需要用 CODEX_EXE 指过去。
CODEX = os.environ.get("CODEX_EXE") or shutil.which("codex") or "codex"
GENERATED = Path.home() / ".codex" / "generated_images"
WRAP = ("Use your built-in image generation tool to generate exactly ONE image. Do not run any shell commands, "
        "do not create or edit any files, and do not generate more than one image. When the image is done, "
        "reply with the single word: done.\n\nImage prompt:\n{prompt}")


def panel_prompt(spec, region, index):
    r = spec["地域"][region]
    parts = [spec["画风"], r["调"], r["幅"][index], spec["几何"]]
    if index > 0:
        parts.append(spec["续画"])
    return "\n\n".join(parts)


def generate(spec, out_root, region, index, log):
    folder = out_root / region
    folder.mkdir(parents=True, exist_ok=True)
    target = folder / f"{region}-{index + 1}.png"
    cmd = [str(CODEX), "exec", "--skip-git-repo-check", "-s", "read-only", "-C", str(folder),
           "--json", "-o", str(folder / f"last-{index + 1}.txt")]
    if index > 0:
        cmd += ["-i", str(folder / f"{region}-{index}.png")]
    cmd += ["--", WRAP.format(prompt=panel_prompt(spec, region, index))]
    for attempt in range(1, 3):
        start = time.time()
        events_path = folder / f"events-{index + 1}.jsonl"
        with open(events_path, "w", encoding="utf-8") as events, \
                open(folder / f"stderr-{index + 1}.txt", "w", encoding="utf-8") as err:
            code = subprocess.run(cmd, stdin=subprocess.DEVNULL, stdout=events, stderr=err, timeout=900).returncode
        took = time.time() - start
        thread = re.search(r'"thread_id":"([^"]+)"', events_path.read_text(encoding="utf-8", errors="ignore"))
        made = sorted((GENERATED / thread.group(1)).glob("*.png"), key=lambda f: f.stat().st_mtime) if thread else []
        if made:
            shutil.copyfile(made[-1], target)
            log(f"{region} #{index + 1}  ok  {took:.0f}s  try {attempt}  <- {made[-1].parent.name}")
            return True
        log(f"{region} #{index + 1}  NO IMAGE  exit {code}  {took:.0f}s  try {attempt}")
    return False


def run_region(spec, out_root, region, first, last, log):
    for index in range(first - 1, last):
        if index > 0 and not (out_root / region / f"{region}-{index}.png").exists():
            log(f"{region} #{index + 1}  skipped: previous panel missing")
            return
        if not generate(spec, out_root, region, index, log):
            return


def main():
    spec = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    out_root = Path(sys.argv[2])
    regions = sys.argv[3].split(",")
    first, last = int(sys.argv[4]), int(sys.argv[5])
    workers = int(sys.argv[6]) if len(sys.argv) > 6 else 3
    out_root.mkdir(parents=True, exist_ok=True)

    def log(message):
        line = time.strftime("%H:%M:%S ") + message
        print(line, flush=True)
        with open(out_root / "gen.log", "a", encoding="utf-8") as f:
            f.write(line + "\n")

    with ThreadPoolExecutor(max_workers=workers) as pool:
        for region in regions:
            pool.submit(run_region, spec, out_root, region, first, last, log)


if __name__ == "__main__":
    main()
