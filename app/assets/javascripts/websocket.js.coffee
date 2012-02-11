$(document).ready ->
  host = "ws://127.0.0.1:8080/";

  if window.WebSocket
    window.socket = new WebSocket(host)
  else if window.MozWebSocket
    window.socket = new MozWebSocket(host)

  window.socket.addEventListener "open", (event) ->
    console.log 'connected'

  window.socket.addEventListener "close", (event) ->
    console.log 'disconnected'

  window.socket.addEventListener "message", (event) ->
    # console.log(event.data)
    list = $('table#blocks tbody.blocks')
    odd = list.children('tr:first-child').attr("class") == "odd"
    list.children('tr:last-child').remove()
    list.prepend(event.data)
    list.children('tr:first-child').attr("class", "odd")  unless odd
    list.children('tr:first-child').children('td').effect("highlight")