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
#![feature(type_inference_v2)]

import std;
import float32;

type ConvolveNumber = float32::F32;

// SIZE is the fixed size we see between read and write, BUF_SIZE is
// next power of two, so that it can easily be addressed with a fixed-bit width
// unsigned. BUF_SIZE needs to be at least 1 more than SIZE
// There is no read pos, as it is by definition always SIZE elements behind
// write.
pub struct RingBuffer<SIZE: u32, BUF_SZ: u32 = {std::next_pow2(SIZE + 1)}> {
    //type CountType = uN[std::clog2(BUF_SZ)];  // would be good here
    buffer: ConvolveNumber[BUF_SZ],  // TODO: want type template parameter
    write_pos: uN[std::clog2(BUF_SZ)],  // TODO: want as local type CountType = ...
}

impl RingBuffer<SIZE, BUF_SZ> {
    type CountType = uN[std::clog2(BUF_SZ)];

    fn default() -> RingBuffer<SIZE, BUF_SZ> {
	//assert!(SIZE <= BUF_SZ, "Buffer size calculation wrong");
	//assert!(std::is_pow2(BUF_SZ), "Buffer needs to be a power of 2");
        RingBuffer<SIZE, BUF_SZ> { ..zero!<RingBuffer<SIZE, BUF_SZ>>() }
    }

    // Read value SIZE elements behind write pos, plus offset.
    fn ReadAtOffset(self, offset: u32) -> ConvolveNumber {
        self.buffer[self.write_pos - SIZE as CountType + offset as CountType]
    }

    // Push value to ring buffer and return modified buffer
    fn PushValue(self, v: ConvolveNumber) -> RingBuffer<SIZE, BUF_SZ> {
        RingBuffer<SIZE, BUF_SZ> {
            buffer: update(self.buffer, self.write_pos, v),
            write_pos: self.write_pos + 1,
        }
    }
}

// Convolve with WIDTH array for coefficient, ringbuffer for samples.
// Only do N operations starting at offset; if N is not given,
// assume N = WIDTH, i.e. convolution over the whole length.
// Note area: Stamps out N copies of fma().
pub fn convolve<WIDTH: u32, RB_BUF_SZ: u32, N: u32 = {WIDTH}>
    (samples: RingBuffer<WIDTH, RB_BUF_SZ>, coefficients: ConvolveNumber[WIDTH], offset: u32)
    -> ConvolveNumber {
    assert!(offset + N <= WIDTH, "Sweep outside range");
    for (idx, acc): (u32, ConvolveNumber) in 0..N {
        float32::fma(coefficients[idx + offset], samples.ReadAtOffset(idx + offset), acc)
    }(float32::zero(u1:0))
}

// A fully typed-out top() for code generation.
const TOP_WIDTH = u32:32;

fn top(s: RingBuffer<TOP_WIDTH>, c: ConvolveNumber[TOP_WIDTH]) -> ConvolveNumber {
    convolve(s, c, 0)
}

#[test]
fn ringbuffer_test() {
    let buffer = RingBuffer<7>::default();

    let zero_value = float32::cast_from_fixed_using_rne(s32:0);
    // Default is just filled with zeroes
    assert_eq(buffer.ReadAtOffset(0), zero_value);
    assert_eq(buffer.ReadAtOffset(1), zero_value);
    assert_eq(buffer.write_pos, 0);

    let buffer = for (val, samples) in s32[6]:[1, 2, 3, 4, 5, 6] {
        samples.PushValue(float32::cast_from_fixed_using_rne(val))
    }(RingBuffer<6>::default());

    let test_value = float32::cast_from_fixed_using_rne(s32:3);
    assert_eq(buffer.write_pos, 6);
    map(0..6, |i|{
	assert_eq(buffer.ReadAtOffset(i as u32),
		  float32::cast_from_fixed_using_rne((i + 1) as s32));
    });
}

#[test]
fn convolve_test() {
    let coefficients = map(s32[6]:[10, 11, -12, -13, 14, 15], float32::cast_from_fixed_using_rne);

    // TODO: could this be map() initialized ?
    let samples = for (val, samples) in s32[6]:[1, 2, 3, 4, 5, 6] {
        samples.PushValue(float32::cast_from_fixed_using_rne(val))
    }(RingBuffer<6>::default());

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
