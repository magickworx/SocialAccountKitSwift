/*****************************************************************************
 *
 * FILE:	GitHubOAuthCredential.swift
 * DESCRIPTION:	SocialAccountKit: OAuth Credentials for GitHub
 * DATE:	Wed, Oct 25 2017
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

public class GitHubCredential: OAuthCredential
{
  public var userID: Int64? = nil
  public var name: String? = nil
  public var login: String? = nil
  public var email: String? = nil
}

fileprivate typealias GitHubRequestHandler = (Data) -> Void

extension OAuth
{
  func requestGitHubCredentials(handler: @escaping OAuthAuthenticationHandler) {
    print("[GitHub] request")
    if let configuration = self.configuration as? GitHubOAuthConfiguration {
      let scope = configuration.scopes.count > 0
                ? configuration.scopes.joined(separator: "%20")
                : "read:user"
      let urlString = configuration.authorizationURI
                    + "?allow_signup=false"
                    + "&state=" + nonce()
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

  func obtainGitHubAccessToken(with callbackURL: URL) {
    print("[GitHub] obtain " + callbackURL.absoluteString)
    guard let query = callbackURL.query else { return }
    let urlString = configuration.accessTokenURI
                  + "?client_id=\(configuration.consumerKey)"
                  + "&client_secret=\(configuration.consumerSecret)"
                  + "&redirect_uri=\(configuration.callbackURI)"
                  + "&" + query
    if let url = URL(string: urlString) {
      var request = URLRequest(url: url)
      request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
      request.setValue("application/json", forHTTPHeaderField: "Accept")
      sendRequest(request, handler: {
        [unowned self] (data) in
        self.acquireGitHubCredentials(with: data)
      })
    }
  }

  func acquireGitHubCredentials(with data: Data) {
    print("[GitHub] aquire")
    do {
      if let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String:Any] {
        if let accessToken = json["access_token"] as? String,
           let   tokenType = json["token_type"] as? String {
          credential.renew(token: accessToken, type: tokenType.lowercased())
          verifyGitHubCredential()
        }
      }
    }
    catch let error {
      handleCredentialsError(error)
    }
  }

  func verifyGitHubCredential() {
    print("[GitHub] verify")
    guard let accessToken = credential.oauth2Token else { return }
    let urlString = self.configuration.verifyTokenURI
    if let url = URL(string: urlString) {
      var request = URLRequest(url: url)
      request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
      request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
      request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
      sendRequest(request, handler: {
        [unowned self] (data) in
        self.githubCredentials(with: data)
      })
    }
  }

  func githubCredentials(with data: Data) {
    print("[GitHub] credentials")
    do {
      if let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String:Any] {
        if let  tokenType = self.credential.tokenType,
           let oauthToken = self.credential.oauth2Token {
          let expiry = Date(timeIntervalSinceNow: 60*60*24*365)
          let credentials = GitHubCredential(token: oauthToken, expiry: expiry)
          credentials.refreshToken = "none" // XXX: Dummy...要検討
          credentials.tokenType = tokenType
          credentials.userID = json["id"] as? Int64
          credentials.name = json["name"] as? String
          credentials.login = json["login"] as? String
          credentials.email = json["email"] as? String
          let userInfo: [String:Any] = [
            OAuthCredentialsKey: credentials
          ]
          NotificationCenter.default.post(name: .OAuthDidVerifyCredentials, object: nil, userInfo: userInfo)
        }
      }
    }
    catch let error {
      handleCredentialsError(error)
    }
  }

  fileprivate func sendRequest(_ request: URLRequest, handler: @escaping GitHubRequestHandler) {
    (URLSession.shared.dataTask(with: request) {
      [unowned self] (data, response, error) in
      if error == nil, let data = data {
        if let httpResponse = response as? HTTPURLResponse {
          let statusCode = httpResponse.statusCode
          if statusCode == 200 {
            handler(data)
          }
          else {
            self.handleErrorResponse(data, statusCode: statusCode)
          }
        }
      }
      else {
        if let error = error {
          self.handleCredentialsError(error)
        }
      }
    }).resume()
  }
}
