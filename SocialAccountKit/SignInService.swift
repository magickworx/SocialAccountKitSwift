/*****************************************************************************
 *
 * FILE:	SignInService.swift
 * DESCRIPTION:	SocialAccountKit: Sign In Service Class
 * DATE:	Sat, Oct 21 2017
 * UPDATED:	Thu, Oct 26 2017
 * AUTHOR:	Kouichi ABE (WALL) / 阿部康一
 * E-MAIL:	kouichi@MagickWorX.COM
 * URL:		http://www.MagickWorX.COM/
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

public typealias SAKSignInServiceCompletionHandler = (Bool, SAKAccount?, Error?) -> Void

public class SAKSignInService: NSObject
{
  /*
   * Sign In 認証後に SAKAccountStore にアカウントを保存する。
   * Google Firebase と連携する場合は、false が望ましいと思う。
   * SAKAccountViewController 経由でアカウント作成をしない場合は、
   * true を設定すると良い。
   */
  public var isStoreEnabled: Bool = false // true: AccountStore に保存する

  public internal(set) var accountType: SAKAccountType? = nil {
    didSet {
      if let accountType = accountType {
        switch accountType.identifier {
          case .twitter:
            let configuration = TwitterOAuthConfiguration()
            oauth = OAuth(configuration)
          case .facebook:
            let configuration = FacebookOAuthConfiguration()
            oauth = OAuth(configuration)
          case .github:
            let configuration = GitHubOAuthConfiguration()
            oauth = OAuth(configuration)
          case .appOnly:
            let configuration = AppOnlyAuthConfiguration()
            oauth = OAuth(configuration)
        }
      }
    }
  }

  let accountStore = SAKAccountStore.shared

  var oauth: OAuth? = nil
  var completionHandler: SAKSignInServiceCompletionHandler? = nil

  public convenience init(accountType: SAKAccountType) {
    self.init()

    addNotification()

    defer {
      self.accountType = accountType
    }
  }

  deinit {
    removeNotification()
  }
}

extension SAKSignInService
{
  fileprivate func addNotification() {
    let center = NotificationCenter.default
    center.addObserver(self,
                       selector: #selector(verfiyCredentials),
                       name: .OAuthDidVerifyCredentials,
                       object: nil)
    center.addObserver(self,
                       selector: #selector(missCredentials),
                       name: .OAuthDidMissCredentials,
                       object: nil)
    center.addObserver(self,
                       selector: #selector(authorizationFailure),
                       name: .OAuthDidEndInFailure,
                       object: nil)
  }

  fileprivate func removeNotification() {
    let center = NotificationCenter.default
    center.removeObserver(self,
                          name: .OAuthDidVerifyCredentials,
                          object: nil)
    center.removeObserver(self,
                          name: .OAuthDidMissCredentials,
                          object: nil)
    center.removeObserver(self,
                          name: .OAuthDidEndInFailure,
                          object: nil)
  }

  @objc fileprivate func verfiyCredentials(_ notification: Notification) {
    guard let userInfo = notification.userInfo else { return }
    if let accountType = self.accountType,
       let credentials = userInfo[OAuthCredentialsKey] as? OAuthCredential {
      saveCredentials(credentials, accountType: accountType)
    }
  }

  fileprivate func saveCredentials(_ credentials: OAuthCredential, accountType: SAKAccountType) {
    let account = SAKAccount(accountType: accountType)
    switch accountType.identifier {
      case .twitter:
        if let credentials = credentials as? TwitterCredential,
           let name = credentials.screenName,
           let token = credentials.oauthToken,
           let secret = credentials.oauthTokenSecret {
          account.username = name
          account.credential = SAKAccountCredential(oAuthToken: token, tokenSecret: secret)
        }
      case .facebook:
        if let credentials = credentials as? FacebookCredential,
           let name = credentials.fullName,
           let type = credentials.tokenType,
           let token = credentials.oauth2Token,
           let refresh = credentials.refreshToken,
           let expiry = credentials.expiryDate {
          account.username = name
          account.credential = SAKAccountCredential(oAuth2Token: token, refreshToken: refresh, expiryDate: expiry, tokenType: type)
        }
      case .github:
        if let credentials = credentials as? GitHubCredential,
           let name = credentials.login,
           let type = credentials.tokenType,
           let token = credentials.oauth2Token,
           let refresh = credentials.refreshToken,
           let expiry = credentials.expiryDate {
          account.username = name
          account.credential = SAKAccountCredential(oAuth2Token: token, refreshToken: refresh, expiryDate: expiry, tokenType: type)
        }
      case .appOnly:
        if let credentials = credentials as? AppOnlyCredential,
           let type = credentials.tokenType,
           let token = credentials.oauth2Token,
           let refresh = credentials.refreshToken,
           let expiry = credentials.expiryDate {
          account.username = credentials.appName
          account.credential = SAKAccountCredential(oAuth2Token: token, refreshToken: refresh, expiryDate: expiry, tokenType: type)
        }
    }
    if isStoreEnabled {
      accountStore.saveAccount(account, withCompletionHandler: {
        [unowned self] (successful, error) in
        if let completionHandler = self.completionHandler {
          completionHandler(successful, account, error)
        }
      })
    }
    else {
      if let completionHandler = self.completionHandler {
        completionHandler(true, account, nil)
      }
    }
  }

