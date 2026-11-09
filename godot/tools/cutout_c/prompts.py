"""Frame-sheet prompts, method-C resident spike (docs/RESIDENTS_2D.md section 7, 2026-11-08).
usage: prompts.py <walk|carry|idle> <front|q_front|q_back|back> <out_path>
Attached images (gen.sh): 1) ref_woman_A.png (concept A woman: identity, outfit, colours),
2) ref_inset_woman.png (the in-game proportions: big head ~40% of the height, short pear body, short legs),
3) template.png (2 rows x 4 cells, top line + ground line per cell)."""
import sys

VIEWS = {
    "front": "FRONT view: she faces the viewer squarely and walks straight TOWARD the viewer",
    "q_front": "THREE-QUARTER FRONT view: her body is turned about 45 degrees toward the RIGHT edge of the image; she walks toward the lower-right (toward the viewer and to the right); we see her front and her right side",
    "q_back": "THREE-QUARTER BACK view: she walks AWAY from the viewer toward the upper-RIGHT; we see mostly her BACK and a little of her left side (the apron is hidden except a sliver of its edge and the apron strings tied in a bow at the back of the waist)",
    "back": "BACK view: seen from directly behind, she walks straight AWAY from the viewer; we see the back of the dress and the apron strings tied in a small bow at the back of the waist; no apron front",
}

BODY = """The FIRST attached image is the APPROVED CHARACTER: an adult village woman in a soft, rounded, cosy picture-book style. Draw HER BODY AND CLOTHES exactly like that: a dusty-rose (#BE7575) dress with a gathered round cream neckline, big PUFFY cream (#F3E6CC) short sleeves ending at the elbow with a gathered band, bare warm light-tan forearms and soft mitten-like hands, a cream apron in front, a brown (#8A5A3A) cloth sash knotted at the waist with two hanging tails, the dress hem at MID-CALF so the lower legs show, light tan stockings, soft dark-brown (#6B4630) shoes. Thick dark-brown ink outline (#3A2A22) of even weight around every shape, flat cel colour with ONE soft shade step, light from the upper-left. Cute, soft and rounded, no sharp angles.
The SECOND attached image shows her IN-GAME PROPORTIONS — copy these proportions: a chunky little figure, the head about 40% of the total height, NO neck, a short soft pear-shaped body, short arms, short legs.
HEAD PLACEHOLDER (very important): do NOT draw her head, face, hair or headscarf. In place of the whole head draw ONE plain flat solid MAGENTA (#FF00FF) filled circle with NO outline and no details, as big as her head would be (about 40% of the figure height, slightly wider than her shoulders), sitting directly on the collar (no neck). The magenta circle moves with the body (it bobs up and down with the walk) but always keeps the same size. It will be replaced by a separate head drawing later."""

LAYOUT = """The THIRD attached image is a STRICT LAYOUT TEMPLATE (1536x1024): 2 rows x 4 cells. Follow it exactly:
- Background: one flat, uniform pure chroma green #00FF00 everywhere. The darker green guide lines may be left or omitted; draw nothing else on the background (no text, no numbers, no ground, no cast shadows, no gradient).
- Exactly ONE figure per cell, centred horizontally in its cell (on the small centre tick), never touching the cell edges or another figure.
- The top of the magenta head circle is near the upper thin guide line and the soles of the shoe(s) standing on the ground are exactly on the thick ground line, in every cell. All figures are drawn at EXACTLY THE SAME SIZE and scale.
- CONSISTENCY (most important): all 8 figures are the same character in the same view: identical dress shape and length, identical sleeve size, identical apron, identical colours, identical leg length and shoe size, identical magenta circle size. Only the pose changes from cell to cell, as in an animation sprite sheet. Frames are read left-to-right, top row then bottom row."""

