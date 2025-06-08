import float32;

type ConvolveNumber = float32::F32;

pub fn convolve<WIDTH: u32>(samples: ConvolveNumber[WIDTH],
                            coefficients: ConvolveNumber[WIDTH])
    -> ConvolveNumber {
    for (idx, acc): (u32, ConvolveNumber) in u32:0..WIDTH {
        let product = float32::mul(coefficients[idx], samples[idx]);
        float32::add(acc, product)
    }(float32::zero(u1:0))
}

const TOP_WIDTH = u32:32;

fn top(s: ConvolveNumber[TOP_WIDTH], c: ConvolveNumber[TOP_WIDTH]) -> ConvolveNumber {
    convolve(s, c)
}

#[test]
fn convolve_test() {
    let samples = map(s32[6]:[1, 2, 3, 4, 5, 6],
                      float32::cast_from_fixed_using_rne);
    let coefficients = map(s32[6]:[10, 11, -12, -13, 14, 15],
                           float32::cast_from_fixed_using_rne);

    let result = convolve(samples, coefficients);
    let expected = float32::cast_from_fixed_using_rne(s32:104);
    assert_eq(result, expected);
}
