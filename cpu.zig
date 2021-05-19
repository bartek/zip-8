const std = @import("std");
const memory = @import("./memory.zig");
const warn = std.log.warn;

// CPU is the CHIP-8's CPU
pub const CPU = struct {
    // CHIP-8 Programs are loaded into memory starting at address 200
    pc: u12 = 0x0200,
    memory: *memory.Memory,

    pub fn init(cpu: *CPU, mem: *memory.Memory) void {
        cpu.memory = mem;

        cpu.pc = 0x0200;
    }

    pub fn deinit(cpu: *CPU, alloc: *std.mem.Allocator) void {
        alloc.destroy(cpu);
    }

    pub fn tick(cpu: *CPU) void {
        var opcode = cpu.fetch();
        cpu.execute(opcode);
        // opcode = cpu.fetch();
        // cpu.execute(opcode)
        // cpu.pc += 2
        return;
    }

    fn execute(cpu: *CPU, opcode: u16) void {
        warn("\n{X}", .{opcode});
    }

    // fetch reads the instruction the PC is currently pointing at
    // An instruction is two bytes, so two successive bytes are read from memory
    // and then combined
    fn fetch(cpu: *CPU) u16 {
        var high: u16 = cpu.memory.read(cpu.pc);
        var low: u16 = cpu.memory.read(cpu.pc + 1);

        warn("\n{X}, {X}", .{ high, low });

        cpu.pc += 2;

        return (high << 8) | low;
    }
};
