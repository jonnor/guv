
debug = require('debug')('guv:governor')

heroku = require './heroku'
rabbitmq = require './rabbitmq'
scale = require './scale'

checkAndScale = (cfg, callback) ->
  state = {}
  rabbitmq.getStats cfg['*'], (err, queues) ->
    return callback err if err

    workers = {}
    for name, role of cfg
      continue if name == '*'
      state[name] = s = {}
      s.current_jobs = queues[role.queue]
      return callback new Error "Could not get data for queue: #{role.queue}" if not s.current_jobs?

      s.new_workers = scale.scale role, s.current_jobs
      workers[role.worker] = s.new_workers

    heroku.setWorkers cfg['*'], workers, (err) ->
      return callback err, state if err
      return callback null, state


class Governor
  constructor: (c) ->
    @config = c
    @state =
      roles: {}
    for name, vars of @config
      continue if name == '*'
      @state.roles[name] = {}

    @interval = null

  # TODO: emit events on error, iteration
  start: () ->
    runFunc = () =>
      @runOnce (err, state) =>
        debug 'ran iteration', err, state

    interval = setInterval runFunc, 30*1000
    runFunc() # do first iteration right now

  stop: () ->
    clearInterval @interval if @interval

  runOnce: (callback) ->
    checkAndScale @config, callback


exports.Governor = Governor
