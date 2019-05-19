/*****************************************************************************
 *
 * FILE:	TwitterOAuthCredential.swift
 * DESCRIPTION:	SocialAccountKit: OAuth Credentails for Twitter
 * DATE:	Fri, Sep 15 2017
 * UPDATED:	Sat, Oct  7 2017
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
 *****************************************************************************/

import Foundation

public class TwitterCredential: OAuthCredential
{
  public var userID: String? = nil
  public var screenName: String? = nil
}

extension OAuth
{
  func verifyTwitterCredentials() {
    let urlString = self.configuration.verifyTokenURI
    let parameters = [
      "include_entities" : "false",
      "skip_status" : "true",
      "include_email" : "true"
    ]
    if let requestURL = URL(string: urlString) {
      request(with: "GET", url: requestURL, parameters: parameters, completion: {
        [unowned self] (data, response, error) in
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 200 {
          if let data = data {
            self.twitterCredentials(with: data)
          }
        }
        if let error = error {
          self.handleCredentialsError(error)
        }
      })
    }
  }

  func twitterCredentials(with data: Data) {
    do {
      if let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String:Any] {
        if let screenName = json["screen_name"] as? String,
           let userIdStr = json["id_str"] as? String,
           let oauthToken = self.credential.oauthToken,
           let tokenSecret = self.credential.oauthTokenSecret {
          let credentials = TwitterCredential(token: oauthToken, secret: tokenSecret)
          credentials.screenName = screenName
          credentials.userID = userIdStr
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
}
