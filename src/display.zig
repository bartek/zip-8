const std = @import("std");

pub const SCREEN_WIDTH = 64;
pub const SCREEN_HEIGHT = 32;

// Display defines the display for the CHIP-8.
// The display is 64 pixels wide and 32 pixels tall. Each pixel can be on or
// off. In other words, each pixel is a boolean.
pub const Display = struct {
    // buffer represents the ram for the Display
    buffer: [SCREEN_WIDTH][SCREEN_HEIGHT]u8,

    pub fn init(d: *Display) void {
        d.reset();
    }

    pub fn deinit(d: *Display, alloc: *std.mem.Allocator) void {
        alloc.destroy(d);
    }

    pub fn read(d: *Display, x: u16, y: u16) u16 {
        return d.buffer[x][y];
    }

    pub fn write(d: *Display, x: u16, y: u16, bit: u1) void {
        d.buffer[x][y] = bit;
    }

    pub fn reset(d: *Display) void {
        for (d.buffer) |row, y| {
            for (row) |cell, x| {
                d.buffer[y][x] = 0;
            }
        }
    }
};
