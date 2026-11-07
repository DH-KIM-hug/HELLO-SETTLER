# GDScript (4.4 → 4.7)

Last verified: 2026-11-07
Primary source: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html and .../static_typing.html; upgrade guides in `breaking-changes.md`.

## Language additions
| Since | Feature | Notes (docs wording) |
|---|---|---|
| 4.4 | Typed Dictionary `Dictionary[K, V]` | Both types required (`Variant` for untyped); `Dictionary` == `Dictionary[Variant, Variant]`; nested typed collections unsupported; value-returning methods still `Variant` |
| 4.5 | Variadic functions `func f(a, ...rest: Array)` | One rest parameter, last, no default; static and lambda functions may be variadic; typed arrays unsupported as the rest type; spread syntax unsupported |
| 4.5 | `@abstract` classes/methods | Abstract class cannot be instantiated or attached to a node; class with an abstract method must be abstract |
| 4.4 | UID `.uid` files beside scripts | https://godotengine.org/releases/4.4/ |
| 4.4 | Debugger expression evaluator tab | release post 4.4 |
| 4.6 | Step Out in debugger; `%s`/`{name}` placeholder highlight | https://godotengine.org/releases/4.6/ |
| 4.7 | GDScript can implement/override Java interfaces (Android) | https://godotengine.org/releases/4.7/ |

## Behaviour changes (4.7 guide)
- "Setting the element of packed arrays no longer calls the setter for the entire packed array property".
- "Methods that inherit from a method with a typed return now inherit the return type as well" (override must return explicitly).

## Semantics to remember
- `static var`: class-level, shared across instances, accessible via child classes, can be typed and have setters/getters; no `@export`/`@onready`; local variables cannot be static. No change to this listed in the 4.4-4.7 guides (absence is not proof). Known bug in docs: scripts are never freed even with `@static_unload`.
- Lambdas: locals captured by value once at creation; cannot reassign outer locals; cannot be `static`; call via `.call()`, not `()`.
- `await`: signal or coroutine; calling a coroutine without `await` and using its return value errors; no function state object like old `yield`; multi-parameter signals yield an `Array`.
- `Tween.tween_await()` exists in 4.7 docs (https://docs.godotengine.org/en/stable/classes/class_tween.html); "since" version NOT SOURCEABLE there, but the 4.7 post lists it under Animation. Tweens "are not designed to be reused"; bound-node free kills the tween; infinite `set_loops()` needs a duration/delay.
- Static typing: `:=` infers; `as` may return `null`; typed `for` loop variables since 4.2 (static_typing.html).

## Typed-code risk list when moving across 4.5→4.7
`AnimationPlayer.current_animation` / `autoplay` / `assigned_animation` are `StringName`; `Object.is_class` takes `StringName`; `Node.set_name` takes `StringName`; `RichTextLabel.add_image` width/height float. See breaking-changes.md.
