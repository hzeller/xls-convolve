// Continuously convolve a stream of input data, e.g. to be used as FIR filter.
// For a convolution of WIDTH items, there is
//  - an Array of WIDTH elements for the coefficients.
//  - a Ringbuffer of input data, holding WIDTH elements.
// Goal is that eventually we have proc: With each new sample, it is added to
// the ringbuffer and a convolution step is done over it, emitting one output
// sample.
//
// To limit the area, the convolve() can take a parameter N to
// only do part of the operation starting from an offset. That can be used
// to time-multiplex in the proc (use WIDTH / N cycles to process one
// full convolution.
#![feature(type_inference_v2)]

import std;
import float32;

type ConvolveNumber = float32::F32;

// SIZE is the size we see between read and write, BUF_SIZE is
// next power of two, so that it can easily be addressed with a fixed-bit width
// unsigned. BUF_SIZE needs to be at least 1 more than SIZE
// assert(SIZE < BUF_SIZE)
// assert(is_pow2(BUF_SIZE))
//
// Ideally want to caclulate BUF_SZ: u32 = { std::next_pow2(SIZE + 1) }. Tiv2?
pub struct RingBuffer<SIZE: u32, BUF_SZ: u32> {
    buffer: ConvolveNumber[BUF_SZ],     // TODO: want type template parameter
    write_pos: uN[std::clog2(BUF_SZ)],  // TODO: want as local type CountType = ...
}

// Should be in impl RingBuffer of sorts at some point.
fn RingBuffer_default<SIZE: u32, BUF_SZ: u32 = { std::next_pow2(SIZE + u32:1) }>()
   -> RingBuffer<SIZE, BUF_SZ> {
    RingBuffer<SIZE, BUF_SZ> { ..zero!<RingBuffer<SIZE, BUF_SZ>>() }
}

fn RingBuffer_ReadAtOffset<SIZE: u32, BUF_SZ:u32>(rb: RingBuffer<SIZE, BUF_SZ>,
						  offset: u32)
				      -> ConvolveNumber {
    type CountType = uN[std::clog2(BUF_SZ)];
    rb.buffer[rb.write_pos - SIZE as CountType + offset as CountType]
}

fn RingBuffer_PushValue<SIZE: u32, BUF_SZ: u32>(rb: RingBuffer<SIZE, BUF_SZ>,
						v: ConvolveNumber)
				   -> RingBuffer<SIZE, BUF_SZ> {
    RingBuffer<SIZE, BUF_SZ> {
        buffer: update(rb.buffer, rb.write_pos, v),
        write_pos: rb.write_pos + uN[std::clog2(BUF_SZ)]:1,
    }
}

// Convolve with WIDTH array for coefficient, ringbuffer for samples.
// Only do N operations starting at offset; if N is not given,
// assume N = WIDTH, i.e. convolution over the whole length.
// Note area: Stamps out N copies of fma().
pub fn convolve<WIDTH: u32, RB_BUF_SZ: u32, N: u32 = { WIDTH }>(samples: RingBuffer<WIDTH, RB_BUF_SZ>,
					       coefficients: ConvolveNumber[WIDTH],
					       offset: u32)
     -> ConvolveNumber {
    assert!(offset + N <= WIDTH, "Sweep outside range");
    for (idx, acc): (u32, ConvolveNumber) in u32:0..N {
        float32::fma(coefficients[idx + offset],
	             RingBuffer_ReadAtOffset<WIDTH, RB_BUF_SZ>(samples, idx + offset),
		     acc)
    }(float32::zero(u1:0))
}

// A fully typed-out top() for code generation.
const TOP_WIDTH = u32:32;
fn top(s: RingBuffer<TOP_WIDTH, u32:32>,
       c: ConvolveNumber[TOP_WIDTH]) -> ConvolveNumber {
    convolve(s, c, u32:0)
}

#[test]
fn convolve_test() {
    let coefficients = map(s32[6]:[10, 11, -12, -13, 14, 15],
			   float32::cast_from_fixed_using_rne);

    // TODO: could this be map() initialized ?
    let samples = for (val, samples) in s32[6]:[1, 2, 3, 4, 5, 6] {
        RingBuffer_PushValue(samples, float32::cast_from_fixed_using_rne(val))
    }(RingBuffer_default<u32:6>());

    let result = convolve(samples, coefficients, u32:0);
    let expected = float32::cast_from_fixed_using_rne(s32:104);
    assert_eq(result, expected);

    // Add a few more samples. This will also make the ringbuffer wrap around.
    let samples = for (val, samples) in s32[3]:[12, -1, 7] {
        RingBuffer_PushValue(samples, float32::cast_from_fixed_using_rne(val))
    }(samples);
    // Values in sliding ringbuffer window now [4, 5, 6, 12, -1, 7]

    let result = convolve(samples, coefficients, u32:0);
    let expected = float32::cast_from_fixed_using_rne(s32:-42);
    assert_eq(result, expected);

    // Now let's do that in multiple steps.
    const N = u32:3;
    let part1 = convolve<u32:6, u32:8, N>(samples, coefficients, u32:0);
    let part2 = convolve<u32:6, u32:8, N>(samples, coefficients, N);
    let result = float32::add(part1, part2);
    assert_eq(result, expected);
}
