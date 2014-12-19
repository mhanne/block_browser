class Mempool

  connect: ->
    [ "mempool_accepted",
      "mempool_rejected",
      "mempool_doublespend",
      "mempool_seen",
      "mempool_confirmed" ]

  mempool_accepted: (data) ->
    console.log("mempool accepted: #{data['hash']}")
    type = document.location.pathname.split("/")[2]
    if(!type || type == "accepted")
      add_to_list($('#mempool tbody.transactions'), data['partial'])
    $('#mempool_n_tx').text(parseInt($('#mempool_n_tx').text()) + 1)
    $('#mempool_n_accepted').text(parseInt($('#mempool_n_accepted').text()) + 1)

  mempool_rejected: (data) ->
    console.log("mempool rejected: #{data['hash']}")
    type = document.location.pathname.split("/")[2]
    if(!type || type == "rejected")
      add_to_list($('#mempool tbody.transactions'), data['partial'])
    $('#mempool_n_tx').text(parseInt($('#mempool_n_tx').text()) + 1)
    $('#mempool_n_rejected').text(parseInt($('#mempool_n_rejected').text()) + 1)

  mempool_doublespend: (data) ->
    console.log("mempool doublespend: #{data['hash']}")
    type = document.location.pathname.split("/")[2]
    if(!type || type != "doublespend")
      $("#mempool_" + data["hash"]).addClass("doublespent")
    else
      # add doublespend tx to list
      console.log('add to list')
      add_to_list($('#mempool tbody.transactions'), data['partial'])
      $('#mempool_n_ds').text(parseInt($('#mempool_n_ds').text()) + 1)

  mempool_seen: (data) ->
    td = $("#mempool_" + data['hash'] + " td.times_seen")
    td.text(data["times_seen"])
    #td.effect("highlight")
    td = $("#mempool_" + data['hash'] + " td.updated_at")
    td.text(data["updated_at"].substr(0, 19))
    #td.effect("highlight")

  mempool_confirmed: (data) ->
    $('#mempool_n_tx').text(parseInt($('#mempool_n_tx').text()) - 1)
    $("#mempool_n_#{data['type']}").text(parseInt($("#mempool_n_#{data['type']}").text()) - 1)
    tr = $("#mempool_" + data['hash'])
    tr.children().effect("highlight", {color: "#33cc33"}, 1000, `function() { tr.remove()}`)

window.Mempool = Mempool
