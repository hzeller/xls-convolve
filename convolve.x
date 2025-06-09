import std;
import float32;

type ConvolveNumber = float32::F32;

// SIZE is the size we see between read and write, BUF_SIZE is
// next power of two, so that it can easily be addressed with a fixed-bit width
// unsigned. BUF_SIZE needs to be at least 1 more than SIZE
// assert(SIZE < BUF_SIZE)
// assert(is_pow2(BUF_SIZE))
//
// Ideally want to caclulate BUF_SZ: u32 = { std::next_pow2(SIZE + 1) }, but
// that only works with tiv2 (but: https://github.com/google/xls/issues/2358)
pub struct RingBuffer<SIZE: u32, BUF_SZ: u32> {
    buffer: ConvolveNumber[BUF_SZ],     // TODO: want type template parameter
    write_pos: uN[std::clog2(BUF_SZ)],  // TODO: want as local type CountType = ...
}

// Should be in impl RingBuffer of sorts at some point.
fn RingBuffer_default<SIZE: u32, BUF_SZ: u32>() -> RingBuffer<SIZE, BUF_SZ> {
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

// Convolve with ärrays for samples and coefficients
pub fn convolve<WIDTH: u32>(samples: ConvolveNumber[WIDTH],
			    coefficients: ConvolveNumber[WIDTH])
     -> ConvolveNumber {
    for (idx, acc): (u32, ConvolveNumber) in u32:0..WIDTH {
        float32::fma(coefficients[idx], samples[idx], acc)
    }(float32::zero(u1:0))
}

// Convolve with array for coefficient, ringbuffer for samples.
// Only do N operations starting at offset.
pub fn convolve_rb<WIDTH: u32, RB_BUF_SZ: u32, N: u32 = { WIDTH }>(samples: RingBuffer<WIDTH, RB_BUF_SZ>,
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
    convolve_rb(s, c, u32:0)
}

#[test]
fn convolve_test() {
    let coefficients = map(s32[6]:[10, 11, -12, -13, 14, 15],
			   float32::cast_from_fixed_using_rne);

    let samples = map(s32[6]:[1, 2, 3, 4, 5, 6],
		      float32::cast_from_fixed_using_rne);
    let result = convolve(samples, coefficients);
    let expected = float32::cast_from_fixed_using_rne(s32:104);
    assert_eq(result, expected);
}


#[test]
fn convolve_rb_test() {
    let coefficients = map(s32[6]:[10, 11, -12, -13, 14, 15],
			   float32::cast_from_fixed_using_rne);

    // TODO: could this be map() initialized ?
    let samples = for (val, samples) in s32[6]:[1, 2, 3, 4, 5, 6] {
        RingBuffer_PushValue(samples, float32::cast_from_fixed_using_rne(val))
    }(RingBuffer_default<u32:6, u32:8>());

    let result = convolve_rb(samples, coefficients, u32:0);
    let expected = float32::cast_from_fixed_using_rne(s32:104);
    assert_eq(result, expected);

    // Add a few more samples. This will also make the ringbuffer wrap around.
    let samples = for (val, samples) in s32[3]:[12, -1, 7] {
        RingBuffer_PushValue(samples, float32::cast_from_fixed_using_rne(val))
    }(samples);
    // Values in sliding ringbuffer window now [4, 5, 6, 12, -1, 7]

    let result = convolve_rb(samples, coefficients, u32:0);
    let expected = float32::cast_from_fixed_using_rne(s32:-42);
    assert_eq(result, expected);

    // Now let's do that in multiple steps.
    const N = u32:3;
    let part1 = convolve_rb<u32:6, u32:8, N>(samples, coefficients, u32:0);
    let part2 = convolve_rb<u32:6, u32:8, N>(samples, coefficients, N);
    let result = float32::add(part1, part2);
    assert_eq(result, expected);
}
