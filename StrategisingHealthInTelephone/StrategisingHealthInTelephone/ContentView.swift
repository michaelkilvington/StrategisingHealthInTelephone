import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var selectedTab = 0
    
    var body: some View {
        if profiles.isEmpty {
            ProfileSetupView()
        } else {
            TabView(selection: $selectedTab) {
                DailyDiaryView()
                    .tabItem {
                        Label("Diary", systemImage: "calendar")
                    }
                    .tag(0)
                
                WeightProgressView()
                    .tabItem {
                        Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(1)
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(2)
            }
        }
    }
}

struct ProfileSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var gender = Gender.male
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    @State private var height = 170.0
    @State private var currentWeight = 70.0
    @State private var goalWeight = 65.0
    @State private var weeklyWeightLoss = 0.5
    @State private var activityLevel = ActivityLevel.moderate
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Personal Information") {
                    TextField("Name", text: $name)
                    Picker("Gender", selection: $gender) {
                        ForEach(Gender.allCases, id: \.self) { g in
                            Text(g.rawValue).tag(g)
                        }
                    }
                    DatePicker("Birth Date", selection: $birthDate, displayedComponents: .date)
                    Stepper("Height: \(Int(height)) cm", value: $height, in: 140...220)
                    Stepper("Current Weight: \(String(format: "%.1f", currentWeight)) kg", value: $currentWeight, in: 40...200, step: 0.1)
                }
                
                Section("Goals") {
                    Stepper("Goal Weight: \(String(format: "%.1f", goalWeight)) kg", value: $goalWeight, in: 40...200, step: 0.1)
                    Stepper("Weekly Loss: \(String(format: "%.1f", weeklyWeightLoss)) kg", value: $weeklyWeightLoss, in: 0.1...2.0, step: 0.1)
                    Picker("Activity Level", selection: $activityLevel) {
                        ForEach(ActivityLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                }
                
                if let profile = calculateProfile() {
                    Section("Calculated Targets") {
                        Text("Daily Calories: \(Int(profile.dailyCalorieTarget)) kcal")
                        Text("Protein: \(Int(profile.proteinTarget))g")
                        Text("Carbs: \(Int(profile.carbsTarget))g")
                        Text("Fat: \(Int(profile.fatTarget))g")
                    }
                }
            }
            .navigationTitle("Setup Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                }
            }
        }
    }
    
    func calculateProfile() -> UserProfile? {
        guard !name.isEmpty else { return nil }
        let profile = UserProfile(
            name: name,
            gender: gender,
            birthDate: birthDate,
            height: height,
            currentWeight: currentWeight,
            goalWeight: goalWeight,
            weeklyWeightLossGoal: weeklyWeightLoss,
            activityLevel: activityLevel
        )
        profile.dailyCalorieTarget = profile.calculateDailyCalorieTarget()
        let macros = profile.calculateMacroTargets()
        profile.proteinTarget = macros.protein
        profile.carbsTarget = macros.carbs
        profile.fatTarget = macros.fat
        return profile
    }
    
    func saveProfile() {
        guard let profile = calculateProfile() else { return }
        modelContext.insert(profile)
        try? modelContext.save()
    }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var edamamAppId = ""
    @State private var edamamAppKey = ""
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var exportURL: URL?
    @State private var exportData: Data?
    @State private var exportType: ExportType = .daily

    enum ExportType {
        case daily, weight, all
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Edamam API") {
                    TextField("App ID", text: $edamamAppId)
                    TextField("App Key", text: $edamamAppKey)
                    Button("Save API Keys") {
                        EdamamConfig.appId = edamamAppId
                        EdamamConfig.appKey = edamamAppKey
                    }
                }

                Section("Profile") {
                    if let profile = profiles.first {
                        BindableProfileSection(profile: profile)
                    }
                }

                Section("Data Management") {
                    Button("Export Daily Logs CSV") {
                        exportType = .daily
                        exportURL = CSVService.shared.exportDailyLogs(modelContext: modelContext)
                        if let url = exportURL, let data = try? Data(contentsOf: url) {
                            exportData = data
                            exportURL = url
                        }
                        showingExporter = true
                    }
                    .foregroundColor(.blue)

                    Button("Export Weight Logs CSV") {
                        exportType = .weight
                        exportURL = CSVService.shared.exportWeightLogs(modelContext: modelContext)
                        if let url = exportURL, let data = try? Data(contentsOf: url) {
                            exportData = data
                        }
                        showingExporter = true
                    }
                    .foregroundColor(.blue)

                    Button("Export All Data CSV") {
                        exportType = .all
                        exportURL = CSVService.shared.exportAllData(modelContext: modelContext)
                        if let url = exportURL, let data = try? Data(contentsOf: url) {
                            exportData = data
                        }
                        showingExporter = true
                    }
                    .foregroundColor(.blue)

                    Button("Import MyFitnessPal Weight CSV") {
                        showingImporter = true
                    }
                    .foregroundColor(.blue)
                }

                Section("Cloud Sync") {
                    Button("Sync to iCloud") {
                        Task {
                            await CloudKitService.shared.syncAllData(modelContext: modelContext)
                        }
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Settings")
            .fileExporter(
                isPresented: $showingExporter,
                document: exportData.map { CSVFile(data: $0) },
                contentType: UTType.commaSeparatedText,
                defaultFilename: exportURL?.lastPathComponent ?? "export.csv"
            ) { result in
                switch result {
                case .success:
                    print("Export successful")
                case .failure(let error):
                    print("Export failed: \(error)")
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [UTType.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        CSVService.shared.importMyFitnessPalWeightCSV(url: url, modelContext: modelContext)
                    }
                case .failure(let error):
                    print("Import failed: \(error)")
                }
            }
        }
    }
}

struct BindableProfileSection: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Stepper("Height: \(Int(profile.height)) cm", value: $profile.height, in: 140...220)
        Stepper("Current Weight: \(String(format: "%.1f", profile.currentWeight)) kg", value: $profile.currentWeight, in: 40...200, step: 0.1)
        Stepper("Goal Weight: \(String(format: "%.1f", profile.goalWeight)) kg", value: $profile.goalWeight, in: 40...200, step: 0.1)
        Picker("Activity Level", selection: $profile.activityLevel) {
            ForEach(ActivityLevel.allCases, id: \.self) { level in
                Text(level.rawValue).tag(level)
            }
        }
        Button("Recalculate Targets") {
            profile.dailyCalorieTarget = profile.calculateDailyCalorieTarget()
            let macros = profile.calculateMacroTargets()
            profile.proteinTarget = macros.protein
            profile.carbsTarget = macros.carbs
            profile.fatTarget = macros.fat
            try? modelContext.save()
        }
        .foregroundColor(.blue)
    }
}

struct CSVFile: FileDocument {
    static var readableContentTypes: [UTType] { [UTType.commaSeparatedText] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [UserProfile.self, DailyLog.self, WeightLog.self])
}
