import Flutter
import UIKit
import Vision

public class TextDetectorPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "text_detector", binaryMessenger: registrar.messenger())
        let instance = TextDetectorPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "detectText":
            handleTextDetection(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleTextDetection(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let imagePath = arguments["imagePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS",
                               message: "Image path is required",
                               details: nil))
            return
        }

        let recognitionLevel = (arguments["recognitionLevel"] as? String) ?? "accurate"
        let languages = arguments["languages"] as? [String]

        detectTextInImage(imagePath: imagePath,
                         recognitionLevel: recognitionLevel,
                         languages: languages,
                         result: result)
    }

    private func detectTextInImage(imagePath: String,
                                  recognitionLevel: String,
                                  languages: [String]?,
                                  result: @escaping FlutterResult) {
        guard let image = UIImage(contentsOfFile: imagePath) else {
            result(FlutterError(code: "IMAGE_LOAD_ERROR",
                               message: "Failed to load image from path",
                               details: nil))
            return
        }

        // Fix the image orientation to match display
        let fixedImage = fixImageOrientation(image)

        guard let cgImage = fixedImage.cgImage else {
            result(FlutterError(code: "IMAGE_LOAD_ERROR",
                               message: "Failed to get CGImage",
                               details: nil))
            return
        }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        let request = VNRecognizeTextRequest { (request, error) in
            if let error = error {
                result(FlutterError(code: "RECOGNITION_ERROR",
                                   message: "Text recognition failed",
                                   details: error.localizedDescription))
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                result([])
                return
            }

            var detectedTexts: [[String: Any]] = []

            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else { continue }

                let boundingBox = observation.boundingBox

                // Convert normalized coordinates to image coordinates
                let x = boundingBox.origin.x * CGFloat(cgImage.width)
                let y = (1 - boundingBox.origin.y - boundingBox.height) * CGFloat(cgImage.height)
                let width = boundingBox.width * CGFloat(cgImage.width)
                let height = boundingBox.height * CGFloat(cgImage.height)

                let textBlock: [String: Any] = [
                    "text": topCandidate.string,
                    "confidence": topCandidate.confidence,
                    "x": x,
                    "y": y,
                    "width": width,
                    "height": height,
                    "imageWidth": cgImage.width,
                    "imageHeight": cgImage.height
                ]

                detectedTexts.append(textBlock)
            }

            result(detectedTexts)
        }

        // Configure recognition level
        request.recognitionLevel = recognitionLevel == "fast" ? .fast : .accurate

        // Configure languages if specified
        if let languages = languages, !languages.isEmpty {
            request.recognitionLanguages = languages
        } else {
            // Use automatic language detection
            request.automaticallyDetectsLanguage = true
        }

        // Set minimum text height
        request.minimumTextHeight = 0.05

        // Use language correction
        request.usesLanguageCorrection = true

        // Perform the request
        do {
            try requestHandler.perform([request])
        } catch {
            result(FlutterError(code: "REQUEST_FAILED",
                               message: "Failed to perform text recognition",
                               details: error.localizedDescription))
        }
    }

    private func fixImageOrientation(_ image: UIImage) -> UIImage {
        // If image orientation is already correct, return as is
        if image.imageOrientation == .up {
            return image
        }

        // Redraw the image with correct orientation
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        return normalizedImage
    }
}