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

  _readFileTask: (filename) =>
    task = name: 'read', ƒ: (callback) =>
      fs.readFile filename, 'utf8', (err, data) =>
        if not err
          @emitter.emit 'logv', "Read file: #{filename}"
          callback?(null, data)
        else 
          callback?(err)

  _rreadFileTask: (rdir, filename) =>
    filename = path.join @path, rdir, filename
    @_readFileTask filename, data

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
    @queue.push @_rreadFileTask(relativeDir, filename), callback

  link: (firstRelDir, firstFileName, secondRelDir, secondFileName, linkName = '', callback) ->
    if typeof linkName is 'function'
      callback = linkName
      linkName = undefined

    linkName = linkName or @opts.linkName

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

  findLinks: (relativeDir, filename, linkName, linkedRelDir, callback) ->
    if typeof linkName is 'function'
      callback = linkName
      linkName = undefined
    else if typeof linkedRelDir is 'function'
      callback = linkedRelDir
      linkedRelDir = undefined

    linkName = linkName or @opts.linkName

    targetLinkDir = path.join @path, relativeDir, @opts.refsDirName, filename, linkName
    if linkedRelDir
      targetLinkDir = path.join targetLinkDir, linkedRelDir 

    task = name: 'readdir', ƒ: (callback) ->
      doReadDir = (dir, callback) ->
        fs.readdir dir, (err, files) ->
          if err
            callback?(err)
          else
            callback?(null, _.map files, (file) -> path.join dir, file)
      
      if linkedRelDir
        doReadDir targetLinkDir, callback
      else
        doReadDir targetLinkDir, (err, dirs) ->
          return callback?(err) if err
          # If there's lots of linked tables, this won't go well.
          # mapSeries is much slower, but won't have a problem with lots of tables.
          async.map dirs, doReadDir, (err, files) ->
            return callback?(err) if err
            callback?(null, _.flatten files)

    @queue.push task, callback

  readLinks: (relativeDir, filename, linkName, linkedRelDir, callback) =>
    if typeof linkName is 'function'
      callback = linkName
      linkName = undefined
    else if typeof linkedRelDir is 'function'
      callback = linkedRelDir
      linkedRelDir = undefined

    linkName = linkName or @opts.linkName

    @findLinks relativeDir, filename, linkName, linkedRelDir, (err, files) =>
      return callback?(err) if err

      readFile = (file, callback) => @queue.push @_readFileTask(file), callback

      # OK, perhaps streaming would be nice here...
      async.mapSeries files, readFile, (err, data) ->
        return callback?(err) if err
        result = {}
        result[ files[i] ] = data[i] for i of files
        callback?(null, result)

module.exports = Cardamom