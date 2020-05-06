class Dashing.TodaysDate extends Dashing.Widget

  ready: ->
    setInterval(@startTime, 500)

  startTime: =>
    today = new Date()
    @set('date', today.toDateString())

  formatTime: (i) ->
    if i < 10 then "0" + i else i