//
//  MapViewController.swift
//  FollowMe
//
//  Created by riverciao on 2017/12/18.
//  Copyright © 2017年 riverciao. All rights reserved.
//

import UIKit
import MapKit
import Firebase

protocol RouteProviderDelegate: class {
    func didGet(routeImageView: UIImageView)
}

protocol HandleMapSearch {
    
    func dropPinZoomIn(placemark: MKPlacemark)
    func setRouteWith(currentLocationCoordinate: CLLocationCoordinate2D, destinationCoordinate: CLLocationCoordinate2D)
}

class MapViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate, UISearchBarDelegate {

    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        
        searchBackgroundView.isHidden = false
        
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        
        searchBackgroundView.isHidden = true
        
    }
    
    //Location Manager
    let locationSearchTableViewController = LocationSearchTableViewController()
    private var locationManager: CLLocationManager!
    private var currentLocation: CLLocation?
    private var route: MKRoute?
    
    var selectedPin: MKPlacemark? = nil
    var coordinatesPerMeter: [CLLocationCoordinate2D] = []
    // TODO: - weak var delegate
    var delegate: CoordinateManagerDelegate? = nil
    weak var routeDelegate: RouteProviderDelegate?
    
    var isSaved: Bool = true
    
    var destinationCoordinate: CLLocationCoordinate2D?
    
    var currentLocationCoordinateForARSetting: CLLocationCoordinate2D?
    
    var currentLocationAnnotation: Annotation!
    
    //add pathId to pass to ARFollowerController
    var currentPathId: pathId?
    
    //Route screen shot
    var routeImageView: UIImageView?
    
    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var searchBackgroundView: UIView!
    
    @IBOutlet weak var goToARButtonOutlet: UIButton!
    
    @IBAction func goToARButton(_ sender: Any) {
        
        upload()
        
        self.takeSnapShot()
        
        let arFollowerViewController = ARFollowerViewController()
        
        if let currentLocationCoordinateForARSetting = self.currentLocationCoordinateForARSetting {
            
            arFollowerViewController.currentLocationCoordinateForARSetting = currentLocationCoordinateForARSetting
        
        }
        
        arFollowerViewController.route = self.route
        
        arFollowerViewController.currentPathId = self.currentPathId
        
        arFollowerViewController.routeImageView = self.routeImageView
        
        self.navigationController?.pushViewController(arFollowerViewController, animated: true)
        
    }
    
    
    @IBAction func CancelButton(_ sender: Any) {
        
        self.dismiss(animated: true, completion: nil)
        
    }
    
    @IBAction func addPin(_ sender: UITapGestureRecognizer) {
        
        let location = sender.location(in: self.mapView)
        self.destinationCoordinate = self.mapView.convert(location, toCoordinateFrom: self.mapView)
        
        if let destinationCoordinate = destinationCoordinate, let currentLocationCoordinate = currentLocationCoordinateForARSetting {
            
            self.mapView.removeAnnotations(self.mapView.annotations)
            
            setRouteWith(currentLocationCoordinate: currentLocationCoordinate, destinationCoordinate: destinationCoordinate)

        }
        
    }
    
    // MARK: - View life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.delegate = self
        locationSearchTableViewController.handleMapSearchDelegate = self
        
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        //add addANewArticle navigationItem at rightside
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.search, target: self, action: #selector(search(sender:)))
        

        
        // Check for Location Services
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()
        
        } else {
            
            self.mapView.showsUserLocation = false
        
        }
        
        if let currentLocationCoordinate = currentLocationCoordinateForARSetting {
            setupAnnotationsFor(currentLocationCoordinate: currentLocationCoordinate)
        }
        
        setupGoToARButtonOutlet()
        
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillAppear(animated)
        setupSearchBackgroundView()
        hideKeyboardWhenTappedAround()
        hideSearchBackgroundViewWhenTappedAround()
    
    }
    
    
    // MARK: - Search Controller
    
    @objc private func search(sender: UIBarButtonItem) {
        
        searchBackgroundView.isHidden = false
        
        //Setup search results controller
        let searchController = UISearchController(searchResultsController: locationSearchTableViewController)
        
        searchController.searchResultsUpdater = locationSearchTableViewController
        searchController.searchBar.delegate = self
        
        // limits the overlap area to just the View Controller’s frame instead of the whole Navigation Controller
        definesPresentationContext = true
        
        if let currentLocationCoordinateForARSetting = self.currentLocationCoordinateForARSetting {
            //Pass Value
            let currentLocationForARSetting = CLLocation(coordinate: currentLocationCoordinateForARSetting, altitude: 0)
            locationSearchTableViewController.currentLocation = currentLocationForARSetting
            locationSearchTableViewController.mapView = self.mapView
            present(searchController, animated: true, completion: nil)
        }

    }
    
    func setupSearchBackgroundView() {
        searchBackgroundView.backgroundColor = Palette.duckFeather
        searchBackgroundView.isHidden = true
    }

    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {

        searchBackgroundView.isHidden = true
        
        //Ignore user
        UIApplication.shared.beginIgnoringInteractionEvents()
        
        //Activity indicator
        let activityIndicator = UIActivityIndicatorView()
        activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.gray
        activityIndicator.center = self.view.center
        activityIndicator.hidesWhenStopped = true
        activityIndicator.startAnimating()
        
        self.view.addSubview(activityIndicator)
        
        //Hide search bar
        searchBar.resignFirstResponder()
        dismiss(animated: true, completion: nil)
        
        //Create the search request
        let searchRequest = MKLocalSearchRequest()
        searchRequest.naturalLanguageQuery = searchBar.text
        
        let activeSearch = MKLocalSearch(request: searchRequest)
        
        activeSearch.start { (response, error) in
            
            activityIndicator.stopAnimating()
            UIApplication.shared.endIgnoringInteractionEvents()
            
            if let error = error {
                print("Error: \(error)")
                return
            }
            
            //Remove annotations
            let annotations = self.mapView.annotations
            self.mapView.removeAnnotations(annotations)
            
            //Getting data
            let latitude = response?.boundingRegion.center.latitude
            let longitude = response?.boundingRegion.center.longitude
            
            //Create annotation
            self.destinationCoordinate = CLLocationCoordinate2DMake(latitude!, longitude!)
            let annotation = Annotation(title: searchBar.text!, subtitle: "", coordinate: self.destinationCoordinate!)
            self.mapView.addAnnotation(annotation)
            
            //Draw the route
            if let currentLocationCoordinate = self.currentLocationCoordinateForARSetting {
                self.setRouteWith(currentLocationCoordinate: currentLocationCoordinate, destinationCoordinate: self.destinationCoordinate!)
            }
            
            //TODO: - adjust the scale of zoom in level (depends on the size of destination)
            //Zoom in on annotation
            let span = MKCoordinateSpanMake(0.1, 0.1)
            let region = MKCoordinateRegionMake(self.destinationCoordinate!, span)
            self.mapView.setRegion(region, animated: true)
        }
        
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.showsCancelButton = false
        searchBackgroundView.isHidden = true
    }
    
    private func setupGoToARButtonOutlet() {
        goToARButtonOutlet.backgroundColor = Palette.duckBeak
        goToARButtonOutlet.setTitleColor(Palette.mystic, for: .normal)
        goToARButtonOutlet.titleLabel?.font = UIFont(name: "ARCADECLASSIC", size: 36)
        goToARButtonOutlet.layer.cornerRadius = goToARButtonOutlet.bounds.height / 2
        goToARButtonOutlet.clipsToBounds = true
        goToARButtonOutlet.setImage(#imageLiteral(resourceName: "icon-walking-bird"), for: .highlighted)
        goToARButtonOutlet.imageEdgeInsets = UIEdgeInsetsMake(70, 70, 70, 70)
        goToARButtonOutlet.imageView?.contentMode = .scaleAspectFit
        goToARButtonOutlet.setBackgroundColor(color: Palette.baliHai, forState: .highlighted)
    }
    
    private func setupAnnotationsFor(destinationCoordinate: CLLocationCoordinate2D) {
        
        let destinationAnnotation = Annotation(title: "Destination", subtitle: "You want to arrive here", coordinate: destinationCoordinate)
        
        self.mapView.addAnnotation(destinationAnnotation)
    }
    
    private func setupAnnotationsFor(currentLocationCoordinate: CLLocationCoordinate2D) {

        let region = MKCoordinateRegionMakeWithDistance(currentLocationCoordinate, 200, 200)
        mapView.setRegion(region, animated: true)
        
        self.currentLocationAnnotation = Annotation(title: "Current Location", subtitle: "You are here now", coordinate: currentLocationCoordinate)
        
        mapView.addAnnotation(currentLocationAnnotation)
    }
    
    
    private func getMapItem(with coordinate: CLLocationCoordinate2D) -> MKMapItem {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        return mapItem
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.strokeColor = UIColor.red
        renderer.lineWidth = 4.0
        
        return renderer
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        defer {
            
            currentLocation = locations.last
            
        }
        
        if currentLocation == nil {
            
        }
    }
    
    // MARK: - Custom Annotation
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let annotationView = MKAnnotationView(annotation: currentLocationAnnotation, reuseIdentifier: "currentLocationAnnotation")
        annotationView.image = #imageLiteral(resourceName: "icon-start-node")
//        let transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
//        annotationView.transform = transform
        return annotationView
    }
    

    
    typealias coordinates = [CLLocationCoordinate2D]
    
    public func getCoordinatesFromStraintLine(from coordinates: coordinates) -> coordinates {
        
        var coordinatesPerMeter = coordinates
        
        var segment: Int = 0
        
        for _ in 1..<coordinates.count {
            
            // TODO: - add altitude to CLLocation argument
            
            let coordinate = coordinates[segment]
            
            let nextCoordinate = coordinates[segment + 1]
            
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            let nextLocation = CLLocation(latitude: nextCoordinate.latitude, longitude: nextCoordinate.longitude)
            
            let distance = location.distance(from: nextLocation)
            
            var count: Double = 1
            
            if distance > 3 {
                
                for _ in 1..<Int(distance/3) {
                    
                    let  fraction = count * 3 / distance
                    
                    let startLatitude = coordinate.latitude
                    
                    let startLongitude = coordinate.longitude
                    
                    let endLatitude = nextCoordinate.latitude
                    
                    let endLongitude = nextCoordinate.longitude
                    
                    let newLatitude = startLatitude * fraction + endLatitude * (1 - fraction)
                    
                    let newLongitude = startLongitude * fraction + endLongitude * (1 - fraction)
                    
                    let newCoordinate = CLLocationCoordinate2D(latitude: newLatitude, longitude: newLongitude)
                    
                    coordinatesPerMeter.append(newCoordinate)
                    
                    count += 1
                }
                
            }
            
            segment += 1
            
        }
        
        return coordinatesPerMeter
    }
    
    //TODO: - make component
    //MARK: - upload to firebase
    
    private func upload() {
        
        // Upload new path to firebase
        let pathIdRef = FirebasePath.pathRef.childByAutoId()
        
        uploadStartNode(in: pathIdRef)
        uploadPathNode(in: pathIdRef)
        uploadEndNode(in: pathIdRef)
        uploadStepNode(in: pathIdRef)
        
        self.currentPathId = pathIdRef.key

    }
    
    private func uploadStartNode(in pathIdRef: DatabaseReference) {
        
        let startNodeRef = pathIdRef.child("start-node")
        
        //Make current location assign only onece when user press add path button
        
        guard let currentLocationCoordinate = currentLocationCoordinateForARSetting else {
            
            print("currentLocation not found")
            
            return
            
        }
        
        let latitude = currentLocationCoordinate.latitude, longitude = currentLocationCoordinate.longitude, altitude = 0
        
        let values = [NodeCoordinate.Schema.latitude: latitude, NodeCoordinate.Schema.longitude: longitude, NodeCoordinate.Schema.altitude: altitude] as [String : Any]
        
        startNodeRef.setValue(values)
        
    }
    
    private func uploadPathNode(in pathIdRef: DatabaseReference) {
        
        for pathNode in self.coordinatesPerMeter {
            
            // Upload pathNodes to firebase
            let pathId = pathIdRef.key
            
            let pathNodesRef = FirebasePath.pathRef.child(pathId).child("path-nodes")
            
            let pointsPositionRef = pathNodesRef.childByAutoId()
            
            let latitude = pathNode.latitude, longitude = pathNode.longitude, altitude = 0
            
            let values = [NodeCoordinate.Schema.latitude: latitude, NodeCoordinate.Schema.longitude: longitude, NodeCoordinate.Schema.altitude: altitude] as [String : Any]
            
            pointsPositionRef.updateChildValues(values, withCompletionBlock: { (error, ref) in
                
                if let error = error {
                    
                    print(error)
                    
                    return
                }
                
            })
            
        }
    }
    
    private func uploadEndNode(in pathIdRef: DatabaseReference) {
        
        let endNodeRef = pathIdRef.child("end-node")
        
        guard let destinationCoordinate = destinationCoordinate else {
            
            print("destinationCoordinate not found")
            
            return
            
        }
        
        let latitude = destinationCoordinate.latitude, longitude = destinationCoordinate.longitude
        
        let values = [NodeCoordinate.Schema.latitude: latitude, NodeCoordinate.Schema.longitude: longitude] as [String : Any]
        
        endNodeRef.setValue(values)
        
    }
    
    private func uploadStepNode(in pathIdRef: DatabaseReference) {
        
        guard let steps = self.route?.steps else { return }
        
        for step in steps {
            
            //data to be uploaded
            let coordinate = step.polyline.coordinates.last
            let latitude = coordinate?.latitude, longitude = coordinate?.longitude
            
            let instruction = step.instructions
            let distance = step.distance
            
            //setup firebase reference
            let pathId = pathIdRef.key
            let stepNodesRef = FirebasePath.pathRef.child(pathId).child("step-nodes")
            let stepNodeRef = stepNodesRef.childByAutoId()
            let values = ["latitude": latitude!, "longitude": longitude!, "instruction": instruction, "distance": distance] as [String: Any]
            
            stepNodeRef.updateChildValues(values, withCompletionBlock: { (error, ref) in
                
                if let error = error {
                    
                    print(error)
                    
                    return
                }
                
            })
        
        }

    }
    
}

