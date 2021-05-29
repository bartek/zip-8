const std = @import("std");
const Allocator = std.mem.Allocator;

const stdin = std.io.getStdIn().reader();
const debug = std.log.debug;
const warn = std.log.warn;

// Keyboard defines functionality to support reading input and maintaining what
// keys are pressed in order for the CPU to provide functionality.
pub const Keyboard = struct {
    keys: [16]u16,
    pressed: u16,

    // the keyboard should:
    // have a method to capture input
    // maintain what keys are pressed
    // be able to read those keys
    // cpu will compare vx to what's in here
    pub fn init(k: *Keyboard) void {
        // Key Map    Scan Codes
        // 1 2 3 4   02 03 04 05
        // Q W E R   10 11 12 13
        // A S D F   1E 1F 20 21
        // Z X C V   2C 2D 2E 2F
        k.keys = [16]u16{
            0x02,
            0x03,
            0x04,
            0x05,
            0x10,
            0x11,
            0x12,
            0x13,
            0x1E,
            0x1F,
            0x20,
            0x21,
            0x2C,
            0x2D,
            0x2E,
            0x2F,
        };
    }

    pub fn deinit(k: *Keyboard, alloc: *Allocator) void {
        alloc.destroy(k);
    }

    // readInput attempts to read input from the user until a valid key is
    // pressed.
    pub fn readInput(k: *Keyboard) u8 {
        while (true) {
            warn("getting a key", .{});
            const input = stdin.readByte() catch unreachable;
            for (k.keys) |key| {
                debug("key {x} against input {x}", .{key, input});
                if (key == input) {
                    k.pressed = input;
                    break;
                }
            }
        }
        return k.pressed;
    }
};
