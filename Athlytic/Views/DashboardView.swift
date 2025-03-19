import SwiftUI
import Charts
import CoreData

enum TimeRange: Int, CaseIterable {
    case oneMonth = 1
    case threeMonths = 3
    case sixMonths = 6
    case twelveMonths = 12
    case twentyFourMonths = 24
    
    var title: String {
        switch self {
        case .oneMonth: return "1M"
        case .threeMonths: return "3M"
        case .sixMonths: return "6M"
        case .twelveMonths: return "1Y"
        case .twentyFourMonths: return "2Y"
        }
    }
    
    var shouldShowDailyData: Bool {
        self == .oneMonth
    }
}

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest private var todaysWorkoutSets: FetchedResults<CDWorkoutSet>
    @FetchRequest private var lastMonthSets: FetchedResults<CDWorkoutSet>
    @FetchRequest private var thisYearSets: FetchedResults<CDWorkoutSet>
    @FetchRequest private var lastYearSets: FetchedResults<CDWorkoutSet>
    @FetchRequest private var thisWeekWorkouts: FetchedResults<CDWorkout>
    @FetchRequest private var lastWeekWorkouts: FetchedResults<CDWorkout>
    
    @State private var selectedTimeRange: TimeRange = .threeMonths
    @State private var showingAddWorkout = false
    @State private var selectedCurrentVolume: Double = 0
    @State private var selectedPreviousVolume: Double = 0
    
    private func formatVolume(_ volumeLbs: Double) -> String {
        return NumberFormatter.volumeFormatter.string(from: NSNumber(value: volumeLbs)) ?? "0"
    }
    
    init() {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        
        // Today's sets
        _todaysWorkoutSets = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \CDWorkoutSet.date, ascending: true)],
            predicate: NSPredicate(format: "date >= %@ AND date < %@", startOfToday as NSDate, endOfToday as NSDate)
        )
        
        // Last month's sets
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfMonth)!
        let endOfLastMonth = calendar.date(byAdding: .day, value: -1, to: startOfMonth)!
        
        _lastMonthSets = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \CDWorkoutSet.date, ascending: true)],
            predicate: NSPredicate(format: "date >= %@ AND date <= %@", startOfLastMonth as NSDate, endOfLastMonth as NSDate)
        )
        
        // This year's sets
        let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
        let endOfYear = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: startOfYear)!
        _thisYearSets = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \CDWorkoutSet.date, ascending: true)],
            predicate: NSPredicate(format: "date >= %@ AND date <= %@", startOfYear as NSDate, endOfYear as NSDate)
        )
        
        // Last year's sets
        let startOfLastYear = calendar.date(byAdding: .year, value: -1, to: startOfYear)!
        let endOfLastYear = calendar.date(byAdding: .year, value: -1, to: now)!
        _lastYearSets = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \CDWorkoutSet.date, ascending: true)],
            predicate: NSPredicate(format: "date >= %@ AND date <= %@", startOfLastYear as NSDate, endOfLastYear as NSDate)
        )
        
        // This week's workouts
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek)!
        _thisWeekWorkouts = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \CDWorkout.date, ascending: true)],
            predicate: NSPredicate(format: "date >= %@ AND date < %@", startOfWeek as NSDate, endOfWeek as NSDate)
        )
        
        // Last week's workouts
        let startOfLastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfWeek)!
        let endOfLastWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfLastWeek)!
        _lastWeekWorkouts = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \CDWorkout.date, ascending: true)],
            predicate: NSPredicate(format: "date >= %@ AND date < %@", startOfLastWeek as NSDate, endOfLastWeek as NSDate)
        )
    }
    
    private var todaysVolume: Double {
        todaysWorkoutSets.reduce(0.0) { $0 + (Double($1.reps) * $1.weight) }
    }
    
    private var thisMonthVolume: Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1), to: startOfMonth)!
        
        return thisYearSets
            .filter { guard let date = $0.date else { return false }; return date >= startOfMonth && date < endOfMonth }
            .reduce(0.0) { $0 + (Double($1.reps) * $1.weight) }
    }
    
    private var lastMonthVolume: Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfMonth)!
        let endOfLastMonth = calendar.date(byAdding: .day, value: -1, to: startOfMonth)!
        
        return thisYearSets
            .filter { guard let date = $0.date else { return false }; return date >= startOfLastMonth && date <= endOfLastMonth }
            .reduce(0.0) { $0 + (Double($1.reps) * $1.weight) }
    }
    
    private var thisYearVolume: Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
        let endOfYear = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: startOfYear)!
        
        return thisYearSets
            .filter { guard let date = $0.date else { return false }; return date >= startOfYear && date <= endOfYear }
            .reduce(0.0) { $0 + (Double($1.reps) * $1.weight) }
    }
    
    private var lastYearVolume: Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
        let startOfLastYear = calendar.date(byAdding: .year, value: -1, to: startOfYear)!
        let endOfLastYear = calendar.date(byAdding: .year, value: -1, to: now)!
        
        return lastYearSets
            .filter { guard let date = $0.date else { return false }; return date >= startOfLastYear && date <= endOfLastYear }
            .reduce(0.0) { $0 + (Double($1.reps) * $1.weight) }
    }
    
    private func getCumulativeVolumes() -> (current: [(date: Date, volume: Double)], last: [(date: Date, volume: Double)]) {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfMonth)!
        let endOfLastMonth = calendar.date(byAdding: .day, value: -1, to: startOfMonth)!
        
        // Get all sets for current month
        let currentMonthSets = thisYearSets.filter { guard let date = $0.date else { return false }; return date >= startOfMonth }
        let lastMonthSets = thisYearSets.filter { guard let date = $0.date else { return false }; return date >= startOfLastMonth && date <= endOfLastMonth }
        
        // Process current month data
        var currentMonthData: [(date: Date, volume: Double)] = []
        var runningVolume: Double = 0
        let currentMonthDays = calendar.range(of: .day, in: .month, for: now)?.count ?? 0
        
        for day in 1...currentMonthDays {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                let dayVolume = currentMonthSets
                    .filter { guard let setDate = $0.date else { return false }; return calendar.isDate(setDate, inSameDayAs: date) }
                    .reduce(0.0) { $0 + (Double($1.reps) * $1.weight) }
                runningVolume += dayVolume
                currentMonthData.append((date: date, volume: runningVolume))
            }
        }
        
        // Process last month data
        var lastMonthData: [(date: Date, volume: Double)] = []
        runningVolume = 0
        let lastMonthDays = calendar.range(of: .day, in: .month, for: startOfLastMonth)?.count ?? 0
        
        for day in 1...lastMonthDays {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfLastMonth) {
                let dayVolume = lastMonthSets
                    .filter { guard let setDate = $0.date else { return false }; return calendar.isDate(setDate, inSameDayAs: date) }
                    .reduce(0.0) { $0 + (Double($1.reps) * $1.weight) }
                runningVolume += dayVolume
                lastMonthData.append((date: date, volume: runningVolume))
            }
        }
        
        return (current: currentMonthData, last: lastMonthData)
    }
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Today's Volume")
                            .font(.headline)
                        Spacer()
                        Text("\(NumberFormatter.volumeFormatter.string(from: NSNumber(value: todaysVolume)) ?? "0") lbs")
                            .font(.title2)
                            .bold()
                    }
                    
                    if todaysWorkoutSets.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 40))
                                .foregroundColor(.blue)
                            Text("No sets logged today")
                                .font(.headline)
                            Text("Add your first set to start tracking")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                }
                .padding(.vertical, 8)
            }
            
            Section("Monthly Comparison") {
                if thisYearSets.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        Text("No monthly data available")
                            .font(.headline)
                        Text("Start logging workouts to see your progress")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        let volumes = getCumulativeVolumes()
                        VolumeComparisonView(
                            title: "Month to Date",
                            currentValue: selectedCurrentVolume,
                            previousValue: selectedPreviousVolume
                        )
                        
                        CumulativeVolumeChart(
                            currentMonthData: volumes.current,
                            lastMonthData: volumes.last,
                            currentValue: $selectedCurrentVolume,
                            previousValue: $selectedPreviousVolume
                        )
                        .onAppear {
                            selectedCurrentVolume = volumes.current.last?.volume ?? 0
                            selectedPreviousVolume = volumes.last.last?.volume ?? 0
                        }
                    }
                }
            }
            
            Section("Yearly Comparison") {
                if thisYearSets.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        Text("No yearly data available")
                            .font(.headline)
                        Text("Track your progress over time")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    VolumeComparisonView(
                        title: "Year to Date",
                        currentValue: thisYearVolume,
                        previousValue: lastYearVolume
                    )
                }
            }
            
            Section("Weekly Activity") {
                if thisWeekWorkouts.isEmpty && lastWeekWorkouts.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        Text("No weekly activity")
                            .font(.headline)
                        Text("Start logging workouts to track your activity")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("This Week")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(thisWeekWorkouts.count) workouts")
                                .font(.headline)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Last Week")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(lastWeekWorkouts.count) workouts")
                                .font(.headline)
                        }
                    }
                }
            }
            
            Section("Volume Trend") {
                if thisYearSets.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        Text("No volume trend data")
                            .font(.headline)
                        Text("Log workouts to see your volume trends")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        // Time range selector
                        Picker("Time Range", selection: $selectedTimeRange) {
                            ForEach(TimeRange.allCases, id: \.self) { range in
                                Text(range.title).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.bottom, 4)
                        
                        if selectedTimeRange == .oneMonth {
                            VolumeTrendChart(volumes: monthlyVolumes())
                        } else {
                            MonthlyVolumeChart(volumes: monthlyVolumes(), timeRange: selectedTimeRange)
                        }
                    }
                }
            }
        }
        .navigationTitle("Dashboard")
    }
    
    private func monthlyVolumes() -> [(date: Date, volume: Double)] {
        let calendar = Calendar.current
        let now = Date()
        let monthsAgo = calendar.date(byAdding: .month, value: -selectedTimeRange.rawValue, to: now)!
        
        // Create a dictionary to store volumes
        var volumeDict: [Date: Double] = [:]
        
        // Get all sets from Core Data
        let allSetsFetchRequest: NSFetchRequest<CDWorkoutSet> = CDWorkoutSet.fetchRequest()
        allSetsFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CDWorkoutSet.date, ascending: true)]
        
        do {
            let allSets = try viewContext.fetch(allSetsFetchRequest)
            
            // Calculate volumes for each set
            let filteredSets = allSets.filter { guard let date = $0.date else { return false }; return date >= monthsAgo }
            
            for set in filteredSets {
                guard let date = set.date else { continue }
                let setVolume = Double(set.reps) * set.weight
                
                if selectedTimeRange == .oneMonth {
                    // For 1M view, group by day
                    let dayStart = calendar.startOfDay(for: date)
                    volumeDict[dayStart, default: 0] += setVolume
                } else {
                    // For all other views (3M, 6M, 1Y, 2Y), group by month
                    let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
                    volumeDict[monthStart, default: 0] += setVolume
                }
            }
        } catch {
            print("Error fetching sets: \(error)")
        }
        
        // Convert dictionary to array and sort by date
        return volumeDict.map { ($0.key, $0.value) }
            .sorted { $0.0 < $1.0 }
    }
}