extension MapViewController: HandleMapSearch {
    
    
    func dropPinZoomIn(placemark: MKPlacemark) {
        
        // cache the pin
        selectedPin = placemark
        
        // clear existing pins
        mapView.removeAnnotations(mapView.annotations)
        let annotation = MKPointAnnotation()
        annotation.coordinate = placemark.coordinate
        annotation.title = placemark.name
        
        if let city = placemark.locality, let state = placemark.administrativeArea {
            annotation.subtitle = "\(city) \(state)"
        }
        
        mapView.addAnnotation(annotation)
        let span = MKCoordinateSpanMake(0.05, 0.05)
        let region = MKCoordinateRegionMake(placemark.coordinate, span)
        
        mapView.setRegion(region, animated: true)
    }
     
    func setRouteWith(currentLocationCoordinate: CLLocationCoordinate2D, destinationCoordinate: CLLocationCoordinate2D) {
        
        let overlays = mapView.overlays
        mapView.removeOverlays(overlays)
        
        setupAnnotationsFor(destinationCoordinate: destinationCoordinate)
        setupAnnotationsFor(currentLocationCoordinate: currentLocationCoordinate)
        
        let currentLocationMapItem = getMapItem(with: currentLocationCoordinate)
        let destinationMapItem = getMapItem(with: destinationCoordinate)
        
        let directionRequest = MKDirectionsRequest()
        directionRequest.source = currentLocationMapItem
        directionRequest.destination = destinationMapItem
        directionRequest.transportType = .walking
        
        // Calculate the direction
        let directions = MKDirections(request: directionRequest)
        
        directions.calculate { (response, error) in
            
            
            guard let response = response else {
                
                if let error = error {
                    print(error)
                }
                
                return
                
            }
            
            
            self.route = response.routes[0]
            
            
            // MARK: - Retrieve GPS coordinate from polyline
            
            let routeCoordinates = self.route?.polyline.coordinates
            
            self.coordinatesPerMeter = self.getCoordinatesFromStraintLine(from: routeCoordinates!)
            
            if let route = self.route {
                
                self.mapView.add((route.polyline), level: MKOverlayLevel.aboveRoads)
                
            }
        }
    }
}

