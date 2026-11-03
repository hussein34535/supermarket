extends Control

# Lightweight vector icon renderer for the UI. Icons are drawn on a 24x24 grid
# so they stay crisp at any size and do not depend on font glyph coverage.

var icon: String = "grid"
var tint: Color = Color.WHITE
var stroke: float = 1.7


func setup(kind: String, color: Color, px: float = 20.0) -> void:
	icon = kind
	tint = color
	custom_minimum_size = Vector2(px, px)
	size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _p(x: float, y: float, s: float, o: Vector2) -> Vector2:
	return o + Vector2(x, y) * s


func _draw() -> void:
	var s: float = minf(size.x, size.y) / 24.0
	var o: Vector2 = (size - Vector2(24.0, 24.0) * s) * 0.5
	var w: float = maxf(1.1, stroke * s)
	var c: Vector2 = _p(12.0, 12.0, s, o)
	match icon:
		"coin":
			draw_arc(c, 8.4 * s, 0.0, TAU, 32, tint, w, true)
			draw_line(_p(12, 6.6, s, o), _p(12, 17.4, s, o), tint, w, true)
			draw_arc(_p(12, 9.9, s, o), 2.6 * s, -PI * 0.5, PI * 0.5, 14, tint, w, true)
			draw_arc(_p(12, 14.1, s, o), 2.6 * s, PI * 0.5, PI * 1.5, 14, tint, w, true)
		"clock":
			draw_arc(c, 8.4 * s, 0.0, TAU, 32, tint, w, true)
			draw_line(c, _p(12, 6.8, s, o), tint, w, true)
			draw_line(c, _p(16.2, 13.2, s, o), tint, w, true)
		"bolt":
			draw_colored_polygon(PackedVector2Array([
				_p(13.6, 2.4, s, o), _p(5.4, 13.6, s, o), _p(10.8, 13.6, s, o),
				_p(9.8, 21.6, s, o), _p(18.6, 10.4, s, o), _p(13.2, 10.4, s, o),
			]), tint)
		"grid":
			for gx in [4.0, 13.0]:
				for gy in [4.0, 13.0]:
					draw_rect(Rect2(_p(gx, gy, s, o), Vector2(7.0, 7.0) * s), tint, false, w, true)
		"users":
			draw_arc(_p(9.0, 8.8, s, o), 3.4 * s, 0.0, TAU, 20, tint, w, true)
			draw_arc(_p(9.0, 17.6, s, o), 5.4 * s, PI, TAU, 20, tint, w, true)
			draw_arc(_p(16.6, 8.4, s, o), 2.6 * s, 0.0, TAU, 18, tint, w, true)
			draw_arc(_p(17.4, 16.4, s, o), 3.8 * s, PI * 1.02, PI * 1.98, 16, tint, w, true)
		"store":
			draw_polyline(PackedVector2Array([
				_p(3, 9, s, o), _p(5, 4, s, o), _p(19, 4, s, o), _p(21, 9, s, o),
			]), tint, w, true)
			draw_line(_p(3, 9, s, o), _p(21, 9, s, o), tint, w, true)
			draw_rect(Rect2(_p(5, 9, s, o), Vector2(14, 12) * s), tint, false, w, true)
			draw_rect(Rect2(_p(10.2, 14.5, s, o), Vector2(3.6, 6.5) * s), tint, false, w, true)
			draw_line(_p(7, 12, s, o), _p(9, 12, s, o), tint, w, true)
		"chart":
			draw_line(_p(3, 21, s, o), _p(21, 21, s, o), tint, w, true)
			draw_rect(Rect2(_p(5.4, 13, s, o), Vector2(3, 6.2) * s), tint, true)
			draw_rect(Rect2(_p(10.5, 9, s, o), Vector2(3, 10.2) * s), tint, true)
			draw_rect(Rect2(_p(15.6, 4.4, s, o), Vector2(3, 14.8) * s), tint, true)
		"star":
			var star := PackedVector2Array()
			for i in 10:
				var ang: float = -PI * 0.5 + float(i) * PI / 5.0
				var rad: float = 9.2 if i % 2 == 0 else 3.9
				star.append(_p(12.0 + cos(ang) * rad, 12.0 + sin(ang) * rad, s, o))
			draw_colored_polygon(star, tint)
		"truck":
			draw_rect(Rect2(_p(2, 7, s, o), Vector2(11.5, 8.5) * s), tint, false, w, true)
			draw_polyline(PackedVector2Array([
				_p(13.5, 10, s, o), _p(17.5, 10, s, o), _p(21, 13, s, o),
				_p(21, 15.5, s, o), _p(13.5, 15.5, s, o),
			]), tint, w, true)
			draw_circle(_p(7, 18, s, o), 2.1 * s, tint)
			draw_circle(_p(17.5, 18, s, o), 2.1 * s, tint)
		"broom":
			draw_line(_p(19, 3.4, s, o), _p(11.4, 12, s, o), tint, w * 1.25, true)
			draw_colored_polygon(PackedVector2Array([
				_p(8.2, 11.4, s, o), _p(14.6, 10.6, s, o), _p(13.2, 21, s, o), _p(5, 19, s, o),
			]), tint)
		"box":
			draw_polyline(PackedVector2Array([
				_p(4, 7, s, o), _p(12, 3, s, o), _p(20, 7, s, o), _p(12, 11, s, o), _p(4, 7, s, o),
			]), tint, w, true)
			draw_line(_p(12, 11, s, o), _p(12, 20.5, s, o), tint, w, true)
			draw_line(_p(4, 7, s, o), _p(4, 20.5, s, o), tint, w, true)
			draw_line(_p(4, 20.5, s, o), _p(12, 20.5, s, o), tint, w, true)
			draw_line(_p(20, 7, s, o), _p(20, 20.5, s, o), tint, w, true)
			draw_line(_p(20, 20.5, s, o), _p(12, 20.5, s, o), tint, w, true)
		"close":
			draw_line(_p(6, 6, s, o), _p(18, 18, s, o), tint, w * 1.15, true)
			draw_line(_p(18, 6, s, o), _p(6, 18, s, o), tint, w * 1.15, true)
		"check":
			draw_polyline(PackedVector2Array([
				_p(4.5, 12.5, s, o), _p(9.8, 17.6, s, o), _p(19.5, 6.4, s, o),
			]), tint, w * 1.2, true)
		"tag":
			draw_polyline(PackedVector2Array([
				_p(3.5, 12, s, o), _p(12, 3.5, s, o), _p(20.5, 3.5, s, o),
				_p(20.5, 12, s, o), _p(12, 20.5, s, o), _p(3.5, 12, s, o),
			]), tint, w, true)
			draw_circle(_p(16, 8, s, o), 1.7 * s, tint)
		"cart":
			draw_polyline(PackedVector2Array([
				_p(2.5, 4, s, o), _p(5.4, 4, s, o), _p(8.6, 15.2, s, o), _p(19, 15.2, s, o),
			]), tint, w, true)
			draw_line(_p(6.4, 7.4, s, o), _p(19.4, 7.4, s, o), tint, w, true)
			draw_circle(_p(9.4, 19.2, s, o), 1.8 * s, tint)
			draw_circle(_p(17.6, 19.2, s, o), 1.8 * s, tint)
		"scan":
			draw_line(_p(4, 9, s, o), _p(4, 4, s, o), tint, w, true)
			draw_line(_p(4, 4, s, o), _p(9, 4, s, o), tint, w, true)
			draw_line(_p(15, 4, s, o), _p(20, 4, s, o), tint, w, true)
			draw_line(_p(20, 4, s, o), _p(20, 9, s, o), tint, w, true)
			draw_line(_p(4, 15, s, o), _p(4, 20, s, o), tint, w, true)
			draw_line(_p(4, 20, s, o), _p(9, 20, s, o), tint, w, true)
			draw_line(_p(15, 20, s, o), _p(20, 20, s, o), tint, w, true)
			draw_line(_p(20, 20, s, o), _p(20, 15, s, o), tint, w, true)
			draw_line(_p(4.5, 12, s, o), _p(19.5, 12, s, o), tint, w, true)
		"pause":
			draw_rect(Rect2(_p(7, 5, s, o), Vector2(3.4, 14) * s), tint, true)
			draw_rect(Rect2(_p(13.6, 5, s, o), Vector2(3.4, 14) * s), tint, true)
		"play":
			draw_colored_polygon(PackedVector2Array([
				_p(7.5, 4, s, o), _p(19.5, 12, s, o), _p(7.5, 20, s, o),
			]), tint)
		"arrow":
			draw_polyline(PackedVector2Array([
				_p(9, 5, s, o), _p(16, 12, s, o), _p(9, 19, s, o),
			]), tint, w * 1.2, true)
		"chevron":
			draw_polyline(PackedVector2Array([
				_p(14, 5, s, o), _p(7, 12, s, o), _p(14, 19, s, o),
			]), tint, w * 1.2, true)
		"crown":
			draw_colored_polygon(PackedVector2Array([
				_p(3, 18, s, o), _p(4, 7.5, s, o), _p(9, 12.5, s, o), _p(12, 4.5, s, o),
				_p(15, 12.5, s, o), _p(20, 7.5, s, o), _p(21, 18, s, o),
			]), tint)
			draw_line(_p(3, 20.2, s, o), _p(21, 20.2, s, o), tint, w * 1.3, true)
		"trash":
			draw_line(_p(4, 7, s, o), _p(20, 7, s, o), tint, w, true)
			draw_polyline(PackedVector2Array([
				_p(6, 7, s, o), _p(7, 20.5, s, o), _p(17, 20.5, s, o), _p(18, 7, s, o),
			]), tint, w, true)
			draw_line(_p(9, 4, s, o), _p(15, 4, s, o), tint, w, true)
			draw_line(_p(10, 11, s, o), _p(10.4, 17, s, o), tint, w, true)
			draw_line(_p(14, 11, s, o), _p(13.6, 17, s, o), tint, w, true)
		"speed":
			draw_arc(_p(12, 15, s, o), 8.4 * s, PI, TAU, 24, tint, w, true)
			draw_line(_p(12, 15, s, o), _p(17, 9.6, s, o), tint, w * 1.2, true)
			draw_circle(_p(12, 15, s, o), 1.5 * s, tint)
		"reach":
			draw_line(_p(4, 12, s, o), _p(20, 12, s, o), tint, w, true)
			draw_polyline(PackedVector2Array([
				_p(8, 8, s, o), _p(4, 12, s, o), _p(8, 16, s, o),
			]), tint, w, true)
			draw_polyline(PackedVector2Array([
				_p(16, 8, s, o), _p(20, 12, s, o), _p(16, 16, s, o),
			]), tint, w, true)
		"capacity":
			draw_rect(Rect2(_p(3, 4, s, o), Vector2(7, 7) * s), tint, false, w, true)
			draw_rect(Rect2(_p(14, 4, s, o), Vector2(7, 7) * s), tint, false, w, true)
			draw_rect(Rect2(_p(8.5, 13, s, o), Vector2(7, 7) * s), tint, false, w, true)
		"sparkle":
			draw_colored_polygon(PackedVector2Array([
				_p(12, 2.5, s, o), _p(14.2, 9.8, s, o), _p(21.5, 12, s, o),
				_p(14.2, 14.2, s, o), _p(12, 21.5, s, o), _p(9.8, 14.2, s, o),
				_p(2.5, 12, s, o), _p(9.8, 9.8, s, o),
			]), tint)
		"shield":
			draw_polyline(PackedVector2Array([
				_p(12, 2.8, s, o), _p(20, 5.8, s, o), _p(20, 12, s, o),
				_p(12, 21.2, s, o), _p(4, 12, s, o), _p(4, 5.8, s, o), _p(12, 2.8, s, o),
			]), tint, w, true)
		"flame":
			draw_colored_polygon(PackedVector2Array([
				_p(12, 2.4, s, o), _p(17.6, 9.2, s, o), _p(15.8, 13, s, o),
				_p(18.2, 15.4, s, o), _p(16.2, 21, s, o), _p(7.8, 21, s, o),
				_p(5.8, 15.4, s, o), _p(8.2, 12.4, s, o), _p(8.6, 7.6, s, o),
			]), tint)
		"home":
			draw_polyline(PackedVector2Array([
				_p(3, 11, s, o), _p(12, 3, s, o), _p(21, 11, s, o),
			]), tint, w, true)
			draw_rect(Rect2(_p(5.5, 11, s, o), Vector2(13, 10) * s), tint, false, w, true)
			draw_rect(Rect2(_p(10, 15, s, o), Vector2(4, 6) * s), tint, false, w, true)
		"dots":
			draw_circle(_p(5.5, 12, s, o), 1.9 * s, tint)
			draw_circle(_p(12, 12, s, o), 1.9 * s, tint)
			draw_circle(_p(18.5, 12, s, o), 1.9 * s, tint)
		"plus":
			draw_line(_p(12, 5, s, o), _p(12, 19, s, o), tint, w * 1.2, true)
			draw_line(_p(5, 12, s, o), _p(19, 12, s, o), tint, w * 1.2, true)
		"minus":
			draw_line(_p(5, 12, s, o), _p(19, 12, s, o), tint, w * 1.2, true)
		"heart":
			draw_circle(_p(8.4, 9, s, o), 3.7 * s, tint)
			draw_circle(_p(15.6, 9, s, o), 3.7 * s, tint)
			draw_colored_polygon(PackedVector2Array([
				_p(4.8, 10.4, s, o), _p(19.2, 10.4, s, o), _p(12, 20.4, s, o),
			]), tint)
		"warning":
			draw_polyline(PackedVector2Array([
				_p(12, 3.4, s, o), _p(21, 20, s, o), _p(3, 20, s, o), _p(12, 3.4, s, o),
			]), tint, w, true)
			draw_line(_p(12, 9, s, o), _p(12, 14.2, s, o), tint, w, true)
			draw_circle(_p(12, 17.2, s, o), 1.0 * s, tint)
		"calendar":
			draw_rect(Rect2(_p(3.5, 5, s, o), Vector2(17, 15.5) * s), tint, false, w, true)
			draw_line(_p(3.5, 9.5, s, o), _p(20.5, 9.5, s, o), tint, w, true)
			draw_line(_p(8, 3, s, o), _p(8, 7, s, o), tint, w, true)
			draw_line(_p(16, 3, s, o), _p(16, 7, s, o), tint, w, true)
			draw_circle(_p(8, 13.5, s, o), 1.1 * s, tint)
			draw_circle(_p(12, 13.5, s, o), 1.1 * s, tint)
			draw_circle(_p(16, 13.5, s, o), 1.1 * s, tint)
		_:
			draw_arc(c, 8.4 * s, 0.0, TAU, 32, tint, w, true)
