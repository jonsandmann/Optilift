import SwiftUI
import Charts
import CoreData

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest private var todaysWorkoutSets: FetchedResults<CDWorkoutSet>
    @FetchRequest private var thisMonthSets: FetchedResults<CDWorkoutSet>
    @FetchRequest private var lastMonthSets: FetchedResults<CDWorkoutSet>
    @FetchRequest private var thisYearSets: FetchedResults<CDWorkoutSet>
    @FetchRequest private var lastYearSets: FetchedResults<CDWorkoutSet>
    @FetchRequest private var thisWeekWorkouts: FetchedResults<CDWorkout>
    @FetchRequest private var lastWeekWorkouts: FetchedResults<CDWorkout>
    
    private let kgToLbsMultiplier = 2.20462
    
    private func formatVolume(_ volumeKg: Double) -> String {
        let volumeLbs = volumeKg * kgToLbsMultiplier
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
        
        // This month's sets
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        _thisMonthSets = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \CDWorkoutSet.date, ascending: true)],
            predicate: NSPredicate(format: "date >= %@ AND date <= %@", startOfMonth as NSDate, endOfMonth as NSDate)
        )
        
        // Last month's sets
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
        let endOfLastYear = calendar.date(byAdding: .day, value: -1, to: startOfYear)!
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
        thisMonthSets.reduce(0.0) { $0 + (Double($1.reps) * $1.weight) }
    }
    
    private var lastMonthVolume: Double {
        lastMonthSets.reduce(0.0) { $0 + (Double($1.reps) * $1.weight) }
    }
    
    private var thisYearVolume: Double {
        thisYearSets.reduce(0.0) { $0 + (Double($1.reps) * $1.weight) }
    }
    
    private var lastYearVolume: Double {
        lastYearSets.reduce(0.0) { $0 + (Double($1.reps) * $1.weight) }
    }
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Today's Volume")
                        .font(.headline)
                    Text("\(formatVolume(todaysVolume)) lbs")
                        .font(.system(size: 34, weight: .bold))
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
                if !thisYearSets.isEmpty {
                    Chart {
                        ForEach(monthlyVolumes(), id: \.date) { item in
                            BarMark(
                                x: .value("Month", item.date, unit: .month),
                                y: .value("Volume", item.volume * kgToLbsMultiplier)
                            )
                        }
                    }
                    .frame(height: 200)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let volume = value.as(Double.self) {
                                    Text(NumberFormatter.volumeFormatter.string(from: NSNumber(value: volume)) ?? "")
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month)) { value in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                        }
                    }
                    .padding(.top)
                } else {
                    Text("Start logging workouts to see your volume trend")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            }
        }
        .navigationTitle("Dashboard")
    }
    
    private func monthlyVolumes() -> [(date: Date, volume: Double)] {
        let calendar = Calendar.current
        let now = Date()
        let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: now)!
        
        return thisYearSets
            .filter { $0.date ?? Date() >= sixMonthsAgo }
            .reduce(into: [:]) { result, set in
                guard let date = set.date else { return }
                let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
                result[monthStart, default: 0] += Double(set.reps) * set.weight
            }
            .map { ($0.key, $0.value) }
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

// VolumeComparisonView moved to its own file: VolumeComparisonView.swift 