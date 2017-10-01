/*****************************************************************************
 *
 * FILE:	OAuth.swift
 * DESCRIPTION:	SocialAccountKit: OAuth 1.0
 * DATE:	Fri, Sep 15 2017
 * UPDATED:	Fri, Sep 22 2017
 * AUTHOR:	Kouichi ABE (WALL) / 阿部康一
 * E-MAIL:	kouichi@MagickWorX.COM
 * URL:		http://www.MagickWorX.COM/
 * CHECKER:     http://quonos.nl/oauthTester/
 * COPYRIGHT:	(c) 2017 阿部康一／Kouichi ABE (WALL), All rights reserved.
 * LICENSE:
 *
 *  Copyright (c) 2017 Kouichi ABE (WALL) <kouichi@MagickWorX.COM>,
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions
 *  are met:
 *
 *   1. Redistributions of source code must retain the above copyright
 *      notice, this list of conditions and the following disclaimer.
 *
 *   2. Redistributions in binary form must reproduce the above copyright
 *      notice, this list of conditions and the following disclaimer in the
 *      documentation and/or other materials provided with the distribution.
 *
 *   THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 *   ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 *   THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 *   PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
 *   LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 *   CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 *   SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 *   INTERRUPTION)  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 *   CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *   ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 *   THE POSSIBILITY OF SUCH DAMAGE.
 *
 * $Id: AppDelegate.m,v 1.6 2017/04/12 09:59:00 kouichi Exp $
 *
 *****************************************************************************/

import Foundation
import UIKit
import CommonCrypto

// MARK: - 
public let OAuthDidAuthenticateRequestTokenNotification: String = "OAuthDidAuthenticateRequestTokenNotification"
public let OAuthAuthenticateCallbackURLKey: String = "OAuthAuthenticateCallbackURLKey"

public let OAuthDidVerifyCredentialsNotification: String = "OAuthDidVerifyCredentialsNotification"
public let OAuthCredentialsKey: String = "OAuthCredentialsKey"

public extension NSNotification.Name {
  public static let OAuthDidAuthenticateRequestToken = NSNotification.Name(OAuthDidAuthenticateRequestTokenNotification)
  public static let OAuthDidVerifyCredentials = NSNotification.Name(OAuthDidVerifyCredentialsNotification)
}

// MARK: - 
public enum OAuthConfigurationServiceType
{
  case standard
  case twitter
  case facebook
}

public protocol OAuthConfigurationProtocol
{
  var serviceType: OAuthConfigurationServiceType { get }

  var requestTokenURI: String { get }
  var authorizationURI: String { get }
  var accessTokenURI: String { get }

  var callbackURI: String { set get }

  var consumerKey: String { set get }
  var consumerSecret: String { set get }
}

public struct TwitterOAuthConfiguration: OAuthConfigurationProtocol
{
  public var serviceType: OAuthConfigurationServiceType = .twitter

  public let requestTokenURI = "https://api.twitter.com/oauth/request_token"
  public let authorizationURI = "https://api.twitter.com/oauth/authorize"
  public let accessTokenURI = "https://api.twitter.com/oauth/access_token"

  // "oob" is out-of-band (See Section 2.1 Temporary Credentials)
  public var callbackURI = "swift-oauth://callback"

  public var consumerKey = ""
  public var consumerSecret = ""

  public init() {
    readConsumerKeyAndSecret()
  }
}

// MARK: - 
open class OAuthCredential
{
  public var oauthToken: String? = nil
  public var oauthTokenSecret: String? = nil

  public var oauthVerifier: String? = nil

  public init() {
  }

  public convenience init(token: String, secret: String) {
    self.init()
    self.oauthToken = token
    self.oauthTokenSecret = secret
  }
}

public class TwitterCredential: OAuthCredential
{
  public var userID: String? = nil
  public var screenName: String? = nil
}

public typealias OAuthRequestHandler = (Data?, URLResponse?, Error?) -> Void

/*
 * RFC 5849 - The OAuth 1.0 Protocol
 */
public class OAuth
{
  public var isForceLogin: Bool = false

