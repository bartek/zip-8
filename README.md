## zip-8

zip-8 is a CHIP-8 emulator written in [Zig](https://ziglang.org/). This project is currently a work in
progress.

This project is my first time dabbling with Zig and my first emulation project.
Most of the details on implementation were informed by the links found in
[references](#references).

## Running

    zig build run

## TODO

- Non-naive timers
- Sound (beep above 0, might be annoying)
- Keyboard input
- Improve debugging, flags when building (e.g. specifying ROM)
- Tests? (The CHIP-8 Test Roms offer plenty of coverage)

## Aspirational

- [Add XO-CHIP support](https://tobiasvl.github.io/blog/write-a-chip-8-emulator/#add-xo-chip-support)

## References

- [Chip-8 Technical Reference](http://devernay.free.fr/hacks/chip8/C8TECH10.HTM)
- [Writing a CHIP-8 Emulator](https://tobiasvl.github.io/blog/write-a-chip-8-emulator/)
