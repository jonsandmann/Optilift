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
    @State private var selectedTimeRange: TimeRange = .threeMonths
    @State private var showingAddWorkout = false
    @State private var selectedCurrentVolume: Double = 0
    @State private var selectedPreviousVolume: Double = 0
    
    // Single fetch request for workout sets
    @FetchRequest private var workoutSets: FetchedResults<CDWorkoutSet>
    
    private func formatVolume(_ volumeLbs: Double) -> String {
        return NumberFormatter.volumeFormatter.string(from: NSNumber(value: volumeLbs)) ?? "0"
    }
    
    init() {
        // Initialize with a default predicate that will be updated
        _workoutSets = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \CDWorkoutSet.date, ascending: true)],
            predicate: NSPredicate(format: "date >= %@", Date() as NSDate)
        )
    }
    
    private func updateFetchRequest() {
        let calendar = Calendar.current
        let now = Date()
        
        // Calculate date range based on selected time range
        let startDate: Date
        let endDate: Date
        
        switch selectedTimeRange {
        case .oneMonth:
            startDate = calendar.date(byAdding: .month, value: -1, to: now)!
            endDate = now
        case .threeMonths:
            startDate = calendar.date(byAdding: .month, value: -3, to: now)!
            endDate = now
        case .sixMonths:
            startDate = calendar.date(byAdding: .month, value: -6, to: now)!
            endDate = now
        case .twelveMonths:
            startDate = calendar.date(byAdding: .month, value: -12, to: now)!
            endDate = now
        case .twentyFourMonths:
            startDate = calendar.date(byAdding: .month, value: -24, to: now)!
            endDate = now
        }
        
        // Create a new fetch request with the updated predicate
        let request = CDWorkoutSet.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDWorkoutSet.date, ascending: true)]
        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", startDate as NSDate, endDate as NSDate)
        
        // Update the fetch request
        workoutSets.nsPredicate = request.predicate
        _ = try? viewContext.fetch(request)
    }
    
    private var todaysVolume: Double {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        
        return workoutSets
            .filter { $0.date ?? Date() >= startOfToday && $0.date ?? Date() < endOfToday }
            .reduce(0.0) { $0 + (Double($1.reps) * $1.weight) }
    }
    
    private var lastMonthVolume: Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfMonth)!
        let endOfLastMonth = calendar.date(byAdding: .day, value: -1, to: startOfMonth)!
        
        return workoutSets
            .filter { $0.date ?? Date() >= startOfLastMonth && $0.date ?? Date() <= endOfLastMonth }
            .reduce(0.0) { $0 + (Double($1.reps) * $1.weight) }
    }
    
    private var thisYearVolume: Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
        let endOfYear = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: startOfYear)!
        
        return workoutSets
            .filter { $0.date ?? Date() >= startOfYear && $0.date ?? Date() <= endOfYear }
            .reduce(0.0) { $0 + (Double($1.reps) * $1.weight) }
    }
    
    private var lastYearVolume: Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
        let startOfLastYear = calendar.date(byAdding: .year, value: -1, to: startOfYear)!
        
        return workoutSets
            .filter { $0.date ?? Date() >= startOfLastYear }
            .reduce(0.0) { $0 + (Double($1.reps) * $1.weight) }
    }
    
    private var thisWeekWorkoutCount: Int {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek)!
        
        return Set(workoutSets
            .filter { $0.date ?? Date() >= startOfWeek && $0.date ?? Date() < endOfWeek }
            .map { $0.workout?.date ?? Date() })
            .count
    }
    
    private var lastWeekWorkoutCount: Int {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let startOfLastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfWeek)!
        let endOfLastWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfLastWeek)!
        
        return Set(workoutSets
            .filter { $0.date ?? Date() >= startOfLastWeek && $0.date ?? Date() < endOfLastWeek }
            .map { $0.workout?.date ?? Date() })
            .count
    }
    
    var body: some View {
        List {
            // Today's Activity Card
            Section {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Today's Activity")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("\(formatVolume(todaysVolume)) lbs")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                    }
                    
                    if workoutSets.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 40))
                                .foregroundStyle(.blue)
                            Text("No sets logged today")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Add your first set to start tracking")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }
                }
            }
            
            // Weekly Activity Card
            Section {
                VStack(spacing: 12) {
                    Text("Weekly Activity")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if thisWeekWorkoutCount == 0 && lastWeekWorkoutCount == 0 {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar")
                                .font(.system(size: 40))
                                .foregroundStyle(.blue)
                            Text("No weekly activity")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Start logging workouts to track your activity")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("This Week")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("\(thisWeekWorkoutCount) workouts")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(.primary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Last Week")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("\(lastWeekWorkoutCount) workouts")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(.primary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            
            // Volume Trend Card
            Section {
                VStack(spacing: 12) {
                    Text("Volume Trend")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if workoutSets.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.bar")
                                .font(.system(size: 40))
                                .foregroundStyle(.blue)
                            Text("No volume trend data")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Start logging workouts to see your progress")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        VStack(spacing: 16) {
                            Picker("Time Range", selection: $selectedTimeRange) {
                                ForEach(TimeRange.allCases, id: \.self) { range in
                                    Text(range.title).tag(range)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            if selectedTimeRange == .oneMonth {
                                VolumeTrendChart(volumes: monthlyVolumes())
                            } else {
                                MonthlyVolumeChart(volumes: monthlyVolumes(), timeRange: selectedTimeRange)
                            }
                        }
                    }
                }
            }
            
            // Cumulative Progress Card
            Section {
                VStack(spacing: 12) {
                    Text("Cumulative Progress")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if workoutSets.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 40))
                                .foregroundStyle(.blue)
                            Text("No progress data available")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Start logging workouts to track your progress")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        let volumes = getCumulativeVolumes()
                        CumulativeVolumeChart(
                            currentMonthData: volumes.currentMonth,
                            lastMonthData: volumes.lastMonth,
                            currentYearData: volumes.currentYear,
                            lastYearData: volumes.lastYear,
                            currentValue: $selectedCurrentVolume,
                            previousValue: $selectedPreviousVolume
                        )
                        .onAppear {
                            selectedCurrentVolume = volumes.currentMonth.last?.volume ?? 0
                            selectedPreviousVolume = volumes.lastMonth.last?.volume ?? 0
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Dashboard")
        .onChange(of: selectedTimeRange) { oldValue, newValue in
            updateFetchRequest()
        }
        .onAppear {
            updateFetchRequest()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
            updateFetchRequest()
        }
    }
    
    private func monthlyVolumes() -> [(date: Date, volume: Double)] {
        let calendar = Calendar.current
        let now = Date()
        let monthsAgo = calendar.date(byAdding: .month, value: -selectedTimeRange.rawValue + 1, to: now)!
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthsAgo))!
        
        // Create a dictionary to store volumes
        var volumeDict: [Date: Double] = [:]
        
        // Create a fetch request with the correct predicate
        let request = CDWorkoutSet.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDWorkoutSet.date, ascending: true)]
        request.predicate = NSPredicate(format: "date >= %@", startOfMonth as NSDate)
        
        // Add a batch size to limit memory usage
        request.fetchBatchSize = 100
        
        do {
            let filteredSets = try viewContext.fetch(request)
            
            // Process sets in batches
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
    
    private func getCumulativeVolumes() -> (
        currentMonth: [(date: Date, volume: Double)],
        lastMonth: [(date: Date, volume: Double)],
        currentYear: [(date: Date, volume: Double)],
        lastYear: [(date: Date, volume: Double)]
    ) {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfMonth)!
        let endOfLastMonth = calendar.date(byAdding: .day, value: -1, to: startOfMonth)!
        let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
        let startOfLastYear = calendar.date(byAdding: .year, value: -1, to: startOfYear)!
        
        // Create fetch requests with proper predicates and batch sizes
        let currentMonthRequest = CDWorkoutSet.fetchRequest()
        currentMonthRequest.predicate = NSPredicate(format: "date >= %@", startOfMonth as NSDate)
        currentMonthRequest.fetchBatchSize = 100
        
        let lastMonthRequest = CDWorkoutSet.fetchRequest()
        lastMonthRequest.predicate = NSPredicate(format: "date >= %@ AND date <= %@", startOfLastMonth as NSDate, endOfLastMonth as NSDate)
        lastMonthRequest.fetchBatchSize = 100
        
        let currentYearRequest = CDWorkoutSet.fetchRequest()
        currentYearRequest.predicate = NSPredicate(format: "date >= %@", startOfYear as NSDate)
        currentYearRequest.fetchBatchSize = 100
        
        let lastYearRequest = CDWorkoutSet.fetchRequest()
        lastYearRequest.predicate = NSPredicate(format: "date >= %@", startOfLastYear as NSDate)
        lastYearRequest.fetchBatchSize = 100
        
        // Fetch sets for each period
        let currentMonthSets = (try? viewContext.fetch(currentMonthRequest)) ?? []
        let lastMonthSets = (try? viewContext.fetch(lastMonthRequest)) ?? []
        let currentYearSets = (try? viewContext.fetch(currentYearRequest)) ?? []
        let lastYearSets = (try? viewContext.fetch(lastYearRequest)) ?? []
        
        // Process current month data
        var currentMonthData: [(date: Date, volume: Double)] = []
        var runningVolume: Double = 0
        let currentMonthDays = calendar.range(of: .day, in: .month, for: now)?.count ?? 0
        
        // Create a dictionary to store daily volumes
        var currentMonthVolumes: [Date: Double] = [:]
        
        // Calculate daily volumes
        for set in currentMonthSets {
            guard let date = set.date else { continue }
            let dayStart = calendar.startOfDay(for: date)
            let setVolume = Double(set.reps) * set.weight
            currentMonthVolumes[dayStart, default: 0] += setVolume
        }
        
        // Build cumulative data
        for day in 1...currentMonthDays {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                let dayVolume = currentMonthVolumes[date] ?? 0
                runningVolume += dayVolume
                currentMonthData.append((date: date, volume: runningVolume))
            }
        }
        
        // Process last month data
        var lastMonthData: [(date: Date, volume: Double)] = []
        runningVolume = 0
        let lastMonthDays = calendar.range(of: .day, in: .month, for: startOfLastMonth)?.count ?? 0
        
        // Create a dictionary to store daily volumes
        var lastMonthVolumes: [Date: Double] = [:]
        
        // Calculate daily volumes
        for set in lastMonthSets {
            guard let date = set.date else { continue }
            let dayStart = calendar.startOfDay(for: date)
            let setVolume = Double(set.reps) * set.weight
            lastMonthVolumes[dayStart, default: 0] += setVolume
        }
        
        // Build cumulative data
        for day in 1...lastMonthDays {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfLastMonth) {
                let dayVolume = lastMonthVolumes[date] ?? 0
                runningVolume += dayVolume
                lastMonthData.append((date: date, volume: runningVolume))
            }
        }
        
        // Process current year data
        var currentYearData: [(date: Date, volume: Double)] = []
        runningVolume = 0
        let currentYearDays = calendar.component(.dayOfYear, from: now)
        
        // Create a dictionary to store daily volumes
        var currentYearVolumes: [Date: Double] = [:]
        
        // Calculate daily volumes
        for set in currentYearSets {
            guard let date = set.date else { continue }
            let dayStart = calendar.startOfDay(for: date)
            let setVolume = Double(set.reps) * set.weight
            currentYearVolumes[dayStart, default: 0] += setVolume
        }
        
        // Build cumulative data
        for day in 1...currentYearDays {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfYear) {
                let dayVolume = currentYearVolumes[date] ?? 0
                runningVolume += dayVolume
                currentYearData.append((date: date, volume: runningVolume))
            }
        }
        
        // Process last year data
        var lastYearData: [(date: Date, volume: Double)] = []
        runningVolume = 0
        let lastYearDays = calendar.range(of: .day, in: .year, for: startOfLastYear)?.count ?? 0
        
        // Create a dictionary to store daily volumes
        var lastYearVolumes: [Date: Double] = [:]
        
        // Calculate daily volumes
        for set in lastYearSets {
            guard let date = set.date else { continue }
            let dayStart = calendar.startOfDay(for: date)
            let setVolume = Double(set.reps) * set.weight
            lastYearVolumes[dayStart, default: 0] += setVolume
        }
        
        // Build cumulative data
        for day in 1...lastYearDays {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfLastYear) {
                let dayVolume = lastYearVolumes[date] ?? 0
                runningVolume += dayVolume
                lastYearData.append((date: date, volume: runningVolume))
            }
        }
        
        return (currentMonth: currentMonthData, lastMonth: lastMonthData, currentYear: currentYearData, lastYear: lastYearData)
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
                .foregroundStyle(.secondary)
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
                    .offset(y: shouldCenterLabels ? 4 : 8)
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
            .padding(.horizontal, 20)
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
                .foregroundStyle(.secondary)
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
            .padding(.horizontal, 20)
        }
    }
}

// VolumeComparisonView moved to its own file: VolumeComparisonView.swift 
