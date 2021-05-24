const std = @import("std");
const process = std.process;

const stdin = std.io.getStdIn().reader();
const stderr = std.io.getStdErr().writer();

// waitForInput waits for input from the user.
// It does nothing with the input. It's simply used as a blocking call
pub fn waitForInput() void {
    var repl_buf: [1024]u8 = undefined;
    const in = stdin.readUntilDelimiterOrEof(&repl_buf, '\n') catch unreachable;
}
