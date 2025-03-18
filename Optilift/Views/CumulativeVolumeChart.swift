import SwiftUI
import Charts

struct CumulativeVolumeChart: View {
    let currentMonthData: [(date: Date, volume: Double)]
    let lastMonthData: [(date: Date, volume: Double)]
    @State private var selectedDay: Int?
    @Binding var currentValue: Double
    @Binding var previousValue: Double
    
    private var maxVolume: Double {
        let currentMax = currentMonthData.map { $0.volume }.max() ?? 0
        let lastMax = lastMonthData.map { $0.volume }.max() ?? 0
        return max(currentMax, lastMax)
    }
    
    private var yAxisValues: [Double] {
        let step = maxVolume / 4
        let roundedStep = round(step / 500) * 500
        let values = Array(stride(from: 0, through: maxVolume, by: roundedStep))
        // Ensure we include the max value if it's not already included
        if let lastValue = values.last, lastValue < maxVolume {
            return values + [maxVolume]
        }
        return values
    }
    
    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1_000_000 {
            return String(format: "%.0fM", volume / 1_000_000)
        } else if volume >= 1_000 {
            return String(format: "%.0fK", volume / 1_000)
        }
        return NumberFormatter.volumeFormatter.string(from: NSNumber(value: volume)) ?? "0"
    }
    
    private var chartData: [(date: Date, volume: Double, series: String)] {
        let current = currentMonthData.map { (date: $0.date, volume: $0.volume, series: "Current") }
        let last = lastMonthData.map { (date: $0.date, volume: $0.volume, series: "Last Month") }
        return current + last
    }
    
    private func getVolumeForDay(_ day: Int, series: String) -> Double? {
        let data = series == "Current" ? currentMonthData : lastMonthData
        return data.first { Calendar.current.component(.day, from: $0.date) == day }?.volume
    }
    
    var body: some View {
        Chart(chartData, id: \.date) { item in
            LineMark(
                x: .value("Day", Calendar.current.component(.day, from: item.date)),
                y: .value("Volume", item.volume)
            )
            .foregroundStyle(by: .value("Month", item.series))
            .lineStyle(StrokeStyle(
                lineWidth: item.series == "Current" ? 2 : 1,
                dash: item.series == "Last Month" ? [4, 4] : []
            ))
        }
        .frame(height: 200)
        .padding(.top)
        .chartForegroundStyleScale([
            "Current": .blue,
            "Last Month": .gray
        ])
        .chartLegend(.hidden)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let x = value.location.x - geometry[proxy.plotAreaFrame].origin.x
                                guard x >= 0, x <= geometry[proxy.plotAreaFrame].width else { return }
                                
                                let day: Int = proxy.value(atX: x, as: Int.self) ?? 0
                                selectedDay = day
                                
                                if let currentVolume = getVolumeForDay(day, series: "Current"),
                                   let lastVolume = getVolumeForDay(day, series: "Last Month") {
                                    currentValue = currentVolume
                                    previousValue = lastVolume
                                }
                            }
                            .onEnded { _ in
                                selectedDay = nil
                                // Reset to total volumes
                                currentValue = currentMonthData.last?.volume ?? 0
                                previousValue = lastMonthData.last?.volume ?? 0
                            }
                    )
                
                if let day = selectedDay,
                   let xPosition = proxy.position(forX: day) {
                    Rectangle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 1)
                        .position(
                            x: geometry[proxy.plotAreaFrame].origin.x + xPosition,
                            y: geometry.size.height / 2
                        )
                }
            }
        }
        .chartXAxis {
            AxisMarks(
                preset: .automatic,
                position: .bottom,
                values: .stride(by: 5)
            ) { value in
                if value.as(Int.self) == 0 {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                } else {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                }
                AxisTick(stroke: StrokeStyle(lineWidth: 1))
                AxisValueLabel {
                    if let day = value.as(Int.self) {
                        Text("\(day)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .offset(y: 4)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: yAxisValues) { value in
                if value.as(Double.self) == 0 {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                } else {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                }
                AxisTick(stroke: StrokeStyle(lineWidth: 1))
                AxisValueLabel {
                    if let volume = value.as(Double.self) {
                        Text(formatVolume(volume))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartYScale(domain: 0...maxVolume)
    }
} 
