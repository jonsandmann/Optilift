import SwiftUI
import Charts
import CoreData

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
    
    enum TimeRange: Int, CaseIterable {
        case threeMonths = 3
        case sixMonths = 6
        case twelveMonths = 12
        case twentyFourMonths = 24
        
        var title: String {
            switch self {
            case .threeMonths: return "3M"
            case .sixMonths: return "6M"
            case .twelveMonths: return "1Y"
            case .twentyFourMonths: return "2Y"
            }
        }
    }
    
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
                VolumeComparisonView(
                    title: "Month to Date",
                    currentValue: thisMonthVolume,
                    previousValue: lastMonthVolume
                )
            }
            
            Section("Yearly Comparison") {
                VolumeComparisonView(
                    title: "Year to Date",
                    currentValue: thisYearVolume,
                    previousValue: lastYearVolume
                )
            }
            
            Section("Weekly Activity") {
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
            
            Section("Volume Trend") {
                VStack(alignment: .leading, spacing: 12) {
                    // Time range selector
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.title).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 4)
                    
                    if !thisYearSets.isEmpty {
                        VolumeTrendChart(volumes: monthlyVolumes())
                    } else {
                        Text("Start logging workouts to see your volume trend")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    }
                }
            }
            
            Section {
                NavigationLink {
                    WorkoutsView()
                } label: {
                    HStack {
                        Image(systemName: "list.bullet")
                        Text("View All Workouts")
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
        
        // Create a dictionary to store monthly volumes
        var monthlyVolumeDict: [Date: Double] = [:]
        
        // Get all sets from Core Data
        let allSetsFetchRequest: NSFetchRequest<CDWorkoutSet> = CDWorkoutSet.fetchRequest()
        allSetsFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CDWorkoutSet.date, ascending: true)]
        
        do {
            let allSets = try viewContext.fetch(allSetsFetchRequest)
            
            // Calculate volumes for each set
            let filteredSets = allSets.filter { guard let date = $0.date else { return false }; return date >= monthsAgo }
            
            for set in filteredSets {
                guard let date = set.date else { continue }
                let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
                let setVolume = Double(set.reps) * set.weight
                monthlyVolumeDict[monthStart, default: 0] += setVolume
            }
        } catch {
            print("Error fetching sets: \(error)")
        }
        
        // Convert dictionary to array and sort by date
        return monthlyVolumeDict.map { ($0.key, $0.value) }
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
        formatter.dateFormat = volumes.count > 12 ? "MMM yy" : "MMM"
        return formatter
    }
    
    private var maxVolume: Double {
        volumes.map { $0.volume }.max() ?? 0
    }
    
    private var yAxisValues: [Double] {
        let step = maxVolume / 4 // Create 4 major grid lines
        let roundedStep = round(step / 1000) * 1000 // Round to nearest 1000 for clean numbers
        return stride(from: 0, through: maxVolume, by: roundedStep).map { $0 }
    }
    
    private var xAxisStride: Int {
        // Show every label for 3M and 6M views
        if volumes.count <= 6 { return 1 }
        // Show every third label for 1Y view
        if volumes.count <= 12 { return 3 }
        // Show every fourth label for 2Y view
        return 4
    }
    
    private var shouldCenterLabels: Bool {
        volumes.count <= 6 // Center labels for 3M and 6M views
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
                        x: .value("Month", item.date, unit: .month),
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
                    values: shouldCenterLabels ? .automatic : .stride(by: .month, count: xAxisStride)
                ) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    AxisTick()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(dateFormatter.string(from: date))
                                .font(.caption)
                        }
                    }
                    .offset(y: 4)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: yAxisValues) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    AxisTick()
                    AxisValueLabel {
                        if let volume = value.as(Double.self) {
                            Text(NumberFormatter.volumeFormatter.string(from: NSNumber(value: volume)) ?? "")
                                .font(.caption)
                        }
                    }
                }
            }
            .padding(.top)
        }
    }
}

// VolumeComparisonView moved to its own file: VolumeComparisonView.swift 