  var configuration: OAuthConfigurationProtocol
  var credential: OAuthCredential

  public init(_ configuration: OAuthConfigurationProtocol, credential: OAuthCredential = OAuthCredential()) {
    self.configuration = configuration
    self.credential = credential
  }

  public func request(with method: String, url: URL, parameters: [String:Any] = [:], completion: @escaping OAuthRequestHandler) {
    var requestURL: URL = url

    let parametersString: String = parameters.enumerated().reduce("") {
      (input, tuple) -> String in
      switch tuple.element.value {
        case let int as Int:
          return input + tuple.element.key + "=" + String(int) + (parameters.count - 1 > tuple.offset ? "&" : "")
        case let string as String:
          return input + tuple.element.key + "=" + string + (parameters.count - 1 > tuple.offset ? "&" : "")
        default:
          return input
      }
    }

    var request = URLRequest(url: url)
    if method == "GET" && parameters.count > 0 {
      var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
      components?.query = parametersString
      if let newURL = components?.url {
        request = URLRequest(url: newURL)
        requestURL = newURL
      }
    }

    request.httpMethod = method
    request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    let authField = authorizationHttpField(with: method, requestURL: requestURL)
    request.setValue(authField, forHTTPHeaderField: "Authorization")

    request.setValue("application/json", forHTTPHeaderField: "Accept")
    switch method {
      case "POST":
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        if parameters.count > 0 {
          request.httpBody = parametersString.data(using: String.Encoding.utf8)
          var length: Int = 0
          if let body = request.httpBody {
            length = body.count
          }
          request.setValue(String(length), forHTTPHeaderField: "Content-Length")
        }
      default:
        break
    }

    let task = URLSession.shared.dataTask(with: request) {
      (data, response, error) in
      completion(data, response, error)
    }
    task.resume()
  }

  func authorizationHttpField(with method: String, requestURL: URL) -> String {
    var param = [String:String]()
    param["oauth_consumer_key"] = configuration.consumerKey
    if let oauthToken = credential.oauthToken {
      param["oauth_token"] = oauthToken
    }
    if let oauthVerifier = credential.oauthVerifier {
      param["oauth_verifier"] = oauthVerifier
    }
    param["oauth_signature_method"] = "HMAC-SHA1"
    param["oauth_timestamp"] = String(Int64(Date().timeIntervalSince1970))
    param["oauth_nonce"] = nonce()
    param["oauth_version"] = "1.0"
    param["oauth_callback"] = configuration.callbackURI
    param["oauth_signature"] = signature(with: method, url: requestURL, parameters: param)
    let oauthField = oauthString(with: param)
    return oauthField
  }

  func nonce() -> String {
    let uuid = UUID().uuidString
    return uuid.substring(to: uuid.index(uuid.startIndex, offsetBy: 8))
  }

  func signature(with method: String, url: URL, parameters: [String:String]) -> String {
    var signatureArray = [String]() // for Signature Base String

    // The HTTP request method (e.g., "GET", "POST", etc).
    signatureArray.append(method.uppercased())

    // RFC 5849 Section 3.4.1.2
    if let urlString = url.baseURLString.urlEncoded {
      signatureArray.append(urlString)
    }

    // The protocol parameters excluding the "oauth_signature".
    var parameterArray = [String]()
    for (key, val) in parameters {
      if let keyString = key.urlEncoded,
         let valString = val.urlEncoded {
        let line = String(format: "%@=%@", keyString, valString)
        parameterArray.append(line)
      }
    }

    if let query = url.query {
      let queryArray = query.components(separatedBy: "&")
      for str in queryArray {
        let arr = str.components(separatedBy: "=")
        if let  name = arr[0].urlEncoded,
           let value = arr[1].urlEncoded {
          let line = String(format: "%@=%@", name, value)
          parameterArray.append(line)
        }
      }
    }
    parameterArray = parameterArray.sorted { $0 < $1 }
    let parameterString = parameterArray.joined(separator: "&")
    if let encodedString = parameterString.urlEncoded {
      signatureArray.append(encodedString)
    }

    let baseString = signatureArray.joined(separator: "&")
#if     DEBUG
    print("DEBUG[base] \(baseString)")
#endif // DEBUG

    var signingArray = [String]()
    if let consumerSecret = configuration.consumerSecret.urlEncoded {
      signingArray.append(consumerSecret)
    }
    if let tokenSecret = credential.oauthTokenSecret?.urlEncoded {
      signingArray.append(tokenSecret)
    }
    else {
      signingArray.append("")
    }
    let signingKey = signingArray.joined(separator: "&")
#if     DEBUG
    print("DEBUG[key] \(signingKey)")
#endif // DEBUG

    let signature = baseString.hmac(algorithm: .SHA1, key: signingKey)
#if     DEBUG
    print("DEBUG[signature] \(signature)")
#endif // DEBUG
    return signature
  }

