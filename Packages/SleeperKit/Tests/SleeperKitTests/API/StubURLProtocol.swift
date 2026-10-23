import Foundation

/// `URLProtocol` que responde con un manejador por test. Ninguna petición sale a la red:
/// si el manejador no existe, la petición falla con `notConnectedToInternet`.
///
/// Los tests corren en paralelo, así que cada sesión lleva un identificador en una cabecera
/// y el manejador se busca por ese identificador, no en un estado global compartido.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    private static let idHeader = "X-Stub-ID"
    private static let lock = NSLock()
    nonisolated(unsafe) private static var handlers: [String: Handler] = [:]

    static func session(handler: @escaping Handler) -> URLSession {
        let id = UUID().uuidString
        lock.withLock { handlers[id] = handler }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.httpAdditionalHeaders = [idHeader: id]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let id = request.value(forHTTPHeaderField: Self.idHeader)
        guard let id, let handler = Self.lock.withLock({ Self.handlers[id] }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

/// Guarda las peticiones que llegaron al stub, para comprobar URL, método y timeout.
final class RequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URLRequest] = []

    var requests: [URLRequest] { lock.withLock { storage } }
    func record(_ request: URLRequest) { lock.withLock { storage.append(request) } }
}

/// Respuesta HTTP de prueba. `url` permite simular una respuesta que viene de otro host.
func stubResponse(
    for request: URLRequest,
    status: Int = 200,
    url: URL? = nil,
    headers: [String: String] = [:],
    body: Data = Data()
) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(
        url: url ?? request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
    return (response, body)
}
