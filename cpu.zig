const std = @import("std");
const memory = @import("./memory.zig");
const warn = std.log.warn;

// CPU is the CHIP-8's CPU
pub const CPU = struct {
    // CHIP-8 Programs are loaded into memory starting at address 200
    pc: u12,
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
        var instruction = cpu.decode(opcode);
        cpu.execute(opcode);

        // opcode = cpu.fetch();
        // cpu.execute(opcode)
        // cpu.pc += 2
        return;
    }

    fn execute(cpu: *CPU, opcode: u16) void {
        warn("\nInstruction 0x{x}", .{opcode});
    }

    // fetch reads the instruction the PC is currently pointing at
    // An instruction is two bytes, so two successive bytes are read from memory
    // and then combined
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
        var nibble = @intCast(u8, (opcode & 0xF000) >> 12);
        warn("0x{x}", .{nibble});
    }
};
