/*****************************************************************************
 *
 * FILE:	AppOnlyAuthCredential.swift
 * DESCRIPTION:	SocialAccountKit: OAuth Credentails for App-only of Twitter
 * DATE:	Fri, Oct 20 2017
 * UPDATED:	Tue, Oct 24 2017
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

public class AppOnlyCredential: OAuthCredential
{
  public internal(set) var resources: [String:Any]? = nil

  public var appName: String {
    guard let name = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String else {
      return "Twitter (AppOnly)"
    }
    return name
  }
}

extension OAuth
{
  func appOnlyAuthHeaderField() -> String {
    if let tokenType = credential.tokenType {
      guard let oauthToken = credential.oauth2Token else { return "" }
      if tokenType == "bearer" {
        return "Bearer \(oauthToken)"
      }
    }
    else {
      if let key = configuration.consumerKey.urlEncoded,
         let secret = configuration.consumerSecret.urlEncoded {
        let string = key + ":" + secret
        if let data = string.data(using: .utf8) {
          let base64 = data.base64EncodedString(options: [])
          return "Basic \(base64)"
        }
      }
    }
    return ""
  }

  func requestAppOnlyCredentials(handler: @escaping OAuthAuthenticationHandler) {
    let urlString = configuration.requestTokenURI
    let parameters = [
      "grant_type" : "client_credentials"
    ]
    if let requestURL = URL(string: urlString) {
      request(with: "POST", url: requestURL, parameters: parameters, completion: {
        [unowned self] (data, response, error) in
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 200 {
          if let data = data {
            do {
              if let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String:Any] {
                if let accessToken = json["access_token"] as? String,
                   let   tokenType = json["token_type"] as? String {
                  let expiresIn: TimeInterval = 60 * 60 * 24 * 365
                  let expiry = Date(timeIntervalSinceNow: expiresIn)
                  self.credential.renew(token: accessToken, expiry: expiry, type: tokenType.lowercased())
                  handler(nil, nil)
                }
              }
            }
            catch let error {
              handler(nil, error)
            }
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

  func verifyAppOnlyCredentials() {
    let urlString = self.configuration.verifyTokenURI
    let parameters = [
      "resources" : "users,search,statuses"
    ]
    if let requestURL = URL(string: urlString) {
      request(with: "GET", url: requestURL, parameters: parameters, completion: {
        [unowned self] (data, response, error) in
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 200 {
          if let data = data {
            self.appOnlyCredentials(with: data)
          }
        }
        if let error = error {
          self.handleCredentialsError(error)
        }
      })
    }
  }

  func appOnlyCredentials(with data: Data) {
    do {
      if let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String:Any] {
        if let context = json["rate_limit_context"] as? [String:String],
           let consumerKey = context["application"],
           let oauthToken = self.credential.oauth2Token,
           let expiryDate = self.credential.expiryDate,
           let tokenType = self.credential.tokenType {
          let credentials = AppOnlyCredential(token: oauthToken, expiry: expiryDate, type: tokenType)
          credentials.resources = json["resources"] as? [String:Any]
          credentials.refreshToken = "none" // XXX: Dummy...要検討
          if consumerKey == configuration.consumerKey {
            let userInfo: [String:Any] = [
              OAuthCredentialsKey: credentials
            ]
            NotificationCenter.default.post(name: .OAuthDidVerifyCredentials, object: nil, userInfo: userInfo)
          }
        }
      }
    }
    catch let error {
      handleCredentialsError(error)
    }
  }
}
