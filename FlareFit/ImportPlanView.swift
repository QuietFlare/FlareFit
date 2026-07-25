//
//  ImportPlanView.swift
//  FlareFit
//

import SwiftUI
import PhotosUI

struct ImportPlanView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (WorkoutPlan) -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isAnalyzing = false
    @State private var extractedPlan: WorkoutPlan?
    @State private var errorMessage: String?

    private let importer = ClaudePlanImporter()

    var body: some View {
        NavigationStack {
            List {
                photoSection

                if selectedImage != nil && extractedPlan == nil {
                    analyzeSection
                }

                if let plan = extractedPlan {
                    resultSection(plan)
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Create from Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: selectedItem) {
                Task { await loadImage() }
            }
        }
    }

    // MARK: - Sections

    private var photoSection: some View {
        Section {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 260)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .listRowInsets(EdgeInsets())
                    .padding(8)
            }
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label(selectedImage == nil ? "Choose Photo" : "Choose a Different Photo",
                      systemImage: "photo.on.rectangle")
            }
        } footer: {
            Text("Snap a picture of any workout plan — whiteboard, magazine, handwritten note — and AI will turn it into a FlareFit plan.")
        }
    }

    private var analyzeSection: some View {
        Section {
            Button {
                Task { await analyze() }
            } label: {
                if isAnalyzing {
                    HStack {
                        ProgressView()
                        Text("Analyzing photo…")
                            .padding(.leading, 8)
                    }
                } else {
                    Label("Extract Plan with AI", systemImage: "sparkles")
                }
            }
            .disabled(isAnalyzing)
        }
    }

    private func resultSection(_ plan: WorkoutPlan) -> some View {
        Group {
            Section("Extracted Plan") {
                LabeledContent("Name", value: plan.name)
                if plan.repetitions > 1 {
                    LabeledContent("Plan repeats", value: "\(plan.repetitions)×")
                }
                LabeledContent("Switch timer", value: "\(plan.switchSeconds)s")
                ForEach(plan.exercises) { exercise in
                    ExerciseRow(exercise: exercise)
                }
            }
            Section {
                Button {
                    onAdd(plan)
                    dismiss()
                } label: {
                    Label("Add Plan", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                }
                Button("Re-analyze", role: .destructive) {
                    extractedPlan = nil
                }
            } footer: {
                Text("You can fine-tune every exercise after adding.")
            }
        }
    }

    // MARK: - Actions

    private func loadImage() async {
        guard let selectedItem else { return }
        extractedPlan = nil
        errorMessage = nil
        if let data = try? await selectedItem.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            selectedImage = image
        } else {
            errorMessage = "Couldn't load that photo. Try another one."
        }
    }

    private func analyze() async {
        guard let selectedImage else { return }
        isAnalyzing = true
        errorMessage = nil
        defer { isAnalyzing = false }

        do {
            extractedPlan = try await importer.importPlan(from: selectedImage)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ImportPlanView { _ in }
}
