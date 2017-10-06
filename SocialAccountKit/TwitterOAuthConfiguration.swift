/*****************************************************************************
 *
 * FILE:	TwitterOAuthConfiguration.swift
 * DESCRIPTION:	SocialAccountKit: OAuth Configuration for Twitter
 * DATE:	Fri, Sep 15 2017
 * UPDATED:	Fri, Oct  6 2017
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

public struct TwitterOAuthConfiguration: OAuthConfigurationProtocol
{
  public var serviceType: OAuthConfigurationServiceType = .twitter

  public let requestTokenURI = "https://api.twitter.com/oauth/request_token"
  public let authorizationURI = "https://api.twitter.com/oauth/authorize"
  public let accessTokenURI = "https://api.twitter.com/oauth/access_token"
  public let verifyTokenURI = "https://api.twitter.com/1.1/account/verify_credentials.json"

  // "oob" is out-of-band (See Section 2.1 Temporary Credentials)
  public var callbackURI = "swift-oauth://callback"

  public var consumerKey = ""
  public var consumerSecret = ""

  public var isForceLogin: Bool = true

  public var isReady: Bool {
    return (consumerKey != "" && consumerSecret != "")
  }

  public init() {
    readConsumerKeyAndSecret()
  }
}

extension TwitterOAuthConfiguration
{
  // Twitter.plist に ConsumerKey と ConsumerSecret が設定されていたら
  // それらの値を初期値とする
  mutating func readConsumerKeyAndSecret(from plist: String = "Twitter") {
    if let url = Bundle.main.url(forResource: plist, withExtension: "plist") {
      do {
        let data = try Data(contentsOf: url)
        let dict = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as! [String:Any]
        if let key = dict["ConsumerKey"] as? String,
           let secret = dict["ConsumerSecret"] as? String {
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
