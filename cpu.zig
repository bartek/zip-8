const std = @import("std");
const memory = @import("./memory.zig");
const display = @import("./display.zig");
const warn = std.log.warn;

const utils = @import("./utils.zig");

// CPU is the CHIP-8's CPU
pub const CPU = struct {
    // CHIP-8 Programs are loaded into memory starting at address 200
    pc: u12,
    memory: *memory.Memory,
    display: *display.Display,

    // Registers
    index_register: u16,

    // Display based registers
    vx_register: u16,
    vy_register: u16,
    vf_register: u16,

    pub fn init(cpu: *CPU, mem: *memory.Memory, dis: *display.Display) void {
        cpu.memory = mem;
        cpu.display = dis;

        cpu.pc = 0x0200;
        cpu.index_register = 0x000;
        cpu.vx_register = 0x000;
        cpu.vy_register = 0x000;
        cpu.vf_register = 0x000;
    }

    pub fn deinit(cpu: *CPU, alloc: *std.mem.Allocator) void {
        alloc.destroy(cpu);
    }

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
            0xa000 => {
                warn("Set index register to NNN", .{});
                var v = opcode & 0x0FFF;
                cpu.index_register = v;
            },
            0xd000 => {
                // DXYN
                // Draw an N pixels tall sprite from the memory location that
                // the I index register is holding to the sreen, at the horizontal X
                // coordinate in VX register and the Y coordinate in VY register
                warn("Draw a sprite at (VX, Y) that is n rows tall.", .{});

                // Get X and Y from appropriate registers
                var x = cpu.vx_register;
                var y = cpu.vy_register;

                // Set VF to 0
                cpu.vf_register = 0x000;

                // For N rows
                var rows = opcode & 0x000F;
                var row: u8 = 0;
                while (row < rows) : (row += 1) {
                    warn("Drawing Row {d}", .{row});
                    // Get one byte of sprite data from the memory address in
                    // the I register
                    var sprite_byte = cpu.memory.read(@intCast(u12, cpu.index_register));
                }
            },
            0x6000 => {
                warn("Set VX to NN", .{});
                var v = opcode & 0x00FF;
                cpu.vx_register = v;
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