  func oauthString(with parameters: Dictionary<String,String>) -> String {
    var oauthArray = [String]()
    for (key, val) in parameters {
      if let keyString = key.urlEncoded,
         let valString = val.urlEncoded {
        let field = String(format: "%@=\"%@\"", keyString, valString)
        oauthArray.append(field)
      }
    }
    oauthArray = oauthArray.sorted { $0 < $1 }
    return "OAuth " + oauthArray.joined(separator: ", ")
  }
}


// MARK: - 
public enum OAuthError: Error
{
  case unknownError(code: Int)

  case badRequest       // 400
  case unauthorized     // 401
  case forbidden        // 403
  case notFound         // 404
  case methodNotAllowed // 405
  case requestTimeout   // 408
  case lengthRequired   // 411

  case serverError      // 500
  case badGateway       // 502
  case unavailable      // 503
  case gatewayTimeout   // 504

  case unconstructedURL

  init(code: Int) {
    switch code {
      case 400: self = .badRequest
      case 401: self = .unauthorized
      case 403: self = .forbidden
      case 404: self = .notFound
      case 405: self = .methodNotAllowed
      case 408: self = .requestTimeout
      case 411: self = .lengthRequired
      case 500: self = .serverError
      case 502: self = .badGateway
      case 503: self = .unavailable
      case 504: self = .gatewayTimeout
      case 999: self = .unconstructedURL
      default: self = .unknownError(code: code)
    }
  }
}

public typealias OAuthAuthenticationHandler = (URL?, Error?) -> Void

