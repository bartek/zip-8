const std = @import("std");
const memory = @import("./memory.zig");
const display = @import("./display.zig");
const warn = std.log.warn;

const utils = @import("./utils.zig");

// FIXME: This is re-declared in display.zig. Can/should that be resolved?
const screenWidth = 64;
const screenHeight = 32;

// CPU is the CHIP-8's CPU
pub const CPU = struct {
    // CHIP-8 Programs are loaded into memory starting at address 200
    pc: u16,
    memory: *memory.Memory,
    display: *display.Display,

    // Stack & Stack Pointer
    stack: [16]u16,
    sp: u16,

    // Index register
    i: u16,

    // 16 8-bit general purpose variable registers numbered 0 through F
    v: [16]u16,

    pub fn init(cpu: *CPU, mem: *memory.Memory, dis: *display.Display) void {
        cpu.memory = mem;
        cpu.display = dis;

        cpu.pc = 0x0200;
        cpu.sp = 0;

        cpu.i = 0x000;
        cpu.v = undefined;
    }

    pub fn deinit(cpu: *CPU, alloc: *std.mem.Allocator) void {
        alloc.destroy(cpu);
    }

    // tick ticks the CPU
    pub fn tick(cpu: *CPU) void {
        var opcode = cpu.fetch();
        var instruction = cpu.decode(opcode);

        return;
    }

    // fetch reads the instruction the PC is currently pointing at
    // An instruction is two bytes, so two successive bytes are read from memory
    // and then combined
    // The first byte is bitshifted to the left and then ORed with the second
    // byte. The end result is a 16 bit opcode
    fn fetch(cpu: *CPU) u16 {
        var high: u16 = cpu.memory.read(cpu.pc);
        var low: u16 = cpu.memory.read(cpu.pc + 1);

        cpu.pc += 2;

        return (high << 8) | low;
    }

    // decode decodes the opcode to identify the instruction.
    // This is done by first obtaining the nibble (or half-byte), which is the
    // first hexadecimal number.
    fn decode(cpu: *CPU, opcode: u16) void {
        warn("# Instruction 0x{x}", .{opcode});

        var nibble = opcode & 0xF000;
        warn("nibble 0x{x}", .{nibble});
        switch (nibble) {
            0x0000 => {
                var rest = opcode & 0x000F;
                // The rest of the nibble
                switch (rest) {
                    0x0000 => {
                        // 0x00E0 -> Clear Screen
                        warn("Clear screen", .{});
                        CLS(cpu);
                    },
                    0x00E => {
                        warn("Return from a subroutine", .{});
                        cpu.sp -= 1;
                        cpu.pc = cpu.stack[cpu.sp];
                        cpu.stack[cpu.sp] = 0;
                    },
                    else => {},
                }
            },
            0x1000 => {
                warn("1NNN: Jump. Jump PC to NNN", .{});
                cpu.pc = @intCast(u12, opcode & 0x0FFF);
            },
            0x2000 => {
                warn("2NNN: Call sub routine at location NNN", .{});

                // First push the current PC to the stack, so the subroutine can
                // return later.
                cpu.stack[cpu.sp] = cpu.pc;
                cpu.sp += 1;
                cpu.pc = opcode & 0x0FFF;
            },
            0x3000 => {
                warn("3XNN: Skip one instruction if the value in VX is equal to NN", .{});
                var x = (opcode & 0x0F00) >> 8;
                var nn = opcode & 0x00FF;
                if (cpu.v[x] == nn) {
                    // Jump ahead
                    cpu.pc += 2;
                }
            },
            0x4000 => {
                warn("4XNN: Skip one instruction if the value in VX is *not* equal to NN", .{});
                var x = (opcode & 0x0F00) >> 8;
                var nn = opcode & 0x00FF;
                if (cpu.v[x] != nn) {
                    // Jump ahead
                    cpu.pc += 2;
                }
            },
            0x5000 => {
                warn("5XY0: Skips if the value in VX and VY are equal", .{});
                var x = (opcode & 0x0F00) >> 8;
                var y = (opcode & 0x00F0) >> 4;
                if (cpu.v[x] == cpu.v[y]) {
                    cpu.pc += 2;
                }
            },
            0xa000 => {
                warn("Set index register to NNN", .{});
                var nnn = opcode & 0x0FFF;
                cpu.i = nnn;
            },
            0xc000 => {
                warn("CXNN: Random", .{});
                var nn = opcode & 0x00FF;
                var x = (opcode & 0x0F00) >> 8;

                // FIXME: Confirm this is valid
                var rng = std.rand.DefaultPrng.init(0);
                const r = rng.random.intRangeLessThan(u16, 0, 255);

                cpu.v[x] = r & nn;
            },
            0xd000 => {
                // DXYN
                // Draw an N pixels tall sprite from the memory location that
                // the I index register is holding to the screen, at the horizontal X
                // coordinate in VX register and the Y coordinate in VY register
                warn("Draw a sprite at (VX, Y) that is n rows tall.", .{});

                // Organize X, Y, and N
                var vx = cpu.v[(opcode & 0x0F00) >> 8];
                var vy = cpu.v[(opcode & 0x00F0) >> 4];
                var n = opcode & 0x000F;

                // Get the sprite beginning at the register I and taking into
                // account the height (n)
                const sprite = cpu.memory.readRange(cpu.i, cpu.i + n);

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
                            var xi = (vx + i) % screenWidth;
                            var yj = (vy + j) % screenHeight;

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
            0x6000 => {
                warn("Set VX to NN", .{});
                var nn = opcode & 0x00FF;
                var x = (opcode & 0x0F00) >> 8;
                cpu.v[x] = nn;
            },
            0x7000 => {
                warn("7XNN: Add. Add the value NN to X", .{});
                var nn = opcode & 0x00FF;
                var x = (opcode & 0x0F00) >> 8;
                cpu.v[x] = nn;
            },
            0x8000 => {
                // Instructions under 0x8000 need further decoding beyond just
                // the first nibble. All these instructions are logical or
                // arithmetic operations.
                warn("8XXX: Decoding further", .{});

                var vx = (opcode & 0x0F00) >> 8;
                var vy = (opcode & 0x00F0) >> 4;

                var rest = opcode & 0x000F;
                switch (rest) {
                    0x0000 => {
                        warn("0x8XY0: Set VX to the value of VY", .{});
                        cpu.v[vx] = cpu.v[vy];
                    },
                    0x0001 => {
                        warn("0x8XY1: Logical OR, VX set to bitwise OR of VX and VY", .{});
                        cpu.v[vx] |= cpu.v[vy];
                    },
                    0x0002 => {
                        warn("0x8XY2: Set VX to the value of VX & VY (bitwise AND)", .{});
                        cpu.v[vx] &= cpu.v[vy];
                    },
                    0x0003 => {
                        warn("0x8XY3: Set VX to the value of VX xor VY", .{});
                        cpu.v[vx] ^= cpu.v[vy];
                    },
                    0x0004 => {
                        warn("0x8XY4: Set VX to the value of VX plus VY", .{});
                        var total = cpu.v[vx] + cpu.v[vy];
                        cpu.v[vx] = total;

                        // Additonally, if the result is larger than 255, the flag register
                        // VF is set to 1. If it's not, set to 0
                        if (total > 255) {
                            cpu.v[0xF] = 1;
                        } else {
                            cpu.v[0xF] = 0;
                        }
                    },
                    0x0005 => {
                        warn("0x8XY5: Set VX to the value of VX minus VY", .{});
                        var total = cpu.v[vx] - cpu.v[vy];

                        if (cpu.v[vx] > cpu.v[vy]) {
                            cpu.v[0xF] = 1;
                        } else {
                            cpu.v[0xF] = 0;
                        }

                        cpu.v[vx] = total;
                    },
                    0x0006 => {
                        warn("0x8XY6: Set VX to the value of VY then shift VX 1 bit to the right or left", .{});
                        cpu.v[0xF] = cpu.v[vx] & 0x1;
                        cpu.v[vx] >>= 1;
                    },
                    else => {
                        warn("Not implemented 0x{x}", .{rest});
                        utils.waitForInput();
                    },
                }
            },
            0x9000 => {
                warn("5XY0: Skips if the value in VX and VY are *not* equal", .{});
                var x = (opcode & 0x0F00) >> 8;
                var y = (opcode & 0x00F0) >> 4;
                if (cpu.v[x] != cpu.v[y]) {
                    cpu.pc += 2;
                }
            },
            else => {
                warn("Not implemented", .{});
                utils.waitForInput();
            },
        }
    }
};

fn CLS(cpu: *CPU) void {
    cpu.display.reset();
}
