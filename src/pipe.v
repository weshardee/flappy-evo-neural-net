module main

import kit.shapes { Vec2 }
import rand
import gx

enum Pipe {
	top
	bottom
}

fn (mut app App) spawn_pipes() {
	color := gx.rgb(byte(0.44 * 255), byte(0.81 * 255), byte(0.42 * 255))

	gap_size := pipe_gap_size - app.pipe_cnt - app.gen
	app.pipe_cnt++
	gap_y := rand.f32_in_range(pipe_gap_min, pipe_gap_max - pipe_gap_size)

	x := width
	y1 := gap_y - height
	y2 := gap_y + gap_size

	top := app.ecs.add()
	app.ecs.set<Pipe>(top, Pipe.top)
	app.ecs.set<Sprite>(top, Sprite{
		color: color
		size: Vec2{pipe_width, height}
	})
	app.ecs.set<Pos>(top, Pos{x:x, y:y1})
	app.ecs.set<Vel>(top, pipe_vel)

	bottom := app.ecs.add()
	app.ecs.set<Pipe>(bottom, Pipe.bottom)
	app.ecs.set<Sprite>(bottom, Sprite{
		color: color
		size: Vec2{pipe_width, height}
	})
	app.ecs.set<Pos>(bottom, Pos{x:x, y:y2 })
	app.ecs.set<Vel>(bottom, pipe_vel)
}

// type PipePos = Pipe | Pos

// fn (mut app App) despawn_pipes() {
// 	pipes := app.ecs.query<PipePos>()
// 	width, _ := window_size()

// 	for e in pipes {
// 		pos := app.ecs.get<Pos>(e)
// 		if pos.x < (-width - 128.0) / 2.0 {
// 			app.ecs.remove(e)
// 		}
// 	}
// }