extension NumberFormatter {
    static let volumeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        return formatter
    }()
}

// MARK: - Helper Views

struct VolumeTrendChart: View {
    let volumes: [(date: Date, volume: Double)]
    @Environment(\.colorScheme) var colorScheme
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        if volumes.count <= 31 { // Daily data
            formatter.dateFormat = "MMM d" // Show month and day to avoid confusion
        } else if volumes.count <= 6 { // Monthly data for 3M/6M
            formatter.dateFormat = "MMM" // Show month abbreviation
        } else if volumes.count <= 12 { // Monthly data for 1Y
            formatter.dateFormat = "MMM" // Show month abbreviation
        } else { // Monthly data for 2Y
            formatter.dateFormat = "MMM yy" // Show month and year
        }
        return formatter
    }
    
    private var maxVolume: Double {
        volumes.map { $0.volume }.max() ?? 0
    }
    
    private var yAxisValues: [Double] {
        if maxVolume == 0 {
            return [0, 100, 200, 300, 400, 500] // Default values for no data
        }
        
        let step: Double
        if maxVolume < 1000 {
            step = max(round(maxVolume / 4 / 100) * 100, 100) // Round to nearest 100 for small volumes
        } else if maxVolume < 10000 {
            step = max(round(maxVolume / 4 / 1000) * 1000, 1000) // Round to nearest 1000 for medium volumes
        } else {
            step = max(round(maxVolume / 4 / 10000) * 10000, 10000) // Round to nearest 10000 for large volumes
        }
        
        let values = stride(from: 0, through: maxVolume, by: step).map { $0 }
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
    
    private var xAxisStride: Int {
        if volumes.count <= 31 { // Daily data
            return max(1, volumes.count / 5) // Show about 5 labels for daily data
        } else if volumes.count <= 6 { // Monthly data for 3M/6M
            return 1 // Show every month
        } else if volumes.count <= 12 { // Monthly data for 1Y
            return 2 // Show every other month
        }
        return 3 // Show every third month for 2Y
    }
    
    private var shouldCenterLabels: Bool {
        volumes.count <= 6 // Center labels for 3M and 6M views
    }
    
    private var isDailyData: Bool {
        volumes.count <= 31
    }
    
    var body: some View {
        if volumes.isEmpty {
            Text("No data available")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        } else {
            Chart {
                ForEach(volumes, id: \.date) { item in
                    BarMark(
                        x: .value("Date", item.date, unit: isDailyData ? .day : .month),
                        y: .value("Volume", item.volume)
                    )
                    .foregroundStyle(Color.blue)
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(
                    preset: shouldCenterLabels ? .automatic : .aligned,
                    position: .bottom,
                    values: .stride(by: isDailyData ? .day : .month, count: xAxisStride)
                ) { value in
                    if value.as(Date.self) == volumes.first?.date {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    } else {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                    }
                    AxisTick(stroke: StrokeStyle(lineWidth: 1))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(dateFormatter.string(from: date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .offset(y: shouldCenterLabels ? 4 : 8) // Increase offset for non-centered labels
                }
            }
            .chartXScale(domain: ClosedRange(uncheckedBounds: (volumes.first?.date ?? Date(), volumes.last?.date ?? Date())))
            .chartYAxis {
                AxisMarks(
                    position: .leading,
                    values: .automatic(desiredCount: 4)
                ) { value in
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
            .padding(.top)
        }
    }
}

struct MonthlyVolumeChart: View {
    let volumes: [(date: Date, volume: Double)]
    let timeRange: TimeRange
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        if timeRange == .twentyFourMonths {
            formatter.dateFormat = "MMM yy"
        } else {
            formatter.dateFormat = "MMM"
        }
        return formatter
    }
    
    private var maxVolume: Double {
        volumes.map { $0.volume }.max() ?? 0
    }
    
    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1_000_000 {
            return String(format: "%.0fM", volume / 1_000_000)
        } else if volume >= 1_000 {
            return String(format: "%.0fK", volume / 1_000)
        }
        return NumberFormatter.volumeFormatter.string(from: NSNumber(value: volume)) ?? "0"
    }
    
    private func shouldShowLabel(for index: Int) -> Bool {
        switch timeRange {
        case .threeMonths, .sixMonths:
            return true // Show all labels
        case .twelveMonths:
            return index % 3 == 0 // Show every third month
        case .twentyFourMonths:
            return index % 6 == 0 // Show every sixth month
        case .oneMonth:
            return true
        }
    }
    
    var body: some View {
        if volumes.isEmpty {
            Text("No data available")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        } else {
            Chart {
                ForEach(Array(volumes.enumerated()), id: \.element.date) { index, item in
                    BarMark(
                        x: .value("Month", dateFormatter.string(from: item.date)),
                        y: .value("Volume", item.volume)
                    )
                    .foregroundStyle(Color.blue)
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks { value in
                    if let month = value.as(String.self),
                       let index = volumes.firstIndex(where: { dateFormatter.string(from: $0.date) == month }),
                       shouldShowLabel(for: index) {
                        AxisValueLabel {
                            Text(month)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .offset(y: 4)
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
            .padding(.top)
        }
    }
}

// VolumeComparisonView moved to its own file: VolumeComparisonView.swift 