CLIPS = {
    "walk": """This is an 8-FRAME WALK CYCLE sprite sheet (walking IN PLACE like on a treadmill, the figure does not travel across the cell) of her in {view}.
Frames: 1) CONTACT: her right foot has just stepped forward (heel touching down), the left foot behind (toe still on the ground), legs apart, arms swing opposite to the legs; 2) DOWN: weight on the right foot, body at its LOWEST, knees slightly bent; 3) PASSING: the left leg swings forward past the right one, the left foot lifted off the ground with the knee bent, body rising; 4) UP: body at its HIGHEST, pushing off the right toe, the left leg reaching forward; 5) CONTACT with the LEFT foot forward (mirror of frame 1); 6) DOWN on the left foot (mirror of 2); 7) PASSING with the right leg (mirror of 3); 8) UP (mirror of 4).
The legs and feet clearly show the steps (lifted foot, bent knee, stride), the skirt hem swings a little with the legs, the arms swing forward and back opposite to the legs (forward arm comes in front of the body). The body bobs: lowest in frames 2 and 6, highest in 4 and 8.""",
    "carry": """This is an 8-FRAME WALK CYCLE sprite sheet of her CARRYING A FLOUR SACK ON HER SHOULDER (walking IN PLACE like on a treadmill) in {view}.
The sack: a big plump soft cloth FLOUR SACK, light cool grey-white (#D9D9D2, clearly greyer and whiter than her cream apron) with ONE wide muted BLUE (#5A7FB0) stripe across its middle and a tied gathered top, about as big as her body. It rests on her RIGHT shoulder, lying across the shoulder and pressing against the side of the magenta head circle (the sack must NOT cover the magenta circle — it sits beside it, slightly lower), and BOTH her hands are raised to hold it there (the right hand holding the sack from below, the left hand reaching up across to steady it). Because of the weight she leans very slightly forward and her steps are a little shorter and heavier.
Frames (same step timing as a walk cycle): 1) CONTACT right foot forward; 2) DOWN (lowest, knees bent under the load); 3) PASSING (left leg swings forward, foot lifted); 4) UP; 5) CONTACT left foot forward; 6) DOWN; 7) PASSING right leg; 8) UP. The legs clearly show the steps, the sack bounces slightly with the body and stays the same size and shape in every frame.""",
    "idle": """This is an IDLE sprite sheet of her standing in {view}.
TOP ROW (frames 1-4) = STANDING AND BREATHING: she stands relaxed, feet slightly apart and both soles flat on the ground line, arms hanging relaxed a little away from the body with the hands near the hips. 1) neutral; 2) breathing in: chest and shoulders rise very slightly, arms lift a tiny bit; 3) full breath: body a few pixels taller, shoulders highest; 4) breathing out, back toward neutral. The changes are SMALL (a few pixels), the feet never move.
BOTTOM ROW (frames 5-8) = STANDING STILL HOLDING A FLOUR SACK ON HER RIGHT SHOULDER, breathing the same way (5 neutral, 6 in, 7 full, 8 out), feet flat and still. The sack: a big plump soft cloth flour sack, light cool grey-white (#D9D9D2, clearly greyer and whiter than her cream apron) with ONE wide muted BLUE (#5A7FB0) stripe across its middle and a tied gathered top, about as big as her body, lying across her right shoulder beside the magenta head circle (NOT covering the circle), held with both raised hands.""",
}

