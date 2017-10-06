/*****************************************************************************
 *
 * FILE:	AccountStore.swift
 * DESCRIPTION:	SocialAccountKit: Manipulating and storing accounts.
 * DATE:	Wed, Sep 20 2017
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
import CoreData

public enum SAKAccountCredentialRenewResult
{
  case renewed
  case rejected
  case failed
}

public typealias SAKAccountStoreSaveCompletionHandler = (_ success: Bool, _ error: Error?) -> Void
public typealias SAKAccountStoreRemoveCompletionHandler = (_ success: Bool, _ error: Error?) -> Void
public typealias SAKAccountStoreRequestAccessCompletionHandler = (_ granted: Bool, _ error: Error?) -> Void
public typealias SAKAccountStoreCredentialRenewalHandler = (_ result: SAKAccountCredentialRenewResult, _ error: Error?) -> Void

typealias AccountStoreType = [String:Dictionary<String,String>]

fileprivate let entityName = "Account"

public final class SAKAccountStore
{
  public static let shared = SAKAccountStore()

  public internal(set) var accounts = [SAKAccount]()

  init() {
    accounts = readAllAccounts()
  }

  deinit {
    // Saves changes in the application's managed object context
    // before the application terminates.
    self.saveContext()
  }

  // MARK: - Core Data stack
  lazy var persistentContainer: NSPersistentContainer = {
    /*
     * The persistent container for the application. This implementation
     * creates and returns a container, having loaded the store for the
     * application to it. This property is optional since there are legitimate
     * error conditions that could cause the creation of the store to fail.
     */
    let container = NSPersistentContainer(name: entityName, managedObjectModel: self.managedObjectModel)
    container.loadPersistentStores(completionHandler: {
      (storeDescription, error) in
      if let error = error as NSError? {
        /*
         * Replace this implementation with code to handle the error appropriately.
         * fatalError() causes the application to generate a crash log
         * and terminate. You should not use this function in a shipping
         * application, although it may be useful during development.
         */

        /*
         * Typical reasons for an error here include:
         * - The parent directory does not exist, cannot be created,
         *   or disallows writing.
         * - The persistent store is not accessible, due to permissions
         *   or data protection when the device is locked.
         * - The device is out of space.
         * - The store could not be migrated to the current model version.
         * Check the error message to determine what the actual problem was.
         */
        fatalError("Unresolved error \(error), \(error.userInfo)")
      }
    })
    return container
  }()

  // MARK: - Core Data Saving support
  func saveContext () {
    let context = persistentContainer.viewContext
    if context.hasChanges {
      do {
        try context.save()
      }
      catch {
        /*
         * Replace this implementation with code to handle the error appropriately.
         * fatalError() causes the application to generate a crash log
         * and terminate. You should not use this function in a shipping
         * application, although it may be useful during development.
         */
        let nserror = error as NSError
        fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
      }
    }
  }

  lazy var managedObjectModel: NSManagedObjectModel = {
    let model = NSManagedObjectModel()

    // Create the entity
    let entity = NSEntityDescription()
    entity.name = entityName
    entity.managedObjectClassName = entityName
    /*
    if #available(iOS 11.0, *) {
      entity.indexes = Array<NSFetchIndexDescription>
    }
    */

    // Create the attributes
    var properties = Array<NSAttributeDescription>()

    let makeDescription = {
      (name: String, type: NSAttributeType, opt: Bool, idx: Bool) -> Void in
      let desc = NSAttributeDescription()
      desc.name = name
      desc.attributeType = type
      desc.isOptional = opt
      if #available(iOS 11.0, *) {
        // Use NSEntityDescription.indexes
      }
      else {
        desc.isIndexed = idx
      }
      properties.append(desc)
    }
    makeDescription("identifier", .stringAttributeType,     false, true)
    makeDescription("service",    .integer32AttributeType,  false, false)
    makeDescription("username",   .stringAttributeType,     true,  true)
    makeDescription("oauth1",     .binaryDataAttributeType, true,  false)
    makeDescription("oauth2",     .binaryDataAttributeType, true,  false)

    // Add attributes to entity
    entity.properties = properties

    // Add entity to model
    model.entities = [entity]

    return model
  }()
}

extension SAKAccountStore
{
  func createAccount(_ account: SAKAccount) {
    let context = persistentContainer.viewContext
    let entity = Account(context: context)
    entity.identifier = account.identifier
    entity.serviceType = account.accountType.identifier
    if let username = account.username {
      entity.username = username
    }
    if let credential = account.credential {
      if let oauth1 = credential.oauth1Info {
        entity.oauthCredential = oauth1
      }
      if let oauth2 = credential.oauth2Info {
        entity.oauth2Credential = oauth2
      }
    }
    saveContext()
  }

  fileprivate func account(with entity: Account) -> SAKAccount {
    let type = SAKAccountType(entity.serviceType)
    let acct = SAKAccount(accountType: type, identifier: entity.identifier)
    if let username = entity.username {
      acct.username = username
    }
    if let  oauth = entity.oauthCredential,
       let  token = oauth["oauth_token"],
       let secret = oauth["oauth_token_secret"] {
      acct.credential = SAKAccountCredential(oAuthToken: token, tokenSecret: secret)
    }
    if let   oauth = entity.oauth2Credential,
       let   token = oauth["oauth_token"] as? String,
       let refresh = oauth["refresh_token"] as? String,
       let  expiry = oauth["expiry_date"] as? Date,
       let    type = oauth["token_type"] as? String {
      acct.credential = SAKAccountCredential(oAuth2Token: token, refreshToken: refresh, expiryDate: expiry, tokenType: type)
    }
    return acct
  }

