const std = @import("std");

const MemoryError = error{
    ProgramTooLarge,
    OutOfBounds,
};

//  CHIP-8  may refer to a group of sprites representing the hexadecimal digits 0 through F. 
//  These sprites are 5 bytes long, or 8x5 pixels. The data should be stored in
//  the interpreter area of Chip-8 memory (0x000 to 0x1FF). 
const font = [80]u8{
    0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    0x90, 0x90, 0xF0, 0x10, 0x10, // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
    0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
    0xF0, 0x80, 0x80, 0x80, 0xF0, // C
    0xE0, 0x90, 0x90, 0x90, 0xE0, // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
    0xF0, 0x80, 0xF0, 0x80, 0x80, // F
};

// Memory is the CHIP-8's Memory
// The memory should be 4B (4 kilobytes, 4096 bytes) large
// CHIP-8's index register and program counter can only address 12 bits, which is conveniently, 4096 address
// All memory is RAM and should be considered writable
pub const Memory = struct {
    memory: [4096]u8,

    pub fn init(mem: *Memory) void {
        std.mem.set(u8, mem.memory[0..], 0);

        // Load the font into memory
        for (mem.memory[0..80]) |*m, i| {
            m.* = font[i];
        }
    }

    pub fn deinit(mem: *Memory, alloc: *std.mem.Allocator) void {
        alloc.destroy(mem);
    }

    pub fn read(mem: *Memory, address: u16) !u8 {
        if (address > 4096 - 1) {
            return MemoryError.OutOfBounds;
        }
        return mem.memory[address];
    }

    pub fn range(mem: *Memory, start: u16, end: u16) []u8 {
        return mem.memory[start..end];
    }

    pub fn write(mem: *Memory, address: u16, value: u8) void {
        mem.memory[address] = value;
    }

    // loadRom loads a buffer into Memory
    pub fn loadRom(mem: *Memory, buffer: []u8) !void {
        if (buffer.len > 4096) {
            return MemoryError.ProgramTooLarge;
        }

        for (buffer) |b, index| {
            mem.write(@intCast(u16, index + 0x200), b);
        }
    }
};
