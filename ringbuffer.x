//usr/bin/env -S make ringbuffer.test; exit   # just run as 'script' to run tests

// A Generic ringbuffer implementation.

#![feature(generics)]

import std;

// SIZE is the fixed size we see between read and write, BUF_SIZE is
// next power of two, so that it can easily be addressed with a fixed-bit width
// unsigned. If SIZE is a power of two already, ReadAt() is cheaper.
// There is no read pos, as it is by definition always SIZE elements behind
// write and we always ReadAt() from there with an offset.
pub struct RingBuffer<T: type, SIZE: u32, BUF_SZ: u32 = {std::next_pow2(SIZE)}> {
    // type CountType = uN[std::clog2(BUF_SZ)];  // would be good here
    buffer: T[BUF_SZ],
    write_pos: uN[std::clog2(BUF_SZ)],  // TODO: want as local type CountType = ...
}

pub impl RingBuffer<T, SIZE, BUF_SZ> {
    const INTERNAL_BUF_SZ = BUF_SZ;
    type CountType = uN[std::clog2(BUF_SZ)];

    fn default() -> Self {
        assert!(SIZE <= BUF_SZ, "Smaller buffer than required by size");
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
    fn PushValue(self, v: T) -> Self {
        RingBuffer<T, SIZE, BUF_SZ> {
            buffer: update(self.buffer, self.write_pos, v),
            write_pos: self.write_pos + 1,
        }
    }
}

fn ringbuffer_initialized_with_zero<BUFFER_SIZE: u32>() {
    type TestType = RingBuffer<u32, BUFFER_SIZE>;

    // A fresh buffer should be all zeroes.
    let buffer = TestType::default();
    map(0..BUFFER_SIZE, |i| { assert_eq(buffer.ReadAt(i), 0); });
}

#[test]
fn ringbuffer_initialized_with_zero_test() {

    // commented out due to https://github.com/google/xls/issues/4895
    // ringbuffer_initialized_with_zero<7>();
    // ringbuffer_initialized_with_zero<8>();
    // ringbuffer_initialized_with_zero<9>();
}

fn ringbuffer_functionality<BUFFER_SIZE: u32>() {
    type TestType = RingBuffer<u32, BUFFER_SIZE>;
    //type CountType = TestType::CountType;  // this doesn't work yet #4898
    type CountType = uN[std::clog2(TestType::INTERNAL_BUF_SZ)];

    // Let's push some values into the buffer, that are derived from the
    // index, so they are easy to test.
    let buffer = for (val, samples) in 10..(BUFFER_SIZE + 10) {
        samples.PushValue(val)
    }(TestType::default());

    assert_eq(buffer.write_pos, BUFFER_SIZE as CountType);
    map(0..BUFFER_SIZE, |i| { assert_eq(buffer.ReadAt(i), i + 10); });

    // Adding one more value and now we start reading where value is one more
    let buffer = buffer.PushValue(BUFFER_SIZE + 10);
    map(0..BUFFER_SIZE, |i| { assert_eq(buffer.ReadAt(i), i + 1 + 10); });
}

#[test]
fn ringbuffer_functionaliy_test() {
    ringbuffer_functionality<7>();
    ringbuffer_functionality<8>();
    ringbuffer_functionality<9>();
    ringbuffer_functionality<15>();
    ringbuffer_functionality<16>();
    ringbuffer_functionality<17>();
}
