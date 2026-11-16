class_name EnvClock
extends RefCounted
## Fallback environment (no network yet): night flag and weather for a unix time.
## Seed weather is deterministic from (save_seed, "wx", local date, 4-hour block).
## Forecast hours given to apply_forecast() win over the seed weather.

const SECONDS_PER_HOUR: int = 3600
const SECONDS_PER_DAY: int = 86400
const WEATHER_BLOCK_S: int = 14400  # 4 hours
const BLOCKS_PER_DAY: int = 6

var _save_seed: int
var _day_start_hour: int
var _night_start_hour: int
var _seed_clear_p: float      # from tuning.json seed_weather_clear_p
var _seed_cloudy_p: float     # from tuning.json seed_weather_cloudy_p (rain takes the rest)
var _forecast: Dictionary = {}  # hour start (unix seconds, int) -> weather String


func _init(save_seed: int, day_start_hour: int, night_start_hour: int, seed_clear_p: float, seed_cloudy_p: float) -> void:
	_save_seed = save_seed
	_day_start_hour = day_start_hour
	_night_start_hour = night_start_hour
	_seed_clear_p = seed_clear_p
	_seed_cloudy_p = seed_cloudy_p


## WMO weather code -> "clear" | "cloudy" | "rain". Returns "" for codes not in the table.
## Snow (71-77, 85-86) is cloudy in the MVP.
static func wmo_to_weather(code: int) -> String:
	if code == 0 or code == 1 or code == 2:
		return "clear"
	if code == 3 or code == 45 or code == 48:
		return "cloudy"
	if (code >= 71 and code <= 77) or code == 85 or code == 86:
		return "cloudy"
	if (code >= 51 and code <= 57) or (code >= 61 and code <= 67) or (code >= 80 and code <= 82) or (code >= 95 and code <= 99):
		return "rain"
	return ""


## hours: Array of Dictionary {unix_hour: int (unix seconds of an hour start), wmo_code: int}.
## Entries with an unknown WMO code are skipped. Returns the number of accepted entries.
func apply_forecast(hours: Array) -> int:
	var accepted: int = 0
	for entry: Variant in hours:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = entry
		if not d.has("unix_hour") or not d.has("wmo_code"):
			continue
		var weather: String = EnvClock.wmo_to_weather(int(d["wmo_code"]))
		if weather == "":
			continue
		_forecast[_hour_start(int(d["unix_hour"]))] = weather
		accepted += 1
	return accepted


## Returns {is_night: bool, weather: String, source: "seed" | "cache"}.
func at(unix_t: int, utc_offset_s: int) -> Dictionary:
	var local_t: int = unix_t + utc_offset_s
	var hour_of_day: int = _floor_div(posmod(local_t, SECONDS_PER_DAY), SECONDS_PER_HOUR)
	var is_night: bool = hour_of_day >= _night_start_hour or hour_of_day < _day_start_hour
	var key: int = _hour_start(unix_t)
	if _forecast.has(key):
		return {"is_night": is_night, "weather": _forecast[key], "source": "cache"}
	return {"is_night": is_night, "weather": _seed_weather(local_t), "source": "seed"}


func _seed_weather(local_t: int) -> String:
	var day_index: int = _floor_div(local_t, SECONDS_PER_DAY)
	var block: int = _floor_div(posmod(local_t, SECONDS_PER_DAY), WEATHER_BLOCK_S)
	var number: int = day_index * BLOCKS_PER_DAY + block
	var roll: float = DetRng.unit(_save_seed, "wx", number)
	if roll < _seed_clear_p:
		return "clear"
	if roll < _seed_clear_p + _seed_cloudy_p:
		return "cloudy"
	return "rain"


func _hour_start(unix_t: int) -> int:
	return _floor_div(unix_t, SECONDS_PER_HOUR) * SECONDS_PER_HOUR


static func _floor_div(a: int, b: int) -> int:
	return floori(float(a) / float(b))
