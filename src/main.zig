const std = @import("std");

// SDL ref:
// https://gist.github.com/peterhellberg/421735d78a9e01fcde245dc84f6f3ecc
const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

const fs = std.fs;
const cwd = fs.cwd();
const warn = std.log.warn;
const print = std.debug.print;

const memory = @import("./memory.zig");
const display = @import("./display.zig");
const cpu = @import("./cpu.zig");
const keys = @import("./keys.zig");

// The frequency rate (represented in Hz) that the CHIP 8 runs at.
const FREQUENCY = 60;

// Emulate a ~540 Hz CPU
const CPUHz = FREQUENCY * 9;

// Emulate 9 cycles before drawing a frame.
const CYCLES_PER_FRAME = (CPUHz / FREQUENCY);

// Scale everything by scale
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

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    print("Loading CHIP-8\n\n", .{});

    // SDL
    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) != 0) { // FIXME: SDL_INIT_AUDIO
        sdl.SDL_Log("unable to initialize SDL: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer sdl.SDL_Quit();

    // Memory
    var mem = allocator.create(memory.Memory) catch {
        warn("\nunable to allocate memory for Memory", .{});
        return;
    };
    defer mem.deinit(allocator);
    mem.init();

    // Display
    var dis = allocator.create(display.Display) catch {
        warn("\nunable to allocate memory for Display", .{});
        return;
    };
    defer dis.deinit(allocator);
    dis.init();

    // Keyboard
    var keyboard = allocator.create(keys.Keyboard) catch {
        warn("\nunable to allocate memory for Keyboard", .{});
        return;
    };
    defer keyboard.deinit(allocator);

    // Initialize Keyboard by mapping the desired keys to SDL Scan Code values.
    // The input array is in order of the key map (1 .. V)
    const inputs = [16]u8{
        sdl.SDL_SCANCODE_1,
        sdl.SDL_SCANCODE_2,
        sdl.SDL_SCANCODE_3,
        sdl.SDL_SCANCODE_4,
        sdl.SDL_SCANCODE_Q,
        sdl.SDL_SCANCODE_W,
        sdl.SDL_SCANCODE_E,
        sdl.SDL_SCANCODE_R,
        sdl.SDL_SCANCODE_A,
        sdl.SDL_SCANCODE_S,
        sdl.SDL_SCANCODE_D,
        sdl.SDL_SCANCODE_F,
        sdl.SDL_SCANCODE_Z,
        sdl.SDL_SCANCODE_X,
        sdl.SDL_SCANCODE_C,
        sdl.SDL_SCANCODE_V,
    };
    keyboard.init(inputs);

    // Create SDL window
    const screen = sdl.SDL_CreateWindow("zip-8", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, screenWidth(), screenHeight(), sdl.SDL_WINDOW_OPENGL) orelse
        {
        sdl.SDL_Log("unable to create window: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer sdl.SDL_DestroyWindow(screen);

    // SDL Renderer
    const renderer = sdl.SDL_CreateRenderer(screen, -1, sdl.SDL_RENDERER_ACCELERATED | sdl.SDL_RENDERER_PRESENTVSYNC) orelse {
        sdl.SDL_Log("unable to create renderer: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer sdl.SDL_DestroyRenderer(renderer);

    // Scale rendering
    _ = sdl.SDL_RenderSetScale(renderer, scale, scale);

    // CPU is aware of most modules as it interacts with them.
    var c = allocator.create(cpu.CPU) catch {
        warn("\nunable to allocate memory for CPU", .{});
        return;
    };
    defer c.deinit(allocator);

    c.init(allocator, mem, dis, keyboard);

    // Read the provided ROM
    // FIXME: Currently hardcoded path for debugging
    const buffer = cwd.readFileAlloc(allocator, "./roms/INVADERS", 4096) catch |err| {
        warn("unable to open file: {s}\n", .{@errorName(err)});
        return err;
    };

    // And load the buffer into the emulators memory
    try mem.loadRom(buffer);

    // The emulator runs an infinite loop and does three tasks in succession:
    // Fetch the instruction from memory at the current PC
    // Decode the instruction to find out what the emulator should do
    // Execute the instruction and do what it tells you.
    var quit = false;
    var cycle: u8 = 0;
    while (!quit) {
        // Timing
        cycle += 1;

        // Tick the CPU
        if (!c.waitingForInput()) {
            c.tick();
        } else {
            if (keyboard.pressed > 0) {
                c.tick();
            }
        }
        
        // Ensure we have completed the desired cycles per frame before drawing
        if (cycle < CYCLES_PER_FRAME) {
            continue;
        }

        cycle = 0;

        // Decrement audo and delay timers
        c.decrement_timers();

        // Reset keyboard on each view/input tick
        keyboard.pressed = undefined;

        var event: sdl.SDL_Event = undefined;
        while (SDL_PollEvent(&event) != 0) {
            switch (event.@"type") {
                sdl.SDL_QUIT => {
                    quit = true;
                },
                else => {},
            }
        }

        var state = sdl.SDL_GetKeyboardState(null);

        // Watch for valid keyboard input
        for (keyboard.inputs) |input, i| {
            // A valid input is being pressed
            if (state[input] == 1) {
                keyboard.set_key(@intCast(u8, i));
            }

        }

        // Draw
        _ = sdl.SDL_SetRenderDrawColor(renderer, 200, 200, 200, 255);
        _ = sdl.SDL_RenderClear(renderer);
        _ = sdl.SDL_SetRenderDrawColor(renderer, 255, 255, 200, 255);

        // Iterate over each pixel on the screen and draw it if on
        var i: u16 = 0;
        while (i < display.SCREEN_WIDTH) : (i += 1) {
            var j: u16 = 0;
            while (j < display.SCREEN_HEIGHT) : (j += 1) {
                var pixel = dis.read(i, j);
                if (pixel == 1) {
                    _ = sdl.SDL_RenderDrawPoint(renderer, i, j);
                }
            }
        }

        sdl.SDL_RenderPresent(renderer);
    }
}
