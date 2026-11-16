# Spirit lineup — prompts

Generated 2026-11-16 with `codex exec` (codex-cli 0.163.0, built-in image generation), one image per call, run from the repo root:

```sh
codex exec --skip-git-repo-check -C <repo> -s workspace-write - \
  -i design/concept/spirit_house/style_test/B_card.png \
  -i design/concept/spirit_house/style_test/B_shelf.png \
  [-i design/concept/spirit_house/lineup/lineup_a.png]   # lineup_b only
  <<<"$PROMPT"
```

Style references (`-i`): `B_card.png` (image 1), `B_shelf.png` (image 2). `lineup_b` also gets `lineup_a.png` as image 3.
The `ART STYLE` paragraph and the chibi paragraph are copied verbatim from `../style_test/prompts.md` (direction B).
Below is the full text sent for each image. 3 generations used (of 4 allowed).

## lineup_a.png

16:9 lineup, 8 spirits + thimble · gen 1/4

```text
Use your built-in image generation tool to create ONE wide landscape image in 16:9 aspect ratio (1672x941, or the closest wide 16:9 landscape size the tool supports). Use the two attached images only as style and character references (see REFERENCES below). Then save it (copy the generated PNG, unmodified) to design/concept/spirit_house/lineup/lineup_a.png and print the path and its pixel size (use sips). Do not crop, resize or edit the image. Do not create any other files. Generate exactly one image.

IMAGE PROMPT:
ART STYLE: soft gouache and watercolor picture-book painting. Gentle visible paper grain, soft transparent washes, opaque gouache accents, soft edges, warm cozy palette, hand-painted storybook feel. Faces stay clean and clearly readable: neat simple linework on faces and eyes, no muddy smudges on faces. Premium picture-book illustration quality, suitable as store key art.

REFERENCES: the two attached images set the painting style and three existing character designs. Image 1 (teacup) shows the flower spirit. Image 2 (bookshelf) shows the leaf spirit (boy in a leaf hood on the ribbon swing), the flower spirit (asleep in the matchbox) and the star spirit (blonde girl with star antennae sitting on the thimble). Match their painting style, face style, eye style and body proportions closely, and keep those three character designs recognisably the same. Do not copy the reference backgrounds or scenes.

SCENE: a character lineup sheet. Eight tiny spirits stand side by side in ONE straight horizontal row, all full body from the top of the head (including hats, antennae and sprouts) down to the feet, facing the viewer (slight three-quarter turns are fine), all at the SAME SCALE and on the same ground line, evenly spaced with a small gap between each so nobody overlaps. Each has a small cheerful standing pose that shows personality (a wave, hands clasped, a little hop, a shy smile), but all stay standing. At the far right end of the row, after the eighth spirit, stands one plain shiny silver sewing thimble on the same ground line, for scale; the thimble is about as tall as the spirits. The figures fill roughly the middle half of the image height so the faces are big enough to read. Background: plain warm cream watercolor paper with soft paper grain and a faint warm wash, nothing else; only a soft pale shadow under each figure's feet. No room, no furniture, no props other than the thimble.

THE EIGHT SPIRITS, LEFT TO RIGHT (original designs; four girls and four boys; each wears a small round brooch or embroidered badge showing its element symbol):
1. Flower spirit (girl), same character as the reference: hair shaped like layered soft-pink flower petals forming a round bob, a tiny green leaf sprout on top, rosy-pink eyes; a pink and cream dress with a petal collar and a petal skirt; little cream shoes; a flower badge.
2. Leaf spirit (boy), same character as the reference: chestnut-brown hair, a hood shaped like one big fresh green leaf with its little stem sticking up at the tip, a moss-green poncho, cream shorts, small brown boots; a leaf badge.
3. Water spirit (boy): pale aqua hair with one droplet-shaped curl over his forehead, light blue eyes; a cape shaped like one big translucent water droplet that shimmers, worn over a light blue tunic and white shorts; a water-droplet badge.
4. Candle spirit (girl): warm honey-amber hair in two short pigtails; only the very tips of her hair glow softly like small calm candle flames in warm orange and gold (gentle cozy candlelight, nothing is burning, no sparks, not dangerous); amber eyes; a cream collar shaped like softly dripping candle wax; a warm orange pinafore dress; a little flame badge. Sleepy-sweet and gentle.
5. Breeze spirit (boy): fluffy white hair with sky-blue tips, and two soft white-and-sky-blue feathers sticking out sideways from the sides of his head like little ears; sky-blue eyes; a light airy white tunic and a short sky-blue scarf fluttering in a breeze; a swirl-of-wind badge. Light and playful, standing on tiptoe.
6. Moss spirit (boy): a little round and chubby, calm; warm brown skin; short dark-brown hair under a wide, round, soft cap made of deep green moss, shaped a little like a mushroom cap, with a few tiny white flower buds on it; olive eyes; a deep green and earthy brown smock; a tiny mushroom badge. Sleepy, cozy smile.
7. Rain spirit (girl, rare): long straight silver-blue hair; a small delicate crown made of clear glittering raindrops resting on her hair (a crown sitting on the head, not a halo, nothing floating); silver-blue eyes; a fluffy soft grey-white cloud shawl around her shoulders; a pale silver-blue dress that deepens toward the hem with faint rain-streak patterns; a raindrop badge. A little more elegant and detailed than the others, with a faint shimmer, but exactly the same height and size.
8. Star spirit (girl, rare), same character as the reference: pale lemon wavy hair, two thin springy antennae on her head each tipped with a small glowing golden starlight spark; golden eyes; a long night-sky dress in deep navy blue sprinkled with tiny gold star dots, like a little piece of the night sky; a star badge. A little more special than the others, with a faint glow, but exactly the same height and size.
Make all eight clearly different in silhouette, hair shape, hair color and main color, while sharing one consistent face style and the same body proportions. Nobody is taller, bigger or more powerful-looking than the others.

The spirits are cute moe chibi characters: about 2 to 2.5 heads tall, big expressive sparkling eyes, small nose, tiny smiling mouths, soft pink blush on cheeks, small rounded bodies, tiny hands. They are tiny nature spirits that look like little people. They are fully clothed in modest, simple, original outfits. Wholesome, innocent, non-sexualized.
SCALE: they are fingertip-sized, each about as tall as the sewing thimble (about 2.5 cm).

AVOID: any text, letters, numbers, captions, labels, name tags, logos, signatures, watermarks, UI, frames; halos or rings above heads; guns or weapons; school uniforms; cats, cat ears or animal mascots; real fire or anything dangerous; horror, creepy or sad faces; photorealism; 3D render look; extra or missing fingers; distorted or asymmetric eyes; overlapping figures; cropped heads or feet; spirits of different sizes; designs that resemble existing famous characters (all designs must be original); adult or revealing clothing.
```

