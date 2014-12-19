class BlockCount

  connect: ->
    ["new_block"]

  new_block: (data) ->
    current_height = parseInt($("#head_block a").html())
    if current_height > data['height'] - 1 # missed blocks; reload
      document.location = document.location
    else if current_height < data['height'] - 1
      # ignore
    else
      $('#head_block').html("<a href='/block/#{data['json']['hash']}'>#{data['height']}</a>")
      $('#footer').effect("highlight")

window.BlockCount = BlockCount
