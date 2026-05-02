import SwiftUI
import SwiftData
import Charts

struct WeightProgressView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightLog.date, order: .forward) private var weightLogs: [WeightLog]
    @Query private var profiles: [UserProfile]
    
    @State private var showingAddWeight = false
    @State private var selectedDate = Date()
    @State private var weightInput = ""
    @State private var timeRange: TimeRange = .month
    
    enum TimeRange: String, CaseIterable {
        case week = "1W"
        case month = "1M"
        case threeMonths = "3M"
        case all = "All"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let profile = profiles.first {
                        currentStatsSection(profile: profile)
                    }
                    
                    timeRangeSelector
                    
                    weightChartSection
                    
                    recentLogsSection
                }
                .padding()
            }
            .navigationTitle("Progress")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddWeight = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddWeight) {
                AddWeightView()
            }
        }
    }
    
    func currentStatsSection(profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Stats")
                .font(.headline)
            
            HStack(spacing: 20) {
                StatBox(title: "Current", value: String(format: "%.1f", profile.currentWeight), unit: "kg")
                StatBox(title: "Goal", value: String(format: "%.1f", profile.goalWeight), unit: "kg")
                StatBox(title: "To Go", value: String(format: "%.1f", max(0, profile.currentWeight - profile.goalWeight)), unit: "kg")
            }
            
            if let latestLog = weightLogs.last {
                Text("Latest: \(String(format: "%.1f", latestLog.weight)) kg on \(formattedDate(latestLog.date))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    var timeRangeSelector: some View {
        Picker("Time Range", selection: $timeRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
    }
    
    var filteredLogs: [WeightLog] {
        let calendar = Calendar.current
        let now = Date()
        
        switch timeRange {
        case .week:
            let startDate = calendar.date(byAdding: .day, value: -7, to: now)!
            return weightLogs.filter { $0.date >= startDate }
        case .month:
            let startDate = calendar.date(byAdding: .month, value: -1, to: now)!
            return weightLogs.filter { $0.date >= startDate }
        case .threeMonths:
            let startDate = calendar.date(byAdding: .month, value: -3, to: now)!
            return weightLogs.filter { $0.date >= startDate }
        case .all:
            return weightLogs
        }
    }
    
    var weightChartSection: some View {
        VStack(alignment: .leading) {
            Text("Weight Trend")
                .font(.headline)
            
            if filteredLogs.isEmpty {
                ContentUnavailableView("No weight data", systemImage: "chart.line.uptrend.xyaxis")
                    .frame(height: 200)
            } else {
                Chart {
                    ForEach(filteredLogs) { log in
                        LineMark(
                            x: .value("Date", log.date, unit: .day),
                            y: .value("Weight", log.weight)
                        )
                        .foregroundStyle(Color.blue)
                        
                        PointMark(
                            x: .value("Date", log.date, unit: .day),
                            y: .value("Weight", log.weight)
                        )
                        .foregroundStyle(Color.blue)
                    }
                    
                    if let profile = profiles.first {
                        RuleMark(y: .value("Goal", profile.goalWeight))
                            .foregroundStyle(Color.green)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                            .annotation(position: .trailing) {
                                Text("Goal")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                    }
                }
                .frame(height: 250)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: timeRange == .week ? 1 : 7)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    var recentLogsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Logs")
                .font(.headline)
            
            if weightLogs.isEmpty {
                Text("No weight logs yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(weightLogs.suffix(10).reversed())) { log in
                    HStack {
                        Text(formattedDate(log.date))
                        Spacer()
                        Text("\(String(format: "%.1f", log.weight)) kg")
                            .fontWeight(.medium)
                        Button(action: { deleteWeightLog(log) }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    if log.id != weightLogs.suffix(10).last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    func deleteWeightLog(_ log: WeightLog) {
        modelContext.delete(log)
        try? modelContext.save()
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(unit)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct AddWeightView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDate = Date()
    @State private var weight = ""
    @Query private var profiles: [UserProfile]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Weight Entry") {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    
                    HStack {
                        TextField("Weight", text: $weight)
                            .keyboardType(.decimalPad)
                        Text("kg")
                            .foregroundColor(.secondary)
                    }
                    
                    if let profile = profiles.first {
                        Text("Current: \(String(format: "%.1f", profile.currentWeight)) kg")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button("Save Weight") {
                        saveWeight()
                    }
                    .disabled(weight.isEmpty)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Log Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    func saveWeight() {
        guard let weightValue = Double(weight) else { return }
        
        let weightLog = WeightLog(date: selectedDate, weight: weightValue)
        modelContext.insert(weightLog)
        
        if let profile = profiles.first {
            profile.currentWeight = weightValue
        }
        
        try? modelContext.save()
        dismiss()
    }
}
