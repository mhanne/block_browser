class WebSocketHandler

  constructor: (url) ->
    @url = url
    @handlers = []

  add_handler: (handler) ->
    @handlers.push handler

  connect: () ->
    if window.WebSocket
      @socket = new WebSocket(@url)
    else if window.MozWebSocket
      @socket = new MozWebSocket(@url)

    @socket.addEventListener "open", (event) =>
      console.log 'WebSocket connected'

      $(@handlers).each (i, handler) =>
        c = handler.connect()
        $(c).each (i, m) =>
          @socket.send(m)

    @socket.addEventListener "close", (event) =>
      console.log 'WebSocket disconnected'
      delay 10000, ->
        window.connect_websocket(host)

    @socket.addEventListener "message", (event) =>
      d = JSON.parse(event.data); cmd = d[0]; data = d[1]
      $(@handlers).each (i, handler) ->
        if handler[cmd]
          handler[cmd](data)

window.WebSocketHandler = WebSocketHandler

delay = (ms, func) -> setTimeout func, ms

window.add_to_list = (list, row, max = 250) ->
  odd = list.children('tr:first-child').hasClass('odd')
  if list.children('tr').length >= max
    list.children('tr:last-child').remove()
  list.prepend(row)
  list.children('tr:first-child').addClass('odd') unless odd
  list.children('tr:first-child').children('td').effect('highlight')