## lineup_b.png

Fix take of lineup_a (all eyes open, candle flames attached to the hair, taller thimble) · gen 3/4 · extra reference: `lineup_a.png`

```text
Use your built-in image generation tool to create ONE wide landscape image in 16:9 aspect ratio (1672x941, or the closest wide 16:9 landscape size the tool supports). Use the three attached images only as style and character references (see REFERENCES below). Then save it (copy the generated PNG, unmodified) to design/concept/spirit_house/lineup/lineup_b.png and print the path and its pixel size (use sips). Do not crop, resize or edit the image. Do not create any other files. Generate exactly one image.

IMAGE PROMPT:
ART STYLE: soft gouache and watercolor picture-book painting. Gentle visible paper grain, soft transparent washes, opaque gouache accents, soft edges, warm cozy palette, hand-painted storybook feel. Faces stay clean and clearly readable: neat simple linework on faces and eyes, no muddy smudges on faces. Premium picture-book illustration quality, suitable as store key art.

REFERENCES: the two attached images set the painting style and three existing character designs. Image 1 (teacup) shows the flower spirit. Image 2 (bookshelf) shows the leaf spirit (boy in a leaf hood on the ribbon swing), the flower spirit (asleep in the matchbox) and the star spirit (blonde girl with star antennae sitting on the thimble). Match their painting style, face style, eye style and body proportions closely, and keep those three character designs recognisably the same. Do not copy the reference backgrounds or scenes.
Image 3 is our previous draft of this exact lineup. Keep the same eight characters, the same order, the same plain paper background and the same overall look, but paint a fresh improved version with these FIXES:
- EVERY spirit has OPEN eyes (big sparkling eyes, clearly showing each eye color). No closed-eye smiles, no winks. The leaf spirit, the candle spirit and the moss spirit had closed eyes in the draft: open them.
- The candle spirit's flames must be the ends of her own two pigtails: each pigtail tip turns into a soft candle-flame shape attached to the hair. Nothing floats next to her.
- Make the figures a little larger and closer together so they fill more of the image height (about 45-50%), while all eight plus the thimble still fit in one row with small gaps.
- The thimble is about as tall as the spirits (the draft's thimble was too short).
- Give each spirit a slightly different, lively standing pose, all still standing on the ground line.

SCENE: a character lineup sheet. Eight tiny spirits stand side by side in ONE straight horizontal row, all full body from the top of the head (including hats, antennae and sprouts) down to the feet, facing the viewer (slight three-quarter turns are fine), all at the SAME SCALE and on the same ground line, evenly spaced with a small gap between each so nobody overlaps. Each has a small cheerful standing pose that shows personality (a wave, hands clasped, a little hop, a shy smile), but all stay standing. At the far right end of the row, after the eighth spirit, stands one plain shiny silver sewing thimble on the same ground line, for scale; the thimble is about as tall as the spirits. The figures fill roughly the middle half of the image height so the faces are big enough to read. Background: plain warm cream watercolor paper with soft paper grain and a faint warm wash, nothing else; only a soft pale shadow under each figure's feet. No room, no furniture, no props other than the thimble.

THE EIGHT SPIRITS, LEFT TO RIGHT (original designs; four girls and four boys; each wears a small round brooch or embroidered badge showing its element symbol):
1. Flower spirit (girl), same character as the reference: hair shaped like layered soft-pink flower petals forming a round bob, a tiny green leaf sprout on top, rosy-pink eyes; a pink and cream dress with a petal collar and a petal skirt; little cream shoes; a flower badge.
2. Leaf spirit (boy), same character as the reference: chestnut-brown hair, a hood shaped like one big fresh green leaf with its little stem sticking up at the tip, a moss-green poncho, cream shorts, small brown boots; a leaf badge.
3. Water spirit (boy): pale aqua hair with one droplet-shaped curl over his forehead, light blue eyes; a cape shaped like one big translucent water droplet that shimmers, worn over a light blue tunic and white shorts; a water-droplet badge.
4. Candle spirit (girl): warm honey-amber hair in two short pigtails; only the very tips of her hair glow softly like small calm candle flames in warm orange and gold (gentle cozy candlelight, nothing is burning, no sparks, not dangerous); amber eyes; a cream collar shaped like softly dripping candle wax; a warm orange pinafore dress; a little flame badge. Sleepy-sweet and gentle.
5. Breeze spirit (boy): fluffy white hair with sky-blue tips, and two soft white-and-sky-blue feathers sticking out sideways from the sides of his head like little ears; sky-blue eyes; a light airy white tunic and a short sky-blue scarf fluttering in a breeze; a swirl-of-wind badge. Light and playful, standing on tiptoe.
6. Moss spirit (boy): a little round and chubby, calm; warm brown skin; short dark-brown hair under a wide, round, soft cap made of deep green moss, shaped a little like a mushroom cap, with a few tiny white flower buds on it; olive eyes; a deep green and earthy brown smock; a tiny mushroom badge. Sleepy, cozy smile.
7. Rain spirit (girl, rare): long straight silver-blue hair; a small delicate crown made of clear glittering raindrops resting on her hair (a crown sitting on the head, not a halo, nothing floating); silver-blue eyes; a fluffy soft grey-white cloud shawl around her shoulders; a pale silver-blue dress that deepens toward the hem with faint rain-streak patterns; a raindrop badge. A little more elegant and detailed than the others, with a faint shimmer, but exactly the same height and size.
8. Star spirit (girl, rare), same character as the reference: pale lemon wavy hair, two thin springy antennae on her head each tipped with a small glowing golden starlight spark; golden eyes; a long night-sky dress in deep navy blue sprinkled with tiny gold star dots, like a little piece of the night sky; a star badge. A little more special than the others, with a faint glow, but exactly the same height and size.
Make all eight clearly different in silhouette, hair shape, hair color and main color, while sharing one consistent face style and the same body proportions. Nobody is taller, bigger or more powerful-looking than the others.

The spirits are cute moe chibi characters: about 2 to 2.5 heads tall, big expressive sparkling eyes, small nose, tiny smiling mouths, soft pink blush on cheeks, small rounded bodies, tiny hands. They are tiny nature spirits that look like little people. They are fully clothed in modest, simple, original outfits. Wholesome, innocent, non-sexualized.
SCALE: they are fingertip-sized, each about as tall as the sewing thimble (about 2.5 cm).

AVOID: any text, letters, numbers, captions, labels, name tags, logos, signatures, watermarks, UI, frames; halos or rings above heads; guns or weapons; school uniforms; cats, cat ears or animal mascots; real fire or anything dangerous; horror, creepy or sad faces; photorealism; 3D render look; extra or missing fingers; distorted or asymmetric eyes; overlapping figures; cropped heads or feet; spirits of different sizes; designs that resemble existing famous characters (all designs must be original); adult or revealing clothing.
```