// MARK: - 
extension OAuth
{
  public func requestCredentials(handler: @escaping OAuthAuthenticationHandler) {
    if let requestURL = URL(string: configuration.requestTokenURI) {
      request(with: "POST", url: requestURL, completion: {
        [unowned self] (data, response, error) in
        if error == nil, let data = data {
          if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 200 {
              if let responseString = String(data: data, encoding: .utf8) {
                let url = self.authenticateURL(with: responseString)
                handler(url, nil)
              }
            }
            else {
              handler(nil, OAuthError(code: httpResponse.statusCode))
            }
          }
        }
        else {
          handler(nil, error)
        }
      })
    }
    else {
      handler(nil, OAuthError(code: 999))
    }
  }

  func authenticateURL(with parameterString: String) -> URL? {
    var url: URL? = nil
    if let queryItems = parameterString.queryItems,
       let token = queryItems.filter({ $0.name == "oauth_token" }).first,
       let confirmed = queryItems.filter({ $0.name == "oauth_callback_confirmed" }).first {
      if confirmed.value == "true", let oauth_token = token.value {
        var urlString = configuration.authorizationURI + "?\(token.name)=\(oauth_token)"
        if isForceLogin {
          urlString += "&force_login=true"
        }
        url = URL(string: urlString)
        addNotification()
      }
    }
    return url
  }

  func addNotification() {
    let center = NotificationCenter.default
    center.addObserver(self,
                       selector: #selector(obtainAccessToken),
                       name: .OAuthDidAuthenticateRequestToken,
                       object: nil)
  }

  func removeNotification() {
    let center = NotificationCenter.default
    center.removeObserver(self,
                          name: .OAuthDidAuthenticateRequestToken,
                          object: nil)
  }

  @objc func obtainAccessToken(_ notification: Notification) {
    removeNotification()
    guard let userInfo = notification.userInfo else { return }
    /*
     * ios - Best way to parse URL string to get values for keys?
     *     - Stack Overflow
     * https://stackoverflow.com/questions/8756683/best-way-to-parse-url-string-to-get-values-for-keys
     */
    if let callbackURL = userInfo[OAuthAuthenticateCallbackURLKey] as? URL,
       let  queryItems = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems,
       let token = queryItems.filter({ $0.name == "oauth_token" }).first,
       let verifier = queryItems.filter({ $0.name == "oauth_verifier" }).first {
      credential.oauthToken = token.value
      credential.oauthVerifier = verifier.value
      if let requestURL = URL(string: configuration.accessTokenURI) {
        request(with: "POST", url: requestURL, completion: {
          [unowned self] (data, response, error) in
          guard error == nil, let data = data else {
            dump(error)
            return
          }
          if let httpResponse = response as? HTTPURLResponse {
            if let responseString = String(data: data, encoding: .utf8) {
              if httpResponse.statusCode == 200 {
                self.acquireCredentials(with: responseString)
              }
              else {
                print("Status code is \(httpResponse.statusCode)")
                dump(responseString)
              }
            }
          }
        })
      }
    }
  }

  func acquireCredentials(with responseString: String) {
    if let queryItems = responseString.queryItems,
       let token = queryItems.filter({ $0.name == "oauth_token" }).first,
       let secret = queryItems.filter({ $0.name == "oauth_token_secret" }).first {
      credential.oauthToken = token.value
      credential.oauthTokenSecret = secret.value
      credential.oauthVerifier = nil
      verifyCredentials()
    }
  }

  func verifyCredentials() {
    if let requestURL = URL(string: "https://api.twitter.com/1.1/account/verify_credentials.json") {
      let parameters: [String:String] = [
        "include_entities" : "false",
        "skip_status" : "true",
        "include_email" : "true"
      ]
      request(with: "GET", url: requestURL, parameters: parameters, completion: {
        [unowned self] (data, response, error) in
        guard error == nil, let data = data else {
          dump(error)
          return
        }
        if let httpResponse = response as? HTTPURLResponse {
          if httpResponse.statusCode == 200 {
            switch self.configuration.serviceType {
              case .twitter:
                self.twitterCredentials(with: data)
              default:
                break
            }
          }
          else {
            print("Status code is \(httpResponse.statusCode)")
            let responseString = String(data: data, encoding: .utf8)
            dump(responseString)
          }
        }
      })
    }
  }

  func twitterCredentials(with data: Data) {
    do {
      if let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String:Any] {
        if let screenName = json["screen_name"] as? String,
           let userIdStr = json["id_str"] as? String,
           let oauthToken = self.credential.oauthToken,
           let tokenSecret = self.credential.oauthTokenSecret {
          let credentials = TwitterCredential(token: oauthToken, secret: tokenSecret)
          credentials.screenName = screenName
          credentials.userID = userIdStr
          let userInfo: [String:Any] = [
            OAuthCredentialsKey: credentials
          ]
          NotificationCenter.default.post(name: .OAuthDidVerifyCredentials, object: nil, userInfo: userInfo)
        }
      }
    }
    catch let error {
      dump(error)
    }
  }
}


// MARK: - 
extension TwitterOAuthConfiguration
{
  // Xcode の Info.plist に ConsumerKey と ConsumerSecret が設定されていたら
  // それらの値を初期値とする
  mutating func readConsumerKeyAndSecret(from plist: String = "Info") {
    if let url = Bundle.main.url(forResource: plist, withExtension: "plist") {
      do {
        let data = try Data(contentsOf: url)
        let dict = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as! [String:Any]
        if let key = dict["TwitterConsumerKey"] as? String,
           let secret = dict["TwitterConsumerSecret"] as? String {
          consumerKey = key
          consumerSecret = secret
        }
      }
      catch let error {
        dump(error)
      }
    }
  }
}


