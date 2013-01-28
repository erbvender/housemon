# Web server startup, i.e. first code loaded from app.js

global._ = require 'underscore'

# This list is also the order in which everything gets initialised
state = require './state'
briqs = require('./briqs') state
local = require '../local'
http = require 'http'
ss = require 'socketstream'

# Auto-load all briqs from a central directory
briqs.loadAll ->
  console.info "briqs loaded"

# Hook state management into SocketStream
ss.api.add 'fetch', state.fetch
ss.api.add 'store', state.store
state.on 'store', (hash, value) ->
  ss.api.publish.all 'ss-store', hash, value
  
# Define a single-page client called 'main'
ss.client.define 'main',
  view: 'index.jade'
  css: ['libs', 'app.styl']
  code: ['libs', 'app', 'modules']

# Serve this client on the root URL
ss.http.route '/', (req, res) ->
  res.serveClient 'main'

# Persistent sessions and storage based on Redis
ss.session.store.use 'redis', local.redisConfig
# ss.publish.transport.use 'redis', local.redisConfig
collections = ['bobs', 'readings', 'locations', 'drivers']
state.setupStorage collections, local.redisConfig

# Code Formatters known by SocketStream
ss.client.formatters.add require('ss-coffee')
ss.client.formatters.add require('ss-jade')
ss.client.formatters.add require('ss-stylus')

# Use client-side templates
ss.client.templateEngine.use 'angular'

# Minimise and pack assets if you type: SS_ENV=production node app.js
ss.client.packAssets()  if ss.env is 'production'

# Start web server
server = http.Server ss.http.middleware
server.listen local.httpPort
ss.start server

# This event is periodically pushed to the clients to make them, eh, "tick"
setInterval ->
  ss.api.publish.all 'ss-tick', Date.now()
, 1000
