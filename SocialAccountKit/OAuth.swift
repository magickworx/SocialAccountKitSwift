/*****************************************************************************
 *
 * FILE:	OAuth.swift
 * DESCRIPTION:	SocialAccountKit: OAuth Authorization Class
 * DATE:	Fri, Sep 15 2017
 * UPDATED:	Tue, Oct 10 2017
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
public let OAuthDidEndInFailureNotification: String = "OAuthDidEndInFailureNotification"
public let OAuthAuthenticateCallbackURLKey: String = "OAuthAuthenticateCallbackURLKey"

public let OAuthDidVerifyCredentialsNotification: String = "OAuthDidVerifyCredentialsNotification"
public let OAuthDidMissCredentialsNotification: String = "OAuthDidMissCredentialsNotification"
public let OAuthCredentialsKey: String = "OAuthCredentialsKey"
public let OAuthErrorInfoKey: String = "OAuthErrorInfoKey"

public extension NSNotification.Name {
  public static let OAuthDidAuthenticateRequestToken = NSNotification.Name(OAuthDidAuthenticateRequestTokenNotification)
  public static let OAuthDidEndInFailure = NSNotification.Name(OAuthDidEndInFailureNotification)
  public static let OAuthDidVerifyCredentials = NSNotification.Name(OAuthDidVerifyCredentialsNotification)
  public static let OAuthDidMissCredentials = NSNotification.Name(OAuthDidMissCredentialsNotification)
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
  var verifyTokenURI: String { get }

  var callbackURI: String { set get }

  var consumerKey: String { set get }
  var consumerSecret: String { set get }

  var isReady: Bool { get }
}

// MARK: - 
open class OAuthCredential
{
  public init() {
  }

  // MARK: - OAuth 1.0
  public internal(set) var oauthToken: String? = nil
  public internal(set) var oauthTokenSecret: String? = nil

  public internal(set) var oauthVerifier: String? = nil

  public convenience init(token: String, secret: String) {
    self.init()
    self.oauthToken = token
    self.oauthTokenSecret = secret
  }

  public func update(token: String?, verifier: String?) {
    self.oauthToken = token
    self.oauthVerifier = verifier
  }

  public func renew(token: String?, secret: String?) {
    self.oauthToken = token
    self.oauthTokenSecret = secret
    self.oauthVerifier = nil
  }

  public var isValidOAuth: Bool {
    return (oauthToken != nil && oauthTokenSecret != nil)
  }

  // MARK: - OAuth 2.0
  public var oauth2Token: String? = nil
  public var refreshToken: String? = nil
  public var expiryDate: Date? = nil

  public var tokenType: String? = nil // "bearer", "mac", and so on

  public convenience init(token: String, refresh: String? = nil, expiry: Date, type: String = "bearer") {
    self.init()
    self.oauth2Token = token
    self.refreshToken = refresh
    self.expiryDate = expiry
    self.tokenType = type
  }
}

public typealias OAuthRequestHandler = (Data?, URLResponse?, Error?) -> Void

/*
 * RFC 5849 - The OAuth 1.0 Protocol
 */
public class OAuth
{
  public internal(set) var configuration: OAuthConfigurationProtocol
  var credential: OAuthCredential

  public init(_ configuration: OAuthConfigurationProtocol, credential: OAuthCredential = OAuthCredential()) {
    self.configuration = configuration
    self.credential = credential
  }

