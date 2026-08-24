import Foundation

package enum AppSupportPaths {
    private static let currentDirectoryName = "Roster"
    private static let legacyDirectoryName = "Birthday"

    package static func database(named fileName: String) -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let currentDirectory = support.appendingPathComponent(currentDirectoryName, isDirectory: true)
        let legacyDirectory = support.appendingPathComponent(legacyDirectoryName, isDirectory: true)
        let currentURL = currentDirectory.appendingPathComponent(fileName)
        let legacyURL = legacyDirectory.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: currentURL.path) {
            return currentURL
        }
        if FileManager.default.fileExists(atPath: legacyURL.path) {
            do {
                try FileManager.default.createDirectory(
                    at: currentDirectory,
                    withIntermediateDirectories: true
                )
                try FileManager.default.copyItem(at: legacyURL, to: currentURL)
                return currentURL
            } catch {
                return legacyURL
            }
        }
        return currentURL
    }
}
