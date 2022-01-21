module main

import kit.ecs { Ecs, Entity }
import kit.debug { Debug }
import kit.shapes { Rect, Vec2 }
import time
import gg
import gx
import os
import rand
import math

const (
	width         = 1280
	height        = 720

	top_bird_cnt  = 30
	max_birds     = top_bird_cnt * top_bird_cnt + top_bird_cnt
	max_entities  = max_birds + 64

	unit_px       = 64
	bird_size     = unit_px * 1
	pipe_width    = unit_px * 2

	fps           = f32(60)
	dt            = f32(1) / fps

	flap_force    = 7
	gravity       = 0.3

	pipe_interval = int(2 * fps)
	pipe_gap_size = unit_px * 5
	pipe_gap_min  = unit_px * 1
	pipe_gap_max  = height - pipe_gap_min
	pipe_vel      = Vel{
		x: -5
		y: 0
	}

	live_curtain = unit_px * 0.5
	live_box     = shapes.rect(Vec2{-live_curtain, -live_curtain}, Vec2{width + live_curtain * 2,
		height + live_curtain * 2})

	nn_structure = [4, 1] // neuron layers: input, [hidden], output
)

fn main() {
	mut fpath := os.resource_abs_path(os.join_path('..', 'assets', 'fonts', 'FiraMono-Regular.ttf'))

	mut app := &App{}

	// TODO maybe wrap up the initialization in kit
	// so that we can apply common exit shortcuts and stuff
	// like that
	app.gg = gg.new_context(
		user_data: app
		window_title: 'Flappy Bird Genetic Neural Net'
		resizable: true
		width: width
		height: height
		frame_fn: frame
		keydown_fn: keydown
		keyup_fn: keyup
		font_path: fpath // wait_events: true
	)
	app.init()
	app.gg.run()
}

fn frame(mut app App) {
	app.process()
	app.frame_timer.restart()
	app.draw()
}

[live]
fn keydown(code gg.KeyCode, mod gg.Modifier, mut app App) {
	// -- os
	if code == gg.KeyCode.escape
		|| (mod == gg.Modifier.super && code == gg.KeyCode.w)
		|| (mod == gg.Modifier.super && code == gg.KeyCode.q) {
		app.gg.quit()
	}

	// -- game
	if code == gg.KeyCode.space {
		app.player_input.start_flap()
	}
}

[live]
fn keyup(code gg.KeyCode, mod gg.Modifier, mut app App) {
	if code == gg.KeyCode.space {
		app.player_input.stop_flap()
	}
}

// -- entity components

struct Pos {
	Vec2
}

struct Vel {
	Vec2
}

struct Sprite {
	color gx.Color
	size  Vec2
}

// TODO break this up into multiple components?
struct Bird {
pub mut:
	fitness    f32
	multiplier f32
}

struct BirdBrain {
pub mut:
	nn NeuralNetwork = new_nn(nn_structure)
}

struct Input {
mut:
	should_flap bool
	did_flap    bool
}

fn (mut i Input) start_flap() {
	if i.should_flap {
		return
	}
	i.should_flap = true
	i.did_flap = false
}

fn (mut i Input) stop_flap() {
	if !i.should_flap {
		return
	}
	i.should_flap = false
}

struct BirdRecord {
	fit int
	nn  NeuralNetwork
}

// -- application logic
struct App {
mut:
	// Ecs<EntityDef>
	gg    &gg.Context = voidptr(0)
	debug Debug

	gen       int = -1
	gen_frame int

	frame_timer time.StopWatch = time.new_stopwatch()

	phys_accum f64
	phys_timer time.StopWatch = time.new_stopwatch()

	ecs          Ecs = ecs.new_ecs(max_entities)
	player_e     Entity
	player_input Input

	graveyard []BirdRecord
	num_alive int
	pipe_cnt int
}

fn (mut app App) init() {
	// TODO add [flag]
	app.ecs.init_comp<Pos>()
	app.ecs.init_comp<Vel>()
	app.ecs.init_comp<Sprite>()
	app.ecs.init_comp<Bird>()
	app.ecs.init_comp<BirdBrain>()
	app.ecs.init_comp<Input>()

	app.start()
}

[live]
fn (mut app App) process() {
	// accumulate physics time
	app.phys_accum += app.phys_timer.elapsed().seconds()
	app.phys_timer.restart()

	// advance sim if physics dt is passed
	if app.phys_accum > dt {
		app.process_fixed()
	}
	for app.phys_accum > dt {
		app.phys_accum -= dt
	}
}

fn (mut app App) process_fixed() {
	app.gen_frame++

	app.process_spawn_pipes()
	app.process_bird_brain()
	app.process_input_vel()
	app.process_gravity()
	app.process_vel_pos()
	app.process_out_of_bounds()
	app.process_bird_pipe_collisions()
	app.process_check_all_dead()
}

fn (mut app App) process_spawn_pipes() {
	if app.gen_frame % pipe_interval == 0 {
		app.spawn_pipes()
	}
}

fn (mut app App) process_input_vel() {
	for e in app.ecs.query(['Input', 'Vel']) {
		mut input := app.ecs.get<Input>(e)
		if input.should_flap && !input.did_flap {
			input.did_flap = true
			mut vel := app.ecs.get<Vel>(e)
			vel.y = -flap_force
			app.ecs.set(e, vel)
		}
		app.ecs.set(e, input)
	}
}

fn (mut app App) process_gravity() {
	for e in app.ecs.query(['Bird', 'Vel']) {
		mut vel := app.ecs.get<Vel>(e)
		vel.y += gravity
		app.ecs.set<Vel>(e, vel)
	}
}

