fs = require 'fs'
async = require 'async'
path = require 'path'
Emitter = require('events').EventEmitter
_ = require 'underscore'

class Cardamom
  constructor: (@path, @opts) ->
    @opts = _.extend {
      concurrencyLimit: 1
      refsDirName: '_refs'
      linkName: '__link__'
    }
    @queue = async.queue @_processTask, @opts.concurrencyLimit
    @emitter = new Emitter
    @taskCount = 0

  _processTask: (task, callback) => 
    @emitter.emit 'log', "[#{++@taskCount}]: #{task.name}"
    task.ƒ callback

  _writeFileTask: (rdir, filename, data) ->
    basePath = path.join @path, rdir
    filename = path.join basePath, filename
    task = name: 'write', ƒ: (callback) =>
      @emitter.emit 'logv', "Creating file: #{filename}"
      fs.writeFile filename, data, (err) =>
        if not err
          callback?()
        else if err.code is 'ENOENT'
          @_mkdir rdir, (err) =>
            if not err
              task.ƒ callback
            else
              callback?(err)
        else
          callback?(err)

  _readFileTask: (rdir, filename, data) ->
    filename = path.join @path, rdir, filename
    task = name: 'read', ƒ: (callback) ->
      fs.readFile filename, (err, data) =>
        if not err
          @emitter.emit 'log', "Read file: #{filename}"
          callback?(null, data)
        else 
          callback?(err)

  _mkdirTask: (rdir) =>
    targetDir = path.join @path, rdir
    task = name: 'mkdir', ƒ: (callback) =>
      fs.mkdir targetDir, (err) =>
        if not err or err.code is 'EEXIST'
          @emitter.emit 'logv', "Created directory #{targetDir}"
          callback?()
        else if err.code isnt 'ENOENT'
          callback?(err)
        else
          @_mkdir path.join(rdir, '../'), (err) ->
            return callback?(err) if err
            task.ƒ callback

  _mkdir: (rdir, callback) =>
    @_processTask @_mkdirTask(rdir), callback

  write: (relativeDir, filename, data, callback) ->
    if typeof data is 'function'
      callback = data
      data = ""
    @queue.push @_writeFileTask(relativeDir, filename, data), callback

  read: (relativeDir, filename, callback) ->
    @queue.push @_readFileTask(relativeDir, filename), callback

  #linkMeta does nothing as yet. TODO.
  link: (firstRelDir, firstFileName, secondRelDir, secondFileName, linkName = '', linkMeta = '', callback) ->
    if typeof linkName is 'function'
      callback = linkName
      linkName = undefined
    if typeof linkMeta is 'function'
      callback = linkMeta
      linkMeta = undefined

    linkName = linkName or @opts.linkName
    linkMeta = linkMeta or ''

    targets = [ path.join(firstRelDir, firstFileName), path.join(secondRelDir, secondFileName) ]
    links = [ path.join(secondRelDir, @opts.refsDirName, secondFileName, linkName, firstRelDir, firstFileName), 
             path.join(firstRelDir, @opts.refsDirName, firstFileName, linkName, secondRelDir, secondFileName) ]

    createLink = (link, callback) => 
      @_mkdir path.join(link[1], '../'), (err) =>
        return callback?(err) if err
        link = _.map link, (linkPath) => path.join @path, linkPath
        @emitter.emit 'logv', "Symlinking #{link[1]} -> #{link[0]}"
        fs.symlink link[0], link[1], callback

    task = name: 'link', ƒ: (callback) -> 
      async.map _.zip(targets, links), createLink, callback

    @queue.push task, callback


module.exports = Cardamom