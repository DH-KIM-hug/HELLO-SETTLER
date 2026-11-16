# Spirit house — style test prompts

Generated 2026-11-16 with `codex exec` (codex-cli 0.163.0, built-in image generation), one image per call:
`codex exec --skip-git-repo-check -C design/concept/spirit_house/style_test -s workspace-write - <<<"$PROMPT"`.
No reference images (`-i`) were used. Below is the full text sent for each image (save path shown repo-relative).
The `_v2` room prompts are the same as the first ones except the SCALE paragraph, which adds real sizes in cm.

## A_room.png

Direction A — clean anime cel, pastel · 1st try

```text
Use your built-in image generation tool to create ONE tall portrait image in 9:16 aspect ratio (1024x1792, or the closest tall portrait size the tool supports). Then save it (copy the generated PNG, unmodified) to design/concept/spirit_house/style_test/A_room.png and print the path and its pixel size (use sips). Do not crop, resize or edit the image. Do not create any other files. Generate exactly one image.

IMAGE PROMPT:
ART STYLE: clean modern anime cel-shading illustration in a soft pastel palette. Crisp, thin, even line art with colored (not pure black) lines. Flat color fills with exactly ONE crisp shadow tone per color, plus small clean highlights. Bright, soft, airy and very tidy. No painterly texture, no heavy gradients. Polished, store-key-art quality for a cute mobile game.

SCENE: a window-sill and desk corner inside an ordinary cozy human-sized room on a rainy afternoon. Camera at a gentle three-quarter view looking slightly down at the desk top and the window sill just behind it. A large window fills the upper middle of the picture: raindrops and rain streaks on the glass, soft grey-blue rain clouds and blurred wet trees outside. Soft cool daylight comes in through the window from the back and lights the scene (the window is the only light source); a warm faint reflection on the wooden desk.
On the wooden desk: a big ceramic coffee mug (human size, pale cream with a simple stripe, faint steam), a short stack of two or three hardcover books with plain covers, a pencil, a folded handkerchief. These human objects show the scale.
Three tiny spirits play on miniature toys left out for them on the desk and sill:
- the flower spirit sits on the rim of a shiny silver sewing thimble, legs dangling, waving;
- the star spirit balances on top of a wooden spool of thread, the loose thread trailing across the desk;
- the water spirit splashes happily in a metal bottle cap filled with water like a tiny pool.
A tiny food bowl (an acorn-cap bowl with a few crumbs of biscuit) sits next to them.
THE THREE SPIRITS (original designs; each has an element mark on the body):
1. Flower spirit (girl): her hair is shaped like layered soft-pink flower petals forming a round bob, with a tiny green leaf sprout on top; a short petal-skirt dress in pink and cream.
2. Water spirit (boy): pale aqua hair with a droplet-shaped curl; he wears a cape shaped like one big translucent water droplet that shimmers; light blue tunic.
3. Star spirit (girl): pale lemon hair, two thin springy antennae on her head each tipped with a small glowing starlight spark; a navy-blue little coat sprinkled with tiny star dots.
The spirits are cute moe chibi characters: about 2 to 2.5 heads tall, big expressive sparkling eyes, small nose, tiny smiling mouths, soft pink blush on cheeks, small rounded bodies, tiny hands. They are tiny nature spirits that look like little people. They are fully clothed in modest, simple, original outfits. Wholesome, innocent, non-sexualized.
SCALE IS THE MOST IMPORTANT THING: the room and objects are drawn at REAL HUMAN SIZE, and the spirits are fingertip-sized. Each spirit is at most one fifth of the height of the coffee mug - roughly as tall as the thimble. The coffee mug, the books and the window tower over them like buildings. A spirit standing next to the mug reaches only the bottom of the mug's handle.
COMPOSITION for a phone screen: keep the spirits and toys in the middle band of the image. Leave calm, simple, uncluttered space in the top ~15% (soft upper window / wall) and the bottom ~15% (plain desk surface) where phone UI will go later. Do not draw any UI, buttons, frames or icons.
Mood: cozy, quiet, gentle, secret little visitors; soft rain atmosphere, but still bright and cute, not gloomy.
AVOID: any text, letters, numbers, captions, logos, signatures, watermarks, UI; halos or rings above heads; guns or weapons; school uniforms; cats or cat-like visitors; a veranda or yard view; horror, creepy or sad faces; photorealism; 3D render look (unless soft painted); extra or missing fingers; distorted or asymmetric eyes; spirits drawn too large (they must stay fingertip-sized); adult or revealing clothing.
```

## A_room_v2.png

Direction A · scale-fix regeneration