fn (mut app App) process_vel_pos() {
	for e in app.ecs.query(['Vel', 'Pos']) {
		pos := app.ecs.get<Pos>(e)
		vel := app.ecs.get<Vel>(e)
		app.ecs.set<Pos>(e, Pos{pos.Vec2 + vel.Vec2})
	}
}

fn (mut app App) process_out_of_bounds() {
	for e in app.ecs.query(['Sprite', 'Pos']) {
		body := app.get_body(e)
		if !body.overlaps(live_box) {
			app.memorialize(e)
		}
	}
}

fn (mut app App) process_bird_pipe_collisions() {
	for bird_e in app.ecs.query(['Bird']) {
		bird_body := app.get_body(bird_e)
		for pipe_e in app.ecs.query(['Pipe']) {
			pipe_body := app.get_body(pipe_e)
			if bird_body.overlaps(pipe_body) {
				app.memorialize(bird_e)
			}
		}
	}
}

fn (app App) get_pipe_corners() (f32, f32, f32) {
	mut t := Vec2{math.max_f32, math.max_f32}
	mut b := Vec2{math.max_f32, math.max_f32}

	for e in app.ecs.query(['Pipe', 'Sprite', 'Pos']) {
		pipe := app.ecs.get<Pipe>(e)
		sprite := app.ecs.get<Sprite>(e)
		pos := app.ecs.get<Pos>(e)
		x := pos.x
		if x < 0 {
			continue
		}
		match pipe {
			.top {
				y := sprite.size.y + pos.y
				if x < t.x {
					t = Vec2{x, y}
				}
			}
			.bottom {
				y := pos.y
				if x < b.x {
					b = Vec2{x, y}
				}
			}
		}
	}
	return t.x, t.y, b.y
}

fn (mut app App) process_bird_brain() {
	pipe_x, pipe_y1, pipe_y2 := app.get_pipe_corners()

	for e in app.ecs.query(['BirdBrain', 'Input', 'Pos']) {
		brain := app.ecs.get<BirdBrain>(e)
		bird := app.ecs.get<Pos>(e)

		brain_input := [bird.y, pipe_x, pipe_y1, pipe_y2]
		brain_output := brain.nn.process(brain_input)

		mut input := app.ecs.get<Input>(e)
		if input.did_flap {
			input.stop_flap()
		}
		if brain_output[0] > 0.98 {
			input.start_flap()
		}

		app.ecs.set(e, input)
	}
}

fn (mut app App) process_check_all_dead() {
	app.num_alive = 0
	for _ in app.ecs.query(['Bird']) {
		app.num_alive++
	}
	if app.num_alive == 0 {
		app.start()
	}
}

fn (app App) get_body(e Entity) Rect {
	pos := app.ecs.get<Pos>(e)
	sprite := app.ecs.get<Sprite>(e)
	box := shapes.rect(pos.Vec2, sprite.size)
	return box
}

[live]
fn (mut app App) draw() {
	app.gg.begin()
	for e in app.ecs.query(['Pos', 'Sprite']) {
		pos := app.ecs.get<Pos>(e)
		sprite := app.ecs.get<Sprite>(e)
		app.gg.draw_rect_filled(pos.x, pos.y, sprite.size.x, sprite.size.y, sprite.color)
	}

	app.debug.ln('gen: $app.gen')
	app.debug.ln('frame: $app.gen_frame')
	app.debug.ln('num_alive: $app.num_alive')

	app.debug.draw(app.gg)
	app.gg.end()
}

fn (mut app App) start() {
	app.gen++
	app.gen_frame = 0
	app.pipe_cnt = 0

	// clear any existing pipes
	for e in app.ecs.query(['Pipe']) {
		app.ecs.remove(e)
	}
	app.spawn_pipes()

	mut spawn_cnt := 0

	if app.gen > 0 {
		// sorting the whole thing seems pretty wasteful
		app.graveyard.sort(a.fit > b.fit)
		top := app.graveyard[..top_bird_cnt]
		app.debug.log('gen ${app.gen-1} longest life: ${top[0].fit}')

		// make some clones
		for r in top { 
			e := app.spawn_bird()
			spawn_cnt++
			app.ecs.set(e, BirdBrain{r.nn.clone()})
		}

		// breed them birdies
		for i, top_a in top {
			for top_b in top[i+1..] {
				nn_a := top_a.nn.mutate()
				nn_b := top_b.nn.mutate()
				nn := nn_a.crossover(nn_b)	

				e := app.spawn_bird()
				app.ecs.set(e, BirdBrain{nn})
				spawn_cnt++
			}
		}
		app.graveyard = []
	}
	for spawn_cnt < max_birds {
		e := app.spawn_bird()
		app.ecs.set(e, BirdBrain{})
		spawn_cnt++
	}
}

fn (mut app App) memorialize(e Entity) {
	if app.ecs.has(e, ['Bird', 'BirdBrain']) {
		app.graveyard << BirdRecord{
			fit: app.gen_frame
			nn: app.ecs.get<BirdBrain>(e).nn
		}
	}
	app.ecs.remove(e)
}

fn (mut app App) spawn_bird() Entity {
	e := app.ecs.add()

	// TODO
	r := byte(rand.f32() * 255)
	g := byte(rand.f32() * 255)
	b := byte(rand.f32() * 255)
	app.ecs.set(e, Sprite{
		color: gx.rgb(r, g, b)
		size: Vec2{bird_size, bird_size}
	})
	app.ecs.set(e, Pos{Vec2{unit_px * 1, unit_px * 5}})
	app.ecs.set(e, Vel{Vec2{0, 0}})
	app.ecs.set(e, Bird{})
	app.ecs.set(e, Input{})

	return e
}
