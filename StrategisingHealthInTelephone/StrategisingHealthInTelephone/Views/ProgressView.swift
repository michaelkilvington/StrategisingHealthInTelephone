import SwiftUI
import SwiftData
import Charts
import PhotosUI

struct WeightProgressView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightLog.date, order: .forward) private var weightLogs: [WeightLog]
    @Query private var profiles: [UserProfile]
    
    @State private var showingAddWeight = false
    @State private var timeRange: TimeRange = .month
    
    enum TimeRange: String, CaseIterable {
        case week = "1W"
        case month = "1M"
        case threeMonths = "3M"
        case year = "1Y"
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
                    
                    allLogsSection
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
        case .year:
            let startDate = calendar.date(byAdding: .year, value: -1, to: now)!
            return weightLogs.filter { $0.date >= startDate }
        case .all:
            return weightLogs
        }
    }
    
    // ✅ Actual spread of visible data in days
    var dateRangeInDays: Int {
        guard let first = filteredLogs.first, let last = filteredLogs.last else { return 1 }
        return Calendar.current.dateComponents([.day], from: first.date, to: last.date).day ?? 1
    }
    
    // ✅ Dynamic x-axis stride component based on actual data spread
    var xAxisStride: Calendar.Component {
        switch dateRangeInDays {
        case 0...14:   return .day
        case 15...60:  return .weekOfYear
        case 61...730: return .month
        default:       return .year
        }
    }
    
    // ✅ Dynamic x-axis stride count to prevent label crowding
    var xAxisStrideCount: Int {
        switch dateRangeInDays {
        case 0...14:    return 1
        case 15...60:   return 1
        case 61...180:  return 1
        case 181...365: return 2       // Every 2 months for ~1 year
        case 366...730: return 3       // Every 3 months for ~2 years
        case 731...1825: return 6      // Every 6 months for 2-5 years
        default:        return 12      // Every year for 5+ years
        }
    }
    
    // ✅ Dynamic x-axis date format based on data spread
    var xAxisDateFormat: Date.FormatStyle {
        switch dateRangeInDays {
        case 0...60:   return .dateTime.day().month(.abbreviated)
        case 61...365: return .dateTime.month(.abbreviated)
        case 366...730: return .dateTime.month(.abbreviated).year(.twoDigits)
        default:       return .dateTime.year()
        }
    }
    
    // ✅ Y-axis min with padding
    var weightMin: Double {
        let min = filteredLogs.map { $0.weight }.min() ?? 0
        return (min - 2).rounded(.down)
    }
    
    // ✅ Y-axis max with padding
    var weightMax: Double {
        let max = filteredLogs.map { $0.weight }.max() ?? 100
        return (max + 2).rounded(.up)
    }
    
    // ✅ Dynamic y-axis stride based on visible weight range
    var yAxisStride: Double {
        let range = weightMax - weightMin
        switch range {
        case 0...5:   return 0.5
        case 5...15:  return 1
        case 15...30: return 2
        case 30...60: return 5
        default:      return 10
        }
    }
    
    var weightChartSection: some View {
        VStack(alignment: .leading) {
            Text("Weight Trend")
                .font(.headline)
            
            if filteredLogs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No weight data")
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            } else {
                Chart {
                    ForEach(filteredLogs) { log in
                        LineMark(
                            x: .value("Date", log.date, unit: .day),
                            y: .value("Weight", log.weight)
                        )
                        .foregroundStyle(Color.blue)
                        
                        // ✅ Only show point marks on shorter ranges
                        if timeRange == .week || timeRange == .month {
                            PointMark(
                                x: .value("Date", log.date, unit: .day),
                                y: .value("Weight", log.weight)
                            )
                            .foregroundStyle(Color.blue)
                        }
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
                // ✅ Dynamic y-axis scale and labels
                .chartYScale(domain: weightMin...weightMax)
                .chartYAxis {
                    AxisMarks(values: .stride(by: yAxisStride)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let kg = value.as(Double.self) {
                                Text("\(String(format: "%.1f", kg))")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                // ✅ Dynamic x-axis labels based on actual date range
                .chartXAxis {
                    AxisMarks(values: .stride(by: xAxisStride, count: xAxisStrideCount)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: xAxisDateFormat)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    var allLogsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Weight History")
                .font(.headline)
                .padding(.bottom, 12)
            
            if weightLogs.isEmpty {
                Text("No weight logs yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(weightLogs.reversed())) { log in
                    WeightLogRow(log: log, onDelete: { deleteWeightLog(log) })
                    
                    if log.id != weightLogs.first?.id {
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

struct WeightLogRow: View {
    let log: WeightLog
    let onDelete: () -> Void
    
    @State private var showingCamera = false
    @State private var showingPhoto = false
    @State private var capturedImageData: Data? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formattedDate(log.date))
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text("\(String(format: "%.1f", log.weight)) kg")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    if let photoData = log.photo, let uiImage = UIImage(data: photoData) {
                        Button(action: { showingPhoto = true }) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    } else {
                        Button(action: { showingCamera = true }) {
                            Image(systemName: "camera")
                                .foregroundColor(.blue)
                                .frame(width: 44, height: 44)
                        }
                    }
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .onChange(of: capturedImageData) {
            if let data = capturedImageData {
                log.photo = data
                capturedImageData = nil
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView(imageData: $capturedImageData)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showingPhoto) {
            if let photoData = log.photo, let uiImage = UIImage(data: photoData) {
                PhotoViewerSheet(image: uiImage, onRemove: {
                    log.photo = nil
                    showingPhoto = false
                })
            }
        }
    }
    
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct PhotoViewerSheet: View {
    let image: UIImage
    let onRemove: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding()
                Spacer()
            }
            .navigationTitle("Progress Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Remove", role: .destructive) {
                        onRemove()
                    }
                }
            }
        }
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
    @State private var showingCamera = false
    @State private var photoData: Data? = nil
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
                
                Section("Progress Photo (Optional)") {
                    if let data = photoData, let uiImage = UIImage(data: data) {
                        HStack {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Spacer()
                            Button("Remove", role: .destructive) {
                                photoData = nil
                            }
                        }
                    } else {
                        Button(action: { showingCamera = true }) {
                            Label("Take Photo", systemImage: "camera")
                        }
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
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView(imageData: $photoData)
                    .ignoresSafeArea()
            }
        }
    }
    
    func saveWeight() {
        guard let weightValue = Double(weight) else { return }
        
        let weightLog = WeightLog(date: selectedDate, weight: weightValue)
        weightLog.photo = photoData
        modelContext.insert(weightLog)
        
        if let profile = profiles.first {
            profile.currentWeight = weightValue
        }
        
        try? modelContext.save()
        dismiss()
    }
}
