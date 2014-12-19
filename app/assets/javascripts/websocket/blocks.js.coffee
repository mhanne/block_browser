class Blocks

  connect: ->
    ["new_block"]

  new_block: (data) ->
    list = $('table#blocks tbody.blocks')
    if list.length > 0
      odd = list.children('tr:first-child').attr("class") == "odd"
      list.children('tr:last-child').remove()
      list.prepend(data["partial"])
      list.children('tr:first-child').attr("class", "odd")  unless odd
      list.children('tr:first-child').children('td').effect("highlight")

window.Blocks = Blocks
