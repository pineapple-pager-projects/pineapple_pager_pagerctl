# pagerctl

Hardware control library for the WiFi Pineapple Pager. Provides smooth, flicker-free graphics and complete hardware access through a shared library.

## Features

- **Display** - Double-buffered framebuffer rendering (480x222 RGB565)
- **Text** - Built-in bitmap font with multiple sizes
- **TTF Fonts** - TrueType font rendering via stb_truetype
- **Images** - Load and draw JPG, PNG, BMP, GIF images via stb_image
- **Input** - Button handling (D-pad, A, B, Power) with thread-safe event queue
- **LEDs** - RGB D-pad LEDs and A/B button LEDs
- **Audio** - Buzzer control with RTTTL ringtone support
- **Vibration** - Haptic feedback
- **Brightness** - Screen backlight control via sysfs

## Quick Start

Pre-compiled binaries are included. Copy the payloads folder to your Pager:

```bash
scp -r payloads/user/examples/PAGERCTL root@172.16.52.1:/root/payloads/user/examples/
```

Then on the Pager, navigate to: **Payloads > Examples > PAGERCTL Example**

Or run directly via SSH:
```bash
ssh root@172.16.52.1
cd /root/payloads/user/examples/PAGERCTL
/etc/init.d/pineapplepager stop
python3 examples/demo.py   # Python demo
# or
./examples/demo            # C demo
/etc/init.d/pineapplepager start
```

## Usage

### Python

```python
from pagerctl import Pager

with Pager() as p:
    p.set_rotation(270)  # Landscape mode
    p.clear(p.rgb(0, 0, 32))
    p.draw_text_centered(100, "Hello Pager!", p.WHITE, 2)
    p.flip()
    p.wait_button()
```

### C

```c
#include "pagerctl.h"

int main() {
    pager_init();
    pager_set_rotation(270);
    pager_clear(RGB565(0, 0, 32));
    pager_draw_text_centered(100, "Hello Pager!", COLOR_WHITE, 2);
    pager_flip();
    pager_wait_button();
    pager_cleanup();
    return 0;
}
```

## API Reference

### Display

| Function | Description |
|----------|-------------|
| `pager_init()` | Initialize display and input |
| `pager_cleanup()` | Clean up resources |
| `pager_set_rotation(deg)` | Set rotation (0, 90, 180, 270) |
| `pager_clear(color)` | Clear screen with color |
| `pager_flip()` | Swap buffers (show drawn content) |
| `pager_get_width()` | Get screen width |
| `pager_get_height()` | Get screen height |

### Drawing

| Function | Description |
|----------|-------------|
| `pager_draw_pixel(x, y, color)` | Draw single pixel |
| `pager_fill_rect(x, y, w, h, color)` | Draw filled rectangle |
| `pager_rect(x, y, w, h, color)` | Draw rectangle outline |
| `pager_line(x1, y1, x2, y2, color)` | Draw line |
| `pager_fill_circle(cx, cy, r, color)` | Draw filled circle |

### Text

| Function | Description |
|----------|-------------|
| `pager_draw_text(x, y, text, color, scale)` | Draw text at position |
| `pager_draw_text_centered(y, text, color, scale)` | Draw horizontally centered text |
| `pager_draw_ttf(x, y, text, color, font, size)` | Draw TTF text |
| `pager_draw_ttf_centered(y, text, color, font, size)` | Draw centered TTF text |

### Images

| Function | Description |
|----------|-------------|
| `pager_load_image(filepath)` | Load image file, returns handle (caller must free) |
| `pager_free_image(handle)` | Free a loaded image |
| `pager_draw_image(x, y, handle)` | Draw loaded image at position |
| `pager_draw_image_scaled(x, y, w, h, handle)` | Draw loaded image scaled to w×h |
| `pager_draw_image_file(x, y, filepath)` | Load and draw in one call |
| `pager_draw_image_file_scaled(x, y, w, h, filepath)` | Load and draw scaled in one call |
| `pager_get_image_info(filepath, &w, &h)` | Get image dimensions without loading |

Supported formats: JPEG, PNG, BMP, GIF (first frame only)

