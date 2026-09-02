//usr/bin/env -S make ringbuffer.test; exit   # just run as 'script' to run tests

// A Generic ringbuffer implementation.

#![feature(generics)]
#![feature(type_inference_v2)]

import std;

// SIZE is the fixed size we see between read and write, BUF_SIZE is
// next power of two, so that it can easily be addressed with a fixed-bit width
// unsigned. BUF_SIZE needs to be at least 1 more than SIZE
// There is no read pos, as it is by definition always SIZE elements behind
// write.
pub struct RingBuffer<T: type, SIZE: u32, BUF_SZ: u32 = {std::next_pow2(SIZE + 1)}> {
    //type CountType = uN[std::clog2(BUF_SZ)];  // would be good here
    buffer: T[BUF_SZ],
    write_pos: uN[std::clog2(BUF_SZ)],  // TODO: want as local type CountType = ...
}

impl RingBuffer<T, SIZE, BUF_SZ> {
    type CountType = uN[std::clog2(BUF_SZ)];

    fn default() -> RingBuffer<T, SIZE, BUF_SZ> {
        assert!(SIZE <= BUF_SZ, "Buffer size calculation wrong");
        assert!(std::is_pow2(BUF_SZ), "Buffer needs to be a power of 2");
        RingBuffer<T, SIZE, BUF_SZ> { ..zero!<RingBuffer<T, SIZE, BUF_SZ>>() }
    }

    // Read value SIZE elements behind write pos, plus offset.
    fn ReadAtOffset(self, offset: u32) -> T {
        self.buffer[self.write_pos - SIZE as CountType + offset as CountType]
    }

    // Push value to ring buffer and return modified buffer
    fn PushValue(self, v: T) -> RingBuffer<T, SIZE, BUF_SZ> {
        RingBuffer<T, SIZE, BUF_SZ> {
            buffer: update(self.buffer, self.write_pos, v),
            write_pos: self.write_pos + 1,
        }
    }
}

#[test]
fn ringbuffer_test() {
    let buffer = RingBuffer<u32, 7>::default();

    let zero_value = u32:0;
    // Default is just filled with zeroes
    assert_eq(buffer.ReadAtOffset(0), zero_value);
    assert_eq(buffer.ReadAtOffset(1), zero_value);
    assert_eq(buffer.write_pos, 0);

    let buffer = for (val, samples) in u32[6]:[1, 2, 3, 4, 5, 6] {
        samples.PushValue(val)
    }(RingBuffer<u32, 6>::default());

    assert_eq(buffer.write_pos, 6);
    map(0..6, |i|{
	assert_eq(buffer.ReadAtOffset(i as u32), (i + 1) as u32);
    });

    // Adding one more value and now we start reading where value is 2
    let buffer = buffer.PushValue(7);
    map(0..6, |i|{
	assert_eq(buffer.ReadAtOffset(i as u32), (i + 2) as u32);
    });
}
