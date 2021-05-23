## zip-8

zip-8 is a CHIP-8 emulator written in Zig with an uninspired name. It compiles
to WebAssembly.

This project was my first time dabbling with Zig and first published emulator.
Most of the details on implementation were informed by the links found in
[references](#references).

I don't intend to maintain this project as I've hit my goals on it, but if you
would like to make a PR to help improve the Zig or emulation code, I'm open to
discussion :)

## Running

    zig run main.zig

## Run tests

    TODO

## TODO

- Where would Union be useful? [union](https://ziglang.org/documentation/0.7.1/#union)

## References

- [Chip-8 Technical Reference](http://devernay.free.fr/hacks/chip8/C8TECH10.HTM)
- [Writing a CHIP-8 Emulator](https://tobiasvl.github.io/blog/write-a-chip-8-emulator/)
- [chip 8 rust/wasm](https://github.com/wtfleming/chip-8-rust-wasm/blob/master/chip_8_wasm/crate/src/lib.rs)
