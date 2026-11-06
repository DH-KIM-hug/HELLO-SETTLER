## 저장용 변환 — 시뮬 객체의 스크립트 변수를 그대로 사전으로 (docs/SAVE.md 1 · 6).
## 각 시뮬 클래스의 to_dict()/from_dict()가 이 도우미를 쓴다: 변수는 이름 그대로 모두 담고(새 변수가 생겨도 저절로 저장),
## 다른 객체를 가리키는 변수만 클래스가 직접 다룬다 (skip 목록). 모르는 객체를 만나면 push_error — 조용히 잃지 않게.
## 난수(RandomNumberGenerator)는 {"$rng": [seed, state]} → 불러오면 같은 흐름이 이어진다 (결정론).
## 주민의 걸음(steps)에 든 할 일 묶음(ResidentAI.op)은 건물·나무·바위·낟알·버섯·민들레를 붙잡고 있다 →
##   enc_ref / dec_ref가 {"$b": 건물 id} · {"$l": [목록 이름, 자리]} · {"$o": 떠돌이 번호}로 바꾼다.
class_name SaveCodec
extends RefCounted

static var errors := 0                 # 저장할 수 없는 값을 만난 횟수 (시험이 0인지 본다)


## 스크립트 변수들 → 사전 (skip에 든 이름은 뺀다)
static func props(o: Object, skip: Array = []) -> Dictionary:
	var d := {}
	for p: Dictionary in o.get_property_list():
		if not (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var n: String = p["name"]
		if n in skip:
			continue
		d[n] = enc(o.get(n), n)
	return d


## 사전 → 스크립트 변수 (없는 이름은 기본값 그대로 — 옛 저장을 읽을 때). 타입이 정해진 배열은 그 타입으로
static func apply(o: Object, d: Dictionary, skip: Array = []) -> void:
	for p: Dictionary in o.get_property_list():
		if not (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var n: String = p["name"]
		if n in skip or not d.has(n):
			continue
		var cur: Variant = o.get(n)
		var val: Variant = d[n]
		if cur is RandomNumberGenerator:
			set_rng(cur, val)
		elif cur is Array and (cur as Array).is_typed():
			var a := cur as Array
			o.set(n, Array(dec(val), a.get_typed_builtin(), a.get_typed_class_name(), a.get_typed_script()))
		else:
			o.set(n, dec(val))


## 값 하나 → 저장할 수 있는 값 (사전·배열은 새로 만든다 — 저장본이 살아 있는 상태와 엉키지 않게)
static func enc(x: Variant, what := "") -> Variant:
	match typeof(x):
		TYPE_OBJECT:
			if x == null:
				return null
			if x is RandomNumberGenerator:
				return {"$rng": [(x as RandomNumberGenerator).seed, (x as RandomNumberGenerator).state]}
			errors += 1
			push_error("SaveCodec: 저장할 수 없는 객체 %s (%s)" % [x, what])
			return null
		TYPE_ARRAY:
			var out := []
			out.resize((x as Array).size())
			var i := 0
			for e: Variant in x:
				out[i] = enc(e, what)
				i += 1
			return out
		TYPE_DICTIONARY:
			var out := {}
			for k: Variant in x:
				out[k] = enc(x[k], what)
			return out
		TYPE_CALLABLE:
			errors += 1
			push_error("SaveCodec: Callable은 저장할 수 없다 (%s)" % what)
			return null
	return x


static func dec(x: Variant) -> Variant:
	match typeof(x):
		TYPE_ARRAY:
			var out := []
			out.resize((x as Array).size())
			var i := 0
			for e: Variant in x:
				out[i] = dec(e)
				i += 1
			return out
		TYPE_DICTIONARY:
			var dx: Dictionary = x
			if dx.size() == 1 and dx.has("$rng"):
				var r := RandomNumberGenerator.new()
				set_rng(r, dx)
				return r
			var out := {}
			for k: Variant in dx:
				out[k] = dec(dx[k])
			return out
	return x


static func set_rng(r: RandomNumberGenerator, d: Variant) -> void:
	if not (d is Dictionary and (d as Dictionary).has("$rng")):
		return
	var a: Array = d["$rng"]
	r.seed = int(a[0])
	r.state = int(a[1])         # seed를 정하면 state가 처음으로 돌아가므로 state는 뒤에


# ───────────────────────── 걸음 속 할 일 묶음의 붙잡은 것 ─────────────────────────
## 붙잡을 수 있는 목록 (이름 → 배열). 버섯·민들레는 Flora에
static func ref_lists(v: Village) -> Dictionary:
	var l := {"trees": v.trees, "rocks": v.rocks, "manna": v.manna}
	if v.flora != null:
		l["shrooms"] = v.flora.shrooms
		l["dands"] = v.flora.dands
	return l


## 할 일 묶음(op) 안의 값 → 저장 값. orphans = 목록에서 빠졌지만 아직 누가 붙잡고 있는 사전 (같은 것은 한 번만)
static func enc_ref(x: Variant, lists: Dictionary, orphans: Array) -> Variant:
	if x is Building:
		return {"$b": (x as Building).id}
	if x is Resident:
		return {"$p": (x as Resident).id}
	if x is Dictionary:
		var d: Dictionary = x
		if d.has("op"):                     # 할 일 묶음 (안에 또 묶음이 들 수 있다: put → drop)
			var o := {}
			for k: Variant in d:
				o[k] = enc_ref(d[k], lists, orphans)
			return o
		for ln: String in lists:
			var arr: Array = lists[ln]
			for i in arr.size():
				if is_same(arr[i], d):
					return {"$l": [ln, i]}
		for i in orphans.size():
			if is_same(orphans[i], d):
				return {"$o": i}
		orphans.append(d)
		return {"$o": orphans.size() - 1}
	return enc(x, "op")


static func dec_ref(x: Variant, v: Village, lists: Dictionary, orphans: Array) -> Variant:
	if x is Dictionary:
		var d: Dictionary = x
		if d.has("$b"):
			return v.bld(int(d["$b"]))
		if d.has("$p"):
			return v.person(int(d["$p"]))
		if d.has("$l"):
			var a: Array = d["$l"]
			return (lists[a[0]] as Array)[int(a[1])]
		if d.has("$o"):
			return orphans[int(d["$o"])]
		var o := {}
		for k: Variant in d:
			o[k] = dec_ref(d[k], v, lists, orphans)
		return o
	return dec(x)


## 주민의 걸음 목록 → 저장 값
## 걸음 하나 = {k, x, y} 또는 {k, left, anim, done, fast, cancel} — 값마다 (done·cancel은 할 일 묶음)
static func enc_steps(steps: Array, lists: Dictionary, orphans: Array) -> Array:
	var out := []
	for s: Dictionary in steps:
		var o := {}
		for k: Variant in s:
			o[k] = enc_ref(s[k], lists, orphans)
		out.append(o)
	return out


static func dec_steps(a: Array, v: Village, lists: Dictionary, orphans: Array) -> Array:
	var out := []
	for s: Dictionary in a:
		var o := {}
		for k: Variant in s:
			o[k] = dec_ref(s[k], v, lists, orphans)
		out.append(o)
	return out


# ───────────────────────── 상태 지문 (시험 · 결정론 확인) ─────────────────────────
## 저장 사전 → sha256 (같은 상태 = 같은 지문)
static func digest(d: Variant) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(var_to_bytes(d))
	return ctx.finish().hex_encode()
