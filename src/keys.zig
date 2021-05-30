const std = @import("std");
const Allocator = std.mem.Allocator;

const stdin = std.io.getStdIn().reader();
const debug = std.log.debug;
const warn = std.log.warn;

// Keyboard defines functionality to support reading input and maintaining what
// keys are pressed in order for the CPU to provide functionality.
pub const Keyboard = struct {
    keys: [16]u8,
    inputs: [16]u8,

    pressed: u8,

    // the keyboard should:
    // have a method to capture input
    // maintain what keys are pressed
    // be able to read those keys
    // cpu will compare vx to what's in here
    pub fn init(k: *Keyboard, inputs: [16]u8) void {
        k.inputs = inputs;

        // Key Map 
        // 1 2 3 4 
        // Q W E R 
        // A S D F 
        // Z X C V 
        k.keys = [16]u8{
            // 1 2 3 4
            0x1,
            0x2,
            0x3,
            0xc,

            // Q W E R
            0x4,
            0x5,
            0x6,
            0x7,

            // A S D F
            0x7,
            0x8,
            0x9,
            0xe,

            // Z X C V
            0xa,
            0x0,
            0xb,
            0xf,
        };
    }

    pub fn deinit(k: *Keyboard, alloc: *Allocator) void {
        alloc.destroy(k);
    }

    pub fn set_key(k: *Keyboard, index: u8) void {
        k.pressed = k.keys[index];
    }
