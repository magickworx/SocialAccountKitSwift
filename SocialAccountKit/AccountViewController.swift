/*****************************************************************************
 *
 * FILE:	AccountViewController.swift
 * DESCRIPTION:	SocialAccountKit: View Controller to Manage Accounts
 * DATE:	Wed, Sep 27 2017
 * UPDATED:	Fri, Sep 29 2017
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
import UIKit

public class SAKAccountViewController: UINavigationController
{
  let rvc = AccountViewController()

  required public init(coder aDecoder: NSCoder) {
    fatalError("NSCoding not supported")
  }

  override init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: Bundle!) {
    super.init(nibName: nil, bundle: nil)
  }

  public init() {
    super.init(rootViewController: rvc)
  }
}

class AccountViewController: UIViewController
{
  let accountStore = SAKAccountStore.shared

  var configuration = TwitterOAuthConfiguration()
  var credential: TwitterCredential?
  var oauth: OAuth? = nil

  var tableView: UITableView = UITableView()
  var tableData: [SAKAccount] = []

  required init(coder aDecoder: NSCoder) {
    fatalError("NSCoding not supported")
  }

  override init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: Bundle!) {
    super.init(nibName: nil, bundle: nil)
  }

  public convenience init() {
    self.init(nibName: nil, bundle: nil)
    self.title = "Account Manager"

    configuration.consumerKey = "lONGPpCiaKmpjdqt4aaIwj7Xv"
    configuration.consumerSecret = "V4aWQmxJVCnv3Bd1OUt8KVA2vnMXnjSKczrUotWiwreZQYTBds"
    oauth = OAuth(configuration)
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  override func loadView() {
    super.loadView()

    self.edgesForExtendedLayout = []
    self.extendedLayoutIncludesOpaqueBars = true
    self.automaticallyAdjustsScrollViewInsets = false

    self.view.backgroundColor = .white
    self.view.autoresizesSubviews = true
    self.view.autoresizingMask	= [ .flexibleWidth, .flexibleHeight ]

    tableView.frame = self.view.bounds
    tableView.delegate = self
    tableView.dataSource = self
    tableView.rowHeight = UITableViewAutomaticDimension
    tableView.estimatedRowHeight = 48
    tableView.allowsSelectionDuringEditing = true
    tableView.autoresizingMask = [ .flexibleWidth, .flexibleHeight ]
    self.view.addSubview(tableView)
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    let closeItem = UIBarButtonItem(barButtonSystemItem: .stop,
                                    target: self,
                                    action: #selector(closeAction))
    self.navigationItem.leftBarButtonItem = closeItem
    self.navigationItem.rightBarButtonItem = self.editButtonItem
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    loadData()

    addNotification()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    removeNotification()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
  }
}

extension AccountViewController
{
  func loadData() {
    DispatchQueue.main.async { [unowned self] in
      self.tableData = self.accountStore.readAllAccounts()
      self.tableView.reloadData()
    }
  }

  func closeAction(_ sender: UIBarButtonItem) {
    dismiss(animated: true, completion: nil)
  }

  override func setEditing(_ editing: Bool, animated: Bool) {
    super.setEditing(editing, animated: animated)

    self.navigationItem.leftBarButtonItem?.isEnabled = !editing

    let section = 0
    let row = tableData.count
    let indexPath = IndexPath(row: row, section: section)

    tableView.beginUpdates()
    tableView.setEditing(editing, animated: animated)
    if editing { // Show the placeholder row
      tableView.insertRows(at: [indexPath], with: .automatic)
    }
    else { // Hide the placeholder row
      tableView.deleteRows(at: [indexPath], with: .fade)
    }
    tableView.endUpdates()

    if editing && row > 0 {
      tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }
  }
}

extension AccountViewController: UITableViewDataSource
{
  func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return tableData.count + (tableView.isEditing ? 1 : 0)
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let reuseId = "UITableViewCellReusableIdentifier"
    let cell: UITableViewCell = {
      guard let cell = tableView.dequeueReusableCell(withIdentifier: reuseId) else {
        return UITableViewCell(style: .value1, reuseIdentifier: reuseId)
      }
      return cell
    }()
    cell.selectionStyle = .none
    cell.textLabel?.font = UIFont.systemFont(ofSize: 14.0)

    let row = indexPath.row
    if row == tableData.count {
      cell.editingAccessoryType = .disclosureIndicator
      cell.textLabel?.text = "Add New Account"
    }
    else {
      let account = tableData[row]
      cell.accessoryType = .none
      cell.editingAccessoryType = .none
      cell.textLabel?.text = account.username
      cell.detailTextLabel?.text = account.accountType.description
    }

    return cell
  }

  func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return "Accounts"
  }
}

extension AccountViewController: UITableViewDelegate
{
  func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
    let row = indexPath.row
    if row == tableData.count {
      return .insert
    }
    return .delete
  }

  func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return tableView.isEditing
  }

  func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      let row = indexPath.row
      let account = tableData[row]
      accountStore.removeAccount(account, withCompletionHandler: {
        [unowned self] (success, error) in
        self.tableData.remove(at: row)
        self.tableView.beginUpdates()
        self.tableView.deleteRows(at: [indexPath], with: .fade)
        self.tableView.endUpdates()
      })
    }
    else if editingStyle == .insert {
      createNewAccount()
    }
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)

    if tableView.isEditing && indexPath.row == tableData.count {
      createNewAccount()
    }
    else {
      dump(tableData[indexPath.row])
    }
  }
}

extension AccountViewController
{
  func addNotification() {
    let center = NotificationCenter.default
    center.addObserver(self,
                       selector: #selector(verfiyCredentials),
                       name: .OAuthDidVerifyCredentials,
                       object: nil)
  }

  func removeNotification() {
    let center = NotificationCenter.default
    center.removeObserver(self,
                          name: .OAuthDidVerifyCredentials,
                          object: nil)
  }

  func verfiyCredentials(_ notification: Notification) {
    guard let userInfo = notification.userInfo else { return }
    if let credentials = userInfo[OAuthCredentialsKey] as? TwitterCredential {
      saveCredentials(credentials)
    }
  }

  func saveCredentials(_ credentials: TwitterCredential) {
    if let name = credentials.screenName,
       let token = credentials.oauthToken,
       let secret = credentials.oauthTokenSecret {
      let accountType = SAKAccountType(with: .twitter)
      let account = SAKAccount(accountType: accountType)
      account.username = name
      account.credential = SAKAccountCredential(oAuthToken: token, tokenSecret: secret)
      accountStore.saveAccount(account, withCompletionHandler: {
        (success, error) in
        guard success, error == nil else { return }
        DispatchQueue.main.async { [unowned self] in
          self.tableData.append(account)
          let section = 0
          let row = self.tableData.count - 1
          let indexPath = IndexPath(row: row, section: section)
          self.tableView.beginUpdates()
          self.tableView.insertRows(at: [indexPath], with: .automatic)
          self.tableView.endUpdates()
          self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
        }
      })
    }
  }

  func createNewAccount() {
    guard let oauth = self.oauth else { return }
    oauth.isForceLogin = true
    oauth.requestCredentials(handler: {
      (url, error) in
      if let authenticateURL = url, error == nil {
        DispatchQueue.main.async { [unowned self] in
          autoreleasepool {
            let viewController = SAKSignInViewController(with: authenticateURL)
            self.present(viewController, animated: true, completion: nil)
          }
        }
      }
    })
  }
}
