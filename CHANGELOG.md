# Changelog

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
