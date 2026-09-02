import Foundation
import SwiftData
import Testing
@testable import ThruFlow

@MainActor
struct PersistenceErrorHandlingTests {
    @Test func issueCenterPublishesAndDismissesRecoverableFailure() {
        let center = PersistenceIssueCenter()

        center.report(TestFailure.expected, operation: .taskUpdate)

        #expect(center.currentIssue?.operation == .taskUpdate)
        center.dismissCurrentIssue()
        #expect(center.currentIssue == nil)
    }

    @Test func successfulSaveDoesNotPublishAnIssue() throws {
        let container = AppModelContainerFactory.make()
        let context = ModelContext(container)
        let center = PersistenceIssueCenter()
        context.insert(Area(name: "仕事", type: .neutral))

        #expect(center.save(context, operation: .areaUpdate))
        #expect(center.currentIssue == nil)
        #expect(try context.fetch(FetchDescriptor<Area>()).count == 1)
    }

    @Test func userDataPersistenceDoesNotSilentlyDiscardErrors() throws {
        let sourceRoot = repositoryRoot.appending(path: "ThruFlow")
        let enumerator = try #require(
            FileManager.default.enumerator(
                at: sourceRoot,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        )
        var violations: [String] = []

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            for (offset, line) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let value = String(line)
                guard value.contains("try?"),
                      value.contains("modelContext.save") || value.contains("modelContext.fetch")
                else { continue }
                violations.append("\(relativePath(for: fileURL)):\(offset + 1)")
            }
        }

        #expect(
            violations.isEmpty,
            "Silent SwiftData operations: \(violations.joined(separator: ", "))"
        )
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func relativePath(for fileURL: URL) -> String {
        fileURL.path.replacingOccurrences(of: repositoryRoot.path + "/", with: "")
    }

    private enum TestFailure: Error {
        case expected
    }
}