```text
Use your built-in image generation tool to create ONE tall portrait image in 9:16 aspect ratio (1024x1792, or the closest tall portrait size the tool supports). Then save it (copy the generated PNG, unmodified) to design/concept/spirit_house/style_test/A_room_v2.png and print the path and its pixel size (use sips). Do not crop, resize or edit the image. Do not create any other files. Generate exactly one image.

IMAGE PROMPT:
ART STYLE: clean modern anime cel-shading illustration in a soft pastel palette. Crisp, thin, even line art with colored (not pure black) lines. Flat color fills with exactly ONE crisp shadow tone per color, plus small clean highlights. Bright, soft, airy and very tidy. No painterly texture, no heavy gradients. Polished, store-key-art quality for a cute mobile game.

SCENE: a window-sill and desk corner inside an ordinary cozy human-sized room on a rainy afternoon. Camera at a gentle three-quarter view looking slightly down at the desk top and the window sill just behind it. A large window fills the upper middle of the picture: raindrops and rain streaks on the glass, soft grey-blue rain clouds and blurred wet trees outside. Soft cool daylight comes in through the window from the back and lights the scene (the window is the only light source); a warm faint reflection on the wooden desk.
On the wooden desk: a big ceramic coffee mug (human size, pale cream with a simple stripe, faint steam), a short stack of two or three hardcover books with plain covers, a pencil, a folded handkerchief. These human objects show the scale.
Three tiny spirits play on miniature toys left out for them on the desk and sill:
- the flower spirit sits on the rim of a shiny silver sewing thimble, legs dangling, waving;
- the star spirit balances on top of a wooden spool of thread, the loose thread trailing across the desk;
- the water spirit splashes happily in a metal bottle cap filled with water like a tiny pool.
A tiny food bowl (an acorn-cap bowl with a few crumbs of biscuit) sits next to them.
THE THREE SPIRITS (original designs; each has an element mark on the body):
1. Flower spirit (girl): her hair is shaped like layered soft-pink flower petals forming a round bob, with a tiny green leaf sprout on top; a short petal-skirt dress in pink and cream.
2. Water spirit (boy): pale aqua hair with a droplet-shaped curl; he wears a cape shaped like one big translucent water droplet that shimmers; light blue tunic.
3. Star spirit (girl): pale lemon hair, two thin springy antennae on her head each tipped with a small glowing starlight spark; a navy-blue little coat sprinkled with tiny star dots.
The spirits are cute moe chibi characters: about 2 to 2.5 heads tall, big expressive sparkling eyes, small nose, tiny smiling mouths, soft pink blush on cheeks, small rounded bodies, tiny hands. They are tiny nature spirits that look like little people. They are fully clothed in modest, simple, original outfits. Wholesome, innocent, non-sexualized.
SCALE IS THE MOST IMPORTANT THING (an earlier attempt drew the spirits far too big - make them MUCH smaller): the room and objects are drawn at REAL HUMAN SIZE and the spirits are fingertip-sized. Real sizes: the coffee mug is 10 cm tall, the thimble is 2.5 cm tall, the spool is 5 cm tall, the bottle cap is 3 cm wide, the pencil is 18 cm long, and EACH SPIRIT IS ONLY ABOUT 2 CM TALL. So: each spirit is one fifth of the mug's height or less; the flower spirit is smaller than the thimble she sits on; the star spirit is shorter than the spool she stands on; the water spirit fits completely inside the bottle cap like a bathtub; a spirit's whole body is about as long as the pencil's metal band plus eraser. Place the toys right in front of the mug so the size comparison is direct and obvious. Keep the camera close enough that the tiny faces are still clearly readable and cute.
COMPOSITION for a phone screen: keep the spirits and toys in the middle band of the image. Leave calm, simple, uncluttered space in the top ~15% (soft upper window / wall) and the bottom ~15% (plain desk surface) where phone UI will go later. Do not draw any UI, buttons, frames or icons.
Mood: cozy, quiet, gentle, secret little visitors; soft rain atmosphere, but still bright and cute, not gloomy.
AVOID: any text, letters, numbers, captions, logos, signatures, watermarks, UI; halos or rings above heads; guns or weapons; school uniforms; cats or cat-like visitors; a veranda or yard view; horror, creepy or sad faces; photorealism; 3D render look (unless soft painted); extra or missing fingers; distorted or asymmetric eyes; spirits drawn too large (they must stay fingertip-sized); adult or revealing clothing.
```

## A_card.png

Direction A

