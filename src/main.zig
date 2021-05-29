const std = @import("std");

// TODO: Ref
// https://gigi.nullneuron.net/gigilabs/sdl2-pixel-drawing/

// SDL ref:
// https://gist.github.com/peterhellberg/421735d78a9e01fcde245dc84f6f3ecc
const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

const fs = std.fs;
const cwd = fs.cwd();
const warn = std.log.warn;

const memory = @import("./memory.zig");
const display = @import("./display.zig");
const cpu = @import("./cpu.zig");

const scale = 10;

fn screenWidth() u16 {
    return display.SCREEN_WIDTH * scale;
}

fn screenHeight() u16 {
    return display.SCREEN_HEIGHT * scale;
}

// See https://github.com/zig-lang/zig/issues/565
const SDL_WINDOWPOS_UNDEFINED = @bitCast(c_int, sdl.SDL_WINDOWPOS_UNDEFINED_MASK);
extern fn SDL_PollEvent(event: *sdl.SDL_Event) c_int;

inline fn SDL_RWclose(ctx: [*]sdl.SDL_RWops) c_int {
    return ctx[0].close.?(ctx);
}

const print = std.debug.print;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("Loading CHIP-8\n\n", .{});

    // SDL
    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) != 0) {
        sdl.SDL_Log("Unable to initialize SDL: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer sdl.SDL_Quit();

    // Memory
    var mem = allocator.create(memory.Memory) catch {
        warn("\nCould not allocate memory for Memory", .{});
        return;
    };
    defer mem.deinit(allocator);
    mem.init();

    // Display
    var dis = allocator.create(display.Display) catch {
        warn("\nCould not allocate memory for Display", .{});
        return;
    };
    defer dis.deinit(allocator);
    dis.init();

    // Create SDL window
    const screen = sdl.SDL_CreateWindow("zip-8", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, screenWidth(), screenHeight(), sdl.SDL_WINDOW_OPENGL) orelse
        {
        sdl.SDL_Log("Unable to create window: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer sdl.SDL_DestroyWindow(screen);

    // SDL Renderer
    const renderer = sdl.SDL_CreateRenderer(screen, -1, 0) orelse {
        sdl.SDL_Log("Unable to create renderer: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer sdl.SDL_DestroyRenderer(renderer);

    // SDL Texture
    const texture = sdl.SDL_CreateTexture(renderer, sdl.SDL_PIXELFORMAT_ARGB8888, sdl.SDL_TEXTUREACCESS_STATIC, screenWidth(), screenHeight()) orelse {
        sdl.SDL_Log("Unable to create texture: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer sdl.SDL_DestroyTexture(texture);

    // CPU is aware of most modules as it interacts with them.
    var c = allocator.create(cpu.CPU) catch {
        warn("\nCould not allocate memory for CPU", .{});
        return;
    };
    defer c.deinit(allocator);

    // FIXME: Initialize the keyboard in main so it can be fed SDL events? Might
    // be sanest way to pass this down, while also passing keyboard into the CPU
    // for comparison sake
    c.init(allocator, mem, dis);

    // Read the provided ROM
    // FIXME: Currently hardcoded path for debugging
    const buffer = cwd.readFileAlloc(allocator, "./roms/INVADERS", 4096) catch |err| {
        warn("Unable to open file: {s}\n", .{@errorName(err)});
        return err;
    };

    // And load the buffer into the emulators memory
    try mem.loadRom(buffer);

    // The emulator runs an infinite loop and does three tasks in succession:
    // Fetch the instruction from memory at the current PC
    // Decode the instruction to find out what the emulator should do
    // Execute the instruction and do what it tells you.
    var quit = false;
    while (!quit) {
        var event: sdl.SDL_Event = undefined;
        while (SDL_PollEvent(&event) != 0) {
            switch (event.@"type") {
                sdl.SDL_QUIT => {
                    quit = true;
                },
                else => {},
            }
        }

        // Tick the CPU
        c.tick();

        _ = sdl.SDL_SetRenderDrawColor(renderer, 200, 200, 200, 255);
        _ = sdl.SDL_RenderClear(renderer);

        // Draw. Iterate over each pixel on the screen and draw it if on
        var i: u16 = 0;
        while (i < display.SCREEN_WIDTH) : (i += 1) {
            var j: u16 = 0;
            while (j < display.SCREEN_HEIGHT) : (j += 1) {
                var pixel = dis.read(i, j);
                if (pixel == 1) {
                    const rect = &sdl.SDL_Rect{
                        .x = i * scale,
                        .y = j * scale,
                        .w = scale,
                        .h = scale,
                    };

                    _ = sdl.SDL_SetRenderDrawColor(renderer, 255, 255, 200, 255);
                    _ = sdl.SDL_RenderFillRect(renderer, rect);
                }
            }
        }

        sdl.SDL_RenderPresent(renderer);
    }
}
