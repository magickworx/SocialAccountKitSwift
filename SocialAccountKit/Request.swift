/*****************************************************************************
 *
 * FILE:	Request.swift
 * DESCRIPTION:	SocialAccountKit: Request Wrapper
 * DATE:	Thu, Sep 21 2017
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
 * $Id: AppDelegate.m,v 1.6 2017/04/12 09:59:00 kouichi Exp $
 *
 *****************************************************************************/

import Foundation

public enum SAKRequestMethod: String
{
  case GET    = "GET"
  case POST   = "POST"
  case DELETE = "DELETE"
  case PUT    = "PUT"
}

public typealias SAKRequestHandler = OAuthRequestHandler

public struct SAKRequest
{
  public internal(set) var account: SAKAccount? = nil
  public internal(set) var method: SAKRequestMethod = .GET
  public internal(set) var URL: URL? = nil
  public internal(set) var parameters: [String:Any] = [:]

  fileprivate var oauth: OAuth? = nil

  public init(forAccount account: SAKAccount, requestMethod method: SAKRequestMethod, url: URL, parameters: [String:Any] = [:]) throws {
    self.account = account
    self.method = method
    self.URL = url
    self.parameters = parameters

    var configuration: OAuthConfigurationProtocol
    var credential: OAuthCredential
    switch account.accountType.identifier {
      case .twitter:
        configuration = TwitterOAuthConfiguration()
        guard let ac = account.credential,
              let token = ac.oAuthToken, let secret = ac.tokenSecret else {
          throw SAKError.CredentialItemNotFound
        }
        credential = TwitterCredential(token: token, secret: secret)
      case .facebook:
        configuration = FacebookOAuthConfiguration()
        guard let ac = account.credential,
              let token = ac.oAuth2Token, let expiry = ac.expiryDate else {
          throw SAKError.CredentialItemNotFound
        }
        credential = FacebookCredential(token: token, expiry: expiry)
      default:
        throw SAKError.AccountTypeInvalid
    }
    oauth = OAuth(configuration, credential: credential)
  }
}

extension SAKRequest
{
  public func perform(handler: @escaping SAKRequestHandler) {
    if let oauth = self.oauth, let url = self.URL {
      oauth.request(with: method.rawValue, url: url, parameters: parameters, completion: handler)
    }
  }
}
