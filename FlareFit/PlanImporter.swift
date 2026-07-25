//
//  PlanImporter.swift
//  FlareFit
//
//  Sends a photo of a workout plan to the Claude API and gets back a
//  structured WorkoutPlan. Uses structured outputs (JSON schema) so the
//  response is guaranteed to be valid, parseable JSON.
//

import UIKit

enum PlanImportError: LocalizedError {
    case missingAPIKey
    case imageEncodingFailed
    case requestFailed(String)
    case refused
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No API key set. Add your Anthropic API key in Settings."
        case .imageEncodingFailed:
            return "Couldn't process that image. Try a different photo."
        case .requestFailed(let message):
            return message
        case .refused:
            return "The AI declined to process this image. Try a clearer photo of a workout plan."
        case .invalidResponse:
            return "Got an unexpected response. Please try again."
        }
    }
}

final class ClaudePlanImporter {

    // Wire format for the extracted plan (matches the JSON schema below).
    private struct ImportedPlan: Codable {
        let name: String
        let repetitions: Int
        let switchSeconds: Int
        let exercises: [ImportedExercise]
    }

    private struct ImportedExercise: Codable {
        let name: String
        let repetitions: Int
        let workSeconds: Int
        let restSeconds: Int
    }

    func importPlan(from image: UIImage) async throws -> WorkoutPlan {
        guard let apiKey = KeychainHelper.loadAPIKey(), !apiKey.isEmpty else {
            throw PlanImportError.missingAPIKey
        }
        guard let imageData = Self.jpegData(from: image) else {
            throw PlanImportError.imageEncodingFailed
        }

        let body = Self.requestBody(imageBase64: imageData.base64EncodedString())

        guard let endpoint = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw PlanImportError.invalidResponse
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw PlanImportError.invalidResponse
        }
        guard http.statusCode == 200 else {
            let apiMessage = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { $0["error"] as? [String: Any] }
                .flatMap { $0["message"] as? String }
            throw PlanImportError.requestFailed(apiMessage ?? "Request failed (HTTP \(http.statusCode)).")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PlanImportError.invalidResponse
        }
        if json["stop_reason"] as? String == "refusal" {
            throw PlanImportError.refused
        }
        guard let content = json["content"] as? [[String: Any]],
              let text = content.first(where: { $0["type"] as? String == "text" })?["text"] as? String,
              let planData = text.data(using: .utf8),
              let imported = try? JSONDecoder().decode(ImportedPlan.self, from: planData)
        else {
            throw PlanImportError.invalidResponse
        }

        return WorkoutPlan(
            name: imported.name,
            repetitions: max(imported.repetitions, 1),
            switchSeconds: max(imported.switchSeconds, 0),
            exercises: imported.exercises.map {
                Exercise(
                    name: $0.name,
                    repetitions: max($0.repetitions, 1),
                    workSeconds: max($0.workSeconds, 5),
                    restSeconds: max($0.restSeconds, 0)
                )
            }
        )
    }

    // MARK: - Request construction

    private static func requestBody(imageBase64: String) -> [String: Any] {
        [
            "model": "claude-opus-4-8",
            "max_tokens": 16000,
            "thinking": ["type": "adaptive"],
            "output_config": [
                "format": [
                    "type": "json_schema",
                    "schema": planSchema,
                ]
            ],
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": imageBase64,
                            ],
                        ],
                        [
                            "type": "text",
                            "text": """
                            Extract the workout plan from this image into structured data. \
                            The image may be a handwritten note, whiteboard, screenshot, or printed plan. \
                            All timer values are in seconds. Where the image doesn't specify a value, \
                            use sensible defaults: exercise repetitions 3, work 30s, rest 15s, \
                            plan repetitions 1, switch timer 10s. If a duration is given in minutes, \
                            convert to seconds. Give the plan a short descriptive name if none is shown.
                            """,
                        ],
                    ],
                ]
            ],
        ]
    }

    private static let planSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "name": ["type": "string", "description": "Short plan name, e.g. Arms"],
            "repetitions": ["type": "integer", "description": "How many times the whole plan repeats"],
            "switchSeconds": ["type": "integer", "description": "Transition seconds between exercises"],
            "exercises": [
                "type": "array",
                "items": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string"],
                        "repetitions": ["type": "integer", "description": "Work/rest cycles for this exercise"],
                        "workSeconds": ["type": "integer"],
                        "restSeconds": ["type": "integer"],
                    ],
                    "required": ["name", "repetitions", "workSeconds", "restSeconds"],
                    "additionalProperties": false,
                ],
            ],
        ],
        "required": ["name", "repetitions", "switchSeconds", "exercises"],
        "additionalProperties": false,
    ]

    // MARK: - Image preparation

    /// Downscale to keep image tokens (and cost) reasonable while staying readable.
    private static func jpegData(from image: UIImage, maxDimension: CGFloat = 1568) -> Data? {
        let size = image.size
        let longEdge = max(size.width, size.height)
        guard longEdge > maxDimension else {
            return image.jpegData(compressionQuality: 0.8)
        }
        let scale = maxDimension / longEdge
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}
