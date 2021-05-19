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
        cpu.pc += 2;
        // opcode = cpu.fetch();
        // cpu.execute(opcode)
        // cpu.pc += 2
        return;
    }

    fn execute(cpu: *CPU, opcode: u16) void {
        warn("\n{X}", .{opcode});
    }

    fn fetch(cpu: *CPU) u16 {
        return cpu.memory.read(cpu.pc);
    }
};
