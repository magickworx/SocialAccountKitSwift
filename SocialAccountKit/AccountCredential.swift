/*****************************************************************************
 *
 * FILE:	AccountCredential.swift
 * DESCRIPTION:	SocialAccountKit: Encapsulates the info to authenticate a user
 * DATE:	Wed, Sep 20 2017
 * UPDATED:	Wed, Sep 27 2017
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

public struct SAKAccountCredential
{
  var oAuthToken: String! = nil
  var tokenSecret: String! = nil

  // Initializes an account credential using OAuth.
  public init(oAuthToken: String, tokenSecret: String) {
    self.oAuthToken = oAuthToken
    self.tokenSecret = tokenSecret
  }

  var oAuth2Token: String! = nil
  var refreshToken: String! = nil
  var expiryDate: Date! = nil

  // Initializes an account credential using OAuth 2.
  public init(oAuth2Token: String, refreshToken: String, expiryDate: Date) {
    self.oAuth2Token = oAuth2Token
    self.refreshToken = refreshToken
    self.expiryDate = expiryDate
  }
}

extension SAKAccountCredential
{
  // This property is only valid for OAuth2 credentials
  public var oauthToken: String! {
    return oAuth2Token
  }
}

// MARK: - Convenience Methods for CoreData (AccountManager)
extension SAKAccountCredential
{
  public var oauth1Info: Dictionary<String,String>? {
    guard let token = oAuthToken, let secret = tokenSecret else {
      return nil
    }
    return [ "oauth_token": token, "oauth_token_secret": secret ]
  }

  public var oauth2Info: Dictionary<String,Any>? {
    guard let token = oAuth2Token, let refresh = refreshToken, let expiry = expiryDate else { return nil }
    return [ "oauth_token": token, "refresh_token": refresh, "expiry_date": expiry ]
  }
}
