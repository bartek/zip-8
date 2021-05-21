const std = @import("std");

// Display defines the display for the CHIP-8.
// The display is 64 pixels wide and 32 pixels tall. Each pixel can be on or
// off. In other words, each pixel is a boolean.
pub const Display = struct {
    buffer: [2048]u1, // 64 x 32

    pub fn init(d: *Display) void {
        d.reset();
    }

    pub fn deinit(d: *Display, alloc: *std.mem.Allocator) void {
        alloc.destroy(d);
    }

    pub fn read(d: *Display, address: u12) u8 {
        return d.buffer[address];
    }

    pub fn write(d: *Display, address: u12, bit: u1) void {
        d.buffer[address] = bit;
    }

    pub fn reset(d: *Display) void {
        std.mem.set(u1, d.buffer[0..], 0);
    }
};