```text
Use your built-in image generation tool to create ONE portrait image in 3:4 aspect ratio (1024x1365, or the closest 3:4-ish portrait size the tool supports). Then save it (copy the generated PNG, unmodified) to design/concept/spirit_house/style_test/A_card.png and print the path and its pixel size (use sips). Do not crop, resize or edit the image. Do not create any other files. Generate exactly one image.

IMAGE PROMPT:
ART STYLE: clean modern anime cel-shading illustration in a soft pastel palette. Crisp, thin, even line art with colored (not pure black) lines. Flat color fills with exactly ONE crisp shadow tone per color, plus small clean highlights. Bright, soft, airy and very tidy. No painterly texture, no heavy gradients. Polished, store-key-art quality for a cute mobile game.

SCENE: a single-character reward illustration of the flower spirit. She sits inside a human-sized porcelain teacup (white with a thin gold rim and a small painted blue flower), which is huge compared with her: only her head, shoulders and arms show above the rim, her arms folded on the rim, smiling softly with her head tilted. A little warm tea in the cup with a few petals floating. Soft pink flower petals fall gently around her through the air. The teacup sits on its saucer on a windowsill; soft warm sunlight from a window behind her, gentle bokeh of curtains and a potted plant in the background. Petal particles glow in the light.
THE FLOWER SPIRIT (original design): her hair is shaped like layered soft-pink flower petals forming a round bob, with a tiny green leaf sprout on top; a petal-collar dress in pink and cream. She is fingertip-sized: the teacup is far bigger than she is.
The spirits are cute moe chibi characters: about 2 to 2.5 heads tall, big expressive sparkling eyes, small nose, tiny smiling mouths, soft pink blush on cheeks, small rounded bodies, tiny hands. They are tiny nature spirits that look like little people. They are fully clothed in modest, simple, original outfits. Wholesome, innocent, non-sexualized.
Make this a full, beautiful, finished illustration: careful lighting, appealing face as the focal point, rich but gentle color, clear silhouette. Do not draw any card frame, border, title, text or UI.
AVOID: any text, letters, numbers, captions, logos, signatures, watermarks, UI; halos or rings above heads; guns or weapons; school uniforms; cats or cat-like visitors; a veranda or yard view; horror, creepy or sad faces; photorealism; 3D render look (unless soft painted); extra or missing fingers; distorted or asymmetric eyes; spirits drawn too large (they must stay fingertip-sized); adult or revealing clothing.
```

## B_room.png

Direction B — gouache / watercolor picture-book · 1st try

```text
Use your built-in image generation tool to create ONE tall portrait image in 9:16 aspect ratio (1024x1792, or the closest tall portrait size the tool supports). Then save it (copy the generated PNG, unmodified) to design/concept/spirit_house/style_test/B_room.png and print the path and its pixel size (use sips). Do not crop, resize or edit the image. Do not create any other files. Generate exactly one image.

IMAGE PROMPT:
ART STYLE: soft gouache and watercolor picture-book painting. Gentle visible paper grain, soft transparent washes, opaque gouache accents, soft edges, warm cozy palette, hand-painted storybook feel. Faces stay clean and clearly readable: neat simple linework on faces and eyes, no muddy smudges on faces. Premium picture-book illustration quality, suitable as store key art.

SCENE: a window-sill and desk corner inside an ordinary cozy human-sized room on a rainy afternoon. Camera at a gentle three-quarter view looking slightly down at the desk top and the window sill just behind it. A large window fills the upper middle of the picture: raindrops and rain streaks on the glass, soft grey-blue rain clouds and blurred wet trees outside. Soft cool daylight comes in through the window from the back and lights the scene (the window is the only light source); a warm faint reflection on the wooden desk.
On the wooden desk: a big ceramic coffee mug (human size, pale cream with a simple stripe, faint steam), a short stack of two or three hardcover books with plain covers, a pencil, a folded handkerchief. These human objects show the scale.
Three tiny spirits play on miniature toys left out for them on the desk and sill:
- the flower spirit sits on the rim of a shiny silver sewing thimble, legs dangling, waving;
- the star spirit balances on top of a wooden spool of thread, the loose thread trailing across the desk;
- the water spirit splashes happily in a metal bottle cap filled with water like a tiny pool.
A tiny food bowl (an acorn-cap bowl with a few crumbs of biscuit) sits next to them.
THE THREE SPIRITS (original designs; each has an element mark on the body):
1. Flower spirit (girl): her hair is shaped like layered soft-pink flower petals forming a round bob, with a tiny green leaf sprout on top; a short petal-skirt dress in pink and cream.
2. Water spirit (boy): pale aqua hair with a droplet-shaped curl; he wears a cape shaped like one big translucent water droplet that shimmers; light blue tunic.
3. Star spirit (girl): pale lemon hair, two thin springy antennae on her head each tipped with a small glowing starlight spark; a navy-blue little coat sprinkled with tiny star dots.
The spirits are cute moe chibi characters: about 2 to 2.5 heads tall, big expressive sparkling eyes, small nose, tiny smiling mouths, soft pink blush on cheeks, small rounded bodies, tiny hands. They are tiny nature spirits that look like little people. They are fully clothed in modest, simple, original outfits. Wholesome, innocent, non-sexualized.
SCALE IS THE MOST IMPORTANT THING: the room and objects are drawn at REAL HUMAN SIZE, and the spirits are fingertip-sized. Each spirit is at most one fifth of the height of the coffee mug - roughly as tall as the thimble. The coffee mug, the books and the window tower over them like buildings. A spirit standing next to the mug reaches only the bottom of the mug's handle.
COMPOSITION for a phone screen: keep the spirits and toys in the middle band of the image. Leave calm, simple, uncluttered space in the top ~15% (soft upper window / wall) and the bottom ~15% (plain desk surface) where phone UI will go later. Do not draw any UI, buttons, frames or icons.
Mood: cozy, quiet, gentle, secret little visitors; soft rain atmosphere, but still bright and cute, not gloomy.
AVOID: any text, letters, numbers, captions, logos, signatures, watermarks, UI; halos or rings above heads; guns or weapons; school uniforms; cats or cat-like visitors; a veranda or yard view; horror, creepy or sad faces; photorealism; 3D render look (unless soft painted); extra or missing fingers; distorted or asymmetric eyes; spirits drawn too large (they must stay fingertip-sized); adult or revealing clothing.
```

