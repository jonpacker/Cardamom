fs = require 'fs'
async = require 'async'
path = require 'path'
Emitter = require('events').EventEmitter

class Cardamom
  constructor: (@path, concurrencyLimit = 2) ->
    @queue = async.queue @_process, concurrencyLimit
    @emitter = new Emitter

  _writeFileTask: (rdir, filename, data) ->
    basePath = path.join @path, rdir
    filename = path.join basePath, filename
    task = (callback) ->
      fs.writeFile filename, data, (err) ->
        if not err
          @emitter.emit 'log', "Created file: #{filename}"
          callback?()
        if err.code is 'ENOENT'
          fs.mkdir basePath, (err) ->
            if not err
              @emitter.emit 'log', "Created directory: #{basePath}"
              task callback
            else
              callback?(err)
        else
          callback?(err)

  _readFileTask: (rdir, filename, data) ->
    filename = path.join @path, rdir, filename
    task = (callback) ->
      fs.readFile filename, (err, data) ->
        if not err
          @emitter.emit 'log', "Read file: #{filename}"
          callback?(null, data)
        else 
          callback?(err)

  write: (relativeDir, filename, data, callback) ->
    if typeof data is 'function'
      callback = data
      data = ""
    @queue.push @_writeFileTask(relativeDir, filename, data), callback

  read: (relativeDir, filename, callback) ->
    @queue.push @_readFileTask(relativeDir, filename), callback