  public func request(with method: String, url: URL, parameters: [String:Any] = [:], completion: @escaping OAuthRequestHandler) {
    let glueCount = parameters.count - 1 // パラメータ間の '&' の個数
    let queryString: String = parameters.enumerated().reduce("") {
      (input, tuple) -> String in
      var key = tuple.element.key
      if let encodedKey = key.urlEncoded {
        key = encodedKey
      }
      switch tuple.element.value {
        case let bool as Bool:
          return input + key + "=" + (bool ? "true" : "false")
                       + (glueCount > tuple.offset ? "&" : "")
        case let int as Int:
          return input + key + "=" + String(int)
                       + (glueCount > tuple.offset ? "&" : "")
        case let string as String:
          var value = string
          if let encodedValue = value.urlEncoded {
            value = encodedValue
          }
          return input + key + "=" + value
                       + (glueCount > tuple.offset ? "&" : "")
        default:
          return input
      }
    }

    var request = URLRequest(url: url)
    if method == "GET" && !parameters.isEmpty {
      var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
      components?.query = queryString
      if let newURL = components?.url {
        request = URLRequest(url: newURL)
      }
    }

    request.httpMethod = method
    request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    let authField = authorizationHttpField(with: method, url: url.baseStringURI, query: queryString.isEmpty ? nil : queryString)
    request.setValue(authField, forHTTPHeaderField: "Authorization")

    request.setValue("application/json", forHTTPHeaderField: "Accept")
    switch method {
      case "POST":
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        if !parameters.isEmpty {
          request.httpBody = queryString.data(using: .utf8)
          var length: Int = 0
          if let body = request.httpBody {
            length = body.count
          }
          request.setValue(String(length), forHTTPHeaderField: "Content-Length")
        }
      default:
        break
    }

    (URLSession.shared.dataTask(with: request) {
      (data, response, error) in
      if let httpResponse = response as? HTTPURLResponse {
        let statusCode = httpResponse.statusCode
        if let data = data {
          if statusCode == 200 {
            completion(data, response, nil)
          }
          else {
            completion(data, response, SAKError.FailedServerResponse(statusCode, data))
          }
        }
      }
      if let error = error {
        completion(data, response, SAKError.SendRequestError(error))
      }
    }).resume()
  }

  func authorizationHttpField(with method: String, url: URL, query: String?) -> String {
    switch configuration.serviceType {
      case .facebook:
        return oAuth2HeaderField()
      default:
        return oAuth1HeaderField(with: method, url: url, query: query)
    }
  }

  func oAuth2HeaderField() -> String {
    guard let  tokenType = credential.tokenType,
          let oauthToken = credential.oauth2Token else { return "" }
    switch tokenType {
      case "bearer":
        return "Bearer \(oauthToken)"
      default:
        return ""
    }
  }

  func oAuth1HeaderField(with method: String, url: URL, query: String?) -> String {
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
    if !credential.isValidOAuth {
      param["oauth_callback"] = configuration.callbackURI
    }
    param["oauth_signature"] = signature(with: method, url: url, query: query, parameters: param)
    let oauthField = oauthString(with: param)
    return oauthField
  }

  func nonce() -> String {
    let uuid = UUID().uuidString
    return uuid.substring(to: uuid.index(uuid.startIndex, offsetBy: 8))
  }

