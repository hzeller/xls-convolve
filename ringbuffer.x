//usr/bin/env -S make ringbuffer.test; exit   # just run as 'script' to run tests

// A Generic ringbuffer implementation.

#![feature(generics)]
#![feature(type_inference_v2)]

import std;

// SIZE is the fixed size we see between read and write, BUF_SIZE is
// next power of two, so that it can easily be addressed with a fixed-bit width
// unsigned. If SIZE is a power of two already, ReadAt() is cheaper.
// There is no read pos, as it is by definition always SIZE elements behind
// write and we always ReadAt() from there with an offset.
pub struct RingBuffer<T: type, SIZE: u32, BUF_SZ: u32 = {std::next_pow2(SIZE)}> {
    //type CountType = uN[std::clog2(BUF_SZ)];  // would be good here
    buffer: T[BUF_SZ],
    write_pos: uN[std::clog2(BUF_SZ)],  // TODO: want as local type CountType = ...
}

impl RingBuffer<T, SIZE, BUF_SZ> {
    const INTERNAL_BUF_SZ = BUF_SZ;
    type CountType = uN[std::clog2(BUF_SZ)];

    fn default() -> RingBuffer<T, SIZE, BUF_SZ> {
        assert!(SIZE <= BUF_SZ, "Buffer size calculation wrong");
        assert!(std::is_pow2(BUF_SZ), "Buffer needs to be a power of 2");

        RingBuffer<T, SIZE, BUF_SZ> { ..zero!<RingBuffer<T, SIZE, BUF_SZ>>() }
    }

    // Read value SIZE elements behind write pos, plus offset.
    fn ReadAt(self, offset: u32) -> T {
        // Read pos is always SIZE behind; if SIZE == BUF_SIZE we start reading
        // at exact the position the next write will overwrite
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
fn ringbuffer_initialized_with_zero_test() {
    const BUFFER_SIZE = u32:9;

    type TestType = RingBuffer<u32, BUFFER_SIZE>;

    // A fresh buffer should be all zeroes.
    let buffer = TestType::default();
    map(0..BUFFER_SIZE, |i| {
	assert_eq(buffer.ReadAt(i), u32:0);
    });
}

#[test]
fn ringbuffer_functionality_test() {
    const BUFFER_SIZE = u32:9;

    type TestType = RingBuffer<u32, BUFFER_SIZE>;
    //type CountType = TestType::CountType;  // this doesn't work yet
    type CountType = uN[std::clog2(TestType::INTERNAL_BUF_SZ)];

    // Let's push some values into the buffer, that are derived from the
    // index, so they are easy to test.
    let buffer = for (val, samples) in u32:10..(BUFFER_SIZE + 10) {
        samples.PushValue(val)
    }(TestType::default());

    assert_eq(buffer.write_pos, BUFFER_SIZE as CountType);
    map(0..BUFFER_SIZE, |i|{
	assert_eq(buffer.ReadAt(i as u32), (i + 10) as u32);
    });

    // Adding one more value and now we start reading where value is one more
    let buffer = buffer.PushValue(BUFFER_SIZE + 10);
    map(0..BUFFER_SIZE, |i|{
	assert_eq(buffer.ReadAt(i as u32), (i + 1 + 10) as u32);
    });
}
