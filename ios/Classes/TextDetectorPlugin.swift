import Flutter
import UIKit
import Vision
import CoreImage

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
        let enhanceForBrightness = (arguments["enhanceForBrightness"] as? Bool) ?? true
        let preprocessingLevel = (arguments["preprocessingLevel"] as? String) ?? "auto"
        let multiPass = (arguments["multiPass"] as? Bool) ?? true

        detectTextInImage(imagePath: imagePath,
                         recognitionLevel: recognitionLevel,
                         languages: languages,
                         enhanceForBrightness: enhanceForBrightness,
                         preprocessingLevel: preprocessingLevel,
                         multiPass: multiPass,
                         result: result)
    }

    private func detectTextInImage(imagePath: String,
                                  recognitionLevel: String,
                                  languages: [String]?,
                                  enhanceForBrightness: Bool,
                                  preprocessingLevel: String,
                                  multiPass: Bool,
                                  result: @escaping FlutterResult) {
        guard let image = UIImage(contentsOfFile: imagePath) else {
            result(FlutterError(code: "IMAGE_LOAD_ERROR",
                               message: "Failed to load image from path",
                               details: nil))
            return
        }

        // Fix the image orientation to match display
        let fixedImage = fixImageOrientation(image)

        guard let originalCGImage = fixedImage.cgImage else {
            result(FlutterError(code: "IMAGE_LOAD_ERROR",
                               message: "Failed to get CGImage",
                               details: nil))
            return
        }

        // Analyze brightness if auto preprocessing is enabled
        var shouldPreprocess = enhanceForBrightness
        var actualPreprocessingLevel = preprocessingLevel

        if preprocessingLevel == "auto" && enhanceForBrightness {
            let (luminance, isOverexposed) = analyzeImageBrightness(originalCGImage)
            shouldPreprocess = isOverexposed || luminance > 0.7

            // Determine preprocessing level based on luminance
            if luminance > 0.85 {
                actualPreprocessingLevel = "aggressive"
            } else if luminance > 0.75 {
                actualPreprocessingLevel = "moderate"
            } else {
                actualPreprocessingLevel = "light"
            }
        }

        // Prepare images for multi-pass detection
        var imagesToProcess: [(cgImage: CGImage, passName: String)] = []

        // Pass 1: Original image
        imagesToProcess.append((originalCGImage, "original"))

        // Pass 2 & 3: Preprocessed images if needed
        if multiPass && shouldPreprocess {
            if let moderateImage = preprocessImageForBrightness(originalCGImage, level: actualPreprocessingLevel) {
                imagesToProcess.append((moderateImage, "enhanced"))
            }

            // Add a third pass with different preprocessing for very bright images
            if actualPreprocessingLevel == "aggressive" {
                if let aggressiveImage = preprocessImageForBrightness(originalCGImage, level: "aggressive") {
                    imagesToProcess.append((aggressiveImage, "aggressive"))
                }
            }
        }

        // Collect results from all passes
        var allDetectedTexts: [String: [String: Any]] = [:]
        let dispatchGroup = DispatchGroup()

        for (cgImage, passName) in imagesToProcess {
            dispatchGroup.enter()

            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { (request, error) in
                defer { dispatchGroup.leave() }
                if let error = error {
                    print("Text recognition error in pass \(passName): \(error.localizedDescription)")
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    return
                }

                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }

                    let boundingBox = observation.boundingBox

                    // Convert normalized coordinates to image coordinates (using original dimensions)
                    let x = boundingBox.origin.x * CGFloat(originalCGImage.width)
                    let y = (1 - boundingBox.origin.y - boundingBox.height) * CGFloat(originalCGImage.height)
                    let width = boundingBox.width * CGFloat(originalCGImage.width)
                    let height = boundingBox.height * CGFloat(originalCGImage.height)

                    // Create unique key based on approximate position
                    let key = "\(Int(x/10))_\(Int(y/10))_\(Int(width/10))_\(Int(height/10))"

                    // Only add if not already detected or if confidence is higher
                    if let existing = allDetectedTexts[key] {
                        let existingConfidence = existing["confidence"] as? Float ?? 0
                        if topCandidate.confidence > existingConfidence {
                            allDetectedTexts[key] = [
                                "text": topCandidate.string,
                                "confidence": topCandidate.confidence,
                                "x": x,
                                "y": y,
                                "width": width,
                                "height": height,
                                "imageWidth": originalCGImage.width,
                                "imageHeight": originalCGImage.height,
                                "detectionPass": passName
                            ]
                        }
                    } else {
                        allDetectedTexts[key] = [
                            "text": topCandidate.string,
                            "confidence": topCandidate.confidence,
                            "x": x,
                            "y": y,
                            "width": width,
                            "height": height,
                            "imageWidth": originalCGImage.width,
                            "imageHeight": originalCGImage.height,
                            "detectionPass": passName
                        ]
                    }
                }
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

            // Set lower minimum text height for better detection
            request.minimumTextHeight = 0.01  // Reduced from 0.05

            // Use language correction
            request.usesLanguageCorrection = true

            // Set custom revision for better accuracy
            if #available(iOS 16.0, *) {
                request.revision = VNRecognizeTextRequestRevision3
            }

            // Perform the request
            do {
                try requestHandler.perform([request])
            } catch {
                print("Failed to perform text recognition for pass \(passName): \(error.localizedDescription)")
            }
        }

        // Wait for all passes to complete
        dispatchGroup.notify(queue: .main) {
            // Convert dictionary to array and sort by position
            let finalResults = Array(allDetectedTexts.values).sorted { first, second in
                let y1 = first["y"] as? CGFloat ?? 0
                let y2 = second["y"] as? CGFloat ?? 0
                let x1 = first["x"] as? CGFloat ?? 0
                let x2 = second["x"] as? CGFloat ?? 0

                // Sort by vertical position, then horizontal
                if abs(y1 - y2) > 10 {
                    return y1 < y2
                }
                return x1 < x2
            }

            result(finalResults)
        }
    }

    // MARK: - Image Preprocessing

    private func analyzeImageBrightness(_ cgImage: CGImage) -> (averageLuminance: Double, isOverexposed: Bool) {
        let ciImage = CIImage(cgImage: cgImage)
        let extentVector = CIVector(x: ciImage.extent.origin.x,
                                     y: ciImage.extent.origin.y,
                                     z: ciImage.extent.size.width,
                                     w: ciImage.extent.size.height)

        guard let filter = CIFilter(name: "CIAreaAverage") else {
            return (0.5, false)
        }

        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(extentVector, forKey: kCIInputExtentKey)

        guard let outputImage = filter.outputImage else {
            return (0.5, false)
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext()
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8, colorSpace: nil)

        // Calculate luminance using standard formula
        let luminance = (0.299 * Double(bitmap[0]) + 0.587 * Double(bitmap[1]) + 0.114 * Double(bitmap[2])) / 255.0
        let isOverexposed = luminance > 0.75 // Consider overexposed if > 75% brightness

        return (luminance, isOverexposed)
    }

    private func preprocessImageForBrightness(_ cgImage: CGImage, level: String = "moderate") -> CGImage? {
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext()

        var processedImage = ciImage

        // Determine preprocessing intensity based on level
        let (exposureAdjust, contrast, brightness, highlightReduction) = getPreprocessingParameters(for: level)

        // Apply exposure adjustment
        if let exposureFilter = CIFilter(name: "CIExposureAdjust") {
            exposureFilter.setValue(processedImage, forKey: kCIInputImageKey)
            exposureFilter.setValue(exposureAdjust, forKey: kCIInputEVKey)
            processedImage = exposureFilter.outputImage ?? processedImage
        }

        // Apply color controls (contrast and brightness)
        if let colorFilter = CIFilter(name: "CIColorControls") {
            colorFilter.setValue(processedImage, forKey: kCIInputImageKey)
            colorFilter.setValue(contrast, forKey: kCIInputContrastKey)
            colorFilter.setValue(brightness, forKey: kCIInputBrightnessKey)
            processedImage = colorFilter.outputImage ?? processedImage
        }

        // Apply highlight/shadow adjustment
        if let highlightFilter = CIFilter(name: "CIHighlightShadowAdjust") {
            highlightFilter.setValue(processedImage, forKey: kCIInputImageKey)
            highlightFilter.setValue(highlightReduction, forKey: "inputHighlightAmount")
            highlightFilter.setValue(0.3, forKey: "inputShadowAmount")
            processedImage = highlightFilter.outputImage ?? processedImage
        }

        // Apply unsharp mask for edge enhancement
        if let unsharpFilter = CIFilter(name: "CIUnsharpMask") {
            unsharpFilter.setValue(processedImage, forKey: kCIInputImageKey)
            unsharpFilter.setValue(2.5, forKey: kCIInputRadiusKey)
            unsharpFilter.setValue(0.5, forKey: kCIInputIntensityKey)
            processedImage = unsharpFilter.outputImage ?? processedImage
        }

        // Convert back to CGImage
        guard let outputCGImage = context.createCGImage(processedImage, from: processedImage.extent) else {
            return nil
        }

        return outputCGImage
    }

    private func getPreprocessingParameters(for level: String) -> (exposure: Double, contrast: Double, brightness: Double, highlight: Double) {
        switch level {
        case "light":
            return (-0.5, 1.1, -0.05, -0.3)
        case "moderate":
            return (-1.0, 1.3, -0.15, -0.5)
        case "aggressive":
            return (-1.5, 1.5, -0.25, -0.8)
        default:
            return (0, 1.0, 0, 0)
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