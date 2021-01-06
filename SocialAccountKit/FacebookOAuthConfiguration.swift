/*****************************************************************************
 *
 * FILE:	FacebookOAuthConfiguration.swift
 * DESCRIPTION:	SocialAccountKit: OAuth Configuration for Facebook
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

public class FacebookOAuthConfiguration: OAuthConfigurationProtocol
{
  public var serviceType: OAuthConfigurationServiceType = .facebook

  public let requestTokenURI: String = "https://m.facebook.com/v9.0/dialog/oauth"
  public let authorizationURI: String = "https://m.facebook.com/v9.0/dialog/oauth"
  public let accessTokenURI: String = "https://graph.facebook.com/v9.0/oauth/access_token"
  public let verifyTokenURI: String = "https://graph.facebook.com/v9.0/debug_token"

  public var callbackURI: String = "https://www.facebook.com/connect/login_success.html"

  public var consumerKey: String = ""
  public var consumerSecret: String = ""

  public var permissions: [String] = []

  public var isReady: Bool {
    return (!consumerKey.isEmpty && !consumerSecret.isEmpty)
  }

  public init() {
    try? readConsumerKeyAndSecret()
  }
}

extension FacebookOAuthConfiguration
{
  // Facebook.plist に AppID と AppSecret が設定されていたら
  // それらの値を初期値とする
  func readConsumerKeyAndSecret(from plist: String = "Facebook") throws {
    if let url = Bundle.main.url(forResource: plist, withExtension: "plist") {
      do {
        let data = try Data(contentsOf: url)
        let dict = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as! [String:Any]
        if let    key = dict["AppID"] as? String,
           let secret = dict["AppSecret"] as? String {
          self.consumerKey = key
          self.consumerSecret = secret
          if let scope = dict["Permissions"] as? Array<String> {
            self.permissions = scope
          }
          if let cbURI = dict["CallbackURI"] as? String {
            self.callbackURI = cbURI
          }
        }
      }
      catch let error {
        throw SAKError.OAuthConfigurationError(error)
      }
    }
  }
}
