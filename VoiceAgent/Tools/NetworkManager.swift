//
//  NetworkManager.swift
//  Scene-Examples
//
//  Created by zhaoyongqiang on 2021/11/19.
//
import UIKit

public enum AgoraTokenType: Int {
    case rtc = 1
    case rtm = 2
    case chat = 3
}

public class NetworkManager:NSObject {
    enum HTTPMethods: String {
        case GET
        case POST
    }
    
    var gameToken: String = ""

    public typealias SuccessClosure = ([String: Any]) -> Void
    public typealias FailClosure = (String) -> Void

    private var sessionConfig: URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Content-Type": "application/json",
        ]
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        return config
    }

    public static let shared = NetworkManager()
    
    private func basicAuth(key: String, password: String) -> String {
        let loginString = String(format: "%@:%@", key, password)
        guard let loginData = loginString.data(using: String.Encoding.utf8) else {
            return ""
        }
        let base64LoginString = loginData.base64EncodedString()
        return base64LoginString
    }
//    
//    /// get token
//    /// - Parameters:
//    ///   - channelName: the name of channel
//    ///   - uid: user uid
//    ///   - types: [token type :  token string]
//    public func generateToken(channelName: String,
//                       uid: String,
//                       expire: Int = 86400,
//                       types: [AgoraTokenType],
//                       success: @escaping (String?) -> Void) {
//       
//    }
    
    public func getRequest(urlString: String, params: [String: Any]?, success: SuccessClosure?, failure: FailClosure?) {
        DispatchQueue.global().async {
            self.request(urlString: urlString, params: params, method: .GET, success: success, failure: failure)
        }
    }

    public func postRequest(urlString: String, params: [String: Any]?, success: SuccessClosure?, failure: FailClosure?) {
        DispatchQueue.global().async {
            self.request(urlString: urlString, params: params, method: .POST, success: success, failure: failure)
        }
    }

    public func uploadRequest(urlString: String,
                              parameters: [String: String],
                              imageData: Data,
                              success: SuccessClosure?,
                              failure: FailClosure?) {
        uploadRequest(urlString: urlString,
                     parameters: parameters,
                     fileData: imageData,
                     fileName: "image.jpg",
                     mimeType: "image/jpeg",
                     fieldName: "image",
                     success: success,
                     failure: failure)
    }
    
    /// Upload file with flexible format support
    /// - Parameters:
    ///   - urlString: API endpoint URL
    ///   - parameters: Text parameters for the request
    ///   - fileData: File data to upload
    ///   - fileName: Name of the file (e.g., "voiceprint.pcm")
    ///   - mimeType: MIME type of the file (e.g., "audio/mp4")
    ///   - fieldName: Form field name for the file (e.g., "file", "audio")
    ///   - success: Success callback
    ///   - failure: Failure callback
    public func uploadRequest(urlString: String,
                              parameters: [String: String],
                              fileData: Data,
                              fileName: String,
                              mimeType: String,
                              fieldName: String,
                              success: SuccessClosure?,
                              failure: FailClosure?) {
        guard let url = URL(string: urlString) else {
            failure?("Invalid URL")
            return
        }
        
        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Set headers with auth token
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Create multipart body
        var body = Data()
        
        // Add text parameters
        for (key, value) in parameters {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Add file data with flexible format
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        #if DEBUG
        let curl = request.cURL(pretty: false)
        debugPrint("upload curl == \(curl)")
        #endif
        
        // Use existing sessionConfig with longer timeout for uploads
        let config = sessionConfig
        config.timeoutIntervalForRequest = 60 // Longer timeout for uploads
        config.timeoutIntervalForResource = 60
        let session = URLSession(configuration: config)
        
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.checkResponse(response: response, data: data, success: success, failure: failure)
            }
        }.resume()
    }

    private func request(urlString: String,
                         params: [String: Any]?,
                         method: HTTPMethods,
                         success: SuccessClosure?,
                         failure: FailClosure?) {
        let session = URLSession(configuration: sessionConfig)
        guard let request = getRequest(urlString: urlString,
                                       params: params,
                                       method: method,
                                       success: success,
                                       failure: failure) else { return }
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.checkResponse(response: response, data: data, success: success, failure: failure)
            }
        }.resume()
    }

    private func getRequest(urlString: String,
                            params: [String: Any]?,
                            method: HTTPMethods,
                            success: SuccessClosure?,
                            failure: FailClosure?) -> URLRequest? {
        var string = urlString
        if method == .GET {
            string = string.appendingParameters(parameters: params)
        }
        
        guard let url = URL(string: string) else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if method == .POST {
            request.httpBody = try? JSONSerialization.data(withJSONObject: params ?? [],
                                                           options: .sortedKeys)
        }
        
        #if DEBUG
        let curl = request.cURL(pretty: false)
        debugPrint("curl == \(curl)")
        #endif
        return request
    }

    private func convertParams(params: [String: Any]?) -> String {
        guard let params = params else { return "" }
        let value = params.map({ String(format: "%@=%@", $0.key, "\($0.value)") }).joined(separator: "&")
        return value
    }

    private func checkResponse(response: URLResponse?, data: Data?, success: SuccessClosure?, failure: FailClosure?) {
        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200...201:
                if let resultData = data {
                    let result = try? JSONSerialization.jsonObject(with: resultData)
                    success?(result as! [String : Any])
                } else {
                    failure?("Error in the request status code \(httpResponse.statusCode), response: \(String(describing: response))")
                }
            default:
                failure?("Error in the request status code \(httpResponse.statusCode), response: \(String(describing: response))")
            }
        } else {
            failure?("Error in the request status code \(400), response: \(String(describing: response))")
        }
    }
}

public extension URLRequest {
    func cURL(pretty: Bool = false) -> String {
        let newLine = pretty ? "\\\n" : ""
        let method = (pretty ? "--request " : "-X ") + "\(httpMethod ?? "GET") \(newLine)"
        let url: String = (pretty ? "--url " : "") + "\'\(url?.absoluteString ?? "")\' \(newLine)"

        var cURL = "curl "
        var header = ""
        var data = ""

        if let httpHeaders = allHTTPHeaderFields, httpHeaders.keys.count > 0 {
            for (key, value) in httpHeaders {
                if key.lowercased() == "content-type" && value.lowercased().contains("multipart/form-data") {
                    header += (pretty ? "--header " : "-H ") + "\'\(key): \(value)\' \(newLine)"
                    data = "--data '@image_data'"
                    continue
                }
                header += (pretty ? "--header " : "-H ") + "\'\(key): \(value)\' \(newLine)"
            }
        }

        if data.isEmpty, let bodyData = httpBody {
            if let bodyString = String(data: bodyData, encoding: .utf8), !bodyString.isEmpty {
                data = "--data '\(bodyString)'"
            } else {
                data = "--data '@binary_data'"
            }
        }

        cURL += method + url + header + data

        return cURL
    }
}

extension String {
    func appendingParameters(parameters: [String: Any]?) -> String {
        guard let parameters = parameters else {
            return self
        }
        var url = self
        if !parameters.isEmpty {
            let paramComponents = parameters.map { "\($0.key)=\($0.value)" }
            let paramString = paramComponents.joined(separator: "&")
            url += "?\(paramString)"
        }
        return url
    }
}
