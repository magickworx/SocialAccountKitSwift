/*****************************************************************************
 *
 * FILE:	Error.swift
 * DESCRIPTION:	SocialAccountKit: Account Error
 * DATE:	Mon, Sep 25 2017
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

public let SAKErrorDomain = "SAKErrorDomain"

public enum SAKError: LocalizedError
{
  case Unknown

  case AccountMissingRequiredProperty
  case AccountAuthenticationFailed
  case AccountTypeInvalid
  case AccountAlreadyExists
  case AccountNotFound

  case PermissionDenied
  case AccessInfoInvalid
  case ClientPermissionDenied
  case AccessDeniedByProtectionPolicy

  case CredentialNotFound
  case FetchCredentialFailed
  case StoreCredentialFailed
  case RemoveCredentialFailed

  case UpdatingNonexistentAccount
  case InvalidClientBundleID
  case DeniedByPlugin
  case CoreDataSaveFailed
  case CoreDataFetchError(Error)
  case FailedSerializingAccountInfo

  case CredentialItemNotFound
  case CredentialItemNotExpired

  case UnconstructedURL(String)

  case FailedServerResponse(Int, Data)
  case SendRequestError(Error)

  case OAuthConfigurationError(Error)
}

extension SAKError: CustomStringConvertible
{
  public var domain: String {
    return SAKErrorDomain
  }

  public var description: String {
    switch self {
      case .Unknown:
        return "Unexpected and unknown error was happened."

      case .AccountMissingRequiredProperty:
        return "Account wasn't saved because it is missing a required property."
      case .AccountAuthenticationFailed:
        return "Account wasn't saved because authentication of the supplied credential failed."
      case .AccountTypeInvalid:
        return "Account wasn't saved because the account type is invalid."
      case .AccountAlreadyExists:
        return "Account wasn't added because it already exists."
      case .AccountNotFound:
        return "Account wasn't deleted because it could not be found."

      case .PermissionDenied:
        return "The operation didn't complete because the user denied permission."
      case .AccessInfoInvalid:
        return "The client's access info dictionary has incorrect or missing values."
      case .ClientPermissionDenied:
        return "Your client does not have access to the requested data."
      case .AccessDeniedByProtectionPolicy:
        return "Due to the current protection policy in effect, we couldn't fetch a credential"
      case .CredentialNotFound:
        return "Yo, I tried to find your credential, but it must have run off!"
      case .FetchCredentialFailed:
        return "Something bad happened on the way to the keychain"
      case .StoreCredentialFailed:
        return "Unable to store credential"
      case .RemoveCredentialFailed:
        return "Unable to remove credential"
      case .UpdatingNonexistentAccount:
        return "Account save failed because the account being updated has been removed."
      case .InvalidClientBundleID:
        return "The client making the request does not have a valid bundle ID."
      case .DeniedByPlugin:
        return "A plugin prevented the expected action to occur."
      case .CoreDataSaveFailed:
        return "Something broke below us when we tried to the CoreData store."
      case .CoreDataFetchError(let error):
        return "Fetch failure: \(error.localizedDescription)"
      case .FailedSerializingAccountInfo:
        return ""

      case .CredentialItemNotFound:
        return "Credential item wasn't saved because it could not be found."
      case .CredentialItemNotExpired:
        return "Credential item wasn't removed because it has not yet expired."

      case .UnconstructedURL(let urlString):
        return "Unconstructed URL: \(urlString)"

      case .FailedServerResponse(let statusCode, let data):
        var text: String = ""
        if let responseString = String(data: data, encoding: .utf8) {
          text = "Status code: \(statusCode)\n" + responseString
        }
        do {
          if let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String:Any] {
            if let errors = json["errors"] as? [[String:Any]],
               let error = errors.first {
              if let message = error["message"] as? String,
                 let code = error["code"] as? Int {
                text = "Status code: \(statusCode)\n"
                     + "Error code: \(code)\n"
                     + "\(message)"
              }
            }
          }
        }
        catch {
        }
        return text

      case .SendRequestError(let error):
        return "Request had an error.\n\(error.localizedDescription)"

      case .OAuthConfigurationError(let error):
        return "Failed to read configuration parameters.\n\(error.localizedDescription)"
    }
  }

  public var errorDescription: String? {
    return self.description
  }
}
