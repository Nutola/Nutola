import Foundation

enum CatboxError: LocalizedError {
    case network(String)
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .network(let message): return "Upload failed: \(message)"
        case .badResponse(let body): return "catbox.moe returned an unexpected response: \(body)"
        }
    }
}

/// Uploads a self-contained HTML page to catbox.moe — a free, no-account file host
/// that serves .html as text/html, so the page renders in a browser. Needs nothing
/// installed, only a network connection. The link is PUBLIC (anyone with the URL can
/// view it) and lives on a third-party host you don't control — surface that in the UI.
enum CatboxPublisher {
    static func publish(html: String, filename: String) async throws -> URL {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "https://catbox.moe/user/api.php")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body(boundary: boundary, filename: filename, html: html)
        request.timeoutInterval = 60

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw CatboxError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw CatboxError.network("No HTTP response")
        }
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard http.statusCode == 200, let url = URL(string: text), url.scheme == "https" else {
            throw CatboxError.badResponse(text.isEmpty ? "HTTP \(http.statusCode)" : text)
        }
        return url
    }

    private static func body(boundary: String, filename: String, html: String) -> Data {
        var data = Data()
        data.append("--\(boundary)\r\n")
        data.append("Content-Disposition: form-data; name=\"reqtype\"\r\n\r\n")
        data.append("fileupload\r\n")
        data.append("--\(boundary)\r\n")
        data.append("Content-Disposition: form-data; name=\"fileToUpload\"; filename=\"\(filename)\"\r\n")
        data.append("Content-Type: text/html\r\n\r\n")
        data.append(html)
        data.append("\r\n--\(boundary)--\r\n")
        return data
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