**Python example:**
```python
# One-shot draw (loads, draws, frees)
p.draw_image_file_scaled(0, 0, 200, 100, "/path/to/image.jpg")

# For repeated drawing, load once
img = p.load_image("/path/to/image.png")
p.draw_image(10, 10, img)
p.draw_image_scaled(100, 10, 50, 50, img)
p.free_image(img)

# Get dimensions without loading
w, h = p.get_image_info("/path/to/image.jpg")
```

### Input

| Function | Description |
|----------|-------------|
| `pager_wait_button()` | Wait for button press (blocking) |
| `pager_poll_input(input)` | Poll input state (non-blocking) |
| `pager_get_input_event(event)` | Get next event from thread-safe queue |
| `pager_has_input_events()` | Check if events are pending in queue |
| `pager_peek_buttons()` | Get current button state without consuming events |
| `pager_clear_input_events()` | Clear all pending events from queue |

Button constants: `BTN_UP`, `BTN_DOWN`, `BTN_LEFT`, `BTN_RIGHT`, `BTN_A`, `BTN_B`, `BTN_POWER`

Event types: `EVENT_NONE` (0), `EVENT_PRESS` (1), `EVENT_RELEASE` (2)

**Python example - Single-threaded (games):**
```python
# Blocking wait
button = p.wait_button()
if button & Pager.BTN_A:
    print("A pressed")

# Non-blocking poll (for game loops)
current, pressed, released = p.poll_input()
if pressed & Pager.BTN_A:      # Just pressed this frame
    p.beep(800, 50)
if current & Pager.BTN_UP:      # Currently held down
    player_y -= 1
if released & Pager.BTN_B:      # Just released
    print("B released")
```

**Python example - Multi-threaded (background button monitoring):**
```python
# Thread-safe event queue for apps with multiple threads
# Each event is only consumed once, preventing race conditions

def button_thread(pager):
    while running:
        pager.poll_input()  # Read hardware, populate queue
        event = pager.get_input_event()
        if event:
            button, event_type, timestamp = event
            if button == Pager.BTN_B and event_type == Pager.EVENT_PRESS:
                show_menu()

# Check button state without consuming events
if pager.peek_buttons() & Pager.BTN_A:
    print("A is currently held")

# Clear queue when transitioning between screens
pager.clear_input_events()
```

### LEDs

| Function | Description |
|----------|-------------|
| `pager_led_dpad(dir, color)` | Set D-pad LED color (dir: "up", "down", "left", "right") |
| `pager_led_set(name, brightness)` | Set LED brightness (name: "a-button-led", "b-button-led") |
| `pager_led_all_off()` | Turn off all LEDs |

Note: A/B button LED sysfs names are swapped - "b-button-led" controls green/A, "a-button-led" controls red/B.

### Audio

| Function | Description |
|----------|-------------|
| `pager_beep(freq, duration_ms)` | Play tone |
| `pager_play_rtttl(melody)` | Play RTTTL in background (sound only) |
| `pager_play_rtttl_ex(melody, mode)` | Play RTTTL with mode (see below) |
| `pager_play_rtttl_sync(melody, vibrate)` | Play RTTTL blocking (0=sound, 1=sound+vibrate) |
| `pager_stop_audio()` | Stop audio/vibration playback |

**RTTTL Playback Modes** (for `pager_play_rtttl_ex`):
- `RTTTL_SOUND_ONLY` (0) - Sound only (default)
- `RTTTL_SOUND_VIBRATE` (1) - Sound + vibration synced to notes
- `RTTTL_VIBRATE_ONLY` (2) - Silent vibration pattern (no sound)

### Vibration

| Function | Description |
|----------|-------------|
| `pager_vibrate(duration_ms)` | Vibrate for duration |
| `pager_vibrate_pattern(pattern)` | Play pattern "on,off,on,off,..." |

### Brightness

| Function | Description |
|----------|-------------|
| `pager_set_brightness(percent)` | Set screen brightness (0-100%), returns 0 on success |
| `pager_get_brightness()` | Get current brightness as percentage (0-100) |
| `pager_get_max_brightness()` | Get hardware max brightness value |

**Python example:**
```python
# Set brightness to 50%
p.set_brightness(50)

# Get current brightness
current = p.get_brightness()
print(f"Brightness: {current}%")

# Dim the screen gradually
for level in range(100, 20, -10):
    p.set_brightness(level)
    p.delay(100)
```

