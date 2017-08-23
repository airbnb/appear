# Changelog

## 1.2.1

- Override == method for CommandBuilder class to make it more test friendly.

## 1.2.0

- new experimental feature: `appear --edit nvim FILES...` to edit files in Nvim inside Tmux
  inside iTerm2. Support is limited.
- refactors of many core components:
  - Tmux service
  - MacRevealers were split into Terminal services
- new handy Utils classes in appear/util, including the very handy
  `Appear::Util::CommandBuilder`, and the slightly less useful
  `Appear::Util::Memoizer`.

## 1.1.1

- passing in a PID was broken.

## 1.1.0

- You no longer have to pass a PID. If no PID is given, `appear` will default
  to the current process.
- by default, `appear` will print no output. Pass -v or --verbose for timing
  and logging information. It previously printed the PID and timing
  information by default, and then more extensive logs with --verbose.
- improved help output
- added --version command line option

## 1.0.3

- remove some binding.pry that really shouldn't have been there

## 1.0.2

- README improvements: badges, links, contributing
- scripts/console: better user experince with `Pry` magic

## 1.0.1

- create binaries

## 1.0.0

- initial release
