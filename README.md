# playsound-win32

`playsound.exe` is a small command-line program that plays a WAV file on
Windows 10 and Windows 11. It calls the Win32 `PlaySound` function and
nothing more.

It is made for [Claude Code hooks](https://code.claude.com/docs/en/hooks),
for example to play a sound when Claude finishes a response. It never
makes a hook fail or block Claude Code: the exit code is always 0.

- One small exe. You do not need to install a runtime: it uses only
  `kernel32.dll` and `winmm.dll`, which are part of Windows.
- File paths can have spaces and non-ASCII characters, such as Japanese.
- MIT License.

## Download

Download `playsound-<version>-x64.zip` from the
[Releases](https://github.com/kuangyujing/playsound-win32/releases) page,
and put `playsound.exe` in any folder, for example `C:\Tools`.

The exe is for 64-bit (x64) Windows. You can also build it yourself. See
[Build](#build).

## Usage

```
playsound <file.wav>
```

`playsound` plays the file and waits until the sound ends. When the sound
plays, it shows nothing.

`playsound -h`, `playsound --help`, and `playsound /?` show the help.

## Use with Claude Code hooks

Add hooks to your Claude Code settings file, for example
`%USERPROFILE%\.claude\settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "C:\\Tools\\playsound.exe",
            "args": ["C:\\Windows\\Media\\tada.wav"],
            "async": true
          }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "C:\\Tools\\playsound.exe",
            "args": ["C:\\Windows\\Media\\chimes.wav"],
            "async": true
          }
        ]
      }
    ]
  }
}
```

- `"async": true` runs the hook in the background. Claude Code does not
  wait until the sound ends.
- With `"args"`, Claude Code starts `playsound.exe` directly, without a
  shell such as Git Bash. Each item of `args` is one argument, so a path
  with spaces needs no extra quotes. You can use `${CLAUDE_PROJECT_DIR}`
  in `args` for a sound file in your project.
- In JSON, write each backslash as `\\`.
- Claude Code treats exit code 2 as a "blocking error". For example, when
  a `Stop` hook exits with 2, Claude does not stop and keeps working.
  `playsound` always exits with 0, so a missing or broken sound file never
  changes what Claude Code does.
- In non-interactive mode (`claude -p`), Claude Code stops async hooks
  that are still running when it exits, so the end of a sound can be cut
  off.

For details, see the
[Claude Code hooks documentation](https://code.claude.com/docs/en/hooks).

## How it works

`playsound` gets the full path of the file, checks that the file exists,
and calls:

```c
PlaySoundW(path, NULL, SND_FILENAME | SND_SYNC | SND_NODEFAULT | SND_SYSTEM);
```

- **Full path**: With a relative path, `PlaySound` also looks for the file
  in the Windows folder and in the folders in `PATH`, so it could play a
  different file with the same name. `playsound` gives `PlaySound` the
  full path, so only the file that you name can play.
- **No default sound**: `SND_NODEFAULT` stops `PlaySound` from playing the
  default system sound when it cannot find the file.
- **Volume**: The sound uses the "System sounds" volume of the Windows
  volume mixer (`SND_SYSTEM`). When system sounds are muted, `playsound`
  is muted too.
- **Path length**: The full path can have at most 255 characters. This is
  a limit of `PlaySound`. For a longer path, `playsound` plays nothing and
  shows no message.
- **File size**: `PlaySound` reads the whole file into memory before it
  plays it. Use short files, such as notification sounds.
- **Formats**: `PlaySound` plays only the formats that the audio drivers
  on the PC support. 16-bit PCM WAV files are the safest choice.

## Messages and exit code

The exit code is always 0. Messages go to standard error. (The help that
`-h` shows goes to standard output.)

| Case | Message |
| --- | --- |
| The sound played | (none) |
| No argument, or more than one argument | The help |
| The file does not exist | `playsound: file not found` |
| The path is a folder | `playsound: path is a directory` |
| The full path has more than 255 characters | (none) |
| `PlaySound` failed, for example because the format is not supported | `playsound: cannot play the file` |

## Build

You need Visual Studio 2022 or later, or Build Tools for Visual Studio,
with the C++ build tools for x64 (the "Desktop development with C++"
workload).

Run this in a Command Prompt or PowerShell window in the repository
folder:

```
build.cmd
```

The output is `build\playsound.exe`. `build.cmd` finds Visual Studio with
`vswhere.exe` and sets up the build tools itself, so you do not need a
Developer Command Prompt. At the end, it shows the size of the exe and
the DLLs that the exe needs.

`playsound` does not use the C runtime library. It is built with
`/NODEFAULTLIB` and its own entry point, and it reads the command line
with the same rules as the Microsoft C runtime. This keeps the exe small.

To run the tests (they do not need speakers):

```
pwsh test\smoke.ps1
```

GitHub Actions builds and tests the exe for every push. When a tag that
starts with `v` (for example `v1.0.0`) is pushed, GitHub Actions also
creates a release with the zip file. See [TESTING.md](TESTING.md) for the
tests that need speakers.

## License

[MIT](LICENSE)