  @objc fileprivate func missCredentials(_ notification: Notification) {
    guard let userInfo = notification.userInfo else { return }
    if let error = userInfo[OAuthErrorInfoKey] as? Error {
      handleError(error)
    }
  }

  @objc fileprivate func authorizationFailure(_ notification: Notification) {
    let text = "Failed to authorize account. Check username and password once again."
    handleError(SAKError.OAuthAuthenticationFailed(text))
  }
}

extension SAKSignInService
{
  public func signIn(contentController: UIViewController, completion: @escaping SAKSignInServiceCompletionHandler) {
    self.completionHandler = completion
    guard let oauth = self.oauth, oauth.configuration.isReady else {
      configurationUnprepared()
      return
    }
    guard let accountType = self.accountType,
          accountType.identifier != .appOnly else {
      return
    }
    oauth.requestCredentials(handler: {
      [unowned self] (url, error) in
      guard error == nil else {
        if let error = error {
          var text = String()
          dump(error, to: &text)
          self.handleError(SAKError.OAuthAuthenticationFailed(text))
        }
        return
      }
      if let authenticateURL = url {
        DispatchQueue.main.async {
          autoreleasepool {
            let viewController = SAKSignInViewController(with: authenticateURL, accountType: accountType)
            viewController.callback = oauth.configuration.callbackURI
            switch accountType.identifier {
              case .facebook:
                viewController.clearCache(of: [ .diskCache, .memoryCache, .cookies ], in: "facebook.com")
              case .github:
                viewController.clearCache()
              default:
                break
            }
            contentController.present(viewController, animated: true, completion: nil)
          }
        }
      }
    })
  }

  public func signIn(completion: @escaping SAKSignInServiceCompletionHandler) {
    guard let oauth = self.oauth, oauth.configuration.isReady else {
      configurationUnprepared()
      return
    }
    if let accountType = self.accountType, accountType.identifier == .appOnly {
      self.completionHandler = completion
      oauth.requestCredentials(handler: {
        [unowned self] (url, error) in
        if url == nil && error == nil {
          oauth.verifyAppOnlyCredentials()
        }
        else {
          self.handleError(error)
        }
      })
    }
  }

  public func signOut(_ account: SAKAccount, completion: @escaping SAKSignInServiceCompletionHandler) {
    self.completionHandler = nil // XXX: Clear
    accountStore.removeAccount(account, withCompletionHandler: {
      (successful, error) in
      completion(successful, account, error)
    })
  }

  fileprivate func configurationUnprepared() {
    if let accountType = self.accountType {
      let service = accountType.serviceName
      let text: String
      switch accountType.identifier {
        case .twitter, .appOnly:
          text = "Confirm \(service).plist has set ConsumerKey and ConsumerSecret."
        case .facebook:
          text = "Confirm \(service).plist has set AppID and AppSecret."
        case .github:
          text = "Confirm \(service).plist has set ClientID and ClientSecret."
        /*
        default:
          text = "Unsupported service: \(service)"
          */
      }
      handleError(SAKError.OAuthConfigurationUnprepared(text))
    }
  }

  fileprivate func handleError(_ error: Error?) {
    if let completionHandler = self.completionHandler {
      completionHandler(false, nil, error)
    }
  }
}
