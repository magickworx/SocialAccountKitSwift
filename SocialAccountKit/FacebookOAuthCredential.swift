/*****************************************************************************
 *
 * FILE:	FacebookOAuthCredential.swift
 * DESCRIPTION:	SocialAccountKit: OAuth Credentials for Facebook
 * DATE:	Fri, Sep 15 2017
 * UPDATED:	Tue, Jan  5 2021
 * AUTHOR:	Kouichi ABE (WALL) / 阿部康一
 * E-MAIL:	kouichi@MagickWorX.COM
 * URL:		http://www.MagickWorX.COM/
 * CHECKER:     http://quonos.nl/oauthTester/
 * COPYRIGHT:	(c) 2017-2021 阿部康一／Kouichi ABE (WALL), All rights reserved.
 * LICENSE:
 *
 *  Copyright (c) 2017-2021 Kouichi ABE (WALL) <kouichi@MagickWorX.COM>,
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
 *****************************************************************************/

import Foundation

public final class FacebookCredential: OAuthCredential
{
  public var userID: String? = nil
  public var fullName: String? = nil
}

fileprivate typealias FacebookRequestHandler = (Data) -> Void

extension OAuth
{
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

  func obtainFacebookAccessToken(with callbackURL: URL) {
    guard let code = callbackURL.query else { return }
    let urlString = self.configuration.accessTokenURI
                  + "?client_id=\(self.configuration.consumerKey)"
                  + "&client_secret=\(self.configuration.consumerSecret)"
                  + "&redirect_uri=\(self.configuration.callbackURI)"
                  + "&" + code
    if let url = URL(string: urlString) {
      var request = URLRequest(url: url)
      request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
      sendRequest(request, handler: {
        [unowned self] (data) in
        self.acquireFacebookCredentials(with: data)
      })
    }
  }

  private func acquireFacebookCredentials(with data: Data) {
    do {
      if let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String:Any] {
        if let accessToken = json["access_token"] as? String,
           let   tokenType = json["token_type"] as? String,
           let   expiresIn = json["expires_in"] as? TimeInterval {
          let expiry = Date(timeIntervalSinceNow: expiresIn)
          credential.renew(token: accessToken, expiry: expiry, type: tokenType.lowercased())
          verifyFacebookCredential()
        }
      }
    }
    catch let error {
      handleCredentialsError(error)
    }
  }

  private func verifyFacebookCredential() {
    guard let accessToken = credential.oauth2Token else { return }
    /*
     * https://developers.facebook.com/docs/facebook-login/access-tokens/#apptokens
     * GET /oauth/access_token を使う方法で appToken を作成するが良いのかな…
     */
    if let appToken = (configuration.consumerKey + "|" + configuration.consumerSecret).urlEncoded {
      let urlString = self.configuration.verifyTokenURI
                    + "?input_token=" + accessToken
                    + "&access_token=" + appToken
      if let url = URL(string: urlString) {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        sendRequest(request, handler: {
          [unowned self] (data) in
          self.facebookCredentials(with: data)
        })
      }
    }
  }

  private func facebookCredentials(with data: Data) {
    do {
      if let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String:Any], let data = json["data"] as? [String:Any] {
        if let     userID = data["user_id"] as? String,
           let  expiresAt = data["expires_at"] as? TimeInterval,
           let  tokenType = self.credential.tokenType,
           let oauthToken = self.credential.oauth2Token {
          let expiry: Date = Date(timeIntervalSince1970: expiresAt)
          let credentials = FacebookCredential(token: oauthToken, expiry: expiry)
          credentials.refreshToken = "none" // XXX: Dummy...要検討
          credentials.tokenType = tokenType
          credentials.userID = userID
          fetchUserInfo(with: userID, handler: {
            (json: [String:Any]?) in
            if let info = json, let name = info["name"] as? String {
              credentials.fullName = name
            }
            let userInfo: [String:Any] = [
              OAuthCredentialsKey: credentials
            ]
            NotificationCenter.default.post(name: .OAuthDidVerifyCredentials, object: nil, userInfo: userInfo)
          })
        }
      }
    }
    catch let error {
      handleCredentialsError(error)
    }
  }

  private func fetchUserInfo(with userID: String, handler: @escaping (Dictionary<String,Any>?) -> Void) {
    let urlString = "https://graph.facebook.com/me"
    if let url = URL(string: urlString) {
      request(with: "GET", url: url, completion: {
        (data, response, error) in
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 200,
           let data = data, error == nil {
          let json = (try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String:Any]).flatMap { $0 }
          handler(json)
        }
        else {
          handler(nil)
        }
      })
    }
  }

  private func sendRequest(_ request: URLRequest, handler: @escaping FacebookRequestHandler) {
    (URLSession.shared.dataTask(with: request) {
      [weak self] (data, response, error) in
      guard let self = `self` else { return }
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
