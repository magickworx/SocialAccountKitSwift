/*****************************************************************************
 *
 * FILE:	SignInViewController.swift
 * DESCRIPTION:	SocialAccountKit: View Controller for Sign In Service
 * DATE:	Fri, Sep 22 2017
 * UPDATED:	Thu, Oct 26 2017
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
import WebKit

public class SAKSignInViewController: UIViewController
{
  public var callback: String = "swift-oauth://callback"

  public internal(set) var requestURL: URL?
  public internal(set) var accountType: SAKAccountType?

  enum SignInState: CustomStringConvertible {
    case ready
    case start
    case request
    case authorizing
    case authorized
    case failed

    mutating func next(_ requestURL: URL, _ nextURL: URL, _ callback: String) {
      let requestBase = requestURL.baseStringURIString
      let    nextBase = nextURL.baseStringURIString
      switch self {
        case .ready:
          if  requestURL == nextURL  { self = .start }
        case .start:
          if requestBase == nextBase { self = .authorizing }
          else                       { self = .request }
        case .request:
          if requestBase == nextBase { self = .authorizing }
        case .authorizing:
          if    nextBase == callback { self = .authorized }
          else if requestBase == nextBase {}
          else                       { self = .failed }
        case .authorized:
          break
        case .failed:
          break
      }
    }

    var description: String {
      switch self {
        case .ready:       return "Ready"
        case .start:       return "Start"
        case .request:     return "Request"
        case .authorizing: return "Authorizing"
        case .authorized:  return "Authorized"
        case .failed:      return "Failed"
      }
    }
  }
  var state: SignInState = .ready

  var configuration = WKWebViewConfiguration()
  var webView: WKWebView?

  required public init(coder aDecoder: NSCoder) {
    fatalError("NSCoding not supported")
  }

  init() {
    super.init(nibName: nil, bundle: nil)
  }

  public convenience init(with url: URL, configuration: WKWebViewConfiguration? = nil, accountType type: SAKAccountType = SAKAccountType(.twitter)) {
    self.init()
    self.requestURL = url
    if let configuration = configuration {
      self.configuration = configuration
    }
    self.accountType = type
  }

  deinit {
    if let webView = self.webView, webView.isLoading {
      webView.stopLoading()
      webView.navigationDelegate = nil
    }
  }

  override public func loadView() {
    super.loadView()

    self.edgesForExtendedLayout = []
    self.extendedLayoutIncludesOpaqueBars = true
    if #available(iOS 11.0, *) {
    }
    else {
      self.automaticallyAdjustsScrollViewInsets = false
    }

    self.view.backgroundColor = .white
    self.view.autoresizesSubviews = true
    self.view.autoresizingMask	= [ .flexibleWidth, .flexibleHeight ]

    webView = WKWebView(frame: self.view.bounds, configuration: configuration)
    webView?.autoresizingMask = [ .flexibleWidth, .flexibleHeight ]
    webView?.navigationDelegate = self
    self.view.addSubview(webView!)
  }

  override public func viewDidLoad() {
    super.viewDidLoad()

    if let webView = self.webView, let url = self.requestURL {
      var request = URLRequest(url: url)
      request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
      webView.load(request)
    }
  }

  override public func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
}

extension SAKSignInViewController: WKNavigationDelegate
{
  public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    if let callbackURL = navigationAction.request.url, let requestURL = self.requestURL, let accountType = self.accountType {
      switch accountType.identifier {
        case .twitter:
          handleTwitterSignIn(requestURL: requestURL, callbackURL: callbackURL)
        case .facebook:
          handleFacebookSignIn(requestURL: requestURL, callbackURL: callbackURL)
        case .github:
          handleGitHubSignIn(requestURL: requestURL, callbackURL: callbackURL)
        default:
          break
      }
    }
    decisionHandler(.allow)
  }

  fileprivate func handleTwitterSignIn(requestURL: URL, callbackURL: URL) {
    state.next(requestURL, callbackURL, callback)
    switch state {
      case .authorized:
        NotificationCenter.default.post(name: .OAuthDidAuthenticateRequestToken, object: nil, userInfo: [
          OAuthAuthenticateCallbackURLKey: callbackURL
        ])
        self.dismiss(animated: true, completion: nil)
      case .failed:
        self.dismiss(animated: true, completion: {
          NotificationCenter.default.post(name: .OAuthDidEndInFailure, object: nil, userInfo: nil)
        })
      default:
        break
    }
  }

  /*
   * ログインフローを手作業で構築する - Facebook ログイン
   * https://developers.facebook.com/docs/facebook-login/manually-build-a-login-flow/
   */
  fileprivate func handleFacebookSignIn(requestURL: URL, callbackURL: URL) {
    if callbackURL.baseStringURIString == callback {
      NotificationCenter.default.post(name: .OAuthDidAuthenticateRequestToken, object: nil, userInfo: [
        OAuthAuthenticateCallbackURLKey: callbackURL
      ])
      self.dismiss(animated: true, completion: nil)
    }
  }

  fileprivate func handleGitHubSignIn(requestURL: URL, callbackURL: URL) {
    state.next(requestURL, callbackURL, callback)
#if DEBUG_FLOW
    print("REQUEST:  " + requestURL.absoluteString)
    print("CALLBACK: " + callbackURL.absoluteString)
    print("[\(state.description)]")
#endif // DEBUG
    switch state {
      case .authorized:
        NotificationCenter.default.post(name: .OAuthDidAuthenticateRequestToken, object: nil, userInfo: [
          OAuthAuthenticateCallbackURLKey: callbackURL
        ])
        self.dismiss(animated: true, completion: nil)
      case .failed:
        self.dismiss(animated: true, completion: {
          NotificationCenter.default.post(name: .OAuthDidEndInFailure, object: nil, userInfo: nil)
        })
      default:
        break
    }
  }
}