## B_room_v2.png

Direction B · scale-fix regeneration

```text
Use your built-in image generation tool to create ONE tall portrait image in 9:16 aspect ratio (1024x1792, or the closest tall portrait size the tool supports). Then save it (copy the generated PNG, unmodified) to design/concept/spirit_house/style_test/B_room_v2.png and print the path and its pixel size (use sips). Do not crop, resize or edit the image. Do not create any other files. Generate exactly one image.

IMAGE PROMPT:
ART STYLE: soft gouache and watercolor picture-book painting. Gentle visible paper grain, soft transparent washes, opaque gouache accents, soft edges, warm cozy palette, hand-painted storybook feel. Faces stay clean and clearly readable: neat simple linework on faces and eyes, no muddy smudges on faces. Premium picture-book illustration quality, suitable as store key art.

SCENE: a window-sill and desk corner inside an ordinary cozy human-sized room on a rainy afternoon. Camera at a gentle three-quarter view looking slightly down at the desk top and the window sill just behind it. A large window fills the upper middle of the picture: raindrops and rain streaks on the glass, soft grey-blue rain clouds and blurred wet trees outside. Soft cool daylight comes in through the window from the back and lights the scene (the window is the only light source); a warm faint reflection on the wooden desk.
On the wooden desk: a big ceramic coffee mug (human size, pale cream with a simple stripe, faint steam), a short stack of two or three hardcover books with plain covers, a pencil, a folded handkerchief. These human objects show the scale.
Three tiny spirits play on miniature toys left out for them on the desk and sill:
- the flower spirit sits on the rim of a shiny silver sewing thimble, legs dangling, waving;
- the star spirit balances on top of a wooden spool of thread, the loose thread trailing across the desk;
- the water spirit splashes happily in a metal bottle cap filled with water like a tiny pool.
A tiny food bowl (an acorn-cap bowl with a few crumbs of biscuit) sits next to them.
THE THREE SPIRITS (original designs; each has an element mark on the body):
1. Flower spirit (girl): her hair is shaped like layered soft-pink flower petals forming a round bob, with a tiny green leaf sprout on top; a short petal-skirt dress in pink and cream.
2. Water spirit (boy): pale aqua hair with a droplet-shaped curl; he wears a cape shaped like one big translucent water droplet that shimmers; light blue tunic.
3. Star spirit (girl): pale lemon hair, two thin springy antennae on her head each tipped with a small glowing starlight spark; a navy-blue little coat sprinkled with tiny star dots.
The spirits are cute moe chibi characters: about 2 to 2.5 heads tall, big expressive sparkling eyes, small nose, tiny smiling mouths, soft pink blush on cheeks, small rounded bodies, tiny hands. They are tiny nature spirits that look like little people. They are fully clothed in modest, simple, original outfits. Wholesome, innocent, non-sexualized.
SCALE IS THE MOST IMPORTANT THING (an earlier attempt drew the spirits far too big - make them MUCH smaller): the room and objects are drawn at REAL HUMAN SIZE and the spirits are fingertip-sized. Real sizes: the coffee mug is 10 cm tall, the thimble is 2.5 cm tall, the spool is 5 cm tall, the bottle cap is 3 cm wide, the pencil is 18 cm long, and EACH SPIRIT IS ONLY ABOUT 2 CM TALL. So: each spirit is one fifth of the mug's height or less; the flower spirit is smaller than the thimble she sits on; the star spirit is shorter than the spool she stands on; the water spirit fits completely inside the bottle cap like a bathtub; a spirit's whole body is about as long as the pencil's metal band plus eraser. Place the toys right in front of the mug so the size comparison is direct and obvious. Keep the camera close enough that the tiny faces are still clearly readable and cute.
COMPOSITION for a phone screen: keep the spirits and toys in the middle band of the image. Leave calm, simple, uncluttered space in the top ~15% (soft upper window / wall) and the bottom ~15% (plain desk surface) where phone UI will go later. Do not draw any UI, buttons, frames or icons.
Mood: cozy, quiet, gentle, secret little visitors; soft rain atmosphere, but still bright and cute, not gloomy.
AVOID: any text, letters, numbers, captions, logos, signatures, watermarks, UI; halos or rings above heads; guns or weapons; school uniforms; cats or cat-like visitors; a veranda or yard view; horror, creepy or sad faces; photorealism; 3D render look (unless soft painted); extra or missing fingers; distorted or asymmetric eyes; spirits drawn too large (they must stay fingertip-sized); adult or revealing clothing.
```

