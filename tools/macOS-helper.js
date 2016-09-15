#!/usr/bin/env osascript -l JavaScript
// osascript is a OS X-native scripting tool that allows scripting the system.
// Usually scripts are written in AppleScript, but AppleScript really sucks, so
// we're going to write Javascript instead.
//
// osascript is interesting because it can inspect the state of the OS X gui,
// including enumerating windows and inspecting window contents, if
// accessibility is enabled in System Preferences.
//
// documentation:
// https://developer.apple.com/library/mac/releasenotes/InterapplicationCommunication/RN-JavaScriptForAutomation/Articles/OSX10-10.html#//apple_ref/doc/uid/TP40014508-CH109-SW1

// This script is called from Appear to interact with macOS GUI apps. Both
// Terminal.app and iTerm2 publish Applescript APIs, so they're super-easy to
// script without accessibility!

// libaries -----------------------------------------------
var SystemEvents = Application('System Events')

// allows using things like ThisApp.displayDialog
var ThisApp = Application.currentApplication()
ThisApp.includeStandardAdditions = true

// helpful
var ScriptContext = this

// -----------------------------------------------------------
var PROGRAM_NAME = 'appear-macOS-helper'
var Methods = {}
function delegateMethod(methodName, klass, fn) {
  result = function() {
    var instance = new klass();
    return instance[fn].apply(instance, arguments)
  }
  result.name = methodName
  Methods[methodName] = result
  return result
}

// entrypoint -------------------------------------------------
// this is the main method of this script when it is called from the command line.
// the remainer of the file is parsed and evaluated, and then the osascript
// environment calls this function with two arguments:
// 1: Array<String> argv
// 2: Object ???. Could be ScriptContext?
function run(argv, unknown) {
  var method_name = argv[0]
  var data = argv[1]
  var message = "running method " + method_name

  if (data) {
    data = JSON.parse(data)
    message = message + " with data"
  }

  try {
    var method = Methods[method_name]
    if (!method) throw new Error('unknown method ' + method_name)
    // helpful for debugging sometimes! don't delete. just un-comment
    //say(message)
    var result = ok(method(data))
    Subprocess.cleanup()
    return JSON.stringify(result)
  } catch (err) {
    //say("failed because " + err.message)
    Subprocess.cleanup()
    return JSON.stringify(error(err))
  }
}

function ok(result) {
  return {status: 'ok', value: result}
}

function error(err) {
  return {status: 'error', error: { message: err.message, stack: err.stack }}
}

// ------------------------------------------------------------

function TerminalEmulator() {}
TerminalEmulator.prototype.forEachPane = function(callback) {}
TerminalEmulator.prototype.panes = function panes() {
  var panes = []
  this.forEachPane(function(pane) {
    panes.push(pane)
  })
  return panes;
}
TerminalEmulator.prototype.revealTty = function(tty) {}

// ------------------------------------------------------------
// Iterm2 library

function Iterm2() {
  this.app = Application('com.googlecode.iterm2')
}

Iterm2.prototype = new TerminalEmulator();

Iterm2.prototype.forEachPane = function forEachPane(callback) {
  this.app.windows().forEach(function(win) {
    win.tabs().forEach(function(tab) {
      tab.sessions().forEach(function(session) {
        callback({
          window: win,
          tab: tab,
          session: session,
          tty: session.tty(),
        })
      })
    })
  })
}

Iterm2.prototype.revealTty = function revealTty(tty) {
  var success = false;

  this.forEachPane(function(pane) {
    if (pane.tty !== tty) return
    if (success) return

    pane.tab.select()
    pane.session.select()
    pane.window.select()
    success = true;
  })

  if (success) smartActivate(this.app)
  return success;
}

Iterm2.prototype.newWindow = function newWindow(command) {
  var window = this.app.createWindowWithDefaultProfile({command: command})
  var session = window.currentSession();

  return {
    win: window,
    tab: window.currentTab(),
    session: session,
    tty: session.tty(),
  };
}

delegateMethod('iterm2_reveal_tty', Iterm2, 'revealTty')
delegateMethod('iterm2_panes', Iterm2, 'panes')
delegateMethod('iterm2_new_window', Iterm2, 'newWindow')

// -------------------------------------------------------------
// Terminal.app library

function Terminal() {
  this.app = Application('com.apple.Terminal')
}

Terminal.prototype = new TerminalEmulator();

