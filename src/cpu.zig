const std = @import("std");
const memory = @import("./memory.zig");
const display = @import("./display.zig");
const warn = std.log.warn;

const utils = @import("./utils.zig");

// FIXME: This is re-declared in display.zig. Can/should that be resolved?
const screenWidth = 64;
const screenHeight = 32;

const Registers = struct {
    // Index register
    i: u16,

    // Display based registers
    // FIXME: Probably make this a single V register. An array of 16 usually
    // refered to as Vx where x is a hexadecimal digit (0 through F)
    vx: u16,
    vy: u16,
    vf: u16,
};

// CPU is the CHIP-8's CPU
pub const CPU = struct {
    // CHIP-8 Programs are loaded into memory starting at address 200
    pc: u12,
    memory: *memory.Memory,
    display: *display.Display,

    registers: Registers,

    pub fn init(cpu: *CPU, mem: *memory.Memory, dis: *display.Display) void {
        cpu.memory = mem;
        cpu.display = dis;

        cpu.pc = 0x0200;

        cpu.registers = Registers{
            .i = 0x000,
            .vx = 0x000,
            .vy = 0x000,
            .vf = 0x000,
        };
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
                var low = opcode & 0x000F;
                // The rest of the nibble
                switch (low) {
                    0x0000 => {
                        // 0x00E0 -> Clear Screen
                        warn("Clear screen", .{});
                        CLS(cpu);
                    },
                    else => {},
                }
            },
            0x1000 => {
                warn("1NNN: Jump. Jump PC to NNN", .{});
                cpu.pc = @intCast(u12, opcode & 0x0FFF);
            },
            0xa000 => {
                warn("Set index register to NNN", .{});
                var v = opcode & 0x0FFF;
                cpu.registers.i = v;
            },
            0xd000 => {
                // DXYN
                // Draw an N pixels tall sprite from the memory location that
                // the I index register is holding to the sreen, at the horizontal X
                // coordinate in VX register and the Y coordinate in VY register
                warn("Draw a sprite at (VX, Y) that is n rows tall.", .{});

                // Get X and Y from appropriate registers
                var vx = cpu.registers.vx;
                var vy = cpu.registers.vy;

                // Set VF to 0
                cpu.registers.vf = 0x000;

                // For N rows
                var rows = opcode & 0x000F;

                var j: u8 = 0;
                while (j < rows) : (j += 1) {

                    // Get one byte of sprite data from the memory address in
                    // the I register. This is equivalent to a pixel on the screen.
                    var row: u8 = cpu.memory.read(@intCast(u12, cpu.registers.i + j));

                    // For each of the 8 pixels/bits in this sprite row:
                    var i: u8 = 0;
                    while (i < 8) : (i += 1) {
                        var new_value = row >> (@intCast(u3, 7 - i)) & 0x01;

                        if (new_value == 1) {
                            var xi = (vx + i) % screenWidth;
                            var yj = (vy + j) % screenHeight;

                            var old_value = cpu.display.read(xi, yj);
                            if (old_value == 1) {
                                cpu.registers.vf = 1;
                            }

                            var display_value = (old_value ^ new_value);
                            cpu.display.write(xi, yj, @intCast(u1, display_value));
                        }

                        // Get the bit at the column to see if it's been set
                        //var mask = 0x10 * col;
                        //var bit = pixel & mask;
                        //warn("bit {d}", .{bit});
                    }
                }
            },
            0x6000 => {
                warn("Set VX to NN", .{});
                var v = opcode & 0x00FF;
                cpu.registers.vx = v;
            },
            0x7000 => {
                warn("7XNN: Add. Add the value NN to X", .{});
                var v = opcode & 0x00FF;
                cpu.registers.vx = v;
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
