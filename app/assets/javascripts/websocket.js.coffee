delay = (ms, func) -> setTimeout func, ms

window.connect_websocket = (host) ->
  if window.WebSocket
    window.socket = new WebSocket(host)
  else if window.MozWebSocket
    window.socket = new MozWebSocket(host)

  window.socket.addEventListener "open", (event) =>
    console.log 'connected'

  window.socket.addEventListener "close", (event) =>
    console.log 'disconnected'
    delay 10000, ->
      window.connect_websocket(host)

  window.socket.addEventListener "message", (event) =>
    d = JSON.parse(event.data); cmd = d[0]; data = d[1]
    if(cmd == "new_block")
      current_height = parseInt($("#head_block a").html())
      if current_height > data['height'] - 1 # missed blocks; reload
        document.location = document.location
      else if current_height < data['height'] - 1
        # ignore
      else
        $('#head_block').html("<a href='/block/#{data['json']['hash']}'>#{data['height']}</a>")
        $('#footer').effect("highlight")
        list = $('table#blocks tbody.blocks')
        if list.length > 0
          odd = list.children('tr:first-child').attr("class") == "odd"
          list.children('tr:last-child').remove()
          list.prepend(data["partial"])
          list.children('tr:first-child').attr("class", "odd")  unless odd
          list.children('tr:first-child').children('td').effect("highlight")
    else if(cmd == "client_count")
      $('#client_count').html(data)
