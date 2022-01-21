module shapes

import gx
import gg.m4 { Vec4 }
import gg
import math
import rand

pub const (
	left  = (Vec2{-1, 0})
	down  = (Vec2{0, -1})
	right = (Vec2{1, 0})
	up    = (Vec2{0, 1})
	zero  = (Vec2{0, 0})
)

const (
	discriminant_epsilon = f32(0.0000001)
)

pub struct Circle {
pub mut:
	center Vec2
	r      f32
}

fn (c Circle) expand(r f32) Circle {
	return Circle{c.center, c.r + r}
}

pub struct Rect {
pub:
	min Vec2
	max Vec2
}

pub const (
	rect_one = Rect{
		min: Vec2{0, 0}
		max: Vec2{1, 1}
	}

	rect_two = Rect{
		min: Vec2{0, 0}
		max: Vec2{2, 2}
	}
)

pub struct LineSegment {
	a      Vec2
	b      Vec2
	normal Vec2
}

pub struct Interval {
pub:
	min f32
	max f32
}

pub struct Projection_Result {
pub mut:
	step             Vec2
	step_mag         f32
	collision_normal Vec2
}

pub struct Hittest_Result {
	hit    bool
	edge   Vec2
	normal Vec2
	depth  f32
}

pub struct Overlap_Result {
	normal   Vec2
	distance f32
}

// TODO switch to interface?
pub type Shape = Circle | Rect | Vec2

pub fn (s Shape) draw_outline(gg &gg.Context, color gx.Color) {
	match s {
		Vec2 { gg.draw_pixel(s.x, s.y, color) }
		Circle { gg.draw_circle_line(s.center.x, s.center.y, int(s.r), 8, color) }
		Rect { gg.draw_rect_empty(s.min.x, s.min.y, s.w(), s.h(), color) }
	}
}

pub fn (s Shape) draw_filled(gg &gg.Context, color gx.Color) {
	match s {
		Vec2 { gg.draw_pixel(s.x, s.y, color) }
		Circle { gg.draw_circle_filled(s.center.x, s.center.y, s.r, color) }
		Rect { gg.draw_rect_filled(s.min.x, s.min.y, s.w(), s.h(), color) }
	}
}

pub fn (r Rect) left_edge() LineSegment {
	a := Vec2{r.min.x, r.min.y}
	b := Vec2{r.min.x, r.max.y}
	return LineSegment{a, b, shapes.left}
}

pub fn (r Rect) bottom_edge() LineSegment {
	a := Vec2{r.min.x, r.min.y}
	b := Vec2{r.max.x, r.min.y}
	return LineSegment{a, b, shapes.down}
}

pub fn (r Rect) top_edge() LineSegment {
	a := Vec2{r.min.x, r.max.y}
	b := Vec2{r.max.x, r.max.y}
	return LineSegment{a, b, shapes.up}
}

pub fn (r Rect) right_edge() LineSegment {
	a := Vec2{r.max.x, r.max.y}
	b := Vec2{r.max.x, r.min.y}
	return LineSegment{a, b, shapes.right}
}

pub fn (r Rect) w() f32 {
	return r.max.x - r.min.x
}

pub fn (r Rect) h() f32 {
	return r.max.y - r.min.y
}

pub fn get_line_intersection(p0 Vec2, p1 Vec2, p2 Vec2, p3 Vec2) (bool, Vec2) {
	// shamelessly borrowed from https://stackoverflow.com/a/1968345

	s1 := p1 - p0
	s2 := (p3 - p2)

	s := (-s1.y * (p0.x - p2.x) + s1.x * (p0.y - p2.y)) / (-s2.x * s1.y + s1.x * s2.y)
	t := (s2.x * (p0.y - p2.y) - s2.y * (p0.x - p2.x)) / (-s2.x * s1.y + s1.x * s2.y)

	if s >= 0 && s <= 1 && t >= 0 && t <= 1 {
		// Collision detected
		return true, Vec2{p0.x + (t * s1.x), p0.y + (t * s1.y)}
	} else {
		// No collision
		return false, Vec2{}
	}
}