extension MapViewController {
    
    // MARK: - Route screen shot
    func takeSnapShot() {
        
        let mapSnapshotOptions = MKMapSnapshotOptions()
        
        // Set the region of the map that is rendered. (by polyline)
        //        let polyLine = MKPolyline(coordinates: &yourCoordinates, count: yourCoordinates.count)
        guard let polyLine = self.route?.polyline else {
            print("polyLine is nil")
            return
        }
        
        //change destinationCoordinate to polyline.coordinate
        let span = MKCoordinateSpanMake(0.003, 0.003)
        let region = MKCoordinateRegionMake(polyLine.coordinate, span)
        
        
        mapSnapshotOptions.region = region
        
        // Set the scale of the image. We'll just use the scale of the current device, which is 2x scale on Retina screens.
        mapSnapshotOptions.scale = UIScreen.main.scale
        
        // Set the size of the image output.
        // TODO: - change size to routes table view controller
        mapSnapshotOptions.size = CGSize(width: 150, height: 150)
        
        // Show buildings and Points of Interest on the snapshot
        mapSnapshotOptions.showsBuildings = true
        mapSnapshotOptions.showsPointsOfInterest = true
        
        let snapShotter = MKMapSnapshotter(options: mapSnapshotOptions)
        
        snapShotter.start() { snapshot, error in
            guard let snapshot = snapshot else {
                return
            }
            // Don't just pass snapshot.image, pass snapshot itself!
            let imageView = UIImageView()
            imageView.frame = CGRect(origin: .zero, size: CGSize(width: 150, height: 150))
            imageView.image = self.drawLineOnImage(snapshot: snapshot)
            
            self.routeImageView = self.annotationAddedImageView(annotationImage: #imageLiteral(resourceName: "pin"), to: imageView, at: snapshot.point(for: self.destinationCoordinate!))
            
            //handle image
            let image = self.routeImageView?.image
            let imageData = UIImageJPEGRepresentation(image!, 1)
            
            DispatchQueue.main.async {
                if let pathId = self.currentPathId, let imageData = imageData {
                    
                    CoreDataHandler.saveObject(id: pathId, image: imageData)
                    
                }
            }
            
            
            self.routeDelegate?.didGet(routeImageView: self.routeImageView!)
        }
    }
    
    func annotationAddedImageView(annotationImage: UIImage, to baseImageView: UIImageView, at point: CGPoint) -> UIImageView {
        
        let size = baseImageView.frame.size
        UIGraphicsBeginImageContext(size)
        
        let areaSize = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        let baseImage = baseImageView.image
        baseImage!.draw(in: areaSize)
        
        
        let topImageSize = CGSize(width: 30, height: 30)
        let newSizeTopImage = annotationImage.resizedImage(newSize: topImageSize)
        let origin = CGPoint(x: point.x - topImageSize.width / 2, y: point.y - topImageSize.height / 2)
        newSizeTopImage.draw(at: origin)
        
        
        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        baseImageView.image = newImage
        let newImageView = baseImageView
        
        
        return newImageView
        
    }
    
    func drawLineOnImage(snapshot: MKMapSnapshot) -> UIImage {
        let image = snapshot.image
        
        // for Retina screen
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 150, height: 150), true, 0)
        
