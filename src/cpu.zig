const std = @import("std");
const time = std.time;
const memory = @import("./memory.zig");
const display = @import("./display.zig");
const keyboard = @import("./keyboard.zig");
const utils = @import("./utils.zig");

const Allocator = std.mem.Allocator;
const warn = std.log.warn;

// CPU is the CHIP-8's CPU
pub const CPU = struct {
    allocator: *Allocator,

    // CHIP-8 Programs are loaded into memory starting at address 200
    pc: u16,
    memory: *memory.Memory,
    display: *display.Display,
    keyboard: *keyboard.Keyboard,

    // A Stack for 16-bit addresses, which is used to call subroutines/functions
    // and return from them.
    stack: [16]u16,
    sp: u8,

    // Delay Timer
    dt: u8,

    // Sound timer
    st: u8,

    // Index register
    i: u16,

    // 16 8-bit general purpose variable registers numbered 0 through F
    v: [16]u8,

    pub fn init(cpu: *CPU, allocator: *Allocator, mem: *memory.Memory, dis: *display.Display) void {
        cpu.allocator = allocator;
        cpu.memory = mem;
        cpu.display = dis;

        var kb = allocator.create(keyboard.Keyboard) catch {
            warn("\ncould not allocate memory for Keyboard", .{});
            return;
        };
        defer kb.deinit(allocator);
        kb.init();
        cpu.keyboard = kb;

        cpu.pc = 0x0200;
        cpu.sp = 0;

        cpu.dt = 0;
        cpu.st = 0;

        cpu.i = 0x000;
        std.mem.set(u8, cpu.v[0..], 0);
    }

    pub fn deinit(cpu: *CPU, alloc: *std.mem.Allocator) void {
        alloc.destroy(cpu);
    }

    // tick ticks the CPU
    pub fn tick(cpu: *CPU) void {
        var opcode = cpu.fetch();
        var instruction = cpu.execute(opcode);

        // Decrement delay and sound timers.
        // FIXME: This is likely a naive approach. These should be independent
        // of the CPU tick but also, this may be sufficient for CHIP-8
        if (cpu.dt > 0) {
            cpu.dt -= 1;
        }

        if (cpu.st > 0) {
            cpu.st -= 1;
        }

        return;
    }

    // fetch reads the instruction the PC is currently pointing at
    // An instruction is two bytes, so two successive bytes are read from memory
    // and then combined
    // The first byte is bit-shifted to the left and then ORed with the second
    // byte. The end result is a 16 bit opcode
    fn fetch(cpu: *CPU) u16 {
        var high: u16 = cpu.memory.read(cpu.pc);
        var low: u16 = cpu.memory.read(cpu.pc + 1);

        cpu.pc += 2;

        return (high << 8) | low;
    }

    // execute decodes the opcode to identify the instruction.
    // This is done by first obtaining the nibble (or half-byte), which is the
    // first hexadecimal number.
    fn execute(cpu: *CPU, opcode: u16) void {
        warn("instruction 0x{x}", .{opcode});
        var nibble = opcode & 0xF000;
        switch (nibble) {
            0x0000 => {
                var rest = opcode & 0x000F;
                // The rest of the nibble
                switch (rest) {
                    0x0000 => {
                        // Clear Screen
                        cpu.display.reset();
                    },
                    0x00E => {
                        // Return from a subroutine
                        cpu.sp -= 1;
                        cpu.pc = cpu.stack[cpu.sp];
                        cpu.stack[cpu.sp] = 0;
                    },
                    else => {
                        warn("waiting", .{});
                        utils.waitForInput();
                    },
                }
            },
            0x1000 => {
                // 1NNN: Jump. Jump PC to NNN
                cpu.pc = @intCast(u12, opcode & 0x0FFF);
            },
            0x2000 => {
                // 2NNN: Call sub routine at location NNN

                // First push the current PC to the stack, so the subroutine can
                // return later.
                cpu.stack[cpu.sp] = cpu.pc;
                cpu.sp += 1;
                cpu.pc = opcode & 0x0FFF;
            },
            0x3000 => {
                // 3XNN: Skip one instruction if the value in VX is equal to NN
                var x = (opcode & 0x0F00) >> 8;
                var nn = opcode & 0x00FF;
                if (cpu.v[x] == nn) {
                    // Jump ahead
                    cpu.pc += 2;
                }
            },
            0x4000 => {
                // 4XNN: Skip one instruction if the value in VX is *not* equal to NN
                var x = (opcode & 0x0F00) >> 8;
                var nn = opcode & 0x00FF;
                if (cpu.v[x] != nn) {
                    // Jump ahead
                    cpu.pc += 2;
                }
            },
            0x5000 => {
                // 5XY0: Skips if the value in VX and VY are equal
                var x = (opcode & 0x0F00) >> 8;
                var y = (opcode & 0x00F0) >> 4;
                if (cpu.v[x] == cpu.v[y]) {
                    cpu.pc += 2;
                }
            },
            0xa000 => {
                // Set index register to NNN
                var nnn = opcode & 0x0FFF;
                cpu.i = nnn;
            },
            0xb000 => {
                // BNNN: Jump with offset
                // Ambiguous. Jump to the address XNN, plus the value in the
                // register VX
                // Non-quirk implementation is to simply add V0
                var a = opcode & 0x0FFF;
                cpu.pc = a + cpu.v[0x0];
            },
            0xc000 => {
                // CXNN: Random
                var x = (opcode & 0x0F00) >> 8;
                var nn = @intCast(u8, opcode & 0x00FF);

                var rng = std.rand.DefaultPrng.init(@intCast(u64, time.milliTimestamp()));
                const r = rng.random.intRangeLessThan(u8, 0, 255);

                cpu.v[x] = r & nn;
            },
            0xd000 => {
                // DXYN
                // Draw an N pixels tall sprite from the memory location that
                // the I index register is holding to the screen, at the horizontal X
                // coordinate in VX register and the Y coordinate in VY register

                // Organize X, Y, and N
                var vx = @intCast(usize, cpu.v[(opcode & 0x0F00) >> 8]);
                var vy = @intCast(usize, cpu.v[(opcode & 0x00F0) >> 4]);
                var n = opcode & 0x000F;

                // Get the sprite beginning at the register I and taking into
                // account the height (n)
                const sprite = cpu.memory.range(cpu.i, cpu.i + n);

                // Set VF to 0
                cpu.v[0xF] = 0;

                var j: u8 = 0;
                while (j < sprite.len) : (j += 1) {
                    var row = sprite[j];

                    // For each of the 8 pixels/bits in this sprite row:
                    var i: u8 = 0;
                    while (i < 8) : (i += 1) {
                        var bit = row >> (@intCast(u3, 7 - i)) & 0x01;
                        if (bit == 1) {
                            var xi = @intCast(u8, (vx + i) % display.SCREEN_WIDTH);
                            var yj = @intCast(u8, (vy + j) % display.SCREEN_HEIGHT);

                            var old_value = cpu.display.read(xi, yj);
                            if (old_value == 1) {
                                cpu.v[0xF] = 1;
                            }

                            // Since bit is == 1, new value is 1 ^ old_value
                            cpu.display.write(xi, yj, @intCast(u1, bit ^ old_value));
                        }
                    }
                }
            },
            0xf000 => {
                var vx = (opcode & 0x0F00) >> 8;
                var rest = opcode & 0x00FF;
                switch (rest) {
                    0x07 => {
                        // FX07: Sets VX to the current value of the delay timer.
                        cpu.v[vx] = cpu.dt;
                    },
                    0x0a => {
                        // FX0A: Get key. Block until key input

                        // Read a valid input key into VX
                        cpu.v[vx] = cpu.keyboard.readInput();

                        // Additional increment to PC with a valid key press
                        cpu.pc += 2;
                        
                    },
                    0x15 => {
                        // Set the delay timer to VX
                        cpu.dt = cpu.v[vx];
                    },
                    0x18 => {
                        // Set the sound timer to VX
                        cpu.st = cpu.v[vx];
                    },
                    0x1e => {
                        // Index register gets the value in VX added to it
                        cpu.i += cpu.v[vx];
                    },
                    0x29 => {
                        // Set I to the location of the sprite for the character
                        // in VX. Characters are represented by a 4x5 font
                        cpu.i = cpu.v[vx] * 5;
                    },
                    0x33 => {
                        cpu.memory.write(cpu.i, @intCast(u8, cpu.v[vx] / 100));
                        cpu.memory.write(cpu.i + 1, @intCast(u8, (cpu.v[vx] / 10) % 10));
                        cpu.memory.write(cpu.i + 2, @intCast(u8, (cpu.v[vx] % 100) % 10));
                    },
                    0x55 => {
                        var j: u8 = 0;
                        while (j < vx) : (j += 1) {
                            cpu.memory.write(cpu.i + j, cpu.v[j]);
                        }
                    },
                    0x65 => {
                        var j: u16 = 0;
                        while (j < vx) : (j += 1) {
                            cpu.v[vx] = cpu.memory.read(cpu.i + j);
                        }
                    },
                    else => {
                        warn("waiting", .{});
                        utils.waitForInput();
                    },
                }
            },
            0xe000 => {
                var vx = (opcode & 0x0F00) >> 8;
                var rest = opcode & 0x00FF;

                switch(rest) {
                    0x9e => {
                        // EX9E: Skip one instruction if the key corresponding to the value in VX is pressed
                        if (cpu.v[vx] == cpu.keyboard.pressed) {
                            cpu.pc += 2;
                        }
                    },
                    0xa1 => {
                        // Skip if the key corresponding to the value in VX is
                        // *not* pressed
                        if (cpu.v[vx] != cpu.keyboard.pressed) {
                            cpu.pc += 2;
                        }
                    },
                    else => {
                        warn("not implemented 0x{x}", .{rest});
                        utils.waitForInput();
                    },
                }
            },
            0x6000 => {
                // Set VX to NN
                var x = (opcode & 0x0F00) >> 8;
                var nn = @intCast(u8, opcode & 0x00FF);
                cpu.v[x] = nn;
            },
            0x7000 => {
                // 7XNN: Add the value NN to X with overflow.
                var x = (opcode & 0x0F00) >> 8;
                var nn = @intCast(u8, opcode & 0x00FF);

                // For many emulators, this would affect the carry flag. At
                // least on this instruction, not the CHIP-8. Just do an overflow add and don't worry about the boolean result.
                // result
                var result: u8 = undefined;
                _ = @addWithOverflow(u8, cpu.v[x], nn, &result);
                cpu.v[x] = result;
            },
            0x8000 => {
                // Instructions under 0x8000 need further decoding beyond just
                // the first nibble. All these instructions are logical or
                // arithmetic operations.
                var vx = (opcode & 0x0F00) >> 8;
                var vy = (opcode & 0x00F0) >> 4;

                var rest = opcode & 0x000F;
                switch (rest) {
                    0x0000 => {
                        // 8XY0: Set VX to the value of VY
                        cpu.v[vx] = cpu.v[vy];
                    },
                    0x0001 => {
                        // 8XY1: Logical OR, VX set to bitwise OR of VX and VY
                        cpu.v[vx] |= cpu.v[vy];
                    },
                    0x0002 => {
                        // 8XY2: Set VX to the value of VX & VY (bitwise AND)
                        cpu.v[vx] &= cpu.v[vy];
                    },
                    0x0003 => {
                        // 8XY3: Set VX to the value of VX xor VY
                        cpu.v[vx] ^= cpu.v[vy];
                    },
                    0x0004 => {
                        // 8XY4: Set VX to the value of VX plus VY
                        var result: u8 = undefined;
                        if (@addWithOverflow(u8, cpu.v[vx], cpu.v[vy], &result)) {
                            cpu.v[0xF] = 1;
                        } else {
                            cpu.v[0xF] = 0;
                        }

                        cpu.v[vx] = result;
                    },
                    0x0005 => {
                        // 8XY5: Set VX to the value of VX minus VY

                        var result: u8 = undefined;
                        _ = @subWithOverflow(u8, cpu.v[vx], cpu.v[vy], &result);

                        if (cpu.v[vx] > cpu.v[vy]) {
                            cpu.v[0xF] = 1;
                        } else {
                            cpu.v[0xF] = 0;
                        }

                        cpu.v[vx] = result;
                    },
                    0x0006 => {
                        // 8XY6: Set VX to the value of VY then shift VX 1 bit to the right
                        cpu.v[0xF] = cpu.v[vx] & 0x1;
                        cpu.v[vx] >>= 1;
                    },
                    0xe => {
                        // 8XYE: Set VX to the value of VY then shift VX 1 bit to the left
                        cpu.v[0xF] = cpu.v[vx] & 0x80;
                        cpu.v[vx] <<= 1;
                    },
                    else => {
                        warn("not implemented 0x{x}", .{rest});
                        utils.waitForInput();
                    },
                }
            },
            0x9000 => {
                // 5XY0: Skips if the value in VX and VY are *not* equal
                var x = (opcode & 0x0F00) >> 8;
                var y = (opcode & 0x00F0) >> 4;
                if (cpu.v[x] != cpu.v[y]) {
                    cpu.pc += 2;
                }
            },
            else => {
                warn("not implemented", .{});
                utils.waitForInput();
            },
        }
    }
};
