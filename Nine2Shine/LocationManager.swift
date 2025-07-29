// MARK: - LocationManager.swift

import CoreLocation
import SwiftUI

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let officeLocation = CLLocation(latitude: 23.7423632, longitude: 90.380696)
    private let arrivalThresholdMeters: CLLocationDistance = 100
    private let minimumDurationInOffice: TimeInterval = 300  // 5 minutes

    private var timer: Timer?
    private var arrivalTime: Date?
    private var didSetEntryTime = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 10

        checkPermission()
        locationManager.startUpdatingLocation()
    }

    private func checkPermission() {
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            print("[LocationManager] Requested location permission")
        } else {
            print("[LocationManager] Permission status:", status.rawValue)
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("[LocationManager] Auth changed:", status.rawValue)
        if status == .authorized || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("[LocationManager] Location update received")

        guard UserDefaults.standard.bool(forKey: "useLocationForTime") else {
            print("[LocationManager] useLocationForTime is false")
            return
        }

        if hasEntryTimeForToday {
            print("[LocationManager] Entry time already set for today")
            return
        }

        guard let current = locations.last else {
            print("[LocationManager] No valid location")
            return
        }

        let distance = current.distance(from: officeLocation)
        print("[LocationManager] Distance to office:", distance, "meters")

        if distance <= arrivalThresholdMeters {
            if arrivalTime == nil {
                arrivalTime = Date()
                print("[LocationManager] Entered office zone, starting 5-min timer")
                startStabilityTimer()
            }
        } else {
            print("[LocationManager] Left office zone or too far, resetting")
            resetTracking()
        }
    }

    private func startStabilityTimer() {
        timer?.invalidate()
        print("[LocationManager] Timer started at", Date())
        timer = Timer.scheduledTimer(withTimeInterval: minimumDurationInOffice, repeats: false) { _ in
            self.setEntryTimeIfNeeded()
        }
    }

    private func setEntryTimeIfNeeded() {
        guard !hasEntryTimeForToday else { return }
        let now = Date()
        let comps = Calendar.current.dateComponents([.hour, .minute], from: now)

        UserDefaults.standard.set(comps.hour ?? -1, forKey: "entryHour")
        UserDefaults.standard.set(comps.minute ?? -1, forKey: "entryMinute")
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: "entryDate")

        didSetEntryTime = true
        print("[LocationManager] ✅ Entry time set automatically at", now)
    }

    private func resetTracking() {
        timer?.invalidate()
        arrivalTime = nil
    }

    private var hasEntryTimeForToday: Bool {
        let storedDate = UserDefaults.standard.double(forKey: "entryDate")
        guard storedDate > 0 else { return false }
        let entryDate = Date(timeIntervalSince1970: storedDate)

        let calendar = Calendar.current
        let now = Date()

        // Check if entryDate is today and was set after 6am
        if calendar.isDate(entryDate, inSameDayAs: now) {
            let sixAM = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: now) ?? now
            return entryDate >= sixAM
        }
        return false
    }
} 
