import Foundation
import IndexStore

struct IndexStoreFinder {
    let indexStorePath: String

    func fileReferences(of symbolName: String, symbolType: String?) throws -> [String] {
        let store = try IndexStore(path: indexStorePath)
        var referencedFiles = Set<String>()
        let expectedKind = symbolType?.lowercased()

        for unitReader in store.units {
            var recordToSource: [String: String] = [:]
            unitReader.forEach { dependency in
                guard dependency.kind == .record else { return }
                recordToSource[dependency.name] = dependency.filePath
            }

            for recordName in unitReader.recordNames {
                guard let recordReader = try? RecordReader(indexStore: store, recordName: recordName) else {
                    continue
                }

                let sourcePath = recordToSource[recordName]
                recordReader.forEach { (occurrence: SymbolOccurrence) in
                    guard occurrence.symbol.name == symbolName else { return }
                    if let expectedKind,
                       occurrence.symbol.kind.description.lowercased() != expectedKind {
                        return
                    }

                    let filename: String
                    if let sourcePath, !sourcePath.isEmpty {
                        filename = URL(fileURLWithPath: sourcePath).path()
                    } else {
                        filename = recordName
                    }
                    referencedFiles.insert(filename)
                }
            }
        }

        return referencedFiles.sorted()
    }
}
