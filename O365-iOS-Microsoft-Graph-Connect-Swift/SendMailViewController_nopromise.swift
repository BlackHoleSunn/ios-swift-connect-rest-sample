/*
* Copyright (c) Microsoft. All rights reserved. Licensed under the MIT license.
* See LICENSE in the project root for license information.
*/

import UIKit
import Foundation


/**
 SendMailViewController is responsible for sending email using the Microsoft Graph API.
 Recipient address is pre-filled with the signed-in user's email address, and it can
 be modified.
 
 */
class SendMailViewController_noPromise : UIViewController {
    // MARK: Constants, Outlets, and Properties
    // Outlets
    @IBOutlet var headerLabel: UILabel!
    @IBOutlet var emailTextField: UITextField!
    @IBOutlet var sendMailButton: UIButton!
    @IBOutlet var statusTextView: UITextView!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!

    // Constants
    let successString = "Check your Inbox, you have a new message."
    let failureString = "The email couldn't be sent. Check the log for errors."

    // Properties
    var userEmailAddress: String!
    var userName: String!
    var userProfilePicture: UIImage? = nil
    var userPictureUrl: String? = nil

    
    // MARK: ViewController methods
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationItem.hidesBackButton = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
      //  self.headerLabel.text = "Hi, unkown user!"

       
            
