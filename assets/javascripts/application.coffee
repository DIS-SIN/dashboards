# dashing.js is located in the dashing framework
# It includes jquery & batman for you.
#= require dashing.js

#= require_directory .
#= require_tree ../../widgets

console.log("Yeah! The dashboard has started!")

Dashing.on 'ready', ->
  Dashing.widget_margins ||= [5, 5]
  Dashing.widget_base_dimensions ||= [300, 360]
  # Dashing.numColumns ||= 4

  contentWidth = (Dashing.widget_base_dimensions[0] + Dashing.widget_margins[0] * 2) * Dashing.numColumns
  contentHeight = (Dashing.widget_base_dimensions[1] + Dashing.widget_margins[1] * 2) * Dashing.numRows

  Batman.setImmediate ->
    $('.gridster').width(contentWidth)
    $('.gridster ul:first').gridster
      widget_margins: Dashing.widget_margins
      widget_base_dimensions: Dashing.widget_base_dimensions
      avoid_overlapped_widgets: !Dashing.customGridsterLayout
      draggable:
        stop: Dashing.showGridsterInstructions
        start: -> Dashing.currentWidgetPositions = Dashing.getWidgetPositions()

  setScale(contentWidth, contentHeight)
  



setScale = (content_width, content_height) ->
  e = window
  a = "inner"
  unless "innerWidth" of window
    a = "client"
    e = document.documentElement or document.body
  width= e[a + "Width"]
  height= e[a + "Height"]

  scaleWidth = width / content_width
  scaleHeight = height / content_height

  scale = 0
  
  if scaleWidth > scaleHeight
    scale = scaleHeight
    $(".container-transform").css({
      "transform-origin": "top center"
    })
  else
    scale = scaleWidth
    $(".container-transform").css({
      "transform-origin": "top left"
    })

  $('#container').css({
    transform: "scale(" + scale + ")"
  })

