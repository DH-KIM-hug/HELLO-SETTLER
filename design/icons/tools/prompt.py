import json,sys
d=json.load(open(sys.argv[1])); sid=sys.argv[2]; out=sys.argv[3]
s=[x for x in d["sheets"] if x["id"]==sid][0]
c,r=s["cols"],s["rows"]
lines=[]
for i,it in enumerate(s["items"]):
    rid,ko,desc=it[:3]
    if ko=="-" and False: pass
    lines.append(f"Row {i//c+1}, column {i%c+1}: {desc}.")
bold = " These are UI tool button icons: bolder and simpler shapes, slightly thicker dark-brown outline, filled warm colours (honey, terracotta, cream, mint), minimal detail, very clear silhouette." if s.get("bold") else ""
p=f"""Use your built-in image generation tool to create ONE landscape image, 1536x1024. {d['style']}{bold}

Layout: exactly {c*r} separate icons arranged in a {c} columns x {r} rows grid, each icon centred in its own invisible equal cell, every icon about the same size (about 65% of its cell), with generous empty magenta space between icons so no two icons touch or overlap. Every icon must be one connected object (no floating separate bits far away).
{chr(10).join(lines)}

The first attached image is only a colour/line style reference (cozy cel-shaded storybook look); do not copy its content.
After the image is generated, copy the generated PNG file to {out} (create the folder if needed). Do not write any other files. Reply with the saved path only."""
print(p)