            //Get user profile picture
             do
            {
                try self.userName = AuthenticationClass.sharedInstance?.authenticationProvider.users()[0].name!
                try self.emailTextField.text = AuthenticationClass.sharedInstance?.authenticationProvider.users()[0].displayableId
                self.userEmailAddress = self.emailTextField.text
                self.headerLabel.text = "Hi, \(self.userName! )"
                let _ = self.sendCRUDMessage(resource: "photo/$value", operation: "GET", content: Data.init(), completion: { (dataPic, response, error)  in
                    if let _ = error {
                        print(error as Any )
                        self.updateUI(showActivityIndicator: false, statusText: self.failureString)
                        return
                    }
                    
                    self.userProfilePicture = UIImage(data: (dataPic as Data?)!)!;
                    //Upload picture to OneDrive
                    let driveItem:Data = self.sendCRUDMessage(resource: "drive/root:/me.jpg:/content",
                                                              operation: "PUT",
                                                              content: UIImageJPEGRepresentation(self.userProfilePicture!,
                                                                                                 1)!,
                                                              completion: { (data, response, error)  in
                                                                if let _ = error {
                                                                    print(error as Any )
                                                                    self.updateUI(showActivityIndicator: false, statusText: self.failureString)
                                                                    return
                                                                }
                                                                var jsonResponseBody: Any
                                                                do {
                                                                    try jsonResponseBody = JSONSerialization.jsonObject(with: data!, options: .allowFragments);
                                                                    var statusTextString: Data
                                                                    try statusTextString = JSONSerialization.data(withJSONObject: jsonResponseBody, options: JSONSerialization.WritingOptions.prettyPrinted)
                                                                    self.updateUI(showActivityIndicator: false,
                                                                                  statusText: String(data: statusTextString, encoding: String.Encoding.utf8))
                                                                } catch {
                                                                    
                                                                }

                                                                // do stuff
                    });

                    
                    var jsonResponseBody: Any
                    do {
                        try jsonResponseBody = JSONSerialization.jsonObject(with: driveItem, options: .allowFragments);
                        var statusTextString: Data
                        try statusTextString = JSONSerialization.data(withJSONObject: jsonResponseBody, options: JSONSerialization.WritingOptions.prettyPrinted)
                        self.updateUI(showActivityIndicator: false,
                                      statusText: String(data: statusTextString, encoding: String.Encoding.utf8))
                    } catch {
                        
                    }

            })
            
            //Get sharing link for picture
            //try self.userPictureUrl = self.sendCRUDMessage(resource: "drive/root:/me.jpg", operation: "GET", content: Data.init())

             } catch _ as NSError{
            self.updateUI(showActivityIndicator: false,
                          statusText: "Error getting user profile picture.")
        }

        
    }
    
    
    // MARK: IBActions
    @IBAction func sendMail(_ sender: AnyObject) {
        // Fetch content from file
        updateUI(showActivityIndicator: true, statusText: "Sending")
        
        if let uploadContent = mailContent() {
            sendMailRestWithContent(uploadContent)
        }
        else {
            updateUI(showActivityIndicator: false,
                statusText: "Error assembling the mail content.")
        }
    }
    
    @IBAction func disconnect(_ sender: AnyObject) {
        AuthenticationClass.sharedInstance?.disconnect()
        self.navigationController?.popViewController(animated: true)
    }
    
    
    // MARK: Helper methods

    /**
     Prepare mail content by loading the files from resources and replacing placeholders with the
     HTML body.
     */
    func mailContent() -> Data? {
        
        if let emailFilePath = Bundle.main.path(forResource: "EmailPostContent", ofType: "json"),
            let emailBodyFilePath = Bundle.main.path(forResource: "EmailBody", ofType: "html")
        {
            do {
                // Prepare upload content
                let emailContent = try String(contentsOfFile: emailFilePath, encoding: String.Encoding.utf8)
                let emailBodyRaw = try String(contentsOfFile: emailBodyFilePath, encoding: String.Encoding.utf8)
                // Request doesn't accept a single quotation mark("), so change it to the acceptable form (\")
                var emailValidBody: String;
                emailValidBody = emailBodyRaw.replacingOccurrences(of: "\"", with: "\\\"")
                emailValidBody = emailValidBody.replacingOccurrences(of: "a href=%s", with: ("a href=" + self.userPictureUrl!))

                
                let emailPostContent = emailContent.replacingOccurrences(of: "<EMAIL>", with: self.emailTextField.text!)
                    .replacingOccurrences(of: "<CONTENTTYPE>", with: "HTML")
                    .replacingOccurrences(of: "<CONTENT>", with: emailValidBody)
                
                return emailPostContent.data(using: String.Encoding.utf8)
            }
            catch {
                // Error handling in case file loading fails.
                return nil
            }
        }
        // Error handling in case files aren't present.
        return nil
    }
    
    func sendMailRestWithContent(_ content: Data) {
        let _ = self.sendCRUDMessage(resource: "microsoft.graph.sendmail",
                                     operation: "POST",
                                     content: content,
                                     completion: { (data, response, error)  in
                if let _ = error {
                    print(error as Any )
                    self.updateUI(showActivityIndicator: false, statusText: self.failureString)
                    return
                }
            
                let statusCode = (response as! HTTPURLResponse).statusCode
            
                if statusCode == 202 {
                    self.updateUI(showActivityIndicator: false, statusText: self.successString)
                }
                else {
                    print("response: \(response!)")
                    print(String(data: data!, encoding: String.Encoding.utf8) as Any )
                    self.updateUI(showActivityIndicator: false, statusText: self.failureString)
                }

        })
    }
    
    
    /**
     Send a create, read, update, delete (CRUD) nessage.
     Create= POST, Update= PUT, Delete= DELETE.
     Read= GET. Use sendGETMessage(resource: String) to read Graph contents
     */
    func sendCRUDMessage(resource: String, operation:String, content: Data, completion: @escaping (Data?, URLResponse?, Error?) -> Void)->Data  {
        
        var returnData: Data;
        returnData = Data.init();
        
        if  (self.connectToGraph()){
            
            if (operation == "GET") {
                return self.sendGETMessage(resource: resource)
            }
            let request = NSMutableURLRequest(url: URL(string: "https://graph.microsoft.com/v1.0/me/" + resource)!)
            request.httpMethod = operation;
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
            
            let accessToken = AuthenticationClass.sharedInstance?.accessToken
            request.setValue("Bearer \(accessToken!)" as String, forHTTPHeaderField: "Authorization")
            request.httpBody = content
            
            
            let task = URLSession.shared.dataTask(with:request as URLRequest, completionHandler:completion) // let task
            
            task.resume()

        }
        return returnData;
        
    }
    
    /**
     Sends a GET request. Internal helper method is only called by SendCRUDRequest()
     */
    func sendGETMessage(resource: String) -> Data {
        var returnData: Data;
        returnData = Data.init();
        
        let request = NSMutableURLRequest(url: URL(string: "https://graph.microsoft.com/v1.0/me/" + resource)!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        
        let accessToken = AuthenticationClass.sharedInstance?.accessToken
        request.setValue("Bearer \(accessToken!)" as String, forHTTPHeaderField: "Authorization")
        
        
        let task = URLSession.shared.dataTask(with:request as URLRequest, completionHandler: {
            (data, response, error) in
            
            if let _ = error {
                print(error as Any )
                self.updateUI(showActivityIndicator: false, statusText: self.failureString)
                return
            }
            
            let statusCode = (response as! HTTPURLResponse).statusCode
            
            if statusCode == 202 {
                self.updateUI(showActivityIndicator: false, statusText: self.successString)
            }
            else {
                print("response: \(response!)")
                print(String(data: data!, encoding: String.Encoding.utf8) as Any )
                self.updateUI(showActivityIndicator: false, statusText: self.failureString)
            }
        }) // let task
        
        task.resume()
            
        return returnData;
    }

    
    func connectToGraph() -> Bool {
        
//        if  ((AuthenticationClass.sharedInstance?.accessToken) != ""){
//            return true;
//        }

        // Acquire an access token, if logged in already, this shouldn't bring up an authentication window.
        // However, if the token is expired, user will be asked to sign in again.
        var authenticated: Bool;
        authenticated = ((AuthenticationClass.sharedInstance?.connectToGraph(scopes: ApplicationConstants.kScopes) {
            (result: ApplicationConstants.MSGraphError?, accessToken: String) -> Bool in
            
            
            if  ((AuthenticationClass.sharedInstance?.accessToken) == nil){
                // Upon failure, alert and go back.
                let localizedDescription: String = ApplicationConstants.MSGraphError.nsErrorType(error: result! as NSError).localizedDescription
                print(localizedDescription)
                
                let alertController = UIAlertController(title: "Error", message: ApplicationConstants.MSGraphError.nsErrorType(error: result! as NSError).localizedDescription, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "Close", style: .destructive, handler: {
                    (action) -> Void in
                    AuthenticationClass.sharedInstance?.disconnect()
                    self.navigationController!.popViewController(animated: true)
                }))
                
                self.present(alertController, animated: true, completion: nil)
                return false;
                
            } else {
                
                return true;
                
            } // else authentication token != nil
        }) != nil)
        return authenticated;
    }
    
    func updateUI(showActivityIndicator: Bool,
        statusText: String? = nil) {
            if showActivityIndicator {
                DispatchQueue.main.async(execute: { () -> Void in
                    self.sendMailButton.isEnabled = false
                    self.activityIndicator.startAnimating()
                })
            }
            else {
                DispatchQueue.main.async(execute: { () -> Void in
                    self.sendMailButton.isEnabled = true
                    self.activityIndicator.stopAnimating()
                })
            }
            if let _ = statusText {
                DispatchQueue.main.async(execute: { () -> Void in
                    self.statusTextView.text = statusText
                })
            }
    }
}