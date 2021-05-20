const std = @import("std");

const MemoryError = error{ProgramTooLarge};

// Memory is the CHIP-8's Memory
// The memory should be 4B (4 kilobytes, 4096 bytes) large
// CHIP-8's index register and program counter can only address 12 bits, which is conveniently, 4096 address
// All memory is RAM and should be considered writable
pub const Memory = struct {
    memory: [4096]u8,

    pub fn init(mem: *Memory) void {
        std.mem.set(u8, mem.memory[0..], 0);
    }

    pub fn deinit(mem: *Memory, alloc: *std.mem.Allocator) void {
        alloc.destroy(mem);
    }

    pub fn read(mem: *Memory, address: u12) u8 {
        return mem.memory[address];
    }

    pub fn write(mem: *Memory, address: u12, value: u8) void {
        mem.memory[address] = value;
    }

    // loadRom loads a buffer into Memory
    pub fn loadRom(mem: *Memory, buffer: []u8) !void {
        if (buffer.len > 4096) {
            return MemoryError.ProgramTooLarge;
        }

        for (buffer) |b, index| {
            mem.write(@intCast(u12, index + 0x200), b);
        }
    }
};