        // draw original image into the context
        image.draw(at: CGPoint.zero)
        
        // get the context for CoreGraphics
        let context = UIGraphicsGetCurrentContext()
        
        // set stroking width and color of the context
        context!.setLineWidth(2.0)
        context!.setStrokeColor(UIColor.orange.cgColor)
        
        //polyline coordinates
        let polylineCoordinates = self.route?.polyline.coordinates
        
        // Here is the trick :
        // We use addLine() and move() to draw the line, this should be easy to understand.
        // The diificult part is that they both take CGPoint as parameters, and it would be way too complex for us to calculate by ourselves
        // Thus we use snapshot.point() to save the pain.
        context!.move(to: snapshot.point(for: polylineCoordinates![0]))
        for i in 0...polylineCoordinates!.count-1 {
            context!.addLine(to: snapshot.point(for: polylineCoordinates![i]))
            context!.move(to: snapshot.point(for: polylineCoordinates![i]))
        }
        
        // apply the stroke to the context
        context!.strokePath()
        
        // get the image from the graphics context
        let resultImage = UIGraphicsGetImageFromCurrentImageContext()
        
        // end the graphics context
        UIGraphicsEndImageContext()
        
        return resultImage!
    }
    

}

class CustomPointAnnotation: MKPointAnnotation {
    var imageName: UIImage!
}

extension MapViewController {
    func hideSearchBackgroundViewWhenTappedAround() {
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(hideSearchBackgroundView))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    @objc func hideSearchBackgroundView() {
        searchBackgroundView.isHidden = true
    }
}

extension MapViewController {
    func hideKeyboardWhenTappedAround() {
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}

