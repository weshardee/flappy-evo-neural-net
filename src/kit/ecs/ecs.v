module ecs

// Uniquely identifies an entity by its index in the table of components and by 'generation' counter
// which tracks the number of times given index has been reused.
pub struct Entity {
 idx int
	gen int
}

// Stores values for a registered component
struct Comp<T> {
mut:
	vals []T
}

pub struct Ecs {
mut:
	cap int
	// linked list of open entities available to be used
	next_available_ll []int
	next_available    int
	// defines which components are active for a given entity
	def []int
	// tracks how many times a given entity id has been used
	gen []int
	// the table of components for each entity
	comps map[string]&byte
	flags map[string]int
	// counts the number of registerd comps - used to generate flags
	num_comps int
}

// Generates a new Ecs with the specified size
pub fn new_ecs(cap int) Ecs {
	def := []int{len: cap}
	gen := []int{len: cap}
	mut next_available_ll := []int{len: cap, init: it + 1}
	next_available_ll[cap - 1] = -1
	return Ecs{
		cap: cap
		next_available_ll: next_available_ll
		def: def
		gen: gen
	}
}

// Registers a comp for use in the ecs
pub fn (mut ecs Ecs) init_comp<T>() {
	comp := &Comp<T>{[]T{len: ecs.cap}}
	ecs.comps[T.name] = comp
	ecs.flags[T.name] = 1 << ecs.num_comps
	ecs.num_comps++
}

// Gets a new entity identifier from the ecs and makes that entity active
pub fn (mut ecs Ecs) add() Entity {
	i := ecs.next_available
	ecs.next_available = ecs.next_available_ll[i]
	return Entity{i, ecs.gen[i]}
}

// Deactivites the entity specified by the given entity identifier
pub fn (mut ecs Ecs) remove(e Entity) {
	i := e.idx
	assert ecs.gen[i] == e.gen
	ecs.def[i] = 0
	ecs.gen[i]++
	ecs.next_available_ll[i] = ecs.next_available
	ecs.next_available = i
}

// Gets the value of the specified comp for a given entity
pub fn (ecs Ecs) get<T>(e Entity) T {
	i := int(e.idx)
	assert ecs.gen[i] == e.gen
	vals := unsafe { &Comp<T>(ecs.comps[T.name]).vals }
	return vals[i]
}

// Sets a component value for the specified entity. Also, registers
// that the entity has the specified component.
pub fn (mut ecs Ecs) set<T>(e Entity, val T) {
	i := int(e.idx)
	assert ecs.gen[i] == e.gen
	if T.name !in ecs.comps {
		ecs.init_comp<T>()
	}
	ecs.def[i] |= ecs.flags[T.name]
	mut vals := unsafe { &Comp<T>(ecs.comps[T.name]).vals }
	vals[i] = val
}

//
// iteration
//

struct QueryIterator {
	ecs &Ecs
	def int
mut:
	idx int
}

fn (mut q QueryIterator) next() ?Entity {
	if q.idx >= q.ecs.cap {
		return error('')
	}
	for q.idx < q.ecs.cap {
		i := q.idx
		q.idx++
		if q.def & q.ecs.def[i] == q.def {
			return Entity{i, q.ecs.gen[i]}
		}
	}
	return error('')
}

// TODO cache frequent queries
pub fn (ecs Ecs) query(comps []string) QueryIterator {
	mut def := 0
	for comp_str in comps {
		def |= ecs.flags[comp_str]
	}
	return QueryIterator{&ecs, def, 0}
}

pub fn (ecs Ecs) has(e Entity, comps[]string) bool {
	i := int(e.idx)
	assert ecs.gen[i] == e.gen
	
	mut def := 0
	for comp_str in comps {
		def |= ecs.flags[comp_str]
	}
	return def & ecs.def[i] == def
}
