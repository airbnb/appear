# Appear

Appear your terminal programs in your gui!

![screenshot demo thing](./screenshot.gif)

Appear is a tool for revealing a given process in your terminal. Given a
process ID, `appear` finds the terminal emulator view (be it a window, tab, or
pane) containing that process and shows it to you. Appear understands terminal
multiplexers like `tmux`, so if your target process is in a multiplexer
session, `appear` will reveal a client connected to that session, or start one
if needed.

This project intends to support all POSIX operating systems eventually, but
currently only supports macOS.

## usage

```
Usage: appear [options] PID - appear PID in your user interface
    -l, --log-file [PATH]            log to a file
    -v, --verbose                    tell many tales about how the appear process is going
        --record-runs                record every executed command as a JSON file
```

Appear will exit 0 if it managed to reveal something.
Appear will exit 1 if an exception occured.
Appear will exit 2 if there were no errors, but nothing was revealed.

## supported terminal emulators

macOS:

 - iTerm2
 - Terminal

cross-platform:

 - tmux

GNU Screen support is a non-goal. It's time for screen users to switch to tmux.

## system requirements

 - `ruby` >= 2
 - `lsof` command
 - `ps` command
 - `pgrep` command
 - if you're a mac, then you should have macOS >= 10.10

Appear depends only on the Ruby standard library.

## how it works

Here's how Appear works in a nutshell, given a `target_pid`

1. get all the parent processes of `target_pid`, up to pid1. We end up with a
   list of ProcessInfos, which have fields `{pid, parent_pid, command, name}`
2. go through our list of "revealers", one for each terminal emulator (tmux,
   iterm2, terminal.app) and ask the revealer if it can apply itself to the
   process tree.
3. if a revealer finds an associated process in the tree (eg, tmux revealer
finds the tmux server process), it performs its reveal action
  - this usually involves invoking `lsof` on a `/dev/ttys*` device to see what
    processes are talking on what ttys to each other, which takes a bunch of
    time
  - `lsof` in Appear is parallel, so grouped lsof calls are less expensive
  - the Tmux revealer is smart enough to both focus the pane that the
    `target_pid` is running in, AND to recurse the revealing process with the
    tmux client id, to reveal the tmux client.
4. the revealer sends some instructions to the terminal emulator that contains
the view for the PID
  - for our Mac apps, this involves a helper process using [Javascript for
    Automation][jfora], a JavaScript x Applescript crossover episode.
  - for tmux this is just some shell commands, super easy.

[jfora]: https://developer.apple.com/library/mac/releasenotes/InterapplicationCommunication/RN-JavaScriptForAutomation/Articles/OSX10-10.html#//apple_ref/doc/uid/TP40014508-CH109-SW1

## ruby api

The method documented here is the only part of Appear that should be considered
stable.

```ruby
require 'appear'

# super simple
Appear.appear(pid)

# You may customize logging, if needed, using the Config class
config = Appear::Config.new

# print debug info to STDOUT
config.silent = false
# also write to a log file
config.log_file = '/tmp/my-app-appear.log'

Appear.appear(pid, config)
```
