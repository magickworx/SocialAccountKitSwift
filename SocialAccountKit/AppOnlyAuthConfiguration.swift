/*****************************************************************************
 *
 * FILE:	AppOnlyAuthConfiguration.swift
 * DESCRIPTION:	SocialAccountKit: OAuth Configuration for App-only of Twitter
 * DATE:	Fri, Oct 20 2017
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

public final class AppOnlyAuthConfiguration: OAuthConfigurationProtocol
{
  public var serviceType: OAuthConfigurationServiceType = .appOnly

  /*
   * POST oauth2/token ? Twitter Developers
   * https://developer.twitter.com/en/docs/basics/authentication/api-reference/token
   */
  public let requestTokenURI: String = "https://api.twitter.com/oauth2/token"

  public let verifyTokenURI: String = "https://api.twitter.com/1.1/application/rate_limit_status.json"
  // XXX: Following URIs are unused.
  public let authorizationURI: String = ""
  public let accessTokenURI: String = ""
  public var callbackURI: String = ""

  /*
   * XXX: This configuration only
   * POST oauth2/invalidate_token ? Twitter Developers
   * https://developer.twitter.com/en/docs/basics/authentication/api-reference/invalidate_token
   */
  public let revokeTokenURI: String = "https://api.twitter.com/oauth2/invalidate_token"

  public var consumerKey: String = ""
  public var consumerSecret: String = ""

  public var isForceLogin: Bool = false

  public var isReady: Bool {
    return (!consumerKey.isEmpty && !consumerSecret.isEmpty)
  }

  public init() {
    try? readConsumerKeyAndSecret()
  }
}

extension AppOnlyAuthConfiguration
{
  // Twitter.plist に ConsumerKey と ConsumerSecret が設定されていたら
  // それらの値を初期値とする
  func readConsumerKeyAndSecret(from plist: String = "Twitter") throws {
    if let url = Bundle.main.url(forResource: plist, withExtension: "plist") {
      do {
        let data = try Data(contentsOf: url)
        let dict = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as! [String:Any]
        if let    key = dict["ConsumerKey"] as? String,
           let secret = dict["ConsumerSecret"] as? String {
          self.consumerKey = key
          self.consumerSecret = secret
        }
      }
      catch let error {
        throw SAKError.OAuthConfigurationError(error)
      }
    }
  }
}