extension SAKSignInViewController
{
  /*
   * swift3 - Any property or method to clear a WKWebiew's cache
   *        - Stack Overflow
   * https://stackoverflow.com/questions/43767009/any-property-or-method-to-clear-a-wkwebiews-cache
   */
  public func clearCache(of dataTypesSet: WebsiteDataType = .allWebsiteData, in domainSubstring: String? = nil) {
    let dataStore = WKWebsiteDataStore.default()
    let dataTypes = dataTypesSet.dataTypes()
    if let domain = domainSubstring {
      dataStore.fetchDataRecords(ofTypes: dataTypes) {
        (records) in
        for record in records {
print("Found: \(record.displayName)")
          guard record.displayName.contains(domain) else { continue }
          dataStore.removeData(ofTypes: dataTypes, for: [record], completionHandler: {
            print("Deleted: \(record.displayName)")
          })
        }
      }
    }
    else {
      dataStore.removeData(ofTypes: dataTypes, modifiedSince: Date(timeIntervalSince1970: 0), completionHandler: {})
    }
  }
}

public struct WebsiteDataType: OptionSet
{
  public let rawValue: Int

  static let allWebsiteData             = WebsiteDataType(rawValue: 1 << 0)
  static let diskCache                  = WebsiteDataType(rawValue: 1 << 1)
  static let memoryCache                = WebsiteDataType(rawValue: 1 << 2)
  static let offlineWebApplicationCache = WebsiteDataType(rawValue: 1 << 3)
  static let cookies                    = WebsiteDataType(rawValue: 1 << 4)
  static let sessionStorage             = WebsiteDataType(rawValue: 1 << 5)
  static let localStorage               = WebsiteDataType(rawValue: 1 << 6)
  static let webSQLDatabases            = WebsiteDataType(rawValue: 1 << 7)
  static let indexedDBDatabases         = WebsiteDataType(rawValue: 1 << 8)

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  func dataTypes() -> Set<String> {
    if self.contains(.allWebsiteData) {
      return WKWebsiteDataStore.allWebsiteDataTypes()
    }

    var types: Set<String> = []
    if self.contains(.diskCache) { // On-disk caches.
      types.insert(WKWebsiteDataTypeDiskCache)
    }
    if self.contains(.memoryCache) { // In-memory caches.
      types.insert(WKWebsiteDataTypeMemoryCache)
    }
    if self.contains(.offlineWebApplicationCache) {
      // HTML offline web application caches.
      types.insert(WKWebsiteDataTypeOfflineWebApplicationCache)
    }
    if self.contains(.cookies) { // Cookies.
      types.insert(WKWebsiteDataTypeCookies)
    }
    if self.contains(.sessionStorage) { // HTML session storage.
      types.insert(WKWebsiteDataTypeSessionStorage)
    }
    if self.contains(.localStorage) { // HTML local storage.
      types.insert(WKWebsiteDataTypeLocalStorage)
    }
    if self.contains(.webSQLDatabases) { // WebSQL databases.
      types.insert(WKWebsiteDataTypeWebSQLDatabases)
    }
    if self.contains(.indexedDBDatabases) { // IndexedDB databases.
      types.insert(WKWebsiteDataTypeIndexedDBDatabases)
    }
    return types
  }
}