# v2 (2026-11-09 user: "한 발로만 걷는 것 같아요"): the 3/4 walk / carry sheets of v1 repeated the SAME leg's step in frames 5-8
# (a half cycle drawn twice -> she limps on one foot). The cycle is now spelled out per frame with NEAR / FAR leg, and the far leg
# is drawn a little darker so the alternation reads at small size.
LEGS_Q = """LEG ALTERNATION (most important — a full two-step cycle, NOT the same step twice):
- The NEAR leg is the leg closer to the viewer: drawn in front, its foot lower on the image. The FAR leg is behind it: partly hidden by the skirt and the near leg, its foot a little higher on the image, and the far leg and far shoe are drawn ONE SHADE DARKER (in shadow) so the two legs are always easy to tell apart.
- Frames 1-4 = the NEAR leg's step: 1) CONTACT: NEAR foot forward (heel down), FAR foot behind on its toe; 2) DOWN: weight on the NEAR foot (flat, now under the body), FAR foot lifting behind; 3) PASSING: the FAR leg swings forward past the near leg, FAR foot lifted with the knee bent; 4) UP: FAR leg reaching forward, NEAR foot pushing off behind.
- Frames 5-8 = the FAR leg's step (the mirror in time): 5) CONTACT: FAR foot forward (heel down), NEAR foot behind on its toe; 6) DOWN: weight on the FAR foot, NEAR foot lifting behind; 7) PASSING: the NEAR leg swings forward past the far leg, NEAR foot lifted with the knee bent; 8) UP: NEAR leg reaching forward.
- So frame 5 must look DIFFERENT from frame 1 (the other leg is in front), and frame 7 different from frame 3. The planted foot slides steadily BACKWARD from frame to frame while it is on the ground (treadmill)."""

# v3 (2026-11-09): v2 still drew the same leg stepping in both halves. The FAR leg is now drawn in KEY COLOURS (cyan stocking,
# navy shoe) so the model has a concrete identity to track per frame; build_frames.py checks the alternation and paints the
# far leg back to stocking / shoe colours one shade darker.
LEGS_Q3 = """LEG COLOUR CODE + ALTERNATION (most important — a full two-step cycle, NOT the same step twice):
- Draw her FAR leg (the one further from the viewer, partly behind the skirt) with a bright CYAN (#20A8FF) stocking and a dark NAVY (#203070) shoe. Draw her NEAR leg (closer to the viewer) with the normal light tan stocking and dark-brown shoe. Keep this colour code in EVERY frame. Both feet are visible in every frame.
- 1) CONTACT: TAN leg forward (heel down), CYAN leg behind on its toe. 2) DOWN: weight on the TAN foot, CYAN foot lifting behind. 3) PASSING: the CYAN leg swings forward past the tan leg, CYAN foot lifted off the ground, knee bent. 4) UP: CYAN leg reaching forward, TAN foot pushing off behind.
- 5) CONTACT: CYAN leg forward (heel down), TAN leg behind on its toe. 6) DOWN: weight on the CYAN foot, TAN foot lifting behind. 7) PASSING: the TAN leg swings forward past the cyan leg, TAN foot lifted, knee bent. 8) UP: TAN leg reaching forward, CYAN foot pushing off behind.
- Check: in frames 1-2 the TAN foot is in front, in frames 5-6 the CYAN foot is in front; in frame 3 the CYAN foot is lifted, in frame 7 the TAN foot is lifted. The planted foot slides steadily backward from frame to frame while it is on the ground (treadmill). Everything else on her (dress, sleeves, apron, arms) keeps its normal colours."""

LEGS_FB = """LEG ALTERNATION (most important — a full two-step cycle, NOT the same step twice): frames 1-4: the image-LEFT foot is the planted one and the image-RIGHT foot lifts and steps in frames 3-4); frames 5-8 = the mirror: the image-RIGHT foot is planted and the image-LEFT foot lifts and steps in frames 7-8. Frame 7 must show the OTHER foot lifted than frame 3. The far leg is never hidden: both shoes are visible in every frame."""

TEMPLATE = """Use your built-in image generation tool to create ONE landscape image, exactly 1536x1024, then save it (copy the generated PNG) to {out} and print the path.

{body}

{clip}

{layout}

Clean flat cel colour, NO gradients, NO texture noise, NO hatching, NO cast shadows, NO text."""