// MARK: - 
fileprivate extension URL
{
  var baseURLString: String {
    var array = [String]()
    if let scheme = self.scheme {
      array.append(scheme)
      array.append("://")
    }
    if let host = self.host {
      array.append(host)
    }
    if let port = self.port, port != 80 {
      array.append(String(format: ":%zd", port))
    }
    array.append(path)
    return array.joined()
  }
}


// MARK: - 
fileprivate extension String
{
  var urlEncoded: String? {
    let allowedCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
    return self.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet)
  }

  var queryItems: [URLQueryItem]? {
    var parameters = [URLQueryItem]()
    let parameterArray = self.components(separatedBy: "&")
    for parameter in parameterArray {
      let components = parameter.components(separatedBy: "=")
      if let key = components.first, let val = components.last {
        let queryItem = URLQueryItem(name: key, value: val)
        parameters.append(queryItem)
      }
    }
    return parameters.count > 0 ? parameters : nil
  }
}

/*
 * ios - Implementing HMAC and SHA1 encryption in swift - Stack Overflow
 * https://stackoverflow.com/questions/26970807/implementing-hmac-and-sha1-encryption-in-swift
 *
 * osx - CommonHMAC in Swift - Stack Overflow
 * https://stackoverflow.com/questions/24099520/commonhmac-in-swift
 */
fileprivate enum CryptoAlgorithm
{
  case MD5, SHA1, SHA224, SHA256, SHA384, SHA512

  var HMACAlgorithm: CCHmacAlgorithm {
    var result: Int = 0
    switch self {
      case .MD5:    result = kCCHmacAlgMD5
      case .SHA1:   result = kCCHmacAlgSHA1
      case .SHA224: result = kCCHmacAlgSHA224
      case .SHA256: result = kCCHmacAlgSHA256
      case .SHA384: result = kCCHmacAlgSHA384
      case .SHA512: result = kCCHmacAlgSHA512
    }
    return CCHmacAlgorithm(result)
  }

  var digestLength: Int {
    var result: Int32 = 0
    switch self {
      case .MD5:    result = CC_MD5_DIGEST_LENGTH
      case .SHA1:   result = CC_SHA1_DIGEST_LENGTH
      case .SHA224: result = CC_SHA224_DIGEST_LENGTH
      case .SHA256: result = CC_SHA256_DIGEST_LENGTH
      case .SHA384: result = CC_SHA384_DIGEST_LENGTH
      case .SHA512: result = CC_SHA512_DIGEST_LENGTH
    }
    return Int(result)
  }
}

fileprivate extension String
{
  func hmac(algorithm: CryptoAlgorithm, key: String) -> String {
    let  keyStr =  key.cString(using: String.Encoding.utf8)
    let  keyLen = Int(key.lengthOfBytes(using: String.Encoding.utf8))
    let dataStr = self.cString(using: String.Encoding.utf8)
    let dataLen = Int(self.lengthOfBytes(using: String.Encoding.utf8))
    let digestLen = algorithm.digestLength
    var result = [CUnsignedChar](repeating: 0, count: digestLen)
    CCHmac(algorithm.HMACAlgorithm, keyStr!, keyLen, dataStr!, dataLen, &result)
    let hmacData: NSData = NSData(bytes: result, length: digestLen)
#if     false
    let hmacBase64 = hmacData.base64EncodedString(options: NSData.Base64EncodingOptions.lineLength76Characters)
#else
    let hmacBase64 = hmacData.base64EncodedString(options: NSData.Base64EncodingOptions.lineLength64Characters)
#endif
    return String(hmacBase64)
  }
}


// MARK: - DEBUG for Develpers
public let debugHandler: OAuthRequestHandler = {
  (data, response, error) in
  guard let data = data, error == nil else {
    dump(error)
    return
  }
  if let httpResponse = response as? HTTPURLResponse {
    print("Status code is \(httpResponse.statusCode)")
  }
  let responseString = String(data: data, encoding: .utf8)
  dump(responseString)
}
