/*****************************************************************************
 *
 * FILE:	GitHubOAuthConfiguration.swift
 * DESCRIPTION:	SocialAccountKit: OAuth Configuration for GitHub
 * DATE:	Wed, Oct 25 2017
 * UPDATED:	Wed, Oct 25 2017
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

public struct GitHubOAuthConfiguration: OAuthConfigurationProtocol
{
  public var serviceType: OAuthConfigurationServiceType = .github

  public let requestTokenURI = "Unused in OAuth2"
  public let authorizationURI = "https://github.com/login/oauth/authorize"
  public let accessTokenURI = "https://github.com/login/oauth/access_token"
  public let verifyTokenURI = "https://api.github.com/user"

  public var callbackURI = "swift-oauth://callback"

  public var consumerKey = ""
  public var consumerSecret = ""

  /*
   * About scopes for OAuth Apps
   * https://developer.github.com/apps/building-integrations/setting-up-and-registering-oauth-apps/about-scopes-for-oauth-apps/
   */
  public var scopes: [String] = []

  public var isReady: Bool {
    return (consumerKey != "" && consumerSecret != "")
  }

  public init() {
    try? readConsumerKeyAndSecret()
  }
}

extension GitHubOAuthConfiguration
{
  // GitHub.plist に ClientID と ClientSecret が設定されていたら
  // それらの値を初期値とする
  mutating func readConsumerKeyAndSecret(from plist: String = "GitHub") throws {
    if let url = Bundle.main.url(forResource: plist, withExtension: "plist") {
      do {
        let data = try Data(contentsOf: url)
        let dict = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as! [String:Any]
        if let    key = dict["ClientID"] as? String,
           let secret = dict["ClientSecret"] as? String {
          consumerKey = key
          consumerSecret = secret
          if let scope = dict["Scopes"] as? Array<String> {
            scopes = scope
          }
          if let cbURI = dict["CallbackURI"] as? String {
            callbackURI = cbURI
          }
        }
      }
      catch let error {
        throw SAKError.OAuthConfigurationError(error)
      }
    }
  }
}