# v4 (2026-11-09, user chose "pose reference"): the THIRD attached image is a programmatic POSE REFERENCE sheet (pose_ref.py) —
# a puppet per cell with the exact feet / knees / arms / sack of a classic two-leg cycle and colour-coded legs.
POSE = """Use your built-in image generation tool to create ONE landscape image, exactly 1536x1024, then save it (copy the generated PNG) to {out} and print the path.

{body}
HEM: the dress is LONG, down to mid-shin exactly where the reference dress ends; under it only her short rounded BOOTS (and a little ankle) show. The total figure is short and chunky — do NOT make the legs longer than in the reference.

This is an 8-frame {what} animation sprite sheet of her in {view}.

The THIRD attached image is the POSE REFERENCE AND LAYOUT (1536x1024, 2 rows x 4 cells). Each cell holds a crude puppet: a magenta head circle, a trapezoid dress, stick arms, stick legs and oval shoes{sack}. It is ONLY a pose guide — in each cell draw HER (the character of the first image, with her real dress, apron, sash, puffy sleeves, rounded arms and mitten hands, rounded legs) in EXACTLY the puppet's pose:
- Keep the magenta head circle exactly as in the reference: a flat solid MAGENTA (#FF00FF) circle, same size and same position in each cell (no face, no hair, no outline).
- TRACE THE FEET EXACTLY: each shoe at the same position as the puppet's shoe (same x, same height above the ground line), the lifted foot lifted exactly as high, the same knee bends, the same leg in front. The two legs are colour-coded and you must KEEP THESE COLOURS: the TAN puppet leg = her tan stocking with a dark-brown shoe; the CYAN puppet leg = a bright CYAN (#20A8FF) stocking with a dark NAVY (#203070) shoe. Both legs and both shoes are visible in EVERY frame; where one leg passes behind the other, draw the cyan one behind.
- LEG SHAPE: only short chunky ankles and small rounded boots show under the long skirt, exactly as much as in the reference (NO visible knees, NO long legs) — the cute stubby proportions of the second attached image. The boots still step: the lifted boot is lifted (partly tucked under the hem) and the boots alternate exactly as in the reference.
- Arms{sack2}: they swing OPPOSITE to the legs — when the TAN leg is forward her arm on the cyan-leg side swings forward, and the other way round.
- The puppet's dress shows where her dress goes (hem at the knee); draw her real dress shape there.
- Background: flat uniform pure chroma green #00FF00 everywhere; the dark green cell frames and ground lines may stay or go; NO numbers, NO text, NO cast shadows. Exactly one figure per cell, same size in every cell, soles of the planted foot on the ground line.
Thick dark-brown ink outline, flat cel colour with one soft shade step, cute and rounded — but the POSES (especially the leg and foot positions) must match the reference cells one by one.
Clean flat cel colour, NO gradients, NO texture noise, NO hatching."""


if __name__ == "__main__" and sys.argv[1] == "pose":
    clip, view, out = sys.argv[2], sys.argv[3], sys.argv[4]
    sk = clip == "carry"
    print(POSE.format(out=out, body=BODY, view=VIEWS[view],
                      what="WALK CYCLE (walking in place, treadmill)" if not sk else "WALK CYCLE CARRYING A FLOUR SACK ON HER RIGHT SHOULDER (walking in place)",
                      sack=" and a grey sack with a blue stripe" if sk else "",
                      sack2=" (no swing: both hands holding the sack on her right shoulder: a big plump soft cloth flour sack, light cool grey-white #D9D9D2 with ONE wide muted blue #5A7FB0 stripe and a tied gathered top, exactly where the puppet's sack is)" if sk else ""))
    sys.exit(0)

if __name__ == "__main__":
    clip, view, out = sys.argv[1], sys.argv[2], sys.argv[3]
    ctext = CLIPS[clip].format(view=VIEWS[view])
    if clip in ("walk", "carry"):
        ctext += "\n" + (LEGS_Q3 if view in ("q_front", "q_back") else LEGS_FB)
    print(TEMPLATE.format(out=out, body=BODY, clip=ctext, layout=LAYOUT))
