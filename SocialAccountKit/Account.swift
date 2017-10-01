/*****************************************************************************
 *
 * FILE:	Account.swift
 * DESCRIPTION:	SocialAccountKit: Encapsulates the info about a user
 * DATE:	Wed, Sep 20 2017
 * UPDATED:	Sun, Sep 24 2017
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

public class SAKAccount
{
  public internal(set) var accountType: SAKAccountType
  public internal(set) var identifier: String

  public var username: String? = nil
  public var credential: SAKAccountCredential? = nil

  init(accountType type: SAKAccountType, identifier: String) {
    self.accountType = type
    self.identifier = identifier
  }

  public convenience init(accountType type: SAKAccountType) {
    self.init(accountType: type, identifier: UUID().uuidString)
  }
}

extension SAKAccount: CustomStringConvertible
{
  public var description: String {
    var text: String = "[\(accountType.description)]"
    switch accountType.identifier {
      case .twitter:
        if let screenName = self.username {
          text += "@" + screenName
        }
      default:
        break
    }
    return text
  }

  public var accountDescription: String {
    switch accountType.identifier {
      case .twitter:
        if let screenName = self.username {
          return "@" + screenName
        }
      default:
        break
    }
    return accountType.description
  }

  public var userFullName: String {
    switch accountType.identifier {
      case .facebook:
        break
      default:
        break
    }
    return "..."
  }
}
