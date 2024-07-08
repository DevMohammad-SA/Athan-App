import Adhan
import CoreLocation
import UserNotifications
import SwiftUI

class PrayerTimesClass: NSObject, ObservableObject, CLLocationManagerDelegate, UNUserNotificationCenterDelegate {
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    @Published var prayers: PrayerTimes?
    @Published var city: String?
    @Published var error: Error?
    
    var notificationSettings: [String: Bool] = [
        "الفجر": true,
        "الظهر": true,
        "العصر": true,
        "المغرب": true,
        "العشاء": true,
        "الشروق": true,
    ]
    
    private var notificationCenter: UNUserNotificationCenter {
        UNUserNotificationCenter.current()
    }

    func scheduleNotification(for prayerTime: Date, with prayerName: String) {
        let content = UNMutableNotificationContent()
        content.title = "تطبيق الأذان"
        switch prayerName {
        case "الفجر":
            content.subtitle = "دخل الآن وقت صلاة الفجر"
            content.body = "قال رسول الله ﷺ (من صلى الصبح فهو في ذمة الله) [رواه مسلم]"
        case "الشروق":
            content.subtitle = "وقت الشروق"
            content.body = "خرج وقت صلاة الفجر"
        default:
            content.subtitle = "دخل الآن وقت صلاة \(prayerName)"
        }
        content.sound = UNNotificationSound.default
        let prayerComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: prayerTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: prayerComponents, repeats: true)
        let request = UNNotificationRequest(identifier: prayerName, content: content, trigger: trigger)
                
        // Remove existing notification for the same prayer time
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [prayerName])
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }

    func schedulePrayerTimesNotification() {
        guard let prayers = prayers else {
            print("Cannot schedule notifications because prayer times are not available yet.")
            return
        }
        let prayerTimes = [
            ("الفجر", prayers.fajr),
            ("الشروق", prayers.sunrise),
            ("الظهر", prayers.dhuhr),
            ("العصر", prayers.asr),
            ("المغرب", prayers.maghrib),
            ("العشاء", prayers.isha),
        ]
        for (prayerName, prayerTime) in prayerTimes {
            if notificationSettings[prayerName] == true {
                scheduleNotification(for: prayerTime, with: prayerName)
            }
        }
    }

    func updateNotificationSettings(for prayerName: String, sendNotification: Bool) {
        notificationSettings[prayerName] = sendNotification
        schedulePrayerTimesNotification()
        let defaults = UserDefaults.standard
        defaults.set(notificationSettings, forKey: "notificationSettings")
    }

    override init() {
        super.init()
        
        let defaults = UserDefaults.standard
        if let savedSettings = defaults.object(forKey: "notificationSettings") as? [String: Bool] {
            notificationSettings = savedSettings
        }
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.requestWhenInUseAuthorization()
        notificationCenter.delegate = self
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting authorization for notifications: \(error.localizedDescription)")
            } else if granted {
                print("User granted permission for notifications!")
            } else {
                print("User denied permission for notifications.")
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let coordinates = Coordinates(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            let params = CalculationMethod.ummAlQura.params
            let components = Calendar.current.dateComponents([.year, .month, .day], from: location.timestamp)
            guard let prayerTimes = PrayerTimes(coordinates: coordinates, date: components, calculationParameters: params) else { return }
            
            DispatchQueue.main.async {
                self.prayers = prayerTimes
                self.error = nil
                self.schedulePrayerTimesNotification()
            }
            self.geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.error = error
                    }
                } else if let placemark = placemarks?.first {
                    DispatchQueue.main.async {
                        self.city = placemark.locality ?? placemark.administrativeArea ?? placemark.country ?? "Unknown location"
                    }
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.error = error
        }
    }

    func startUpdatingLocation() {
        locationManager.delegate = self
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    func formattedPrayerTime(_ prayerTime: Date?) -> String {
        guard let prayerTime = prayerTime else { return "N/A" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.current
        return formatter.string(from: prayerTime)
    }
    
    func getNextPrayer() -> (String, Date)? {
        guard let prayers = prayers else { return nil }
        let now = Date()
        let times: [(String, Date)] = [
            ("الفجر", prayers.fajr),
            ("الشروق", prayers.sunrise),
            ("الظهر", prayers.dhuhr),
            ("العصر", prayers.asr),
            ("المغرب", prayers.maghrib),
            ("العشاء", prayers.isha)
        ]
        
        // Find the next prayer for today
        if let nextPrayer = times.first(where: { $0.1 > now }) {
            return nextPrayer
        }
        
        // If no next prayer today, find the first prayer of tomorrow
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        let components = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
        let coordinates = CLLocationManager().location!.coordinate
        let coords = Coordinates(latitude: coordinates.latitude, longitude: coordinates.longitude)
        let params = CalculationMethod.ummAlQura.params
        if let prayerTimesTomorrow = PrayerTimes(coordinates: coords, date: components, calculationParameters: params) {
            return [
                ("الفجر", prayerTimesTomorrow.fajr),
                ("الشروق", prayerTimesTomorrow.sunrise),
                ("الظهر", prayerTimesTomorrow.dhuhr),
                ("العصر", prayerTimesTomorrow.asr),
                ("المغرب", prayerTimesTomorrow.maghrib),
                ("العشاء", prayerTimesTomorrow.isha)
            ].first
        }
        
        return nil
    }
}