pub fn project_circle_v_segment(mut result Projection_Result, c Circle, edge LineSegment) {
	// use the edge's normal to find the nearest point on the circle, this
	// is the earliest possible point of intersection, and therefore the
	// only one we care about.
	circ_edge_a := (c.center - (edge.normal.mul(c.r)))
	circ_edge_b := (circ_edge_a + result.step)

	intersection_exists, intersection := get_line_intersection(edge.a, edge.b, circ_edge_a,
		circ_edge_b)
	if intersection_exists {
		hit_dist := (intersection - circ_edge_a)
		hit_magnitude := hit_dist.length()
		if hit_magnitude < result.step_mag {
			result.step_mag = hit_magnitude
			result.step = result.step.normalize().mul(hit_magnitude)
			result.collision_normal = edge.normal
		}
	}
}

pub fn test_interval_overlap(a Interval, b Interval) bool {
	return a.min < b.max && b.min < a.max
}

pub fn get_interval_overlap(a Interval, b Interval) f32 {
	if a.max > b.min {
		return a.max - b.min
	}
	if b.max > a.min {
		return a.min - b.max
	}
	return 0
}

pub fn test_point_v_circle(p Vec2, c Circle) bool {
	delta_v := (p - c.center)
	x_sq := delta_v.x * delta_v.x
	y_sq := delta_v.y * delta_v.y
	r_sq := c.r * c.r
	return (x_sq + y_sq) < r_sq
}

pub fn test_point_v_rect(p Vec2, rect Rect) bool {
	return p.x > rect.min.x && p.x < rect.max.x && p.y > rect.min.y && p.y < rect.max.y
}

pub fn test_rect_v_rect(a Rect, b Rect) bool {
	{
		interval_a := Interval{a.min.y, a.max.y}
		interval_b := Interval{b.min.y, b.max.y}
		if !test_interval_overlap(interval_a, interval_b) {
			return false
		}
	}
	{
		interval_a := Interval{a.min.x, a.max.x}
		interval_b := Interval{b.min.x, b.max.x}
		if !test_interval_overlap(interval_a, interval_b) {
			return false
		}
	}
	return true
}

pub fn test_circle_v_circle(a Circle, b Circle) bool {
	// merge one circle into the other so we can { a simple point test }
	expanded_c := Circle{
		center: b.center
		r: a.r + b.r
	}
	return test_point_v_circle(a.center, expanded_c)
}

pub fn test_overlap(a Shape, b Shape) bool {
	// sort the shapes to reduce the test cases
	// if (a.type > b.type) {
	// c: Shape = b;
	// b = a;
	// a = c;
	//}

	assert a is Rect
	return match a {
		Vec2 {
			match b {
				Vec2 { a == b }
				Circle { test_point_v_circle(a, b) }
				Rect { test_point_v_rect(a, b) }
			}
		}
		Circle {
			match b {
				Vec2 { test_point_v_circle(b, a) }
				Circle { test_circle_v_circle(a, b) }
				Rect { test_circle_v_rect(a, b) }
			}
		}
		Rect {
			match b {
				Vec2 { test_point_v_rect(b, a) }
				Circle { test_circle_v_rect(b, a) }
				Rect { test_rect_v_rect(a, b) }
			}
		}
	}
}

fn test_circle_v_rect(a Circle, b Rect) bool {
	{
		corner := Vec2{b.min.x, b.min.y}
		if test_point_v_circle(corner, a) {
			return true
		}
	}
	{
		corner := Vec2{b.min.x, b.max.y}
		if test_point_v_circle(corner, a) {
			return true
		}
	}
	{
		corner := Vec2{b.max.x, b.max.y}
		if test_point_v_circle(corner, a) {
			return true
		}
	}
	{
		corner := Vec2{b.max.x, b.min.y}
		if test_point_v_circle(corner, a) {
			return true
		}
	}
	rect_y := Rect{
		min: Vec2{b.min.x, b.min.y - a.r}
		max: Vec2{b.max.x, b.max.y + a.r}
	}
	if test_point_v_rect(a.center, rect_y) {
		return true
	}
	rect_x := Rect{
		min: Vec2{b.min.x - a.r, b.min.y}
		max: Vec2{b.max.x + a.r, b.max.y}
	}
	if test_point_v_rect(a.center, rect_x) {
		return true
	}
	return false
}

