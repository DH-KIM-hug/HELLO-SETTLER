"""docs/ART_PROMPTS.md 에서 프롬프트를 뽑아 design/concept/prompts.json 으로 만든다 (Codex 등 에이전트가 순서대로 생성하기 위한 목록)."""
import json, os, re
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
md = open(os.path.join(root, "docs", "ART_PROMPTS.md"), encoding="utf-8").read()
blocks = re.findall(r"```\n(.*?)\n```", md, re.S)
style, negative = blocks[0].replace("\n", " ").strip(), blocks[1].replace("\n", " ").strip()
items = []
def ratio(p):
    m = re.search(r"(\d+:\d+)\s*$", p.strip()); return m.group(1) if m else "16:9"
def strip_ratio(p): return re.sub(r",?\s*\d+:\d+\s*$", "", p.strip())
# ### 1-1. 제목 + 설명 + 코드블록
for m in re.finditer(r"### (\d+-\d+)\. ([^\n]+)\n\*([^\n]+)\*\n```\n(.*?)\n```", md, re.S):
    pid, title, desc, prompt = m.groups(); prompt = prompt.replace("\n", " ")
    items.append({"id": pid, "title": title.strip(), "desc": desc.strip(), "prompt": strip_ratio(prompt), "aspect": ratio(prompt)})
# 표: | 2-1 | **제목** — 설명 | `prompt` |
for m in re.finditer(r"^\| (\d+-\d+) \| (.+?) \| `(.+?)` \|$", md, re.M):
    pid, title, prompt = m.groups()
    t = re.sub(r"\*\*", "", title); name, _, desc = t.partition(" — ")
    items.append({"id": pid, "title": name.strip(), "desc": desc.strip(), "prompt": strip_ratio(prompt), "aspect": ratio(prompt)})
# 5장 건물 시트 (제목 없는 코드블록 두 개)
sec5 = md[md.index("## 5. 건물"):md.index("## 6.")]
b5 = re.findall(r"```\n(.*?)\n```", sec5, re.S)
for i, (t, p) in enumerate(zip(["건물 세트 (개척기·마을)", "기후별 건축 양식"], b5), 1):
    p = p.replace("\n", " "); items.append({"id": f"5-{i}", "title": t, "desc": "", "prompt": strip_ratio(p), "aspect": ratio(p)})
def key(it): a, b = it["id"].split("-"); return (int(a), int(b))
items.sort(key=key)
slug = lambda s: re.sub(r"[^0-9a-z]+", "-", s.lower()).strip("-")
for it in items:
    it["file"] = f"design/concept/{it['id']}.png"
    it["full_prompt"] = f"{style}, {it['prompt']}"
out = {"style": style, "negative": negative, "count": len(items), "items": items}
path = os.path.join(root, "design", "concept", "prompts.json")
json.dump(out, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(len(items), "prompts ->", path)
