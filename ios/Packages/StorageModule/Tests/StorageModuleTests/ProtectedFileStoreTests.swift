//
//  Created by Jerel Walters on 7/2/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import XCTest
@testable import StorageModule

final class ProtectedFileStoreTests: XCTestCase {
    func testStoreFileCopiesRawBytesIntoProtectedDirectory() throws {
        let fixture = try makeStore()
        defer { fixture.removeStoredItems() }
        let sourceURL = try fixture.writeSourceFile(
            named: "pod.pdf",
            data: Data("proof-of-delivery".utf8)
        )

        let storedFile = try fixture.store.storeFile(
            from: sourceURL,
            identifier: "document-1",
            preferredFileName: "pod.pdf"
        )

        XCTAssertEqual(storedFile.fileName, "pod.pdf")
        XCTAssertEqual(storedFile.byteCount, 17)
        XCTAssertEqual(
            storedFile.sha256Hex,
            "4fb3907c6c07c2ebe47312275a90301d78f88b16a900987f195fdc2c3601d02c"
        )
        XCTAssertEqual(storedFile.fileURL.lastPathComponent, "document-1.pdf")
        XCTAssertEqual(try Data(contentsOf: storedFile.fileURL), Data("proof-of-delivery".utf8))
    }

    func testStoreFileSanitizesIdentifiersAndPreferredNames() throws {
        let fixture = try makeStore()
        defer { fixture.removeStoredItems() }
        let sourceURL = try fixture.writeSourceFile(
            named: "invoice.pdf",
            data: Data([0x01, 0x02])
        )

        let storedFile = try fixture.store.storeFile(
            from: sourceURL,
            identifier: "load/123:document",
            preferredFileName: " invoice/final:copy.pdf "
        )

        XCTAssertEqual(storedFile.fileName, "invoice-final-copy.pdf")
        XCTAssertEqual(storedFile.fileURL.lastPathComponent, "load-123-document.pdf")
        XCTAssertTrue(storedFile.fileURL.path.hasPrefix(fixture.directoryURL.path))
    }

    func testStoreFileReplacesExistingIdentifierAndDeleteRemovesIt() throws {
        let fixture = try makeStore()
        defer { fixture.removeStoredItems() }
        let firstURL = try fixture.writeSourceFile(
            named: "first.pdf",
            data: Data("first".utf8)
        )
        let updatedURL = try fixture.writeSourceFile(
            named: "updated.pdf",
            data: Data("updated".utf8)
        )

        let firstStoredFile = try fixture.store.storeFile(
            from: firstURL,
            identifier: "document-1",
            preferredFileName: "pod.pdf"
        )
        let updatedStoredFile = try fixture.store.storeFile(
            from: updatedURL,
            identifier: "document-1",
            preferredFileName: "pod.pdf"
        )

        XCTAssertEqual(firstStoredFile.fileURL, updatedStoredFile.fileURL)
        XCTAssertEqual(try Data(contentsOf: updatedStoredFile.fileURL), Data("updated".utf8))

        try fixture.store.removeFile(at: updatedStoredFile.fileURL)

        XCTAssertFalse(FileManager.default.fileExists(atPath: updatedStoredFile.fileURL.path))
    }

    func testRemoveAllFilesDeletesEveryStoredFile() throws {
        let fixture = try makeStore()
        defer { fixture.removeStoredItems() }
        let firstURL = try fixture.writeSourceFile(
            named: "pod.pdf",
            data: Data("pod".utf8)
        )
        let secondURL = try fixture.writeSourceFile(
            named: "receipt.pdf",
            data: Data("receipt".utf8)
        )

        _ = try fixture.store.storeFile(
            from: firstURL,
            identifier: "document-1",
            preferredFileName: "pod.pdf"
        )
        _ = try fixture.store.storeFile(
            from: secondURL,
            identifier: "document-2",
            preferredFileName: "receipt.pdf"
        )

        try fixture.store.removeAllFiles()

        let remainingFiles = try FileManager.default.contentsOfDirectory(
            at: fixture.directoryURL,
            includingPropertiesForKeys: nil
        )
        XCTAssertTrue(remainingFiles.isEmpty)
    }

    private func makeStore() throws -> ProtectedFileStoreFixture {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("com.haulmate.protected-file-store-tests.\(UUID().uuidString)", isDirectory: true)
        let sourceDirectoryURL = rootURL.appendingPathComponent("Source", isDirectory: true)
        let directoryURL = rootURL.appendingPathComponent("Protected", isDirectory: true)
        try FileManager.default.createDirectory(
            at: sourceDirectoryURL,
            withIntermediateDirectories: true
        )

        return ProtectedFileStoreFixture(
            rootURL: rootURL,
            sourceDirectoryURL: sourceDirectoryURL,
            directoryURL: directoryURL,
            store: ProtectedFileStore(directoryURL: directoryURL)
        )
    }
}

private struct ProtectedFileStoreFixture {
    let rootURL: URL
    let sourceDirectoryURL: URL
    let directoryURL: URL
    let store: ProtectedFileStore

    func writeSourceFile(named fileName: String, data: Data) throws -> URL {
        let fileURL = sourceDirectoryURL.appendingPathComponent(fileName)
        try data.write(to: fileURL)

        return fileURL
    }

    func removeStoredItems() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}
