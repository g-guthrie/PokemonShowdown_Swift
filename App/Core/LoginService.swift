import Foundation
import Security
import ShowdownKit

enum LoginError: LocalizedError {
    case needsPassword
    case message(String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .needsPassword: return "This name is registered. Enter its password to use it."
        case .message(let text): return text
        case .badResponse: return "The login server sent an unexpected response. Try again in a moment."
        }
    }
}

/// Talks to Showdown's login server to turn a challstr into a signed assertion for `/trn`.
enum LoginService {
    static let actionURL = URL(string: "https://play.pokemonshowdown.com/action.php")!

    static func assertion(username: String, password: String?, challstr: String) async throws -> String {
        if let password, !password.isEmpty {
            return try await login(username: username, password: password, challstr: challstr)
        }
        var components = URLComponents(url: actionURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "act", value: "getassertion"),
            URLQueryItem(name: "userid", value: toID(username)),
            URLQueryItem(name: "challstr", value: challstr),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        if text == ";" { throw LoginError.needsPassword }
        if text.hasPrefix(";;") { throw LoginError.message(String(text.dropFirst(2))) }
        if text.isEmpty || text.hasPrefix("<") { throw LoginError.badResponse }
        return text
    }

    private static func login(username: String, password: String, challstr: String) async throws -> String {
        var request = URLRequest(url: actionURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncode(["act": "login", "name": username, "pass": password, "challstr": challstr])
        let (data, _) = try await URLSession.shared.data(for: request)
        var text = String(decoding: data, as: UTF8.self)
        if text.hasPrefix("]") { text.removeFirst() }
        guard let json = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else {
            throw LoginError.badResponse
        }
        if let assertion = json["assertion"] as? String, !assertion.isEmpty {
            if assertion.hasPrefix(";;") { throw LoginError.message(String(assertion.dropFirst(2))) }
            if assertion.hasPrefix(";") { throw LoginError.message("Wrong password.") }
            return assertion
        }
        throw LoginError.message("Wrong username or password.")
    }

    private static func formEncode(_ fields: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._*")
        let body = fields.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value)"
        }.joined(separator: "&")
        return Data(body.utf8)
    }
}

/// Stores the registered account's credentials so the app can sign back in after reconnecting.
enum Keychain {
    private static let service = "showdown.account"

    static func save(username: String, password: String) {
        delete()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: username,
            kSecValueData as String: Data(password.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load() -> (username: String, password: String)? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let item = result as? [String: Any],
              let account = item[kSecAttrAccount as String] as? String,
              let data = item[kSecValueData as String] as? Data else { return nil }
        return (account, String(decoding: data, as: UTF8.self))
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