fn get_overlap_point_v_rect(p Vec2, rect Rect) Overlap_Result {
	// start with the left edge
	mut min_axis := shapes.left
	mut min_mag := p.x - rect.min.x
	{
		r_mag := rect.max.x - p.x
		if r_mag < min_mag {
			min_axis = shapes.right
			min_mag = r_mag
		}
	}
	{
		u_mag := rect.max.y - p.y
		if u_mag < min_mag {
			min_axis = shapes.up
			min_mag = u_mag
		}
	}
	{
		d_mag := p.y - rect.min.y
		if d_mag < min_mag {
			min_axis = shapes.down
			min_mag = d_mag
		}
	}
	result := Overlap_Result{
		normal: min_axis
		distance: min_mag
	}
	return result
}

fn get_overlap_point_v_circle(p Vec2, c Circle) Overlap_Result {
	dist := (p - c.center)
	dist_mag := dist.length()
	normal := dist.normalize()
	result := Overlap_Result{normal, c.r - dist_mag}
	return result
}

fn get_overlap(a Shape, b Shape) Overlap_Result {
	return match a {
		Vec2 {
			match b {
				Vec2 { Overlap_Result{} }
				Rect { get_overlap_point_v_rect(a, b) }
				Circle { get_overlap_point_v_circle(a, b) }
			}
		}
		Circle {
			match b {
				Vec2 {
					get_overlap_point_v_circle(b, a).invert()
				}
				Circle {
					p := a.center
					c := b.expand(a.r)
					get_overlap_point_v_circle(p, c)
				}
				Rect {
					get_overlap_circle_v_rect(a, b)
				}
			}
		}
		Rect {
			match b {
				Vec2 { get_overlap_point_v_rect(b, a).invert() }
				Circle { get_overlap_circle_v_rect(b, a).invert() }
				Rect { get_overlap_rect_v_rect(a, b) }
			}
		}
	}
}

fn get_overlap_circle_v_rect(a Circle, b Rect) Overlap_Result {
	if a.center.x > b.max.x && a.center.y > b.max.y {
		corner := Vec2{b.max.x, b.max.y}
		corner_c := Circle{
			center: corner
			r: a.r
		}
		return get_overlap_point_v_circle(a.center, corner_c)
	}
	if a.center.x < b.min.x && a.center.y > b.max.y {
		corner := Vec2{b.min.x, b.max.y}
		corner_c := Circle{
			center: corner
			r: a.r
		}
		return get_overlap_point_v_circle(a.center, corner_c)
	}
	if a.center.x > b.max.x && a.center.y < b.min.y {
		corner := Vec2{b.max.x, b.min.y}
		corner_c := Circle{
			center: corner
			r: a.r
		}
		return get_overlap_point_v_circle(a.center, corner_c)
	}
	if a.center.x < b.min.x && a.center.y < b.min.y {
		corner := Vec2{b.min.x, b.min.y}
		corner_c := Circle{
			center: corner
			r: a.r
		}
		return get_overlap_point_v_circle(a.center, corner_c)
	}
	rect_expanded := Rect{
		min: Vec2{b.min.x - a.r, b.min.y - a.r}
		max: Vec2{b.max.x + a.r, b.max.y + a.r}
	}
	return get_overlap_point_v_rect(a.center, rect_expanded)
}

fn get_overlap_rect_v_rect(a Rect, b Rect) Overlap_Result {
	mut min_distance := f32(math.max_f32)
	mut min_normal := Vec2{}
	{
		distance := a.max.x - b.min.x
		if distance < min_distance {
			min_distance = distance
			min_normal = shapes.left
		}
	}
	{
		distance := b.max.x - a.min.x
		if distance < min_distance {
			min_distance = distance
			min_normal = shapes.right
		}
	}
	{
		distance := a.max.y - b.min.y
		if distance < min_distance {
			min_distance = distance
			min_normal = shapes.down
		}
	}
	{
		distance := b.max.y - a.min.y
		if distance < min_distance {
			min_distance = distance
			min_normal = shapes.up
		}
	}
	result := Overlap_Result{
		distance: min_distance
		normal: min_normal
	}
	return result
}

fn (o Overlap_Result) invert() Overlap_Result {
	return Overlap_Result{o.normal.mul(-1), o.distance}
}

fn lerp_f(a f32, b f32, time f32) f32 {
	return (1 - time) * a + time * b
}

