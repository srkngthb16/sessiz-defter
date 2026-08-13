import Foundation
import SwiftData

public enum StoreError: Error, CustomStringConvertible {
    case protectionNotApplied(String)

    public var description: String {
        switch self {
        case .protectionNotApplied(let path):
            "Dosya koruma sınıfı uygulanamadı: \(path)"
        }
    }
}

public enum StoreFactory {
    public static let storeFileName = "SessizDefter.store"

    /// Üretim kabı. CloudKit kapalı ve sync .none — bulut senkronizasyonu kapatılabilir
    /// bir ayar değil, hiç kurulmamış bir yol.
    public static func makeContainer(
        directory: URL? = nil,
        fileProtection: FileProtectionType = .complete
    ) throws -> ModelContainer {
        let folder = try directory ?? defaultDirectory()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try applyProtection(fileProtection, to: folder)

        let url = folder.appendingPathComponent(storeFileName)
        let configuration = ModelConfiguration(
            schema: Schema(SchemaV1.models),
            url: url,
            allowsSave: true,
            cloudKitDatabase: .none)

        let container = try ModelContainer(
            for: Schema(SchemaV1.models),
            configurations: configuration)

        // SQLite yanında -wal ve -shm dosyaları da doğar; üçü de korunmalı.
        for suffix in ["", "-wal", "-shm"] {
            let sidecar = URL(fileURLWithPath: url.path + suffix)
            if FileManager.default.fileExists(atPath: sidecar.path) {
                try applyProtection(fileProtection, to: sidecar)
            }
        }
        return container
    }

    /// Test kabı: diske hiç yazmaz.
    public static func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: Schema(SchemaV1.models),
            isStoredInMemoryOnly: true,
            allowsSave: true,
            cloudKitDatabase: .none)
        return try ModelContainer(for: Schema(SchemaV1.models), configurations: configuration)
    }

    public static func defaultDirectory() throws -> URL {
        try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask,
                 appropriateFor: nil, create: true)
            .appendingPathComponent("SessizDefter", isDirectory: true)
    }

    public static func applyProtection(_ type: FileProtectionType, to url: URL) throws {
        try FileManager.default.setAttributes(
            [.protectionKey: type], ofItemAtPath: url.path)
    }

    /// F3 "Tüm verileri sil": kap kapandıktan sonra dosyalar da gider.
    public static func destroyStoreFiles(directory: URL? = nil) throws {
        let folder = try directory ?? defaultDirectory()
        let url = folder.appendingPathComponent(storeFileName)
        for suffix in ["", "-wal", "-shm"] {
            let sidecar = URL(fileURLWithPath: url.path + suffix)
            if FileManager.default.fileExists(atPath: sidecar.path) {
                try FileManager.default.removeItem(at: sidecar)
            }
        }
    }
}
