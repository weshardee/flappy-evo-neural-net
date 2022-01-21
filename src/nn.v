module main

import rand
import math

fn sigmoid(x f32) f32 {
	return 1.0 / (1.0 + math.powf(math.e, -x))
}

pub struct NeuralNetwork {
	pub mut:
	structure []int
	weights []f32
}

pub fn new_nn(structure []int) NeuralNetwork {
	mut num_weights := int(0)
	for layer_i in 0 .. structure.len - 1 {
		num_nodes_curr_layer := structure[layer_i]
		num_nodes_next_layer := structure[layer_i + 1]
		num_weights += num_nodes_curr_layer * num_nodes_next_layer
	}
	weights := []f32{len: num_weights, init: rand.f32_in_range(-1, 1)}
	return NeuralNetwork{structure, weights}
}

pub fn (n NeuralNetwork) process(input []f32) []f32 {
	first_layer_len := n.structure[1]
	mut curr_values := []f32{len: first_layer_len}
	mut prev_values := input.clone()

	mut weight_idx := 0
	for curr_i in 0..curr_values.len {
		// sum up all inputs for the current node
		mut sum := f32(0)
		for prev_i in 0..prev_values.len {
			weight := n.weights[weight_idx]
			weight_idx++

			sum += weight * prev_values[prev_i]
		}
		// apply the sigmoid function to the sum
		curr_values[curr_i] = sigmoid(sum)
	}

	return curr_values
}

fn (n NeuralNetwork) mutate() NeuralNetwork {
	mut result := n.clone()
	for mut w in result.weights {
		if rand.f32() > 0.88 {
			w *= rand.f32_in_range(-1.0, 1.0)
		}
	}
	return result
}

fn (n NeuralNetwork) clone() NeuralNetwork {
	mut result := NeuralNetwork{
		n.structure.clone()
		n.weights.clone()
	} 
	return result
}


fn (a NeuralNetwork) crossover(b NeuralNetwork) NeuralNetwork {
	assert a.structure == b.structure
	mut result := a.clone()

	for i, val in result.weights {
		// averaging smells wrong... maybe randomize which parent we take the weight from? or rand lerp?
		result.weights[i] = (val + b.weights[i]) / 2
	}	

	return result
}
