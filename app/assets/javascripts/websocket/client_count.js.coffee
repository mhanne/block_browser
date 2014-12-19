class ClientCount

  connect: ->
    ["client_count"]

  client_count: (data) ->
    $('#client_count').html(data)

window.ClientCount = ClientCount