Note: Returns -1 if backlight control is not available on the device.

## Colors

Predefined colors (RGB565):
- `COLOR_BLACK`, `COLOR_WHITE`
- `COLOR_RED`, `COLOR_GREEN`, `COLOR_BLUE`
- `COLOR_YELLOW`, `COLOR_CYAN`, `COLOR_MAGENTA`
- `COLOR_ORANGE`, `COLOR_GRAY`, `COLOR_DARK_GRAY`

Create custom colors: `RGB565(r, g, b)`

## File Structure

```
pagerctl/
├── src/
│   ├── pagerctl.c          # Main library source
│   ├── pagerctl.h          # Header file
│   ├── stb_truetype.h      # TTF rendering
│   ├── stb_image.h         # Image loading (JPG, PNG, BMP, GIF)
│   └── demo.c              # C demo source
├── payloads/user/examples/PAGERCTL/  # Payload directory
│   ├── libpagerctl.so      # Compiled library
│   ├── pagerctl.py         # Python wrapper
│   ├── payload.sh          # Pager payload entry
│   ├── demo                # C demo binary
│   ├── examples/
│   │   └── demo.py         # Python demo
│   ├── fonts/              # TTF fonts
│   └── images/             # Test images
└── Makefile
```

## Creating Your Own Payload

### Using pagerctl in Your Project

Copy both files to your project (keep them together in the same directory):
- `pagerctl.py` - Python wrapper
- `libpagerctl.so` - Compiled library

These files are portable - `pagerctl.py` automatically finds `libpagerctl.so` in the same directory.

```python
# In your script, import from where you placed the files
import sys
sys.path.insert(0, "/path/to/your/lib")
from pagerctl import Pager

with Pager() as p:
    p.set_rotation(270)
    p.draw_text(10, 10, "My App!", p.WHITE, 2)
    p.flip()
```

### As a Pager Payload

1. Copy `payload.sh` and `examples/demo.py` to your payload directory
2. Copy `pagerctl.py` and `libpagerctl.so` to your payload's lib folder
3. Update paths in `payload.sh` to point to your payload location
4. Deploy and run via Payloads menu

## Requirements

- WiFi Pineapple Pager
- Python3 + python3-ctypes (auto-installed by payload)

## Building from Source

Only needed if you modify the C source code. The Pager uses a MIPS processor, so C code must be cross-compiled.

### Option 1: Docker (Recommended)

Pull the OpenWrt SDK image:
```bash
docker pull openwrt/sdk:mipsel_24kc-22.03.5
```

Then use the Makefile targets:
```bash
make remote-build   # Build libpagerctl.so library
make remote-demo    # Build C demo binary
make fonts          # Download TTF fonts (optional)
make deploy PAGER_IP=172.16.52.1  # Deploy to Pager
```

### Option 2: Local SDK Installation

Download and extract the OpenWrt SDK:
```bash
# Download SDK
wget https://downloads.openwrt.org/releases/22.03.5/targets/ramips/mt76x8/openwrt-sdk-22.03.5-ramips-mt76x8_gcc-11.2.0_musl.Linux-x86_64.tar.xz

# Extract
tar -xf openwrt-sdk-22.03.5-ramips-mt76x8_gcc-11.2.0_musl.Linux-x86_64.tar.xz

# Add to PATH
export PATH=$PWD/openwrt-sdk-22.03.5-ramips-mt76x8_gcc-11.2.0_musl.Linux-x86_64/staging_dir/toolchain-mipsel_24kc_gcc-11.2.0_musl/bin:$PATH
export STAGING_DIR=$PWD/openwrt-sdk-22.03.5-ramips-mt76x8_gcc-11.2.0_musl.Linux-x86_64/staging_dir
```

Then compile directly:
```bash
mipsel-openwrt-linux-musl-gcc -Wall -O2 -shared -fPIC -o libpagerctl.so src/pagerctl.c -lm -lpthread
mipsel-openwrt-linux-musl-gcc -Wall -O2 -I src -o demo src/demo.c -L. -l:libpagerctl.so -lm
```

## License

MIT License

## Author

**brAinphreAk**

www.brainphreak.net

https://ko-fi.com/brainphreak
