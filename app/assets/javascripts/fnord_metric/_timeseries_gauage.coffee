window.FnordMetric ||= {}

class window.FnordMetric.TimeseriesGauge extends window.FnordMetric.Gauge
  
  constructor: (options={})->
    super(options)
    
    @tick = options.tick ? 1 # 1 second
    @interval = @tick * 1000
    @lag = options.lag ? 3 # events don't seem to show up until 3 seconds after _now_
    
    @el.addClass('rickshaw-chart')
    @graph = @createGraph(options)
    @yAxis = @createYAxis(options.yAxis) if options.yAxis
  
  start: ->
    setInterval _.bind(@fetchData, @), @interval
  
  render: ->
    @graph.render() if @graph
  
  dataReceived: (evt)->
    @graph.series.addData @processData(evt.data)
    super
  
  processData: (data)->
    data
  
  createGraph: (options)->
    el = $('<div class="graph">').appendTo(@el)
    new Rickshaw.Graph
      element: el[0]
      width: options.width ? @el.width()
      height: options.height ? @el.height()
      renderer: options.renderer ? 'line'
      series: new Rickshaw.Series.FixedDuration(@createSeries(options), undefined, {
        timeInterval: @interval,
        maxDataPoints: options.timeSpan ? 60, # 1 minute
        timeBase: @now()
      })
  
  createSeries: (options)->
    [{ name: @widgetKey }]
  
  createYAxis: (options)->
    el = $('<div class="y-axis">').appendTo(@el)
    @yAxis = new Rickshaw.Graph.Axis.Y
      element: el[0]
      orientation: options.orientation ? 'right'
      tickFormat: options.formatter ? Rickshaw.Fixtures.Number.formatDuration
      graph: @graph
  
  fetchData: ->
    super {"until": @now() - @lag}
  
  now: ->
    parseInt(new Date().getTime() / 1000)