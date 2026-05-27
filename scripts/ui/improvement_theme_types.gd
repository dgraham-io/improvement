## Theme type and palette key names shared by Improvement themes and UI code.
class_name ImprovementThemeTypes
extends RefCounted

const TASK_ROW := &"TaskRow"
const TASK_LED := &"TaskLed"
const METRICS_ROW := &"MetricsRow"
const OVERLAY_DIM := &"OverlayDim"

const PRIORITY_NONE := &"priority_none"
const PRIORITY_LOW := &"priority_low"
const PRIORITY_MEDIUM := &"priority_medium"
const PRIORITY_HIGH := &"priority_high"

const DONE_TITLE := &"done_title"
const DONE_WORK_TIME := &"done_work_time"
const DONE_RESET := &"done_reset"

const LED_GLOW := &"glow"
const LED_CORE := &"core"
const LED_OFF_FILL := &"off_fill"
const LED_OFF_BORDER := &"off_border"
const LED_SPECULAR := &"specular"
const LED_INNER_SHADOW := &"inner_shadow"

const METRICS_ACCENT_DOT := &"accent_dot"
const CHART_TICK := &"chart_tick"
const OVERLAY := &"overlay"

static func priority_key(priority: int) -> StringName:
	match clampi(priority, 0, 3):
		1:
			return PRIORITY_LOW
		2:
			return PRIORITY_MEDIUM
		3:
			return PRIORITY_HIGH
		_:
			return PRIORITY_NONE