## lineup_rare.png

3:2 pair illustration of the two rares · gen 2/4 (run in parallel with lineup_a)

```text
Use your built-in image generation tool to create ONE landscape image in 3:2 aspect ratio (1536x1024, or the closest 3:2 landscape size the tool supports). Use the two attached images only as style and character references (see REFERENCES below). Then save it (copy the generated PNG, unmodified) to design/concept/spirit_house/lineup/lineup_rare.png and print the path and its pixel size (use sips). Do not crop, resize or edit the image. Do not create any other files. Generate exactly one image.

IMAGE PROMPT:
ART STYLE: soft gouache and watercolor picture-book painting. Gentle visible paper grain, soft transparent washes, opaque gouache accents, soft edges, warm cozy palette, hand-painted storybook feel. Faces stay clean and clearly readable: neat simple linework on faces and eyes, no muddy smudges on faces. Premium picture-book illustration quality, suitable as store key art.

REFERENCES: the two attached images set the painting style and three existing character designs. Image 1 (teacup) shows the flower spirit. Image 2 (bookshelf) shows the leaf spirit (boy in a leaf hood on the ribbon swing), the flower spirit (asleep in the matchbox) and the star spirit (blonde girl with star antennae sitting on the thimble). Match their painting style, face style, eye style and body proportions closely, and keep the star spirit recognisably the same character. Do not copy the reference backgrounds or scenes.

SCENE: a special pair illustration of the two rare spirits, drawn large in the frame as a close-up so their faces are the focal point, both shown full body. They sit side by side on a wooden windowsill inside an ordinary cozy human-sized room in the evening, as the rain is ending. The window glass behind them is split in mood: on the left side gentle raindrops still run down the glass; on the right side the clouds have parted and a deep blue night sky with a few soft twinkling stars shows through. Warm golden light from an off-frame desk lamp lights them from the front, mixing with cool moonlight from the window: cozy and bright, not dark or gloomy.
- The rain spirit (left) sits on the rim of a metal bottle cap filled with rainwater like a tiny pool, her toes dipping in the water, a few droplets around her.
- The star spirit (right) lounges in a small hammock made from a pale yellow satin ribbon tied between two human-size objects, waving at the rain spirit.
They look at each other and smile, like close friends. Human-size objects at the edges show the scale: part of a big ceramic mug at the left edge, the corner of a hardcover book with no text at the right edge.
THE TWO RARE SPIRITS (original designs; each wears a small round badge showing its element symbol):
1. Rain spirit (girl): long straight silver-blue hair; a small delicate crown made of clear glittering raindrops resting on her hair (a crown sitting on the head, not a halo, nothing floating); silver-blue eyes; a fluffy soft grey-white cloud shawl around her shoulders; a pale silver-blue dress that deepens toward the hem with faint rain-streak patterns; a raindrop badge. Elegant, calm, a faint shimmer.
2. Star spirit (girl), same character as the reference: pale lemon wavy hair, two thin springy antennae on her head each tipped with a small glowing golden starlight spark; golden eyes; a long night-sky dress in deep navy blue sprinkled with tiny gold star dots, like a little piece of the night sky; a star badge. Bright, playful, a faint glow.
Both are the same size as each other.

The spirits are cute moe chibi characters: about 2 to 2.5 heads tall, big expressive sparkling eyes, small nose, tiny smiling mouths, soft pink blush on cheeks, small rounded bodies, tiny hands. They are tiny nature spirits that look like little people. They are fully clothed in modest, simple, original outfits. Wholesome, innocent, non-sexualized.
SCALE: they are fingertip-sized (about 2.5 cm tall): the bottle cap is a bathtub for the rain spirit, and the mug and book tower over them.
Make this a full, beautiful, finished illustration: careful lighting, appealing faces, rich but gentle color, clear silhouettes. Do not draw any card frame, border, title, text or UI.

AVOID: any text, letters, numbers, captions, labels, logos, signatures, watermarks, UI, frames; halos or rings above heads; guns or weapons; school uniforms; cats, cat ears or animal mascots; horror, creepy or sad faces; photorealism; 3D render look; extra or missing fingers; distorted or asymmetric eyes; designs that resemble existing famous characters (all designs must be original); adult or revealing clothing.
```
