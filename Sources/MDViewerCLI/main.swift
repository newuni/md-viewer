import Foundation
import MarkdownRendererCore

@main
struct MDViewerCLI {
    static func main() {
        do {
            try run()
        } catch {
            fputs("error: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func run() throws {
        let args = Array(CommandLine.arguments.dropFirst())

        guard !args.isEmpty, !args.contains("--help") else {
            print(usage)
            return
        }

        if args.first == "--export-html" {
            try exportHTML(args)
            return
        }

        let inputURL = resolvePath(args[0])
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw NSError(domain: "md-viewer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Input file does not exist: \(inputURL.path)"])
        }

        try openInViewer(fileURL: inputURL)
    }

    private static func exportHTML(_ args: [String]) throws {
        guard args.count >= 4 else {
            throw NSError(domain: "md-viewer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing arguments. Use --export-html <input.md> -o <output.html>"])
        }

        guard let outputFlagIndex = args.firstIndex(of: "-o"), outputFlagIndex + 1 < args.count else {
            throw NSError(domain: "md-viewer", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing -o <output.html> argument."])
        }

        let inputURL = resolvePath(args[1])
        let outputURL = resolvePath(args[outputFlagIndex + 1])

        let renderer = MarkdownRenderer()
        let html = try renderer.render(fileURL: inputURL)
        try html.write(to: outputURL, atomically: true, encoding: .utf8)

        print("Exported HTML to \(outputURL.path)")
    }

    private static func openInViewer(fileURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "MDViewer", fileURL.path]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "md-viewer",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Could not open MDViewer app. Install or build MDViewer first."]
            )
        }
    }

    private static func resolvePath(_ value: String) -> URL {
        let expanded = (value as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded)
        }

        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return URL(fileURLWithPath: expanded, relativeTo: cwd).standardizedFileURL
    }

    private static let usage = """
    md-viewer usage

      md-viewer <input.md>
      md-viewer --export-html <input.md> -o <output.html>
      md-viewer --help
    """
}