## B_card.png

Direction B

```text
Use your built-in image generation tool to create ONE portrait image in 3:4 aspect ratio (1024x1365, or the closest 3:4-ish portrait size the tool supports). Then save it (copy the generated PNG, unmodified) to design/concept/spirit_house/style_test/B_card.png and print the path and its pixel size (use sips). Do not crop, resize or edit the image. Do not create any other files. Generate exactly one image.

IMAGE PROMPT:
ART STYLE: soft gouache and watercolor picture-book painting. Gentle visible paper grain, soft transparent washes, opaque gouache accents, soft edges, warm cozy palette, hand-painted storybook feel. Faces stay clean and clearly readable: neat simple linework on faces and eyes, no muddy smudges on faces. Premium picture-book illustration quality, suitable as store key art.

SCENE: a single-character reward illustration of the flower spirit. She sits inside a human-sized porcelain teacup (white with a thin gold rim and a small painted blue flower), which is huge compared with her: only her head, shoulders and arms show above the rim, her arms folded on the rim, smiling softly with her head tilted. A little warm tea in the cup with a few petals floating. Soft pink flower petals fall gently around her through the air. The teacup sits on its saucer on a windowsill; soft warm sunlight from a window behind her, gentle bokeh of curtains and a potted plant in the background. Petal particles glow in the light.
THE FLOWER SPIRIT (original design): her hair is shaped like layered soft-pink flower petals forming a round bob, with a tiny green leaf sprout on top; a petal-collar dress in pink and cream. She is fingertip-sized: the teacup is far bigger than she is.
The spirits are cute moe chibi characters: about 2 to 2.5 heads tall, big expressive sparkling eyes, small nose, tiny smiling mouths, soft pink blush on cheeks, small rounded bodies, tiny hands. They are tiny nature spirits that look like little people. They are fully clothed in modest, simple, original outfits. Wholesome, innocent, non-sexualized.
Make this a full, beautiful, finished illustration: careful lighting, appealing face as the focal point, rich but gentle color, clear silhouette. Do not draw any card frame, border, title, text or UI.
AVOID: any text, letters, numbers, captions, logos, signatures, watermarks, UI; halos or rings above heads; guns or weapons; school uniforms; cats or cat-like visitors; a veranda or yard view; horror, creepy or sad faces; photorealism; 3D render look (unless soft painted); extra or missing fingers; distorted or asymmetric eyes; spirits drawn too large (they must stay fingertip-sized); adult or revealing clothing.
```

## B_shelf.png

Direction B · extra variant (sunny bookshelf, ribbon swing, matchbox bed, leaf spirit)

