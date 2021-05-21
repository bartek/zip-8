const std = @import("std");
const memory = @import("./memory.zig");
const display = @import("./display.zig");
const warn = std.log.warn;

// CPU is the CHIP-8's CPU
pub const CPU = struct {
    // CHIP-8 Programs are loaded into memory starting at address 200
    pc: u12,
    memory: *memory.Memory,
    display: *display.Display,

    // Registers
    index_register: u16,
    vx_register: u16,

    pub fn init(cpu: *CPU, mem: *memory.Memory, dis: *display.Display) void {
        cpu.memory = mem;
        cpu.display = dis;

        cpu.pc = 0x0200;
        cpu.index_register = 0x000;
        cpu.vx_register = 0x000;
    }

    pub fn deinit(cpu: *CPU, alloc: *std.mem.Allocator) void {
        alloc.destroy(cpu);
    }

    pub fn tick(cpu: *CPU) void {
        var opcode = cpu.fetch();
        var instruction = cpu.decode(opcode);

        // opcode = cpu.fetch();
        // cpu.execute(opcode)
        // cpu.pc += 2
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
                // Set index register to NNN
                var v = opcode & 0x0FFF;
                cpu.index_register = v;
            },
            0x6000 => {
                warn("Set VX to NN", .{});
                var v = opcode & 0x00FF;
                cpu.vx_register = v;
            },
            else => {},
        }
    }
};

fn CLS(cpu: *CPU) void {
    cpu.display.reset();
}
