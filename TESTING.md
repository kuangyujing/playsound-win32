# Testing

## Automatic tests

[`test/smoke.ps1`](test/smoke.ps1) runs on GitHub Actions for every pull
request to `main`, and again before the files are added to a release.
The runners have no audio device, so the tests cannot check that a sound
is heard. They check:

- The help (`-h`, `--help`, `/?`), and the help on standard error when
  there is no argument or more than one argument.
- Quotes and backslashes in the command line (the rules of the Microsoft
  C runtime).
- A missing file, a folder, and a file that is not a WAV file: the
  messages.
- A path with Japanese characters and spaces, a relative path, and a path
  with forward slashes: the file is found.
- A relative path to a file that is only in a folder in `PATH`: the file
  is not played (`playsound: file not found`).
- A full path of 255 characters is used, and a full path of 256
  characters or more is ignored without a message.
- The exit code is 0 in every case.

The pull request check also runs `test/measure.ps1 -NoSound`, which shows
how long it takes to start `playsound.exe` and `powershell.exe` (no sound
plays).

## Manual tests

These tests need a Windows PC with speakers. Write the result after each
item.

- [ ] A 16-bit PCM WAV file plays to the end. The exit code is 0.
- [ ] A file that does not exist: no sound plays, not even the default
      system sound.
- [ ] A path with Japanese characters and spaces: the sound plays.
- [ ] A text file renamed to `.wav`: does `playsound` show
      `playsound: cannot play the file`? (The `PlaySound` documentation
      does not say if `PlaySound` returns FALSE in this case.)
- [ ] Other WAV formats: IMA ADPCM, 24-bit PCM, 32-bit float, and
      WAVE_FORMAT_EXTENSIBLE. Does each one play?
- [ ] A WAV file of a few MB: does it play, and how long does it take
      until the sound starts?
- [ ] Ctrl+C stops the sound.
- [ ] The "System sounds" volume of the volume mixer changes the volume.
- [ ] Time compared with PowerShell `System.Media.SoundPlayer`: run
      `powershell -ExecutionPolicy Bypass -File test\measure.ps1`.
- [ ] From the terminal of VS Code Remote - SSH: is the sound heard from
      the speakers of the Windows PC?
- [ ] Claude Code hooks with `"async": true` (see the README): the sound
      plays, and Claude Code does not wait for it.
