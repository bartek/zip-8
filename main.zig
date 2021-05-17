const std = @import("std");

const fs = std.fs;
const cwd = fs.cwd();
const warn = std.log.warn;

const memory = @import("./memory.zig");
const cpu = @import("./cpu.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("Loading CHIP-8", .{});
    var mem = allocator.create(memory.Memory) catch {
        warn("\nCould not allocate memory for Memory", .{});
        return;
    };
    defer mem.deinit(allocator);
    mem.init();

    var c = allocator.create(cpu.CPU) catch {
        warn("\nCould not allocate memory for CPU", .{});
        return;
    };
    defer c.deinit(allocator);
    c.init(mem);

    // Load the provided ROM into memory
    // FIXME: Currently hardcoded path for debugging
    var buffer: [0x1000]u8 = undefined;
    var file = cwd.openFile("./roms/ibm-logo.ch8", .{}) catch |err| {
        warn("Unable to open file: {s}\n", .{@errorName(err)});
        return err;
    };
    defer file.close();
    const end_index = try file.readAll(&buffer);

    // The emulator runs an infinite loop and does three tasks in succession:
    // Fetch the instruction from memory at the current PC
    // Decode the instruction to find out what the emulator should do
    // Execute the instruction and do what it tells you.
    while (true) {
        std.time.sleep(1000);

        // Fetch. Read the instruction that PC is currently pointing at from
        // memory. An instruction is two bytes, so read two successive bytes
        // from memory and combine them into one 16-bit instruction
        //
        //  Then immediately increment the PC by 2, to be ready to fetch the
        //  next opcode.
        c.tick();
    }
}