fn rand_in_shape(shape Shape) Vec2 {
	match shape {
		Vec2 {
			return shape
		}
		Rect {
			x := lerp_f(shape.min.x, shape.max.x, rand.f32())
			y := lerp_f(shape.min.y, shape.max.y, rand.f32())
			return Vec2{x, y}
		}
		Circle {
			a := rand.f32() * 2.0 * math.pi
			r := shape.r * math.sqrtf(rand.f32())

			// If you need it in Cartesian coordinates
			x := r * math.cosf(a)
			y := r * math.sinf(a)
			return shape.center + Vec2{x, y}
		}
	}
}

pub fn (r Rect) translate(pos Vec2) Rect {
	return Rect{
		min: Vec2{r.min.x + pos.x, r.min.y + pos.y}
		max: Vec2{r.max.x + pos.x, r.max.y + pos.y}
	}
}

pub fn (c Circle) translate(pos Vec2) Circle {
	return Circle{c.center + pos, c.r}
}

pub fn (s Shape) translate(pos Vec2) Shape {
	return match s {
		Vec2 { s + pos }
		Rect { s.translate(pos) }
		Circle { s.translate(pos) }
	}
}

pub fn (r Rect) scale(scale Vec2) Rect {
	return Rect{
		min: r.min * scale
		max: r.max * scale
	}
}

pub fn (s Shape) bounds() Rect {
	return match s {
		Vec2 {
			Rect{ s, s }
		}
		Rect {
			s.bounds()
		}
		Circle {
			s.bounds()
		}
	}
}

pub fn (c Circle) bounds() Rect {
	return Rect{
		min: Vec2{c.center.x - c.r, c.center.y - c.r}
		max: Vec2{c.center.x + c.r, c.center.y + c.r}
	}
}

pub fn (s Rect) bounds() Rect {
	return s
}

pub fn rect(pos Vec2, width Vec2) Rect {
	return Rect{pos, pos + width}
}

pub fn (a Rect) overlaps(b Rect) bool {
	return test_rect_v_rect(a, b)
}

//
// vector math
//

pub struct Vec2 {
pub mut:
	x f32
	y f32
}

fn (a Vec2) + (b Vec2) Vec2 {
	return Vec2{a.x + b.x, a.y + b.y}
}

fn (a Vec2) - (b Vec2) Vec2 {
	return Vec2{a.x - b.x, a.y - b.y}
}

fn (a Vec2) * (b Vec2) Vec2 {
	return Vec2{(a.x * b.x), (a.y * b.y)}
}

fn (a Vec2) dot(b Vec2) f32 {
	return (a.x * b.x) + (a.y * b.y)
}

pub fn (v Vec2) mul(f f32) Vec2 {
	return Vec2{v.x * f, v.y * f}
}

pub fn (v Vec2) div(f f32) Vec2 {
	return Vec2{v.x / f, v.y / f}
}

pub fn (v Vec2) length_sq() f32 {
	return v.x * v.x + v.y * v.y
}

pub fn (v Vec2) length() f32 {
	return math.sqrtf(v.length_sq())
}

pub fn (v Vec2) normalize() Vec2 {
	return v.div(v.length())
}

pub fn (v Vec2) z(z f32) Vec3 {
	return Vec3{v.x, v.y, z}
}

pub fn (v Vec2) str() string {
	return '{$v.x, $v.y}'
}

pub struct Vec3 {
pub mut:
	x f32
	y f32
	z f32
}

pub fn (a Vec3) + (b Vec3) Vec3 {
	return Vec3{a.x + b.x, a.y + b.y, a.z + b.z}
}

pub fn (a Vec3) - (b Vec3) Vec3 {
	return Vec3{a.x - b.x, a.y - b.y, a.z - b.z}
}

pub fn (v Vec3) mul(f f32) Vec3 {
	return Vec3{v.x * f, v.y * f, v.z * f}
}

pub fn (v Vec3) div(f f32) Vec3 {
	return Vec3{v.x / f, v.y / f, v.z / f}
}

pub fn (v Vec3) length_sq() f32 {
	return v.x * v.x + v.y * v.y + v.z * v.z
}

pub fn (v Vec3) length() f32 {
	return math.sqrtf(v.length_sq())
}

pub fn (v Vec3) normalize() Vec3 {
	return v.div(v.length())
}

pub fn (v Vec3) v4() Vec4 {
	return m4.vec3(v.x, v.y, v.z)
}

pub fn (v Vec3) str() string {
	return '{$v.x, $v.y, $v.z}'
}

pub fn v4(x f32, y f32, z f32, w f32) Vec4 {
	return Vec4{
		e: [x, y, z, w]!
	}
}
