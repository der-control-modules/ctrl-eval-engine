using PlotlyLight
using Dates
using JSON

PlotlyLight.preset.display.fullscreen!()

repeat_last(vec) = vcat(vec, [vec[end]])
plot_interval(; y, kwargs...) =
    Config(; y = repeat_last(y), line = Config(; shape = :hv), kwargs...)

plotOptions = Config(; toImageButtonOptions = Config(; format = :svg), responsive = true)

outputFilename = ARGS[1]
if !isfile(outputFilename)
    @error "Output file $outputFilename doesn't exist."
    exit(1)
end
outputDict = JSON.parsefile(outputFilename; use_mmap = false)

traces = Config[]
subPlots = 0

layout = Config()
layout.xaxis.title = "Time"

for chart in outputDict["timeCharts"]
    global subPlots
    trLeft = Config[]
    trRight = Config[]
    layout["yaxis$(subPlots+1)"] = get(chart, "yAxisLeft", Config())
    layout["legend$(subPlots+1)"].title.text = get(chart, "title", "")
    for curve in chart["data"]
        trace = if curve["type"] == "interval"
            plot_interval(; x = curve["x"], y = curve["y"], name = curve["name"])
        else
            Config(; x = curve["x"], y = curve["y"], name = get(curve, "name", ""))
        end
        if get(curve, "yAxis", "left") == "left"
            push!(trLeft, trace)
            trace.yaxis = "y$(subPlots+1)"
            trace.legend = "legend$(subPlots+1)"
        else
            push!(trRight, trace)
            trace.yaxis = "y$(subPlots+2)"
            trace.legend = "legend$(subPlots+2)"
        end
    end
    if isempty(trRight)
        subPlots += 1
    else
        layout["yaxis$(subPlots+2)"] = get(chart, "yAxisRight", Config())
        subPlots += 2
    end
    append!(traces, trLeft, trRight)
end

layout.grid = Config(; rows = subPlots, columns = 1)
for iSubPlot = 1:subPlots
    layout["legend$iSubPlot"].yanchor = :top
    layout["legend$iSubPlot"].y = (subPlots + 1 - iSubPlot) / subPlots
end

timeCharts = Plot(traces, layout, plotOptions)
PlotlyLight.save(timeCharts, "$outputFilename-time_charts.html")