  func signature(with method: String, url: URL, query: String?, parameters: [String:String]) -> String {
    var signatureArray = [String]() // for Signature Base String

    // The HTTP request method (e.g., "GET", "POST", etc).
    signatureArray.append(method.uppercased())

    // RFC 5849 Section 3.4.1.2
    if let urlString = url.baseStringURIString.urlEncoded {
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

    if let query = query {
      let queryArray = query.components(separatedBy: "&")
      for pair in queryArray {
        // pair 文字列は既に urlEncoded 済み
        parameterArray.append(pair)
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


public typealias OAuthAuthenticationHandler = (URL?, Error?) -> Void

// MARK: - 
extension OAuth
{
  public func requestCredentials(handler: @escaping OAuthAuthenticationHandler) {
    credential = OAuthCredential() // XXX: 手っ取り早い初期化
    switch self.configuration.serviceType {
      case .facebook:
        requestFacebookCredentials(handler: handler)
      default:
        requestOAuthCredentials(handler: handler)
    }
  }

  func requestOAuthCredentials(handler: @escaping OAuthAuthenticationHandler) {
    let urlString = configuration.requestTokenURI
    if let requestURL = URL(string: urlString) {
      request(with: "POST", url: requestURL, completion: {
        [unowned self] (data, response, error) in
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 200 {
          if let data = data, let responseString = String(data: data, encoding: .utf8) {
            let url = self.authenticateURL(with: responseString)
            handler(url, nil)
          }
        }
        else if let error = error {
          handler(nil, error)
        }
      })
    }
    else {
      handler(nil, SAKError.UnconstructedURL(urlString))
    }
  }

  func authenticateURL(with parameterString: String) -> URL? {
    var url: URL? = nil
    if let queryItems = parameterString.queryItems,
       let token = queryItems.filter({ $0.name == "oauth_token" }).first,
       let confirmed = queryItems.filter({ $0.name == "oauth_callback_confirmed" }).first {
      if confirmed.value == "true", let oauth_token = token.value {
        var urlString = configuration.authorizationURI + "?\(token.name)=\(oauth_token)"
        if configuration.serviceType == .twitter,
           let twitterConfig = configuration as? TwitterOAuthConfiguration,
           twitterConfig.isForceLogin {
          urlString += "&force_login=true"
        }
        url = URL(string: urlString)
        addNotification()
      }
    }
    return url
  }

  func requestFacebookCredentials(handler: @escaping OAuthAuthenticationHandler) {
    if let configuration = self.configuration as? FacebookOAuthConfiguration {
      // See https://developers.facebook.com/docs/facebook-login/permissions/
      let scope = configuration.permissions.count > 0
                ? configuration.permissions.joined(separator: ",")
                : "public_profile"
      let urlString = configuration.authorizationURI
                    + "?response_type=code"
                    + "&client_id=" + configuration.consumerKey
                    + "&redirect_uri=" + configuration.callbackURI
                    + "&scope=" + scope
      if let url = URL(string: urlString) {
        addNotification()
        handler(url, nil)
      }
      else {
        handler(nil, SAKError.UnconstructedURL(urlString))
      }
    }
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
    if let callbackURL = userInfo[OAuthAuthenticateCallbackURLKey] as? URL {
      switch self.configuration.serviceType {
        case .facebook:
          obtainFacebookAccessToken(with: callbackURL)
        default:
          obtainOAuthAccessToken(with: callbackURL)
      }
    }
  }
}

extension OAuth
{
  func handleCredentialsError(_ error: Error) {
    NotificationCenter.default.post(name: .OAuthDidMissCredentials, object: nil, userInfo: [
      OAuthErrorInfoKey: error
    ])
  }

  func handleErrorResponse(_ data: Data, statusCode: Int) {
    let error = SAKError.FailedServerResponse(statusCode, data)
    handleCredentialsError(error)
  }
}

// MARK: - Handle OAuth Access Token
extension OAuth
{
  func obtainOAuthAccessToken(with callbackURL: URL) {
    /*
     * ios - Best way to parse URL string to get values for keys?
     *     - Stack Overflow
     * https://stackoverflow.com/questions/8756683/best-way-to-parse-url-string-to-get-values-for-keys
     */
    if let queryItems = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems,
       let token = queryItems.filter({ $0.name == "oauth_token" }).first,
       let verifier = queryItems.filter({ $0.name == "oauth_verifier" }).first {
      credential.update(token: token.value, verifier: verifier.value)
      if let requestURL = URL(string: configuration.accessTokenURI) {
        request(with: "POST", url: requestURL, completion: {
          [unowned self] (data, response, error) in
          if let httpResponse = response as? HTTPURLResponse,
             httpResponse.statusCode == 200 {
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
              self.acquireCredentials(with: responseString)
            }
          }
          else if let error = error {
            self.handleCredentialsError(error)
          }
        })
      }
    }
  }

  func acquireCredentials(with responseString: String) {
    if let queryItems = responseString.queryItems,
       let token = queryItems.filter({ $0.name == "oauth_token" }).first,
       let secret = queryItems.filter({ $0.name == "oauth_token_secret" }).first {
      credential.renew(token: token.value, secret: secret.value)
      switch self.configuration.serviceType {
        case .twitter:
          verifyTwitterCredentials()
        default:
          break
      }
    }
  }
}


// MARK: - 
extension URL
{
  var baseStringURIString: String {
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

  var baseStringURI: URL {
    return URL(string: self.baseStringURIString)!
  }
}


// MARK: - 
extension String
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
    return parameters.isEmpty ? nil : parameters
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
