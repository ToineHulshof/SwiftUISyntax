//
//  main.swift
//  SwiftUISyntax
//
//  Created by Toine Hulshof on 05/03/2020.
//  Copyright c 2020 Toine Hulshof. All rights reserved.
//

import SwiftSyntax
import Foundation

func shell(_ command: String) -> String {
    let task = Process()
    task.launchPath = "/bin/bash"
    task.arguments = ["--login", "-c", command]

    let pipe = Pipe()
    task.standardOutput = pipe
    task.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output: String = NSString(data: data, encoding: String.Encoding.utf8.rawValue)! as String

    return output
}

func translateFile(file: URL) -> String {
    do {
        let sourceFile = try SyntaxParser.parse(file)
        var visitor = SwiftUIVisitor()
        sourceFile.walk(&visitor)
        return visitor.translations.joined(separator: "\n\n")
    } catch {
        fatalError(error.localizedDescription)
    }
}

let input = CommandLine.arguments[1]
let inputURL = URL(fileURLWithPath: input)

if inputURL.hasDirectoryPath {
    let output = CommandLine.arguments[2]
//    let outputURL = URL(fileURLWithPath: output)
    /// Directory!
//    let name = inputURL.lastPathComponent
    /// MARK - Extra opties in command toevoegen. Bijvoorbeeld  -t  voor testen  aanzetten.
    /// TODO: gradle command veranderen zodra er een optie is voor jetpack compose project. Voor nu met de hand een android project aanmaken
    
    // Gradle init
//    _ = shell("cd $(dirname `dirname \(input)`) && mkdir \(name)Compose && cd \(name)Compose && gradle init --dsl kotlin --project-name '\(name)Compose' --package '\(name)Compose' --type kotlin-application")
    _ = shell("cd \(output)/app/src/main/java/com/toinehulshof/translatedcompose && rm MainActivity.kt")

    FileManager.default.enumerator(at: inputURL, includingPropertiesForKeys: nil)?.compactMap({ $0 as? URL }).forEach { file in
        if file.hasDirectoryPath {
            let path = Array(file.pathComponents.suffix(file.pathComponents.count - inputURL.pathComponents.count)).map({ $0.replacingOccurrences(of: " ", with: "\\ ") })
//            _ = shell("mkdir -p $(dirname `dirname \(input)`)/\(name)Compose/src/main/kotlin/\(name)Compose/\(path.joined(separator: "/"))")
            _ = shell("cd \(output)/app/src/main/java/com/toinehulshof/translatedcompose && mkdir \(path.joined(separator: "/"))")
        }
        if file.pathExtension == "swift" {
            /// Translate file!
            var translation = ""
            switch file.lastPathComponent {
            case "AppDelegate.swift": return
            case "SceneDelegate.swift": translation = StructTranslator.sceneDelegateString
            default: translation = translateFile(file: file)
            }
            let path = Array(file.deletingPathExtension().appendingPathExtension("kt").pathComponents.suffix(file.pathComponents.count - inputURL.pathComponents.count)).map({ $0.replacingOccurrences(of: " ", with: "\\ ").replacingOccurrences(of: "SceneDelegate", with: "MainActivity") })
//            _ = shell("cd $(dirname `dirname \(input)`)/\(name)Compose/src/main/kotlin/\(name)Compose && echo '\(translation)' > $(dirname `dirname \(input)`)/\(name)Compose/src/main/kotlin/\(name)Compose/\(path.joined(separator: "/"))")
                _ = shell("cd \(output)/app/src/main/java/com/toinehulshof/translatedcompose && echo '\(translation)' > \(path.joined(separator: "/"))")
        } else {
            if file.hasDirectoryPath {
                
            } else {
                guard ["png", "jpg"].contains(file.pathExtension) else { return }
//                _ = shell("cp \(file.path.replacingOccurrences(of: " ", with: "\\ ")) $(dirname `dirname \(input)`)/\(name)Compose/src/main/resources/\(file.lastPathComponent)")
                _ = shell("cp \(file.path.replacingOccurrences(of: " ", with: "\\ ")) \(output)/app/src/main/res/drawable-v24/\(file.lastPathComponent)")
            }
        }
    }
} else {
    /// Single File!
    let translation = translateFile(file: inputURL)
    /// MARK - Extra opties in command toevoegen. Bijvoorbeeld  -p  voor print vertaling.
    print(translation)
//    do {
//        try translation.write(to: inputURL.deletingPathExtension().appendingPathExtension("kt"), atomically: false, encoding: .utf8)
//    } catch {
//        print(error.localizedDescription)
//    }
}