```text
Use your built-in image generation tool to create ONE tall portrait image in 9:16 aspect ratio (1024x1792, or the closest tall portrait size the tool supports). Then save it (copy the generated PNG, unmodified) to design/concept/spirit_house/style_test/B_shelf.png and print the path and its pixel size (use sips). Do not crop, resize or edit the image. Do not create any other files. Generate exactly one image.

IMAGE PROMPT:
ART STYLE: soft gouache and watercolor picture-book painting. Gentle visible paper grain, soft transparent washes, opaque gouache accents, soft edges, warm cozy palette, hand-painted storybook feel. Faces stay clean and clearly readable: neat simple linework on faces and eyes, no muddy smudges on faces. Premium picture-book illustration quality, suitable as store key art.

SCENE: a sunny morning at a wooden bookshelf corner inside an ordinary cozy human-sized room. Warm low sunbeams come from a window on the left (the only light source) and fall across the shelf; dust motes glow in the light; the sky outside the window edge is clear blue with a few small white clouds. Rows of real human-size hardcover books (each book about 22 cm tall) stand on the shelves, plus a human-size ceramic coffee mug and a pair of folded reading glasses lying on the shelf edge. These human objects show the scale.
On the middle shelf, in a gap between the books, tiny toys are left out for the spirits:
- the leaf spirit swings happily on a ribbon swing: a pale yellow satin ribbon tied in a loop that hangs from the shelf above;
- the flower spirit naps peacefully in a matchbox bed: an open, plain, unprinted matchbox tray with a scrap of patterned cloth as a blanket and a cotton-ball pillow;
- the star spirit sits cross-legged on top of a silver thimble, munching a biscuit crumb from a tiny acorn-cap food bowl beside her.
THE SPIRITS (original designs; each has an element mark on the body):
1. Leaf spirit (boy): chestnut hair, a hood shaped like one big fresh green leaf with its little stem sticking up at the tip, a moss-green poncho.
2. Flower spirit (girl): hair shaped like layered soft-pink flower petals forming a round bob, a tiny green leaf sprout on top, a pink and cream petal-skirt dress.
3. Star spirit (girl): pale lemon hair, two thin springy antennae each tipped with a small glowing starlight spark, a navy-blue little coat with tiny star dots.
The spirits are cute moe chibi characters: about 2 to 2.5 heads tall, big expressive sparkling eyes, small nose, tiny smiling mouths, soft pink blush on cheeks, small rounded bodies, tiny hands. They are tiny nature spirits that look like little people. They are fully clothed in modest, simple, original outfits. Wholesome, innocent, non-sexualized.
SCALE IS THE MOST IMPORTANT THING: the shelf, books, mug and glasses are REAL HUMAN SIZE and the spirits are fingertip-sized, only about 2 cm tall. Each spirit is about one tenth of the height of the books beside them and at most one fifth of the mug's height; the reading glasses lens is wider than a whole spirit. Make them clearly tiny, but keep the camera close enough that their faces are still readable and cute.
COMPOSITION for a phone screen: keep the spirits and toys in the middle band. Leave calm, simple space in the top ~15% and bottom ~15% for phone UI. Do not draw any UI, buttons, frames or icons. No text on book spines.
Mood: bright, warm, sunny and cozy; a secret little morning visit.
AVOID: any text, letters, numbers, captions, logos, signatures, watermarks, UI; halos or rings above heads; guns or weapons; school uniforms; cats or cat-like visitors; a veranda or yard view; horror, creepy or sad faces; photorealism; 3D render look (unless soft painted); extra or missing fingers; distorted or asymmetric eyes; spirits drawn too large (they must stay fingertip-sized); adult or revealing clothing.
```

## C_room.png

Direction C — soft toy-like painted · 1st try

