/*****************************************************************************
 *
 * FILE:	AccountType.swift
 * DESCRIPTION:	SocialAccountKit: Encapsulates info about particular type.
 * DATE:	Wed, Sep 20 2017
 * UPDATED:	Sun, May 19 2019
 * AUTHOR:	Kouichi ABE (WALL) / 阿部康一
 * E-MAIL:	kouichi@MagickWorX.COM
 * URL:		http://www.MagickWorX.COM/
 * CHECKER:     http://quonos.nl/oauthTester/
 * COPYRIGHT:	(c) 2017-2019 阿部康一／Kouichi ABE (WALL), All rights reserved.
 * LICENSE:
 *
 *  Copyright (c) 2017-2019 Kouichi ABE (WALL) <kouichi@MagickWorX.COM>,
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

public enum SAKServiceTypeIdentifier: Int32
{
  case twitter
  case facebook
  case github
  case appOnly // for application-only authentication in Twitter
}

extension SAKServiceTypeIdentifier: CustomStringConvertible
{
  public var description: String {
    switch self {
      case .twitter:  return "Twitter"
      case .facebook: return "Facebook"
      case .github:   return "GitHub"
      case .appOnly:  return "Twitter (AppOnly)"
    }
  }
}

public struct SAKAccountType
{
  public internal(set) var identifier: SAKServiceTypeIdentifier

  public init(_ typeIdentifier: SAKServiceTypeIdentifier) {
    self.identifier = typeIdentifier
  }
}

extension SAKAccountType
{
  public var accessGranted: Bool {
    switch identifier {
      case .twitter, .facebook, .appOnly:
        return true
      default:
        return false
    }
  }
}

extension SAKAccountType
{
  public func with(_ block: @escaping (SAKServiceTypeIdentifier) -> Void) {
    block(identifier)
  }
}

extension SAKAccountType: CustomStringConvertible
{
  public var description: String {
    return identifier.description
  }

  public var serviceName: String {
    switch identifier {
      case .twitter:  return "Twitter"
      case .facebook: return "Facebook"
      case .github:   return "GitHub"
      case .appOnly:  return "Twitter"
    }
  }
}
