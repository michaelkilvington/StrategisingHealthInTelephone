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
    @State private var heightText = "170"
    @State private var currentWeightText = "70.0"
    @State private var goalWeightText = "65.0"
    @State private var weeklyWeightLossText = "0.5"
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
                    
                    HStack {
                        Text("Height (cm)")
                        Spacer()
                        TextField("170", text: $heightText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    HStack {
                        Text("Current Weight (kg)")
                        Spacer()
                        TextField("70.0", text: $currentWeightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
                
                Section("Goals") {
                    HStack {
                        Text("Goal Weight (kg)")
                        Spacer()
                        TextField("65.0", text: $goalWeightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    HStack {
                        Text("Weekly Loss (kg)")
                        Spacer()
                        TextField("0.5", text: $weeklyWeightLossText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
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
        guard !name.isEmpty,
              let height = Double(heightText),
              let currentWeight = Double(currentWeightText),
              let goalWeight = Double(goalWeightText),
              let weeklyWeightLoss = Double(weeklyWeightLossText) else { return nil }
        
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

struct BindableProfileSection: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    
    // Local text state for keyboard input
    @State private var heightText = ""
    @State private var currentWeightText = ""
    @State private var goalWeightText = ""

    var body: some View {
        HStack {
            Text("Height (cm)")
            Spacer()
            TextField("170", text: $heightText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .onAppear { heightText = String(Int(profile.height)) }
                .onChange(of: heightText) {
                    if let value = Double(heightText) { profile.height = value }
                }
        }
        
        HStack {
            Text("Current Weight (kg)")
            Spacer()
            TextField("70.0", text: $currentWeightText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .onAppear { currentWeightText = String(format: "%.1f", profile.currentWeight) }
                .onChange(of: currentWeightText) {
                    if let value = Double(currentWeightText) { profile.currentWeight = value }
                }
        }
        
        HStack {
            Text("Goal Weight (kg)")
            Spacer()
            TextField("65.0", text: $goalWeightText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .onAppear { goalWeightText = String(format: "%.1f", profile.goalWeight) }
                .onChange(of: goalWeightText) {
                    if let value = Double(goalWeightText) { profile.goalWeight = value }
                }
        }
        
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
