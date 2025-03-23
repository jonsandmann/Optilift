import SwiftUI
import Charts

enum ComparisonViewType {
    case mtd
    case ytd
    
    var title: String {
        switch self {
        case .mtd: return "Month to Date"
        case .ytd: return "Year to Date"
        }
    }
}

struct CumulativeVolumeChart: View {
    let currentMonthData: [(date: Date, volume: Double)]
    let lastMonthData: [(date: Date, volume: Double)]
    let currentYearData: [(date: Date, volume: Double)]
    let lastYearData: [(date: Date, volume: Double)]
    @State private var selectedDay: Int?
    @Binding var currentValue: Double
    @Binding var previousValue: Double
    @State private var viewType: ComparisonViewType = .mtd
    
    private var maxVolume: Double {
        switch viewType {
        case .mtd:
            let currentMax = currentMonthData.map { $0.volume }.max() ?? 0
            let lastMax = lastMonthData.map { $0.volume }.max() ?? 0
            return max(currentMax, lastMax)
        case .ytd:
            let currentMax = currentYearData.map { $0.volume }.max() ?? 0
            let lastMax = lastYearData.map { $0.volume }.max() ?? 0
            return max(currentMax, lastMax)
        }
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
        switch viewType {
        case .mtd:
            // Process current month data
            let current = currentMonthData.map { (day: Calendar.current.component(.day, from: $0.date), volume: $0.volume, series: "Current") }
            
            // Process last month data
            let last = lastMonthData.map { (day: Calendar.current.component(.day, from: $0.date), volume: $0.volume, series: "Last Month") }
            
            return current + last
            
        case .ytd:
            // Process current year data
            let current = currentYearData.map { (day: Calendar.current.component(.dayOfYear, from: $0.date), volume: $0.volume, series: "Current") }
            
            // Process last year data
            let last = lastYearData.map { (day: Calendar.current.component(.dayOfYear, from: $0.date), volume: $0.volume, series: "Last Year") }
            
            return current + last
        }
    }
    
    private func getVolumeForDay(_ day: Int, series: String) -> Double? {
        switch viewType {
        case .mtd:
            let data = series == "Current" ? currentMonthData : lastMonthData
            return data.first { Calendar.current.component(.day, from: $0.date) == day }?.volume
            
        case .ytd:
            let data = series == "Current" ? currentYearData : lastYearData
            return data.first { Calendar.current.component(.dayOfYear, from: $0.date) == day }?.volume
        }
    }
    
    private var xAxisStride: Int {
        let maxDays: Int
        switch viewType {
        case .mtd:
            maxDays = max(
                currentMonthData.count > 0 ? Calendar.current.component(.day, from: currentMonthData.last!.date) : 0,
                lastMonthData.count > 0 ? Calendar.current.component(.day, from: lastMonthData.last!.date) : 0
            )
        case .ytd:
            maxDays = max(
                currentYearData.count > 0 ? Calendar.current.component(.dayOfYear, from: currentYearData.last!.date) : 0,
                lastYearData.count > 0 ? Calendar.current.component(.dayOfYear, from: lastYearData.last!.date) : 0
            )
        }
        
        if viewType == .ytd {
            if maxDays <= 90 { return 15 }  // Show every 15 days for first 90 days
            if maxDays <= 180 { return 30 } // Show every 30 days for 90-180 days
            return 45 // Show every 45 days for rest of year
        } else {
            if maxDays <= 7 { return 1 }
            if maxDays <= 14 { return 2 }
            if maxDays <= 21 { return 3 }
            if maxDays <= 31 { return 5 }
            return 5
        }
    }
    
    private var xAxisDomain: ClosedRange<Int> {
        switch viewType {
        case .mtd:
            return 1...31
        case .ytd:
            return 1...365
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("View Type", selection: $viewType) {
                Text("Month to Date").tag(ComparisonViewType.mtd)
                Text("Year to Date").tag(ComparisonViewType.ytd)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .onChange(of: viewType) { oldValue, newValue in
                switch newValue {
                case .mtd:
                    currentValue = currentMonthData.last?.volume ?? 0
                    previousValue = lastMonthData.last?.volume ?? 0
                case .ytd:
                    currentValue = currentYearData.last?.volume ?? 0
                    previousValue = lastYearData.last?.volume ?? 0
                }
            }
            .onAppear {
                // Initialize values based on current view type
                switch viewType {
                case .mtd:
                    currentValue = currentMonthData.last?.volume ?? 0
                    previousValue = lastMonthData.last?.volume ?? 0
                case .ytd:
                    currentValue = currentYearData.last?.volume ?? 0
                    previousValue = lastYearData.last?.volume ?? 0
                }
            }
            
            VolumeComparisonView(
                title: viewType.title,
                currentValue: $currentValue,
                previousValue: $previousValue
            )
            
            Chart(chartData, id: \.day) { item in
                LineMark(
                    x: .value("Day", item.day),
                    y: .value("Volume", item.volume)
                )
                .foregroundStyle(by: .value("Period", item.series))
                .lineStyle(StrokeStyle(
                    lineWidth: item.series == "Current" ? 2 : 1,
                    dash: item.series != "Current" ? [4, 4] : []
                ))
            }
            .frame(height: 200)
            .padding(.top)
            .chartForegroundStyleScale([
                "Current": .blue,
                "Last Month": .gray,
                "Last Year": .gray
            ])
            .chartLegend(.hidden)
            .chartXScale(domain: xAxisDomain)
            .chartXAxis {
                AxisMarks(
                    position: .bottom,
                    values: Array(stride(from: xAxisDomain.lowerBound, through: xAxisDomain.upperBound, by: xAxisStride))
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
                                       let lastVolume = getVolumeForDay(day, series: viewType == .mtd ? "Last Month" : "Last Year") {
                                        currentValue = currentVolume
                                        previousValue = lastVolume
                                    }
                                }
                                .onEnded { _ in
                                    selectedDay = nil
                                    switch viewType {
                                    case .mtd:
                                        currentValue = currentMonthData.last?.volume ?? 0
                                        previousValue = lastMonthData.last?.volume ?? 0
                                    case .ytd:
                                        currentValue = currentYearData.last?.volume ?? 0
                                        previousValue = lastYearData.last?.volume ?? 0
                                    }
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
}

// VolumeComparisonView moved to its own file: VolumeComparisonView.swift 