  func readAllAccounts() -> [SAKAccount] {
    var accounts = [SAKAccount]()
    let context = persistentContainer.viewContext
    let fetchRequest: NSFetchRequest = Account.fetchRequest()
    do {
      let fetchResults = try context.fetch(fetchRequest)
      for entity in fetchResults {
        accounts.append(account(with: entity))
      }
    }
    catch let error {
      dump(error)
    }
    return accounts
  }

  func readAccount(with username: String) throws -> SAKAccount? {
    let context = persistentContainer.viewContext
    let fetchRequest: NSFetchRequest = Account.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "username = %@", username)
    do {
      let fetchResults = try context.fetch(fetchRequest)
      if let entity = fetchResults.first {
        return account(with: entity)
      }
    }
    catch let error {
      throw error
    }
    return nil
  }

  func deleteAccount(_ account: SAKAccount) throws {
    let context = persistentContainer.viewContext
    let identifier = account.identifier
    let fetchRequest: NSFetchRequest = Account.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "identifier = %@", identifier)
    do {
      let fetchResults = try context.fetch(fetchRequest)
      if let account = fetchResults.first {
        context.delete(account)
        saveContext()
      }
    }
    catch let error {
      throw error
    }
  }
}

extension SAKAccountStore
{
  public func account(withIdentifier identifier: String) -> SAKAccount? {
    return accounts.first(where: { $0.identifier == identifier })
  }

  public func accounts(with type: SAKAccountType) -> [SAKAccount]? {
    return accounts.filter({ $0.accountType.identifier == type.identifier })
  }
}

extension SAKAccountStore
{
  public func accountType(withAccountTypeIdentifier typeIdentifier: SAKServiceTypeIdentifier) -> SAKAccountType {
    return SAKAccountType(typeIdentifier)
  }
}

extension SAKAccountStore
{
  public func saveAccount(_ account: SAKAccount, withCompletionHandler handler: @escaping SAKAccountStoreSaveCompletionHandler) {
    let identifier = account.identifier
    if accounts.contains(where: { $0.identifier == identifier }) {
      handler(false, SAKError.AccountAlreadyExists)
    }
    else {
      createAccount(account)
      accounts.append(account)
      handler(true, nil)
    }
  }

  public func removeAccount(_ account: SAKAccount, withCompletionHandler handler: @escaping SAKAccountStoreRemoveCompletionHandler) {
    let identifier = account.identifier
    if let index = accounts.index(where: { $0.identifier == identifier }) {
      do {
        try deleteAccount(account)
        accounts.remove(at: index)
        handler(true, nil)
      }
      catch let error {
        handler(false, error)
      }
    }
    else {
      handler(false, SAKError.AccountNotFound)
    }
  }

  public func renewCredential(for account: SAKAccount, completion: @escaping SAKAccountStoreCredentialRenewalHandler) {
  }

  public func requestAccessToAccounts(with accountType: SAKAccountType, options: Dictionary<String,String>? = nil, completion: @escaping SAKAccountStoreRequestAccessCompletionHandler) {
    switch accountType.identifier {
      case .twitter, .facebook:
        completion(true, nil)
      default:
        completion(false, SAKError.AccountTypeInvalid)
    }
  }
}


// MARK: - Account Entity for CoreData
@objc(Account)
fileprivate class Account: NSManagedObject
{
}

extension Account
{
  @nonobjc public class func fetchRequest() -> NSFetchRequest<Account> {
    return NSFetchRequest<Account>(entityName: entityName)
  }

  @NSManaged var identifier: String
  @NSManaged var service: Int32
  @NSManaged var username: String?
  @NSManaged var oauth1: Data?
  @NSManaged var oauth2: Data?

  /*
   * core data - Swift: Storing states in CoreData with enums - Stack Overflow
   * https://stackoverflow.com/questions/26900302/swift-storing-states-in-coredata-with-enums
   */
  var serviceType: SAKServiceTypeIdentifier {
    set {
      self.service = newValue.rawValue
    }
    get {
      return SAKServiceTypeIdentifier(rawValue: self.service) ?? .twitter
    }
  }

  var oauthCredential: Dictionary<String,String>? {
    set {
      if let dict = newValue {
        self.oauth1 = NSKeyedArchiver.archivedData(withRootObject: dict)
      }
      else {
        self.oauth1 = nil
      }
    }
    get {
      guard let oauth = self.oauth1 else { return nil }
      return NSKeyedUnarchiver.unarchiveObject(with: oauth) as? Dictionary<String,String>
    }
  }

  var oauth2Credential: Dictionary<String,Any>? {
    set {
      if let dict = newValue {
        self.oauth2 = NSKeyedArchiver.archivedData(withRootObject: dict)
      }
      else {
        self.oauth2 = nil
      }
    }
    get {
      guard let oauth = self.oauth2 else { return nil }
      return NSKeyedUnarchiver.unarchiveObject(with: oauth) as? Dictionary<String,Any>
    }
  }
}
