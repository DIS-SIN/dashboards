class Dashing.NumberPercentage extends Dashing.Widget
  @accessor 'current', Dashing.AnimatedValue

  @accessor 'arrow', ->
    if @get('difference')
      if parseInt(@get('difference')) > 0 then 'fa fa-arrow-up' else 'fa fa-arrow-down'

  onData: (data) ->
    if data.status
      # clear existing "status-*" classes
      $(@get('node')).attr 'class', (i,c) ->
        c.replace /\bstatus-\S+/g, ''
      # add new class
      $(@get('node')).addClass "status-#{data.status}"
