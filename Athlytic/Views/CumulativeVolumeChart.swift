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
    
    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1_000_000 {
            return String(format: "%.0fM", volume / 1_000_000)
        } else if volume >= 1_000 {
            return String(format: "%.0fK", volume / 1_000)
        }
        return NumberFormatter.volumeFormatter.string(from: NSNumber(value: volume)) ?? "0"
    }
    
    private var chartData: [(day: Int, volume: Double, series: String)] {
        // Process current month data
        let current = currentMonthData.map { (day: Calendar.current.component(.day, from: $0.date), volume: $0.volume, series: "Current") }
        
        // Process last month data
        let last = lastMonthData.map { (day: Calendar.current.component(.day, from: $0.date), volume: $0.volume, series: "Last Month") }
        
        return current + last
    }
    
    private func getVolumeForDay(_ day: Int, series: String) -> Double? {
        let data = series == "Current" ? currentMonthData : lastMonthData
        return data.first { Calendar.current.component(.day, from: $0.date) == day }?.volume
    }
    
    private var xAxisStride: Int {
        let maxDays = max(
            currentMonthData.count > 0 ? Calendar.current.component(.day, from: currentMonthData.last!.date) : 0,
            lastMonthData.count > 0 ? Calendar.current.component(.day, from: lastMonthData.last!.date) : 0
        )
        
        if maxDays <= 7 { return 1 }
        if maxDays <= 14 { return 2 }
        if maxDays <= 21 { return 3 }
        return 5
    }
    
    var body: some View {
        Chart(chartData, id: \.day) { item in
            LineMark(
                x: .value("Day", item.day),
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
        .chartXScale(domain: 1...31)
        .chartXAxis {
            AxisMarks(
                position: .bottom,
                values: Array(stride(from: 1, through: 31, by: xAxisStride))
            ) { value in
                if let day = value.as(Int.self) {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                    AxisTick(stroke: StrokeStyle(lineWidth: 1))
                    AxisValueLabel {
                        Text("\(day)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(
                position: .leading,
                values: .automatic(desiredCount: 4)
            ) { value in
                if let volume = value.as(Double.self) {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                    AxisTick(stroke: StrokeStyle(lineWidth: 1))
                    AxisValueLabel {
                        Text(formatVolume(volume))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartYScale(domain: 0...maxVolume)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard let plotFrame = proxy.plotFrame else { return }
                                let x = value.location.x - geometry[plotFrame].origin.x
                                guard x >= 0, x <= geometry[plotFrame].width else { return }
                                
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
                                currentValue = currentMonthData.last?.volume ?? 0
                                previousValue = lastMonthData.last?.volume ?? 0
                            }
                    )
                
                if let day = selectedDay,
                   let xPosition = proxy.position(forX: day),
                   let plotFrame = proxy.plotFrame {
                    Rectangle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 1)
                        .position(
                            x: geometry[plotFrame].origin.x + xPosition,
                            y: geometry.size.height / 2
                        )
                }
            }
        }
    }
} 
