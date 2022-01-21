module debug

import gg {window_size}
import gx

pub struct Debug {
	size   int = 20
	offset int = 20
	cfg gx.TextCfg = gx.TextCfg{
		align: .left
		size: 20
		color: gx.white
		mono: true
	}
	shadow_cfg gx.TextCfg = gx.TextCfg{
		align: .left
		size: 20
		color: gx.black
		mono: true
	}

mut:
	txt []string
	log []string = []string{cap: 4}
}

pub fn (mut d Debug) draw(gg &gg.Context) {
	win := window_size()
	for i in 0 .. d.log.len {
		line := d.log[i]
		x := d.offset
		y := win.height - (i + 1) * d.size - d.offset
		gg.draw_text(x, y, line, d.cfg)
	}
	for i in 0 .. d.txt.len {
		s := d.txt[i]
		x0 := d.offset
		y0 := d.offset + i * d.cfg.size
		x1 := x0+1
		y1 := y0+1
		gg.draw_text(x1, y1, s, d.shadow_cfg)
		gg.draw_text(x0, y0, s, d.cfg)
	}
	d.txt = []
}

// Debug log works like a stream, showing a limited number of recent logs on screen in a FIFO order.
pub fn (mut d Debug) log(s string) {
	if d.log.len == d.log.cap {
		d.log.pop()
	}
	d.log.prepend(s)
}

// Debug lines will appear on screen for 1 frame. Call every frame to monitor a value.
pub fn (mut d Debug) ln(s string) {
	d.txt << s
}
