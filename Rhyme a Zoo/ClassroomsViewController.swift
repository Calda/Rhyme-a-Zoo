//
//  SchoolsViewController.swift
//  Rhyme a Zoo
//
//  Created by Cal on 7/28/15.
//  Copyright (c) 2015 Cal Stephens. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation

class ClassroomsViewController : UIViewController, UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var nearbyClassroomsLabel: UILabel!
    @IBOutlet weak var noNearbyLabel: UILabel!
    @IBOutlet weak var topBar: UIVisualEffectView!
    @IBOutlet weak var repeatButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet var touchRecognizer: UITouchGestureRecognizer!
    
    let locationManager = LocationManager(accuracy: kCLLocationAccuracyKilometer)
    var currentLocation: CLLocation?
    var nearbyClassrooms: [Classroom]?
    var searching = false
    
    //MARK: - Asynchronously fetch location and nearby classrooms
    
    override func viewWillAppear(animated: Bool) {
        tableView.contentInset = UIEdgeInsets(top: 70.0, left: 0.0, bottom: 70.0, right: 0.0)
        checkUserLoggedIn()
    }
    
    func checkUserLoggedIn(delayAlertPresentation: Bool = false) {
        RZUserDatabase.userLoggedIn({ loggedIn in
            if !loggedIn {
                
                let alert = UIAlertController(title: "Cannot join Classroom", message: "You must be logged in to an iCloud account on this device to join or create a classroom.", preferredStyle: .Alert)
                alert.addAction(UIAlertAction(title: "Try Again", style: .Default, handler: { _ in
                    //recursively repeat this function
                    self.checkUserLoggedIn()
                }))
                alert.addAction(UIAlertAction(title: "Settings", style: .Default, handler: { _ in
                    self.activityIndicator.alpha = 0.0
                    openSettings()
                    delay(1.0) {
                        self.presentViewController(alert, animated: true, completion: nil)
                    }
                    
                }))
                alert.addAction(UIAlertAction(title: "Cancel", style: .Destructive, handler: { _ in
                    self.dismissViewControllerAnimated(true, completion: nil)
                }))
                
                delay(delayAlertPresentation ? 0.5 : 0.0) {
                    self.presentViewController(alert, animated: true, completion: nil)
                }
                
            }
                
            else {
                self.searchForNearbyClassrooms()
            }
            
        })
    }
    
    func searchForNearbyClassrooms() {
        searching = true
        repeatButton.enabled = false
        
        
        activityIndicator.alpha = 1.0
        if nearbyClassrooms == nil {
            tableView.alpha = 0.0
        }
        
        //load classrooms
        locationManager.getCurrentLocation({ location in
            
            self.currentLocation = location
            RZUserDatabase.getNearbyClassrooms(location, completion: { nearby in
                self.nearbyClassrooms = nearby
                self.dataLoaded()
            })
            }, failure: { error in
                //failed to access location
                self.dataLoaded()
                
                let alert = UIAlertController(title: "Could not determine location", message: "Enable Location Services or search for your classroom by name.", preferredStyle: .Alert)
                let ok = UIAlertAction(title: "OK", style: .Default, handler: nil)
                let settings = UIAlertAction(title: "Settings", style: .Default, handler: { alert in
                    openSettings()
                })
                alert.addAction(ok)
                alert.addAction(settings)
                self.presentViewController(alert, animated: true, completion: nil)
        })
    }
    
    func dataLoaded() {
        searching = false
        delay(1.5) {
            self.repeatButton.enabled = true
        }
        self.tableView.reloadData()
        
        //animate
        let originalIndicatorOrigin = self.activityIndicator.frame.origin
        let newIndicatorOrigin = CGPointMake(self.activityIndicator.frame.origin.x, self.activityIndicator.frame.origin.y + 100)
        UIView.animateWithDuration(0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: nil, animations: {
            
            self.activityIndicator.frame.origin = newIndicatorOrigin
            self.activityIndicator.alpha = 0.0
            
            if self.nearbyClassrooms?.count > 0 {
                self.tableView.alpha = 1.0
                self.topBar.frame.origin = CGPointZero
                self.topBar.alpha = 1.0
                self.noNearbyLabel.alpha = 0.0
            }
            else {
                self.noNearbyLabel.alpha = 0.9
                self.topBar.alpha = 0.0
            }
            
        }, completion: { success in
            self.activityIndicator.frame.origin = originalIndicatorOrigin
        })
    }
    
    //MARK: - Table View Data Source
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return nearbyClassrooms?.count ?? 0
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("classroom") as! ClassroomCell
        
        if let classrooms = nearbyClassrooms {
            let classroom = classrooms[indexPath.item]
            let distance = currentLocation?.distanceFromLocation(classroom.location)
            cell.decorate(name: classroom.name, distance: distance)
        }
        
        return cell
    }
    
    //MARK: - User Interaction
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    @IBAction func touchRecognized(sender: UITouchGestureRecognizer) {
        if sender.state == .Ended {
            animateSelection(nil)
        }
        
        for cell in tableView.visibleCells() as! [ClassroomCell] {
            let touch = sender.locationInView(cell.superview!)
            if cell.frame.contains(touch) {
                
                let index = tableView.indexPathForCell(cell)!.item
                
                if sender.state == .Ended {
                    if let nearbyClassrooms = nearbyClassrooms {
                        let classroom = nearbyClassrooms[index]
                        openPasscodeForClassroom(classroom)
                    }
                }
                else {
                    animateSelection(index)
                }
            }
        }
    }
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        touchRecognizer.enabled = false
        animateSelection(nil)
        delay(0.5) {
            self.touchRecognizer.enabled = true
        }
    }
    
    func animateSelection(index: Int?) {
        for cell in tableView.visibleCells() as! [ClassroomCell] {
            
            if let indexPath = tableView.indexPathForCell(cell) where indexPath.item == index && touchRecognizer.enabled {
                UIView.animateWithDuration(0.15) {
                    cell.backgroundColor = UIColor(white: 1.0, alpha: 0.1)
                }
            }
            else {
                UIView.animateWithDuration(0.15) {
                    cell.backgroundColor = UIColor(white: 1.0, alpha: 0.0)
                }
            }
            
        }
    }
    
    func openPasscodeForClassroom(classroom: Classroom) {
        requestPasscode(classroom.passcode, "Passcode for \"\(classroom.name)\"", currentController: self, completion: {
            self.joinClassroom(classroom)
        })
    }
    
    @IBAction func back(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func repeatSearch(sender: AnyObject) {
        if !searching {
            checkUserLoggedIn(delayAlertPresentation: false)
        }
    }
    
    //MARK: - Creating a Classroom
    
    @IBAction func createClassroomButtonPressed(sender: AnyObject?) {
        if let location = currentLocation {
            requestNewClassroomName(location)
        }
        
        else {
            activityIndicator.alpha = 1.0
            locationManager.getCurrentLocation({ location in
                self.currentLocation = location
                self.requestNewClassroomName(location)
            }, failure: { error in
                self.activityIndicator.alpha = 0.0
                
                //show alert
                let alert = UIAlertController(title: "Could not determine location", message: "A location is required to create a new classroom. Make sure you have Location Services enabled.", preferredStyle: .Alert)
                let cancel = UIAlertAction(title: "Cancel", style: .Default, handler: nil)
                let settings = UIAlertAction(title: "Settings", style: .Default, handler: { alert in
                    openSettings()
                })
                alert.addAction(cancel)
                alert.addAction(settings)
                self.presentViewController(alert, animated: true, completion: nil)
                
            })
        }
    }
    
    func requestNewClassroomName(location: CLLocation, previousNameAttempt: String? = nil) {
        var message: String = "Your classroom can have any name, but it should be easy to identify."
        if let previousName = previousNameAttempt {
            if (previousName as NSString).length < 4 {
                message = "\"\(previousName)\" is too short. Your classroom's name must be at least four letters long."
            } else {
                message = "There is already a classroom named \"\(previousName)\""
            }
        }
        
        let alert = UIAlertController(title: "Name your Classroom", message: message, preferredStyle: .Alert)
        var nameTextField: UITextField!
        alert.addTextFieldWithConfigurationHandler({ textField in
            nameTextField = textField
            nameTextField.placeholder = "Mr. Evan's 3rd Graders"
            textField.autocapitalizationType = .Sentences
            textField.autocorrectionType = .No
        })
        
        let next = UIAlertAction(title: "Next", style: .Default, handler: { _ in
        
            let name = nameTextField.text
            
            //name must be longer than four letters long
            if (name as NSString).length <= 4 {
                self.requestNewClassroomName(location, previousNameAttempt: name)
                return
            }
            
            //check name is unique
            RZUserDatabase.getClassroomsMatchingText(name, location: nil, completion: { classrooms in
                for classroom in classrooms {
                    if classroom.name == name {
                        self.requestNewClassroomName(location, previousNameAttempt: name)
                        return
                    }
                }
                
                //name is unique
                self.requestClassroomPasscode(location, name: name)
                
            })
            
        })
        
        let cancel = UIAlertAction(title: "Cancel", style: .Default, handler: nil)
        alert.addAction(cancel)
        alert.addAction(next)
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    func requestClassroomPasscode(location: CLLocation, name: String) {
        createPasscode("Create a 4-digit passcode for \"\(name)\"", currentController: self, { possiblePasscode in
            
            if let passcode = possiblePasscode where count(passcode) == 4 {
                self.createClassroom(location, name: name, passcode: passcode)
            }
            else {
                let alert = UIAlertController(title: nil, message: "You must create a 4-digit passcode for your classroom.", preferredStyle: .Alert)
                let cancel = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Destructive, handler: nil)
                let tryAgain = UIAlertAction(title: "Try Again", style: UIAlertActionStyle.Default, handler: { _ in
                    self.requestClassroomPasscode(location, name: name)
                })
                alert.addAction(cancel)
                alert.addAction(tryAgain)
                self.presentViewController(alert, animated: true, completion: nil)
            }
            
        })
    }
    
    func createClassroom(location: CLLocation, name: String, passcode: String) {
        RZUserDatabase.createClassroomNamed(name, location: location, passcode: passcode, completion: { classroom in
            if let classroom = classroom {
                self.joinClassroom(classroom)
            }
            else {
                let alert = UIAlertController(title: "Could not create your classroom.", message: "There was a problem saving your classroom. Make sure you are connected to the internet and logged into an iCloud account on this device.", preferredStyle: .Alert)
                let cancel = UIAlertAction(title: "Cancel", style: .Destructive, handler: nil)
                let settings = UIAlertAction(title: "Settings", style: .Default, handler: { _ in
                    openSettings()
                })
                let tryAgain = UIAlertAction(title: "Try Again", style: .Default, handler: { _ in
                    self.createClassroom(location, name: name, passcode: passcode)
                })
                alert.addAction(tryAgain)
                alert.addAction(settings)
                alert.addAction(cancel)
                self.presentViewController(alert, animated: true, completion: nil)
            }
        })
    }
    
    //MARK: - Searching by name
    
    @IBAction func searchPressed(sender: AnyObject?) {
        let alert = UIAlertController(title: "Search for a Classroom", message: nil, preferredStyle: .Alert)
        
        var searchTextField: UITextField?
        alert.addTextFieldWithConfigurationHandler({ textField in
            textField.placeholder = "Classroom Name"
            searchTextField = textField
            textField.autocapitalizationType = .Sentences
            textField.autocorrectionType = .No
        })
        
        let cancel = UIAlertAction(title: "Cancel", style: .Default, handler: nil)
        let search = UIAlertAction(title: "Search", style: .Default, handler: { action in
            if let searchTextField = searchTextField {
                
                let text = searchTextField.text
                self.processSearchText(text)
                
            }
        })
        
        alert.addAction(cancel)
        alert.addAction(search)
        self.presentViewController(alert, animated: true, completion: nil)
        
    }
    
    func processSearchText(text: String) {
        if (text as NSString).length < 4 {
            //search must be atleast 4 characters long
            let alert = UIAlertController(title: "Text Too Short", message: "Your search text must be at least 4 characters long.", preferredStyle: .Alert)
            let cancel = UIAlertAction(title: "Cancel", style: .Default, handler: nil)
            let tryAgain = UIAlertAction(title: "Try Again", style: .Default, handler: { alert in
                self.searchPressed(nil)
            })
            alert.addAction(cancel)
            alert.addAction(tryAgain)
            self.presentViewController(alert, animated: true, completion: nil)
            return
        }
        
        self.noNearbyLabel.text = "No classrooms starting with \"\(text)\""
        self.nearbyClassroomsLabel.text = "Starts with \"\(text)\""
        
        RZUserDatabase.getClassroomsMatchingText(text, location: currentLocation, completion: { classrooms in
            self.nearbyClassrooms = classrooms
            self.dataLoaded()
        })
        
        //animate
        cancelButton.transform = CGAffineTransformMakeScale(0.1, 0.1)
        cancelButton.alpha = 0.0
        activityIndicator.alpha = 0.0
        let originalIndicatorOrigin = self.activityIndicator.frame.origin
        self.activityIndicator.frame.offset(dx: 0, dy: 100)
        
        UIView.animateWithDuration(0.6, delay: 0.0, usingSpringWithDamping: 0.4, initialSpringVelocity: 0.0, options: nil, animations: {
            self.cancelButton.alpha = 1.0
            self.cancelButton.transform = CGAffineTransformMakeScale(1.0, 1.0)
            self.activityIndicator.frame.origin = originalIndicatorOrigin
            self.activityIndicator.alpha = 1.0
            self.noNearbyLabel.alpha = 0.0
        }, completion: nil)
        
        UIView.animateWithDuration(0.3) {
            self.tableView.alpha = 0.0
        }
        
        
    }
    
    @IBAction func cancelSearch(sender: AnyObject) {
        //animate
        let originalIndicatorOrigin = self.activityIndicator.frame.origin
        self.activityIndicator.frame.offset(dx: 0, dy: 100)
        UIView.animateWithDuration(0.4, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.0, options: nil, animations: {
            self.cancelButton.alpha = 0.0
            self.cancelButton.transform = CGAffineTransformMakeScale(0.1, 0.1)
            self.activityIndicator.frame.origin = originalIndicatorOrigin
            self.activityIndicator.alpha = 1.0
            self.tableView.alpha = 0.0
        }, completion: nil)
        
        searchForNearbyClassrooms()
        nearbyClassroomsLabel.text = "Nearby Classrooms"
        noNearbyLabel.text = "No nearby classrooms."
    }
    
    //MARK: - Join a classroom
    
    func joinClassroom(classroom: Classroom) {
        RZUserDatabase.linkToClassroom(classroom)
        //switch to users view
        let alert = UIAlertController(title: classroom.name, message: "You're signed in to your classroom!", preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { _ in
        
            //return to Select a User screen
            dismissController(self, untilMatch: { $0 is UsersViewController })
            
        }))
        
        self.presentViewController(alert, animated: true, completion: nil)
        
    }
    
}

class ClassroomCell : UITableViewCell {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    
    func decorate(#name: String, distance: Double?) {
        nameLabel.text = name
        self.backgroundColor = UIColor.clearColor()
        if let distance = distance {
            distanceLabel.alpha = 1.0
            let meterToMile = 0.000621371
            let miles = distance * meterToMile
            let milesRounded = Int(miles)
            
            if milesRounded == 0 {
                distanceLabel.text = "Very close-by"
            } else if milesRounded == 1 {
                distanceLabel.text = "1 mile away"
            } else if milesRounded > 5000 {
                distanceLabel.text = "Incredibly far away"
            } else if milesRounded > 500 {
                distanceLabel.text = "Very far away"
            } else if milesRounded > 50 {
                distanceLabel.text = "Far away"
            }
            else {
                distanceLabel.text = "\(milesRounded) miles away"
            }
        }
        else {
            distanceLabel.alpha = 0.0
        }
    }
    
}