import Foundation

private final class IOSMacsURLFetchResult: @unchecked Sendable {
    private let lock = NSLock()
    private var dataValue: Data?
    private var responseValue: URLResponse?
    private var errorValue: Error?

    func store(data: Data?, response: URLResponse?, error: Error?) {
        lock.lock()
        dataValue = data
        responseValue = response
        errorValue = error
        lock.unlock()
    }

    func load() -> (Data?, URLResponse?, Error?) {
        lock.lock()
        let result = (dataValue, responseValue, errorValue)
        lock.unlock()
        return result
    }
}

private func allocateCString(_ string: String) -> UnsafeMutablePointer<CChar>? {
    strdup(string)
}

private func allocateBytes(_ data: Data) -> UnsafeMutablePointer<UInt8>? {
    if data.isEmpty {
        return nil
    }
    guard let rawPointer = malloc(data.count) else {
        return nil
    }
    let pointer = rawPointer.bindMemory(to: UInt8.self, capacity: data.count)
    data.copyBytes(to: pointer, count: data.count)
    return pointer
}

private func httpHeaderText(from response: HTTPURLResponse?, bodyLength: Int) -> String {
    guard let response else {
        return ""
    }

    let reason = HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
    var lines = ["HTTP/1.1 \(response.statusCode) \(reason)"]
    for key in response.allHeaderFields.keys.sorted(by: { "\($0)" < "\($1)" }) {
        guard let value = response.allHeaderFields[key] else {
            continue
        }
        let headerName = "\(key)"
        switch headerName.lowercased() {
        case "content-encoding", "content-length", "transfer-encoding":
            continue
        default:
            lines.append("\(headerName): \(value)")
        }
    }
    lines.append("Content-Length: \(bodyLength)")
    return lines.joined(separator: "\r\n") + "\r\n"
}

@_cdecl("iosmacs_swift_url_retrieve")
public func iosmacsSwiftURLRetrieve(
    _ urlCString: UnsafePointer<CChar>?,
    _ timeoutMs: Int32,
    _ statusCodeOut: UnsafeMutablePointer<Int32>?,
    _ bodyOut: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>?,
    _ bodyLengthOut: UnsafeMutablePointer<Int>?,
    _ headersOut: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?,
    _ errorOut: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?,
    _ finalURLOut: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    statusCodeOut?.pointee = 0
    bodyOut?.pointee = nil
    bodyLengthOut?.pointee = 0
    headersOut?.pointee = nil
    errorOut?.pointee = nil
    finalURLOut?.pointee = nil

    guard let urlCString else {
        errorOut?.pointee = allocateCString("missing URL")
        return -1
    }
    let urlString = String(cString: urlCString)
    guard let url = URL(string: urlString) else {
        errorOut?.pointee = allocateCString("invalid URL: \(urlString)")
        return -1
    }

    let timeout = max(1.0, Double(timeoutMs) / 1000.0)
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = timeout
    configuration.timeoutIntervalForResource = timeout
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

    let session = URLSession(configuration: configuration)
    let semaphore = DispatchSemaphore(value: 0)
    let box = IOSMacsURLFetchResult()
    let task = session.dataTask(with: url) { data, response, error in
        box.store(data: data, response: response, error: error)
        semaphore.signal()
    }
    task.resume()

    let waitResult = semaphore.wait(timeout: .now() + timeout + 1.0)
    if waitResult == .timedOut {
        task.cancel()
        session.invalidateAndCancel()
        errorOut?.pointee = allocateCString("URLSession request timed out")
        return -1
    }
    session.finishTasksAndInvalidate()

    let (data, response, error) = box.load()
    if let error {
        errorOut?.pointee = allocateCString(error.localizedDescription)
        return -1
    }

    let httpResponse = response as? HTTPURLResponse
    let responseData = data ?? Data()
    statusCodeOut?.pointee = Int32(httpResponse?.statusCode ?? 0)
    headersOut?.pointee = allocateCString(httpHeaderText(from: httpResponse, bodyLength: responseData.count))
    finalURLOut?.pointee = allocateCString(response?.url?.absoluteString ?? url.absoluteString)

    if !responseData.isEmpty {
        bodyOut?.pointee = allocateBytes(responseData)
        bodyLengthOut?.pointee = responseData.count
    }
    return 0
}
