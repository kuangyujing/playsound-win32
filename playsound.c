/*
 * playsound - play a WAV file with the Windows PlaySound function.
 *
 * Copyright (c) 2026 kuangyujing
 * SPDX-License-Identifier: MIT
 *
 * Usage: playsound <file.wav>
 *
 * The program is made for Claude Code hooks, so it never reports a
 * failure with the exit code: the exit code is always 0. Error messages
 * go to standard error.
 *
 * The program does not use the C runtime library (CRT). This keeps the
 * exe small, and the only DLLs it needs are kernel32.dll and winmm.dll.
 * Because of this:
 *   - The entry point is entry(), not main(). See /ENTRY in build.cmd.
 *   - The command line is read by our own code, with the same rules as
 *     the Microsoft C runtime.
 *   - Large buffers are static, not on the stack. Large stack buffers
 *     would need __chkstk, which is in the CRT.
 */

#include <windows.h>
#include <mmsystem.h>

/* PlaySound accepts at most 256 characters, including the final null. */
#define MAX_SOUND_PATH 256

static const char usage_text[] =
    "Usage: playsound <file.wav>\r\n"
    "\r\n"
    "Play a WAV file with the Windows PlaySound function and wait until\r\n"
    "the sound ends. The full path of the file must be 255 characters\r\n"
    "or less. A longer path is ignored without a message.\r\n"
    "\r\n"
    "The exit code is always 0, even when there is an error. Error\r\n"
    "messages go to standard error.\r\n";

/* A command line has at most 32767 characters, so any argument fits. */
static WCHAR arg[32768];
static WCHAR full_path[MAX_SOUND_PATH];

static void write_text(DWORD std_handle, const char *text)
{
    HANDLE handle = GetStdHandle(std_handle);
    DWORD written;

    if (handle != NULL && handle != INVALID_HANDLE_VALUE)
        WriteFile(handle, text, (DWORD)lstrlenA(text), &written, NULL);
}

static BOOL is_space(WCHAR c)
{
    return c == L' ' || c == L'\t';
}

static const WCHAR *skip_spaces(const WCHAR *p)
{
    while (is_space(*p))
        p++;
    return p;
}

static BOOL equal(const WCHAR *a, const WCHAR *b)
{
    while (*a != L'\0' && *a == *b) {
        a++;
        b++;
    }
    return *a == *b;
}

/*
 * Skip the program name at the start of the command line. As in the
 * Microsoft C runtime, the name ends at the first space or tab outside
 * double quotes.
 */
static const WCHAR *skip_program_name(const WCHAR *p)
{
    BOOL quoted = FALSE;

    while (*p != L'\0' && (quoted || !is_space(*p))) {
        if (*p == L'"')
            quoted = !quoted;
        p++;
    }
    return p;
}

/*
 * Copy the next argument of the command line to buf. Return a pointer to
 * the rest of the command line, or NULL if there are no more arguments.
 * buf must be as large as the command line.
 *
 * The rules are the same as in the Microsoft C runtime:
 *   - Spaces and tabs separate arguments, except inside double quotes.
 *   - 2n backslashes and a quote become n backslashes, and the quote
 *     starts or ends a quoted part.
 *   - 2n+1 backslashes and a quote become n backslashes and a quote.
 *   - Two quotes inside a quoted part become one quote.
 *   - Other backslashes stay as they are.
 */
static const WCHAR *next_arg(const WCHAR *p, WCHAR *buf)
{
    BOOL quoted = FALSE;

    p = skip_spaces(p);
    if (*p == L'\0')
        return NULL;

    for (;;) {
        unsigned int backslashes = 0;
        BOOL copy = TRUE;

        while (*p == L'\\') {
            backslashes++;
            p++;
        }
        if (*p == L'"') {
            if (backslashes % 2 == 0) {
                if (quoted && p[1] == L'"') {
                    p++;
                } else {
                    copy = FALSE;
                    quoted = !quoted;
                }
            }
            backslashes /= 2;
        }
        while (backslashes > 0) {
            *buf++ = L'\\';
            backslashes--;
        }
        if (*p == L'\0' || (!quoted && is_space(*p)))
            break;
        if (copy)
            *buf++ = *p;
        p++;
    }
    *buf = L'\0';
    return p;
}

static void play(const WCHAR *file)
{
    DWORD length;
    DWORD attributes;

    /*
     * Use the full path. With a relative path, PlaySound also looks in
     * the Windows folder and in the folders in PATH, so it could play
     * another file with the same name.
     */
    length = GetFullPathNameW(file, MAX_SOUND_PATH, full_path, NULL);
    if (length == 0) {
        write_text(STD_ERROR_HANDLE, "playsound: file not found\r\n");
        return;
    }
    if (length >= MAX_SOUND_PATH) {
        /* Too long for PlaySound. Exit without a message. */
        return;
    }

    attributes = GetFileAttributesW(full_path);
    if (attributes == INVALID_FILE_ATTRIBUTES) {
        write_text(STD_ERROR_HANDLE, "playsound: file not found\r\n");
        return;
    }
    if (attributes & FILE_ATTRIBUTE_DIRECTORY) {
        write_text(STD_ERROR_HANDLE, "playsound: path is a directory\r\n");
        return;
    }

    /*
     * SND_NODEFAULT: do not play the default system sound when the file
     * cannot be found.
     * SND_SYSTEM: use the "System sounds" volume of the volume mixer.
     */
    if (!PlaySoundW(full_path, NULL,
                    SND_FILENAME | SND_SYNC | SND_NODEFAULT | SND_SYSTEM))
        write_text(STD_ERROR_HANDLE, "playsound: cannot play the file\r\n");
}

/* Entry point of the program (see /ENTRY in build.cmd). */
void __stdcall entry(void)
{
    const WCHAR *rest;

    rest = next_arg(skip_program_name(GetCommandLineW()), arg);
    if (rest == NULL || *skip_spaces(rest) != L'\0')
        write_text(STD_ERROR_HANDLE, usage_text);
    else if (equal(arg, L"-h") || equal(arg, L"--help") || equal(arg, L"/?"))
        write_text(STD_OUTPUT_HANDLE, usage_text);
    else
        play(arg);

    /*
     * Call ExitProcess instead of returning. Returning would end only
     * this thread, and threads that PlaySound started could keep the
     * process alive.
     */
    ExitProcess(0);
}
