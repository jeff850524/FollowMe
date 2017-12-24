//
//  PositioningViewController.swift
//  FollowMe
//
//  Created by riverciao on 2017/12/23.
//  Copyright © 2017年 riverciao. All rights reserved.
//

import UIKit
import MapKit

class PositioningViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {

    private var currentLocation: CLLocation?
    private var locationManager = CLLocationManager()
    let queue = OperationQueue()
    
    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var currentLocationPointerImageView: UIImageView!
    
    @IBAction func confirmLocationButton(_ sender: Any) {
        
        let location = currentLocationPointerImageView.center
        let locationCoordinate = self.mapView.convert(location, toCoordinateFrom: self.mapView)
        print("locationCoordinate\(locationCoordinate)")
        print("heading\(mapView.camera.heading)")
        
        //Transfer to mapViewController
        let mapViewController = MapViewController()
        let navigationController = UINavigationController(rootViewController: mapViewController)
        present(navigationController, animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        mapView.delegate = self
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingHeading()

        setupCurrentLocationPointerImageView()
        
        // Check for Location Services
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()
        }
        
    }

    
    private func setupCurrentLocationPointerImageView() {
        
        //Rotate to point front side
        currentLocationPointerImageView.transform = currentLocationPointerImageView.transform.rotated(by: CGFloat.init(Double.pi * 3 / 2))
        
    }

    // MARK - CLLocationManagerDelegate
    // TODO: - track location and heading for onece and do not keep  tracking to let user adjust it by self
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        defer {
            
            currentLocation = locations.last
            
        }
        
        if currentLocation == nil {
            // Zoom to user location
            if let userLocation = locations.last {
                let viewRegion = MKCoordinateRegionMakeWithDistance(userLocation.coordinate, 60, 60)
                mapView.setRegion(viewRegion, animated: false)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        
        mapView.camera.heading = newHeading.magneticHeading
        mapView.setCamera(mapView.camera, animated: true)
    
    }

}