Terminal.prototype.forEachPane = function iteratePanes(callback) {
  this.app.windows().forEach(function(win) {
    win.tabs().forEach(function(tab) {
      callback({
        window: win,
        tab: tab,
        tty: tab.tty(),
      })
    })
  })
}

Terminal.prototype.revealTty = function revealTty(tty) {
  var success = false;

  this.forEachPane(function(pane) {
    if (pane.tty !== tty) return;
    if (success) return;

    pane.tab.selected = true
    pane.window.index = 0
    success = true
  })

  if (success) smartActivate(this.app)
  return success
}

delegateMethod('terminal_reveal_tty', Terminal, 'revealTty')
delegateMethod('terminal_panes', Terminal, 'panes')

// for tests ----------------------------------------------

Methods['test_ok'] = function test_ok(arg1) {
  return arg1
}

Methods['test_err'] = function test_err(arg1) {
  var error = new Error('testing error handling')
  error.arg1 = arg1
  throw error
}


// paths ---------------------------------------------------
Paths = (function(){
  function splitPath(path) {
    return path.split('/')
  }

  function joinPath(pathArray) {
    var res = pathArray.join('/')
    if (res[0] != '/') res = '/' + res
    return res
  }

  function local(pathIn) {
    var file = ThisApp.pathTo(ScriptContext).toString()
    return join(dirname(file), pathIn)
  }

  function dirname(path) {
    return joinPath(splitPath(path).slice(0, -1))
  }

  function basename(path) {
    return splitPath(path).slice(-1)[0]
  }

  function join(root, extend) {
    return joinPath(splitPath(root).concat(splitPath(extend)).filter(Boolean))
  }

  return {
    local: local,
    dirname: dirname,
    basename: basename,
    join: join,
  }
})();


// Subprocess ---------------------------------------------------

var Subprocess = (function() {
  var FILENAME_PREFIX = Paths.join('/tmp', PROGRAM_NAME + '-' + Date.now() + Math.random() + '-')
  var _tmpfile = 0;
  var _threads = [];

  // if the script doesn't have a file to write to, it will block still.
  function tmpfile() {
    var filename = FILENAME_PREFIX + _tmpfile++ + '.log'
    return filename
  }

  // fork a command, and return the PID.
  function fork(command, detatch) {
    var output = tmpfile()
    var script = command + ' &> ' + output + ' & echo $!'
    var thread = {
      command: command,
      pid: ThisApp.doShellScript(script),
      output: output,
      detatch: detatch,
    }
    console.log('forked process', JSON.stringify(thread, null, 2))
    _threads.push(thread)
    return thread
  }

  function kill(pid) {
    try {
      // this will raise an error if the kill command cant find that process.
      ThisApp.doShellScript('kill ' + pid)
      return true
    } catch (err) {
      return false
    }
  }

  function del(filename) {
    var path = Path(filename)
    if (SystemEvents.exists(path)) {
      SystemEvents.delete(path)
      return true
    }
    return false
  }

  function cleanup() {
    _threads.forEach(function(thread) {
      if (!thread.detatch) kill(thread.pid)
      del(thread.output)
    })
  }

  return {
    fork: fork,
    cleanup: cleanup,
  }
})();

// various utils ----------------------------------------------

function smartActivate(app) {
  if (!app.frontmost()) {
    app.activate()
  }
}

function quotedForm(s) {
  return "'" + s.replace(/'/g, "'\\''") + "'"
}

// non-blocking say text
function say(text) {
  Subprocess.fork('say ' + quotedForm(text), true)
}

// debugging -----------------------------------------------
// these are left in here because they're useful if you ever want to develop this file again.

function log(obj, fieldName) {
  var fn = fieldName || '>'
  console.log(fn, Automation.getDisplayString(obj))
}

function typeName(obj) {
  return Object.prototype.toString.call(obj)
}

function inspect(obj) {
  console.log("--------v")
  log(obj)
  if (obj !== undefined) inspectDetail(obj)
  console.log('--------^')
}

function inspectDetail(obj) {
  var proto = obj.__proto__;
  var constructor = obj.constructor;
  var name = typeName(obj)

  console.log('')

  log(name, 'type name')
  log(proto, 'prototype')

  console.log('')

  log(Object.keys(obj), 'keys')
  for (var thing in obj) {
    log(obj[thing], 'prop ' + Automation.getDisplayString(thing) + ':')
  }

  console.log('')

  log(constructor, 'constructor')
}
// ---------------------------------------------------------
