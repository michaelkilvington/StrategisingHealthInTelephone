import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var appTheme: AppTheme
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var showingJSONImporter = false
    @State private var exportURL: URL?
    @State private var exportData: Data?
    @State private var exportType: ExportType = .daily
    @State private var jsonImportStartYear: String = "2016"

    enum ExportType {
        case daily, weight, all
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    if let profile = profiles.first {
                        BindableProfileSection(profile: profile)
                    }
                }

                Section("Appearance") {
                    Toggle(isOn: $appTheme.useGradientBackground) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Gradient Background")
                            Text("Applies to the diary view")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
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

                Section("Import MyFitnessPal JSON") {
                    HStack {
                        Text("Data start year")
                        Spacer()
                        TextField("2016", text: $jsonImportStartYear)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                    Button("Import Weight JSON") {
                        showingJSONImporter = true
                    }
                    .foregroundColor(.blue)
                    .disabled(Int(jsonImportStartYear) == nil)
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
            .fileImporter(
                isPresented: $showingJSONImporter,
                allowedContentTypes: [UTType.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first, let year = Int(jsonImportStartYear) {
                        CSVService.shared.importMyFitnessPalWeightJSON(
                            url: url,
                            modelContext: modelContext,
                            startYear: year
                        )
                    }
                case .failure(let error):
                    print("JSON import failed: \(error)")
                }
            }
        }
    }
}
