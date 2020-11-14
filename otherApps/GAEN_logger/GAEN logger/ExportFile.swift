//
//  ExportFile.swift
//  GAEN logger
//
//  Created by Bill Pugh on 11/14/20.
//  Copyright © 2020 NinjaMonkeyCoders. All rights reserved.
//

import Foundation

import SwiftUI
import UniformTypeIdentifiers

struct ExportDocument: FileDocument {
    
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    static var writeableContentTypes: [UTType] { [.commaSeparatedText] }

    var text: String

    init(content: [String]) {
        self.text = content.joined(separator: "\n")
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: text.data(using: .utf8)!)
    }
    
}

