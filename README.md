# Appear

Appear your terminal programs in your gui!

[![GitHub repo](https://badge.fury.io/gh/airbnb%2Fappear.svg)](https://github.com/airbnb/appear) [![Build Status](https://secure.travis-ci.org/airbnb/appear.svg?branch=master)](http://travis-ci.org/airbnb/appear) [![Gem Version](https://badge.fury.io/rb/appear.svg)](https://badge.fury.io/rb/appear)

Docs: [current gem](http://www.rubydoc.info/gems/appear), [github master](http://www.rubydoc.info/github/airbnb/appear/master), your branch: `bundle exec rake doc`

[![screenshot demo thing](./screenshot.gif)](https://github.com/airbnb/appear/raw/master/screenshot.gif)
<!-- the above screenshot is purposefully broken for YARD docs: it's annoying
     there, but nice on github :) -->

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
Usage: appear [OPTION]... [PID]
Appear PID in your user interface.
Appear will use the current process PID by default.

Options:
    -l, --log-file [PATH]            log to a file
    -v, --verbose                    tell many tales about how the appear process is going
        --record-runs                record every executed command as a JSON file in the appear spec folder
        --version                    show version information, then exit
    -?, -h, --help                   show this help, then exit

Exit status:
  0  if successfully revealed something,
  1  if an exception occurred,
  2  if there were no errors, but nothing was revealed.
```

## supported terminal emulators

macOS:

 - iTerm2
 - Terminal

cross-platform:

 - tmux

GNU Screen support is a non-goal. It's time for screen users to switch to tmux.

## system requirements

 - `ruby` >= 1.9.3
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

## TmuxIde.app: open files in Nvim + Tmux

I've started a project based on Appear's libraries to open files in Nvim +
Tmux. I prefer Tmux and terminal-based programs to GUI editors, so I've always
wanted to set console Vim as my default application for many filetypes.

I've built a proof-of-concept scipt that intelligently opens clicked files in
Nvim sessions inside Tmux windows. We use
[Platypus](http://sveinbjorn.org/platypus) to turn the script into a Mac native
app, and [`duti`](http://duti.org/) to assign our new app as the default
editor.

This project will eventually be split into its own repo, but lives in Appear
for now.


Set up Neovim:

1. set up Neovim
1. Set up [Neovim Remote](https://github.com/mhinz/neovim-remote).
   Follow the `nvr` install instructions. Make sure the binary ends up in
   /usr/local/bin, /usr/bin, or /bin.
1. make sure you've got `tmux` in /usr/local/bin, too. `brew install tmux` if not.
1. stick this in your .bashrc or .zshrc so that each Neovim process gets it's own socket:
  ```bash
  mkdir -p "$HOME/.vim/sockets/"
  NVIM_LISTEN_ADDRESS="$HOME/.vim/sockets/vim-zsh-$$.sock"
  ```
  Without this snippet, we'll be unable to query or control existing nvim sessions.

Build the app:

1. `brew install platypus`, which is the app builder
1. `bundle exec rake app` builds into ./build/TmuxIde.app

Use it as the default for all of your source code files:

1. Notify OS X that your app exits by running it once, you can find it in
   ./build/TmuxIde.app. It'll display a dialog and then exit.
1. `brew install duti`, which is a tool we use to change default application for filetypes.
1. `bundle exec rake app_defaults` will assign all source code extensions to
   open in TmuxIde by default.

If you have any issues with the app, you can `tail -f /tmp/tmux-ide-*.log` to
view log messages.

## contributing

First, get yourself set up:

1. make sure you have bundler. `gem install bundler`
2. inside a git clone of the project, run `./scripts/setup` or `bundle install`

Then, submit PRs from feature branches for review:

1. `git checkout -b my-name--my-branch-topic`
1. write code
1. run `./scripts/console` for a nice pry session with an instance ready to go
1. run `bundle exec rake` to run tests and doc coverage
1. commit and push your changes, however you do
1. [open a PR against airbnb master](https://github.com/airbnb/appear/compare?expand=1)

## releasing new versions

You must be a collaborator on Rubygems.org, and a committer on the main repo at
https://github.com/airbnb/appear.

1. update lib/appear/version.rb with the new version number
1. update CHANGELOG.md with changes in the new version
1. commit those changes, and merge them to master
1. checkout master
1. `bundle exec rake release`