```text
Use your built-in image generation tool to create ONE tall portrait image in 9:16 aspect ratio (1024x1792, or the closest tall portrait size the tool supports). Then save it (copy the generated PNG, unmodified) to design/concept/spirit_house/style_test/C_room.png and print the path and its pixel size (use sips). Do not crop, resize or edit the image. Do not create any other files. Generate exactly one image.

IMAGE PROMPT:
ART STYLE: soft toy-like painted look. Everything has rounded, chubby, squishy forms; the spirits look a little like soft plush dolls or matte clay figurines, with soft felt or clay-like surfaces, gentle ambient occlusion and soft rim light. It is still a 2D digital painting (not a 3D render, not a photo, not tilt-shift). Moe anime faces with big glossy eyes painted cleanly. Polished, store-key-art quality.

SCENE: a window-sill and desk corner inside an ordinary cozy human-sized room on a rainy afternoon. Camera at a gentle three-quarter view looking slightly down at the desk top and the window sill just behind it. A large window fills the upper middle of the picture: raindrops and rain streaks on the glass, soft grey-blue rain clouds and blurred wet trees outside. Soft cool daylight comes in through the window from the back and lights the scene (the window is the only light source); a warm faint reflection on the wooden desk.
On the wooden desk: a big ceramic coffee mug (human size, pale cream with a simple stripe, faint steam), a short stack of two or three hardcover books with plain covers, a pencil, a folded handkerchief. These human objects show the scale.
Three tiny spirits play on miniature toys left out for them on the desk and sill:
- the flower spirit sits on the rim of a shiny silver sewing thimble, legs dangling, waving;
- the star spirit balances on top of a wooden spool of thread, the loose thread trailing across the desk;
- the water spirit splashes happily in a metal bottle cap filled with water like a tiny pool.
A tiny food bowl (an acorn-cap bowl with a few crumbs of biscuit) sits next to them.
THE THREE SPIRITS (original designs; each has an element mark on the body):
1. Flower spirit (girl): her hair is shaped like layered soft-pink flower petals forming a round bob, with a tiny green leaf sprout on top; a short petal-skirt dress in pink and cream.
2. Water spirit (boy): pale aqua hair with a droplet-shaped curl; he wears a cape shaped like one big translucent water droplet that shimmers; light blue tunic.
3. Star spirit (girl): pale lemon hair, two thin springy antennae on her head each tipped with a small glowing starlight spark; a navy-blue little coat sprinkled with tiny star dots.
The spirits are cute moe chibi characters: about 2 to 2.5 heads tall, big expressive sparkling eyes, small nose, tiny smiling mouths, soft pink blush on cheeks, small rounded bodies, tiny hands. They are tiny nature spirits that look like little people. They are fully clothed in modest, simple, original outfits. Wholesome, innocent, non-sexualized.
SCALE IS THE MOST IMPORTANT THING: the room and objects are drawn at REAL HUMAN SIZE, and the spirits are fingertip-sized. Each spirit is at most one fifth of the height of the coffee mug - roughly as tall as the thimble. The coffee mug, the books and the window tower over them like buildings. A spirit standing next to the mug reaches only the bottom of the mug's handle.
COMPOSITION for a phone screen: keep the spirits and toys in the middle band of the image. Leave calm, simple, uncluttered space in the top ~15% (soft upper window / wall) and the bottom ~15% (plain desk surface) where phone UI will go later. Do not draw any UI, buttons, frames or icons.
Mood: cozy, quiet, gentle, secret little visitors; soft rain atmosphere, but still bright and cute, not gloomy.
AVOID: any text, letters, numbers, captions, logos, signatures, watermarks, UI; halos or rings above heads; guns or weapons; school uniforms; cats or cat-like visitors; a veranda or yard view; horror, creepy or sad faces; photorealism; 3D render look (unless soft painted); extra or missing fingers; distorted or asymmetric eyes; spirits drawn too large (they must stay fingertip-sized); adult or revealing clothing.
```

## C_room_v2.png

Direction C · scale-fix regeneration

```text
Use your built-in image generation tool to create ONE tall portrait image in 9:16 aspect ratio (1024x1792, or the closest tall portrait size the tool supports). Then save it (copy the generated PNG, unmodified) to design/concept/spirit_house/style_test/C_room_v2.png and print the path and its pixel size (use sips). Do not crop, resize or edit the image. Do not create any other files. Generate exactly one image.

IMAGE PROMPT:
ART STYLE: soft toy-like painted look. Everything has rounded, chubby, squishy forms; the spirits look a little like soft plush dolls or matte clay figurines, with soft felt or clay-like surfaces, gentle ambient occlusion and soft rim light. It is still a 2D digital painting (not a 3D render, not a photo, not tilt-shift). Moe anime faces with big glossy eyes painted cleanly. Polished, store-key-art quality.

SCENE: a window-sill and desk corner inside an ordinary cozy human-sized room on a rainy afternoon. Camera at a gentle three-quarter view looking slightly down at the desk top and the window sill just behind it. A large window fills the upper middle of the picture: raindrops and rain streaks on the glass, soft grey-blue rain clouds and blurred wet trees outside. Soft cool daylight comes in through the window from the back and lights the scene (the window is the only light source); a warm faint reflection on the wooden desk.
On the wooden desk: a big ceramic coffee mug (human size, pale cream with a simple stripe, faint steam), a short stack of two or three hardcover books with plain covers, a pencil, a folded handkerchief. These human objects show the scale.
Three tiny spirits play on miniature toys left out for them on the desk and sill:
- the flower spirit sits on the rim of a shiny silver sewing thimble, legs dangling, waving;
- the star spirit balances on top of a wooden spool of thread, the loose thread trailing across the desk;
- the water spirit splashes happily in a metal bottle cap filled with water like a tiny pool.
A tiny food bowl (an acorn-cap bowl with a few crumbs of biscuit) sits next to them.
THE THREE SPIRITS (original designs; each has an element mark on the body):
1. Flower spirit (girl): her hair is shaped like layered soft-pink flower petals forming a round bob, with a tiny green leaf sprout on top; a short petal-skirt dress in pink and cream.
2. Water spirit (boy): pale aqua hair with a droplet-shaped curl; he wears a cape shaped like one big translucent water droplet that shimmers; light blue tunic.
3. Star spirit (girl): pale lemon hair, two thin springy antennae on her head each tipped with a small glowing starlight spark; a navy-blue little coat sprinkled with tiny star dots.
The spirits are cute moe chibi characters: about 2 to 2.5 heads tall, big expressive sparkling eyes, small nose, tiny smiling mouths, soft pink blush on cheeks, small rounded bodies, tiny hands. They are tiny nature spirits that look like little people. They are fully clothed in modest, simple, original outfits. Wholesome, innocent, non-sexualized.
SCALE IS THE MOST IMPORTANT THING (an earlier attempt drew the spirits far too big - make them MUCH smaller): the room and objects are drawn at REAL HUMAN SIZE and the spirits are fingertip-sized. Real sizes: the coffee mug is 10 cm tall, the thimble is 2.5 cm tall, the spool is 5 cm tall, the bottle cap is 3 cm wide, the pencil is 18 cm long, and EACH SPIRIT IS ONLY ABOUT 2 CM TALL. So: each spirit is one fifth of the mug's height or less; the flower spirit is smaller than the thimble she sits on; the star spirit is shorter than the spool she stands on; the water spirit fits completely inside the bottle cap like a bathtub; a spirit's whole body is about as long as the pencil's metal band plus eraser. Place the toys right in front of the mug so the size comparison is direct and obvious. Keep the camera close enough that the tiny faces are still clearly readable and cute.
COMPOSITION for a phone screen: keep the spirits and toys in the middle band of the image. Leave calm, simple, uncluttered space in the top ~15% (soft upper window / wall) and the bottom ~15% (plain desk surface) where phone UI will go later. Do not draw any UI, buttons, frames or icons.
Mood: cozy, quiet, gentle, secret little visitors; soft rain atmosphere, but still bright and cute, not gloomy.
AVOID: any text, letters, numbers, captions, logos, signatures, watermarks, UI; halos or rings above heads; guns or weapons; school uniforms; cats or cat-like visitors; a veranda or yard view; horror, creepy or sad faces; photorealism; 3D render look (unless soft painted); extra or missing fingers; distorted or asymmetric eyes; spirits drawn too large (they must stay fingertip-sized); adult or revealing clothing.
```

