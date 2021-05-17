const std = @import("std");
const memory = @import("./memory.zig");

// CPU is the CHIP-8's CPU
pub const CPU = struct {
    // CHIP-8 Programs are loaded into memory starting at address 200
    pc: u12 = 0x200,
    memory: *memory.Memory,

    pub fn init(cpu: *CPU, mem: *memory.Memory) void {
        cpu.memory = mem;
    }

    pub fn deinit(cpu: *CPU, alloc: *std.mem.Allocator) void {
        alloc.destroy(cpu);
    }

    pub fn tick(cpu: *CPU) void {
        // opcode = cpu.fetch();
        // cpu.execute(opcode)
        // cpu.pc += 2
        return;
    }

    fn fetch(cpu: *CPU) u16 {
        cpu.memory.read(cpu.pc);
    }
};
