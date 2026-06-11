#!/usr/bin/env swift

import AppKit
import Foundation
import Vision

let supportedExtensions = Set(["heic", "jpeg", "jpg", "png", "tif", "tiff"])
let fileManager = FileManager.default

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: decode-qr-folder.swift FOLDER\n", stderr)
    exit(2)
}

let folderURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
guard let files = try? fileManager.contentsOfDirectory(
    at: folderURL,
    includingPropertiesForKeys: nil,
    options: [.skipsHiddenFiles]
) else {
    fputs("Error: cannot read folder: \(folderURL.path)\n", stderr)
    exit(1)
}

let imageFiles = files
    .filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
    .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

guard !imageFiles.isEmpty else {
    fputs("Error: no supported image files found in \(folderURL.path)\n", stderr)
    exit(1)
}

var decodedCount = 0
var sourceByMigrationLink: [String: String] = [:]

for fileURL in imageFiles {
    guard
        let image = NSImage(contentsOf: fileURL),
        let imageData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: imageData),
        let cgImage = bitmap.cgImage
    else {
        fputs("Warning: could not read \(fileURL.lastPathComponent)\n", stderr)
        continue
    }

    let request = VNDetectBarcodesRequest()
    request.symbologies = [.qr]

    do {
        try VNImageRequestHandler(cgImage: cgImage).perform([request])
    } catch {
        fputs("Warning: could not scan \(fileURL.lastPathComponent): \(error)\n", stderr)
        continue
    }

    let payloads = (request.results ?? []).compactMap(\.payloadStringValue)
    let migrationLinks = payloads.filter { $0.hasPrefix("otpauth-migration://offline?data=") }

    if migrationLinks.isEmpty {
        fputs("Warning: no Google Authenticator migration QR found in \(fileURL.lastPathComponent)\n", stderr)
        continue
    }

    for link in migrationLinks {
        if let previousFile = sourceByMigrationLink[link] {
            fputs(
                "Error: duplicate migration QR in \(previousFile) and \(fileURL.lastPathComponent)\n",
                stderr
            )
            exit(1)
        }
        sourceByMigrationLink[link] = fileURL.lastPathComponent
        print(link)
        decodedCount += 1
    }
}

guard decodedCount > 0 else {
    fputs("Error: no Google Authenticator migration QR codes were decoded.\n", stderr)
    exit(1)
}