## C_card.png

Direction C

```text
Use your built-in image generation tool to create ONE portrait image in 3:4 aspect ratio (1024x1365, or the closest 3:4-ish portrait size the tool supports). Then save it (copy the generated PNG, unmodified) to design/concept/spirit_house/style_test/C_card.png and print the path and its pixel size (use sips). Do not crop, resize or edit the image. Do not create any other files. Generate exactly one image.

IMAGE PROMPT:
ART STYLE: soft toy-like painted look. Everything has rounded, chubby, squishy forms; the spirits look a little like soft plush dolls or matte clay figurines, with soft felt or clay-like surfaces, gentle ambient occlusion and soft rim light. It is still a 2D digital painting (not a 3D render, not a photo, not tilt-shift). Moe anime faces with big glossy eyes painted cleanly. Polished, store-key-art quality.

SCENE: a single-character reward illustration of the flower spirit. She sits inside a human-sized porcelain teacup (white with a thin gold rim and a small painted blue flower), which is huge compared with her: only her head, shoulders and arms show above the rim, her arms folded on the rim, smiling softly with her head tilted. A little warm tea in the cup with a few petals floating. Soft pink flower petals fall gently around her through the air. The teacup sits on its saucer on a windowsill; soft warm sunlight from a window behind her, gentle bokeh of curtains and a potted plant in the background. Petal particles glow in the light.
THE FLOWER SPIRIT (original design): her hair is shaped like layered soft-pink flower petals forming a round bob, with a tiny green leaf sprout on top; a petal-collar dress in pink and cream. She is fingertip-sized: the teacup is far bigger than she is.
The spirits are cute moe chibi characters: about 2 to 2.5 heads tall, big expressive sparkling eyes, small nose, tiny smiling mouths, soft pink blush on cheeks, small rounded bodies, tiny hands. They are tiny nature spirits that look like little people. They are fully clothed in modest, simple, original outfits. Wholesome, innocent, non-sexualized.
Make this a full, beautiful, finished illustration: careful lighting, appealing face as the focal point, rich but gentle color, clear silhouette. Do not draw any card frame, border, title, text or UI.
AVOID: any text, letters, numbers, captions, logos, signatures, watermarks, UI; halos or rings above heads; guns or weapons; school uniforms; cats or cat-like visitors; a veranda or yard view; horror, creepy or sad faces; photorealism; 3D render look (unless soft painted); extra or missing fingers; distorted or asymmetric eyes; spirits drawn too large (they must stay fingertip-sized); adult or revealing clothing.
```
