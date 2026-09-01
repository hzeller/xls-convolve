//usr/bin/env -S make convolve.test; exit   # just run as 'script' to run tests

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
#![feature(generics)]
#![feature(type_inference_v2)]

import std;
import float32;
import ringbuffer as rb;

type ConvolveNumber = float32::F32;

// Convolve with WIDTH array for coefficient, ringbuffer for samples.
// Only do N operations starting at offset; if N is not given,
// assume N = WIDTH, i.e. convolution over the whole length.
// Note area: Stamps out N copies of fma().
pub fn convolve<WIDTH: u32, RB_BUF_SZ: u32, N: u32 = {WIDTH}>
    (samples: rb::RingBuffer<ConvolveNumber, WIDTH, RB_BUF_SZ>, coefficients: ConvolveNumber[WIDTH], offset: u32)
    -> ConvolveNumber {
    assert!(offset + N <= WIDTH, "Sweep outside range");
    for (idx, acc): (u32, ConvolveNumber) in 0..N {
        float32::fma(coefficients[idx + offset], samples.ReadAtOffset(idx + offset), acc)
    }(float32::zero(u1:0))
}

// A fully typed-out top() for code generation.
const TOP_WIDTH = u32:32;

fn top(s: rb::RingBuffer<ConvolveNumber, TOP_WIDTH>, c: ConvolveNumber[TOP_WIDTH]) -> ConvolveNumber {
    convolve(s, c, 0)
}

#[test]
fn convolve_test() {
    let coefficients = map(s32[6]:[10, 11, -12, -13, 14, 15], float32::cast_from_fixed_using_rne);

    // TODO: could this be map() initialized ?
    let samples = for (val, samples) in s32[6]:[1, 2, 3, 4, 5, 6] {
        samples.PushValue(float32::cast_from_fixed_using_rne(val))
    }(rb::RingBuffer<ConvolveNumber, 6>::default());

    let result = convolve(samples, coefficients, 0);
    let expected = float32::cast_from_fixed_using_rne(s32:104);
    assert_eq(result, expected);

    // Add a few more samples. This will also make the ringbuffer wrap around.
    let samples = for (val, samples) in s32[3]:[12, -1, 7] {
        samples.PushValue(float32::cast_from_fixed_using_rne(val))
    }(samples);
    // Values in sliding ringbuffer window now [4, 5, 6, 12, -1, 7]

    let result = convolve(samples, coefficients, 0);
    let expected = float32::cast_from_fixed_using_rne(s32:-42);
    assert_eq(result, expected);

    // Now let's do that in multiple steps.
    const N = u32:3;
    let part1 = convolve<6, 8, N>(samples, coefficients, 0);
    let part2 = convolve<6, 8, N>(samples, coefficients, N);
    let result = float32::add(part1, part2);
    assert_eq(result, expected);
}
