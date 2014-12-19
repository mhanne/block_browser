class MempoolTx

  constructor: (id, hash) ->
    @id = id
    @hash = hash

  connect: ->
    this["mempool_seen_#{@id}"] = (data) ->
      $("#updated_at").text(data["updated_at"].substr(0, 19))
      $("#times_seen").text(data["times_seen"])

    this["mempool_confirmed_#{@id}"] = (data) =>
      document.location.pathname = "/tx/#{@hash}"

    ["mempool_seen_#{@id}", "mempool_confirmed_#{@id}"]

window.MempoolTx = MempoolTx
