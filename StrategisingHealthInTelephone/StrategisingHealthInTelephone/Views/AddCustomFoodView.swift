//
//  AddCustomFoodView.swift
//  StrategisingHealthInTelephone
//
//  Created by Michael Kilvington on 5/5/2026.
//
import SwiftUI

struct AddCustomFoodView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var submission = CustomFoodSubmission()
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false
    
    // Text field states for numeric input
    @State private var caloriesText = ""
    @State private var proteinText = ""
    @State private var carbsText = ""
    @State private var fatText = ""
    @State private var fiberText = ""
    @State private var sugarText = ""
    @State private var sodiumText = ""
    @State private var servingSizeText = "100"
    
    var isValid: Bool {
        !submission.name.isEmpty && !caloriesText.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Food Information") {
                    TextField("Name (required)", text: $submission.name)
                    TextField("Brand (optional)", text: $submission.brand)
                }
                
                Section("Serving Size") {
                    HStack {
                        TextField("100", text: $servingSizeText)
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                        TextField("g", text: $submission.servingUnit)
                            .frame(width: 60)
                        Text("per serving")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Nutrition per Serving") {
                    nutritionField("Calories (kcal)", text: $caloriesText)
                    nutritionField("Protein (g)", text: $proteinText)
                    nutritionField("Carbohydrates (g)", text: $carbsText)
                    nutritionField("Fat (g)", text: $fatText)
                    nutritionField("Fiber (g)", text: $fiberText)
                    nutritionField("Sugar (g)", text: $sugarText)
                    nutritionField("Sodium (mg)", text: $sodiumText)
                }
                
                Section("Barcode (optional)") {
                    TextField("e.g. 9352042000328", text: Binding(
                        get: { submission.barcode ?? "" },
                        set: { submission.barcode = $0.isEmpty ? nil : $0 }
                    ))
                    .keyboardType(.numberPad)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                Section {
                    Button(action: submit) {
                        if isSubmitting {
                            HStack {
                                SwiftUI.ProgressView()
                                Text("Submitting...")
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            Text("Submit Food")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .foregroundColor(isValid ? .blue : .gray)
                        }
                    }
                    .disabled(!isValid || isSubmitting)
                }
            }
            .navigationTitle("Add Custom Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Food Submitted!", isPresented: $showingSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("\(submission.name) has been added to the shared food database and is now searchable by all users.")
            }
        }
    }
    
    func nutritionField(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
    }
    
    func submit() {
        submission.calories = Double(caloriesText) ?? 0
        submission.protein = Double(proteinText) ?? 0
        submission.carbs = Double(carbsText) ?? 0
        submission.fat = Double(fatText) ?? 0
        submission.fiber = Double(fiberText) ?? 0
        submission.sugar = Double(sugarText) ?? 0
        submission.sodium = Double(sodiumText) ?? 0
        submission.servingSize = Double(servingSizeText) ?? 100
        
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                try await CustomFoodService.shared.submitFood(submission)
                await MainActor.run {
                    isSubmitting = false
                    showingSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "Failed to submit: \(error.localizedDescription)"
                }
            }
        }
    }
}
